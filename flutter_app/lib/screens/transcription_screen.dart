import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vioo_app/voteinorout/app/transcription_service.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final TextEditingController _pathController = TextEditingController();
  bool _isProcessing = false;
  bool _micActive = false;
  String? _transcript;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final bool ready = await TranscriptionService.init();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _error =
            'Microphone permission is required for live transcription. Enable it in Settings to capture audio from the mic.';
      });
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    unawaited(TranscriptionService.dispose());
    super.dispose();
  }

  Future<void> _transcribeAudioFile() async {
    final String path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _error = 'Provide a local audio file path to transcribe.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _transcript = null;
      _error = null;
    });

    try {
      final String text = await TranscriptionService.transcribeAudio(path);
      setState(() {
        _transcript = text.isEmpty ? '(No speech detected)' : text;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _transcribeFromMic() async {
    if (_micActive) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _micActive = true;
      _transcript = null;
      _error = null;
    });

    try {
      final String text = await TranscriptionService.transcribeFromMic(
        listenFor: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _transcript = text.isEmpty ? '(No speech detected)' : text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _micActive = false;
        });
      }
    }
  }

  Future<void> _cancelMicSession() async {
    if (!_micActive) {
      return;
    }
    // Currently the service stops listening automatically once the future
    // resolves. For manual cancellation we dispose and re-initialise.
    await TranscriptionService.dispose();
    await _initializeSpeech();
    setState(() {
      _micActive = false;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Transcription (Beta)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Local transcription runs on-device using Apple Speech (iOS) or SpeechRecognizer (Android). '
                'Provide an audio file path or capture a quick mic sample to test the pipeline.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  labelText: 'Audio file path',
                  hintText: '/path/to/sample.wav',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: drop a short WAV/MP3 into storage or bundle test clips as assets, then point to the absolute path here.',
                style: theme.textTheme.bodySmall!
                    .copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _transcribeAudioFile,
                icon: const Icon(Icons.audiotrack),
                label: const Text('Transcribe audio file'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _transcribeFromMic,
                icon: Icon(_micActive ? Icons.mic : Icons.mic_none),
                label: Text(_micActive ? 'Listening…' : 'Capture via microphone'),
              ),
              if (_micActive) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _cancelMicSession,
                  child: const Text('Cancel listening'),
                ),
              ],
              const SizedBox(height: 24),
              if (_isProcessing) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_transcript != null) ...[
                Text(
                  'Transcript',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _transcript!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
