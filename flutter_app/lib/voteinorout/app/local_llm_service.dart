import 'dart:async';

import 'package:tflite_flutter/tflite_flutter.dart';

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

  /// Attempts to generate a script in JSON format. Returns `null` when the
  /// local model is unavailable or fails. The caller can then fall back to a
  /// procedural generator.
  static Future<String?> generateJsonScript({
    required String topic,
    required int length,
    required String style,
    List<String>? searchFacts,
  }) async {
    final Interpreter? interpreter = await _loadInterpreter();
    if (interpreter == null) {
      return null;
    }

    final String prompt = _buildPrompt(
    topic: topic,
    length: length,
    style: style,
    searchFacts: searchFacts ?? <String>[],  // Default empty
  );

    try {
      // The current version of `tflite_flutter` bundled with the app does not
      // expose the SignatureRunner helpers that make it easy to call into
      // generated model signatures. Until that support is wired up, we surface
      // a friendly message so callers can fall back to the remote or template
      // based generators without crashing the app.
      _lastError =
          'Local LLM generation is unavailable: signature runner support is missing in this build (prompt length ${prompt.length}).';
    } catch (e) {
      _lastError = e.toString();
    }

    return null;
  }

  /// Exposes the last interpreter error for logging/debug UIs.
  static String? get lastError => _lastError;

  static Future<List<String>> _fetchSearchFacts(String topic) async {
  // Comment out or return empty to disable (Streamlit basic mode doesn't use search)
  return <String>[];
  // If you want optional facts like Streamlit's enrichment, update queries to be neutral:
  // final List<String> queries = <String>{
  //   'Fun facts about $topic',
  //   'Recent news about $topic',
  //   'Statistics about $topic',
  // }.toList();
  // ... (rest of function)
}

  /// Releases interpreter resources. Useful for hot reload or when the app no
  /// longer needs the local model.
  static Future<void> dispose() async {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null;
    }
  }
}

static String _buildPrompt({
  required String topic,
  required int length,
  required String style,
  required List<String> searchFacts,
}) {
  final String styleFragment = (style.isEmpty || style == 'Other') ? 'any' : style.trim().toLowerCase();
  final StringBuffer buffer = StringBuffer()
    ..writeln('Generate a viral video script for "$topic" in $styleFragment style, ')
    ..writeln('length about $length seconds, using the Missy Elliott method to ensure hooks every 3 seconds.')
    ..writeln('Structure as timed beats: 0-3s: [hook], etc.')
    ..writeln('For each: voiceover, on-screen text (if any), visuals/actions.')
    ..writeln('End with a crisp CTA. Keep politically impactful and educational if relevant.');

  if (searchFacts.isNotEmpty) {
    buffer.writeln('\nOptionally paraphrase these facts:');
    for (final String fact in searchFacts) {
      buffer.writeln('- $fact');
    }
  }

  buffer.writeln('Respond with plain text (no JSON).');

  return buffer.toString();
}
