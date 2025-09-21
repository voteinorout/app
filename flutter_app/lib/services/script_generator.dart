import '../models/script_segment.dart';

class ScriptGenerator {
  // Simple static generator; no external dependencies.
  static List<ScriptSegment> generateScript(String topic, int length, String style) {
    final segments = <ScriptSegment>[];
    final int segmentCount = (length / 3).ceil();
    final seed = DateTime.now().millisecond;

    for (int i = 0; i < segmentCount; i++) {
      final start = i * 3;
      final bool flip = ((seed + i) % 2) == 0;

      String voiceover;
      String onScreen;
      String visuals;

      if (style.toLowerCase() == 'entertaining') {
        // Fun, punchy lines
        voiceover = flip
            ? 'Vote like it\'s a party — $topic matters!'
            : 'Make your voice heard about $topic — do it with a smile.';
        onScreen = flip ? 'Vote. Party. Repeat.' : 'Make it count';
        visuals = flip ? 'Confetti, people cheering' : 'Person dancing to ballot box';
      } else {
        // Educational default
        voiceover = flip
            ? 'Voting empowers you: $topic explained in simple terms.'
            : 'Learn how $topic impacts your community — and why your vote matters.';
        onScreen = flip ? 'Your Vote Counts' : '$topic: Why it matters';
        visuals = flip ? 'Ballot box, checklist' : 'Community meeting, infographic';
      }

      // Slightly vary by segment index to avoid exact repeats
      if (i % 3 == 0) {
        onScreen = '$onScreen • Tip ${i ~/ 3 + 1}';
      }

      segments.add(ScriptSegment(
        startTime: start,
        voiceover: voiceover,
        onScreenText: onScreen,
        visualsActions: visuals,
      ));
    }

    return segments;
  }
}
