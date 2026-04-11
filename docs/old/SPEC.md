# AssetManager - Technical Specification

> Technical specification for a cross-platform portable app. See FEATURES.md for use cases and feature descriptions.

---

## 1. Architecture Overview

### Platform: Cross-Platform Desktop & Mobile

Single codebase targeting **macOS, Windows, Linux, iOS, and Android** using Flutter. All data is local (SQLite), no server required. Single-user, offline-first.

| Concern | Technology |
|---------|-----------|
| UI + App Framework | Flutter (Dart) |
| UI Widgets | Material Design 3 (built-in) |
| State Management | Riverpod |
| Database | SQLite via `drift` |
| Calculations | SQL window functions + Dart logic |
| Charts | `fl_chart` |
| File Import | `csv`, `excel` (Dart) |
| Market Data | `dio` HTTP client → Yahoo Finance / Alpha Vantage |
| Local Storage | SQLite (single file, portable, backupable) |

### Architecture Diagram

```
+---------------------------------------------------+
|           Flutter UI (Material 3 + fl_chart)       |
|  Dashboard | Track | Invest | Analytics | Settings |
+------------------------+---+----------------------+
                         |   |
+------------------------+---+----------------------+
|           Business Logic (Dart)                    |
|                                                     |
|  +-----------------------------------------------+ |
|  | Calculation Engine                             | |
|  | - Snapshot computation (SQL + Dart)             | |
|  | - SMA / velocity / volatility (SQL windows)    | |
|  | - P/L formulas (exact Excel parity)            | |
|  | - Depreciation schedules                       | |
|  +-----------------------------------------------+ |
|                                                     |
|  +---------------+  +-------------+  +-----------+ |
|  | File Importer |  | Snapshot    |  | Market    | |
|  | - CSV         |  |   Engine    |  | Data Feed | |
|  | - XLSX/XLS    |  | - Daily     |  | - Prices  | |
|  | - Column map  |  |   compute   |  | - FX      | |
|  | - Dedup hash  |  |             |  |           | |
|  +---------------+  +-------------+  +-----------+ |
+------------------------+---+----------------------+
                         |   |
+------------------------+---+----------------------+
|           drift (type-safe SQLite ORM)             |
+---------------------------------------------------+
|           SQLite (single portable file)            |
+---------------------------------------------------+
```

### Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| App Framework | Flutter 3.x | Single codebase → Mac/Win/Linux/iOS/Android |
| Language | Dart | Type-safe, AOT compiled, great for mobile+desktop |
| UI | Material 3 | Built into Flutter, adaptive, dark mode |
| State | Riverpod | Reactive, testable, no boilerplate |
| Database ORM | drift | Type-safe SQL, migrations, reactive queries for SQLite |
| Charts | fl_chart | Native Flutter charting, performant |
| File Parsing | csv + excel | Pure Dart CSV/XLSX parsing |
| HTTP | dio | Market data fetching |
| Hashing | crypto (dart) | SHA-256 for import deduplication |
| Language | Italian UI labels, English codebase | Match MoneyHistory.xlsx conventions |

---

## 2. Data Model

### 2.1 Account & Transactions

```
Account
+-- id: int (autoincrement)
+-- name: string                    -- "Fineco", "Revolut", "KBC"
+-- type: enum                      -- BANK, BROKER, CRYPTO
+-- currency: string                -- "EUR", "USD", "CHF", "GBP"
+-- institution: string
+-- is_active: boolean
+-- include_in_net_worth: boolean
+-- created_at, updated_at

Transaction
+-- id: int (autoincrement)
+-- account_id: FK →Account
+-- operation_date: date
+-- value_date: date
+-- amount: decimal                 -- positive = income, negative = expense
+-- balance_after: decimal?
+-- description: string
+-- description_full: string?
+-- status: enum                    -- PENDING, SETTLED, CANCELLED
+-- category_id: FK →Category?
+-- currency: string
+-- tags: string[]
+-- expense_type: enum?             -- OPEX, CAPEX (null = unclassified)
+-- depreciation_id: FK →DepreciationSchedule?
+-- raw_metadata: text (JSON)?            -- original unmapped columns from import file
+-- import_hash: string?            -- SHA-256 of original source row (dedup)
+-- created_at

Category
+-- id: int (autoincrement)
+-- name: string                    -- "Casa", "Altre spese", "Rimborsi", "Stipendio"
+-- type: enum                      -- INCOME, EXPENSE, TRANSFER, REIMBURSEMENT
+-- is_essential: boolean           -- for essential vs non-essential breakdown
+-- default_expense_type: enum?     -- OPEX or CAPEX default for this category
+-- icon: string?
+-- color: string?
+-- parent_id: FK →Category?      -- hierarchical

AutoCategorizationRule
+-- id: int (autoincrement)
+-- pattern: string                 -- regex on description
+-- category_id: FK →Category
+-- priority: integer
+-- is_active: boolean
+-- created_at
```

