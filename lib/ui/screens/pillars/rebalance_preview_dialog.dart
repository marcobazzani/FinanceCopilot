import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/formatters.dart' as fmt;

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
  late Stream<PortfolioRebalanceDraft> _draftStream;

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
                  decoration: InputDecoration(labelText: s.rebalanceContribution),
                  onChanged: (_) {
                    setState(() {
                      _draftStream = _buildDraftStream();
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              StreamBuilder<PortfolioRebalanceDraft>(
                stream: _draftStream,
                builder: (context, snapshot) {
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
                    onApply: !isUpdating && draft.hasExecutableTrades ? () => _applyDraft(context, draft) : null,
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

  Stream<PortfolioRebalanceDraft> _buildDraftStream() {
    final locale = ref.read(appLocaleProvider).value ?? 'en';
    final contribution = fmt.tryParseLocalized(_contribution.text, locale: locale) ?? 0;
    final scope = widget.initialScopeKind == PortfolioRebalanceScopeKind.currentPillar
        ? PortfolioRebalanceScope.currentPillar(widget.pillarId)
        : const PortfolioRebalanceScope.allAssociatedPillars();
    return ref
        .read(portfolioRebalanceServiceProvider)
        .buildDraftStream(
          scope: scope,
          mode: _mode,
          contributionAmount: contribution,
        );
  }

  Future<void> _applyDraft(BuildContext context, PortfolioRebalanceDraft draft) async {
    final s = ref.read(appStringsProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.rebalanceApplyConfirmTitle),
        content: Text(s.rebalanceApplyConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.rebalanceApplyDraft)),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(portfolioRebalanceServiceProvider)
        .applyDraft(
          draft,
          ref.read(assetEventServiceProvider),
        );
    if (context.mounted) Navigator.of(context).pop(true);
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
    String percent(double value, double total) {
      if (total <= 0) return '0.0';
      return (value / total * 100.0).toStringAsFixed(2);
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
                  final taxText = row.estimatedTax > 0
                      ? ' · ${s.rebalanceEstimatedTax}: ${amountFormat.format(row.estimatedTax)} ${draft.baseCurrency}'
                      : '';
                  final quantityText = row.isPlaceholder
                      ? s.rebalanceNotExecutable
                      : '${s.rebalanceQuantity}: ${quantityFormat.format(row.estimatedQuantity)}';
                  return Text(
                    '${amountFormat.format(row.baseAmount)} ${draft.baseCurrency} · '
                    '$quantityText'
                    ' · ${percent(row.currentBaseValue, draft.currentPortfolioValueBase)}% → ${percent(row.projectedBaseValue, draft.projectedPortfolioValueBase)}%'
                    '$taxText',
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
