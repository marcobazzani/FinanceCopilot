part of '../main.dart';

extension _AppShellDriveDbOps on _AppShellState {
  /// The import/export icon: with the sync indicator lit, straight to the
  /// Restore (backup newer) or Backup (backup older) confirmation, which can
  /// still lead to this dialog; otherwise the Import/Export dialog.
  Future<void> _openSyncIndicator(BuildContext context) => switch (ref.read(backupSyncStatusProvider).indicator) {
    BackupSyncIndicator.backupNewer => _restoreFromDrive(context, fromIndicator: true),
    BackupSyncIndicator.backupOlder => _backupToDrive(context, fromIndicator: true),
    BackupSyncIndicator.off => _showImportExportDialog(context),
  };

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
      final exported = await _exportDbFile(context, s.dbExportFailed);
      if (exported?.path != null && context.mounted) {
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

  /// Tells the user, in their language, that a database transfer failed: the
  /// specific reason when there is one they can act on (a database from
  /// another app version, a Drive sign-in to renew), otherwise [message]. The
  /// raw error only goes to the log, which the caller writes.
  void _showTransferFailure(BuildContext context, Object error, String message) {
    if (error is DriveSignInExpired) return _showReauthSnack(context, ref.read(googleDriveSyncProvider));
    final s = ref.read(appStringsProvider);
    showInfoSnack(
      context,
      error is SchemaVersionMismatchException ? s.dbSchemaMismatch(error.remoteVersion, error.localVersion) : message,
    );
  }

  /// Picks a database file and merges it into the open one. Returns whether
  /// it was merged: false when the user cancelled or the merge failed (the
  /// failure is reported).
  Future<bool> _mergeDbFromFile(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    try {
      return await DbTransferService.importDb(ref.read(databaseProvider), dialogTitle: s.dbImportPickerTitle) != null;
    } catch (e, st) {
      _log.warning('importDb failed', e, st);
      if (context.mounted) _showTransferFailure(context, e, s.dbImportFailed);
      return false;
    }
  }

  /// Exports the open database to a file the user picks: `(path: …)`, null
  /// inside when the user cancelled. When the export fails the answer is
  /// null: [failure] is reported and the error logged.
  Future<({String? path})?> _exportDbFile(BuildContext context, String failure) async {
    final s = ref.read(appStringsProvider);
    try {
      return (path: await DbTransferService.exportDb(ref.read(databaseProvider), dialogTitle: s.dbExportPickerTitle));
    } catch (e, st) {
      _log.warning('exportDb failed', e, st);
      if (context.mounted) _showTransferFailure(context, e, failure);
      return null;
    }
  }

  String _formatRemoteInfo(AppStrings s, DriveFileInfo info) {
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final size = _formatBytes(info.size, locale);
    final date = fmt.fullDateFormat(locale).add_Hm().format(info.modifiedTime.toLocal());
    return s.importExportRemoteInfo(size, date, info.deviceName);
  }

  String _formatBytes(int bytes, String locale) {
    if (bytes < 1024) return '$bytes B';
    final oneDecimal = NumberFormat('#,##0.0', locale);
    if (bytes < 1024 * 1024) return '${oneDecimal.format(bytes / 1024)} KB';
    return '${oneDecimal.format(bytes / 1024 / 1024)} MB';
  }

  /// Looks up the Drive backup a confirmation quotes: `(backup: …)`, null
  /// inside when Drive holds none. When the lookup fails the operation stops
  /// here: [failure] is reported and the whole answer is null — an unanswered
  /// lookup is no "no backup" (a backup would create a second remote file).
  Future<({DriveFileInfo? backup})?> _lookUpDriveBackup(BuildContext context, GoogleDriveSyncService sync, String failure) async {
    try {
      return (backup: await sync.getRemoteInfo());
    } catch (e, st) {
      _log.warning('Drive backup lookup failed', e, st);
      if (context.mounted) _showTransferFailure(context, e, failure);
      return null;
    }
  }

  /// A Backup or Restore confirmation: [body], then each known, non-empty list
  /// of [changes] under its header, then [warning] when there is one. Opened
  /// from the sync indicator ([fromIndicator]) it also offers the
  /// Import/Export dialog, out of reach otherwise while the indicator is lit.
  /// Says whether to go ahead.
  Future<bool> _confirmDriveTransfer(
    BuildContext context, {
    required String title,
    required String body,
    List<(String header, Set<EditChange>? changes)> changes = const [],
    required String? warning,
    required String confirmLabel,
    required bool fromIndicator,
    Color? confirmColor,
  }) async {
    final s = ref.read(appStringsProvider);
    final choice = await showConfirmChoiceDialog(
      context,
      title: title,
      content: [
        body,
        for (final (header, list) in changes)
          if (list != null && list.isNotEmpty) s.syncChangeList(header, list),
        ?warning,
      ].join('\n\n'),
      confirmLabel: confirmLabel,
      cancelLabel: s.cancel,
      confirmColor: confirmColor,
      alternativeLabel: fromIndicator ? s.syncMoreOptions : null,
    );
    if (choice == ConfirmChoice.alternative && context.mounted) await _showImportExportDialog(context);
    return choice == ConfirmChoice.confirm;
  }

  Future<void> _backupToDrive(BuildContext context, {bool fromIndicator = false}) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);
    final backupSync = ref.read(backupSyncControllerProvider);

