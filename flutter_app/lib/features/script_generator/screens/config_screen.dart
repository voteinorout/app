import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vioo_app/features/script_generator/services/remote/script_generator.dart';

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
  late final ScrollController _scriptScrollController;

  late TabController _tabController;
  String _style = 'Educational';
  bool _isSubmitting = false;
  String? _generatedScript;
  bool _usedHostedGenerator = true;

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

    const int length = 30;
    final String selectedStyle = _style == 'Other'
        ? 'Unspecified'
        : _style.trim();
    final String cta = _ctaController.text.trim();

    setState(() {
      _isSubmitting = true;
      _generatedScript = null;
      _usedHostedGenerator = true;
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
        _usedHostedGenerator = ScriptGenerator.lastRunUsedHosted;
      });

      final String? warning = ScriptGenerator.lastRunWarning;
      if (warning != null && warning.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning)));
      }

      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generation failed: $e. Check your connection or try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _copyScript(BuildContext context, String script) {
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Script copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ButtonStyle? primaryButtonStyle = theme.elevatedButtonTheme.style
        ?.copyWith(
          overlayColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.hovered) ||
                states.contains(MaterialState.focused)) {
              return theme.colorScheme.onPrimary.withOpacity(0.10);
            }
            if (states.contains(MaterialState.pressed)) {
              return theme.colorScheme.onPrimary.withOpacity(0.16);
            }
            return null;
          }),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viral Script Generator'),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'This tool turns key facts into viral scripts for any cause. Just gather 5–7 powerful stats, quotes, or insights tied to trends, impact, or common myths.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _topicController,
                              keyboardType: TextInputType.multiline,
                              minLines: 6,
                              maxLines: 10,
                              style: theme.textTheme.bodyMedium,
                              decoration: const InputDecoration(
                                labelText: 'Your big idea or topic',
                                hintText: 'Write or paste here',
                              ),
                              validator: (String? value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'Please describe the payoff or topic.'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _ctaController,
                              keyboardType: TextInputType.multiline,
                              minLines: 2,
                              maxLines: 5,
                              style: theme.textTheme.bodyMedium,
                              decoration: const InputDecoration(
                                labelText: 'Final call to action (optional)',
                                hintText:
                                    'e.g. Make a plan to vote at vote.org',
                              ),
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              initialValue: _style,
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'Educational',
                                  child: Text('Educational'),
                                ),
                                DropdownMenuItem(
                                  value: 'Motivational',
                                  child: Text('Motivational'),
                                ),
                                DropdownMenuItem(
                                  value: 'Comedy',
                                  child: Text('Comedy'),
                                ),
                                DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('Other'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Style (optional)',
                              ),
                              style: theme.textTheme.bodyMedium,
                              onChanged: (String? value) => setState(
                                () => _style = value ?? 'Educational',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        _topicController.clear();
                                        _ctaController.clear();
                                        setState(() => _style = 'Educational');
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: theme.colorScheme.primary
                                      .withOpacity(0.8),
                                ),
                                child: const Text('Reset form'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: primaryButtonStyle,
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
                        Text(
                          'AI can hallucinate—always check the facts before sharing.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.35,
                              ),
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
                                  child: MarkdownBody(
                                    data: _generatedScript!,
                                    selectable: true,
                                    styleSheet:
                                        MarkdownStyleSheet.fromTheme(
                                          theme,
                                        ).copyWith(
                                          p: theme.textTheme.bodyMedium!
                                              .copyWith(height: 1.4),
                                          strong: theme.textTheme.bodyMedium!
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                          blockquote: theme.textTheme.bodySmall!
                                              .copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                                height: 1.4,
                                              ),
                                          blockquotePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ).copyWith(top: 4, bottom: 2),
                                          blockquoteDecoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.12),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_usedHostedGenerator) ...<Widget>[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Fallback script',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: primaryButtonStyle,
                          onPressed: () =>
                              _copyScript(context, _generatedScript!),
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
