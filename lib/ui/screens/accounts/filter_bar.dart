part of 'account_detail_screen.dart';

/// Compact filter toolbar shown under the search field in the account-detail
/// ledger. It is a single "Filters" button (with an active-count badge) that
/// opens the structured [_FilterSheet], followed by a horizontally-scrolling
/// strip of removable "active filter" pills summarizing what's applied. This
/// replaces the old inline chip row, which couldn't express exclusions and
/// overflowed off-screen.
///
/// Stateless w.r.t. the filter itself: it reads the current [filter] and emits
/// a new one through [onChanged]. The owning state holds the source of truth.
class _LedgerFilterBar extends StatelessWidget {
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onChanged;

  /// Whether the transfer kind is offered. Transfers require two accounts'
  /// data, so they are only meaningful in the merged All-Accounts view.
  final bool showTransfer;

  /// Whether the adjustment kind is offered. Anchor/reimbursement/financed
  /// adjustments are tied to real (account-bound) transactions, so they apply
  /// in both views; only synthetic spread-saving rows are merged-only.
  final bool showAdjustment;
  final String locale;
  final AppStrings s;

  const _LedgerFilterBar({
    required this.filter,
    required this.onChanged,
    required this.showTransfer,
    required this.showAdjustment,
    required this.locale,
    required this.s,
  });

  List<EntryKind> get _availableKinds => [
    EntryKind.inflow,
    EntryKind.outflow,
    EntryKind.noOp,
    EntryKind.cancelled,
    if (showTransfer) EntryKind.transfer,
    if (showAdjustment) EntryKind.adjustment,
  ];

