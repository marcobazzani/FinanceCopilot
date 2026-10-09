import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/services/import/import_service.dart' show ImportTarget;
import 'package:finance_copilot/services/providers/providers.dart';

/// The "Import as" choice between transactions, asset events and income: the
/// one selector the import wizard and the share-to-app sheet both show.
class ImportTargetSelector extends ConsumerWidget {
  final ImportTarget selected;
  final ValueChanged<ImportTarget> onChanged;

  /// Compact density, for a bottom sheet.
  final bool compact;

  const ImportTargetSelector({super.key, required this.selected, required this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    ButtonSegment<ImportTarget> segment(ImportTarget value, IconData icon, String label) => ButtonSegment(
      value: value,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
    return SegmentedButton<ImportTarget>(
      segments: [
        segment(ImportTarget.transaction, Icons.receipt_long, s.importTypeTransaction),
        segment(ImportTarget.assetEvent, Icons.trending_up, s.importTypeAssetEvent),
        segment(ImportTarget.income, Icons.payments, s.importTypeIncome),
      ],
      selected: {selected},
      onSelectionChanged: (v) => onChanged(v.first),
      style: compact ? const ButtonStyle(visualDensity: VisualDensity.compact) : null,
      showSelectedIcon: false,
    );
  }
}
