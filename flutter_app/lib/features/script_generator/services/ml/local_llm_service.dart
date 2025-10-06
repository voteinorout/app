import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:vioo_app/features/script_generator/models/script_segment.dart';
import 'package:vioo_app/features/script_generator/services/openai_service.dart';

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
  static const int _fallbackTotalLength = 30;
  static const List<_FallbackBeat> _fallbackBeatPlan = <_FallbackBeat>[
    _FallbackBeat(
      label: 'Hook',
      start: 0,
      end: 6,
      highlightFact: true,
      fallbackToTopic: true,
    ),
    _FallbackBeat(
      label: 'Spark',
      start: 6,
      end: 12,
      highlightFact: true,
      fallbackToTopic: true,
    ),
    _FallbackBeat(
      label: 'Proof',
      start: 12,
      end: 18,
      highlightFact: true,
      fallbackToTopic: true,
    ),
    _FallbackBeat(
      label: 'Turn',
      start: 18,
      end: 24,
      highlightFact: true,
      fallbackToTopic: true,
    ),
    _FallbackBeat(
      label: 'Final CTA',
      start: 24,
      end: 30,
      highlightFact: true,
      fallbackToTopic: true,
    ),
  ];

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
    int temperature = 6,
  }) async {
    // Attempt to use the hosted OpenAI/Vercel service first.
    const int targetLength = _fallbackTotalLength;
    final String? hostedResult = await OpenAIService.generateJsonScript(
      topic: topic,
      length: targetLength,
      style: style,
      cta: cta,
      searchFacts: searchFacts,
      temperature: temperature,
    );
    if (hostedResult != null && hostedResult.trim().isNotEmpty) {
      return hostedResult.trim();
    }

    final String prompt = _buildPrompt(
      topic: topic,
      length: targetLength,
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
      length: targetLength,
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
    final String trimmedStyle = style.trim();
    final bool hasExplicitStyle =
        trimmedStyle.isNotEmpty && trimmedStyle.toLowerCase() != 'other';
    final String tone = hasExplicitStyle
        ? trimmedStyle
        : 'lighthearted and comedic';
    final List<String> cleanedFacts = _prepareFacts(searchFacts);
    final String factsInstruction = cleanedFacts.isNotEmpty
        ? 'Integrate every one of these facts somewhere in the script, quoting each number or named detail plainly and exactly once: ${cleanedFacts.join('; ')}. Do not paraphrase away the numbers, and never invent new data.'
        : 'Ground each beat in believable, specific, verifiable details without inventing statistics.';

    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'You are a campaign storyteller crafting a $length-second video script about "$topic" in a ${tone.toLowerCase()} tone.',
      )
      ..writeln()
      ..writeln(
        'Break the story into these exact beats and include each label with its timestamp:',
      )
      ..writeln(
        '- Hook (0-6s) — deliver a bold opener that makes $topic impossible to ignore right now.',
      )
      ..writeln(
        '- Spark (6-12s) — explain the catalyst or stakes that keep the viewer leaning in.',
      )
      ..writeln(
        '- Proof (12-18s) — present the evidence, stat, or lived moment that makes the story undeniable.',
      )
      ..writeln(
        '- Turn (18-24s) — pivot toward the hopeful path forward and show who is already driving it.',
      )
      ..writeln(
        '- Final CTA (24-30s) — land the CTA with urgency, clarity, and emotional payoff.',
      )
      ..writeln()
      ..writeln('For each beat, output exactly this format:')
      ..writeln('**Hook (0-6s):**')
      ..writeln(
        'Voiceover: <3-4 sentences, 35-45 words, propelling the story forward with vivid specificity>',
      )
      ..writeln(
        'Visuals: <one dynamic sentence suggesting kinetic supporting footage>',
      );

    if (cleanedFacts.isNotEmpty) {
      buffer.writeln('\nWeave in and paraphrase relevant details from:');
      for (final String fact in cleanedFacts) {
        buffer.writeln('- $fact');
      }
    }

    buffer
      ..writeln()
      ..writeln('Guidelines:')
      ..writeln(
        '- Create a seamless narrative arc where every beat references or escalates the one before it.',
      )
      ..writeln(
        '- Use sharp humor, puns, and fluid metaphors tailored to the topic without repeating opening words.',
      )
      ..writeln(
        '- Voiceover must flow as complete sentences; avoid bullet fragments.',
      )
      ..writeln(
        '- Visuals should suggest clear, vivid shots or actions that match the voiceover.',
      )
      ..writeln('- Never mention on-screen text or captions.')
      ..writeln('- $factsInstruction')
      ..writeln(
        hasExplicitStyle
            ? '- Match that tone in every beat without drifting.'
            : '- Keep it quick, warm, and just mischievous enough to stay memorable.',
      )
      ..writeln(
        '- Focus on concise, fact-heavy delivery, avoiding repetition, with dates, names, and laws spelled out.',
      )
      ..writeln(
        '- Tailor to a U.S. audience concerned with state rights and democracy, emphasizing urgency and legal clarity.',
      )
      ..writeln(
        '- If a CTA is provided, weave it naturally into the Final CTA beat; otherwise invent a specific, time-bound action.',
      );

    return buffer.toString();
  }

  static String _generateFallbackScript({
    required String topic,
    required int length,
    required String style,
    required List<String> searchFacts,
  }) {
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
    final int segmentCount = _fallbackBeatPlan.length;
    final List<Map<String, dynamic>> segments = <Map<String, dynamic>>[];
    final List<String> facts = _prepareFacts(searchFacts);
    final List<String> prioritizedFacts = _prioritizeFacts(facts);
    int factCursor = 0;

    String titleCaseTopic(String value) {
      if (value.trim().isEmpty) {
        return 'This Story';
      }
      return value
          .split(RegExp(r'\s+'))
          .map(
            (String word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');
    }

    final String topicTitle = titleCaseTopic(topic);

    String sanitizeTopicDisplay(String raw, String fallback) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return fallback;
      }
      final String singleLine = trimmed.split(RegExp(r'[\r\n]+')).first;
      String cleaned = singleLine.replaceFirst(
        RegExp(r'^\s*[-–—•]*\s*(?:\(?\d+[.)]\s*)?'),
        '',
      );
      if (cleaned.isEmpty) {
        cleaned = fallback;
      }
      const int maxLength = 120;
      if (cleaned.length > maxLength) {
        cleaned = cleaned.substring(0, maxLength).trimRight();
        if (!cleaned.endsWith('…')) {
          cleaned = '$cleaned…';
        }
      }
      return cleaned;
    }

    final String topicDisplay = sanitizeTopicDisplay(topic, topicTitle);

    String? nextFact() {
      if (prioritizedFacts.isEmpty) {
        return null;
      }
      if (factCursor < prioritizedFacts.length) {
        return prioritizedFacts[factCursor++];
      }
      return null;
    }

    String ensureSentence(String raw) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      final String normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
      final String last = normalized[normalized.length - 1];
      return '.!?'.contains(last) ? normalized : '$normalized.';
    }

    String? buildFactPrompt({
      String? factLine,
      required bool allowTopicFallback,
    }) {
      final String cleaned = _cleanFact(factLine ?? '');
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
      if (allowTopicFallback) {
        return 'Show people this is already happening on the ground.';
      }
      return null;
    }

    String buildVoiceover({
      required _FallbackBeat beat,
      required bool isFirst,
      required bool isLast,
      required int index,
      String? factPrompt,
      required String topicDisplay,
      required String toneDescriptor,
    }) {
      final bool hasFact = (factPrompt ?? '').trim().isNotEmpty;
      final List<String> sentences = <String>[];

      String factHighlight(String prefix) {
        if (!hasFact) {
          return '';
        }
        return ensureSentence('$prefix ${factPrompt!.trim()}');
      }

      switch (beat.label) {
        case 'Hook':
          sentences.add(
            ensureSentence(
              'Hit the feed with a $toneDescriptor first line so $topicDisplay feels like breaking news, not background noise',
            ),
          );
          final String factLine = factHighlight(
            'Lead with the jaw-dropping proof:',
          );
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          sentences.add(
            ensureSentence(
              'Leave them hanging on a question the next beat must answer',
            ),
          );
          break;
        case 'Spark':
          sentences.add(
            ensureSentence(
              'Name the spark that proves this story is unfolding right now—who lit the fuse and why it matters tonight',
            ),
          );
          final String factLine = factHighlight(
            'Spell out the stakes they probably have not heard:',
          );
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          sentences.add(
            ensureSentence(
              'Make the viewer feel the stakes tightening without losing momentum',
            ),
          );
          break;
        case 'Proof':
          sentences.add(
            ensureSentence(
              'Drop the receipts that lock the narrative in place: show what changed, who felt it, and how big the shift really is',
            ),
          );
          final String factLine = factHighlight('Quote the evidence straight:');
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          sentences.add(
            ensureSentence(
              'Tie the evidence straight back to the spark so the arc stays seamless',
            ),
          );
          break;
        case 'Turn':
          sentences.add(
            ensureSentence(
              'Show the pivot—people flipping frustration into forward motion and inviting the viewer into that turn',
            ),
          );
          final String factLine = factHighlight(
            'Point to the momentum that proves the turn is real:',
          );
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          sentences.add(
            ensureSentence(
              'Set up the CTA by hinting at what scales if more of us join in',
            ),
          );
          break;
        case 'Final CTA':
          sentences.add(
            ensureSentence(
              'Deliver the CTA like a payoff: spell out the action, the urgency, and the emotional win for taking it now',
            ),
          );
          final String factLine = factHighlight(
            'Remind them what is on the line:',
          );
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          sentences.add(
            ensureSentence(
              'Close with a vivid image or promise that sticks after the video ends',
            ),
          );
          break;
        default:
          final String factLine = factHighlight('Consider this detail:');
          if (factLine.isNotEmpty) {
            sentences.add(factLine);
          }
          break;
      }

      return sentences
          .where((String value) => value.trim().isNotEmpty)
          .join(' ');
    }

    String buildVisuals({
      required _FallbackBeat beat,
      required bool isFirst,
      required bool isLast,
      required int index,
    }) {
      switch (beat.label) {
        case 'Hook':
          return 'Open with a kinetic montage of headlines and close-up reactions that capture the jolt instantly.';
        case 'Spark':
          return 'Cut into the catalyst—hands on the problem, text threads lighting up, the moment momentum catches.';
        case 'Proof':
          return 'Layer receipts: split screens of data, documentary textures, or on-the-ground testimonies synced to the stat.';
        case 'Turn':
          return 'Show the pivot in action—neighbors linking arms, organizers planning, solutions already moving.';
        case 'Final CTA':
          return 'Close on a bold action tableau: a direct-to-camera appeal, on-screen sign-ups, or crowds moving with purpose.';
        default:
          return 'Keep the pace moving with handheld crowd shots and quick reaction cutaways; go tight on faces that show exactly what’s at stake.';
      }
    }

    for (int i = 0; i < segmentCount; i++) {
      final _FallbackBeat beat = _fallbackBeatPlan[i];
      final bool isFirst = i == 0;
      final bool isLast = i == segmentCount - 1;
      final String? selectedFact = beat.highlightFact ? nextFact() : null;
      final String? factPrompt = buildFactPrompt(
        factLine: selectedFact,
        allowTopicFallback: beat.fallbackToTopic,
      );

      final String voiceover = buildVoiceover(
        beat: beat,
        isFirst: isFirst,
        isLast: isLast,
        index: i,
        factPrompt: factPrompt,
        topicDisplay: topicDisplay,
        toneDescriptor: toneDescriptor,
      );

      final String visuals = buildVisuals(
        beat: beat,
        isFirst: isFirst,
        isLast: isLast,
        index: i,
      );

      segments.add(<String, dynamic>{
        'startTime': beat.start,
        'endTime': beat.end,
        'voiceover': voiceover,
        'onScreenText': beat.label,
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
    int? temperature,
  }) async {
    assert(
      temperature == null || (temperature >= 0 && temperature <= 10),
      'Temperature should use the 0-10 scale before normalization.',
    );
    final String rawJson = _generateFallbackScript(
      topic: topic,
      length: length,
      style: style,
      searchFacts: searchFacts ?? <String>[],
    );
    final List<ScriptSegment> segments = _parseSegments(
      rawJson,
      _fallbackTotalLength,
    );
    if (segments.isNotEmpty) {
      final ScriptSegment last = segments.last;
      final String trimmedCta = cta?.trim() ?? '';
      final String appendedVoiceover = trimmedCta.isNotEmpty
          ? '${last.voiceover} Your final push should invite the viewer to act right now: $trimmedCta.'
          : '${last.voiceover} ${_craftInferredCtaSentence(topic)}';
      segments[segments.length - 1] = ScriptSegment(
        startTime: last.startTime,
        endTime: last.endTime,
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

  static List<String> _prepareFacts(List<String> rawFacts) {
    final LinkedHashSet<String> dedup = LinkedHashSet<String>();
    for (final String raw in rawFacts) {
      for (final String expanded in _expandFacts(raw)) {
        final String cleaned = _cleanFact(expanded);
        if (cleaned.isNotEmpty) {
          dedup.add(cleaned);
        }
      }
    }

    if (dedup.isEmpty) {
      for (final String fallback in rawFacts) {
        final String cleaned = _cleanFact(fallback);
        if (cleaned.isNotEmpty) {
          dedup.add(cleaned);
        }
      }
    }

    return dedup.toList(growable: false);
  }

  static List<String> _prioritizeFacts(List<String> facts) {
    if (facts.isEmpty) {
      return <String>[];
    }

    const int maxFacts = 6;
    final RegExp numeric = RegExp(r'\d');
    final List<String> prioritized = <String>[];

    for (final String fact in facts) {
      if (numeric.hasMatch(fact) && prioritized.length < maxFacts) {
        prioritized.add(fact);
      }
    }

    if (prioritized.length < maxFacts) {
      for (final String fact in facts) {
        if (!prioritized.contains(fact)) {
          prioritized.add(fact);
          if (prioritized.length >= maxFacts) {
            break;
          }
        }
      }
    }

    return prioritized;
  }

  static String _cleanFact(String fact) {
    String normalized = fact
        .replaceAll(RegExp(r'[\uFFFC\uFFFD]'), ' ')
        .replaceFirst(RegExp(r'^\s*[-–—•]*\s*(?:\(?\d+[.)]\s*)?'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (!normalized.endsWith('.')) {
      normalized = '$normalized.';
    }
    return normalized;
  }

  static List<String> _expandFacts(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return <String>[];
    }

    final String normalized = trimmed
        .replaceAll(RegExp(r'\r'), '\n')
        .replaceAll('\t', ' ');

    final RegExp bulletLine = RegExp(r'\d+\.\s+([^\n]+)', caseSensitive: false);
    final Iterable<RegExpMatch> bulletMatches = bulletLine.allMatches(
      normalized,
    );
    final List<String> results = <String>[];

    if (bulletMatches.isNotEmpty) {
      for (final RegExpMatch match in bulletMatches) {
        final String? captured = match.group(1);
        if (captured != null && captured.trim().isNotEmpty) {
          results.add(captured.trim());
        }
      }
    } else {
      for (final String piece
          in normalized
              .split(RegExp(r'[\n•·]+'))
              .map((String value) => value.trim())) {
        if (piece.isNotEmpty) {
          results.add(piece);
        }
      }
    }

    return results;
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

      final List<Map<String, dynamic>> typedSegments = segmentList
          .whereType<Map<String, dynamic>>()
          .toList();
      final int expectedSegments = _fallbackBeatPlan.length;

      final List<ScriptSegment> scriptSegments = <ScriptSegment>[];

      for (int i = 0; i < typedSegments.length; i++) {
        final Map<String, dynamic> segment = typedSegments[i];
        final _FallbackBeat defaultBeat = i < _fallbackBeatPlan.length
            ? _fallbackBeatPlan[i]
            : _fallbackBeatPlan.last;
        final int startTime = _coerceStartTime(
          segment['startTime'],
          defaultBeat.start,
        );
        final String voiceover = segment['voiceover']?.toString().trim() ?? '';
        final String onScreenText =
            segment['onScreenText']?.toString().trim() ?? '';
        final String visualsActions =
            segment['visualsActions']?.toString().trim() ?? '';

        if (voiceover.isEmpty) {
          continue;
        }

        final int rawEndTime = _coerceStartTime(
          segment['endTime'],
          defaultBeat.end,
        );
        final int clampedEnd = max(startTime + 1, min(length, rawEndTime));

        scriptSegments.add(
          ScriptSegment(
            startTime: startTime,
            endTime: clampedEnd,
            voiceover: voiceover,
            onScreenText: onScreenText.isEmpty
                ? defaultBeat.label
                : onScreenText,
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

class _FallbackBeat {
  final String label;
  final int start;
  final int end;
  final bool highlightFact;
  final bool fallbackToTopic;

  const _FallbackBeat({
    required this.label,
    required this.start,
    required this.end,
    this.highlightFact = false,
    this.fallbackToTopic = false,
  });

  String get normalizedRange => '$start-${end}s';
}
