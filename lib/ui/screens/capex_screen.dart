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

class CapexScreen extends ConsumerWidget {
  const CapexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(text: s.capexTabSavingSpent),
                Tab(text: s.capexTabDonationSpent),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _SpreadTab(),
            _IncomeTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Spread tab (existing CAPEX adjustments)
// ════════════════════════════════════════════════════

class _SpreadTab extends ConsumerStatefulWidget {
  const _SpreadTab();

  @override
  ConsumerState<_SpreadTab> createState() => _SpreadTabState();
}

class _SpreadTabState extends ConsumerState<_SpreadTab> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final schedulesAsync = ref.watch(capexSchedulesProvider);
    final statsAsync = ref.watch(capexStatsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;

    return ListenableBuilder(
      listenable: _selection,
      builder: (ctx, _) {
        final schedules = schedulesAsync.value ?? const <DepreciationSchedule>[];
        _selection.setOrderedIds(schedules.map((s) => s.id).toList());
        return Scaffold(
          body: schedulesAsync.when(
            data: (schedules) {
              if (schedules.isEmpty) {
                return Center(
                  child: Text(s.noSpreadAdjustments,
                      textAlign: TextAlign.center),
                );
              }

              final stats = statsAsync.value ?? {};

              return ListView.separated(
                itemCount: schedules.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final schedule = schedules[i];
                  final stat = stats[schedule.id];

                  return SelectableItem<int>(
                    controller: _selection,
                    id: schedule.id,
                    child: _CapexTile(
                      schedule: schedule,
                      stats: stat,
                      baseCurrency: baseCurrency,
                      locale: locale,
                      strings: s,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CapexDetailScreen(scheduleId: schedule.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: schedules.map((s) => s.id).toList(),
                  onDelete: (ids) => ref.read(capexServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CapexEditScreen()),
                  ),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Income tab (income/donation adjustments)
// ════════════════════════════════════════════════════

class _IncomeTab extends ConsumerStatefulWidget {
  const _IncomeTab();

  @override
  ConsumerState<_IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends ConsumerState<_IncomeTab> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final adjAsync = ref.watch(incomeAdjustmentsProvider);

    return ListenableBuilder(
      listenable: _selection,
      builder: (ctx, _) {
        final adjustments = adjAsync.value ?? const <IncomeAdjustment>[];
        _selection.setOrderedIds(adjustments.map((a) => a.id).toList());
        return Scaffold(
          body: adjAsync.when(
            data: (adjustments) {
              if (adjustments.isEmpty) {
                return Center(
                  child: Text(s.noIncomeAdjustments,
                      textAlign: TextAlign.center),
                );
              }

              return ListView.separated(
                itemCount: adjustments.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final adj = adjustments[i];
                  return SelectableItem<int>(
                    controller: _selection,
                    id: adj.id,
                    child: _IncomeAdjTile(
                      adjustment: adj,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IncomeAdjDetailScreen(adjustmentId: adj.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: adjustments.map((a) => a.id).toList(),
                  onDelete: (ids) => ref.read(incomeAdjustmentServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IncomeAdjEditScreen()),
                  ),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }
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
