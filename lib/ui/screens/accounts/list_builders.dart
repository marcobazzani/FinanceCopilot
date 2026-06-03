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
    final transferOfTx = <int, _TransferEntry>{};

    // Bucket by (day, currency, |amount in cents|).
    final buckets = <String, ({List<Transaction> pos, List<Transaction> neg})>{};
    for (final t in filtered) {
      if (t.amount == 0) continue;
      final cents = (t.amount.abs() * 100).round();
      final k = '${dayKey(t.valueDate)}|${t.currency}|$cents';
      final bucket = buckets[k] ?? (pos: <Transaction>[], neg: <Transaction>[]);
      if (t.amount > 0) {
        bucket.pos.add(t);
      } else {
        bucket.neg.add(t);
      }
      buckets[k] = bucket;
    }
    for (final bucket in buckets.values) {
      final pos = bucket.pos;
      final neg = bucket.neg;
      if (pos.isEmpty || neg.isEmpty) continue;
      // Greedy pair: each positive consumes the first available negative
      // belonging to a different account.
      final consumedNeg = <int>{};
      for (final p in pos) {
        Transaction? match;
        for (final n in neg) {
          if (consumedNeg.contains(n.id)) continue;
          if (n.accountId == p.accountId) continue;
          match = n;
          break;
        }
        if (match == null) continue;
        consumedNeg.add(match.id);
        final pair = _TransferEntry(inflow: p, outflow: match);
        transferOfTx[p.id] = pair;
        transferOfTx[match.id] = pair;
      }
    }

    final result = <_Entry>[];
    final emitted = <_TransferEntry>{};
    for (final t in filtered) {
      final pair = transferOfTx[t.id];
      if (pair != null) {
        if (emitted.add(pair)) result.add(pair);
      } else {
        result.add(_TxEntry(t));
      }
    }
    // Silence the unused warning for txById in release builds.
    assert(txById.isNotEmpty);
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
  }) {
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
      title: Text(
        tx.description.isNotEmpty ? tx.description : s.noDescription,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
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
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              fontSize: 14,
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
