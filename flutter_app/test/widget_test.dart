// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:vioo_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoteInOrOutApp());

    // Splash screen renders the brand SVG immediately.
    expect(find.byType(SvgPicture), findsOneWidget);

    // After the splash delay the app navigates to the home screen.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Viral Script Generator'), findsWidgets);
    expect(find.text('Create a script'), findsWidgets);
  });
}
