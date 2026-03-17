import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../services/capex_service.dart';
import '../../services/providers.dart';
import 'capex_detail_screen.dart';
import 'capex_edit_screen.dart';
import 'dashboard_screen.dart' show currencySymbol;

final _amtFormat = NumberFormat('#,##0.00', 'it_IT');
final _dateFmt = DateFormat('MMM yyyy');

class CapexScreen extends ConsumerWidget {
  const CapexScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(capexSchedulesProvider);
    final statsAsync = ref.watch(capexStatsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).valueOrNull ?? 'EUR';

    return Scaffold(
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return const Center(
              child: Text('No adjustments yet.\nAdd an item to spread large expenses over time.',
                  textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.valueOrNull ?? {};

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

class _CapexTile extends StatelessWidget {
  final DepreciationSchedule schedule;
  final CapexStats? stats;
  final String baseCurrency;
  final VoidCallback onTap;

  const _CapexTile({
    required this.schedule,
    required this.stats,
    required this.baseCurrency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        Text('Exp: ${DateFormat('dd/MM/yy').format(schedule.expenseDate!)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${_dateFmt.format(schedule.startDate)} → ${_dateFmt.format(schedule.endDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (stats != null && stats!.totalReimbursed > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reimb: ${_amtFormat.format(stats!.totalReimbursed)} ${currencySymbol(schedule.currency)}',
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
                Text(
                  '${_amtFormat.format(schedule.totalAmount)} ${currencySymbol(schedule.currency)}',
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
