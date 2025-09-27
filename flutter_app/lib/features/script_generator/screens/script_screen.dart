import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ScriptScreen extends StatefulWidget {
  const ScriptScreen({super.key});

  @override
  State<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends State<ScriptScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{})
            as Map<String, dynamic>;

    final String script = (args['script'] as String?)?.trim() ?? '';
    final String topic = args['topic'] as String? ?? 'Topic';
    final String style = args['style'] as String? ?? 'Any';
    final bool usedHosted = args['usedHosted'] as bool? ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Viral Script Generator')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              topic,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Style: $style • Format: Hook → Final CTA (30s)',
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: theme.colorScheme.surface.withValues(alpha: 0.35),
                  child: script.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Generate a script from the CONFIGURE tab to preview it here.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            primary: false,
                            padding: const EdgeInsets.all(16),
                            child: MarkdownBody(
                              data: script,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                  .copyWith(
                                    h1: theme.textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    h2: theme.textTheme.titleSmall!.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    p: theme.textTheme.bodyMedium!.copyWith(
                                      height: 1.4,
                                    ),
                                    listBullet: theme.textTheme.bodyMedium!
                                        .copyWith(fontWeight: FontWeight.w600),
                                    strong: theme.textTheme.bodyMedium!
                                        .copyWith(fontWeight: FontWeight.w700),
                                    blockquote: theme.textTheme.bodySmall!
                                        .copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                          height: 1.4,
                                        ),
                                    blockquotePadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ).copyWith(top: 4, bottom: 4),
                                    blockquoteDecoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: theme.colorScheme.onSurface
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: script.isEmpty
                    ? null
                    : () => _copyToClipboard(context, script),
                child: const Text('Copy script'),
              ),
            ),
            if (!usedHosted) ...<Widget>[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Fallback script',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String script) {
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Script copied to clipboard')));
  }
}
