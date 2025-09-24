import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vioo_app/services/remote/script_generator.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ctaController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _lengthController =
      TextEditingController(text: '30');
  late final ScrollController _scriptScrollController;

  late TabController _tabController;
  String _style = 'Educational';
  bool _isSubmitting = false;
  String? _generatedScript;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scriptScrollController = ScrollController();
  }

  @override
  void dispose() {
    _ctaController.dispose();
    _topicController.dispose();
    _lengthController.dispose();
    _scriptScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateScript() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final String topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the payoff or topic.')),
      );
      return;
    }

    final int length = int.tryParse(_lengthController.text) ?? 30;
    final String selectedStyle =
        _style == 'Other' ? 'Unspecified' : _style.trim();
    final String cta = _ctaController.text.trim();

    setState(() {
      _isSubmitting = true;
      _generatedScript = null;
    });

    try {
      final String script = await ScriptGenerator.generateScript(
        topic,
        length,
        selectedStyle,
        cta: cta.isEmpty ? null : cta,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedScript = script.trim();
      });

      final String? warning = ScriptGenerator.lastRunWarning;
      if (warning != null && warning.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning)),
        );
      }

      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e. Check your connection or try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _copyScript(BuildContext context, String script) {
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Script copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('3-Second Hooks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'CONFIGURE'),
            Tab(text: 'SCRIPT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _topicController,
                      keyboardType: TextInputType.multiline,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'What’s the big idea?',
                        hintText:
                            'Share the key issue driving this campaign—whether it’s something personal, policy-focused, or a response to recent events.',
                      ),
                      validator: (String? value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please describe the payoff or topic.'
                              : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _ctaController,
                      decoration: const InputDecoration(
                        labelText: 'Final call to action (optional)',
                        hintText: 'Make a plan to vote at vote.org',
                      ),
                    ),
                    const SizedBox(height: 20),
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
                        return (parsed == null || parsed <= 0)
                            ? 'Enter a positive number.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _style,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                            value: 'Educational', child: Text('Educational')),
                        DropdownMenuItem(value: 'Motivational', child: Text('Motivational')),
                        DropdownMenuItem(value: 'Comedy', child: Text('Comedy')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Style (optional)',
                      ),
                      onChanged: (String? value) => setState(
                        () => _style = value ?? 'Educational',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _generateScript,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate script'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: _generatedScript == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Generate a script in the CONFIGURE tab to view it here.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Scrollbar(
                                controller: _scriptScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _scriptScrollController,
                                  primary: false,
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    _generatedScript!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _copyScript(context, _generatedScript!),
                          child: const Text('Copy script'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
