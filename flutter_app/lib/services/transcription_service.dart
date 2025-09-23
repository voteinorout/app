import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TranscriptionService {
  TranscriptionService._();

  static final SpeechToText _speechToText = SpeechToText();
  static bool _initialized = false;
  static bool _hasPermission = false;
  static String? _lastError;

  static Future<bool> init() async {
    if (_initialized) {
      return _hasPermission;
    }

    try {
      _hasPermission = await _speechToText.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: false,
      );
    } on Exception catch (e) {
      _lastError = e.toString();
      _hasPermission = false;
    }

    _initialized = true;
    return _hasPermission;
  }

  static Future<String> transcribeAudio(String audioPath) async {
    final bool ready = await init();
    if (!ready) {
      throw StateError(
        'Speech recognition is unavailable. Permission denied or engine init failed.',
      );
    }

    final File audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw ArgumentError('Audio file not found at $audioPath');
    }

    final Completer<String> completer = Completer<String>();
    final List<String> partials = <String>[];

    void onResult(SpeechRecognitionResult result) {
      if (result.recognizedWords.isNotEmpty) {
        partials.add(result.recognizedWords);
      }
      if (result.finalResult && !completer.isCompleted) {
        completer.complete(partials.join(' ').trim());
      }
    }

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final String? localeId =
        await _speechToText.systemLocale().then((value) => value?.localeId);

    final SpeechListenOptions listenOptions = SpeechListenOptions(
      listenMode: ListenMode.dictation,
      partialResults: true,
      onDevice: true,
    );

    final bool started = await _speechToText.listen(
      onResult: onResult,
      listenOptions: listenOptions,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      localeId: localeId,
    );

    if (!started) {
      await _speechToText.stop();
      throw StateError(
        _lastError ??
            'Unable to start the speech recognizer for the provided audio file.',
      );
    }

    await _feedAudioFileToRecognizer(audioFile);

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    if (!completer.isCompleted) {
      completer.complete(partials.join(' ').trim());
    }

    return completer.future;
  }

  static Future<String> transcribeFromMic({
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    final bool ready = await init();
    if (!ready) {
      throw StateError(
        'Speech recognition is unavailable. Permission denied or engine init failed.',
      );
    }

    final Completer<String> completer = Completer<String>();
    final List<String> partials = <String>[];

    void onResult(SpeechRecognitionResult result) {
      if (result.recognizedWords.isNotEmpty) {
        partials.add(result.recognizedWords);
      }
      if (result.finalResult && !completer.isCompleted) {
        completer.complete(partials.join(' ').trim());
      }
    }

    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final String? localeId = await _speechToText.systemLocale().then((value) => value?.localeId);

    final SpeechListenOptions listenOptions = SpeechListenOptions(
      listenMode: ListenMode.dictation,
      partialResults: true,
      onDevice: true,
    );

    final bool started = await _speechToText.listen(
      onResult: onResult,
      listenOptions: listenOptions,
      pauseFor: const Duration(seconds: 2),
      listenFor: listenFor,
      localeId: localeId,
    );

    if (!started) {
      await _speechToText.stop();
      throw StateError(
        _lastError ?? 'Unable to start the speech recognizer for microphone input.',
      );
    }

    try {
      final Duration timeoutWindow = listenFor + const Duration(seconds: 5);
      final String transcript = await completer.future.timeout(
        timeoutWindow,
        onTimeout: () => partials.join(' ').trim(),
      );
      return transcript;
    } finally {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    }
  }

  static Future<void> dispose() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _initialized = false;
    _hasPermission = false;
  }

  static Future<void> _feedAudioFileToRecognizer(File audioFile) async {
    final AudioPlayer player = AudioPlayer();
    try {
      await player.setFilePath(audioFile.path);
      await player.play();
      await player.processingStateStream.firstWhere(
        (ProcessingState state) =>
            state == ProcessingState.completed || state == ProcessingState.idle,
      );
    } on PlayerException catch (e) {
      _lastError = 'Audio playback failed: ${e.message}';
      rethrow;
    } on PlayerInterruptedException catch (e) {
      _lastError = 'Audio playback interrupted: ${e.message}';
      rethrow;
    } finally {
      await player.stop();
      await player.dispose();
    }
  }

  static void _handleError(SpeechRecognitionError error) {
    _lastError = '${error.errorMsg} (${error.permanent})';
  }

  static void _handleStatus(String status) {
    // Status available for debugging if needed.
  }
}
