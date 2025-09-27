import 'package:flutter_test/flutter_test.dart';
import 'package:vioo_app/features/script_generator/models/script_segment.dart';
import 'package:vioo_app/features/script_generator/services/remote/script_generator.dart';

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

      final List<ScriptSegment> segments = ScriptGenerator.parseSegmentsForTest(
        rawJson,
        8,
      );

      expect(segments, hasLength(2));
      expect(segments.first.startTime, 0);
      expect(segments.first.voiceover, contains('dogs are cool'));
      expect(segments.last.startTime, 3);
    });

    test(
      'generateScript falls back to deterministic beats without proxy',
      () async {
        final String script = await ScriptGenerator.generateScript(
          'dogs are cool',
          12,
          'Educational',
        );

        expect(script.isNotEmpty, isTrue);
        const int expectedBeats = 5;
        final Iterable<Match> beats = RegExp(
          r'\*\*[^*]+\(\d+-\d+s\):\*\*',
        ).allMatches(script);
        expect(beats.length, greaterThanOrEqualTo(expectedBeats));
        expect(script.toLowerCase().contains('dogs'), isTrue);
      },
    );
  });
}
