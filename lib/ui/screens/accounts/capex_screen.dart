import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';

// ════════════════════════════════════════════════════
// AdjustmentsView — unified list of ExtraordinaryEvents
// with direction filter chips (All / Inflow / Outflow).
// Replaces the legacy dual CAPEX + IncomeAdjustment lists.
// ════════════════════════════════════════════════════

class AdjustmentsView extends ConsumerStatefulWidget {
  const AdjustmentsView({super.key});

  @override
  ConsumerState<AdjustmentsView> createState() => _AdjustmentsViewState();
}

class _AdjustmentsViewState extends ConsumerState<AdjustmentsView> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final eventsAsync = ref.watch(extraordinaryEventsProvider);
    final statsAsync = ref.watch(extraordinaryEventStatsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;

    return ListenableBuilder(
      listenable: _selection,
      builder: (ctx, _) {
        final events = eventsAsync.value ?? const <ExtraordinaryEvent>[];
        _selection.setOrderedIds(events.map((e) => e.id).toList());

        final stats = statsAsync.value ?? {};

        return Scaffold(
          body: eventsAsync.when(
            data: (_) => MobilePullToRefresh(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const _InfoBox(),
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: EmptyState(icon: Icons.event_note, message: s.noEventsYet),
                    )
                  else
                    for (var i = 0; i < events.length; i++) ...[
                      SelectableItem<int>(
                        controller: _selection,
                        id: events[i].id,
                        child: SwipeToDelete.custom(
                          key: ValueKey('dismiss_adjustment_${events[i].id}'),
                          confirmAndDelete: () => confirmAndDeleteAdjustment(context, ref, events[i]),
                          child: _EventTile(
                            event: events[i],
                            stats: stats[events[i].id],
                            baseCurrency: baseCurrency,
                            locale: locale,
                            strings: s,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(eventId: events[i].id),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (i < events.length - 1) const Divider(height: 1),
                    ],
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(s.error(e))),
          ),
          bottomNavigationBar: _selection.active
              ? SelectionActionBar<int>(
                  controller: _selection,
                  visibleIds: events.map((e) => e.id).toList(),
                  onDelete: (ids) => ref.read(extraordinaryEventServiceProvider).deleteMany(ids.toList()),
                )
              : null,
          floatingActionButton: _selection.active
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EventEditScreen()),
                  ),
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Info box explaining what the Adjustments section represents.
// ════════════════════════════════════════════════════

class _InfoBox extends ConsumerWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.adjustmentsInfoTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.adjustmentsInfoBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Unified tile — single look for any direction/treatment.
// ════════════════════════════════════════════════════

class _EventTile extends StatelessWidget {
  final ExtraordinaryEvent event;
  final ExtraordinaryEventStats? stats;
  final String baseCurrency;
  final String locale;
  final AppStrings strings;
  final VoidCallback onTap;

  const _EventTile({
    required this.event,
    required this.stats,
    required this.baseCurrency,
    required this.locale,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amtFmt = fmt.amountFormat(locale);
    final shortDate = fmt.shortDateFormat(locale);
    final sym = currencySymbol(event.currency);
    final isOutflow = event.direction == EventDirection.outflow;
    final isSpread = event.treatment == EventTreatment.spread;

    final accentColor = isOutflow ? theme.colorScheme.error : theme.colorScheme.primary;
    final avatarBg = isOutflow ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer;

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
                color: avatarBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOutflow ? (isSpread ? Icons.timeline : Icons.trending_down) : (isSpread ? Icons.timeline : Icons.trending_up),
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  _subtitle(shortDate, amtFmt, sym),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PrivacyText(
                  '${amtFmt.format(event.totalAmount)} $sym',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                if (stats != null && stats!.entryCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${stats!.entryCount} · $_treatmentLabel',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ] else
                  Text(
                    _treatmentLabel,
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

  /// Event date, then the amount already allocated to it. The amount is
  /// position size (masked in privacy mode); the date is not.
  Widget _subtitle(DateFormat dateFmt, NumberFormat amtFmt, String sym) {
    final date = dateFmt.format(event.eventDate);
    final allocated = stats != null && stats!.totalAllocated > 0;
    return PrivacySentence(
      allocated ? '$date · ${privacySlot(0)}' : date,
      figures: [if (allocated) '${amtFmt.format(stats!.totalAllocated)} $sym'],
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      overflow: TextOverflow.ellipsis,
    );
  }

  String get _treatmentLabel => event.treatment == EventTreatment.spread ? strings.eventTreatmentSpread : strings.eventTreatmentInstant;
}
