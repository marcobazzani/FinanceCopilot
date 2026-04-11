# MoneyHistory.xlsx - Feature Map

A comprehensive personal finance Excel workbook tracking net worth, investments, income/expenses, and performance across multiple accounts and asset classes since 2017.

---

## 1. TODO Tracker
- Internal task list for spreadsheet improvements
- Status tracking (DONE / pending)
- Planned features: multi-file Fineco import, Stock Plan consolidation, Amazon History merge, tax implementation per asset, geography/currency exposure charts

---

## 2. Graph (Main Dashboard - Daily Time Series)
Daily tracking from 2017 to present (~3,600 rows) with the following metrics:

### Account Balances
- **Fineco** (primary bank)
- **Revolut**
- **KBC** (legacy Irish bank)
- **Buffer Accounts** (earmarked reserves)

### Net Worth Aggregation
- **Portafoglio** (investment portfolio value)
- **Investito** (total amount invested / cost basis)
- **Liquidi** (liquid cash)
- **Liquidabile + Liquidi** (liquidatable + cash)
- **Risparmio Totale (RT)** (total savings)
- **Asset Totale (AT)** (total assets)
- **RT - SMA** (savings with simple moving average)
- **RT/AT ratio** (savings to total asset ratio)

### Performance Metrics
- **Net P/L** (net profit/loss with SMA smoothing)
- **P/L in EUR** (absolute profit/loss)
- **P/L AT %** / **P/L PTF %** (percentage P/L on total assets and portfolio)
- **P/L AT to 0** (break-even tracking)
- **P/L Periodo** (period P/L in EUR and % for AT, PTF, and RT)
- **Log** returns
- **Vol Annuale** (annualized volatility)
- **Delta SMA/RT**

### Income & Expense Tracking
- **Entrate** (income)
- **Uscite** (expenses)
- **Uscite cumulate** (cumulative expenses)
- **SMA Spese** (expense moving average)
- **E/U over RAL** (income/expense ratio over gross salary)
- **Daily RAL** (daily gross salary accrual)

### Registered Transactions
- **Rimborsi Registrati** (registered reimbursements)
- **Entrate Registrate** (registered income entries)
- **Guadagni Registrati** (registered gains)
- **Vendite Registrate** (registered sales)
- **Extra Cassa** (extra cash events)

### Speed/Velocity Metrics
- **Velocità di spesa** (spending velocity)
- **Velocità di risparmio** (savings velocity)
- **Velocità di profitto Net P/L** (profit velocity)

### External Data Integration
- **AMZN INVEST** / **AMZN** (Amazon stock tracking)
- **Plannix-Invested** (Plannix-tracked invested amount)
- **TRACKED PTF** (Plannix-tracked portfolio)
- **PPP** (pension fund value)
- **Diff HTH** (head-to-head difference)

---

## 3. HistoryInvest (Investment Holdings Detail)
~1,980 rows tracking individual investment positions:

### Portfolio Composition
- Asset groups: CASH, STOCK, BOND ETF, STOCK ETF, COMM ETF, GOLD ETC, MON ETF
- Individual tickers: AMZN, Amundi EUR Gov Bond 1-3Y, iShares $ Treasury Bond 1-3Y, iShares Core MSCI World, Amundi STOXX Europe 600, iShares Core MSCI EM IMI, UBS CMCI Composite, WisdomTree Physical Gold, Xtrackers EUR Overnight Rate Swap
- **Percent** allocation per asset
- **Total** value per asset
- Tax flag tracking
- Invested amounts and time intervals
- Date ranges (DA/A) for position tracking

---

## 4. FinecoMY (Fineco Bank Transactions - Merged)
~1,150 rows of Fineco bank transactions:
- Operation date / Value date
- Income (Entrate) / Expenses (Uscite)
- Transaction description and full description
- Status (Autorizzato / Contabilizzato)
- **Moneymap** categorization (Casa, Altre spese, Rimborsi, etc.)
- **e/u** flag (income/expense)
- Running balance (Saldo)
- **Delta Operazione - Valuta** (settlement lag in days)

---

## 5. Fineco_2025_202X / Fineco_2022_2024 (Raw Fineco Imports)
- Split raw bank statement imports by period
- Same structure as FinecoMY (source data for merge)
- ~250 rows (2025+) and ~883 rows (2022-2024)

---

## 6. RevolutIT (Revolut Transactions)
~7,875 rows of Revolut transactions:
- Transaction type (Tipo) and product (Prodotto)
- Start/completion dates
- Description, amount, fees
- Currency and state
- Running balance (Saldo)

---

## 7. estatement (KBC Bank Statements - Legacy)
~2,430 rows of KBC Ireland bank transactions:
- Date, description, amounts
- Running balance tracking
- Income/expense classification

---

## 8. Buffer Accounts (Earmarked Reserves)
~193 rows tracking money set aside for specific purposes:
- Categories: Pre Busta (pre-payroll), Fondo Pensione, AUTO, Donazione, Sell Stock, DELTAPAC, Rimborso Dentista deferred
- Operation/value dates
- Amounts and currency
- Running balance per buffer
- FORCE LAST / PAYROLL flags
- CAR AMM (car amortization) tracking
- RIMBORSO / SALDO status flags

