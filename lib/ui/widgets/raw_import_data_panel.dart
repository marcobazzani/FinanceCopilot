import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/services/import/stored_import_data.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

/// Read-only panel with the source cells an imported row was built from:
/// `rawMetadata`, a JSON object of column name → cell text. Shared by the
/// transaction and asset event edit screens.
///
/// Privacy mode masks every cell VALUE — raw amounts, balances and
/// quantities reveal the position size, and a free-form column cannot be told
/// apart from them — while the column names stay readable.
class RawImportDataPanel extends ConsumerWidget {
  final String rawMetadata;

  const RawImportDataPanel(this.rawMetadata, {super.key});

  static const _cellStyle = TextStyle(fontSize: 11, fontFamily: 'monospace');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final cells = decodeRawMetadata(rawMetadata);
    return Column(
      key: const Key('rawImportData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(s.rawImportData, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: cells == null
              // Not a column → cell object: names cannot be told from values.
              ? PrivacyText(rawMetadata, style: _cellStyle)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cell in cells.entries)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${cell.key}: ', style: _cellStyle),
                          Expanded(child: PrivacyText('${cell.value ?? ''}', style: _cellStyle)),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
