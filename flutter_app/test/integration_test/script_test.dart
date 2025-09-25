import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vioo_app/services/remote/script_generator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Script generation fallback produces timed beats',
      (WidgetTester tester) async {
    final String script = await ScriptGenerator.generateScript(
      'dogs are cool',
      30,
      'Educational',
    );

    expect(script, isNotEmpty);
    expect(script.contains('**0-4s:**'), isTrue);
    expect(script.toLowerCase().contains('dogs'), isTrue);
  });
}