---

## 9. Movimenti Dossier Titoli / X (Securities Transactions)
~214 + ~211 rows tracking securities operations:
- Operation type, value date, description
- Security title and ISIN code
- Buy/Sell direction (Segno)
- Quantity, currency, price, exchange rate
- Countervalue and commission
- "X" version is the cleaned/consolidated version

---

## 10. PPP_FULL (Pension Fund - Fondo Pensione)
~120 rows tracking pension fund contributions:
- Monthly contributions by source: **C/TFR** (severance fund) and **C/Azienda** (employer)
- Cumulative totals per period (TOTALE_PERIODO)
- **TFR** running total
- **Azienda** (employer contribution) running total
- **Versato** (total paid in)
- **Valore** (current value)
- **DELTA CMP** (delta vs cost)
- **TFR/Azienda ratio**
- **Gain PTF** / **Gain Asset** / **Annualized** return

---

## 11. Entrate Registrate (Registered Income & Reimbursements)
~399 rows with multiple sub-sections:

### Income Tracking
- Monthly income by date (since 2013)
- Categories: STIPENDI (salaries), ENTRATE (income), INCASSI (collections), VENDITA (sales), DONAZIONE (donations), RIMBORSO (reimbursements)
- MIO flag (personal income flag)
- Pivot table summaries

### Health Insurance Reimbursements (Rimborsi)
- Provider/clinic name
- Invoice number and date
- Claim amount (Valore Sinistro)
- Beneficiary (Assistito)
- Reimbursed amount
- Document dates and reimbursement dates
- Paid amount, type (RIMBORSO), coverage flag
- **Non Coperto** (uncovered amount)
- **% Rimborso** (reimbursement percentage)
- Processing time (DELTA days)

### Bitcoin Tracking
- BTC quantity and EUR/USD exchange rate
- Current value calculations

---

## 12. Andamento Entrate Uscite (Income/Expense Trends)
~62 rows - likely chart data for income/expense trend visualization (mostly graph-backing data)

---

## 13. Amazon History (Amazon Stock Tracking)
~5,006 rows of daily Amazon stock price history:
- Daily closing price (USD and EUR)
- Shares held count
- **Total Value** in USD and EUR
- **Invest** (cost basis)
- **Gain** (unrealized gain)
- **Tax** calculation
- **Net** (after-tax value)
- **GAIN %** (percentage gain)
- **Var EUR** / **Var USD** (daily variation)
- **EUR/USD** exchange rate tracking
- Reverse compound calculations

---

## 14. Performance (Annual Performance Summary)
~140 rows with yearly performance metrics:
- **P/L AT %** (annual P/L on total assets)
- **EOY P/L EUR** (end-of-year P/L in euros)
- **P/L PTF %** (annual P/L on portfolio)
- **Diff P/L EUR** (year-over-year difference)
- **Absolute** return
- **EOY or YTD** flag
- **Reverse Compound** from 2018 baseline
- Yearly data from 2017 to 2025

---

## 15. BaseData (Reference/Calendar Data)
~137 rows of supporting reference data:
- Italian bank holidays and public holidays (since 2011)
- Company holiday schedule (SLIP HOL)
- Monthly period calculations
- Working day computations
- Date stepping logic (ADD MESE, GIORNO, STEPGIORNI)
- Festivi + Ferie (holidays + vacation) vs Solo Festivi (holidays only)

---

## 16. Stock Plan (Amazon RSU/Stock Vesting)
~34 rows tracking Amazon RSU (Restricted Stock Unit) vesting:
- Vest dates (from Feb 2018 onward)
- **Dollar Vest** date
- **Total ps** (total shares per vest)
- **Kept ps** / **Kept** (shares retained after tax sell)
- **Value at vest** (USD and EUR)
- **EUR/USD** exchange rate at vest
- **Total Value single vest** (EUR value per vest event)
- **Totale per graf** (cumulative for charting)
- **Current Value** (mark-to-market)
- **Capital Gain** calculation
- **Tax to pay** (26% Italian capital gains tax)
- **Net Gain After Tax** (EUR and %)
- **Net Value After Tax**

---

## Cross-Sheet Relationships
- **Graph** pulls daily values from all account sheets (Fineco, Revolut, Buffer, Portfolio)
- **HistoryInvest** feeds portfolio values into **Graph**
- **FinecoMY** merges **Fineco_2025_202X** and **Fineco_2022_2024**
- **Amazon History** feeds AMZN values into **Graph**
- **PPP_FULL** feeds pension values into **Graph**
- **Stock Plan** tracks Amazon RSU separately, feeding into total asset calculations
- **BaseData** provides calendar/holiday logic for working day calculations
- **Performance** summarizes annual returns from **Graph** data
- **Entrate Registrate** feeds income/reimbursement data into **Graph**
- **Buffer Accounts** tracks earmarked reserves shown in **Graph**
