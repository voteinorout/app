import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Provides on-device speech transcription for Vote In Or Out.
///
/// The service wraps the `speech_to_text` plugin so we can reuse the native
/// Apple Speech (iOS) and SpeechRecognizer (Android) implementations. The
/// plugin works offline on supported devices as long as the on-device language
/// pack is installed.
class TranscriptionService {
  TranscriptionService._();

  static final SpeechToText _speechToText = SpeechToText();
  static bool _initialized = false;
  static bool _hasPermission = false;
  static String? _lastError;

  /// Requests microphone permissions (required by the underlying recognizers)
  /// and prepares the speech engine. Returns `true` when everything is ready.
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

  /// Performs a best-effort transcription of the audio stored at [audioPath].
  ///
  /// The `speech_to_text` plugin currently expects live audio input from the
  /// device microphone. To keep the workflow offline, we initialise the engine
  /// in dictation mode and rely on the platform speech stack to listen while
  /// the audio file is played back locally (e.g. through a speaker or by
  /// streaming the bytes via a custom audio player). `_feedAudioFileToRecognizer`
  /// handles playback using `just_audio` so the recognizer hears the audio in
  /// real time.
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

    // The recognizer emits streaming results; we collect them and resolve once
    // a final result arrives or the listening session times out.
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

    // Ensure we are not carrying over a previous session.
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final String? localeId =
        await _speechToText.systemLocale().then((value) => value?.localeId);

    final bool started = await _speechToText.listen(
      onResult: onResult,
      listenMode: ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      localeId: localeId,
      onDevice: true, // Favors offline, on-device recognition when available.
    );

    if (!started) {
      await _speechToText.stop();
      throw StateError(
        _lastError ??
            'Unable to start the speech recognizer for the provided audio file.',
      );
    }

    // TODO: replace this stub with actual audio playback wired into the
    // recognizer. For now we simply delay so the engine has time to listen.
    await _feedAudioFileToRecognizer(audioFile);

    // Stop the session if it is still running after the playback delay.
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    if (!completer.isCompleted) {
      completer.complete(partials.join(' ').trim());
    }

    return completer.future;
  }

  /// Starts a live dictation session using the device microphone and returns
  /// the captured transcript once the recognizer reports a final result or the
  /// provided window elapses.
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

    final bool started = await _speechToText.listen(
      onResult: onResult,
      listenMode: ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 2),
      listenFor: listenFor,
      localeId: localeId,
      onDevice: true,
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

  /// Clears the recognizer state. Call this when the surrounding widget is
  /// disposed or when you no longer need speech services.
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
    // Keep the last status string available for debugging. Could be surfaced
    // via a getter if the UI needs to react to status updates.
  }
}
