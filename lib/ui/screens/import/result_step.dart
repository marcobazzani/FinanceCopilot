part of 'import_screen.dart';

// ──────────────────────────────────────────────
// Step 3: Result
// ──────────────────────────────────────────────

extension _ResultStep on _ImportScreenState {

  Widget _buildResult() {
    final r = _result!;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                r.errorRows == 0 ? Icons.check_circle : Icons.warning,
                size: 64,
                color: r.errorRows == 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text('Import Complete', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _resultRow('Total rows', '${r.totalRows}'),
              _resultRow('Imported', '${r.importedRows}', color: Colors.green),
              if (r.deletedRows > 0) _resultRow('Replaced (overlap)', '${r.deletedRows}', color: Colors.orange),
              if (r.errorRows > 0) _resultRow('Skipped', '${r.errorRows}', color: Colors.red),
              if (r.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...r.errors.take(5).map((e) => Text(e, style: const TextStyle(fontSize: 12, color: Colors.red))),
                if (r.errors.length > 5) Text('... and ${r.errors.length - 5} more', style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => _setState(() {
                      _reset();
                      _step = 1;
                    }),
                    child: const Text('Import Another'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 180, child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
