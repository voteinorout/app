import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/services/openai_service.dart';

/// Simple wrapper around a TensorFlow Lite text generation model that turns
/// prompts into script JSON. The actual model is expected to expose a
/// signature named `generate` that accepts a `prompt` string and returns a
/// `text` field containing the generated payload.
///
/// Replace `assets/models/local_llm.tflite` with your quantized local model.
class LocalLlmService {
  LocalLlmService._();

  static Interpreter? _interpreter;
  static bool _isLoading = false;
  static String? _lastError;

  /// Lazily loads the interpreter from assets so callers do not pay the cost
  /// until the fallback is needed.
  static Future<Interpreter?> _loadInterpreter() async {
    if (_interpreter != null) {
      return _interpreter;
    }
    if (_isLoading) {
      // Wait for any in-flight initialization to finish.
      while (_isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return _interpreter;
    }

    _isLoading = true;
    try {
      _interpreter = await Interpreter.fromAsset(
        'models/local_llm.tflite',
        options: InterpreterOptions()..threads = 2,
      );
    } on Exception catch (e) {
      _lastError = e.toString();
      _interpreter = null;
    } finally {
      _isLoading = false;
    }

    return _interpreter;
  }

  /// Attempts to generate a script in plain text format. Returns `null` when the
  /// local model is unavailable or fails. The caller can then fall back to a
  /// procedural generator.
  static Future<String?> generateJsonScript({
    required String topic,
    required int length,
    required String style,
    List<String>? searchFacts,
    String? cta,
  }) async {
    // Attempt to use the hosted OpenAI/Vercel service first.
    final String? hostedResult = await OpenAIService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
      cta: cta,
      searchFacts: searchFacts,
    );
    if (hostedResult != null && hostedResult.trim().isNotEmpty) {
      return hostedResult.trim();
    }

    final String prompt = _buildPrompt(
      topic: topic,
      length: length,
      style: style,
      searchFacts: searchFacts ?? <String>[],
    );

    // No functional TFLite inference is wired up yet. Attempt to load the
    // interpreter so we can surface a meaningful status message, then fall
    // back to a deterministic rule-based generator that mirrors the legacy
    // behaviour.
    final Interpreter? interpreter = await _loadInterpreter();
    const String hostedWarning =
        'Hosted script proxy unavailable or returned no content. Using deterministic fallback script.';
    if (interpreter == null) {
      _lastError = hostedWarning;
    } else {
      _lastError =
          '$hostedWarning (local model prompt length ${prompt.length}).';
    }

    return _generateFallbackScript(
      topic: topic,
      length: length,
      style: style,
      searchFacts: searchFacts ?? <String>[],
    );
  }

  /// Builds the textual prompt given to the local model.
  static String _buildPrompt({
    required String topic,
    required int length,
    required String style,
    required List<String> searchFacts,
  }) {
    final String tone = (style.isEmpty || style == 'Other')
        ? 'lighthearted and comedic'
        : style.trim();
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'You are a campaign storyteller crafting a $length-second video script about "$topic" in a ${tone.toLowerCase()} tone.',
      )
      ..writeln('Break the script into 6-second beats using this exact template:')
      ..writeln('0-6s: [hook] — conversational question that sparks curiosity.')
      ..writeln('Voiceover: 2-3 sentences, 25-35 words, and no bullet fragments.')
      ..writeln('Visuals: One detailed sentence describing kinetic supporting footage.')
      ..writeln('6-12s: [next beat] — escalate the idea with creative benefits.')
      ..writeln('12-18s: [next beat] — heighten stakes with witty or unexpected scenario.')
      ..writeln('18-24s: [twist] — introduce a doubt or reality check with humor.')
      ..writeln(
        '24-${length}s: [payoff/CTA] — resolve with an inspiring lead-in to the CTA.',
      )
      ..writeln('Never mention on-screen text or captions. Use sharp humor, puns, and fluid metaphors tailored to the topic.');

    if (searchFacts.isNotEmpty) {
      buffer.writeln('\nWeave in and paraphrase relevant details from:');
      for (final String fact in searchFacts) {
        buffer.writeln('- $fact');
      }
    }

    buffer
      ..writeln('Avoid repeating the same opening words (for example, do not rely on "imagine" repeatedly).')
      ..writeln('Return only the formatted beats in plain text, matching the template headings.');