---

### 2.2 Unified Asset Model

**Core design decision**: every asset is tracked through the same model. The system is **asset-agnostic** - it does not hardcode behavior per asset type. Assets are discovered from events (what has been bought/contributed). ETFs, stocks, pension, deposits, mortgages, crypto - all use `Asset` + `AssetEvent` + `AssetSnapshot`.

#### Asset

```
Asset
+-- id: int (autoincrement)
+-- name: string                    -- "iShares Core MSCI World", "Amazon AMZN", "Fondo Pensione"
+-- ticker: string?                 -- "SWDA.MI", "AMZN", null for pension/deposit
+-- isin: string?                   -- "IE00B4L5Y983"
+-- asset_type: enum                -- STOCK, STOCK_ETF, BOND_ETF, COMM_ETF, GOLD_ETC, MON_ETF,
                                    --   CRYPTO, CASH, PENSION, DEPOSIT, REAL_ESTATE, ALTERNATIVE, LIABILITY
+-- asset_group: string             -- maps to MoneyHistory GROUP column ("STOCK ETF", "BOND ETF", "CASH")
+-- currency: string
+-- exchange: string?               -- "XETR", "NASDAQ"
+-- country: string?                -- domicile: "IE", "US", "IT"
+-- region: string?                 -- "World", "Europe", "Emerging Markets", "US"
+-- sector: string?                 -- "Broad Market", "Government Bonds", "Commodities"
+-- ter: decimal?                   -- Total Expense Ratio (annual %)
+-- tax_rate: decimal?              -- asset-specific tax rate for liquidation calc (default: AppConfig.TAX_RATE)
+-- valuation_method: enum          -- MARKET_PRICE (use ticker/price feed), EVENT_DRIVEN (use latest REVALUE),
                                    --   BALANCE (use account balance). Determines how daily value is computed.
+-- is_active: boolean
+-- include_in_net_worth: boolean
+-- notes: string?
+-- created_at, updated_at
```

#### AssetEvent

Every time money enters or leaves an asset. Replaces SecurityTransaction, StockVesting, PensionContribution.

```
AssetEvent
+-- id: int (autoincrement)
+-- asset_id: FK →Asset
+-- date: date
+-- type: enum                      -- BUY, SELL, DIVIDEND, SPLIT, VEST, CONTRIBUTE,
                                    --   INTEREST, REVALUE, TRANSFER_IN, TRANSFER_OUT
+-- quantity: decimal?              -- shares/units (null for fixed-value assets)
+-- price: decimal?                 -- price per unit (null for contribution/interest)
+-- amount: decimal                 -- total EUR value
+-- currency: string
+-- exchange_rate: decimal?         -- for cross-currency
+-- commission: decimal?
+-- tax_withheld: decimal?
+-- source: string?                 -- "RSU_VEST", "TFR", "EMPLOYER", "DCA", "MANUAL"
+-- notes: string?
+-- raw_metadata: text (JSON)?            -- original unmapped columns from import file
+-- import_hash: string?            -- SHA-256 of original source row (dedup)
+-- created_at
```

**Event types are asset-agnostic** - any event type can be used with any asset:

| Event Type | Meaning | Affects Quantity | Affects Invested |
|-----------|---------|:---:|:---:|
| BUY | Purchase units at a price | +qty | +amount |
| SELL | Sell units at a price | -qty | -cost_basis (FIFO) |
| VEST | Receive units (e.g. RSU) at a price | +qty | +amount |
| CONTRIBUTE | Add money (e.g. pension, deposit) | - | +amount |
| DIVIDEND | Cash distribution | - | - (passive income) |
| INTEREST | Interest earned | - | - (passive income) |
| SPLIT | Quantity adjustment, no value change | +/-qty | - |
| REVALUE | Update total value (EVENT_DRIVEN assets) | - | - |
| TRANSFER_IN | Receive from another asset/account | +qty | +amount |
| TRANSFER_OUT | Send to another asset/account | -qty | -cost_basis |

