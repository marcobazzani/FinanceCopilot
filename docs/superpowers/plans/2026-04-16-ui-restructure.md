# UI Restructure: Consolidate Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate 5 top-level navigation destinations into 3 by moving Income and Adjustments inside the Accounts screen as tabs.

**Architecture:** The `AccountsScreen` becomes a tabbed container (`TabBar` + `TabBarView`) with 3 tabs: Accounts, Income, Adjustments. The Adjustments tab merges the two former sub-tabs (Spread Expenses / Donations) into a single filterable list using `FilterChip` widgets. Navigation in `main.dart` shrinks from 5 to 3 destinations.

**Tech Stack:** Flutter, Riverpod, Material 3

---

### Task 1: Add "All" filter chip label to AppStrings

**Files:**
- Modify: `lib/l10n/app_strings.dart:434-435` (near the capex tab strings)

**Note:** `s.all` already exists at line 346. We need a new `capexFilterAll` for the filter chip context, or we can reuse `s.all`. Since `s.all` is generic enough, we'll reuse it. No changes needed for this — skip to Task 2.

---

### Task 2: Extract Adjustments content into a standalone filterable widget

**Files:**
- Modify: `lib/ui/screens/capex_screen.dart`

The current `CapexScreen` is a `DefaultTabController` with 2 tabs (`_SpreadTab`, `_IncomeTab`). We need to replace it with a single widget that shows both lists merged, filtered by chips.

- [ ] **Step 1: Create the new `AdjustmentsView` widget in `capex_screen.dart`**

Replace the entire `CapexScreen` class (lines 20-49) with a new stateful widget that:
- Has a `_filter` enum state: `all`, `spread`, `donation`
- Shows a row of 3 `FilterChip` widgets at the top
- Below the chips, shows a merged list of both spread schedules and income adjustments, filtered by the active chip

```dart
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

    // Determine which selection controller is active based on filter
    final activeSelection = _filter == _AdjFilter.donation
        ? _donationSelection
        : _spreadSelection;

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
```

- [ ] **Step 2: Keep `CapexScreen` as a backward-compatible wrapper (temporarily)**

Keep the old `CapexScreen` class but have it delegate to `AdjustmentsView`:

```dart
class CapexScreen extends StatelessWidget {
  const CapexScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdjustmentsView();
}
```

Keep `_SpreadTab`, `_IncomeTab`, `_CapexTile`, and `_IncomeAdjTile` unchanged — `AdjustmentsView` reuses `_CapexTile` and `_IncomeAdjTile` directly.

- [ ] **Step 3: Verify the app builds and the old Adjustments tab still works**

Run:
```bash
dart fix --apply && dart analyze lib/ test/ integration_test/
```
Expected: zero warnings/infos

- [ ] **Step 4: Commit**

```bash
git add lib/ui/screens/capex_screen.dart
git commit -m "Refactor: extract AdjustmentsView with filter chips from CapexScreen"
```

---

### Task 3: Convert AccountsScreen to a tabbed container

**Files:**
- Modify: `lib/ui/screens/accounts_screen.dart`

The current `AccountsScreen` is a `ConsumerStatefulWidget` with a flat accounts list. We need to wrap it in a `TabBar`/`TabBarView` with 3 tabs, embedding the existing accounts content as the first tab, `IncomeScreen` as the second, and `AdjustmentsView` as the third.

- [ ] **Step 1: Rename current `_AccountsScreenState` content into `_AccountsListTab`**

Extract the current build content (the accounts list with intermediary grouping, FABs, selection) into a new private widget `_AccountsListTab`. This keeps the accounts list logic self-contained.

```dart
// The existing _AccountsScreenState becomes _AccountsListTab
// Move all the accounts list logic (lines 26-145 of current file) into this widget
class _AccountsListTab extends ConsumerStatefulWidget {
  const _AccountsListTab();

  @override
  ConsumerState<_AccountsListTab> createState() => _AccountsListTabState();
}

// _AccountsListTabState contains the exact same code as current _AccountsScreenState
// (selection controller, build method with grouped accounts, FABs, etc.)
```

- [ ] **Step 2: Rewrite `AccountsScreen` as a tabbed container**

The new `AccountsScreen` uses `SingleTickerProviderStateMixin` for the `TabController` (same pattern as `DashboardScreen`):

