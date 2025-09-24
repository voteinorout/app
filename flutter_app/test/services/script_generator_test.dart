import 'package:flutter_test/flutter_test.dart';
import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/services/remote/script_generator.dart';

void main() {
  group('ScriptGenerator parsing', () {
    test('parseSegmentsForTest converts JSON into ScriptSegment list', () {
      const String rawJson = '''
      {
        "segments": [
          {
            "startTime": 0,
            "voiceover": "Hook: dogs are cool",
            "onScreenText": "Dogs!",
            "visualsActions": "Puppies running"
          },
          {
            "startTime": 3,
            "voiceover": "Beat 2",
            "onScreenText": "More dogs",
            "visualsActions": "Dogs playing fetch"
          }
        ]
      }
      ''';

      final List<ScriptSegment> segments =
          ScriptGenerator.parseSegmentsForTest(rawJson, 12);

      expect(segments, hasLength(2));
      expect(segments.first.startTime, 0);
      expect(segments.first.voiceover, contains('dogs are cool'));
      expect(segments.last.startTime, 3);
    });

    test('generateScript falls back to deterministic beats without proxy',
        () async {
      final String script = await ScriptGenerator.generateScript(
        'dogs are cool',
        12,
        'Educational',
      );

      expect(script.isNotEmpty, isTrue);
      expect(script.contains('**0-6s:**'), isTrue);
      expect(script.toLowerCase().contains('dogs'), isTrue);
    });
  });
}
