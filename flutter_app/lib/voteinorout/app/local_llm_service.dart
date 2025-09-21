import 'dart:async';
import 'dart:convert';

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
  }) async {
    final Interpreter? interpreter = await _loadInterpreter();
    if (interpreter == null) {
      return null;
    }

    final String prompt = _buildPrompt(topic: topic, length: length, style: style);

    try {
      final SignatureRunner? runner = interpreter.getSignatureRunner('generate');
      if (runner == null) {
        return null;
      }

      final Map<String, Object?> outputs = runner.run(<String, Object?>{
        'prompt': prompt,
        'max_tokens': 256,
      });

      final Object? rawText = outputs['text'] ?? outputs.values.firstOrNull;
      if (rawText is String && rawText.trim().isNotEmpty) {
        return rawText;
      }

      if (rawText is List && rawText.isNotEmpty) {
        // Some models return UTF-8 bytes. Attempt to decode a single buffer.
        final Object? first = rawText.first;
        if (first is List<int>) {
          return utf8.decode(first, allowMalformed: true);
        }
        if (first is int) {
          return utf8.decode(rawText.cast<int>(), allowMalformed: true);
        }
      }
    } catch (e) {
      _lastError = e.toString();
      return null;
    }

    return null;
  }

  /// Exposes the last interpreter error for logging/debug UIs.
  static String? get lastError => _lastError;

  static String _buildPrompt({
    required String topic,
    required int length,
    required String style,
  }) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('You are a local creative director LLM for voter engagement.')
      ..writeln('Create a $style short-form script about "$topic".')
      ..writeln('The video should run for roughly $length seconds and contain hooks every 3 seconds.')
      ..writeln('Respond with JSON using the schema { "segments": [ { "startTime": number, "voiceover": string, "onScreenText": string, "visualsActions": string } ] }.');

    return buffer.toString();
  }

  /// Releases interpreter resources. Useful for hot reload or when the app no
  /// longer needs the local model.
  static Future<void> dispose() async {
    if (_interpreter != null) {
      await _interpreter?.close();
      _interpreter = null;
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
