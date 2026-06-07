part of 'account_detail_screen.dart';

extension _AccountDetailListBuilders on _AccountDetailScreenState {
  List<_Entry> _buildEntries({
    required List<Transaction> filtered,
    required bool detectTransfers,
    required int Function(DateTime) dayKey,
  }) {
    if (!detectTransfers || filtered.length < 2) {
      return [for (final t in filtered) _TxEntry(t)];
    }

    final txById = <int, Transaction>{for (final t in filtered) t.id: t};

    // Deterministic pairing (cross-account transfers first, then same-account
    // no-ops) lives in a pure, unit-tested helper.
    final pairing = pairTransactions(filtered, dayKey);
    final transferOfTx = <int, _TransferEntry>{};
    for (final p in pairing.transfers) {
      final entry = _TransferEntry(inflow: txById[p.inflowId]!, outflow: txById[p.outflowId]!);
      transferOfTx[p.inflowId] = entry;
      transferOfTx[p.outflowId] = entry;
    }
    final noOpOfTx = <int, _NoOpEntry>{};
    for (final p in pairing.noOps) {
      final entry = _NoOpEntry(inflow: txById[p.inflowId]!, outflow: txById[p.outflowId]!);
      noOpOfTx[p.inflowId] = entry;
      noOpOfTx[p.outflowId] = entry;
    }

    final result = <_Entry>[];
    final emitted = <_Entry>{};
    for (final t in filtered) {
      final transfer = transferOfTx[t.id];
      final noOp = noOpOfTx[t.id];
      if (transfer != null) {
        if (emitted.add(transfer)) result.add(transfer);
      } else if (noOp != null) {
        if (emitted.add(noOp)) result.add(noOp);
      } else {
        result.add(_TxEntry(t));
      }
    }
    return result;
  }

  Widget _buildTxTile({
    required BuildContext context,
    required Transaction tx,
    required bool isPositive,
    required dynamic rowAmtFmt,
    required dynamic dateFmt,
    required Map<int, String> accountNameById,
    required AppStrings s,
    String? adjustedLabel,
  }) {
    final isCancelled = tx.status == TransactionStatus.cancelled;
    final tile = ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        child: Icon(
          isPositive ? Icons.arrow_downward : Icons.arrow_upward,
          size: 16,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              tx.description.isNotEmpty ? tx.description : s.noDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
                color: isCancelled ? Theme.of(context).disabledColor : null,
              ),
            ),
          ),
          if (isCancelled) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                s.cancelledLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          if (adjustedLabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                adjustedLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: _isReadOnly
          ? Row(
              children: [
                Text(dateFmt.format(tx.valueDate), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      accountNameById[tx.accountId] ?? '#${tx.accountId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            )
          : Text(dateFmt.format(tx.valueDate), style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrivacyText(
            '${isPositive ? '+' : ''}${rowAmtFmt.format(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCancelled ? Theme.of(context).disabledColor : (isPositive ? Colors.green.shade700 : Colors.red.shade700),
              fontSize: 14,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          if (!_isReadOnly) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              iconSize: 18,
              padding: EdgeInsets.zero,
              tooltip: isPositive ? s.flagAsIncomeTooltip : s.flagAsAdjustmentTooltip,
              itemBuilder: (_) => [
                if (isPositive)
                  PopupMenuItem(
                    value: 'flag_income',
                    child: Row(
                      children: [
                        const Icon(Icons.label_important_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(s.flagAsIncomeTooltip),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'flag_adjustment',
                    child: Row(
                      children: [
                        const Icon(Icons.compare_arrows, size: 18),
                        const SizedBox(width: 8),
                        Text(s.flagAsAdjustmentTooltip),
                      ],
                    ),
                  ),
              ],
              onSelected: (v) {
                if (v == 'flag_income') _flagAsIncome(tx);
                if (v == 'flag_adjustment') _flagAsAdjustment(tx);
              },
            ),
          ],
        ],
      ),
      onTap: _isReadOnly ? null : () => _openTransaction(tx),
    );
    return _isReadOnly
        ? tile
        : SelectableItem<int>(
            controller: _selection,
            id: tx.id,
            child: tile,
          );
  }

  void _openTransaction(Transaction tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(
          transaction: tx,
          account: widget.account,
        ),
      ),
    );
  }

  void _addTransaction() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(account: widget.account),
      ),
    );
  }
}
