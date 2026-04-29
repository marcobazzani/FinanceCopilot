# Integration test journey

A single comprehensive happy-path test (`integration_test/full_walkthrough_test.dart`)
walks one shared in-memory DB through every major feature in order, asserting
state along the way. Real network calls (no mocks). Google Drive sync and the
`DEBUG_CHARTS`-gated chart editor are excluded by design.

Run:

```
flutter test integration_test/all_tests.dart -d macos
```

## Coverage exclusions (by intent)

| What | Why |
|---|---|
| `google_drive_sync_service.dart` | OAuth — out of scope this round |
| `chart_editor_dialog.dart`, `editable_charts_notifier.dart`, `default_charts_exporter.dart` | Gated behind `DEBUG_CHARTS=true` env var; production-disabled |
| `bug_reporter.dart`, `db_transfer_service.dart` | OS file pickers can't be driven |
| `tables.dart` | Drift schema declarations — no executable code |
| Old migrations in `database.dart` | Covered by `legacy_migration_test.dart` |
| Most strings in `app_strings.dart` | Unused translations for paths the test doesn't take |

## ACT I — Onboarding

1. **Landing page** — empty DB, tap **Start Fresh**
2. **Manage Intermediaries dialog** — create `Default` and `Broker Fineco`
   without closing the parent dialog (covers the round-with-dialog-staying-open
   pattern)
3. **Create accounts** — `Fineco` (EUR) and `Revolut` (USD)

## ACT II — Importing real-shaped data

4. **Fineco multi-year XLSX** — 216 rows over 2020-2025
   - skipRows = 12 (banner)
   - formula amount: `+Entrate − Uscite`
   - multi-column description: `Descrizione + Descrizione_Completa`
   - cumulative balance per row, recalc + verify all rows
5. **Save import config** + **re-import** — confirms the saved-config path
   reaches `quick_confirm_step.dart`
6. **Revolut CSV** — 40 rows, balance-from-column mode
6c. **account_detail search bar** — type query, clear via X icon
6b. **Manual transaction via UI** (TransactionEditScreen) — every field
    populated (descriptionFull, balanceAfter, currency override, status)
7. **Balance-delta CSV** — gap-row carry-forward (round-6 fix)

## ACT III — Investments + REAL NETWORK

8. **Lista Titoli XLSX** — type-from-column A/V (buy/sell), 13 events,
   real ISINs (IE00B4L5Y983 SWDA, IE00BKM4GZ66 EIMI, IE00B53H0131 UBS,
   etc.); ISIN lookup runs through real `IsinLookupService` to populate
   ticker/exchange/name
8b. **Manual asset event via UI** (AssetEventEditScreen) — qty, price,
    auto amount
8c. **Toolbar refresh button → REAL network sync.** Wait 45s. Asserts
    `marketPrices` rows, ETF `ter` populated, FX rates fetched. Hits:
    - `investing_com_service.dart` (price + composition)
    - `market_price_service.dart` (orchestration)
    - `composition_service.dart` (TER + composition)
    - `exchange_rate_service.dart` (FX)
    - `isin_lookup_service.dart` (already exercised at import)

## ACT IV — Income

9. **Income XLSX** import wizard
9b. **Income inline edit dialog** — change amount and type round-trip

## ACT V — Adjustments matrix

Every direction × treatment × frequency × cardinal feature exercised:

10a. **Weekly spread outflow** — grocery budget €100/week × 12
10b. **Monthly spread outflow** — car repair, linked-buffer reimbursement,
     refund (round-23 fix verification)
10c. **Quarterly spread outflow** — insurance €1200/year, 4 steps
10d. **Yearly spread** from Jan 31 — month-end re-anchor (round-3/5)
10e. **Monthly spread INFLOW** — 12 × +500 bonus distribution
10f. **Instant inflow** + manual entry (Gift)
10g. **Instant outflow Plumber via EventEditScreen UI**
10h. **Ephemeral inflow** — line of credit
10i. **Treatment change spread→instant** — orphan cleanup (round-20)
10j. **EventDetailScreen UI** — tap row, scroll timeline, regenerate
10k. **SelectionActionBar** — long-press to multi-select, bulk delete

## ACT VI — Asset CRUD UI

11A. **Create manual asset** via Assets screen FAB — name, ISIN, ticker,
     currency, taxRate populated
11B. **Edit asset** — change name via edit dialog
11C. **Move asset** to a different intermediary
11D. **Multi-select bulk delete** assets via SelectionActionBar

## ACT VII — Account recalc

12A. **Open balance recalc dialog** on Fineco from account_detail_screen
12B. **Switch balance mode** to `filtered` and save

## ACT VIII — Settings dialog

13A. **Open settings dialog** from toolbar gear icon
13B. **Toggle privacy mode** on/off (verifies `PrivacyText` reacts)
13C. **Change base currency** dropdown round-trip (EUR → USD → EUR)
13D. **Change number locale** dropdown
13E. **Change language** to Italiano then back to English
13F. **Tap Clear cache**

## ACT IX — Income deeper flows

14A. **Open income type filter** dropdown
14B. **Multi-select bulk delete** incomes

## ACT X — Dashboard

15. **Dashboard nav** + each tab opened explicitly:
    - **History tab** — renders `price_changes` widget that mounts
      `_AssetDailyChangesCard` + `_SummaryTotalsTable`
    - **Assets Overview tab** — `AllocationTab` renders pie charts with
      real market values
    - **Health tab**
    - **Cash Flow tab** — drag the INNERMOST scrollable (last) so the
      lazy ListView paints below-the-fold ExpansionTiles
      (`_YearlySummaryTable`, `_MonthlyGrid` × 2, `_YoYDiffTable`)

## ACT XI — Cleanup

16. **Cascade-delete sweep** — events, intermediaries, accounts, assets,
    incomes; verify cascades

## Final invariant

17. **Walkthrough done** — print counts of every entity for debug visibility

---

## Notes on test mechanics

- **Real network**: `pumpApp(useRealServices: true)` skips the NoOp market
  price service and the FX stub, so `InvestingComService` and the
  investing-backed `ExchangeRateService` run with real HTTP.
- **`testPreview` injection** in `import_screen.dart` mirrors production by
  calling `_loadSavedConfig` after auto-mapping, so the test that re-imports
  a file with a saved config lands on `quick_confirm_step` like the user
  flow does.
- **Dashboard scrolling** — `find.byType(Scrollable).last` is the
  innermost `ListView` (TabBarView's parent scrollable comes first).
  Dragging the last scrollable is what makes lazy children build.
- **Settle helpers** — `settle()` is 4×50 ms; `longSettle()` is 8×50 ms.
  Heavy `FutureProvider` chains (e.g. `allSeriesDataProvider` →
  `_incomeExpenseDataProvider`) need extra wall-clock time via
  `tester.runAsync(() => Future.delayed(...))`.