The `source` field on AssetEvent provides context (e.g. "RSU_VEST", "TFR", "EMPLOYER", "DCA") without requiring type-specific logic.

#### AssetSnapshot

Daily materialized state. The **day-by-day value, bought, growth** table.

```
AssetSnapshot
+-- id: int (autoincrement)
+-- asset_id: FK →Asset
+-- date: date
+-- value: decimal                  -- what it's worth today (market value)
+-- invested: decimal               -- cumulative money put in (cost basis)
+-- growth: decimal                 -- value - invested
+-- growth_percent: decimal         -- growth / invested (when invested > 0)
+-- after_tax_value: decimal        -- value after applying asset's tax_rate on gains (Liquidabile component)
                                    -- = invested + growth * (1 - tax_rate) if growth > 0, else value
+-- quantity: decimal?              -- current shares/units
+-- price: decimal?                 -- current price per unit
+-- (unique: asset_id + date)
```

**Computation is driven by `valuation_method`** (not asset_type):

| valuation_method | value | invested |
|-----------------|-------|----------|
| MARKET_PRICE | quantity * market_price * fx_rate | SUM(inflow amounts) - SUM(outflow cost_basis, FIFO) |
| EVENT_DRIVEN | amount from latest REVALUE event | SUM(CONTRIBUTE/BUY amounts) |
| BALANCE | latest known balance (from account or event) | balance - SUM(INTEREST/DIVIDEND amounts) |

`growth = value - invested` always. `after_tax_value = invested + MAX(growth, 0) * (1 - tax_rate) + MIN(growth, 0)`.

**Liabilities** (mortgages, loans): value is negative (outstanding debt). Events of type CONTRIBUTE reduce the debt (payments). Growth = 0 or negative (interest accrual).

---

### 2.3 Portfolio & Allocation

```
Portfolio
+-- id: int (autoincrement)
+-- name: string                    -- "Marco Bazzani PX080"
+-- description: string?
+-- is_active: boolean
+-- model_id: FK →PortfolioModel?
+-- created_at, updated_at

PortfolioAsset (many-to-many)
+-- portfolio_id: FK →Portfolio
+-- asset_id: FK →Asset
+-- (unique: portfolio_id + asset_id)

PortfolioModel
+-- id: int (autoincrement)
+-- name: string                    -- "PX080"
+-- description: string?
+-- allocations: text (JSON)              -- [{"asset_group": "STOCK_ETF", "weight": 0.60}, ...]
+-- created_at
```

---

### 2.4 DailySnapshot (Global Aggregation)

Aggregates all AssetSnapshots + account balances into a single daily row. This is the main dashboard time-series.

```
DailySnapshot
+-- id: int (autoincrement)
+-- date: date (unique)
+-- account_balances: text (JSON)         -- {"fineco": 12345.67, "revolut": 890.12, ...}
+-- -- Core aggregates (from AssetSnapshot sums)
+-- portfolio_value: decimal        -- SUM(asset_snapshot.value) for investment types
+-- invested_amount: decimal        -- SUM(asset_snapshot.invested) for investment types
+-- liquid_cash: decimal            -- SUM(bank balances + buffer balances)
+-- total_savings: decimal          -- RT = invested + liquid - gains_registered - sales_registered
+-- total_assets: decimal           -- AT = SUM(all asset values + cash)
+-- liquidabile: decimal            -- Liquidabile = SUM(asset_snapshot.after_tax_value) + liquid_cash
                                    -- What you'd actually get if you sold everything today, after each asset's own tax
+-- -- P/L metrics
+-- pl_eur: decimal                 -- portfolio_value - invested_amount
+-- net_pl_eur: decimal             -- MIN(pl * (1-TAX_RATE), pl)
+-- pl_at_percent: decimal          -- (AT - pension_value) / (RT + extra_cash) - 1
+-- pl_ptf_percent: decimal         -- (portfolio + gains + sales) / (invested + sales) - 1
+-- period_pl_eur: decimal          -- daily delta of net_pl_eur
+-- period_pl_at_percent: decimal
+-- period_pl_ptf_percent: decimal
+-- log_return: decimal             -- LN(AT_today / AT_yesterday)
+-- -- Moving averages (windows from AppConfig)
+-- sma_savings: decimal
+-- sma_expenses: decimal
+-- sma_net_pl: decimal
+-- annualized_volatility: decimal  -- STDEV_S(log_returns, VOL_WINDOW) * SQRT(252)
+-- delta_sma_rt: decimal
+-- -- Income/Expense (from daily RT change)
+-- income: decimal                 -- MAX(daily_RT_change, 0)
+-- expenses: decimal               -- MIN(daily_RT_change, 0)
+-- cumulative_expenses: decimal
+-- -- Depreciation-adjusted
+-- expenses_adjusted: decimal      -- expenses with CAPEX replaced by depreciation
+-- -- Registered events
+-- reimbursements_registered: decimal
+-- income_registered: decimal
+-- gains_registered: decimal
+-- sales_registered: decimal
+-- extra_cash: decimal
+-- -- Velocity (delta of SMA * 30.4)
+-- spending_velocity: decimal
+-- savings_velocity: decimal
+-- profit_velocity: decimal
+-- -- Salary & ratios
+-- daily_ral: decimal
+-- eu_over_ral: decimal
+-- -- Pension & drawdown
+-- pension_value: decimal          -- from AssetSnapshot where type=PENSION
+-- diff_hth: decimal               -- MAX(cumulative_pl) - current_pl
+-- rt_at_ratio: decimal
```

