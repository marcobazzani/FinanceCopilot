import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Global app settings stored in Application Support directory
/// (portable between platforms, accessible before DB is opened).
class AppSettings {
  static Directory? _resolvedConfigDir;
  @visibleForTesting
  static Directory? testConfigDir;
  @visibleForTesting
  static void resetForTesting() {
    _resolvedConfigDir = null;
    _cache = null;
    testConfigDir = null;
  }

  static Future<Directory> _getConfigDir() async {
    if (testConfigDir != null) return testConfigDir!;
    if (_resolvedConfigDir != null) return _resolvedConfigDir!;
    _resolvedConfigDir = await getApplicationSupportDirectory();
    return _resolvedConfigDir!;
  }

  static Future<File> get _file async {
    final dir = await _getConfigDir();
    return File(p.join(dir.path, 'settings.json'));
  }

  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file;
      if (await file.exists()) {
        _cache = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return _cache!;
      }
    } catch (_) {}
    _cache = {};
    return _cache!;
  }

  static Future<void> _save() async {
    if (_cache == null) return;
    final dir = await _getConfigDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = await _file;
    await file.writeAsString(jsonEncode(_cache));
  }

  /// Get a setting value.
  static Future<String?> get(String key) async {
    final data = await _load();
    return data[key] as String?;
  }

  /// Set a setting value.
  static Future<void> set(String key, String value) async {
    final data = await _load();
    data[key] = value;
    await _save();
  }

  /// Get the UI language ('en' or 'it').
  static Future<String> getLanguage() async {
    return await get('language') ?? 'en';
  }

  /// Set the UI language.
  static Future<void> setLanguage(String lang) async {
    await set('language', lang);
  }

  /// Load the persisted UI language for app startup.
  static Future<String> loadLanguageForStartup() async {
    final lang = await getLanguage();
    return lang.startsWith('it') ? 'it' : 'en';
  }
}