```dart
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.navAccounts),
            Tab(text: s.navIncome),
            Tab(text: s.navAdjustments),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _AccountsListTab(),
              IncomeScreen(),
              AdjustmentsView(),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Add required imports**

Add to the top of `accounts_screen.dart`:
```dart
import 'income_screen.dart';
import 'capex_screen.dart' show AdjustmentsView;
```

- [ ] **Step 4: Move dialog methods from `_AccountsScreenState` to `_AccountsListTabState`**

All the dialog methods (`_showCreateDialog`, `_showManageIntermediariesDialog`, `_showIntermediaryDialog`, `_confirmDeleteIntermediary`) stay with `_AccountsListTabState` since they belong to the accounts list tab.

- [ ] **Step 5: Verify the app builds**

Run:
```bash
dart fix --apply && dart analyze lib/ test/ integration_test/
```
Expected: zero warnings/infos

- [ ] **Step 6: Commit**

```bash
git add lib/ui/screens/accounts_screen.dart
git commit -m "Convert AccountsScreen to tabbed container with Accounts/Income/Adjustments tabs"
```

---

### Task 4: Update main.dart navigation from 5 to 3 destinations

**Files:**
- Modify: `lib/main.dart:160-174` (destinations and sidebar items), `lib/main.dart:635-643` (body switch)

- [ ] **Step 1: Update `_destinations` to 3 items**

Replace lines 160-166:
```dart
List<NavigationDestination> _destinations(AppStrings s) => [
  NavigationDestination(icon: const Icon(Icons.dashboard), label: s.navDashboard),
  NavigationDestination(icon: const Icon(Icons.account_balance), label: s.navAccounts),
  NavigationDestination(icon: const Icon(Icons.pie_chart), label: s.navAssets),
];
```

- [ ] **Step 2: Update `_sidebarItems` to 3 items**

Replace lines 168-174:
```dart
List<(IconData, String)> _sidebarItems(AppStrings s) => [
  (Icons.dashboard, s.navDashboard),
  (Icons.account_balance, s.navAccounts),
  (Icons.pie_chart, s.navAssets),
];
```

- [ ] **Step 3: Update `_body()` switch to 3 cases**

Replace lines 635-643:
```dart
Widget _body() {
  return switch (_selectedIndex) {
    0 => const DashboardScreen(),
    1 => const AccountsScreen(),
    2 => const AssetsScreen(),
    _ => const SizedBox(),
  };
}
```

- [ ] **Step 4: Remove unused imports**

Remove `CapexScreen` and `IncomeScreen` imports from `main.dart` if they exist (check — they may be imported indirectly).

- [ ] **Step 5: Verify the app builds and analyze**

Run:
```bash
dart fix --apply && dart analyze lib/ test/ integration_test/
```
Expected: zero warnings/infos

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "Reduce top-level navigation from 5 to 3 destinations"
```

---

### Task 5: Clean up — remove dead CapexScreen wrapper if unused

**Files:**
- Modify: `lib/ui/screens/capex_screen.dart`

- [ ] **Step 1: Check if `CapexScreen` is referenced anywhere besides `main.dart`**

Run:
```bash
grep -r 'CapexScreen' lib/ --include='*.dart' -l
```

If it's only in `capex_screen.dart` itself (the class definition) and no longer in `main.dart`, remove the `CapexScreen` wrapper class. Keep `AdjustmentsView` and all tile/helper classes.

- [ ] **Step 2: Make `_CapexTile` and `_IncomeAdjTile` non-private if needed**

If `AdjustmentsView` is in a different file than the tiles, the tiles need to be public. Since they're all in `capex_screen.dart`, they can stay private.

- [ ] **Step 3: Verify the app builds**

Run:
```bash
dart fix --apply && dart analyze lib/ test/ integration_test/
```
Expected: zero warnings/infos

- [ ] **Step 4: Run all tests**

Run:
```bash
flutter test
```
Expected: all pass

- [ ] **Step 5: Commit**

```bash
git add lib/ui/screens/capex_screen.dart
git commit -m "Remove unused CapexScreen wrapper class"
```

---

### Task 6: Build and manual verification

- [ ] **Step 1: Build and launch the macOS app**

Run:
```bash
source .env && dart fix --apply && flutter build macos --release --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID --dart-define=GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET && pkill -f "FinanceCopilot" 2>/dev/null; open build/macos/Build/Products/Release/FinanceCopilot.app
```

- [ ] **Step 2: Manual verification checklist**

Verify in the running app:
1. Bottom nav / sidebar shows exactly 3 items: Dashboard, Accounts, Assets
2. Accounts screen shows 3 tabs: Accounts, Income, Adjustments
3. Accounts tab: accounts list grouped by intermediary works, FABs work, create dialog works, manage intermediaries works
4. Income tab: income list works, add/edit/delete dialogs work, paste from clipboard works, import FAB works
5. Adjustments tab: filter chips (All / Spread Expenses / Donations) work, list shows correct items per filter, FAB creates correct type per filter, selection/delete works
6. All detail screen navigation still works (tap account -> AccountDetailScreen, tap income -> edit dialog, tap adjustment -> CapexDetailScreen or IncomeAdjDetailScreen)
7. Dashboard and Assets screens are unchanged

- [ ] **Step 3: Run full test suite**

Run:
```bash
flutter test && flutter test integration_test/all_tests.dart -d macos && flutter test integration_test/live_data_fetch_test.dart -d macos
```
Expected: all pass
