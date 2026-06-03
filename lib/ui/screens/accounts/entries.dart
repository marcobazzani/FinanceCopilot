part of 'account_detail_screen.dart';

sealed class _Entry {
  DateTime get valueDate;
}

class _TxEntry extends _Entry {
  final Transaction tx;
  _TxEntry(this.tx);
  @override
  DateTime get valueDate => tx.valueDate;
}

class _TransferEntry extends _Entry {
  final Transaction inflow; // amount > 0
  final Transaction outflow; // amount < 0
  _TransferEntry({required this.inflow, required this.outflow});
  @override
  DateTime get valueDate => outflow.valueDate;
  String get currency => inflow.currency;
  double get absAmount => inflow.amount.abs();
}

class _TransferTile extends StatefulWidget {
  final _TransferEntry entry;
  final Map<int, String> accountNameById;
  final String locale;
  final AppStrings s;

  /// Builds the row for a single leg of the transfer using the same widget as
  /// regular transactions, so the expanded view is visually identical to the
  /// rest of the list.
  final Widget Function(Transaction) legTileBuilder;
  const _TransferTile({
    required this.entry,
    required this.accountNameById,
    required this.locale,
    required this.s,
    required this.legTileBuilder,
  });

  @override
  State<_TransferTile> createState() => _TransferTileState();
}

class _TransferTileState extends State<_TransferTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final s = widget.s;
    final amtFmt = fmt.currencyFormat(widget.locale, entry.currency);
    final dateFmt = fmt.shortDateFormat(widget.locale);
    final fromName = widget.accountNameById[entry.outflow.accountId] ?? '#${entry.outflow.accountId}';
    final toName = widget.accountNameById[entry.inflow.accountId] ?? '#${entry.inflow.accountId}';
    final blue = scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: blue.withValues(alpha: 0.12),
            child: Icon(Icons.swap_horiz, size: 16, color: blue),
          ),
          title: Text(
            s.transferLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              Text(dateFmt.format(entry.valueDate), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.transferFromTo(fromName, toName),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrivacyText(
                amtFmt.format(entry.absAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: blue,
                  fontSize: 14,
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      widget.legTileBuilder(entry.outflow),
                      const Divider(height: 1),
                      widget.legTileBuilder(entry.inflow),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
