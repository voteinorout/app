import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:vioo_app/features/script_generator/models/script_segment.dart';
import 'package:vioo_app/features/script_generator/services/ml/local_llm_service.dart';
import 'package:vioo_app/features/script_generator/services/openai_service.dart';

class ScriptGenerator {
  static const int _targetLengthSeconds = 30;
  static const List<_BeatSlot> _beatSlots = <_BeatSlot>[
    _BeatSlot(label: 'Hook', start: 0, end: 6),
    _BeatSlot(label: 'Spark', start: 6, end: 12),
    _BeatSlot(label: 'Proof', start: 12, end: 18),
    _BeatSlot(label: 'Turn', start: 18, end: 24),
    _BeatSlot(label: 'Final CTA', start: 24, end: 30),
  ];
  static final RegExp _beatPattern = RegExp(r'\*\*[^*]+\((\d+)-(\d+)s\):\*\*');

  static bool _lastRunUsedHosted = false;
  static String? _lastRunWarning;

  static bool get lastRunUsedHosted => _lastRunUsedHosted;

  static String? get lastRunWarning => _lastRunWarning;

  static Future<String> generateScript(
    String topic,
    int length,
    String style, {
    String? cta,
    required int temperature,
  }) async {
    _lastRunWarning = null;
    final String trimmedCta = (cta ?? '').trim();
    const List<String> factList = <String>[];

    final String? remoteScript = await OpenAIService.generateJsonScript(
      topic: topic,
      length: _targetLengthSeconds,
      style: style,
      cta: trimmedCta.isEmpty ? null : trimmedCta,
      temperature: temperature,
    );

    if (remoteScript != null && remoteScript.trim().isNotEmpty) {
      _lastRunUsedHosted = true;
      final String formatted = _formatBeats(remoteScript.trim());
      final int beatCount = _countBeats(formatted);
      List<ScriptSegment>? supplementSegments;
      if (beatCount < _beatSlots.length) {
        _lastRunWarning =
            'Hosted script returned $beatCount of ${_beatSlots.length} beats; padding with fallback sections.';
        supplementSegments = await LocalLlmService.generateFallbackSegments(
          topic: topic,
          length: _targetLengthSeconds,
          style: style,
          cta: trimmedCta.isEmpty ? null : trimmedCta,
          temperature: temperature,
        );
      }
      final String ensured = _ensureBeatCoverage(
        formatted,
        _beatSlots.length,
        fallbackSegments: supplementSegments,
      );
      return _injectFactsIntoScript(
        ensured,
        factList,
        style,
      );
    }

    _lastRunUsedHosted = false;
    if (kDebugMode) {
      debugPrint(
        'Hosted script proxy unavailable or incomplete; using on-device fallback generator.',
      );
    }

    // Local fallback retains legacy JSON format which we convert to readable text.
    final List<ScriptSegment> localSegments =
        await LocalLlmService.generateFallbackSegments(
          topic: topic,
          length: _targetLengthSeconds,
          style: style,
          cta: trimmedCta.isEmpty ? null : trimmedCta,
          temperature: temperature,
        );

    if (localSegments.isEmpty) {
      _lastRunWarning = 'Script generator fallback returned no segments.';
      return _formatBeats(
        'Unable to generate a script right now. Try again with a different prompt.',
      );
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < localSegments.length && i < _beatSlots.length; i++) {
      final ScriptSegment segment = localSegments[i];
      final _BeatSlot slot = _beatSlots[i];
      buffer.writeln('**${slot.label} (${slot.rangeString}):**');
      buffer.writeln(segment.voiceover.trim());
      if (segment.visualsActions.isNotEmpty) {
        buffer.writeln('Visuals: ${segment.visualsActions}');
      }
      buffer.writeln();
    }
    if (trimmedCta.isNotEmpty) {
      buffer.writeln('Call to Action: $trimmedCta');
    }

    final String formattedFallback = _formatBeats(buffer.toString().trim());
    final String ensured = _ensureBeatCoverage(
      formattedFallback,
      _beatSlots.length,
      fallbackSegments: localSegments,
    );

    _lastRunWarning =
        LocalLlmService.lastError ??
        'Hosted script generation failed; using deterministic fallback.';
    return _injectFactsIntoScript(
      ensured,
      factList,
      style,
    );
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
      final int expectedSegments = _beatSlots.length;

      final List<ScriptSegment> scriptSegments = <ScriptSegment>[];

      for (int i = 0; i < typedSegments.length; i++) {
        final Map<String, dynamic> segment = typedSegments[i];
        final _BeatSlot defaultSlot = i < _beatSlots.length
            ? _beatSlots[i]
            : _beatSlots.last;
        final int startTime = _coerceStartTime(
          segment['startTime'],
          defaultSlot.start,
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
          defaultSlot.end,
        );
        final int clampedEnd = max(startTime + 1, min(length, rawEndTime));

        scriptSegments.add(
          ScriptSegment(
            startTime: startTime,
            endTime: clampedEnd,
            voiceover: voiceover,
            onScreenText: onScreenText.isEmpty
                ? defaultSlot.label
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
      // Malformed JSON or unexpected structure falls back to local content generation.
      return <ScriptSegment>[];
    }
  }

  @visibleForTesting
  static List<ScriptSegment> parseSegmentsForTest(
    String rawContent,
    int length,
  ) => _parseSegments(rawContent, length);

  static String _injectFactsIntoScript(
    String script,
    List<String> facts,
    String style,
  ) {
    final String trimmed = script.trimRight();
    if (facts.isEmpty) {
      return trimmed;
    }

    final List<String> normalizedFacts = facts
        .map(
          (String fact) => fact
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll(RegExp(r'[\uFFFC\uFE0F]'), '')
              .trim(),
        )
        .where((String fact) => fact.isNotEmpty)
        .toList(growable: false);

    if (normalizedFacts.isEmpty) {
      return trimmed;
    }

    final StringBuffer buffer = StringBuffer(trimmed)
      ..writeln()
      ..writeln()
      ..writeln('Additional context:');
    for (final String fact in normalizedFacts) {
      buffer.writeln('- ${fact.trim()}');
    }

    return buffer.toString();
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

  static String _formatBeats(String script) {
    final RegExp labelHeader = RegExp(
      r'^(\s*)(?:\*\*)?([^:(\n]+?)\s*\((\d+\s*-\s*\d+\s*(?:s|sec|seconds)?)\)\s*:?(.+)?$',
      caseSensitive: false,
    );
    final RegExp timeHeader = RegExp(
      r'^(\s*)(\d+\s*-\s*\d+\s*(?:s|sec|seconds)?)\s*:(.*)',
    );
    final List<String> lines = script.split('\n');
    final List<String> formatted = <String>[];
    for (final String line in lines) {
      final String trimmed = line.trimLeft();
      if (trimmed.startsWith('**') && trimmed.contains('):**')) {
        formatted.add(line);
        continue;
      }
      final Match? labelMatch = labelHeader.firstMatch(line);
      if (labelMatch != null) {
        final String prefix = labelMatch.group(1) ?? '';
        final String label = labelMatch.group(2)!.trim();
        final String range = _normalizeRange(labelMatch.group(3) ?? '');
        final String rest = labelMatch.group(4)?.trimLeft() ?? '';
        final String suffix = rest.isEmpty ? '' : ' $rest';
        formatted.add('$prefix**$label ($range):**$suffix');
        continue;
      }
      final Match? timeMatch = timeHeader.firstMatch(line);
      if (timeMatch != null) {
        final String prefix = timeMatch.group(1) ?? '';
        final String range = _normalizeRange(timeMatch.group(2) ?? '');
        final String rest = timeMatch.group(3)?.trimLeft() ?? '';
        final String cleanedRest = rest.replaceFirst(
          RegExp(r'^\[[^\]]+\]\s*'),
          '',
        );
        final String suffix = cleanedRest.isEmpty ? '' : ' $cleanedRest';
        final _BeatSlot slot = _beatSlots.firstWhere(
          (candidate) => candidate.matchesRange(range),
          orElse: () => _BeatSlot.fallback(range),
        );
        formatted.add('$prefix**${slot.label} (${slot.rangeString}):**$suffix');
      } else {
        formatted.add(line);
      }
    }
    String formattedScript = formatted.join('\n');
    formattedScript = formattedScript.replaceAllMapped(
      RegExp(r'(^|\n)(\s*)Voiceover:\s*', caseSensitive: false),
      (Match m) => '${m.group(1)}${m.group(2)}',
    );
    formattedScript = formattedScript.replaceAllMapped(
      RegExp(r'(^|\n)Visuals:\s*(.*)'),
      (Match m) => '${m.group(1)}> *Visuals:* ${m.group(2)}',
    );
    return formattedScript;
  }

  static String _ensureBeatCoverage(
    String script,
    int expectedBeats, {
    List<ScriptSegment>? fallbackSegments,
  }) {
    String trimmed = script.trim();
    int actualBeats = _countBeats(trimmed);
    if (actualBeats >= expectedBeats) {
      return trimmed;
    }

    final Map<int, ScriptSegment> fallbackByIndex = <int, ScriptSegment>{};
    if (fallbackSegments != null) {
      for (
        int i = 0;
        i < fallbackSegments.length && i < _beatSlots.length;
        i++
      ) {
        fallbackByIndex[i] = fallbackSegments[i];
      }
    }

    String? callToAction;
    String body = trimmed;
    final RegExp ctaRegex = RegExp(r'(?:^|\n)(Call to Action:\s*.+)$');
    final Match? ctaMatch = ctaRegex.firstMatch(trimmed);
    if (ctaMatch != null) {
      callToAction = ctaMatch.group(1)!.trim();
      body = trimmed.substring(0, ctaMatch.start).trimRight();
    }

    final StringBuffer buffer = StringBuffer(body);
    while (actualBeats < expectedBeats && actualBeats < _beatSlots.length) {
      final _BeatSlot slot = _beatSlots[actualBeats];
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.writeln('**${slot.label} (${slot.rangeString}):**');
      final ScriptSegment? fallbackSegment = fallbackByIndex[actualBeats];
      final String fallbackVoiceover =
          fallbackSegment != null && fallbackSegment.voiceover.trim().isNotEmpty
          ? fallbackSegment.voiceover.trim()
          : 'Reinforce the story arc with a concrete stat or named source that keeps momentum strong.';
      buffer.writeln(fallbackVoiceover);
      final String fallbackVisuals =
          fallbackSegment != null &&
              fallbackSegment.visualsActions.trim().isNotEmpty
          ? fallbackSegment.visualsActions.trim()
          : 'Show supporting footage, charts, or receipts that underline the data point.';
      buffer.writeln('> *Visuals:* $fallbackVisuals');
      actualBeats += 1;
    }

    if (callToAction != null && callToAction.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(callToAction);
    }

    return buffer.toString().trim();
  }

  static int _countBeats(String script) =>
      _beatPattern.allMatches(script).length;

  static String _normalizeRange(String rawRange) {
    String normalized = rawRange.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll('seconds', 's').replaceAll('sec', 's');
    if (!normalized.endsWith('s')) {
      normalized = '${normalized}s';
    }
    return normalized;
  }
}

class _BeatSlot {
  final String label;
  final int start;
  final int end;

  const _BeatSlot({
    required this.label,
    required this.start,
    required this.end,
  });

  String get rangeString => '$start-${end}s';
  String get normalizedRange => rangeString;

  bool matchesRange(String candidate) => candidate == normalizedRange;

  factory _BeatSlot.fallback(String range) {
    final String normalized = ScriptGenerator._normalizeRange(range);
    final List<String> parts = normalized.replaceAll('s', '').split('-');
    if (parts.length == 2) {
      final int? startParsed = int.tryParse(parts[0]);
      final int? endParsed = int.tryParse(parts[1]);
      if (startParsed != null && endParsed != null) {
        return _BeatSlot(label: 'Beat', start: startParsed, end: endParsed);
      }
    }
    return const _BeatSlot(label: 'Beat', start: 0, end: 0);
  }
}