---

### 2.5 OPEX/CAPEX & Depreciation

```
DepreciationSchedule
+-- id: int (autoincrement)
+-- transaction_id: FK →Transaction?  -- the CAPEX purchase (optional)
+-- asset_name: string              -- "Fiat 500", "Lavatrice"
+-- asset_category: string          -- "AUTO", "APPLIANCE", "RENOVATION"
+-- total_amount: decimal
+-- currency: string
+-- method: enum                    -- LINEAR, DECLINING_BALANCE, CUSTOM
+-- start_date: date
+-- end_date: date
+-- useful_life_months: integer
+-- direction: enum                 -- FORWARD, BACKWARD
+-- buffer_id: FK →Buffer?        -- optional: buffer absorbs monthly cost
+-- is_active: boolean
+-- created_at, updated_at

DepreciationEntry (materialized monthly amounts)
+-- id: int (autoincrement)
+-- schedule_id: FK →DepreciationSchedule
+-- date: date                      -- first of month
+-- amount: decimal                 -- depreciation for this period
+-- cumulative: decimal
+-- remaining: decimal              -- total - cumulative
+-- (unique: schedule_id + date)
```

**Forward**: start_date = purchase, entries go into the future.
**Backward**: end_date = purchase, entries go into the past (retroactive smoothing).

---

### 2.6 Buffer Accounts

```
Buffer
+-- id: int (autoincrement)
+-- name: string                    -- "AUTO", "Fondo Pensione", "Pre Busta"
+-- target_amount: decimal?
+-- linked_depreciation_id: FK →DepreciationSchedule?
+-- is_active: boolean
+-- created_at, updated_at

BufferTransaction
+-- id: int (autoincrement)
+-- buffer_id: FK →Buffer
+-- operation_date: date
+-- value_date: date
+-- description: string
+-- amount: decimal
+-- currency: string
+-- balance_after: decimal
+-- is_payroll: boolean
+-- is_force_last: boolean
+-- is_reimbursement: boolean
+-- linked_transaction_id: FK →Transaction?
+-- created_at
```

---

### 2.7 Supporting Entities

```
MarketPrice
+-- asset_id: FK →Asset
+-- date: date
+-- close_price: decimal
+-- currency: string
+-- (unique: asset_id + date)

ExchangeRate
+-- from_currency: string
+-- to_currency: string
+-- date: date
+-- rate: decimal
+-- (unique: from + to + date)

RegisteredEvent
+-- id: int (autoincrement)
+-- date: date
+-- type: enum                      -- STIPENDIO, ENTRATA, INCASSO, VENDITA, DONAZIONE, RIMBORSO
+-- description: string
+-- amount: decimal
+-- is_personal: boolean            -- MIO flag
+-- created_at

HealthReimbursement
+-- id: int (autoincrement)
+-- provider: string
+-- invoice_number: string
+-- document_date: date
+-- claim_amount: decimal
+-- beneficiary: string
+-- reimbursed_amount: decimal
+-- reimbursement_date: date?
+-- paid_amount: decimal
+-- uncovered_amount: decimal
+-- reimbursement_percent: decimal
+-- processing_days: integer
+-- is_covered: boolean

PerformanceSummary (materialized)
+-- year: integer
+-- month: integer?                 -- NULL for annual, 1-12 for monthly
+-- pl_at_percent: decimal
+-- pl_ptf_percent: decimal
+-- eoy_pl_eur: decimal
+-- yoy_diff_eur: decimal
+-- absolute_return: decimal
+-- reverse_compound: decimal
+-- is_ytd: boolean
+-- (unique: year + month)

CalendarDay
+-- date: date (PK)
+-- is_bank_holiday: boolean
+-- is_company_holiday: boolean
+-- holiday_name: string?
+-- is_working_day: boolean
+-- month_working_days: integer

AppConfig (key-value)
+-- key: string (PK)
+-- value: string
+-- description: string
-- Seeded from MoneyHistory Graph row 3455:
-- RT_SMA_WINDOW = 365
-- EXPENSE_SMA_WINDOW = 365
-- RAL_WINDOW = 365
-- VOL_WINDOW = 7
-- NET_PL_SMA_WINDOW = 1530
-- TAX_RATE = 0.26
-- SWR = 0.0275
-- BASE_CURRENCY = EUR
-- DEFAULT_DEPRECIATION_METHOD = LINEAR
```

