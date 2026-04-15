import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/capex_service.dart';
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/formatters.dart' as fmt;
import 'capex_detail_screen.dart';
import 'capex_edit_screen.dart';
import 'income_adj_detail_screen.dart';
import 'income_adj_edit_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import '../widgets/privacy_text.dart';
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

// ════════════════════════════════════════════════════
// CapexScreen — backward-compatible wrapper
// ════════════════════════════════════════════════════

class CapexScreen extends StatelessWidget {
  const CapexScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdjustmentsView();
}

// ════════════════════════════════════════════════════
// AdjustmentsView — merged filterable list
// ════════════════════════════════════════════════════

enum _AdjFilter { all, spread, donation }

class AdjustmentsView extends ConsumerStatefulWidget {
  const AdjustmentsView({super.key});

  @override
  ConsumerState<AdjustmentsView> createState() => _AdjustmentsViewState();
}

class _AdjustmentsViewState extends ConsumerState<AdjustmentsView> {
  _AdjFilter _filter = _AdjFilter.all;
  final _spreadSelection = SelectionController<int>();
  final _donationSelection = SelectionController<int>();

  @override
  void dispose() {
    _spreadSelection.dispose();
    _donationSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final schedulesAsync = ref.watch(capexSchedulesProvider);
    final statsAsync = ref.watch(capexStatsProvider);
    final adjAsync = ref.watch(incomeAdjustmentsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;

    return ListenableBuilder(
      listenable: Listenable.merge([_spreadSelection, _donationSelection]),
      builder: (ctx, _) {
        final schedules = schedulesAsync.value ?? const <DepreciationSchedule>[];
        final adjustments = adjAsync.value ?? const <IncomeAdjustment>[];
        _spreadSelection.setOrderedIds(schedules.map((s) => s.id).toList());
        _donationSelection.setOrderedIds(adjustments.map((a) => a.id).toList());

        final anySelectionActive = _spreadSelection.active || _donationSelection.active;

        // Build merged item list based on filter
        final items = <_AdjItem>[];
        if (_filter != _AdjFilter.donation) {
          for (final s in schedules) {
            items.add(_AdjItem.spread(s));
          }
        }
        if (_filter != _AdjFilter.spread) {
          for (final a in adjustments) {
            items.add(_AdjItem.donation(a));
          }
        }

        final stats = statsAsync.value ?? {};

        final isLoading = schedulesAsync.isLoading || adjAsync.isLoading;
        final error = schedulesAsync.error ?? adjAsync.error;

        return Scaffold(
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(s.error(error)))
                  : Column(
                      children: [
                        // Filter chips row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildChip(s.all, _AdjFilter.all),
                              const SizedBox(width: 8),
                              _buildChip(s.capexTabSavingSpent, _AdjFilter.spread),
                              const SizedBox(width: 8),
                              _buildChip(s.capexTabDonationSpent, _AdjFilter.donation),
                            ],
                          ),
                        ),
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text(
                                    _filter == _AdjFilter.spread
                                        ? s.noSpreadAdjustments
                                        : _filter == _AdjFilter.donation
                                            ? s.noIncomeAdjustments
                                            : s.noSpreadAdjustments,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final item = items[i];
                                    if (item.isSpread) {
                                      return SelectableItem<int>(
                                        controller: _spreadSelection,
                                        id: item.spread!.id,
                                        child: _CapexTile(
                                          schedule: item.spread!,
                                          stats: stats[item.spread!.id],
                                          baseCurrency: baseCurrency,
                                          locale: locale,
                                          strings: s,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CapexDetailScreen(scheduleId: item.spread!.id),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return SelectableItem<int>(
                                        controller: _donationSelection,
                                        id: item.donation!.id,
                                        child: _IncomeAdjTile(
                                          adjustment: item.donation!,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => IncomeAdjDetailScreen(adjustmentId: item.donation!.id),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                        ),
                      ],
                    ),
          bottomNavigationBar: anySelectionActive
              ? _spreadSelection.active
                  ? SelectionActionBar<int>(
                      controller: _spreadSelection,
                      visibleIds: schedules.map((s) => s.id).toList(),
                      onDelete: (ids) => ref.read(capexServiceProvider).deleteMany(ids.toList()),
                    )
                  : SelectionActionBar<int>(
                      controller: _donationSelection,
                      visibleIds: adjustments.map((a) => a.id).toList(),
                      onDelete: (ids) => ref.read(incomeAdjustmentServiceProvider).deleteMany(ids.toList()),
                    )
              : null,
          floatingActionButton: anySelectionActive
              ? null
              : FloatingActionButton(
                  onPressed: () {
                    if (_filter == _AdjFilter.donation) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeAdjEditScreen()));
                    } else if (_filter == _AdjFilter.spread) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CapexEditScreen()));
                    } else {
                      _showAddChoiceDialog(context);
                    }
                  },
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  Widget _buildChip(String label, _AdjFilter filter) {
    return FilterChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Future<void> _showAddChoiceDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final result = await showDialog<_AdjFilter>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.navAdjustments),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _AdjFilter.spread),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(s.capexTabSavingSpent),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _AdjFilter.donation),
            child: ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: Text(s.capexTabDonationSpent),
            ),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    if (result == _AdjFilter.spread) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CapexEditScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeAdjEditScreen()));
    }
  }
}

