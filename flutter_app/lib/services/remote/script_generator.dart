import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/services/ml/local_llm_service.dart';
import 'package:vioo_app/services/openai_service.dart';

class ScriptGenerator {
  static const int _fallbackBeatDurationSeconds = 6;

  static bool _lastRunUsedHosted = false;
  static String? _lastRunWarning;

  static bool get lastRunUsedHosted => _lastRunUsedHosted;

  static String? get lastRunWarning => _lastRunWarning;

  static Future<String> generateScript(
    String topic,
    int length,
    String style, {
    String? cta,
  }) async {
    _lastRunWarning = null;
    final String trimmedCta = (cta ?? '').trim();

    final String? remoteScript = await OpenAIService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
      cta: trimmedCta.isEmpty ? null : trimmedCta,
    );

    if (remoteScript != null && remoteScript.trim().isNotEmpty) {
      _lastRunUsedHosted = true;
      return _formatBeats(remoteScript.trim());
    }

    _lastRunUsedHosted = false;
    if (kDebugMode) {
      debugPrint('Remote script proxy unavailable; using on-device fallback generator.');
    }

    // Local fallback retains legacy JSON format which we convert to readable text.
    final List<ScriptSegment> localSegments =
        await LocalLlmService.generateFallbackSegments(
      topic: topic,
      length: length,
      style: style,
      cta: trimmedCta.isEmpty ? null : trimmedCta,
    );

    if (localSegments.isEmpty) {
      _lastRunWarning = 'Script generator fallback returned no segments.';
      return _formatBeats(
        'Unable to generate a script right now. Try again with a different prompt.',
      );
    }

    final StringBuffer buffer = StringBuffer();
    for (final ScriptSegment segment in localSegments) {
      final int end = min(length, segment.startTime + _fallbackBeatDurationSeconds);
      final String labelSuffix =
          segment.onScreenText.isNotEmpty ? ' ${segment.onScreenText}' : '';
      buffer.writeln('${segment.startTime}-$end s:$labelSuffix');
      buffer.writeln('Voiceover: ${segment.voiceover}');
      if (segment.visualsActions.isNotEmpty) {
        buffer.writeln('Visuals: ${segment.visualsActions}');
      }
      buffer.writeln();
    }
    if (trimmedCta.isNotEmpty) {
      buffer.writeln('Call to Action: $trimmedCta');
    }

    _lastRunWarning =
        LocalLlmService.lastError ?? 'Hosted script generation failed; using deterministic fallback.';
    return _formatBeats(buffer.toString().trim());
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
      final int expectedSegments = max(1, (length / _fallbackBeatDurationSeconds).ceil());

      final List<ScriptSegment> scriptSegments = <ScriptSegment>[];

      for (int i = 0; i < typedSegments.length; i++) {
        final Map<String, dynamic> segment = typedSegments[i];
        final int startTime =
            _coerceStartTime(segment['startTime'], i * _fallbackBeatDurationSeconds);
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

  @visibleForTesting
  static List<ScriptSegment> parseSegmentsForTest(String rawContent, int length) =>
      _parseSegments(rawContent, length);

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
    final RegExp timeHeader =
        RegExp(r'^(\s*)(\d+\s*-\s*\d+\s*(?:s|sec|seconds)?)\s*:(.*)');
    final List<String> lines = script.split('\n');
    final List<String> formatted = <String>[];
    for (final String line in lines) {
      final String trimmed = line.trimLeft();
      if (trimmed.startsWith('**')) {
        formatted.add(line);
        continue;
      }
      final Match? match = timeHeader.firstMatch(line);
      if (match != null) {
        final String prefix = match.group(1) ?? '';
        final String range = match.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        final String rest = match.group(3)?.trimLeft() ?? '';
        final String suffix = rest.isEmpty ? '' : ' $rest';
        formatted.add('$prefix**$range:**$suffix');
      } else {
        formatted.add(line);
      }
    }
    return formatted.join('\n');
  }
}
