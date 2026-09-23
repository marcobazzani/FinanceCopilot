import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';
import 'package:finance_copilot/ui/widgets/global_app_bar_actions.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

/// Samples (newest first) of the uncategorized rows of one merchant group.
final _groupSamplesProvider = FutureProvider.autoDispose.family<List<Transaction>, ({String key, int? accountId})>((
  ref,
  arg,
) {
  // Re-fetch whenever the ledger changes (progress stream ticks on writes).
  ref.watch(classificationProgressProvider(arg.accountId));
  return ref.read(transactionClassifierServiceProvider).uncategorizedOf(arg.key, accountId: arg.accountId, limit: 4);
});

/// Walks the user through uncategorized transactions one merchant group at a
/// time (biggest first). Every answer becomes a rule that is applied to the
/// whole ledger immediately, so the queue shrinks with each step.
class ClassificationWizardScreen extends ConsumerStatefulWidget {
  /// Restrict the queue to one account; null = whole ledger.
  final int? accountId;
  const ClassificationWizardScreen({super.key, this.accountId});

  @override
  ConsumerState<ClassificationWizardScreen> createState() => _ClassificationWizardScreenState();
}

class _ClassificationWizardScreenState extends ConsumerState<ClassificationWizardScreen> {
  final _skipped = <String>{};
  final _history = <ClassifyStep>[];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final groupsAsync = ref.watch(uncategorizedGroupsProvider(widget.accountId));
    final progress = ref.watch(classificationProgressProvider(widget.accountId)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.classificationWizardTitle),
        actions: globalAppBarActions(
          context,
          ref,
          local: [
            AppBarAction(
              icon: Icons.undo,
              tooltip: s.wizardUndo,
              onPressed: _history.isEmpty || _busy ? null : _undo,
            ),
          ],
        ),
      ),
      body: MobilePullToRefresh(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null)
                    _ProgressHeader(
                      progress: progress,
                      s: s,
                      amountFmt: fmt.amountFormat(ref.watch(appLocaleProvider).value ?? Platform.localeName),
                    ),
                  const SizedBox(height: 16),
                  groupsAsync.when(
                    loading: () => const Center(
                      child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('$e'),
                    data: (groups) {
                      final pending = groups.where((g) => !_skipped.contains(g.merchantKey)).toList();
                      if (groups.isEmpty) return _DoneCard(s: s);
                      if (pending.isEmpty) return _AllSkippedCard(s: s, onRestart: () => setState(_skipped.clear));
                      final g = pending.first;
                      final samples = ref.watch(_groupSamplesProvider((key: g.merchantKey, accountId: widget.accountId))).value ?? const [];
                      return TransactionClassifyCard(
                        // A new state per group resets the card's inputs.
                        key: ValueKey(('classify', g.merchantKey)),
                        group: g,
                        samples: samples,
                        accountId: widget.accountId,
                        onSkip: () => setState(() => _skipped.add(g.merchantKey)),
                        onBusyChanged: (v) => setState(() => _busy = v),
                        onApplied: (step) => setState(() {
                          _history.add(step);
                          _skipped.remove(g.merchantKey);
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;
    final s = ref.read(appStringsProvider);
    final step = _history.removeLast();
    setState(() => _busy = true);
    try {
      if (step.ruleId != null) await ref.read(ruleServiceProvider).delete(step.ruleId!);
      await ref.read(transactionClassifierServiceProvider).setCategory(step.changedIds, null);
      if (mounted) showInfoSnack(context, s.wizardUndone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  final ClassificationProgress progress;
  final AppStrings s;
  final NumberFormat amountFmt;
  const _ProgressHeader({required this.progress, required this.s, required this.amountFmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (progress.fraction * 100).round();
    final amounts = progress.totalAmount != null && progress.baseCurrency != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress is money explained, not rows ticked: the header leads with
        // the amounts (masked in privacy mode) and keeps the row count as a
        // secondary line.
        if (amounts)
          PrivacyText(
            s.wizardProgressAmount(
              amountFmt.format(progress.categorizedAmount),
              amountFmt.format(progress.totalAmount),
              progress.baseCurrency!,
              pct,
            ),
            key: const Key('wizardProgress'),
            style: theme.textTheme.titleMedium,
          )
        else
          Text(
            s.wizardProgress(progress.categorized, progress.total, pct),
            key: const Key('wizardProgress'),
            style: theme.textTheme.titleMedium,
          ),
        if (amounts)
          Text(
            s.wizardProgressRows(progress.categorized, progress.total),
            key: const Key('wizardProgressRows'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
        ),
        if (progress.excluded > 0) ...[
          const SizedBox(height: 4),
          Text(
            s.wizardExcludedNote(progress.excluded),
            key: const Key('wizardExcludedNote'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (progress.fxExcluded > 0) ...[
          const SizedBox(height: 2),
          Text(
            s.wizardFxExcludedNote(progress.fxExcluded),
            key: const Key('wizardFxExcludedNote'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  final AppStrings s;
  const _DoneCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('wizardDone'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(s.wizardAllDone, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(s.wizardAllDoneSubtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AllSkippedCard extends StatelessWidget {
  final AppStrings s;
  final VoidCallback onRestart;
  const _AllSkippedCard({required this.s, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.skip_next, size: 48),
            const SizedBox(height: 16),
            Text(s.wizardNothingLeftInScope, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRestart, icon: const Icon(Icons.replay), label: Text(s.wizardRestart)),
          ],
        ),
      ),
    );
  }
}
