// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vioo_app/main.dart';
import 'package:vioo_app/shared/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    AuthService.overrideFirebaseAuth(() => MockFirebaseAuth());
  });

  tearDownAll(() {
    AuthService.overrideFirebaseAuth(() => FirebaseAuth.instance);
  });

  testWidgets('Smoke test renders splash then home content', (WidgetTester tester) async {
    await tester.pumpWidget(const VoteInOrOutApp());

    // Splash screen renders the brand SVG immediately.
    expect(find.byType(SvgPicture), findsOneWidget);

    // After the splash delay the app navigates to the login screen because the
    // mocked FirebaseAuth has no signed-in user.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Apple'), findsOneWidget);
  });
}
