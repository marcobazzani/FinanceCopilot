import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/app_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    AppSettings.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('app_settings_test_');
    AppSettings.testConfigDir = tempDir;
  });

  tearDown(() async {
    AppSettings.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loadLanguageForStartup returns the persisted language', () async {
    expect(await AppSettings.loadLanguageForStartup(), 'en');

    await AppSettings.setLanguage('it');

    expect(await AppSettings.loadLanguageForStartup(), 'it');
  });

  test('loadLanguageForStartup falls back to English for malformed values', () async {
    await AppSettings.set('language', 'pt');

    expect(await AppSettings.loadLanguageForStartup(), 'en');
  });
}
