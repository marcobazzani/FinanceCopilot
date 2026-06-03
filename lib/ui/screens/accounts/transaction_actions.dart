part of 'account_detail_screen.dart';

extension _AccountDetailTransactionActions on _AccountDetailScreenState {
  Future<void> _flagAsIncome(Transaction tx) async {
    final s = ref.read(appStringsProvider);
    var selectedType = IncomeType.income;

    String typeLabel(IncomeType t) => switch (t) {
      IncomeType.income => s.incomeTypeIncome,
      IncomeType.refund => s.incomeTypeRefund,
      IncomeType.pensionContribution => s.incomeTypePensionContribution,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.flagAsIncomeTitle),
          content: DropdownButtonFormField<IncomeType>(
            initialValue: selectedType,
            decoration: InputDecoration(labelText: s.incomeTypeLabel),
            items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(typeLabel(t)))).toList(),
            onChanged: (v) => setDialogState(() => selectedType = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(incomeServiceProvider)
        .create(
          date: tx.valueDate,
          amount: tx.amount,
          type: selectedType,
          currency: tx.currency,
        );

    if (mounted) {
      showInfoSnack(context, s.incomeFlaggedSnack);
    }
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

    final allEvents = await ref.read(extraordinaryEventsProvider.future);
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
              Text(s.flagAsAdjustmentBody(amtFmt.format(tx.amount.abs()))),
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

    await ref
        .read(extraordinaryEventServiceProvider)
        .addManualEntry(
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
      content: '${s.wipeTransactionsBody(widget.account.name)}${s.cannotBeUndone}',
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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteAccountTitle,
      content: s.deleteAccountConfirm(widget.account.name),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );
    if (confirmed) {
      _log.warning('deleting account id=${widget.account.id} name=${widget.account.name}');
      await ref.read(accountServiceProvider).delete(widget.account.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _editAccount(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: widget.account.name);
    var currencyCtrl = TextEditingController(text: widget.account.currency);
    var institutionCtrl = TextEditingController(text: widget.account.institution);
    var isActive = widget.account.isActive;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(s.editAccountTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: s.name),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currencyCtrl,
                    decoration: InputDecoration(labelText: s.currency, hintText: 'EUR'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: institutionCtrl,
                    decoration: InputDecoration(labelText: s.institution),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(s.active),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await ref
                      .read(accountServiceProvider)
                      .update(
                        widget.account.id,
                        AccountsCompanion(
                          name: Value(nameCtrl.text.trim()),
                          currency: Value(currencyCtrl.text.trim()),
                          institution: Value(institutionCtrl.text.trim()),
                          isActive: Value(isActive),
                          updatedAt: Value(DateTime.now()),
                        ),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(s.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
      currencyCtrl.dispose();
      institutionCtrl.dispose();
    }
  }
}