  String _kindLabel(EntryKind k) => switch (k) {
    EntryKind.inflow => s.filterKindInflow,
    EntryKind.outflow => s.filterKindOutflow,
    EntryKind.noOp => s.filterKindNoOp,
    EntryKind.cancelled => s.filterKindCancelled,
    EntryKind.transfer => s.filterKindTransfer,
    EntryKind.adjustment => s.filterKindAdjustment,
  };

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _FilterSheet(
        initial: filter,
        kinds: _availableKinds,
        kindLabel: _kindLabel,
        locale: locale,
        s: s,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final active = filter.activeCount;
    final label = active == 0 ? s.filterTitle : '${s.filterTitle} ($active)';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (active == 0)
            OutlinedButton.icon(
              key: const Key('ledgerFilterButton'),
              onPressed: () => _openSheet(context),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(label),
            )
          else
            FilledButton.tonalIcon(
              key: const Key('ledgerFilterButton'),
              onPressed: () => _openSheet(context),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(label),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: filter.isActive
                ? _ActiveFilterPills(filter: filter, kindLabel: _kindLabel, locale: locale, s: s, onChanged: onChanged)
                : Text(
                    s.filterNone,
                    style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally-scrolling strip of removable pills, one per active filter
/// dimension. Each pill's delete (×) removes only that dimension; a trailing
/// "clear" pill removes everything. Excluded kinds / "doesn't contain" text
/// render in the error palette with a block avatar to read as negations.
///
/// Note: the positive `containsText` is intentionally NOT shown here — it is
/// owned and displayed by the search box directly above, with its own clear.
class _ActiveFilterPills extends StatelessWidget {
  final TransactionFilter filter;
  final String Function(EntryKind) kindLabel;
  final String locale;
  final AppStrings s;
  final ValueChanged<TransactionFilter> onChanged;

  const _ActiveFilterPills({
    required this.filter,
    required this.kindLabel,
    required this.locale,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = fmt.shortDateFormat(locale);
    final amtFmt = fmt.amountFormat(locale);
    final pills = <Widget>[];

    void add(String label, VoidCallback onRemove, {bool negative = false}) {
      pills.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InputChip(
            label: Text(label),
            avatar: negative ? const Icon(Icons.block, size: 16) : null,
            onDeleted: onRemove,
            backgroundColor: negative ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    for (final k in filter.includeKinds) {
      add(kindLabel(k), () => onChanged(filter.withKindSel(k, KindSel.neutral)));
    }
    for (final k in filter.excludeKinds) {
      add(kindLabel(k), () => onChanged(filter.withKindSel(k, KindSel.neutral)), negative: true);
    }
    if (!filter.dateRange.isEmpty) {
      add(_dateRangeLabel(filter.dateRange, dateFmt, s), () => onChanged(filter.copyWith(dateRange: const DateRangeFilter())));
    }
    if (!filter.amountRange.isEmpty) {
      add(
        _amountRangeLabel(filter.amountRange, amtFmt, s),
        () => onChanged(filter.copyWith(amountRange: const AmountRangeFilter())),
        negative: filter.amountRange.outside,
      );
    }
    if (filter.excludesText.isNotEmpty) {
      add('"${filter.excludesText}"', () => onChanged(filter.copyWith(excludesText: '')), negative: true);
    }

    pills.add(
      ActionChip(
        key: const Key('clearAllPill'),
        avatar: const Icon(Icons.clear_all, size: 16),
        label: Text(s.filterClearAll),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Preserve the live search-box text; only the structured filters reset.
        onPressed: () => onChanged(TransactionFilter(containsText: filter.containsText)),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: pills),
    );
  }
}

/// The structured filter editor, shown as a modal bottom sheet. Holds a local
/// draft that is committed only on "Apply" (so partial edits don't churn the
/// list behind the sheet). Sections: Type (Show only / Hide per kind), Date,
/// Amount (inside/outside range), and Text (contains / doesn't contain).
class _FilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final List<EntryKind> kinds;
  final String Function(EntryKind) kindLabel;
  final String locale;
  final AppStrings s;

  const _FilterSheet({
    required this.initial,
    required this.kinds,
    required this.kindLabel,
    required this.locale,
    required this.s,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _draft;
  late final TextEditingController _containsCtrl;
  late final TextEditingController _excludesCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _containsCtrl = TextEditingController(text: widget.initial.containsText);
    _excludesCtrl = TextEditingController(text: widget.initial.excludesText);
  }

  @override
  void dispose() {
    _containsCtrl.dispose();
    _excludesCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() => _draft = TransactionFilter.none);
    _containsCtrl.clear();
    _excludesCtrl.clear();
  }

  void _apply() {
    Navigator.pop(
      context,
      _draft.copyWith(containsText: _containsCtrl.text.trim(), excludesText: _excludesCtrl.text.trim()),
    );
  }

  Future<void> _editDate() async {
    final r = await showDialog<DateRangeFilter>(
      context: context,
      builder: (ctx) => _DateRangeDialog(initial: _draft.dateRange, locale: widget.locale, s: widget.s),
    );
    if (r != null) setState(() => _draft = _draft.copyWith(dateRange: r));
  }

  Future<void> _editAmount() async {
    final r = await showDialog<AmountRangeFilter>(
      context: context,
      builder: (ctx) => _AmountRangeDialog(initial: _draft.amountRange, locale: widget.locale, s: widget.s),
    );
    if (r != null) setState(() => _draft = _draft.copyWith(amountRange: r));
  }

  Widget _kindGroup({required bool hide}) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final k in widget.kinds)
          FilterChip(
            key: ValueKey('kindChip_${hide ? 'hide' : 'show'}_${k.name}'),
            label: Text(widget.kindLabel(k)),
            selected: hide ? _draft.kindSel(k) == KindSel.exclude : _draft.kindSel(k) == KindSel.include,
            onSelected: (sel) {
              final target = hide ? KindSel.exclude : KindSel.include;
              setState(() => _draft = _draft.withKindSel(k, sel ? target : KindSel.neutral));
            },
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    final dateFmt = fmt.shortDateFormat(widget.locale);
    final amtFmt = fmt.amountFormat(widget.locale);
    final sectionStyle = theme.textTheme.titleSmall;
    final subStyle = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      // Lift content above the keyboard when a text field is focused.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: title + reset.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Text(s.filterTitle, style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _draft.isActive ? _reset : null,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text(s.filterClearAll),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  // ── Type ──
                  Text(s.filterType, style: sectionStyle),
                  const SizedBox(height: 6),
                  Text(s.filterShowOnly, style: subStyle),
                  const SizedBox(height: 4),
                  _kindGroup(hide: false),
                  const SizedBox(height: 10),
                  Text(s.filterHide, style: subStyle),
                  const SizedBox(height: 4),
                  _kindGroup(hide: true),
                  const Divider(height: 28),

                  // ── Date ──
                  Text(s.filterDateRange, style: sectionStyle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range),
                    title: Text(_draft.dateRange.isEmpty ? s.filterAnyDate : _dateRangeLabel(_draft.dateRange, dateFmt, s)),
                    trailing: _draft.dateRange.isEmpty
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: s.filterClearAll,
                            onPressed: () => setState(() => _draft = _draft.copyWith(dateRange: const DateRangeFilter())),
                          ),
                    onTap: _editDate,
                  ),
                  const Divider(height: 28),

                  // ── Amount ──
                  Text(s.filterAmountRange, style: sectionStyle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: Text(
                      _draft.amountRange.isEmpty ? s.filterAnyAmount : _amountRangeLabel(_draft.amountRange, amtFmt, s),
                    ),
                    trailing: _draft.amountRange.isEmpty
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: s.filterClearAll,
                            onPressed: () => setState(() => _draft = _draft.copyWith(amountRange: const AmountRangeFilter())),
                          ),
                    onTap: _editAmount,
                  ),
                  const Divider(height: 28),

                  // ── Text ──
                  Text(s.filterTextSection, style: sectionStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _containsCtrl,
                    decoration: InputDecoration(
                      labelText: s.filterTextContains,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _excludesCtrl,
                    decoration: InputDecoration(
                      labelText: s.filterTextExcludes,
                      prefixIcon: const Icon(Icons.block),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            // Footer: cancel / apply.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(onPressed: _apply, child: Text(s.filterApply)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Jun 1 → Jun 30" style label for a date range; open bounds render as "…".
String _dateRangeLabel(DateRangeFilter dr, dynamic dateFmt, AppStrings s) {
  if (dr.isEmpty) return s.filterAnyDate;
  final from = dr.start != null ? dateFmt.format(dr.start!) : '…';
  final to = dr.end != null ? dateFmt.format(dr.end!) : '…';
  return '$from → $to';
}

/// "+ 100 – 500" style label for an amount range; a leading "∉" marks an
/// outside-range (negated) bound, and +/− marks a direction scope.
String _amountRangeLabel(AmountRangeFilter ar, dynamic amtFmt, AppStrings s) {
  final lo = ar.min != null ? amtFmt.format(ar.min) : '…';
  final hi = ar.max != null ? amtFmt.format(ar.max) : '…';
  final dir = switch (ar.direction) {
    AmountDirection.inflow => '+',
    AmountDirection.outflow => '−',
    AmountDirection.both => '',
  };
  final body = (ar.min == null && ar.max == null) ? '' : '$lo – $hi';
  final prefix = ar.outside ? '∉ ' : '';
  return '$prefix$dir $body'.trim();
}

/// Min/max amount editor with a direction scope and an inside/outside toggle.
/// Empty fields mean "open-ended".
class _AmountRangeDialog extends StatefulWidget {
  final AmountRangeFilter initial;
  final String locale;
  final AppStrings s;
  const _AmountRangeDialog({required this.initial, required this.locale, required this.s});

  @override
  State<_AmountRangeDialog> createState() => _AmountRangeDialogState();
}

class _AmountRangeDialogState extends State<_AmountRangeDialog> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late AmountDirection _direction;
  late bool _outside;

  @override
  void initState() {
    super.initState();
    final f = fmt.amountFormat(widget.locale);
    _minCtrl = TextEditingController(text: widget.initial.min != null ? f.format(widget.initial.min) : '');
    _maxCtrl = TextEditingController(text: widget.initial.max != null ? f.format(widget.initial.max) : '');
    _direction = widget.initial.direction;
    _outside = widget.initial.outside;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.filterAmountRange),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: s.filterAmountMin),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _maxCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: s.filterAmountMax),
          ),
          const SizedBox(height: 16),
          // Whether the magnitude bound matches inside or outside the window.
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(s.filterAmountInside)),
              ButtonSegment(value: true, label: Text(s.filterAmountOutside)),
            ],
            selected: {_outside},
            onSelectionChanged: (sel) => setState(() => _outside = sel.first),
          ),
          const SizedBox(height: 8),
          // Direction scope: the magnitude bound applies to inflows, outflows,
          // or either sign.
          SegmentedButton<AmountDirection>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AmountDirection.both, label: Text(s.filterAmountDirBoth)),
              ButtonSegment(value: AmountDirection.inflow, label: Text(s.filterKindInflow)),
              ButtonSegment(value: AmountDirection.outflow, label: Text(s.filterKindOutflow)),
            ],
            selected: {_direction},
            onSelectionChanged: (sel) => setState(() => _direction = sel.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const AmountRangeFilter()),
          child: Text(s.filterClearAll),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            final min = fmt.parseFlexibleNumber(_minCtrl.text.trim());
            final max = fmt.parseFlexibleNumber(_maxCtrl.text.trim());
            Navigator.pop(
              context,
              AmountRangeFilter(min: min?.abs(), max: max?.abs(), direction: _direction, outside: _outside),
            );
          },
          child: Text(s.filterApply),
        ),
      ],
    );
  }
}

