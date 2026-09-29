part of 'account_detail_screen.dart';

/// Asks, then deletes [account] with its transactions, and says whether it
/// did. Behind the account's trashcan on its detail screen and the swipe of
/// the accounts list. Pass the live row: the message names the account as it
/// is now.
Future<bool> confirmAndDeleteAccount(BuildContext context, WidgetRef ref, Account account) async {
  final s = ref.read(appStringsProvider);
  final accounts = ref.read(accountServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.deleteAccountTitle,
    content: s.deleteAccountConfirm(account.name),
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    confirmColor: Colors.red,
  );
  if (!confirmed) return false;
  _log.warning('deleting account id=${account.id} name=${account.name}');
  await accounts.delete(account.id);
  return true;
}

extension _AccountDetailTransactionActions on _AccountDetailScreenState {
  /// Turn a POSITIVE transaction into income. A single inflow is often a mix
  /// (salary + expense refund + pension contribution), so the user allocates
  /// each slice in [showIncomeSplitDialog] and one `Income` row per non-zero
  /// slice is written. The dialog only returns balanced plans, so the recorded
  /// rows always add up to the transaction amount.
  Future<void> _flagAsIncome(Transaction tx) async {
    final s = ref.read(appStringsProvider);

    final entries = await showIncomeSplitDialog(
      context,
      title: s.flagAsIncomeTitle,
      total: tx.amount,
      currency: tx.currency,
    );
    if (entries == null || entries.isEmpty) return;

    await ref
        .read(incomeServiceProvider)
        .createSplit(
          date: tx.valueDate,
          currency: tx.currency,
          entries: entries,
        );

    if (mounted) {
      showInfoSnack(
        context,
        entries.length == 1 ? s.incomeFlaggedSnack : s.incomeFlaggedSplitSnack(entries.length),
      );
    }
  }

