/// Authoritative, developer-maintained reference of the EXACT formulas the app
/// uses to compute its metrics. Fed to the AI assistant so it answers using the
/// app's real definitions (then applies them to data it fetches via
/// query_database) instead of re-deriving the math from raw SQL.
///
/// KEEP IN SYNC with the source of truth:
///   - lib/services/pillars/financial_health_service.dart (KPIs, FIRE, HHI)
///   - lib/utils/asset_value_math.dart (asset base value, after-tax net)
///   - lib/ui/screens/dashboard/models.dart (cash-flow buckets)
///   - lib/ui/screens/dashboard/data_providers.dart (income/expense/NAV)
const String financeFormulas = r'''
CONVENTIONS
- All money is converted to the user's base currency at the FX rate for the
  row's value_date. If a rate is missing, the row is EXCLUDED (never assume 1:1).
- Date/time columns are INTEGER Unix epoch SECONDS. value_date is authoritative
  for ordering and aggregation; operation_date is only for import dedup.
- Amount sign: positive = money IN (income/inflow), negative = money OUT
  (expense/outflow).

ASSET VALUE
- Position base-currency value = quantity * price / bondDivisor * fxRate, where
  bondDivisor = 100 for bonds (price quoted as % of face value) else 1.
- Gain = market_value - invested.
- After-tax "Net Value": if gain <= 0 -> market; else invested + gain*(1 - taxRate).
  taxRate is a fraction clamped to [0,1]; default 0.26 (per-asset override possible).

NET WORTH / WEALTH (point in time)
- cash = sum of account balances (base currency).
- investments = sum of asset market values (base currency).
- grossAssets = cash + investments.
- netWorth = grossAssets.
- liquidAssets = cash + liquid investments (EXCLUDES pension, real-estate,
  alternative, and liability asset types).

CASH FLOW (per month or year)
- income = sum of `incomes` rows EXCLUDING type IN ('refund','pensionContribution'),
  in base currency. Refunds and pension contributions are NOT personal income.
- pensionContrib = sum of `incomes` rows with type = 'pensionContribution' (base ccy).
- navChange = NAV(end) - NAV(start), where NAV (the "Saving" total) = account
  balances + invested + outflow adjustments + non-ephemeral inflow adjustments,
  carried forward over time.
- personalNavChange = navChange - pensionContrib.
- savings = personalNavChange.
- expenses = income - personalNavChange.
- savingsRate = income > 0 ? personalNavChange / income : 0.
- Note: refunds DO land in the bank, so they count toward savings via NAV; only
  their income classification is excluded. Pension contributions are excluded
  from BOTH income and savings (they never hit the user's bank account).

LIQUIDITY KPIs
- Liquidity ratio (%) = cash / netWorth * 100.
- Expense coverage (months) = cash / monthlyExpenses.
- Savings rate (%) = annualSavings / annualIncome * 100.

WEALTH KPIs
- Investment weight (%) = investments / grossAssets * 100.
- Liquid-asset ratio (%) = liquidAssets / grossAssets * 100.
- Income-to-wealth (%) = trailing-12-month income / netWorth * 100.

FIRE (financial independence)
- FI number = annualExpenses / (SWR% / 100). Default SWR% = 2.75.
- Progress (%) = max(0, netWorth / FI number * 100).

DIVERSIFICATION
- HHI = sum over holdings of (value_i / totalValue)^2 * 10000  (0..10000;
  lower = more diversified).
- Portfolio price change (%) = (totalNow - totalPrev) / totalPrev * 100.
''';
