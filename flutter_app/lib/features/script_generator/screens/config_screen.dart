import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vioo_app/features/script_generator/models/generated_script.dart';
import 'package:vioo_app/features/script_generator/services/local/script_storage.dart';
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

  static const Map<String, int> _styleTemperatureDefaults = <String, int>{
    'Educational': 4,
    'Motivational': 6,
    'Comedy': 8,
  };

  late TabController _tabController;
  String _style = 'Educational';
  int _temperature = _styleTemperatureDefaults['Educational']!;
  bool _isSubmitting = false;
  String? _generatedScript;
  bool _usedHostedGenerator = true;
  final Set<String> _selectedScriptIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final String selectedStyle = _style;
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
        temperature: _temperature,
      );

      final String cleanedScript = script.trim();
      final bool usedHosted = ScriptGenerator.lastRunUsedHosted;
      bool saveFailed = false;

      try {
        await ScriptStorage.saveScript(
          topic: topic,
          style: selectedStyle,
          content: cleanedScript,
          usedHostedGenerator: usedHosted,
          cta: cta.isEmpty ? null : cta,
          temperature: _temperature,
          length: length,
        );
      } on Object catch (error, stackTrace) {
        saveFailed = true;
        debugPrint('Failed to persist script locally: $error');
        debugPrintStack(label: 'ScriptStorage failure', stackTrace: stackTrace);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedScript = cleanedScript;
        _usedHostedGenerator = usedHosted;
      });

      if (saveFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved copy unavailable. Script will remain until you leave this screen.',
            ),
          ),
        );
      }

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

  void _loadSavedScript(GeneratedScript script) {
    FocusScope.of(context).unfocus();
    final bool styleSupported = _styleTemperatureDefaults.containsKey(
      script.style,
    );
    final String resolvedStyle = styleSupported ? script.style : 'Educational';
    final int resolvedTemperature =
        script.temperature ??
        (_styleTemperatureDefaults[resolvedStyle] ??
            _styleTemperatureDefaults['Educational']!);

    _topicController.text = script.topic;
    _ctaController.text = script.cta ?? '';

    setState(() {
      _style = resolvedStyle;
      _temperature = resolvedTemperature;
      _generatedScript = script.content;
      _usedHostedGenerator = script.usedHostedGenerator;
      _selectedScriptIds.clear();
    });

    _tabController.animateTo(1);
  }

  void _handleScriptTap(GeneratedScript script) {
    _loadSavedScript(script);
  }

  void _toggleScriptSelection(String id, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedScriptIds.add(id);
      } else {
        _selectedScriptIds.remove(id);
      }
    });
  }

  Future<void> _confirmDeleteAllScripts(int total) async {
    if (total == 0) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Delete all saved scripts?'),
              content: Text(
                'Are you sure you would like to delete all $total saved scripts? Click here to continue.',
                style: theme.textTheme.bodyMedium,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete all'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await ScriptStorage.deleteAll();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedScriptIds.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All saved scripts deleted')));
  }

  Future<void> _confirmDeleteSelectedScripts(int count) async {
    if (count == 0) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            return AlertDialog(
              title: Text('Delete $count selected?'),
              content: Text(
                'This will remove $count saved script${count == 1 ? '' : 's'}.',
                style: theme.textTheme.bodyMedium,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final List<String> idsToDelete = List<String>.from(_selectedScriptIds);
    await ScriptStorage.deleteScripts(idsToDelete);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedScriptIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1 ? 'Deleted 1 script' : 'Deleted $count scripts',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSingleScript(GeneratedScript script) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Delete script?'),
              content: Text(
                'This removes the saved script from this device.',
                style: theme.textTheme.bodyMedium,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await ScriptStorage.deleteScript(script.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedScriptIds.remove(script.id);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Script deleted')));
  }

  void _handleCopyScript(GeneratedScript script) {
    Clipboard.setData(ClipboardData(text: script.content));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Script copied to clipboard')));
  }

  void _showScriptActionSheet(GeneratedScript script) {
    final BuildContext rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text('Copy script'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleCopyScript(script);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete script'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!rootContext.mounted) {
                    return;
                  }
                  _confirmDeleteSingleScript(script);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionBar(ThemeData theme) {
    final int count = _selectedScriptIds.length;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: () => _confirmDeleteSelectedScripts(count),
          child: Text(
            count == 1 ? 'Delete 1 selected' : 'Delete $count selected',
          ),
        ),
      ),
    );
  }

  String _truncateScript(String content) {
    String _stripPrefixes(String value) {
      String working = value.trim();
      final RegExp prefixPattern = RegExp(
        r'^(?:hook[^:]*:|voiceover:|visuals:?|final cta:?|cta:?|beat\s+\d+:|key beat[^:]*:)',
        caseSensitive: false,
      );
      while (true) {
        final RegExpMatch? match = prefixPattern.firstMatch(working);
        if (match == null || match.start != 0) {
          break;
        }
        working = working.substring(match.end).trim();
      }
      if (working.startsWith('>')) {
        return '';
      }
      return working;
    }

    final List<String> lines = content.split('\n');
    String? firstSentence;

    for (final String rawLine in lines) {
      final String trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String stripped = _stripPrefixes(trimmed);
      if (stripped.isEmpty) {
        continue;
      }
      firstSentence = stripped;
      break;
    }

    final String normalized = (firstSentence ?? content)
        .replaceAll(RegExp(r'[\*_#>`~-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return 'Untitled script';
    }
    const int maxWords = 14;
    final List<String> words = normalized.split(' ');
    if (words.length <= maxWords) {
      return normalized;
    }
    return '${words.take(maxWords).join(' ')}…';
  }

  String _formatSavedDate(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String year = local.year.toString();
    return '$month/$day/$year';
  }

  Widget _buildSavedScriptCard(
    GeneratedScript script,
    bool isSelected,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        minVerticalPadding: 8,
        horizontalTitleGap: 12,
        leading: Checkbox(
          value: isSelected,
          onChanged: (bool? value) =>
              _toggleScriptSelection(script.id, value ?? false),
        ),
        title: Text(
          _truncateScript(script.content),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Saved ${_formatSavedDate(script.createdAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showScriptActionSheet(script),
        ),
        onTap: () => _handleScriptTap(script),
      ),
    );
  }

  Widget _buildSavedTab(ThemeData theme) {
    return SafeArea(
      child: ValueListenableBuilder<Box<GeneratedScript>>(
        valueListenable: ScriptStorage.listenable(),
        builder: (BuildContext context, Box<GeneratedScript> _, __) {
          final List<GeneratedScript> scripts = ScriptStorage.getScripts();
          final Set<String> validIds = scripts
              .map((GeneratedScript script) => script.id)
              .toSet();

          if (_selectedScriptIds.any((String id) => !validIds.contains(id))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _selectedScriptIds.removeWhere(
                  (String id) => !validIds.contains(id),
                );
              });
            });
          }

          final int total = scripts.length;

          final Widget listContent = scripts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Scripts you generate will appear here. Create one from the CONFIGURE tab to get started.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    _selectedScriptIds.isNotEmpty ? 96 : 20,
                  ),
                  itemCount: scripts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final GeneratedScript script = scripts[index];
                    final bool isSelected = _selectedScriptIds.contains(
                      script.id,
                    );
                    return _buildSavedScriptCard(script, isSelected, theme);
                  },
                );

          return Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '$total saved script${total == 1 ? '' : 's'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: total == 0
                              ? null
                              : () => _confirmDeleteAllScripts(total),
                          child: const Text('Delete all'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: listContent),
                ],
              ),
              if (_selectedScriptIds.isNotEmpty) _buildSelectionBar(theme),
            ],
          );
        },
      ),
    );
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
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return theme.colorScheme.onPrimary.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.pressed)) {
              return theme.colorScheme.onPrimary.withValues(alpha: 0.16);
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
            Tab(text: 'SAVED'),
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
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Style',
                              ),
                              child: DropdownButton<String>(
                                value: _style,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
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
                                ],
                                onChanged: _isSubmitting
                                    ? null
                                    : (String? value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _style = value;
                                          _temperature =
                                              _styleTemperatureDefaults[value]!;
                                        });
                                      },
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
                                        setState(() {
                                          _style = 'Educational';
                                          _temperature =
                                              _styleTemperatureDefaults['Educational']!;
                                        });
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.8),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Text(
                                        'AI can hallucinate—always check facts before sharing.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      MarkdownBody(
                                        data: _generatedScript!,
                                        selectable: true,
                                        styleSheet:
                                            MarkdownStyleSheet.fromTheme(
                                              theme,
                                            ).copyWith(
                                              p: theme.textTheme.bodyMedium!
                                                  .copyWith(height: 1.4),
                                              strong: theme
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                              blockquote: theme
                                                  .textTheme
                                                  .bodySmall!
                                                  .copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                    height: 1.4,
                                                  ),
                                              blockquotePadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ).copyWith(top: 4, bottom: 2),
                                              blockquoteDecoration:
                                                  BoxDecoration(
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                      ),
                                    ],
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
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
          _buildSavedTab(theme),
        ],
      ),
    );
  }
}
