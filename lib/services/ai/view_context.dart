/// Static, developer-authored description of what each top-level view displays.
///
/// The app's screens are static, so we always know what the user is looking at
/// from the active view name — no "vision" required. This text is fed to the
/// assistant so it can interpret references like "these charts", "this screen",
/// or "what I'm looking at" and answer by querying the underlying data.
String aiViewContext(String view) {
  switch (view) {
    case 'Dashboard':
      return 'The Dashboard shows time-series charts and KPIs derived from the data: '
          'net worth over time (sum of account balances plus asset market values), '
          'invested capital vs. current market value of investments, monthly/yearly '
          'cash flow (income vs. expenses and savings rate), portfolio allocation '
          'breakdowns, and financial-health indicators (e.g. FIRE progress, savings '
          'rate, diversification/concentration).';
    case 'Accounts':
      return 'The Accounts screen lists the accounts (bank / broker / crypto) with their '
          'current balances, and per-account transaction ledgers (income and expense '
          'movements) plus adjustments.';
    case 'Assets':
      return 'The Assets screen lists investment holdings (ETFs, stocks, funds, etc.) with '
          'amount invested, current market value, gain/loss, and allocation breakdowns by '
          'asset class, sector, and geography.';
    case 'Pillars':
      return 'The Pillars screen shows the portfolio "pillars" (goal buckets) with their '
          'target values, current value vs. target, and allocation against the chosen '
          'portfolio model (for rebalancing).';
    default:
      return '';
  }
}
