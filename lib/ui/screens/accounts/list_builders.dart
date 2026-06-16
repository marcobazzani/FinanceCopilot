part of 'account_detail_screen.dart';

extension _AccountDetailListBuilders on _AccountDetailScreenState {
  /// Single source of truth for the rendered ledger: applies text search,
  /// collapses no-op/transfer pairs, resolves event adjustments, merges
  /// synthetic saving rows (merged view only), then applies the structured
  /// kind/date/amount filter. Used by both the rendered list and the
  /// selection ("select all") id snapshot so they never diverge.
  ({List<_Entry> entries, Map<int, String> annotatedTxIds}) _composeEntries(
    List<Transaction> transactions, {
    required AdjustmentInputs? adjInputs,
    required AppStrings s,
  }) {
    int dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

    // Text constraints (contains / doesn't-contain) apply to the raw
    // transactions before pairing/collapsing, over the same searchable fields
    // as before (description + full description + amount).
    final searched = !_filter.hasTextFilter
        ? transactions
        : transactions.where((t) {
            return _filter.textMatches('${t.description} ${t.descriptionFull ?? ''} ${t.amount}');
          }).toList();

    final txEntries = _buildEntries(
      filtered: searched,
      detectTransfers: _isReadOnly,
      detectNoOps: true,
      dayKey: dayKey,
    );

    final AdjustmentResolution? adj = (adjInputs != null)
        ? resolveAdjustments(
            events: adjInputs.events,
            entriesByEvent: adjInputs.entriesByEvent,
            reimbursementsByEvent: adjInputs.reimbursementsByEvent,
            transactions: searched,
            dayKey: dayKey,
            adjustedLabel: s.adjustedForLabel,
            reimbLabel: s.reimbForLabel,
            savingForLabel: s.savingForLabel,
            financedLabel: s.financedForLabel,
          )
        : null;
    final annotatedTxIds = adj?.annotatedTxIds ?? const <int, String>{};

    // Synthetic "Saving for X" spread rows: merged All-accounts view only
    // (no account). Insert by date (desc), preserving same-day order.
    final savingEntries = <_AdjustmentEntry>[
      if (adj != null && _isReadOnly)
        for (final item in adj.savingItems) _AdjustmentEntry(date: item.date, amount: item.amount, eventName: item.eventName),
    ];
    final List<_Entry> allEntries;
    if (savingEntries.isEmpty) {
      allEntries = txEntries;
    } else {
      final merged = List<_Entry>.of(txEntries);
      for (final se in savingEntries) {
        var idx = merged.indexWhere((e) => e.valueDate.isBefore(se.valueDate));
        if (idx < 0) idx = merged.length;
        merged.insert(idx, se);
      }
      allEntries = merged;
    }

    // Kind/date/amount filtering runs on the composed rows (text was already
    // applied above). Skip the pass entirely when no per-row filter is set.
    final entries = _filter.hasRowFilter
        ? allEntries.where((e) => _filter.matches(_entryKinds(e, annotatedTxIds), e.valueDate, _entryAmount(e))).toList()
        : allEntries;

    return (entries: entries, annotatedTxIds: annotatedTxIds);
  }

  /// Classifies a display [_Entry] to its set of [EntryKind]s for filtering.
  /// Collapsed pairs are a single kind; a standalone transaction carries its
  /// sign/cancelled kinds plus [EntryKind.adjustment] when annotated (an
  /// adjustment may itself be an inflow or an outflow).
  Set<EntryKind> _entryKinds(_Entry e, Map<int, String> annotatedTxIds) {
    return switch (e) {
      _TransferEntry() => {EntryKind.transfer},
      _NoOpEntry() => {EntryKind.noOp},
      // Synthetic saving rows ARE adjustments and also count as an in/outflow
      // by sign (they distribute the spread over time).
      _AdjustmentEntry(:final amount) => {
        EntryKind.adjustment,
        if (amount > 0) EntryKind.inflow else if (amount < 0) EntryKind.outflow,
      },
      _TxEntry(:final tx) => {
        ...classifyTransactionKinds(tx),
        if (annotatedTxIds.containsKey(tx.id)) EntryKind.adjustment,
      },
    };
  }

  /// The representative amount used for amount-range filtering. Collapsed
  /// pairs use their absolute pair amount; single rows use the signed amount.
  double _entryAmount(_Entry e) {
    return switch (e) {
      _TransferEntry(:final absAmount) => absAmount,
      _NoOpEntry(:final absAmount) => absAmount,
      _AdjustmentEntry(:final amount) => amount,
      _TxEntry(:final tx) => tx.amount,
    };
  }

  List<_Entry> _buildEntries({
    required List<Transaction> filtered,
    required bool detectTransfers,
    required bool detectNoOps,
    required int Function(DateTime) dayKey,
  }) {
    if ((!detectTransfers && !detectNoOps) || filtered.length < 2) {
      return [for (final t in filtered) _TxEntry(t)];
    }

    final txById = <int, Transaction>{for (final t in filtered) t.id: t};

    // Deterministic pairing (cross-account transfers first, then same-account
    // no-ops) lives in a pure, unit-tested helper. Transfers require two
    // accounts' data, so they are only applied in the merged All-Accounts
    // view; no-ops are same-account and apply in single-account view too.
    final pairing = pairTransactions(filtered, dayKey);
    final transferOfTx = <int, _TransferEntry>{};
    if (detectTransfers) {
      for (final p in pairing.transfers) {
        final entry = _TransferEntry(inflow: txById[p.inflowId]!, outflow: txById[p.outflowId]!);
        transferOfTx[p.inflowId] = entry;
        transferOfTx[p.outflowId] = entry;
      }
    }
    final noOpOfTx = <int, _NoOpEntry>{};
    if (detectNoOps) {
      for (final p in pairing.noOps) {
        final entry = _NoOpEntry(inflow: txById[p.inflowId]!, outflow: txById[p.outflowId]!);
        noOpOfTx[p.inflowId] = entry;
        noOpOfTx[p.outflowId] = entry;
      }
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