---

### 2.8 Entity Relationships

```
Account --< Transaction >-- Category
                |
                +-- DepreciationSchedule --< DepreciationEntry

Asset --< AssetEvent
Asset --< AssetSnapshot
Asset --< MarketPrice
Asset >--< Portfolio (via PortfolioAsset)
Portfolio >-- PortfolioModel

Buffer --< BufferTransaction
Buffer >-- DepreciationSchedule (optional)

DailySnapshot = daily aggregation of AssetSnapshot + Account balances
PerformanceSummary = annual/monthly aggregation of DailySnapshot
```

---

### 2.9 Indexes

```sql
-- Daily snapshots
CREATE INDEX idx_daily_snapshot_date ON daily_snapshot(date DESC);

-- Asset snapshots (per-asset time series)
CREATE UNIQUE INDEX idx_asset_snapshot_asset_date ON asset_snapshot(asset_id, date DESC);

-- Transactions
CREATE INDEX idx_transaction_account_date ON transaction(account_id, operation_date DESC);
CREATE INDEX idx_transaction_category ON transaction(category_id);
-- Full-text search via SQLite FTS5

-- Market prices
CREATE UNIQUE INDEX idx_market_price_asset_date ON market_price(asset_id, date);

-- Asset events
CREATE INDEX idx_asset_event_asset_date ON asset_event(asset_id, date DESC);

-- Performance
CREATE INDEX idx_performance_year_month ON performance_summary(year, month);

-- Buffers
CREATE INDEX idx_buffer_tx_buffer_date ON buffer_transaction(buffer_id, operation_date DESC);

-- Depreciation
CREATE INDEX idx_depreciation_entry_date ON depreciation_entry(schedule_id, date);
```

---

## 3. Key Calculations

All formulas from MoneyHistory.xlsx Graph sheet (row 3000) with config from row 3455.
Implemented as SQL window functions (via drift) and Dart helper functions.

### 3.1 Core Aggregates

```sql
-- Portfolio Value = sum of investment-type asset snapshots
SELECT SUM(s.value) AS portfolio_value
FROM asset_snapshot s
JOIN asset a ON s.asset_id = a.id
WHERE a.asset_type IN ('STOCK','STOCK_ETF','BOND_ETF','COMM_ETF','GOLD_ETC','MON_ETF','CRYPTO')
  AND s.date = :date;

-- Invested Amount = cost basis of all investments + pension
SELECT SUM(s.invested) AS invested_amount
FROM asset_snapshot s
JOIN asset a ON s.asset_id = a.id
WHERE a.asset_type IN ('STOCK','STOCK_ETF','BOND_ETF','COMM_ETF','GOLD_ETC','MON_ETF','CRYPTO','PENSION')
  AND s.date = :date;

-- Liquid Cash = bank balances + buffer balances
-- Total Savings (RT) = invested + liquid - gains_registered - sales_registered
-- Total Assets (AT) = SUM(all asset values) + liquid_cash
```

### 3.2 Liquidabile (After-Tax Liquidation Value)

```dart
// Each asset has its own taxRate (defaults to AppConfig.TAX_RATE = 0.26)
// Liquidabile = what you'd get if you sold everything today
final liquidabile = assetSnapshots.fold(0.0, (sum, s) => sum + s.afterTaxValue) + liquidCash;

// Per-asset afterTaxValue:
// if growth > 0: invested + growth * (1 - taxRate)  -- gains are taxed
// if growth <= 0: value                              -- losses are not deductible
```

