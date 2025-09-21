import 'dart:async';

import 'package:vioo_app/models/script_segment.dart';
import 'package:vioo_app/voteinorout/app/script_generator.dart';

Future<void> main() async {
  final List<ScriptSegment> segments =
      await ScriptGenerator.generateScript('youth turnout', 15, 'energetic');
  for (final segment in segments) {
    print(
        '${segment.startTime}s | VO: ${segment.voiceover} | Text: ${segment.onScreenText} | Visuals: ${segment.visualsActions}');
  }
}
