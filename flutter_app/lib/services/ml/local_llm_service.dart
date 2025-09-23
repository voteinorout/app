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
    _lastError = interpreter == null
        ? 'Local LLM model not bundled; using deterministic fallback script.'
        : 'Local LLM inference not implemented (prompt length ${prompt.length}); using deterministic fallback script.';

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
    final String styleFragment =
        (style.isEmpty || style == 'Other') ? 'any' : style.trim().toLowerCase();
    final StringBuffer buffer = StringBuffer()
      ..writeln('Generate a viral video script for "$topic" in $styleFragment style, ')
      ..writeln(
        'length about $length seconds, using the Missy Elliott method to ensure hooks every 3 seconds.',
      )
      ..writeln('Structure as timed beats: 0-3s: [hook], 3-6s: [next beat], etc.')
      ..writeln('For each beat, include: voiceover, on-screen text (if any), visuals/actions.')
      ..writeln('End with a crisp CTA that fits the topic (e.g., learn more, try it out). Keep it engaging and relevant to the audience.');

    if (searchFacts.isNotEmpty) {
      buffer.writeln('\nOptionally paraphrase these facts:');
      for (final String fact in searchFacts) {
        buffer.writeln('- $fact');
      }
    }

    buffer.writeln('Respond with plain text (no JSON, no extra notes).');

    return buffer.toString();
  }

  static String _generateFallbackScript({
    required String topic,
    required int length,
    required String style,
    required List<String> searchFacts,
  }) {
    final int segmentCount = max(1, (length / 3).ceil());
    final String normalizedStyle = style.trim().isEmpty ? 'Any' : style.trim();
    final Map<String, String> toneDescriptors = <String, String>{
      'Motivational': 'energized and inspiring',
      'Educational': 'clear and informative',
      'Comedy': 'playful and funny',
      'Exciting': 'high-energy and thrilling',
      'Relaxed': 'calm and easygoing',
      'Creative': 'imaginative and unique',
    };
    final String tone =
        toneDescriptors[normalizedStyle] ?? 'attention-holding and direct';

    final List<Map<String, dynamic>> segments = <Map<String, dynamic>>[];
    final List<String> facts =
        searchFacts.where((String fact) => fact.trim().isNotEmpty).toList();

    for (int i = 0; i < segmentCount; i++) {
      final int start = i * 3;
      final bool isFirst = i == 0;
      final bool isLast = i == segmentCount - 1;
      final String factLine =
          i < facts.length ? facts[i] : 'Share something useful about $topic.';

      final String voiceover;
      if (isFirst) {
        voiceover = 'Hook ($tone): $factLine';
      } else if (isLast) {
        voiceover =
            'Close ($tone): wrap up $topic with a clear takeaway or reason to stay curious.';
      } else {
        voiceover = 'Beat ${i + 1} ($tone): $factLine';
      }

      final String onScreen = isFirst
          ? 'HOOK • ${topic.toUpperCase()}'
          : isLast
              ? 'Next steps • $topic'
              : 'Beat ${i + 1} • $topic';

      final String visuals = isFirst
          ? 'Bold typography, punchy imagery introducing $topic.'
          : isLast
              ? 'Close-up shots, call-to-action card, topic visuals.'
              : 'B-roll supporting $topic with captions for key phrases.';

      segments.add(<String, dynamic>{
        'startTime': start,
        'voiceover': voiceover,
        'onScreenText': onScreen,
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
    if (cta != null && cta.trim().isNotEmpty && segments.isNotEmpty) {
      final ScriptSegment last = segments.last;
      segments[segments.length - 1] = ScriptSegment(
        startTime: last.startTime,
        voiceover: '${last.voiceover}\nCTA: ${cta.trim()}',
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
