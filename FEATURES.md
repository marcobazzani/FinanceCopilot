# AssetManager - Use Cases & Features

> Personal wealth management application that replaces MoneyHistory.xlsx (~18 sheets, ~25,000 rows, daily tracking since 2017) with a proper application.

---

## 1. Product Vision

### Problem
All personal finance data lives in a single Excel file that is fragile, manual to update, and impossible to use on mobile. The workbook has grown organically over 8+ years with complex cross-sheet formulas, manual adjustments, and accumulated conventions that make it hard to maintain and extend.

### Goal
Build an application that:
1. Imports and replaces all MoneyHistory.xlsx functionality
2. Provides automation (market data feeds, scheduled calculations, bank CSV import)
3. Adds features the spreadsheet cannot do well (exposure charts, depreciation, OPEX/CAPEX separation)
4. Provides a single source of truth for all personal financial data

### Non-Goals (v1)
- Multi-user / advisor features
- Learning platform

### Platform
Cross-platform portable desktop & mobile app: **macOS, Windows, Linux, iOS, Android**.
Built with **Flutter (Dart)**, local **SQLite** database, no server required. Single-user, offline-first.

---

## 2. User Persona

**Primary user**: Marco - tech-savvy investor who maintains a complex Excel workbook, uses Fineco and Revolut as primary financial tools. Needs daily tracking granularity with annual performance summaries. Italian tax context (26% capital gains).

---

## 3. Feature Modules

### 3.1 Main Dashboard (replaces Graph sheet)

The Graph sheet is the heart of MoneyHistory.xlsx: ~3,600 daily rows x 52 columns tracking everything. The dashboard must replicate all of this.

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Account Balances | Graph: Fineco, Revolut, KBC, Buffer columns | Daily balance per account, multi-currency |
| Net Worth (AT) | Graph: Asset Totale | Total current market value of everything |
| Total Savings (RT) | Graph: Risparmio Totale | Money actually contributed (excludes market returns) |
| RT/AT Ratio | Graph: RT/AT | Savings-to-asset ratio |
| Portfolio Value | Graph: Portafoglio | Sum of all investment holdings at market |
| Invested Amount | Graph: Investito | Total cost basis |
| Liquid Cash | Graph: Liquidi | Sum of bank + buffer balances |
| Liquidabile | Graph: Liquidabile + Liquidi | After-tax value if everything is sold: SUM(each asset after its own tax rate) + cash |
| P/L EUR | Graph: P/L in EUR | Absolute profit/loss = portfolio - invested |
| Net P/L | Graph: Net P/L | Tax-adjusted P/L (gains taxed at 26%, losses at face) |
| P/L AT % | Graph: P/L AT % | % return on total assets (excl. pension) |
| P/L PTF % | Graph: P/L PTF % | % return on portfolio |
| Period P/L | Graph: P/L Periodo | Daily/period change in EUR and % |
| Break-even | Graph: P/L AT to 0 | Distance to break-even |
| RT SMA | Graph: RT-SMA | 365-day simple moving average of savings |
| Delta SMA/RT | Graph: Delta SMA/RT | Savings vs its SMA |
| Net Worth Trend | Graph time series | Sparkline/area chart of AT over time |
| Date Range Selector | - | 1M, 3M, 6M, YTD, 1Y, 3Y, 5Y, MAX |

---

### 3.2 Income & Expense Tracking (replaces Graph income/expense columns + Entrate Registrate)

**Key concept**: MoneyHistory.xlsx tracks income/expenses at TWO levels:

1. **Macro level** (Graph sheet): derived from daily RT changes. Positive RT change = income day, negative = expense day. This is a savings-rate tracker, not a line-item budget.
2. **Micro level** (Fineco/Revolut transactions): line-item categorized spending from bank statements with MoneyMap categories.

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Daily Income (Entrate) | Graph: MAX(daily_RT_change, 0) | Macro income from savings change |
| Daily Expenses (Uscite) | Graph: MIN(daily_RT_change, 0) | Macro expenses from savings change |
| Cumulative Expenses | Graph: Uscite cumulate | Running total of expenses |
| Expense SMA | Graph: SMA Spese | 365-day moving average of expenses |
| Daily RAL | Graph: Daily RAL | Annualized salary accrual (365-day window) |
| E/U over RAL | Graph: E/U over RAL | Income/expense ratio vs gross salary |
| Registered Income | Entrate Registrate | Manual income entries: STIPENDI, ENTRATE, INCASSI, VENDITA, DONAZIONE, RIMBORSO |
| Registered Reimbursements | Entrate Registrate | Rimborsi, Guadagni, Vendite, Extra Cassa |
| Transaction Categories | FinecoMY: Moneymap | Casa, Altre spese, Rimborsi, etc. |
| Income/Expense Trends | Andamento Entrate Uscite | Chart data for trend visualization |
| **OPEX vs CAPEX** | NEW | Tag transactions as operating vs capital expense |
| **Depreciation-adjusted view** | NEW | Show expenses with CAPEX smoothed over useful life |

---

### 3.3 Unified Asset Tracker (replaces HistoryInvest + Amazon History + PPP_FULL + Stock Plan)

**Key design**: ONE asset-agnostic model. The system does not hardcode asset types - it discovers assets from what has been bought/contributed in the past. Every asset, regardless of type, is tracked with the same three daily metrics:
- **Day-by-day value**: what is it worth today?
- **Day-by-day invested/bought**: how much money went in?
- **Day-by-day growth**: value - invested (how much the market/interest added)

This eliminates the need for separate Stock Plan, PPP, and Amazon History sheets. The system treats all assets uniformly - an ETF, a pension fund, a deposit account, and a cryptocurrency are all just "assets with events".

**Per-asset tax handling**: each asset carries its own tax rate for computing the **after-tax liquidation value** (Liquidabile). Italian stocks/ETFs use 26%, pension funds have different tax treatment, deposits may have different rates. This allows computing the total "Liquidabile" = what you'd actually get if you sold everything today.

**RSU handling**: a vest event is just a buy event on the stock at vest price with source=RSU. Tax sell at vest is a sell event. No separate entity needed.

**Liability handling**: mortgages and loans are assets with negative value. A mortgage is created with a REVALUE event for the outstanding balance (negative), and monthly payments reduce it. Liabilities subtract from net worth.

**Portfolio composition** (from HistoryInvest):
- Asset groups: CASH, STOCK, BOND ETF, STOCK ETF, COMM ETF, GOLD ETC, MON ETF
- Percent allocation per asset
- Date ranges (DA/A) for position tracking
- Tax flag tracking

**Pension tracking** (from PPP_FULL):
- Monthly contributions by source: TFR (severance), Employer
- Cumulative totals, TFR/Azienda ratio
- Gain PTF / Gain Asset / Annualized return
- DELTA CMP (delta vs cost)

---

### 3.4 Velocity Metrics (replaces Graph velocity columns)

Unique to MoneyHistory.xlsx - measures the *rate of change* of financial metrics.

| Metric | Excel Source | Formula |
|--------|-------------|---------|
| Spending Velocity | Graph: Velocita di spesa | delta(SMA_expenses) * 30.4 (monthly rate) |
| Savings Velocity | Graph: Velocita di risparmio | delta(SMA_savings) * 30.4 |
| Profit Velocity | Graph: Velocita di profitto Net P/L | delta(SMA_net_pl) * 30.4 |

Positive = accelerating, Negative = decelerating.

---

### 3.5 Volatility & Risk (replaces Graph volatility columns)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Log Returns | Graph: Log | LN(AT_today / AT_yesterday) |
| Annualized Volatility | Graph: Vol Annuale | STDEV.S over 7-day window * SQRT(252) |
| Max Drawdown (Diff HTH) | Graph: Diff HTH | MAX(cumulative_pl) - current_pl |

---

### 3.6 Performance Summary (replaces Performance sheet)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Annual P/L AT % | Performance | Yearly return on total assets |
| Annual P/L PTF % | Performance | Yearly return on portfolio |
| EOY P/L EUR | Performance | End-of-year absolute P/L |
| YoY Difference | Performance: Diff P/L EUR | Year-over-year change |
| Absolute Return | Performance | Cumulative absolute return |
| Reverse Compound | Performance | Compounded return since 2018 baseline |
| Monthly Breakdown | Performance | Same metrics at monthly granularity |
| EOY / YTD flag | Performance | Distinguish completed years from current |

