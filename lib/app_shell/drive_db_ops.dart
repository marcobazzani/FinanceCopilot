part of '../main.dart';

extension _AppShellDriveDbOps on _AppShellState {
  Future<void> _showImportExportDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);
    final isSignedIn = sync.isSignedIn;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: Text(s.settingsExportDb),
              subtitle: Text(s.importExportExportHint),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: Text(s.settingsImportDb),
              subtitle: Text(s.importExportImportHint),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: Text(s.importExportBackupDrive),
              subtitle: Text(isSignedIn ? s.importExportBackupDriveHint : s.importExportSignInFirst),
              enabled: isSignedIn,
              onTap: isSignedIn ? () => Navigator.pop(ctx, 'backup') : null,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: Text(s.importExportRestoreDrive),
              subtitle: Text(isSignedIn ? s.importExportRestoreDriveHint : s.importExportSignInFirst),
              enabled: isSignedIn,
              onTap: isSignedIn ? () => Navigator.pop(ctx, 'restore') : null,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'export') {
      final path = await DbTransferService.exportDb();
      if (path != null && context.mounted) {
        showInfoSnack(context, s.settingsExportSuccess);
      }
    } else if (action == 'import') {
      await _importDb(context);
    } else if (action == 'backup') {
      await _backupToDrive(context);
    } else if (action == 'restore') {
      await _restoreFromDrive(context);
    }
  }

  String _formatRemoteInfo(AppStrings s, DriveFileInfo info) {
    final size = _formatBytes(info.size);
    final date = '${info.modifiedTime.toLocal()}'.split('.').first;
    return s.importExportRemoteInfo(size, date, info.deviceName);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _backupToDrive(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);

    // Pre-flight: show the user what will be overwritten on Drive.
    final existing = await sync.getRemoteInfo();
    if (!context.mounted) return;
    final remoteInfo = existing != null ? _formatRemoteInfo(s, existing) : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportBackupConfirmTitle),
        content: Text(s.importExportBackupConfirmBody(remoteInfo)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.importExportBackupDrive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await sync.backupToDrive();
      if (!context.mounted) return;
      showInfoSnack(context, s.importExportBackupSuccess);
    } catch (e) {
      _log.warning('backupToDrive failed: $e');
      if (!context.mounted) return;
      showInfoSnack(context, '${s.importExportBackupFailed}: $e');
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);

    // Pre-flight: show the user what will be pulled from Drive.
    final existing = await sync.getRemoteInfo();
    if (!context.mounted) return;
    if (existing == null) {
      showInfoSnack(context, s.importExportRestoreEmpty);
      return;
    }
    final remoteInfo = _formatRemoteInfo(s, existing);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportRestoreConfirmTitle),
        content: Text(s.importExportRestoreConfirmBody(remoteInfo)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.importExportRestoreDrive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      _wireSyncCallbacks(sync);
      final restored = await sync.restoreFromDrive();
      if (!context.mounted) return;
      if (restored == null) {
        showInfoSnack(context, s.importExportRestoreEmpty);
        return;
      }
      ref.read(dbReloadTrigger.notifier).state++;
      showInfoSnack(context, s.importExportRestoreSuccess);
    } catch (e) {
      _log.warning('restoreFromDrive failed: $e');
      if (!context.mounted) return;
      showInfoSnack(context, '${s.importExportRestoreFailed}: $e');
    }
  }

  Future<void> _importDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final db = ref.read(databaseProvider);

    if (await _dbHasUserData(db)) {
      if (!context.mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.settingsImportWarningTitle),
          content: Text(s.settingsImportWarningBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'export'),
              child: Text(s.settingsExportFirst),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: Text(s.settingsReplaceAnyway),
            ),
          ],
        ),
      );
      if (action == null) return;
      if (action == 'export') {
        final exported = await DbTransferService.exportDb();
        if (exported == null) return; // cancelled
      }
    }

    // Merge into the open DB via ATTACH. This avoids replacing the SQLite
    // file while Drift still has active stream subscribers, which is fragile
    // on Windows and can leave stale handles.
    if (!context.mounted) return;
    final path = await DbTransferService.importDb(db);
    if (path == null) return;

    ref.read(dbReloadTrigger.notifier).state++;
    if (context.mounted) {
      showInfoSnack(context, s.settingsImportSuccess);
    }
  }

  Future<void> _wipeDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    // Force export first
    final exported = await DbTransferService.exportDb();
    if (exported == null) {
      // User cancelled the export — abort wipe
      if (context.mounted) {
        showInfoSnack(context, s.settingsWipeCancelled);
      }
      return;
    }

    if (!context.mounted) return;

    // Confirm wipe
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 8),
            Text(s.settingsWipeConfirmTitle),
          ],
        ),
        content: Text(s.settingsWipeConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.settingsWipeConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Delete the DB file and reload
    try {
      final path = await DbTransferService.dbPath;
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      ref.read(dbReloadTrigger.notifier).state++;
      if (context.mounted) {
        Navigator.pop(context); // close settings
        // ignore: invalid_use_of_protected_member
        setState(() => _showLanding = true);
      }
    } catch (e) {
      _log.severe('Wipe DB failed: $e');
    }
  }
}
