import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/dialogs.dart';
import '../../../utils/formatters.dart' as fmt;
import '../../widgets/privacy_text.dart';

class RebalancePreviewDialog extends ConsumerStatefulWidget {
  final String pillarId;
  final PortfolioRebalanceScopeKind initialScopeKind;

  const RebalancePreviewDialog({
    super.key,
    required this.pillarId,
    this.initialScopeKind = PortfolioRebalanceScopeKind.currentPillar,
  });

  @override
  ConsumerState<RebalancePreviewDialog> createState() => _RebalancePreviewDialogState();
}

class _RebalancePreviewDialogState extends ConsumerState<RebalancePreviewDialog> {
  PortfolioRebalanceMode _mode = PortfolioRebalanceMode.sellAndBuy;
  late final TextEditingController _contribution;

  /// Null while the buy-only contribution cannot be read: nothing is planned.
  Stream<PortfolioRebalanceDraft>? _draftStream;

  /// True from the Apply tap until the draft is booked (or the confirmation
  /// is declined): a second Apply meanwhile would book the trades twice.
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _contribution = TextEditingController();
    _draftStream = _buildDraftStream();
  }

  @override
  void dispose() {
    _contribution.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
    return AlertDialog(
      title: Text(s.rebalanceTitle),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SegmentedButton<PortfolioRebalanceMode>(
                    segments: [
                      ButtonSegment(
                        value: PortfolioRebalanceMode.sellAndBuy,
                        label: Text(s.rebalanceSellAndBuy),
                      ),
                      ButtonSegment(
                        value: PortfolioRebalanceMode.buyOnly,
                        label: Text(s.rebalanceBuyOnly),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) {
                      setState(() {
                        _mode = value.first;
                        _draftStream = _buildDraftStream();
                      });
                    },
                  ),
                ],
              ),
              if (_mode == PortfolioRebalanceMode.buyOnly) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _contribution,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.rebalanceContribution,
                    errorText: _contributionAmount(locale) == null ? s.invalidNumber : null,
                  ),
                  onChanged: (_) {
                    setState(() {
                      _draftStream = _buildDraftStream();
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              if (_draftStream != null)
                StreamBuilder<PortfolioRebalanceDraft>(
                  stream: _draftStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(s.error(snapshot.error!)));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final draft = snapshot.data!;
                    final isUpdating = snapshot.connectionState != ConnectionState.done;
                    return _DraftView(
                      draft: draft,
                      locale: locale,
                      s: s,
                      isUpdating: isUpdating,
                      onApply: !isUpdating && !_applying && draft.hasExecutableTrades ? () => _applyDraft(context, draft) : null,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
      ],
    );
  }

  /// The typed contribution: 0 when empty, null when [locale] cannot read it.
  double? _contributionAmount(String locale) {
    final typed = fmt.readOptionalNumber(_contribution.text, locale: locale);
    return typed.invalid ? null : typed.value ?? 0;
  }

  Stream<PortfolioRebalanceDraft>? _buildDraftStream() {
    final locale = ref.read(appLocaleProvider).value ?? 'en';
    final contribution = _contributionAmount(locale);
    // Buy-only plans the contribution: one the locale cannot read is flagged
    // on the field and plans nothing, never a plan for 0.
    if (_mode == PortfolioRebalanceMode.buyOnly && contribution == null) return null;
    final scope = widget.initialScopeKind == PortfolioRebalanceScopeKind.currentPillar
        ? PortfolioRebalanceScope.currentPillar(widget.pillarId)
        : const PortfolioRebalanceScope.allAssociatedPillars();
    return ref
        .read(portfolioRebalanceServiceProvider)
        .buildDraftStream(
          scope: scope,
          mode: _mode,
          // Sell-and-buy takes no contribution (its field is hidden).
          contributionAmount: contribution ?? 0,
        );
  }

  Future<void> _applyDraft(BuildContext context, PortfolioRebalanceDraft draft) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final s = ref.read(appStringsProvider);
      final confirm = await showConfirmDialog(
        context,
        title: s.rebalanceApplyConfirmTitle,
        content: s.rebalanceApplyConfirmBody,
        confirmLabel: s.rebalanceApplyDraft,
        cancelLabel: s.cancel,
      );
      if (!confirm) return;
      await ref
          .read(portfolioRebalanceServiceProvider)
          .applyDraft(
            draft,
            ref.read(assetEventServiceProvider),
          );
      if (context.mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}

class _DraftView extends StatelessWidget {
  final PortfolioRebalanceDraft draft;
  final String locale;
  final AppStrings s;
  final bool isUpdating;
  final VoidCallback? onApply;

  const _DraftView({
    required this.draft,
    required this.locale,
    required this.s,
    required this.isUpdating,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final amountFormat = fmt.amountFormat(locale);
    final quantityFormat = NumberFormat('#,##0', locale);
    final weightFormat = NumberFormat('0.00', locale);
    String percent(double value, double total) {
      if (total <= 0) return weightFormat.format(0);
      return weightFormat.format(value / total * 100.0);
    }

    final cashLabel = draft.mode == PortfolioRebalanceMode.sellAndBuy ? s.rebalanceCashAfterSales : s.rebalanceAvailableCash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.rebalanceWholeUnitsOnly,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryMetric(
                      label: cashLabel,
                      value: '${amountFormat.format(draft.availableCashBase)} ${draft.baseCurrency}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.blue,
                    ),
                    _SummaryMetric(
                      label: s.rebalanceExecutedBuy,
                      value: '${amountFormat.format(draft.executedBuyBase)} ${draft.baseCurrency}',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    _SummaryMetric(
                      label: s.rebalanceEstimatedTax,
                      value: '${amountFormat.format(draft.estimatedTax)} ${draft.baseCurrency}',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.red,
                    ),
                    if (draft.leftoverCashBase > 0.01)
                      _SummaryMetric(
                        label: s.rebalanceCashRemaining,
                        value: '${amountFormat.format(draft.leftoverCashBase)} ${draft.baseCurrency}',
                        icon: Icons.savings_outlined,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (draft.unresolved.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(s.portfolioUnresolvedRows, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final row in draft.unresolved)
            ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(row.assetName ?? row.isin ?? row.pillarName ?? s.invalid),
              subtitle: Text(_reason(s, row.reason)),
            ),
        ],
        if (isUpdating) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 3,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          Text(s.rebalanceUpdatingMarketData, style: Theme.of(context).textTheme.labelMedium),
        ],
        const SizedBox(height: 12),
        Text(s.rebalanceDraftRows, style: Theme.of(context).textTheme.titleSmall),
        if (draft.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.rebalanceNoTrades),
          )
        else
          for (final row in draft.rows)
            ListTile(
              dense: true,
              leading: _tradeBadge(s, row),
              title: Text(row.isPlaceholder ? '${row.assetName} · ${s.rebalanceTargetPlaceholder}' : row.assetName),
              subtitle: Builder(
                builder: (context) {
                  // Trade amount, quantity and tax are position size (masked
                  // in privacy mode); the before → after weights are shape.
                  final taxText = row.estimatedTax > 0 ? ' · ${s.rebalanceEstimatedTax}: ${privacySlot(2)}' : '';
                  final quantityText = row.isPlaceholder ? s.rebalanceNotExecutable : '${s.rebalanceQuantity}: ${privacySlot(1)}';
                  return PrivacySentence(
                    '${privacySlot(0)} · '
                    '$quantityText'
                    ' · ${percent(row.currentBaseValue, draft.currentPortfolioValueBase)}% → ${percent(row.projectedBaseValue, draft.projectedPortfolioValueBase)}%'
                    '$taxText',
                    figures: [
                      '${amountFormat.format(row.baseAmount)} ${draft.baseCurrency}',
                      quantityFormat.format(row.estimatedQuantity),
                      '${amountFormat.format(row.estimatedTax)} ${draft.baseCurrency}',
                    ],
                  );
                },
              ),
            ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(s.rebalanceApplyDraft),
            onPressed: onApply,
          ),
        ),
      ],
    );
  }

  String _reason(AppStrings s, PortfolioRebalanceUnresolvedReason reason) => switch (reason) {
    PortfolioRebalanceUnresolvedReason.missingModel => s.rebalanceMissingModel,
    PortfolioRebalanceUnresolvedReason.missingCurrentQuantity => s.rebalanceMissingQuantity,
    PortfolioRebalanceUnresolvedReason.missingMarketPrice => s.rebalanceMissingPrice,
    PortfolioRebalanceUnresolvedReason.missingFxRate => s.rebalanceMissingFx,
    PortfolioRebalanceUnresolvedReason.missingCostBasisFx => s.rebalanceMissingCostFx,
    PortfolioRebalanceUnresolvedReason.missingIsin => s.rebalanceMissingIsin,
    PortfolioRebalanceUnresolvedReason.unmatchedModelItem => s.rebalanceUnmatchedModelItem,
  };

  Widget _tradeBadge(AppStrings s, PortfolioRebalanceDraftRow row) {
    if (row.isPlaceholder) {
      return Semantics(
        label: s.rebalanceTargetPlaceholder,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add_box_outlined, color: Colors.orange.shade700, size: 18),
        ),
      );
    }
    final type = row.type;
    final isBuy = type == EventType.buy;
    final bg = isBuy ? Colors.green.withValues(alpha: 0.14) : Colors.red.withValues(alpha: 0.14);
    final fg = isBuy ? Colors.green.shade800 : Colors.red.shade700;
    return Semantics(
      label: isBuy ? s.rebalanceBuy : s.rebalanceSell,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(isBuy ? Icons.add_shopping_cart : Icons.sell_outlined, color: fg, size: 18),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 164,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          // Cash, buys and taxes of the draft are position size.
          PrivacyText(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
