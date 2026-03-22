import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../services/capex_service.dart';
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'capex_detail_screen.dart';
import 'capex_edit_screen.dart';
import 'income_adj_detail_screen.dart';
import 'income_adj_edit_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;
import '../widgets/privacy_text.dart';

class CapexScreen extends ConsumerWidget {
  const CapexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Saving Spent'),
                Tab(text: 'Donation Spent'),
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

class _SpreadTab extends ConsumerWidget {
  const _SpreadTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(capexSchedulesProvider);
    final statsAsync = ref.watch(capexStatsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';

    return Scaffold(
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return const Center(
              child: Text('No spread adjustments yet.\nAdd an item to spread large expenses over time.',
                  textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.value ?? {};

          return ListView.separated(
            itemCount: schedules.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final schedule = schedules[i];
              final stat = stats[schedule.id];

              return _CapexTile(
                schedule: schedule,
                stats: stat,
                baseCurrency: baseCurrency,
                locale: locale,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CapexDetailScreen(scheduleId: schedule.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CapexEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Income tab (income/donation adjustments)
// ════════════════════════════════════════════════════

class _IncomeTab extends ConsumerWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjAsync = ref.watch(incomeAdjustmentsProvider);

    return Scaffold(
      body: adjAsync.when(
        data: (adjustments) {
          if (adjustments.isEmpty) {
            return const Center(
              child: Text('No income adjustments yet.\nAdd a donation or lump sum to subtract from net worth.',
                  textAlign: TextAlign.center),
            );
          }

          return ListView.separated(
            itemCount: adjustments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final adj = adjustments[i];
              return _IncomeAdjTile(
                adjustment: adj,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncomeAdjDetailScreen(adjustmentId: adj.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IncomeAdjEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
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
  final VoidCallback onTap;

  const _CapexTile({
    required this.schedule,
    required this.stats,
    required this.baseCurrency,
    required this.locale,
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
                        Text('Exp: ${shortDate.format(schedule.expenseDate!)}',
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
                      'Reimb: ${amtFormat.format(stats!.totalReimbursed)} ${currencySymbol(schedule.currency)}',
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
                    '${stats!.entryCount} steps · ${schedule.stepFrequency.name}',
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
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final amtFormat = fmt.amountFormat(locale);
    final shortDate = fmt.shortDateFormat(locale);
    final sym = currencySymbol(adjustment.currency);
    final expensesAsync = ref.watch(incomeAdjustmentExpensesProvider(adjustment.id));
    final totalSpent = expensesAsync.value?.fold(0.0, (sum, e) => sum + e.amount) ?? 0.0;
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
                    'Income: ${shortDate.format(adjustment.incomeDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (totalSpent > 0) ...[
                    const SizedBox(height: 2),
                    PrivacyText(
                      'Spent: ${amtFormat.format(totalSpent)} $sym · Remaining: ${amtFormat.format(remaining)} $sym',
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
