import 'package:flutter/material.dart';
import 'package:vioo_app/voteinorout/app/transcription_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ctaController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController(text: '30');
  final TextEditingController _audioPathController = TextEditingController();

  String _style = 'Educational';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _ctaController.dispose();
    _topicController.dispose();
    _lengthController.dispose();
    _audioPathController.dispose();
    super.dispose();
  }

  Future<void> _generateScript() async {
    if (_isSubmitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final String audioPath = _audioPathController.text.trim();

    if (!mounted) {
      return;
    }

    final Map<String, dynamic> args = <String, dynamic>{
      'cta': _ctaController.text.trim().isEmpty ? null : _ctaController.text.trim(),
      'topic': _topicController.text.trim(),
      'length': int.tryParse(_lengthController.text) ?? 30,
      'style': _style,
    };

    if (audioPath.isNotEmpty) {
      try {
        final String transcribedText =
            await TranscriptionService.transcribeAudio(audioPath);
        if (transcribedText.isNotEmpty) {
          args['topic'] = transcribedText;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcription failed: $e')),
          );
        }
      }
    }

    setState(() => _isSubmitting = false);
    Navigator.of(context).pushNamed('/script', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF1E2A44);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _ctaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Video call-to-action',
                    hintText: 'e.g. Sign up at example.com',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Describe the payoff or main topic',
                    hintText: 'What is the main takeaway?',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe the payoff or topic.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Length (seconds)',
                    hintText: '30',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final int? parsed = int.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _audioPathController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Audio file path (optional)',
                    hintText: 'e.g., /path/to/audio.mp3',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optional: point to a local clip (e.g., a sample WAV/MP3 or mic capture) to auto-transcribe the topic using on-device speech.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _style,
                  dropdownColor: bgColor,
                  decoration: const InputDecoration(
                    labelText: 'Style',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'Educational', child: Text('Educational')),
                    DropdownMenuItem(value: 'Entertaining', child: Text('Entertaining')),
                    DropdownMenuItem(value: 'Missy Elliott', child: Text('Missy Elliott')),
                  ],
                  onChanged: (String? value) => setState(() => _style = value ?? 'Educational'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _generateScript,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Generate script'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
