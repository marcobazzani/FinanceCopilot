import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/app_settings.dart';

import '../integration_test/helpers/test_app.dart';

void main() {
  test('integration test helper isolates app settings from host state', () async {
    final hostDir = await Directory.systemTemp.createTemp('fc_host_settings_');
    try {
      AppSettings.resetForTesting();
      AppSettings.testConfigDir = hostDir;
      await AppSettings.set('googleRefreshToken', 'host-token');

      final isolatedDir = await isolateTestAppSettings();

      expect(await AppSettings.get('googleRefreshToken'), isNull);
      expect(isolatedDir.path, isNot(hostDir.path));
      expect(AppSettings.testConfigDir?.path, isolatedDir.path);
    } finally {
      AppSettings.resetForTesting();
      if (await hostDir.exists()) {
        await hostDir.delete(recursive: true);
      }
    }
  });
}
