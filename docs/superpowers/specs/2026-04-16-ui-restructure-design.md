# UI Restructure: Consolidate Navigation

## Problem

The app has 5 top-level destinations (Dashboard, Accounts, Assets, Adjustments, Income). This is crowded on mobile bottom nav, and Income/Adjustments are low-frequency screens that don't warrant top-level real estate. They are conceptually related to Accounts (money flowing in/out).

## Design

### Top-Level Navigation: 5 -> 3

| Index | Icon | Label | Content |
|-------|------|-------|---------|
| 0 | `dashboard` | Dashboard | Unchanged |
| 1 | `account_balance` | Accounts | New tabbed container (see below) |
| 2 | `pie_chart` | Assets | Unchanged |

Both `NavigationBar` (mobile) and sidebar (desktop) shrink to 3 items. This is the sweet spot per Material 3 (3-5, fewer is better) and Apple HIG (3-5 tabs).

### Accounts Screen: Tabbed Container

The `AccountsScreen` becomes a `DefaultTabController` with 3 tabs:

| Tab | Content | Source |
|-----|---------|--------|
| **Accounts** | Current accounts list, grouped by intermediary | `AccountsScreen` (existing) |
| **Income** | Current income list | `IncomeScreen` (moved here) |
| **Adjustments** | Current adjustments list, flattened | `CapexScreen` (moved + flattened) |

**Tab implementation:** `TabBar` in the app bar area + `TabBarView` for content. Same pattern used by `DashboardScreen` (4 tabs) and `CapexScreen` (2 tabs).

**Desktop:** When the sidebar is visible, the tabs appear inside the Accounts content area. The sidebar selects the section, the tabs select the sub-view. Same as Dashboard currently works.

### Flattening Adjustments Sub-Tabs

Current `CapexScreen` has 2 internal tabs: "Saving Spent" and "Donation Spent". Moving it into Accounts would create tabs-in-tabs, which both Material 3 and Apple HIG discourage.

**Solution:** Replace nested tabs with **filter chips**:

- Row of `FilterChip` widgets: **All | Saving Spent | Donation Spent**
- Default: **All** (shows both types in a single merged list, differentiated by icon/color per item)
- Tapping a chip filters to that type
- Material 3 recommended pattern for filtering within a list view

**What stays the same:**
- Each item's tap navigates to its detail screen (`CapexDetailScreen` or `IncomeAdjDetailScreen`)
- FAB/add button: when a filter is active, creates that type directly; when "All" is active, offers a choice
- Selection/multi-select behavior unchanged
- All existing sub-navigation (detail screens, edit screens) unchanged

### Files Affected

**Modified:**
- `lib/main.dart` — Remove 2 destinations from `_destinations()` and `_sidebarItems()`, update `_body()` switch from 5 to 3 cases
- `lib/ui/screens/accounts_screen.dart` — Wrap in `DefaultTabController(length: 3)`, add `TabBar`, embed existing content as first tab, add Income and Adjustments as second/third tabs
- `lib/ui/screens/capex_screen.dart` — Extract tab content into standalone widgets (`SpreadAdjustmentsView`, `IncomeAdjustmentsView`), replace `DefaultTabController` with filter chips, merge both lists into one filterable view
- `lib/l10n/` — Tab labels if not already in `AppStrings`

**Not modified:**
- `lib/ui/screens/income_screen.dart` — Content reused as-is inside the new tab
- All detail/edit screens — No changes needed
- Dashboard, Assets — Untouched
- All services, providers, database — No changes

### Localization

Tab labels use existing `AppStrings`:
- `s.navAccounts` for the Accounts tab
- `s.navIncome` for the Income tab  
- `s.navAdjustments` for the Adjustments tab
- Filter chip labels reuse `s.capexTabSavingSpent` and `s.capexTabDonationSpent`, plus a new "All" string

### Platform Guidelines Compliance

- **Material 3:** Primary fixed tabs for 3 peer views. Filter chips for sub-filtering. 3 bottom nav destinations.
- **Apple HIG:** Top tabs acceptable in Flutter cross-platform context. 3 tab bar items is ideal. No nested tab bars.
- **Both:** No tabs-in-tabs. Detail navigation via push (unchanged).
