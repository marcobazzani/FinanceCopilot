part of '../main.dart';

extension _AppShellShareIntent on _AppShellState {
  void _initShareIntent() {
    // Handle file shared while app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleSharedFiles(files);
    });
    // Handle file shared while app is running
    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleSharedFiles);
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final path = files.first.path;
    final ext = path.toLowerCase().split('.').last;
    if (!{'csv', 'xlsx', 'xls', 'tsv'}.contains(ext)) {
      _log.warning('Shared file ignored (unsupported type): $path');
      return;
    }
    _log.info('Received shared file: $path');
    if (mounted) _showShareImportDialog(path);
  }

  Future<void> _showShareImportDialog(String filePath) async {
    final s = ref.read(appStringsProvider);
    final accounts = ref.read(accountsProvider).value ?? [];
    var target = ImportTarget.transaction;
    int? accountId = accounts.isNotEmpty ? accounts.first.id : null;

    final result = await showModalBottomSheet<(ImportTarget, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.importTitle, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(filePath.split('/').last, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 20),
              Text(s.importAs, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ImportTargetSelector(
                selected: target,
                onChanged: (v) => setSheetState(() => target = v),
                compact: true,
              ),
              if (target == ImportTarget.transaction && accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.selectAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setSheetState(() => accountId = v),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, (target, target == ImportTarget.transaction ? accountId : null)),
                  child: Text(s.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final (selectedTarget, selectedAccountId) = result;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportScreen(
          initialFilePath: filePath,
          preselectedTarget: selectedTarget,
          preselectedAccountId: selectedAccountId,
        ),
      ),
    );
  }
}
