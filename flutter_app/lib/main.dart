import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vioo_app/features/home/screens/home_screen.dart';
import 'package:vioo_app/features/script_generator/screens/config_screen.dart';
import 'package:vioo_app/features/script_generator/screens/script_screen.dart';
import 'package:vioo_app/features/script_generator/screens/saved_scripts_screen.dart';
import 'package:vioo_app/features/script_generator/services/local/script_storage.dart';
import 'package:vioo_app/shared/config/proxy_config.dart';
import 'package:vioo_app/firebase_options.dart';

const String _scriptProxyEndpoint = ProxyConfig.scriptProxyEndpoint;

Future<void> main() async {
  // firebase setup
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  await ScriptStorage.init();
  if (_scriptProxyEndpoint.isEmpty && kDebugMode) {
    debugPrint(
      'SCRIPT_PROXY_ENDPOINT missing. Provide it via --dart-define to enable hosted script generation.',
    );
  }
  runApp(const VoteInOrOutApp());
}

/// Main application widget
class VoteInOrOutApp extends StatelessWidget {
  const VoteInOrOutApp({super.key});

  static const Color _primaryNavy = Color(0xFF031750);
  static const Color _accentBlue = Color(0xFF2B6FEE);
  static const Color _background = Color(0xFFF4F6FB);

  @override
  Widget build(BuildContext context) {
    final ColorScheme baseScheme = ColorScheme.fromSeed(
      seedColor: _accentBlue,
      brightness: Brightness.light,
    );

    final ColorScheme colorScheme = baseScheme.copyWith(
      primary: _primaryNavy,
      secondary: _accentBlue,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1B1D28),
    );

    const OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color.fromRGBO(3, 23, 80, 0.12)),
    );

    const OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: _accentBlue, width: 1.6),
    );

    return MaterialApp(
      title: 'Vote In Or Out',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _primaryNavy,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primaryNavy,
            letterSpacing: 0.4,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryNavy,
            side: BorderSide(color: _primaryNavy.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: _primaryNavy.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: baseBorder,
          enabledBorder: baseBorder,
          focusedBorder: focusedBorder,
          labelStyle: const TextStyle(color: _primaryNavy),
          hintStyle: TextStyle(
            color: const Color(0xFF1B1D28).withValues(alpha: 0.45),
          ),
        ),
        textTheme: Typography.material2021().black.apply(
          bodyColor: const Color(0xFF1B1D28),
          displayColor: const Color(0xFF1B1D28),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/config': (context) => const ConfigScreen(),
        '/script': (context) => const ScriptScreen(),
        '/saved-scripts': (context) => const SavedScriptsScreen(),
      },
    );
  }
}

/// Splash screen that shows the app title for 2 seconds then navigates to Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: VoteInOrOutApp._primaryNavy,
        child: Center(
          child: SvgPicture.asset(
            'assets/logo-vioo-white.svg',
            semanticsLabel: 'Vote In Or Out logo',
            width: 220,
          ),
        ),
      ),
    );
  }
}