    return buffer.toString();
  }

  static String _generateFallbackScript({
    required String topic,
    required int length,
    required String style,
    required List<String> searchFacts,
  }) {
    const int beatDuration = 6;
    final String toneDescriptor = (() {
      final String normalized = style.trim().toLowerCase();
      switch (normalized) {
        case 'motivational':
          return 'charged and optimistic';
        case 'educational':
          return 'confidently informative';
        case 'comedy':
          return 'playfully sharp';
        case 'exciting':
          return 'high-intensity';
        case 'relaxed':
          return 'warm and steady';
        case 'creative':
          return 'imaginative and unexpected';
        default:
          return 'bold';
      }
    })();
    final int segmentCount = max(1, (length / beatDuration).ceil());

    final List<Map<String, dynamic>> segments = <Map<String, dynamic>>[];
    final List<String> facts =
        searchFacts.where((String fact) => fact.trim().isNotEmpty).toList();

    String _titleCaseTopic(String value) {
      if (value.trim().isEmpty) {
        return 'This Story';
      }
      return value
          .split(RegExp(r'\s+'))
          .map((String word) =>
              word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    final String topicTitle = _titleCaseTopic(topic);
    final String topicDisplay = topic.trim().isEmpty ? topicTitle : topic.trim();

    String humanizeFact(String factLine) {
      String cleaned = factLine
          .replaceFirst(RegExp(r'^[-–—]\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      cleaned = cleaned
          .replaceFirst(
            RegExp(r'^Share something useful about ', caseSensitive: false),
            'Highlight how ',
          )
          .replaceFirst(
            RegExp(r'^Share a useful detail about ', caseSensitive: false),
            'Highlight how ',
          );
      if (cleaned.endsWith('.')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      if (cleaned.isEmpty) {
        cleaned = 'highlight how $topicDisplay is showing up in real life right now';
      }
      if (cleaned.isNotEmpty) {
        cleaned = cleaned[0].toLowerCase() + cleaned.substring(1);
      }
      return cleaned;
    }

    String buildVoiceover({
      required bool isFirst,
      required bool isLast,
      required int index,
      required String factPrompt,
      required String topicDisplay,
      required String toneDescriptor,
    }) {
      final List<String> firstHooks = <String>[
        'Open with a $toneDescriptor jolt so $topicDisplay feels urgent enough to stop the scroll.',
        'Drop the viewer right in: $topicDisplay is already rewriting what they thought was settled.',
      ];
      final List<String> midHooks = <String>[
        'Keep that $toneDescriptor rhythm pounding by showing how $topicDisplay collides with an ordinary moment.',
        'Shift the angle so $topicDisplay hits like breaking gossip in someone’s notifications.',
        'Reveal the twist people miss about $topicDisplay when they only skim the headline.',
      ];
      final List<String> lastHooks = <String>[
        'Stick the landing with that same $toneDescriptor energy and make $topicDisplay impossible to ignore.',
        'Bring it home so $topicDisplay becomes the decision they have to make next.',
      ];
      final List<String> detailPrompts = <String>[
        'Work this in like it just happened to someone they know: $factPrompt, and make it feel personal.',
        'Use it as a quick proof point without sounding scripted: $factPrompt, then tie it to what the viewer controls.',
        'Deliver it like overheard gossip that matters: $factPrompt, and explain why it hits right now.',
      ];
      final List<String> genericDetails = <String>[
        'Drop in a concrete, human-sized example that proves $topicDisplay isn’t abstract.',
        'Give them one vivid moment they can picture happening on their own block because of $topicDisplay.',
        'Paint a fast scene that turns $topicDisplay into something they can feel.',
      ];
      final List<String> midClosers = <String>[
        'Challenge the viewer to picture what changes tonight if they stay with you.',
        'Promise the next beat uncovers the part no one else is saying out loud.',
        'Show what it costs to look away for even one more day.',
      ];
      final List<String> finalClosers = <String>[
        'Make the stakes explicit and invite them to move before the moment passes.',
        'Spell out how their next decision becomes the turning point.',
      ];

      final List<String> twistHooks = <String>[
        'Lean into the doubt: what if $topicDisplay is more complicated than the headline admits?',
        'Acknowledge the skeptic in the room and turn it into a $toneDescriptor punchline about $topicDisplay.',
      ];
      final List<String> twistClosers = <String>[
        'Flip that hesitation into a reason the viewer needs to stay and see what comes next.',
        'Answer the doubt with a believable scenario that still keeps the energy high.',
      ];

      final String hook = isFirst
          ? firstHooks[index % firstHooks.length]
          : isLast
              ? lastHooks[index % lastHooks.length]
              : (index == 3 ? twistHooks[index % twistHooks.length] : midHooks[index % midHooks.length]);

      final String detail = factPrompt.isEmpty
          ? genericDetails[index % genericDetails.length]
          : detailPrompts[index % detailPrompts.length];

      final String closer = isLast
          ? finalClosers[index % finalClosers.length]
          : (index == 3 ? twistClosers[index % twistClosers.length] : midClosers[index % midClosers.length]);

      return '$hook $detail $closer';
    }

    String buildVisuals({
      required bool isFirst,
      required bool isLast,
      required int index,
    }) {
      if (isFirst) {
        return 'Open with a fast push-in on a worried face or headline screenshot, then cut to kinetic footage that makes the stakes feel immediate.';
      }
      if (isLast) {
        return 'Layer a tight shot on the speaker with bold motion graphics flashing the next step, then land on a motivating action moment that invites the viewer to move.';
      }
      final List<String> midVisuals = <String>[
        'Keep the pace moving with handheld crowd shots and quick reaction cutaways; go tight on faces that show exactly what’s at stake.',
        'Track the problem over shoulders or screens so the viewer experiences it in real time, then jump to the fallout.',
        'Use dynamic B-roll that swings from wide context to razor-sharp details, matching each cut to the emotional shift in the voiceover.',
      ];
      return midVisuals[index % midVisuals.length];
    }

    for (int i = 0; i < segmentCount; i++) {
      final int start = i * beatDuration;
      final bool isFirst = i == 0;
      final bool isLast = i == segmentCount - 1;
      final String factLine =
          i < facts.length
              ? facts[i]
              : 'Surface a quick proof point about $topicDisplay.';
      final String factPrompt = humanizeFact(factLine);

      final String voiceover = buildVoiceover(
        isFirst: isFirst,
        isLast: isLast,
        index: i,
        factPrompt: factPrompt,
        topicDisplay: topicDisplay,
        toneDescriptor: toneDescriptor,
      );

      final String visuals = buildVisuals(
        isFirst: isFirst,
        isLast: isLast,
        index: i,
      );

      final List<String> labels = <String>['[hook]', '[next beat]', '[next beat]', '[twist]', '[payoff/CTA]'];
      final String label = labels[min(i, labels.length - 1)];

      segments.add(<String, dynamic>{
        'startTime': start,
        'voiceover': voiceover,
        'onScreenText': label,
        'visualsActions': visuals,
      });
    }

    return jsonEncode(<String, dynamic>{'segments': segments});
  }

  static Future<List<ScriptSegment>> generateFallbackSegments({
    required String topic,
    required int length,
    required String style,
    String? cta,
    List<String>? searchFacts,
  }) async {
    final String rawJson = _generateFallbackScript(
      topic: topic,
      length: length,
      style: style,
      searchFacts: searchFacts ?? <String>[],
    );
    final List<ScriptSegment> segments =
        _parseSegments(rawJson, length);
    if (segments.isNotEmpty) {
      final ScriptSegment last = segments.last;
      final String trimmedCta = cta?.trim() ?? '';
      final String appendedVoiceover = trimmedCta.isNotEmpty
          ? '${last.voiceover} Your final push should invite the viewer to act right now: $trimmedCta.'
          : '${last.voiceover} ${_craftInferredCtaSentence(topic)}';
      segments[segments.length - 1] = ScriptSegment(
        startTime: last.startTime,
        voiceover: appendedVoiceover.trim(),
        onScreenText: last.onScreenText,
        visualsActions: last.visualsActions,
      );
    }
    return segments;
  }

  /// Exposes the last interpreter error for logging/debug UIs.
  static String? get lastError => _lastError;

  /// Releases interpreter resources. Useful for hot reload or when the app no
  /// longer needs the local model.
  static Future<void> dispose() async {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
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

      const int beatDuration = 6;
      final List<Map<String, dynamic>> typedSegments =
          segmentList.whereType<Map<String, dynamic>>().toList();
      final int expectedSegments = max(1, (length / beatDuration).ceil());

      final List<ScriptSegment> scriptSegments = <ScriptSegment>[];

      for (int i = 0; i < typedSegments.length; i++) {
        final Map<String, dynamic> segment = typedSegments[i];
        final int startTime =
            _coerceStartTime(segment['startTime'], i * beatDuration);
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

  static String _craftInferredCtaSentence(String topic) {
    final String trimmed = topic.trim();
    if (trimmed.isEmpty) {
      return 'Give them a next step: share this with someone you trust and agree on one action to take today.';
    }
    final String lower = trimmed.toLowerCase();
    return 'Give them a next step: share this with someone you trust and agree on one action to take today about $lower.';
  }
}
