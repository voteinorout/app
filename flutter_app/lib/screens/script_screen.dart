import 'package:flutter/material.dart';
import '../services/script_generator.dart';
import '../models/script_segment.dart';

class ScriptScreen extends StatelessWidget {
  const ScriptScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final topic = args?['topic'] as String? ?? 'Topic';
    final length = args?['length'] as int? ?? 30;
    final style = args?['style'] as String? ?? 'Educational';

    final List<ScriptSegment> segments =
        ScriptGenerator.generateScript(topic, length, style);

    return Scaffold(
      appBar: AppBar(title: const Text('Script Builder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preview for: $topic', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: segments.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                itemBuilder: (context, index) {
                  final s = segments[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    title: Text('${s.startTime}-${s.startTime + 3}s', style: const TextStyle(color: Colors.white70)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Voiceover: ${s.voiceover}', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('On-screen: ${s.onScreenText}', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('Visuals: ${s.visualsActions}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
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
