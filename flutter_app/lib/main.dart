import 'package:flutter/material.dart';
import 'screens/config_screen.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const VoteInOrOutApp());
}

/// Main application widget
class VoteInOrOutApp extends StatelessWidget {
  const VoteInOrOutApp({Key? key}) : super(key: key);

  // Primary color hex: #1E2A44
  static const int _primaryHex = 0xFF1E2A44;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vote In Or Out',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: createMaterialColor(const Color(_primaryHex)),
        scaffoldBackgroundColor: const Color(_primaryHex),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(_primaryHex),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: createMaterialColor(const Color(_primaryHex))[600],
          ),
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/config': (context) => const ConfigScreen(),
        '/script': (context) => const ScriptScreen(),
      },
    );
  }
}

/// Splash screen that shows the app title for 2 seconds then navigates to Home
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

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
        color: const Color(0xFF1E2A44),
        child: const Center(
          child: Text(
            'VOTE IN OR OUT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple Home screen with navigation to Config and Script screens
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vote In Or Out')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/config'),
              child: const Text('Configuration'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/script'),
              child: const Text('Script Builder'),
            ),
          ],
        ),
      ),
    );
  }
}

// `ConfigScreen` is implemented in `lib/config_screen.dart`.

/// Script screen that consumes arguments from `/config` and displays a preview
class ScriptScreen extends StatelessWidget {
  const ScriptScreen({Key? key}) : super(key: key);

  String _buildScript(Map<String, dynamic> args) {
    final topic = args['topic'] as String? ?? 'your topic';
    final style = args['style'] as String? ?? 'Educational';
    final length = args['length'] as int? ?? 30;
    final cta = args['cta'] as String?;

    final buffer = StringBuffer();
    buffer.writeln('$style short video about $topic');
    buffer.writeln();
    buffer.writeln('Open: Hook the viewer in the first 3 seconds with a strong claim or surprising fact about $topic.');
    buffer.writeln();
    buffer.writeln('Body: Deliver the main payoff clearly. Keep it concise — aim for ${length}s total.');
    buffer.writeln();
    if (cta != null && cta.isNotEmpty) {
      buffer.writeln('Close: $cta');
    } else {
      buffer.writeln('Close: Encourage the viewer to learn more or take action.');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final script = _buildScript(args ?? {});

    return Scaffold(
      appBar: AppBar(title: const Text('Script Builder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Generated script preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    script,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Copy to clipboard
                      Clipboard.setData(ClipboardData(text: script));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Script copied to clipboard')),
                      );
                    },
                    child: const Text('Copy script'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Placeholder action: go back to home
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility: create a MaterialColor from a single Color
MaterialColor createMaterialColor(Color color) {
  // Create a swatch by shifting the lightness in HSL color space.
  final hsl = HSLColor.fromColor(color);
  final strengths = <double>[.05];
  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }

  final swatch = <int, Color>{};
  for (var strength in strengths) {
    // Map strength [0.0 .. 1.0] to a lightness adjustment around current value.
    final double ds = (strength - 0.5) * 1.0; // range roughly -0.45 .. 0.4
    double newLightness = (hsl.lightness + ds).clamp(0.0, 1.0);
    swatch[(strength * 1000).round()] = hsl.withLightness(newLightness).toColor();
  }

  // Normalize keys to 50..900 as required by MaterialColor
  final normalized = <int, Color>{};
  int i = 0;
  for (var key in [50,100,200,300,400,500,600,700,800,900]) {
    normalized[key] = swatch.values.elementAt(i);
    i++;
  }
  return MaterialColor(color.toARGB32(), normalized);
}

