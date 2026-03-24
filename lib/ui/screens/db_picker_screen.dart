import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../database/providers.dart';
import '../../l10n/app_strings.dart';
import '../../services/demo_csv_service.dart';
import '../../services/demo_db_service.dart';
import '../../services/providers.dart';
import '../../services/tour_service.dart';
import '../../utils/logger.dart';
import '../../version.dart';
import '../widgets/tour_keys.dart';

final _log = getLogger('DbPicker');

/// Persisted recent-databases list stored in ~/.config/FinanceCopilot/recent_dbs.json.
class _RecentDbs {
  static String get _homeDir =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

  static final _configDir = Directory(
    Platform.isWindows
        ? p.join(Platform.environment['APPDATA'] ?? _homeDir, 'FinanceCopilot')
        : p.join(_homeDir, '.config', 'FinanceCopilot'),
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
    _loadRecent();
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

  Future<void> _startGuidedTour() async {
    final s = ref.read(appStringsProvider);
    _log.info('Guide Me: showing intro dialog');
    final home = _RecentDbs._homeDir;
    var demoDir = p.join(home, 'Documents', 'FinanceCopilot Demo Files');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.school, size: 28),
              const SizedBox(width: 12),
              Text(s.guideMeDialogTitle),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.guideMeDialogBody),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          demoDir,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            final picked = await FilePicker.platform.getDirectoryPath(
                              dialogTitle: s.guideMeChooseFolder,
                            );
                            if (picked != null) {
                              setDialogState(() => demoDir = picked);
                            }
                          } catch (e) {
                            _log.warning('Guide Me: directory picker error: $e');
                          }
                        },
                        child: Text(s.guideMeChangePath),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.guideMeStart),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    _log.info('Guide Me: starting tour with dir=$demoDir');
    setState(() => _isGenerating = true);
    try {
      await DemoCsvService.generateDemoCsvs(demoDir);
      _log.info('Demo CSVs generated in $demoDir');
      Tour.start(ref.read(tourProvider.notifier), demoDir);
    } catch (e) {
      _log.warning('Failed to generate demo CSVs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate demo files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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
              Text(s.dbPickerTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.folder_open),
                    label: Text(s.dbPickerOpenFile),
                  ),
                  OutlinedButton.icon(
                    key: TourKeys.newProjectButton,
                    onPressed: () async {
                      final tour = ref.read(tourProvider);
                      if (tour.isActive && tour.currentStep == TourStep.dbPickerNewProject) {
                        // During tour: auto-create DB in the demo folder
                        final dbPath = p.join(tour.demoCsvDir!, 'FinanceCopilot_tour.db');
                        final existing = File(dbPath);
                        if (await existing.exists()) await existing.delete();
                        _log.info('Tour: creating DB at $dbPath');
                        await _selectDb(dbPath);
                        Tour.advance(ref.read(tourProvider.notifier));
                      } else {
                        await _createEmpty();
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(s.dbPickerNewProject),
                  ),
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
                  FilledButton.icon(
                    onPressed: _startGuidedTour,
                    icon: const Icon(Icons.school),
                    label: Text(s.dbPickerGuideMe),
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