    // Pre-flight: show the user what will be overwritten on Drive.
    final lookup = await _lookUpDriveBackup(context, sync, s.importExportBackupFailed);
    if (lookup == null || !context.mounted) return;
    final existing = lookup.backup;
    final remoteInfo = existing != null ? _formatRemoteInfo(s, existing) : null;
    await backupSync.sawBackup(existing);
    if (!context.mounted) return;
    final status = ref.read(backupSyncStatusProvider);

    final confirmed = await _confirmDriveTransfer(
      context,
      title: s.importExportBackupConfirmTitle,
      body: s.importExportBackupConfirmBody(remoteInfo),
      changes: [(s.syncNotBackedUpYet, status.localEdits), (s.syncOnlyOnDrive, status.remoteEdits)],
      warning: status.backupOverwritesRemoteEdits ? s.syncBackupOverwritesRemoteEdits : null,
      confirmLabel: s.importExportBackupDrive,
      fromIndicator: fromIndicator,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final uploaded = await sync.backupToDrive();
      if (!context.mounted) return;
      showInfoSnack(context, s.importExportBackupSuccess);
      unawaited(backupSync.backedUp(uploaded));
    } catch (e, st) {
      _log.warning('backupToDrive failed', e, st);
      if (context.mounted) _showTransferFailure(context, e, s.importExportBackupFailed);
    }
  }

  Future<void> _restoreFromDrive(BuildContext context, {bool fromIndicator = false}) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);
    final backupSync = ref.read(backupSyncControllerProvider);

    // Pre-flight: show the user what will be pulled from Drive.
    final lookup = await _lookUpDriveBackup(context, sync, s.importExportRestoreFailed);
    if (lookup == null || !context.mounted) return;
    final existing = lookup.backup;
    await backupSync.sawBackup(existing);
    if (!context.mounted) return;
    if (existing == null) {
      showInfoSnack(context, s.importExportRestoreEmpty);
      return;
    }
    final remoteInfo = _formatRemoteInfo(s, existing);
    final status = ref.read(backupSyncStatusProvider);

    final confirmed = await _confirmDriveTransfer(
      context,
      title: s.importExportRestoreConfirmTitle,
      body: s.importExportRestoreConfirmBody(remoteInfo),
      changes: [(s.syncNewInBackup, status.remoteEdits), (s.syncOnlyOnThisDevice, status.localEdits)],
      warning: status.restoreDiscardsLocalEdits ? s.syncRestoreDiscardsLocalEdits : null,
      confirmLabel: s.importExportRestoreDrive,
      confirmColor: Colors.red,
      fromIndicator: fromIndicator,
    );
    if (!confirmed || !context.mounted) return;

    try {
      _wireSyncCallbacks(sync);
      final restored = await sync.restoreFromDrive();
      if (!context.mounted) return;
      if (restored == null) {
        showInfoSnack(context, s.importExportRestoreEmpty);
        return;
      }
      // Recorded on the restored data, before the database reloads.
      await backupSync.restored(restored);
      if (!context.mounted) return;
      ref.read(dbReloadTrigger.notifier).state++;
      showInfoSnack(context, s.importExportRestoreSuccess);
    } catch (e, st) {
      _log.warning('restoreFromDrive failed', e, st);
      if (context.mounted) _showTransferFailure(context, e, s.importExportRestoreFailed);
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
      if (action == null || !context.mounted) return;
      if (action == 'export') {
        final exported = await _exportDbFile(context, s.dbExportFailed);
        if (exported?.path == null) return; // failed (reported) or cancelled
      }
    }

    // Merge into the open DB via ATTACH. This avoids replacing the SQLite
    // file while Drift still has active stream subscribers, which is fragile
    // on Windows and can leave stale handles.
    if (!context.mounted) return;
    if (!await _mergeDbFromFile(context)) return;

    ref.read(dbReloadTrigger.notifier).state++;
    if (context.mounted) {
      showInfoSnack(context, s.settingsImportSuccess);
    }
  }

  /// Runs from the host screen once the Settings dialog has closed, so its
  /// messages are not raised under that dialog's barrier.
  Future<void> _wipeDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    // Force export first
    final exported = await _exportDbFile(context, s.settingsWipeExportFailed);
    if (exported == null) return; // failed, reported
    if (exported.path == null) {
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

    // Close the connection before deleting its file: Windows refuses to delete
    // an open file, and elsewhere the open handle would keep using the
    // unlinked one. The reload trigger then opens a fresh database — also
    // after a failure, since the closed instance cannot be used any more.
    try {
      await ref.read(databaseProvider).close();
      final file = File(await DbTransferService.dbPath);
      if (file.existsSync()) file.deleteSync();
    } catch (e, st) {
      _log.severe('Wipe DB failed', e, st);
      ref.read(dbReloadTrigger.notifier).state++;
      if (context.mounted) showInfoSnack(context, s.settingsWipeFailed);
      return;
    }
    ref.read(dbReloadTrigger.notifier).state++;
    // The new database never synced: no backup is newer or older than it.
    ref.read(backupSyncControllerProvider).forgetSync();
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() => _showLanding = true);
    }
  }
}