// Helper class for merged list items
class _AdjItem {
  final DepreciationSchedule? spread;
  final IncomeAdjustment? donation;

  _AdjItem.spread(this.spread) : donation = null;
  _AdjItem.donation(this.donation) : spread = null;

  bool get isSpread => spread != null;
}

// ════════════════════════════════════════════════════
// Tiles
// ════════════════════════════════════════════════════

class _CapexTile extends StatelessWidget {
  final DepreciationSchedule schedule;
  final CapexStats? stats;
  final String baseCurrency;
  final String locale;
  final AppStrings strings;
  final VoidCallback onTap;

  const _CapexTile({
    required this.schedule,
    required this.stats,
    required this.baseCurrency,
    required this.locale,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amtFormat = fmt.amountFormat(locale);
    final dateFmt = fmt.monthYearFormat(locale);
    final shortDate = fmt.shortDateFormat(locale);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.assetName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (schedule.expenseDate != null) ...[
                        Text(strings.expLabel(shortDate.format(schedule.expenseDate!)),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${dateFmt.format(schedule.startDate)} → ${dateFmt.format(schedule.endDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (stats != null && stats!.totalReimbursed > 0) ...[
                    const SizedBox(height: 2),
                    PrivacyText(
                      strings.reimbLabel('${amtFormat.format(stats!.totalReimbursed)} ${currencySymbol(schedule.currency)}'),
                      style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PrivacyText(
                  '${amtFormat.format(schedule.totalAmount)} ${currencySymbol(schedule.currency)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (stats != null)
                  Text(
                    strings.nSteps(stats!.entryCount, schedule.stepFrequency.name),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _IncomeAdjTile extends ConsumerWidget {
  final IncomeAdjustment adjustment;
  final VoidCallback onTap;

  const _IncomeAdjTile({required this.adjustment, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final amtFormat = fmt.amountFormat(locale);
    final shortDate = fmt.shortDateFormat(locale);
    final sym = currencySymbol(adjustment.currency);
    final totalSpentAsync = ref.watch(totalSpentProvider(adjustment.id));
    final totalSpent = totalSpentAsync.value ?? 0.0;
    final remaining = adjustment.totalAmount - totalSpent;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.card_giftcard,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adjustment.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ref.read(appStringsProvider).incomeLabel(shortDate.format(adjustment.incomeDate)),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (totalSpent > 0) ...[
                    const SizedBox(height: 2),
                    PrivacyText(
                      ref.read(appStringsProvider).spentRemaining('${amtFormat.format(totalSpent)} $sym', '${amtFormat.format(remaining)} $sym'),
                      style: TextStyle(fontSize: 11, color: remaining > 0 ? Colors.orange.shade600 : Colors.green.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PrivacyText(
              '${amtFormat.format(adjustment.totalAmount)} $sym',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
