import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../database/providers.dart';
import '../../services/app_settings.dart';
import '../../services/demo_db_service.dart';
import '../../services/providers/providers.dart';
import '../../services/update_service.dart';
import '../../utils/bug_reporter.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import '../../version.dart';

final _log = getLogger('DbPicker');

/// Persisted recent-databases list stored in ~/.config/FinanceCopilot/recent_dbs.json.
class _RecentDbs {
  static final _configDir = Directory(
    p.join(
      fmt.homeDir,
      '.config', 'FinanceCopilot',
    ),
  );
  static File get _file => File(p.join(_configDir.path, 'recent_dbs.json'));

  /// Load the list of recent DB paths (most-recent first). Filters out deleted files.
  static Future<List<String>> load() async {
    final file = _file;
    if (!await file.exists()) return [];
    try {
      final list = (jsonDecode(await file.readAsString()) as List).cast<String>();
      // Keep only paths that still exist on disk
      final existing = <String>[];
      for (final path in list) {
        if (await File(path).exists()) existing.add(path);
      }
      return existing;
    } catch (_) {
      return [];
    }
  }

  /// Add [path] to the top of the recent list (dedup, cap at 10).
  static Future<void> add(String path) async {
    final list = await load();
    list.remove(path);
    list.insert(0, path);
    if (list.length > 10) list.removeRange(10, list.length);
    await _save(list);
  }

  /// Remove [path] from the recent list.
  static Future<void> remove(String path) async {
    final list = await load();
    list.remove(path);
    await _save(list);
  }

  static Future<void> _save(List<String> list) async {
    if (!await _configDir.exists()) await _configDir.create(recursive: true);
    await _file.writeAsString(jsonEncode(list));
  }
}

/// Startup screen: open a DB from anywhere, pick from recents, or create a demo.
class DbPickerScreen extends ConsumerStatefulWidget {
  const DbPickerScreen({super.key});

  @override
  ConsumerState<DbPickerScreen> createState() => _DbPickerScreenState();
}

class _DbPickerScreenState extends ConsumerState<DbPickerScreen> {
  List<String> _recentPaths = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  double _demoProgress = 0;
  final _repaintKey = GlobalKey();
  String _demoLabel = '';
  String _channel = 'nightly';

