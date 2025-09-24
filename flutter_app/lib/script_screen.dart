import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ScriptScreen extends StatelessWidget {
  const ScriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{})
            as Map<String, dynamic>;

    final String script = (args['script'] as String?)?.trim() ?? '';
    final String topic = args['topic'] as String? ?? 'Topic';
    final int length = args['length'] as int? ?? 30;
    final String style = args['style'] as String? ?? 'Any';

    return Scaffold(
      appBar: AppBar(title: const Text('3-Second Hooks')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              topic,
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Style: $style • Length: ${length}s',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: MarkdownBody(
                              data: script,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                h1: theme.textTheme.titleMedium!
                                    .copyWith(fontWeight: FontWeight.w700),
                                h2: theme.textTheme.titleSmall!
                                    .copyWith(fontWeight: FontWeight.w700),
                                p: theme.textTheme.bodyMedium!
                                    .copyWith(height: 1.4),
                                listBullet: theme.textTheme.bodyMedium!
                                    .copyWith(fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String script) {
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Script copied to clipboard')),
    );
  }
}
