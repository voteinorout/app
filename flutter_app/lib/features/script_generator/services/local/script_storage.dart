import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vioo_app/features/script_generator/models/generated_script.dart';

/// Helper for persisting generated scripts with Hive.
class ScriptStorage {
  ScriptStorage._();

  static const String _boxName = 'generated_scripts';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    if (!Hive.isAdapterRegistered(GeneratedScriptAdapter().typeId)) {
      Hive.registerAdapter(GeneratedScriptAdapter());
    }

    await Hive.openBox<GeneratedScript>(_boxName);
    _initialized = true;
  }

  static Box<GeneratedScript> _box() {
    if (!_initialized) {
      throw StateError('ScriptStorage.init() must be called before use.');
    }
    return Hive.box<GeneratedScript>(_boxName);
  }

  static ValueListenable<Box<GeneratedScript>> listenable() =>
      _box().listenable();

  static Future<GeneratedScript> saveScript({
    required String topic,
    required String style,
    required String content,
    required bool usedHostedGenerator,
    String? cta,
    int? temperature,
    int? length,
  }) async {
    final GeneratedScript script = GeneratedScript(
      id: _generateId(),
      topic: topic,
      style: style,
      content: content,
      createdAt: DateTime.now(),
      usedHostedGenerator: usedHostedGenerator,
      cta: cta,
      temperature: temperature,
      length: length,
    );

    await _box().put(script.id, script);
    return script;
  }

  static List<GeneratedScript> getScripts() {
    final List<GeneratedScript> scripts = _box().values.toList(growable: false);
    scripts.sort(
      (GeneratedScript a, GeneratedScript b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return scripts;
  }

  static Future<void> deleteScript(String id) async {
    await _box().delete(id);
  }

  static Future<void> deleteScripts(Iterable<String> ids) async {
    await _box().deleteAll(ids);
  }

  static Future<void> deleteAll() async {
    await _box().clear();
  }

  static GeneratedScript? getScript(String id) {
    return _box().get(id);
  }

  static String _generateId() {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final int randomSuffix = Random().nextInt(0x3fffffff);
    return '${timestamp.toRadixString(36)}-${randomSuffix.toRadixString(36)}';
  }
}