### 3.3 P/L

```dart
final plEur = portfolioValue - investedAmount;

// Tax-adjusted: gains taxed at 26%, losses at face value
final netPlEur = min(plEur * (1 - taxRate), plEur);

// P/L on Total Assets (excludes pension)
final plAtPercent = (totalAssets - pensionValue) / (totalSavings + extraCash) - 1;

// P/L on Portfolio (includes registered gains/sales)
final plPtfPercent = (portfolioValue + gainsRegistered + salesRegistered)
    / (investedAmount + salesRegistered) - 1;

// Period P/L
final periodPlEur = today.netPlEur - yesterday.netPlEur;
```

### 3.4 Moving Averages

```sql
-- SMA via SQL window functions (drift)
SELECT date, total_savings,
  AVG(total_savings) OVER (ORDER BY date ROWS BETWEEN :rt_sma_window PRECEDING AND CURRENT ROW) AS sma_savings,
  AVG(net_pl_eur) OVER (ORDER BY date ROWS BETWEEN :net_pl_sma_window PRECEDING AND CURRENT ROW) AS sma_net_pl
FROM daily_snapshot
ORDER BY date;
```

### 3.5 Velocity

```dart
// Velocity = delta of SMA * 30.4 (monthly rate)
final spendingVelocity = (today.smaExpenses - yesterday.smaExpenses) * 30.4;
final savingsVelocity  = (today.smaSavings - yesterday.smaSavings) * 30.4;
final profitVelocity   = (today.smaNetPl - yesterday.smaNetPl) * 30.4;
```

### 3.6 Income & Expenses (Macro)

```dart
final dailyRtChange = today.totalSavings - yesterday.totalSavings;
final income   = max(dailyRtChange, 0);
final expenses = min(dailyRtChange, 0);
cumulativeExpenses += expenses;

// Depreciation-adjusted
final dailyDepreciation = activeEntries.fold(0.0, (s, e) => s + e.amount) / daysInMonth;
final expensesAdjusted = expenses + depreciationOffset;

final dailyRal = registeredIncomeSum / ralWindow;
final euOverRal = income / dailyRal;
```

### 3.7 Volatility & Risk

```sql
-- Log returns and volatility via SQL
SELECT date,
  LN(total_assets / LAG(total_assets) OVER (ORDER BY date)) AS log_return
FROM daily_snapshot;
```

```dart
// Annualized volatility (sample stdev of log returns * sqrt(252))
import 'dart:math';
final stdev = sampleStdev(logReturns.take(volWindow));
final annualizedVolatility = stdev * sqrt(252);
final diffHth = allTimeMaxNetPl - currentNetPl; // max drawdown from peak
```

### 3.8 Italian Capital Gains Tax

```dart
// Per-asset using asset.taxRate (each asset can have its own rate, default 26%)
final capitalGain = currentValue - costBasis;
final rate = asset.taxRate ?? appConfig.taxRate;
final taxToPay = max(capitalGain * rate, 0);
final netGain = capitalGain - taxToPay;
final netValue = costBasis + netGain;
// RSU: costBasis = vestPrice * shares * fxRateAtVest
// Pension: may have different taxRate than investments
// Deposits: interest may have different withholding rate
```

### 3.9 Performance Summary

```dart
reverseCompound[2018] = 1 + plAtPercent[2018];
reverseCompound[year] = reverseCompound[year - 1] * (1 + plAtPercent[year]);
yoyDiffEur = eoyPlEur[year] - eoyPlEur[year - 1];
```

### 3.10 Depreciation

```dart
List<DepreciationEntry> computeDepreciation(DepreciationSchedule schedule) {
  final entries = <DepreciationEntry>[];
  if (schedule.method == DepreciationMethod.linear) {
    final monthly = schedule.totalAmount / schedule.usefulLifeMonths;
    for (var month = schedule.startDate; month.isBefore(schedule.endDate); month = nextMonth(month)) {
      entries.add(DepreciationEntry(date: month, amount: monthly, ...));
    }
  } else if (schedule.method == DepreciationMethod.decliningBalance) {
    final rate = 2 / schedule.usefulLifeMonths;
    var remaining = schedule.totalAmount;
    for (var month = schedule.startDate; month.isBefore(schedule.endDate); month = nextMonth(month)) {
      final amount = remaining * rate;
      remaining -= amount;
      entries.add(DepreciationEntry(date: month, amount: amount, ...));
    }
  }
  // direction=BACKWARD: startDate is in the past, entries cover historical months
  // direction=FORWARD: startDate is purchase date, entries go into the future
  return entries;
}
```