  @override
  void initState() {
    super.initState();
    _copySandboxDbIfNeeded().then((_) => _loadRecent());
    AppSettings.getUpdateChannel().then((ch) {
      if (mounted) setState(() => _channel = ch);
    });
    AppSettings.getLanguage().then((lang) {
      ref.read(portableLanguageProvider.notifier).state = lang;
    });
    // Check for updates on startup (no DB needed)
    Future.microtask(() => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    if (isLocalBuild) {
      _log.info('Skipping update check (local build)');
      return;
    }
    try {
      final channel = await AppSettings.getUpdateChannel();
      _log.info('Checking for updates (channel=$channel, commit=$appCommit)...');
      final updater = UpdateService();
      final info = await updater.checkForUpdate(channel);
      if (!info.available || !mounted) return;

      final changelog = await updater.getChangelog(info.latestCommit);
      if (!mounted) return;

      _showUpdateDialog(info, changelog);
    } catch (e) {
      _log.warning('Update check failed: $e');
    }
  }

  void _showUpdateDialog(UpdateInfo info, List<String> changelog) {
    showDialog(
      context: context,
      builder: (ctx) {
        var downloading = false;
        var progress = 0.0;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            icon: const Icon(Icons.system_update, size: 36, color: Colors.blue),
            title: Text(ref.read(appStringsProvider).updateAvailable(info.latestVersion ?? '')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (changelog.isNotEmpty) ...[
                    Text(ref.read(appStringsProvider).changesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: changelog.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text('• ${changelog[i]}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ] else
                    Text(info.releaseNotes ?? ref.read(appStringsProvider).newVersionAvailable),
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress > 0 ? progress : null),
                    const SizedBox(height: 4),
                    Text(ref.read(appStringsProvider).downloadingProgress((progress * 100).round()),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
            ),
            actions: downloading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(ref.read(appStringsProvider).later),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(ref.read(appStringsProvider).updateAndRestart),
                      onPressed: info.downloadUrl == null
                          ? null
                          : () async {
                              setDialogState(() => downloading = true);
                              try {
                                await UpdateService().applyUpdate(
                                  info,
                                  onProgress: (p) => setDialogState(() => progress = p),
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  setDialogState(() => downloading = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(ref.read(appStringsProvider).updateFailed(e))),
                                  );
                                }
                              }
                            },
                    ),
                  ],
          ),
        );
      },
    );
  }

  /// On first run (macOS only), copy sandbox DB to ~/Documents/ and add to recents.
  Future<void> _copySandboxDbIfNeeded() async {
    if (!Platform.isMacOS) return;
    final sandboxDb = File(
      '/Users/marco/Library/Containers/net.bazzani.financecopilot/Data/Documents/FinanceCopilot/finance_copilot.db',
    );
    final home = fmt.homeDir;
    if (home == '.') return; // No home directory found
    final target = File(p.join(home, 'Documents', 'FinanceCopilot.db'));
    if (await sandboxDb.exists() && !await target.exists()) {
      _log.info('Copying sandbox DB to ${target.path}');
      await sandboxDb.copy(target.path);
      await _RecentDbs.add(target.path);
    }
  }

  Future<void> _loadRecent() async {
    final paths = await _RecentDbs.load();
    if (mounted) setState(() { _recentPaths = paths; _isLoading = false; });
  }

  Future<void> _selectDb(String path) async {
    _log.info('Selected database: $path');
    await _RecentDbs.add(path);
    ref.read(dbPathProvider.notifier).state = path;
  }

  Future<void> _removeRecent(String path) async {
    await _RecentDbs.remove(path);
    await _loadRecent();
  }

  Future<void> _openFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: ref.read(appStringsProvider).openDatabase,
      );
      if (result != null && result.files.single.path != null) {
        _selectDb(result.files.single.path!);
      }
    } catch (e, st) {
      _log.warning('File picker error: $e', e, st);
    }
  }

  Future<void> _createEmpty() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: ref.read(appStringsProvider).createNewProject,
      fileName: 'FinanceCopilot.db',
      allowedExtensions: ['db'],
      type: FileType.custom,
    );
    if (result == null) return;

    final path = result.endsWith('.db') ? result : '$result.db';
    final file = File(path);
    if (await file.exists()) await file.delete();

    // Just open the path — Drift will create an empty DB with all tables via migration
    _log.info('Creating empty project at $path');
    await _selectDb(path);
  }

  Future<void> _generateDemo() async {
    // Ask user where to save
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: ref.read(appStringsProvider).chooseDemoFolder,
    );
    if (dir == null) return;

    setState(() => _isGenerating = true);
    try {
      final path = p.join(dir, 'FinanceCopilot_demo.db');
      final existing = File(path);
      if (await existing.exists()) await existing.delete();

      await DemoDbService.generateDemoDb(path, onProgress: (step, total, label) {
        if (mounted) setState(() { _demoProgress = step / total; _demoLabel = label; });
      });
      _log.info('Demo DB generated at $path');
      await _selectDb(path);
    } catch (e) {
      _log.warning('Failed to generate demo DB: $e');
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.dbPickerDemoFailed(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return RepaintBoundary(
      key: _repaintKey,
      child: Scaffold(
      appBar: AppBar(title: const Text('FinanceCopilot')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(s.dbPickerTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.folder_open),
                    label: Text(s.dbPickerOpenFile),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _createEmpty,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(s.dbPickerNewProject),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _generateDemo,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGenerating ? s.dbPickerGenerating : s.dbPickerCreateDemo),
                  ),
                ],
              ),
              if (_isGenerating) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _demoProgress > 0 ? _demoProgress : null),
                      const SizedBox(height: 4),
                      Text(_demoLabel, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_recentPaths.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(s.dbPickerRecent, style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _recentPaths.length,
                    itemBuilder: (context, index) {
                      final path = _recentPaths[index];
                      final file = File(path);
                      final stat = file.statSync();
                      final sizeKb = stat.size ~/ 1024;
                      final sizeMb = sizeKb / 1024;
                      final sizeStr = sizeMb >= 1
                          ? '${sizeMb.toStringAsFixed(1)} MB'
                          : '$sizeKb KB';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(p.basename(path)),
                          subtitle: Text(
                            '${p.dirname(path)}\n$sizeStr  \u2022  ${dateFmt.format(stat.modified)}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: s.dbPickerRemoveRecent,
                            onPressed: () => _removeRecent(path),
                          ),
                          onTap: () => _selectDb(path),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'v$appVersion ($appCommit)',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => openBugReporter(context, ref, repaintKey: _repaintKey),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.bug_report, size: 14, color: Colors.grey.shade500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LanguageDropdown(
                    value: ref.watch(portableLanguageProvider),
                    onChanged: (lang) async {
                      await AppSettings.setLanguage(lang);
                      ref.read(portableLanguageProvider.notifier).state = lang;
                    },
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final next = _channel == 'nightly' ? 'stable' : 'nightly';
                      await AppSettings.setUpdateChannel(next);
                      if (mounted) setState(() => _channel = next);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        _channel,
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LanguageDropdown({required this.value, required this.onChanged});

  static const _options = [
    ('en', 'English'),
    ('it', 'Italiano'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      isDense: true,
      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
      items: _options
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
