class ScriptSegment {
  final int startTime; // seconds
  final int endTime; // seconds
  final String voiceover;
  final String onScreenText;
  final String visualsActions;

  ScriptSegment({
    required this.startTime,
    required this.endTime,
    required this.voiceover,
    required this.onScreenText,
    required this.visualsActions,
  });

  @override
  String toString() {
    return "$startTime-${endTime}s: Voiceover: $voiceover | Visuals: $visualsActions";
  }
}
