import 'dart:async';
import 'dart:io';

import 'package:vioo_app/features/script_generator/services/remote/script_generator.dart';

Future<void> main() async {
  final String script = await ScriptGenerator.generateScript(
    'youth turnout',
    60,
    'Empowered',
    cta: 'Make a plan to vote at vote.org',
    temperature: 6,
  );
  stdout.writeln(script);
}
