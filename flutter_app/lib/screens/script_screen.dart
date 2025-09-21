import 'package:flutter/material.dart';
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/voteinorout/app/script_generator.dart';

class ScriptScreen extends StatefulWidget {
  const ScriptScreen({Key? key}) : super(key: key);

  @override
  State<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends State<ScriptScreen> {
  late Future<List<ScriptSegment>> _scriptFuture;
  late String _topic;
  late int _length;
  late String _style;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _topic = args?['topic'] as String? ?? 'Topic';
    _length = args?['length'] as int? ?? 30;
    _style = args?['style'] as String? ?? 'Educational';
    _scriptFuture = ScriptGenerator.generateScript(_topic, _length, _style);
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Script Builder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preview for: $_topic',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<ScriptSegment>>(
                future: _scriptFuture,
                builder: (BuildContext context,
                    AsyncSnapshot<List<ScriptSegment>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      snapshot.connectionState == ConnectionState.active) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent),
                            const SizedBox(height: 12),
                            const Text(
                              'There was a problem generating your script. Please try again.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _scriptFuture =
                                      ScriptGenerator.generateScript(
                                          _topic, _length, _style);
                                });
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final List<ScriptSegment> segments =
                      snapshot.data ?? <ScriptSegment>[];
                  if (segments.isEmpty) {
                    return const Center(
                      child: Text(
                          'No script generated yet. Try a different prompt.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: segments.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white24),
                    itemBuilder: (BuildContext context, int index) {
                      final ScriptSegment segment = segments[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 4.0),
                        title: Text(
                          '${segment.startTime}-${segment.startTime + 3}s',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('Voiceover: ${segment.voiceover}',
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('On-screen: ${segment.onScreenText}',
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text('Visuals: ${segment.visualsActions}',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
