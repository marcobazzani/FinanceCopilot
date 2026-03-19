import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../database/providers.dart';
import '../../services/demo_db_service.dart';
import '../../utils/logger.dart';
import '../../version.dart';

final _log = getLogger('DbPicker');

/// Persisted recent-databases list stored in ~/.config/FinanceCopilot/recent_dbs.json.
class _RecentDbs {
  static final _configDir = Directory(
    p.join(Platform.environment['HOME']!, '.config', 'FinanceCopilot'),
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

  @override
  void initState() {
    super.initState();
    _copySandboxDbIfNeeded().then((_) => _loadRecent());
  }

  /// On first run, copy sandbox DB to ~/Documents/ and add to recents.
  Future<void> _copySandboxDbIfNeeded() async {
    final sandboxDb = File(
      '/Users/marco/Library/Containers/com.assetmanager.assetManager/Data/Documents/AssetManager/asset_manager.db',
    );
    final home = Platform.environment['HOME']!;
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
        dialogTitle: 'Open Database',
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
      dialogTitle: 'Create new project',
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
      dialogTitle: 'Choose folder for demo database',
    );
    if (dir == null) return;

    setState(() => _isGenerating = true);
    try {
      final path = p.join(dir, 'FinanceCopilot_demo.db');
      final existing = File(path);
      if (await existing.exists()) await existing.delete();

      await DemoDbService.generateDemoDb(path);
      _log.info('Demo DB generated at $path');
      await _selectDb(path);
    } catch (e) {
      _log.warning('Failed to generate demo DB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate demo DB: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('FinanceCopilot')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Open a Database', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open File...'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _createEmpty,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('New Project'),
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
                    label: Text(_isGenerating ? 'Generating...' : 'Create Demo DB'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_recentPaths.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Recent', style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey)),
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
                            tooltip: 'Remove from recent',
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
              Text(
                'v$appVersion',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
