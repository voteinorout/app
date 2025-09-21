class ScriptSegment {
  final int startTime; // seconds
  final String voiceover;
  final String onScreenText;
  final String visualsActions;

  ScriptSegment({
    required this.startTime,
    required this.voiceover,
    required this.onScreenText,
    required this.visualsActions,
  });

  @override
  String toString() {
    return "$startTime-${startTime + 3}s: Voiceover: $voiceover | On-screen Text: $onScreenText | Visuals/Actions: $visualsActions";
  }
}
