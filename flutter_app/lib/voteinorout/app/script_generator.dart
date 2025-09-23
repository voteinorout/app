import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:vioo_app/services/api_key_service.dart';
import 'package:vioo_app/voteinorout/app/local_llm_service.dart';

class ScriptGenerator {
  ScriptGenerator._();

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

  static const List<String> _requiredFacts = <String>[
    'The U.S. Pentagon just issued a new memo requiring journalists to pledge not to report any unapproved information—even if it’s unclassified—and risk losing credentials.',
    'ABC pulled Jimmy Kimmel Live! off the air indefinitely after his monologue about Charlie Kirk’s death, sparking public debate over whether it was corporate pressure or outright censorship.',
    'In 2025, twelve children from U.S. Department of Defense schools filed a lawsuit after books were removed and curricula changed around race, gender, and LGBTQ topics following new federal rules around “divisive concepts.”',
    'A recent Pew Research survey shows that 73% of U.S. adults believe that a free press is “extremely” or “very” important to the well-being of society.',
    'Experts report that over 78% of “speech restriction developments” globally have increased in the last year, including via laws, court decisions, or government enforcement—even in countries that say they support free speech.',
  ];

  static const String _systemPrompt =
      'Use the Missy Elliott method: design the video in reverse. Start from the payoff, '
      'but write the script by validating the opening three seconds first—then the next three, then the next. '
      'At every beat ask: Would I keep watching? Why should anyone care? Keep hooks tight and specific, '
      'mimicking the viewer’s experience so you consistently maintain attention across each beat until the end.';

  static Future<String> generateScript(
    String topic,
    int length,
    String style, {
    String? cta,
  }) async {
    final String? remoteKey = await ApiKeyService.instance.fetchOpenAiKey();
    final String compileTimeKey = const String.fromEnvironment('OPENAI_API_KEY');
    final String envKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final String apiKey =
        (remoteKey?.trim().isNotEmpty ?? false)
            ? remoteKey!.trim()
            : (compileTimeKey.isNotEmpty
                ? compileTimeKey.trim()
                : envKey.trim());

    if (apiKey.isEmpty) {
      return 'No OpenAI API key available. Configure it via Firebase (getOpenAiApiKey function) or --dart-define/ .env.';
    }

    final List<String> searchFacts = await _fetchSearchFacts(topic);
    final String userPrompt = _buildUserPrompt(
      topic,
      length,
      style,
      searchFacts: searchFacts,
      cta: cta,
    );

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
            <String, String>{'role': 'system', 'content': _systemPrompt},
            <String, String>{'role': 'user', 'content': userPrompt},
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
      } else {
        debugPrint('OpenAI response ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('OpenAI call failed: $e');
      debugPrint(stack.toString());
    }

    final String? localFallback = await LocalLlmService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
    );

    if (localFallback != null && localFallback.isNotEmpty) {
      return localFallback;
    }

    return 'Unable to generate a script right now. Try again after verifying network access and Firebase configuration.';
  }

  static String _buildUserPrompt(
    String topic,
    int length,
    String style, {
    required List<String> searchFacts,
    String? cta,
  }) {
    final int segmentCount = max(1, (length / 5).ceil());
    final String styleFragment =
        (style.isEmpty || style == 'Other') ? 'any' : style.trim();
    final String? tone = _tones[style];

    final StringBuffer buffer = StringBuffer()
      ..writeln(
          "Generate a viral video script for '$topic' in $styleFragment style, length about $length seconds, using the Missy Elliott method to ensure hooks every 5 seconds.")
      ..writeln('Structure the script with clear 5-second beats like:')
      ..writeln('0-5s: [hook]')
      ..writeln('5-10s: [next beat]')
      ..writeln('10-15s: [next beat]')
      ..writeln('... continue until the target length. Include a final Call to Action beat.')
      ..writeln('For each beat include:')
      ..writeln('- Voiceover (a single concise paragraph)')
      ..writeln('- Visuals/Actions (short, cinematic cues)')
      ..writeln('- Search: a suggested keyword/tool/source for the viewer to research next')
      ..writeln('Keep beats punchy, specific, and audience-focused. Use curiosity gaps.');

    buffer
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

    if (searchFacts.isNotEmpty) {
      buffer.writeln('\nBlend in these fresh findings (paraphrase, cite briefly if used):');
      for (final String fact in searchFacts) {
        buffer.writeln('- $fact');
      }
    }

    buffer.writeln('\nYou must incorporate the following verified facts across the beats:');
    for (final String fact in _requiredFacts) {
      buffer.writeln('- $fact');
    }

    if (cta != null && cta.trim().isNotEmpty) {
      buffer.writeln(
          '\nUse this exact CTA in the final beat: "${cta.trim()}"');
    }

    buffer.writeln(
        '\nOutput only the formatted script in plain text. Use headings like “0-5s:”, “5-10s:” etc., and label the final beat “Call to Action (XX-YYs):”.');
    buffer.writeln('Aim for about $segmentCount beats in total.');

    return buffer.toString();
  }

  static Future<List<String>> _fetchSearchFacts(String topic) async {
    final String serperKey =
        (dotenv.env['SERPER_API_KEY'] ?? const String.fromEnvironment('SERPER_API_KEY')).trim();
    if (serperKey.isEmpty) {
      return <String>[];
    }

    final List<String> queries = <String>{
      'Did you know facts about $topic',
      'Recent news about $topic free speech',
      'Statistics about $topic civic engagement',
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

        for (final dynamic entry in organic.take(3)) {
          if (entry is Map<String, dynamic>) {
            final String title = entry['title'] as String? ?? '';
            final String snippet = entry['snippet'] as String? ?? '';
            final String fact = '$title — $snippet'.trim();
            if (fact.isNotEmpty) {
              facts.add(fact);
            }
          }
        }
      } catch (e) {
        debugPrint('Serper query failed for "$query": $e');
      }
    }

    return facts.take(6).toList();
  }
}
