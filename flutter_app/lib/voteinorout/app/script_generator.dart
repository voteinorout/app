import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/voteinorout/app/local_llm_service.dart';

class ScriptGenerator {
  static const String _openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String _defaultSystemPrompt =
      'You are an award-winning political short-form video writer. '
      'Every script you deliver is structured as 3-second beats with sharp hooks, '
      'clear on-screen guidance, and visual directions that keep viewers engaged.';
  static const String _missySystemPrompt =
      'Channel Missy Elliott as a creative director for civic action videos. '
      'Scripts must feel like a Missy track: playful swagger, rhythmic pacing, cultural nods, '
      'and lines that punch in every 3 seconds. Always include on-screen text and matching visuals. '
      'Output only the JSON specified by the user.';

  static Future<List<ScriptSegment>> generateScript(
    String topic,
    int length,
    String style,
  ) async {
    final bool missyMode = style.trim().toLowerCase() == 'missy elliott';
    final String systemPrompt =
        missyMode ? _missySystemPrompt : _defaultSystemPrompt;
    final String userPrompt = _buildUserPrompt(topic, length, style, missyMode);

    List<ScriptSegment> remoteSegments = <ScriptSegment>[];
    final String? apiKey = dotenv.env['OPENAI_API_KEY'];

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final http.Response response = await http.post(
          Uri.parse(_openAiEndpoint),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(<String, dynamic>{
            'model': 'gpt-3.5-turbo',
            'max_tokens': 200,
            'messages': <Map<String, String>>[
              <String, String>{
                'role': 'system',
                'content': systemPrompt,
              },
              <String, String>{
                'role': 'user',
                'content': userPrompt,
              },
            ],
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonBody =
              jsonDecode(response.body) as Map<String, dynamic>;
          final String? content =
              jsonBody['choices']?[0]?['message']?['content'] as String?;

          if (content != null && content.trim().isNotEmpty) {
            remoteSegments = _parseSegments(content, length);
          }
        }
      } catch (_) {
        // Swallow network/parsing errors and attempt the local LLM next.
      }
    }

    if (remoteSegments.isNotEmpty) {
      return remoteSegments;
    }

    final String? localJson = await LocalLlmService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
    );

    if (localJson != null && localJson.trim().isNotEmpty) {
      final List<ScriptSegment> localSegments = _parseSegments(localJson, length);
      if (localSegments.isNotEmpty) {
        return localSegments;
      }
    }

    return _fallbackScript(topic, length);
  }

  static String _buildUserPrompt(
      String topic, int length, String style, bool missyMode) {
    final int expectedSegments = max(1, (length / 3).ceil());
    final StringBuffer buffer = StringBuffer()
      ..writeln('Topic: $topic')
      ..writeln('Total length (seconds): $length')
      ..writeln('Target segments (3-second beats): $expectedSegments')
      ..writeln('Requested style: ${style.isEmpty ? 'Unspecified' : style}');

    if (missyMode) {
      buffer.writeln(
          'Tone directives: Swaggering Missy Elliott energy, rhythmic punchlines, cultural callbacks.');
    } else {
      buffer.writeln(
          'Tone directives: Energetic civic engagement, high retention hooks.');
    }

    buffer
      ..writeln(
          'Output instructions: Return JSON with a "segments" array. Each segment must include')
      ..writeln(
          '"startTime" (seconds from 0, multiples of 3), "voiceover", "onScreenText", "visualsActions".')
      ..writeln(
          'Keep startTime strictly increasing by 3. Limit to $expectedSegments segments.')
      ..writeln(
          'Each segment should end on a cliffhanger hook to lead into the next beat.')
      ..writeln(
          'Do not include commentary or wrap the JSON in markdown fences.');

    return buffer.toString();
  }

  static List<ScriptSegment> _parseSegments(String rawContent, int length) {
    final String cleaned = rawContent
        .replaceAll(RegExp(r'^```json', multiLine: true), '')
        .replaceAll(RegExp(r'^```', multiLine: true), '')
        .replaceAll('```', '')
        .trim();

    try {
      final dynamic decoded = jsonDecode(cleaned);
      final List<dynamic>? segmentList;

      if (decoded is Map<String, dynamic>) {
        segmentList = decoded['segments'] as List<dynamic>?;
      } else if (decoded is List<dynamic>) {
        segmentList = decoded;
      } else {
        segmentList = null;
      }

      if (segmentList == null) {
        return <ScriptSegment>[];
      }
      final List<Map<String, dynamic>> typedSegments =
          segmentList.whereType<Map<String, dynamic>>().toList();
      final int expectedSegments = max(1, (length / 3).ceil());

      final List<ScriptSegment> scriptSegments = <ScriptSegment>[];

      for (int i = 0; i < typedSegments.length; i++) {
        final Map<String, dynamic> segment = typedSegments[i];
        final int startTime = _coerceStartTime(segment['startTime'], i * 3);
        final String voiceover = segment['voiceover']?.toString().trim() ?? '';
        final String onScreenText =
            segment['onScreenText']?.toString().trim() ?? '';
        final String visualsActions =
            segment['visualsActions']?.toString().trim() ?? '';

        if (voiceover.isEmpty) {
          continue;
        }

        scriptSegments.add(
          ScriptSegment(
            startTime: startTime,
            voiceover: voiceover,
            onScreenText: onScreenText,
            visualsActions: visualsActions,
          ),
        );

        if (scriptSegments.length >= expectedSegments) {
          break;
        }
      }

      return scriptSegments;
    } catch (_) {
      // Malformed JSON or unexpected structure falls back to local content generation.
      return <ScriptSegment>[];
    }
  }

  static int _coerceStartTime(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final Match? match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }
    return fallback;
  }

  static List<ScriptSegment> _fallbackScript(String topic, int length) {
    final int segmentCount = max(1, (length / 3).ceil());

    return List<ScriptSegment>.generate(segmentCount, (int index) {
      final int startTime = index * 3;
      final String hook = index == 0
          ? 'Hot take: $topic could reshape the next election.'
          : 'Keep watching — your vote on $topic is the remix we need.';
      final String onScreenText =
          index == 0 ? 'Vote In Or Out?' : 'You decide on $topic';
      final String visuals = index.isEven
          ? 'Energetic crowd at the polls, bold typography overlays.'
          : 'Close-up voter marking ballot, dynamic camera push-in.';

      return ScriptSegment(
        startTime: startTime,
        voiceover: hook,
        onScreenText: onScreenText,
        visualsActions: visuals,
      );
    });
  }
}
