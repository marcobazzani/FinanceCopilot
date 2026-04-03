import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/formatters.dart' show homeDir;

/// Global app settings stored in ~/.config/FinanceCopilot/settings.json
/// (portable between platforms, accessible before DB is opened).
class AppSettings {
  static final _configDir = Directory(
    p.join(homeDir, '.config', 'FinanceCopilot'),
  );
  static File get _file => File(p.join(_configDir.path, 'settings.json'));

  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final file = _file;
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
    if (!await _configDir.exists()) await _configDir.create(recursive: true);
    await _file.writeAsString(jsonEncode(_cache));
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

  /// Get the update channel ('nightly' or 'stable').
  static Future<String> getUpdateChannel() async {
    return await get('updateChannel') ?? 'nightly';
  }

  /// Set the update channel.
  static Future<void> setUpdateChannel(String channel) async {
    await set('updateChannel', channel);
  }

  /// Get the UI language ('en' or 'it').
  static Future<String> getLanguage() async {
    return await get('language') ?? 'en';
  }

  /// Set the UI language.
  static Future<void> setLanguage(String lang) async {
    await set('language', lang);
  }
}
