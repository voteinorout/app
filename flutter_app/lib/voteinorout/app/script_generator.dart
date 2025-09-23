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
  'Witty': 'Clever, sharp, and playful. Uses humor to land the point without diluting the seriousness.',
  'Sarcastic': 'Dry and cutting. Highlights the absurdity of the opponent’s statement with pointed irony.',
  'Empowered': 'Confident, inspiring, and forward-looking. Centers community power and determination.',
  'Logical': 'Calm, fact-forward, and methodical. Walks through the evidence and dismantles the claim with receipts.',
  'Fallacy': 'Instructional tone that calls out the exact logical fallacy or misinformation tactic at play and redirects viewers to the truth.',
};

  static const String _systemPrompt =
    'Use the Missy Elliott method: design the video in reverse. Start from the payoff, '
    'but write the script by validating the opening three seconds first—then the next three, then the next. '
    'At every 3-second beat ask: Would I keep watching? Why should anyone care? Keep hooks tight and specific, '
    'mimicking the viewer’s experience so you consistently maintain attention across each beat until the end.';

  static Future<String> generateScript(
    String topic,
    int length,
    String style, {
    String? cta,
  }) async {
    final String apiKey =
        (dotenv.env['OPENAI_API_KEY'] ?? const String.fromEnvironment('OPENAI_API_KEY')).trim();

    if (apiKey.isEmpty) {
      return 'Add your OPENAI_API_KEY to .env to generate a script.';
    }

    final List<String> searchFacts = await _fetchSearchFacts(topic);
    final String userPrompt =
        _buildUserPrompt(topic, length, style, searchFacts: searchFacts, cta: cta);

    try {
      final http.Response response = await http.post(
        Uri.parse(_openAiEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(<String, dynamic>{
          'model': 'gpt-4o-mini',
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
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String? content =
            jsonBody['choices']?[0]?['message']?['content'] as String?;

        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    } catch (_) {
      // Swallow remote errors to fall back to local generation.
    }

    // Local fallback retains legacy JSON format which we convert to readable text.
    final String? localJson = await LocalLlmService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
      searchFacts: searchFacts,  // Pass facts here
    );

    if (localJson != null && localJson.trim().isNotEmpty) {
      final List<ScriptSegment> localSegments =
          _parseSegments(localJson, length);
      if (localSegments.isNotEmpty) {
        final StringBuffer buffer = StringBuffer();
        for (final ScriptSegment segment in localSegments) {
          final int end = segment.startTime + 3;
          buffer.writeln('${segment.startTime}-$end s');
          buffer.writeln('Voiceover: ${segment.voiceover}');
          if (segment.onScreenText.isNotEmpty) {
            buffer.writeln('On-screen: ${segment.onScreenText}');
          }
          if (segment.visualsActions.isNotEmpty) {
            buffer.writeln('Visuals: ${segment.visualsActions}');
          }
          buffer.writeln();
        }
        if (cta != null && cta.trim().isNotEmpty) {
          buffer.writeln('Call to Action: ${cta.trim()}');
        }
        return buffer.toString().trim();
      }
    }

    return 'Unable to generate a script right now. Try again with a different prompt.';
  }

  static String _buildUserPrompt(
  String topic,
  int length,
  String style, {
  required List<String> searchFacts,
  String? cta,
}) {
  final String styleFragment = (style.isEmpty || style == 'Other') ? 'any' : style.trim().toLowerCase();
  final StringBuffer buffer = StringBuffer()
    ..writeln('Generate a viral video script for "$topic" in $styleFragment style, ')
    ..writeln('length about $length seconds, using the Missy Elliott method to ensure hooks every 3 seconds.')
    ..writeln('Structure the script as a timed breakdown with clear 3-second beats like: ')
    ..writeln('0-3s: [hook]')
    ..writeln('3-6s: [next beat]')
    ..writeln('6-9s: [next beat]')
    ..writeln('... and so on until the target length.')
    ..writeln('For each beat, include:')
    ..writeln('- What is said (voiceover or dialogue)')
    ..writeln('- On-screen text (if any)')
    ..writeln('- Suggested visuals or actions (short)')
    ..writeln('Keep beats punchy, specific, and audience-focused. End with a crisp CTA.')
    ..writeln('Tone and style requirements:')
    ..writeln('- Politically impactful and educational.')  // Keep per Streamlit if desired; remove for full neutrality
    ..writeln('- Click-baity hooks that create curiosity gaps without misleading.')
    ..writeln('- Surprise and delight with credible facts, stats, or discoveries.')
    ..writeln('- Keep claims accurate and responsibly framed; avoid personal attacks or demeaning language.')
    ..writeln('- Where relevant, mention reputable sources or how to verify claims.')
    ..writeln('- Close with a constructive, non-harassing civic action (learn more, verify, vote, contact reps).');

  if (searchFacts.isNotEmpty) {
    buffer.writeln('\nOptionally reference or paraphrase these relevant insights to add credibility and surprise (cite sources briefly if used):');
    for (final String fact in searchFacts) {
      buffer.writeln('- $fact');
    }
  }

  if (cta != null && cta.trim().isNotEmpty) {
    buffer.writeln('\nOverride the default CTA with this exact wording in the final beat: "${cta.trim()}"');
  }

  buffer.writeln('\nOutput only the finished script in plain text (no JSON, no extra notes).');

  return buffer.toString();
}

  static Future<List<String>> _fetchSearchFacts(String topic) async {
  final String serperKey =
      (dotenv.env['SERPER_API_KEY'] ?? const String.fromEnvironment('SERPER_API_KEY')).trim();
  if (serperKey.isEmpty) {
    return <String>[];  // Graceful fallback if no key
  }

  final List<String> queries = <String>{
    'Fun facts about $topic',
    'Recent news about $topic',
    'Statistics about $topic',
  }.toList();

  final List<String> facts = <String>[];

  for (final String query in queries) {
    try {
      final http.Response response = await http.post(
        Uri.parse('https://google.serper.dev/search'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'X-API-KEY': serperKey,
        },
        body: jsonEncode(<String, String>{'q': query, 'gl': 'us', 'hl': 'en'}),
      );

      if (response.statusCode != 200) {
        continue;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? organic = data['organic'] as List<dynamic>?;

      if (organic == null || organic.isEmpty) {
        continue;
      }

      for (final dynamic entry in organic.take(2)) {  // Limit to 2 per query for brevity
        if (entry is Map<String, dynamic>) {
          final String title = entry['title'] as String? ?? '';
          final String snippet = entry['snippet'] as String? ?? '';
          final String fact = '$title — $snippet'.trim();
          if (fact.isNotEmpty && fact.length < 200) {  // Keep facts concise
            facts.add(fact);
          }
        }
      }
    } catch (_) {
      // Ignore individual query failures.
    }
    if (facts.length >= 6) break;  // Cap at 6 total
  }

  return facts.take(6).toList();
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

}