---

### 3.7 Bank Account Management (replaces FinecoMY, RevolutIT, estatement)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Fineco Transactions | FinecoMY + raw imports | Merged transactions with MoneyMap category |
| Revolut Transactions | RevolutIT | ~7,875 rows, multi-currency |
| KBC Transactions | estatement | Legacy Irish bank, ~2,430 rows |
| CSV Import | Raw Fineco/Revolut sheets | Parse bank CSV exports |
| Transaction Merge | FinecoMY = merge of raw sheets | Deduplicate across import periods |
| Settlement Lag | FinecoMY: Delta Operazione-Valuta | Days between operation and value date |
| Auto-Categorization | FinecoMY: Moneymap | Regex rules on description |
| Multi-Currency | RevolutIT | EUR, USD, CHF, GBP with FX conversion |

---

### 3.8 Buffer Accounts (replaces Buffer Accounts sheet)

Earmarked reserves for planned expenses. Used to smooth large capital expenditures.

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Buffer Categories | Buffer: Pre Busta, Fondo Pensione, AUTO, Donazione, Sell Stock, DELTAPAC, Rimborso Dentista | Named reserves |
| Transaction Log | Buffer rows | Deposits, withdrawals, reimbursements per buffer |
| Running Balance | Buffer: Saldo | Balance per buffer |
| PAYROLL Flag | Buffer: PAYROLL | Auto-deducted from salary |
| FORCE_LAST Flag | Buffer: FORCE LAST | End-of-period adjustment |
| CAR AMM | Buffer: CAR AMM | Car amortization sub-ledger |
| RIMBORSO Flag | Buffer: RIMBORSO/SALDO | Reimbursement status |
| **Depreciation Link** | NEW | Buffer absorbs monthly depreciation charge from linked CAPEX item |

---

### 3.9 Securities Transactions (replaces Movimenti Dossier Titoli)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Trade Log | Movimenti Dossier Titoli X | Buy/sell/dividend events |
| ISIN Tracking | Movimenti: ISIN code | Security identification |
| Direction | Movimenti: Segno | Buy vs Sell |
| Price & Quantity | Movimenti columns | Per-trade details |
| Commission | Movimenti: Commissione | Trade costs |
| FX Rate | Movimenti: Cambio | Cross-currency conversion |
| CSV Import | Raw Fineco Dossier Titoli format | Parse securities CSV |
| Tax Lot (FIFO) | NEW | Italian capital gains calculation |

---

### 3.10 Health Insurance Reimbursements (replaces Entrate Registrate: Rimborsi section)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Claims List | Entrate Registrate: Rimborsi | Provider, invoice, date, amount |
| Beneficiary | Rimborsi: Assistito | Per family member |
| Coverage % | Rimborsi: % Rimborso | Reimbursement percentage |
| Processing Time | Rimborsi: DELTA days | Days from claim to reimbursement |
| Uncovered Amount | Rimborsi: Non Coperto | Out-of-pocket |

---

### 3.11 Calendar & Reference Data (replaces BaseData)

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| Italian Bank Holidays | BaseData: holidays since 2011 | Public holiday calendar |
| Company Holidays | BaseData: SLIP HOL | Work schedule |
| Working Day Logic | BaseData: Festivi+Ferie | Business day calculations |
| Monthly Periods | BaseData: ADD MESE, STEPGIORNI | Date stepping logic |

---

## 4. OPEX vs CAPEX Framework (NEW)

### Concept
Separate daily operating expenses (rent, groceries, subscriptions) from capital expenditures (car, appliances, renovations) to get a true picture of sustainable spending. The CAR AMM tracking in Buffer Accounts is a primitive version of this - the app generalizes it.

### How It Works

1. **Tag transactions as OPEX or CAPEX** (via category or manual flag)
2. **CAPEX items get a depreciation schedule**:
   - **Forward depreciation**: spread cost into the future (buy car today for 20,000 EUR, depreciate over 60 months = ~333/month going forward)
   - **Backward depreciation**: retroactively spread cost into the past (recalculate past months as if saving ~333/month instead of a spike)
3. **Two expense views**:
   - Raw: actual transaction amounts (traditional view)
   - Adjusted: OPEX + depreciation portion of CAPEX (smoothed view)
