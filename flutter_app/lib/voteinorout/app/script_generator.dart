import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/voteinorout/app/local_llm_service.dart';

class ScriptGenerator {
  static const String _openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const Map<String, String> _tones = <String, String>{
    'Witty':
        'Clever, sharp, and playful. Uses humor to land the point without diluting the seriousness.',
    'Sarcastic':
        'Dry and cutting. Highlights the absurdity of the opponent’s statement with pointed irony.',
    'Empowered':
        'Confident, inspiring, and forward-looking. Centers community power and determination.',
    'Logical':
        'Calm, fact-forward, and methodical. Walks through the evidence and dismantles the claim with receipts.',
    'Fallacy':
        'Instructional tone that calls out the exact logical fallacy or misinformation tactic at play and redirects viewers to the truth.',
  };

  static const String _systemPrompt =
      'Use the Missy Elliott method: design the video in reverse. Start from the payoff, '
      'but write the script by validating the opening three seconds first—then the next three, then the next. '
      'At every 3-second beat ask: Would I keep watching? Why should anyone care? Keep hooks tight and specific, '
      'mimicking the viewer’s experience so you consistently maintain attention across each beat until the end.';

  static Future<List<ScriptSegment>> generateScript(
    String topic,
    int length,
    String style,
  ) async {
    final String userPrompt = _buildUserPrompt(topic, length, style);

    List<ScriptSegment> remoteSegments = <ScriptSegment>[];
    final String apiKey =
        (dotenv.env['OPENAI_API_KEY'] ?? const String.fromEnvironment('OPENAI_API_KEY')).trim();

    if (apiKey.isNotEmpty) {
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
                'content': _systemPrompt,
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

  static String _buildUserPrompt(String topic, int length, String style) {
    final String styleFragment =
        (style.isEmpty || style == 'Other') ? 'any' : style.trim();
    final String? tone = _tones[style];

    final StringBuffer buffer = StringBuffer()
      ..writeln(
          "Generate a viral video script for '$topic' in $styleFragment style, length about $length seconds, using the Missy Elliott method to ensure hooks every 3 seconds.")
      ..writeln('Structure the script as a timed breakdown with clear 3-second beats like:')
      ..writeln('0-3s: [hook]')
      ..writeln('3-6s: [next beat]')
      ..writeln('6-9s: [next beat]')
      ..writeln('... and so on until the target length.')
      ..writeln('For each beat, include:')
      ..writeln('- What is said (voiceover or dialogue)')
      ..writeln('- Suggested visuals or actions (short)')
      ..writeln(
          'Keep beats punchy, specific, and audience-focused. End with a crisp CTA.')
      ..writeln()
      ..writeln('Tone and style requirements:')
      ..writeln('- Politically impactful and educational.')
      ..writeln('- Click-baity hooks that create curiosity gaps without misleading.')
      ..writeln('- Surprise and delight with credible facts, stats, or discoveries.')
      ..writeln('- Keep claims accurate and responsibly framed; avoid personal attacks or demeaning language.')
      ..writeln('- Where relevant, mention reputable sources or how to verify claims.')
      ..writeln('- Close with a constructive, non-harassing civic action (learn more, verify, vote, contact reps).');

    if (tone != null) {
      buffer.writeln('\nApply this tone: $tone');
    }

    buffer.writeln(
        '\nReturn JSON with a "segments" array. Each segment must include "startTime" (seconds from 0, multiples of 3), "voiceover", and "visualsActions".');
    buffer.writeln(
        'Keep startTime strictly increasing by 3 and limit to ${max(1, (length / 3).ceil())} segments.');
    buffer.writeln('Do not include commentary or wrap the JSON in markdown fences.');

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
