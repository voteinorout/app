import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vioo_app/features/script_generator/models/generated_script.dart';
import 'package:vioo_app/features/script_generator/services/local/script_storage.dart';

class SavedScriptsScreen extends StatelessWidget {
  const SavedScriptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Scripts')),
      body: ValueListenableBuilder<Box<GeneratedScript>>(
        valueListenable: ScriptStorage.listenable(),
        builder: (BuildContext context, Box<GeneratedScript> box, _) {
          final List<GeneratedScript> scripts = ScriptStorage.getScripts();
          if (scripts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Scripts you generate will be saved on this device. Create one to see it here.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemBuilder: (BuildContext context, int index) {
              final GeneratedScript script = scripts[index];
              final DateTime localTimestamp = script.createdAt.toLocal();
              final String formattedDate =
                  '${localTimestamp.month.toString().padLeft(2, '0')}/'
                  '${localTimestamp.day.toString().padLeft(2, '0')}/'
                  '${localTimestamp.year}';
              final String formattedTime =
                  '${localTimestamp.hour.toString().padLeft(2, '0')}:'
                  '${localTimestamp.minute.toString().padLeft(2, '0')}';

              return Dismissible(
                key: ValueKey<String>(script.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                confirmDismiss: (_) async => _confirmDelete(context, script),
                onDismissed: (_) => ScriptStorage.deleteScript(script.id),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  tileColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    script.topic,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Style: ${script.style} • Saved $formattedDate · $formattedTime',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showScriptActions(context, script),
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/script',
                    arguments: <String, dynamic>{
                      'script': script.content,
                      'topic': script.topic,
                      'style': script.style,
                      'usedHosted': script.usedHostedGenerator,
                    },
                  ),
                ),
              );
            },
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemCount: scripts.length,
          );
        },
      ),
    );
  }

  static Future<bool> _confirmDelete(
    BuildContext context,
    GeneratedScript script,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ThemeData theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Delete script?'),
              content: Text(
                'This removes "${script.topic}" from this device.',
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
  }

  static void _showScriptActions(
    BuildContext context,
    GeneratedScript script,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text('Copy script'),
                onTap: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(ClipboardData(text: script.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Script copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScriptStorage.deleteScript(script.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Script deleted')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