---

## 4. AssetSnapshot Computation

Daily computation to build per-asset snapshots. Logic is driven by `valuation_method`, not asset type:

```dart
const inflowEvents = {EventType.buy, EventType.vest, EventType.contribute, EventType.transferIn};
const outflowEvents = {EventType.sell, EventType.transferOut};
const passiveIncomeEvents = {EventType.interest, EventType.dividend};

Future<void> computeDailyAssetSnapshots(DateTime date, AppDatabase db) async {
  final assets = await db.getActiveAssets();
  for (final asset in assets) {
    final events = await db.getEvents(asset.id, upTo: date);

    // --- Compute VALUE based on valuationMethod ---
    double value;
    double? quantity, price;

    switch (asset.valuationMethod) {
      case ValuationMethod.marketPrice:
        price = await db.getMarketPrice(asset.id, date);
        final fx = await db.getExchangeRate(asset.currency, baseCurrency, date);
        quantity = sumQuantities(events, inflowEvents) - sumQuantities(events, outflowEvents);
        value = quantity * price * fx;
      case ValuationMethod.eventDriven:
        value = getLatestEventAmount(events, EventType.revalue);
        quantity = null;
        price = null;
      case ValuationMethod.balance:
        value = await getLatestBalance(asset, date);
        quantity = null;
        price = null;
    }

    // --- Compute INVESTED (always from events) ---
    var invested = sumAmounts(events, inflowEvents) - sumCostBasis(events, outflowEvents); // FIFO
    final passiveIncome = sumAmounts(events, passiveIncomeEvents);

    // For BALANCE-type assets, invested = value - passiveIncome
    if (asset.valuationMethod == ValuationMethod.balance) {
      invested = value - passiveIncome;
    }

    // --- Compute GROWTH and AFTER-TAX ---
    final growth = value - invested;
    final growthPct = invested != 0 ? growth / invested : 0.0;
    final taxRate = asset.taxRate ?? appConfig.taxRate;
    final afterTaxValue = invested + max(growth, 0) * (1 - taxRate) + min(growth, 0);

    await db.upsertAssetSnapshot(AssetSnapshotCompanion(
      assetId: Value(asset.id), date: Value(date),
      value: Value(value), invested: Value(invested),
      growth: Value(growth), growthPercent: Value(growthPct),
      afterTaxValue: Value(afterTaxValue),
      quantity: Value(quantity), price: Value(price),
    ));
  }
}
```

---

## 5. Generic File Importer

### 5.1 Philosophy

No MoneyHistory.xlsx migration. The app imports the **same raw source files** that the Excel workbook used: Fineco bank exports, Revolut exports, KBC statements, Fineco Dossier Titoli (securities). Everything is computed fresh from imported transactions and events.

The importer is **format-agnostic** (CSV, XLSX, XLS) and **source-agnostic** (no bank-specific logic). The user manually maps columns on every import.

### 5.2 Import Flow

```
1. User picks a file (CSV, XLSX, XLS) via native file picker
2. System reads the file into a list of row maps (Dart)
   - CSV: auto-detect delimiter, encoding (via `csv` package)
   - XLSX/XLS: sheet selector if multiple sheets (via `excel` package)
3. User sees a preview of all columns and first N rows
4. User picks target entity: "Account Transaction" or "Asset Event"
5. User maps columns:
   For Transaction:       For AssetEvent:
   - date (required)      - date (required)
   - amount (required)    - amount (required)
   - description          - type (BUY/SELL/VEST/...)
   - balance              - quantity
   - currency             - price
   - status               - currency
                          - exchange_rate
                          - commission
                          - source
6. User selects target Account (for transactions) or target Asset (for events)
7. Preview: show mapped rows with target field values
8. Confirm: rows are inserted into the database
9. Unmapped columns are stored as JSON in a `raw_metadata` field
```

### 5.3 Post-Import Editing (Manual Adjustments)

All imported records are fully editable after import. This is critical for aligning movements across assets:

- **Edit any field** including date, amount, description, category
- **Date alignment**: if a bank shows a transaction on Jan 5 but the actual settlement affects another asset on Jan 7, the user can adjust the date to align them
- **Reclassify**: change a Transaction's category, expense_type (OPEX/CAPEX), or link it to a DepreciationSchedule
- **Split**: break one imported row into multiple transactions
- **Delete**: remove duplicates or irrelevant rows