  /// Open the event-create form pre-seeded for an outflow/spread ("spread
  /// spending") event. The form is pre-populated with the transaction's amount,
  /// currency, date, and description so the user only needs to confirm the
  /// spread window.  Because [resolveAdjustments] matches the anchor by
  /// (dayKey(eventDate), |totalAmount| cents, negative), keeping the pre-filled
  /// date and amount ensures the raw bank transaction is automatically
  /// excluded from All-Accounts totals and replaced by the synthetic saving
  /// schedule rows — no double-count.
  Future<void> _createSpreadSpending(Transaction tx) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditScreen(
          seedName: tx.description,
          seedAmount: tx.amount.abs(),
          seedCurrency: tx.currency,
          seedDate: tx.valueDate,
          seedDirection: EventDirection.outflow,
          seedTreatment: EventTreatment.spread,
        ),
      ),
    );
  }

  /// Mark a NEGATIVE transaction as a manual adjustment against an Inflow
  /// `ExtraordinaryEvent`. The user picks the inflow record (best-match
  /// proposed by smallest |valueDate − eventDate|, currency-equal first).
  /// `addManualEntry` flips the sign for inflow events, so the resulting
  /// entry on the inflow has `+|tx.amount|`.
  Future<void> _flagAsAdjustment(Transaction tx) async {
    final s = ref.read(appStringsProvider);
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final amtFmt = fmt.currencyFormat(locale, tx.currency);
    final service = ref.read(extraordinaryEventServiceProvider);

    // Read once through the service: awaiting extraordinaryEventsProvider
    // never completes on a screen where nothing else listens to it (Riverpod
    // pauses unlistened providers).
    final allEvents = await service.getAll(through: ref.read(waybackDateProvider));
    final inflows = allEvents.where((e) => e.direction == EventDirection.inflow && e.isActive).toList();
    if (inflows.isEmpty) {
      if (mounted) showInfoSnack(context, s.noInflowEventsAvailable);
      return;
    }

    int bestMatchScore(ExtraordinaryEvent e) {
      // Lower is better. Currency mismatch adds a huge penalty so same-currency
      // candidates always win when present.
      final dayDelta = (e.eventDate.difference(tx.valueDate).inDays).abs();
      final currencyPenalty = e.currency == tx.currency ? 0 : 1000000;
      return currencyPenalty + dayDelta;
    }

    inflows.sort((a, b) => bestMatchScore(a).compareTo(bestMatchScore(b)));
    var selectedId = inflows.first.id;
    final dateFmt = fmt.shortDateFormat(locale);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.flagAsAdjustmentTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrivacySentence(s.flagAsAdjustmentBody(privacySlot(0)), figures: [amtFmt.format(tx.amount.abs())]),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.flagAsAdjustmentInflow),
                items: inflows
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '${e.name} · ${e.currency} · ${dateFmt.format(e.eventDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedId = v ?? selectedId),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // An identical manual entry on the same day is usually an accidental
    // re-click (the badge used to appear only after a restart, which made
    // repeat clicks likely). Two identical same-day drawdowns are legitimate
    // though, so confirm rather than block.
    final duplicates = await service.countIdenticalManualEntries(
      eventId: selectedId,
      date: tx.valueDate,
      amount: tx.amount.abs(),
    );
    if (duplicates > 0) {
      if (!mounted) return;
      final addAnyway = await showConfirmDialog(
        context,
        title: s.duplicateAdjustmentTitle,
        content: s.duplicateAdjustmentBody(duplicates, privacySlot(0)),
        maskedFigures: [amtFmt.format(tx.amount.abs())],
        confirmLabel: s.addAnyway,
        cancelLabel: s.cancel,
      );
      if (!addAnyway) return;
    }

    await service.addManualEntry(
      eventId: selectedId,
      date: tx.valueDate,
      amount: tx.amount.abs(),
      description: tx.description,
    );

    if (mounted) {
      showInfoSnack(context, s.adjustmentFlaggedSnack);
    }
  }

  Future<void> _confirmWipeTransactions(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final txCount = ref.read(accountTransactionsProvider(widget.account.id)).value?.length ?? 0;
    if (txCount == 0) {
      showInfoSnack(context, s.noTransactionsToWipe);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: s.wipeAllTransactionsTitle,
      content: '${s.wipeTransactionsBody(_liveAccount(ref.read(accountsProvider).value).name)}${s.cannotBeUndone}',
      confirmLabel: s.wipe,
      cancelLabel: s.cancel,
      confirmColor: Colors.orange,
    );
    if (confirmed) {
      _log.warning('wiping transactions for account ${widget.account.id}');
      final deleted = await ref.read(transactionServiceProvider).deleteByAccount(widget.account.id);
      if (context.mounted) {
        showInfoSnack(context, s.wipedTransactions(deleted));
      }
    }
  }

  /// The trashcan: once the account is deleted, its screen is left.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    if (await confirmAndDeleteAccount(context, ref, _liveAccount(ref.read(accountsProvider).value)) && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _editAccount(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditAccountDialog(account: _liveAccount(ref.read(accountsProvider).value)),
    );
  }

  /// Open the import wizard on the rows rebuilt from this account's stored
  /// statement columns, so the mapping can be changed and the import re-run
  /// without the original file.
  Future<void> _rerunImportFromStored(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final importer = ref.read(importServiceProvider);
    final config = await ref.read(importConfigServiceProvider).getByAccount(widget.account.id);
    final preview = await importer.previewFromStoredRows(widget.account.id, numberLocale: config?.numberLocale);
    if (!context.mounted) return;
    if (preview == null) {
      showInfoSnack(context, s.rerunImportNoStoredRows);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportScreen(preselectedAccountId: widget.account.id, storedPreview: preview),
      ),
    );
  }

  /// Bulk "Set category" on the current multi-selection.
  Future<void> _bulkSetCategory(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final ids = _selection.ids.toList();
    if (ids.isEmpty) return;
    final pick = await showCategoryPicker(context);
    if (pick == null) return;
    final n = await ref.read(transactionClassifierServiceProvider).setCategory(ids, pick.categoryId);
    _selection.clear();
    if (context.mounted) showInfoSnack(context, s.setCategoryCount(n));
  }
}

/// The Edit account form, pre-filled from [account] (the live row). Owns its
/// text controllers and disposes them only once the dialog is gone: disposing
/// them as soon as the dialog returned broke its closing animation, which
/// still rebuilds the fields. Saves at most once: Save is off while it runs.
class _EditAccountDialog extends ConsumerStatefulWidget {
  final Account account;
  const _EditAccountDialog({required this.account});

  @override
  ConsumerState<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<_EditAccountDialog> {
  late final _nameCtrl = TextEditingController(text: widget.account.name);
  late final _currencyCtrl = TextEditingController(text: widget.account.currency);
  late final _institutionCtrl = TextEditingController(text: widget.account.institution);
  late var _isActive = widget.account.isActive;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _institutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(accountServiceProvider)
          .update(
            widget.account.id,
            AccountsCompanion(
              name: Value(_nameCtrl.text.trim()),
              currency: Value(_currencyCtrl.text.trim()),
              institution: Value(_institutionCtrl.text.trim()),
              isActive: Value(_isActive),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(s.editAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.name),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currencyCtrl,
              decoration: InputDecoration(labelText: s.currency, hintText: 'EUR'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _institutionCtrl,
              decoration: InputDecoration(labelText: s.institution),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(s.active),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
