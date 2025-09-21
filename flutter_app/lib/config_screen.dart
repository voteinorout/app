import 'package:flutter/material.dart';
import 'package:vioo_app/voteinorout/app/transcription_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

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

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed('/script', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle helperStyle = theme.textTheme.bodySmall!
        .copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65));

    return Scaffold(
      appBar: AppBar(
        title: const Text('3-Second Hooks'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Describe your message and we'll generate tight 3-second beats ready for video.",
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _ctaController,
                  decoration: const InputDecoration(
                    labelText: 'Video call-to-action',
                    hintText: 'e.g. Sign up at example.com',
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'Describe the payoff or main topic',
                    hintText: 'What should the viewer take away?',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe the payoff or topic.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Length (seconds)',
                    hintText: '30',
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
                const SizedBox(height: 18),
                TextFormField(
                  controller: _audioPathController,
                  decoration: const InputDecoration(
                    labelText: 'Audio file path (optional)',
                    hintText: 'e.g., /path/to/audio.mp3',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Point to a local clip to auto-transcribe the topic with on-device speech.',
                  style: helperStyle,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _style,
                  items: const [
                    DropdownMenuItem(value: 'Educational', child: Text('Educational')),
                    DropdownMenuItem(value: 'Entertaining', child: Text('Entertaining')),
                    DropdownMenuItem(value: 'Missy Elliott', child: Text('Missy Elliott')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Style (optional)',
                  ),
                  dropdownColor: Colors.white,
                  onChanged: (String? value) =>
                      setState(() => _style = value ?? 'Educational'),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _generateScript,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate script'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
