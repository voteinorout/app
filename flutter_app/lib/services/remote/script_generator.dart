import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/services/ml/local_llm_service.dart';
import 'package:vioo_app/services/openai_service.dart';

class ScriptGenerator {
  static Future<String> generateScript(
    String topic,
    int length,
    String style, {
    String? cta,
  }) async {
    final String trimmedCta = (cta ?? '').trim();

    final String? remoteScript = await OpenAIService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
      cta: trimmedCta.isEmpty ? null : trimmedCta,
    );

    if (remoteScript != null && remoteScript.trim().isNotEmpty) {
      return remoteScript.trim();
    }

    // Local fallback retains legacy JSON format which we convert to readable text.
    final String? localJson = await LocalLlmService.generateJsonScript(
      topic: topic,
      length: length,
      style: style,
      searchFacts: const <String>[],
      cta: trimmedCta.isEmpty ? null : trimmedCta,
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
        if (trimmedCta.isNotEmpty) {
          buffer.writeln('Call to Action: $trimmedCta');
        }
        return buffer.toString().trim();
      }
    }

    return 'Unable to generate a script right now. Try again with a different prompt.';
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

}
