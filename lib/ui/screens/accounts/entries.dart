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

/// Two equal and opposite legs shown as one expandable row ([_PairTile]).
sealed class _PairEntry extends _Entry {
  final Transaction inflow; // amount > 0
  final Transaction outflow; // amount < 0
  _PairEntry({required this.inflow, required this.outflow});
  @override
  DateTime get valueDate => outflow.valueDate;
  String get currency => inflow.currency;
  double get absAmount => inflow.amount.abs();
}

/// A same-day transfer between two accounts (merged All-accounts view only).
class _TransferEntry extends _PairEntry {
  _TransferEntry({required super.inflow, required super.outflow});
}

/// A synthetic "Saving for `<event>`" ledger row materialized from a spread
/// event's scheduled amortization entry (no matching real transaction).
/// Shown and counted in totals — mirrors NAV distributing the CAPEX over time.
class _AdjustmentEntry extends _Entry {
  final DateTime date;
  final double amount; // signed
  final String eventName;

  /// The spread event's currency.
  final String currency;
  _AdjustmentEntry({required this.date, required this.amount, required this.eventName, required this.currency});
  @override
  DateTime get valueDate => date;
}

/// A same-account, same-day, equal-and-opposite pair (`+X` and `-X`) that nets
/// to zero — e.g. a charge that was reversed / money round-tripped. Collapses
/// the two legs into one row, kept visible but excluded from income/expense
/// totals (it moved no net money).
class _NoOpEntry extends _PairEntry {
  _NoOpEntry({required super.inflow, required super.outflow});
}

/// Collapsed row of a [_PairEntry], expandable to show both legs: a transfer
/// (accent colour, "from to") or a no-op (muted, amount struck through — it
/// moved no money). Give it a key per pair: the expanded state belongs to the
/// pair, not to the list position.
class _PairTile extends StatefulWidget {
  final _PairEntry entry;
  final Map<int, String> accountNameById;
  final String locale;
  final AppStrings s;

  /// Builds the row for a single leg of the pair using the same widget as
  /// regular transactions, so the expanded view is visually identical to the
  /// rest of the list.
  final Widget Function(Transaction) legTileBuilder;
  const _PairTile({
    super.key,
    required this.entry,
    required this.accountNameById,
    required this.locale,
    required this.s,
    required this.legTileBuilder,
  });

  @override
  State<_PairTile> createState() => _PairTileState();
}

class _PairTileState extends State<_PairTile> {
  bool _expanded = false;

  String _accountName(int id) => widget.accountNameById[id] ?? '#$id';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final s = widget.s;
    final amtFmt = fmt.currencyFormat(widget.locale, entry.currency);
    final dateFmt = fmt.shortDateFormat(widget.locale);
    final isNoOp = entry is _NoOpEntry;
    final (icon, label, accent) = switch (entry) {
      _TransferEntry() => (Icons.swap_horiz, s.transferLabel, scheme.primary),
      _NoOpEntry() => (Icons.sync_alt, s.noOpLabel, scheme.onSurfaceVariant),
    };
    final date = Text(dateFmt.format(entry.valueDate), style: const TextStyle(fontSize: 12));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Icon(icon, size: 16, color: accent),
          ),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: isNoOp
              ? date
              : Row(
                  children: [
                    date,
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.transferFromTo(_accountName(entry.outflow.accountId), _accountName(entry.inflow.accountId)),
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
                  color: accent,
                  fontSize: 14,
                  decoration: isNoOp ? TextDecoration.lineThrough : null,
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

/// Row for a synthetic "Saving for `<event>`" adjustment (scheduled spread).
/// Stateless, visible, counted in totals. Marked with a distinct badge.
class _AdjustmentTile extends StatelessWidget {
  final _AdjustmentEntry entry;
  final String locale;
  final AppStrings s;
  const _AdjustmentTile({required this.entry, required this.locale, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amtFmt = fmt.currencyFormat(locale, entry.currency);
    final dateFmt = fmt.shortDateFormat(locale);
    final isPositive = entry.amount >= 0;
    final accent = scheme.tertiary;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: accent.withValues(alpha: 0.12),
        child: Icon(Icons.savings_outlined, size: 16, color: accent),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              s.savingForLabel(entry.eventName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              s.adjustmentBadge,
              style: TextStyle(fontSize: 10, color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
      subtitle: Text(dateFmt.format(entry.valueDate), style: const TextStyle(fontSize: 12)),
      trailing: PrivacyText(
        '${isPositive ? '+' : ''}${amtFmt.format(entry.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          fontSize: 14,
        ),
      ),
    );
  }
}