4. **Buffer integration**: a buffer can absorb the monthly depreciation charge (generalizes the existing CAR AMM pattern)

### Depreciation Methods
- **Linear** (default): equal monthly amounts over useful life
- **Declining balance**: higher depreciation in early periods
- **Custom**: user-defined schedule

### Example: Car Purchase
- Transaction: -20,000 EUR on 2024-01-15 (tagged CAPEX, type=AUTO)
- Depreciation: 60 months, linear, FORWARD
- Result: budgeting shows -333/month from Jan 2024 to Dec 2028 instead of -20,000 spike
- The "AUTO" buffer pre-accumulates or tracks the remaining depreciation

---

## 5. Exposure Analysis (NEW - from MoneyHistory TODO list)

The MoneyHistory.xlsx TODO list explicitly mentions "geography/currency exposure charts" as a planned feature. The app implements this:

| Exposure Type | Data Source | Visualization |
|--------------|-------------|---------------|
| Asset Class | HistoryInvest: GROUP column | Donut chart (STOCK ETF, BOND ETF, etc.) |
| Geographic Region | Asset metadata: region | Bar/donut (World, Europe, EM, US) |
| Currency | Asset metadata: currency | Bar/donut (EUR, USD, CHF) |
| Country (domicile) | Asset metadata: country | Map or bar |
| Sector | Asset metadata: sector | Bar/donut |
| Cost (TER) | Asset metadata: ter | Total annual cost as % of portfolio |

---

## 6. Settings & Configuration

| Feature | Excel Source | Description |
|---------|-------------|-------------|
| SMA Windows | Graph row 3455: 365, 365, 365 | RT, Expense, RAL window sizes |
| Volatility Window | Graph row 3455: 7 | Days for volatility calculation |
| Net P/L SMA Window | Graph row 3455: 1530 | Days since 2022-01-01 (dynamic) |
| Tax Rate | Graph row 3455: 0.26 | Italian capital gains 26% |
| SWR | Graph row 3455: 0.0275 | Safe Withdrawal Rate 2.75% |
| Base Currency | - | EUR |
| Depreciation Defaults | NEW | Default useful life by asset type, method |
| Market Data Config | NEW | API keys, refresh schedule |
| CSV Import Config | NEW | Parser settings per bank |
| Backup | NEW | Database backup/restore |

---

## 7. Generic File Importer

Import the same raw source files that MoneyHistory.xlsx used. No XLSX migration — everything computed fresh.

### Import Flow
1. Upload any tabular file (CSV, XLSX, XLS)
2. Preview all columns and first N rows
3. Pick target: "Account Transaction" or "Asset Event"
4. Map columns: user selects which column is `date`, `amount`, `description`, etc.
5. Select target Account or Asset
6. Preview mapped rows
7. Confirm import — unmapped columns stored as `raw_metadata` JSON

### Deduplication
Each row is hashed (SHA-256) on import. If the same file is imported again, already-imported rows are automatically skipped. This allows safe re-imports without creating duplicates.

### Post-Import Manual Adjustments
All imported records are fully editable (including dates) for aligning movements across assets. Users can split, delete, reclassify, and re-date any row after import.

### Source Files (same ones MoneyHistory.xlsx used)
- Fineco bank exports (XLSX)
- Revolut exports (CSV)
- KBC estatement (CSV)
- Fineco Dossier Titoli / securities (XLSX)
- Any other tabular file

---

## 8. Implementation Phases (High Level)

### Phase 1 - Foundation (MVP)
Generic file importer, accounts, transactions, unified asset model, daily snapshot computation, main dashboard.

### Phase 2 - Analytics
Income/expense tracking (macro + micro), performance tables, velocity metrics, daily time series, volatility analysis.

### Phase 3 - Investment Management
Market data feeds, unified asset tracker, portfolio management, securities transactions, pension tracking, exposure charts.

### Phase 4 - Planning & Advanced
Buffer accounts with depreciation link, OPEX/CAPEX framework, simulators (future capital, pension, capital income), DCA plans, rebalancing, reimbursement tracker.

### Phase 5 - Automation & Polish
Scheduled jobs (daily snapshot, market prices, FX rates), auto-categorization, notifications, export, backup, responsive polish.