### 5.4 Deduplication (Row Hashing)

Each imported row is hashed to detect re-imports:

1. **Hash computation**: for each row in the source file, compute a SHA-256 hash of the entire row content (all columns, in order, concatenated). This is the `import_hash`.
2. **On import**: before inserting, check if `import_hash` already exists in the target table (Transaction or AssetEvent) for the same account/asset.
3. **Auto-skip**: rows with a matching hash are silently skipped (not imported again).
4. **New rows**: rows with no matching hash are imported normally.

This ensures that importing the same file twice produces no duplicates, while genuinely new rows (even with the same date/amount) are still imported.

```
Transaction.import_hash: string?   -- SHA-256 of original source row
AssetEvent.import_hash: string?    -- SHA-256 of original source row
```

Index: `(account_id, import_hash)` on Transaction, `(asset_id, import_hash)` on AssetEvent.

### 5.5 Raw Metadata Preservation

Every imported record stores the original unmapped columns as JSON:

```
Transaction.raw_metadata: text (JSON)    -- {"Descrizione_Completa": "...", "Stato": "Contabilizzato", ...}
AssetEvent.raw_metadata: text (JSON)     -- {"Titolo": "iShares Core MSCI World", "Controvalore": 1234.56, ...}
```

This allows the user to reference original bank data without losing anything.

### 5.6 Supported File Formats

| Format | Dart Package | Notes |
|--------|-------------|-------|
| CSV | `csv` | Auto-detect delimiter, encoding |
| XLSX | `excel` | Sheet selector if multiple sheets |
| XLS | `excel` | Legacy Excel format |
| TSV | `csv` (tab separator) | Tab-separated |

---

## 6. Data Feeds

### 6.1 Market Prices

| Source | Method | Frequency |
|--------|--------|-----------|
| Market prices | Yahoo Finance API / Alpha Vantage | Daily (EOD) |
| FX rates | ECB API or Yahoo Finance | Daily |

### 6.2 Daily Snapshot Job

Scheduled daily (market close + 1h):
1. Fetch market prices for all active MARKET_PRICE assets
2. Fetch FX rates (EUR/USD, EUR/CHF, EUR/GBP)
3. Compute AssetSnapshot for every active asset
4. Aggregate into DailySnapshot (RT, AT, P/L, SMAs, velocity, volatility)
5. Compute depreciation-adjusted expenses
6. Upsert DepreciationEntry for active schedules
7. Store DailySnapshot

---

## 7. Service Layer (Dart)

Since this is a local app (no server), business logic is exposed via Dart service classes, not REST APIs. The UI layer calls services directly.

```dart
// Service classes (in lib/services/)
class DashboardService        // summary, net-worth-history
class AccountService          // CRUD accounts, list transactions
class TransactionService      // CRUD, bulk-categorize, split
class CategoryService         // CRUD categories + auto-categorization rules
class AssetService            // CRUD assets, snapshots, events
class AssetEventService       // CRUD events
class PortfolioService        // CRUD portfolios, assets, performance
class SnapshotService         // daily/asset snapshots, analytics (velocity, volatility)
class DepreciationService     // CRUD schedules, compute entries
class BufferService           // CRUD buffers + transactions
class RegisteredEventService  // CRUD registered income/sales/gains
class ReimbursementService    // CRUD health reimbursements
class ImportService           // file upload → column preview → mapping → confirm import
class MarketDataService       // fetch prices + FX rates (dio)
class ConfigService           // read/write AppConfig
class ExportService           // export snapshots/transactions as CSV
```

Each service receives the drift `AppDatabase` via constructor injection (provided by Riverpod).

---

## 8. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Screen load | < 2s for dashboard |
| Chart render | < 1s for 3,600 data points |
| Daily snapshot job | < 30s |
| File import (1000 rows) | < 5s |
| Database size (10 years) | < 1 GB |
| Backup | Manual export of SQLite file (portable) |
| Security | None (single user, local device). SQLite file is user-owned. |
| Platforms | macOS, Windows, Linux, iOS, Android |
| Data integrity | Reconciliation checks after every import |
| Formula parity | Computed values must match Excel within +/-0.01 EUR / +/-0.01% |
| Unified model | All assets through Asset + AssetEvent + AssetSnapshot, no special-case entities |