/// From/To date-range editor. Mirrors [_AmountRangeDialog]: explicit Apply /
/// Cancel, with a per-field clear (×) so either bound can be left open-ended —
/// the empty field reads "Any date". Tapping a field opens the app's canonical
/// [pickDate] in keyboard-input entry mode and scoped to the app locale, so a
/// date far from today can be typed directly instead of navigated to in the
/// calendar (the calendar stays one toggle away).
class _DateRangeDialog extends StatefulWidget {
  final DateRangeFilter initial;
  final String locale;
  final AppStrings s;
  const _DateRangeDialog({required this.initial, required this.locale, required this.s});

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start;
    _end = widget.initial.end;
  }

  Future<void> _pick({required bool isStart}) async {
    // Open at the field's current value, or today when the bound is unset.
    // Both bounds default to today, independent of the other field.
    final initial = (isStart ? _start : _end) ?? DateUtils.dateOnly(DateTime.now());
    final picked = await pickDate(
      context,
      initial,
      firstYear: 2000,
      helpText: isStart ? widget.s.filterDateStart : widget.s.filterDateEnd,
      locale: Locale(widget.locale.split(RegExp('[-_]')).first),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final dateFmt = fmt.shortDateFormat(widget.locale);

    void setBound({required bool isStart, required DateTime? value}) {
      setState(() {
        if (isStart) {
          _start = value;
        } else {
          _end = value;
        }
      });
    }

    Widget field({required bool isStart}) {
      final value = isStart ? _start : _end;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event),
        title: Text(isStart ? s.filterDateStart : s.filterDateEnd),
        subtitle: Text(value != null ? dateFmt.format(value) : s.filterAnyDate),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick-set this bound to today without opening the picker.
            TextButton(
              onPressed: () => setBound(isStart: isStart, value: DateUtils.dateOnly(DateTime.now())),
              child: Text(s.filterToday),
            ),
            // Clear to leave the bound open-ended ("Any date").
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: s.filterAnyDate,
                onPressed: () => setBound(isStart: isStart, value: null),
              ),
          ],
        ),
        onTap: () => _pick(isStart: isStart),
      );
    }

    return AlertDialog(
      title: Text(s.filterDateRange),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [field(isStart: true), field(isStart: false)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const DateRangeFilter()),
          child: Text(s.filterClearAll),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            var lo = _start;
            var hi = _end;
            // Normalize so start <= end regardless of pick order.
            if (lo != null && hi != null && hi.isBefore(lo)) {
              final tmp = lo;
              lo = hi;
              hi = tmp;
            }
            Navigator.pop(context, DateRangeFilter(start: lo, end: hi));
          },
          child: Text(s.filterApply),
        ),
      ],
    );
  }
}
