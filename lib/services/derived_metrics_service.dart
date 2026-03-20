import 'dart:math';

import '../database/database.dart';

/// Raw time-series data extracted from the dashboard provider,
/// used as input for derived metrics computation.
class RawTimeSeriesData {
  final DateTime firstDate;
  final List<int> sortedDayKeys;
  final String baseCurrency;

  /// accountId → {dayKey → balance_in_base_currency}
  final Map<int, Map<int, double>> accountBalances;

  /// assetId → {dayKey → cumulative_invested_in_base}
  final Map<int, Map<int, double>> assetInvested;

  /// assetId → {dayKey → market_value_in_base}
  final Map<int, Map<int, double>> assetMarketValue;

  /// scheduleId → {dayKey → cumulative_adjustment}
  final Map<int, Map<int, double>> adjustments;

  /// adjId → {dayKey → cumulative_income_adjustment}
  final Map<int, Map<int, double>> incomeAdjustments;

  const RawTimeSeriesData({
    required this.firstDate,
    required this.sortedDayKeys,
    required this.baseCurrency,
    required this.accountBalances,
    required this.assetInvested,
    required this.assetMarketValue,
    required this.adjustments,
    required this.incomeAdjustments,
  });

  /// Sum of all account balances at a given dayKey (carry-forward).
  double totalAccountBalance(int dayKey) {
    var total = 0.0;
    for (final balances in accountBalances.values) {
      // Find latest value <= dayKey
      double? last;
      for (final dk in sortedDayKeys) {
        if (dk > dayKey) break;
        if (balances.containsKey(dk)) last = balances[dk]!;
      }
      if (last != null) total += last;
    }
    return total;
  }

  /// Sum of all asset invested values at a given dayKey (carry-forward).
  double totalAssetInvested(int dayKey) {
    var total = 0.0;
    for (final invested in assetInvested.values) {
      double? last;
      for (final dk in sortedDayKeys) {
        if (dk > dayKey) break;
        if (invested.containsKey(dk)) last = invested[dk]!;
      }
      if (last != null) total += last;
    }
    return total;
  }

  /// Sum of all asset market values at a given dayKey (carry-forward).
  double totalAssetMarketValue(int dayKey) {
    var total = 0.0;
    for (final market in assetMarketValue.values) {
      double? last;
      for (final dk in sortedDayKeys) {
        if (dk > dayKey) break;
        if (market.containsKey(dk)) last = market[dk]!;
      }
      if (last != null) total += last;
    }
    return total;
  }

  /// Sum of all adjustments at a given dayKey (carry-forward).
  double totalAdjustments(int dayKey) {
    var total = 0.0;
    for (final adj in adjustments.values) {
      double? last;
      for (final dk in sortedDayKeys) {
        if (dk > dayKey) break;
        if (adj.containsKey(dk)) last = adj[dk]!;
      }
      if (last != null) total += last;
    }
    return total;
  }

  /// Sum of all income adjustments at a given dayKey (carry-forward).
  double totalIncomeAdjustments(int dayKey) {
    var total = 0.0;
    for (final adj in incomeAdjustments.values) {
      double? last;
      for (final dk in sortedDayKeys) {
        if (dk > dayKey) break;
        if (adj.containsKey(dk)) last = adj[dk]!;
      }
      if (last != null) total += last;
    }
    return total;
  }
}

/// Holds all computed derived metrics as day-keyed maps.
class DerivedMetrics {
  // ── Tier 1: P/L ──
  final Map<int, double> grossPL;
  final Map<int, double> netPL;
  final Map<int, double> plATPercent;
  final Map<int, double> plPTFPercent;
  final Map<int, double> plATToZero;

  // ── Tier 2: Savings ──
  final Map<int, double> risparTotale;
  final Map<int, double> rtSMA;
  final Map<int, double> deltaSmaRT;
  final Map<int, double> liquidabile;

  // ── Tier 3: Velocity ──
  final Map<int, double> netPLSMA;
  final Map<int, double> cumulativeExpenses;
  final Map<int, double> smaExpenses;
  final Map<int, double> velocitaSpesa;
  final Map<int, double> velocitaRisparmio;
  final Map<int, double> velocitaProfitto;
  final Map<int, double> dailyRAL;

  // ── Tier 4: Risk ──
  final Map<int, double> logReturns;
  final Map<int, double> volatility;
  final Map<int, double> drawdownFromATH;

  // ── Tier 5: Period returns ──
  final Map<int, double> dailyPLAbsAT;
  final Map<int, double> dailyPLPctAT;
  final Map<int, double> dailyPLAbsPTF;
  final Map<int, double> dailyPLPctPTF;
  final Map<int, double> dailyPLAbsRT;
  final Map<int, double> dailyPLPctRT;
  final Map<int, double> euOverRAL;
  final Map<int, double> entrate;
  final Map<int, double> uscite;

  // ── Tier 6: Summary ──
  final Map<String, double> ytdDeltas;
  final Map<String, double> athValues;
  final Map<String, double> drawdowns;

  const DerivedMetrics({
    this.grossPL = const {},
    this.netPL = const {},
    this.plATPercent = const {},
    this.plPTFPercent = const {},
    this.plATToZero = const {},
    this.risparTotale = const {},
    this.rtSMA = const {},
    this.deltaSmaRT = const {},
    this.liquidabile = const {},
    this.netPLSMA = const {},
    this.cumulativeExpenses = const {},
    this.smaExpenses = const {},
    this.velocitaSpesa = const {},
    this.velocitaRisparmio = const {},
    this.velocitaProfitto = const {},
    this.dailyRAL = const {},
    this.logReturns = const {},
    this.volatility = const {},
    this.drawdownFromATH = const {},
    this.dailyPLAbsAT = const {},
    this.dailyPLPctAT = const {},
    this.dailyPLAbsPTF = const {},
    this.dailyPLPctPTF = const {},
    this.dailyPLAbsRT = const {},
    this.dailyPLPctRT = const {},
    this.euOverRAL = const {},
    this.entrate = const {},
    this.uscite = const {},
    this.ytdDeltas = const {},
    this.athValues = const {},
    this.drawdowns = const {},
  });

  /// All named series for chart integration.
  Map<String, Map<int, double>> get allSeries => {
    'Gross P/L': grossPL,
    'Net P/L': netPL,
    'P/L AT%': plATPercent,
    'P/L PTF%': plPTFPercent,
    'P/L AT→0%': plATToZero,
    'Risparmio Totale': risparTotale,
    'RT SMA': rtSMA,
    'Delta SMA-RT': deltaSmaRT,
    'Liquidabile': liquidabile,
    'Net P/L SMA': netPLSMA,
    'Cum. Expenses': cumulativeExpenses,
    'SMA Expenses': smaExpenses,
    'Vel. Spesa': velocitaSpesa,
    'Vel. Risparmio': velocitaRisparmio,
    'Vel. Profitto': velocitaProfitto,
    'Daily RAL': dailyRAL,
    'Log Returns': logReturns,
    'Volatility': volatility,
    'Drawdown ATH': drawdownFromATH,
    'Daily P/L Abs AT': dailyPLAbsAT,
    'Daily P/L % AT': dailyPLPctAT,
    'Daily P/L Abs PTF': dailyPLAbsPTF,
    'Daily P/L % PTF': dailyPLPctPTF,
    'Daily P/L Abs RT': dailyPLAbsRT,
    'Daily P/L % RT': dailyPLPctRT,
    'EU/RAL': euOverRAL,
    'Entrate': entrate,
    'Uscite': uscite,
  };

  /// Group names for chart editor UI.
  static const seriesGroups = {
    'P/L': ['Gross P/L', 'Net P/L', 'P/L AT%', 'P/L PTF%', 'P/L AT→0%'],
    'Savings': ['Risparmio Totale', 'RT SMA', 'Delta SMA-RT', 'Liquidabile'],
    'Velocity': ['Net P/L SMA', 'Cum. Expenses', 'SMA Expenses', 'Vel. Spesa', 'Vel. Risparmio', 'Vel. Profitto', 'Daily RAL'],
    'Risk': ['Log Returns', 'Volatility', 'Drawdown ATH'],
    'Period Returns': ['Daily P/L Abs AT', 'Daily P/L % AT', 'Daily P/L Abs PTF', 'Daily P/L % PTF', 'Daily P/L Abs RT', 'Daily P/L % RT', 'EU/RAL', 'Entrate', 'Uscite'],
  };
}

/// Yearly income vs expenses analysis data.
class YearlyStats {
  final int year;
  final int trackedDays;
  final double income;
  final double expenses;
  final double netSavings;
  final double savingsRate;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double annualizedIncome;
  final double annualizedExpenses;
  final double dailyIncome;
  final double dailyExpenses;
  final double dailySavings;
  final double yoyExpenseChange;
  final double yoyExpenseChangePct;
  final double yoyIncomeChangePct;
  final Map<int, double> monthlyIncomeBreakdown;
  final Map<int, double> monthlyExpenseBreakdown;

  const YearlyStats({
    required this.year,
    required this.trackedDays,
    required this.income,
    required this.expenses,
    required this.netSavings,
    required this.savingsRate,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.annualizedIncome,
    required this.annualizedExpenses,
    required this.dailyIncome,
    required this.dailyExpenses,
    required this.dailySavings,
    this.yoyExpenseChange = 0,
    this.yoyExpenseChangePct = 0,
    this.yoyIncomeChangePct = 0,
    this.monthlyIncomeBreakdown = const {},
    this.monthlyExpenseBreakdown = const {},
  });
}

// ════════════════════════════════════════════════════
// Pure computation utilities
// ════════════════════════════════════════════════════

/// Simple Moving Average over a window of [windowDays] calendar days.
Map<int, double> rollingAverage(
  Map<int, double> series,
  List<int> sortedDays,
  int windowDays,
) {
  final result = <int, double>{};
  for (var i = 0; i < sortedDays.length; i++) {
    final dk = sortedDays[i];
    if (!series.containsKey(dk)) continue;
    final cutoff = dk - windowDays * 86400; // dayKey is epoch seconds
    var sum = 0.0;
    var count = 0;
    for (var j = i; j >= 0; j--) {
      final prev = sortedDays[j];
      if (prev < cutoff) break;
      if (series.containsKey(prev)) {
        sum += series[prev]!;
        count++;
      }
    }
    if (count > 0) result[dk] = sum / count;
  }
  return result;
}

/// Rolling standard deviation over a window of [windowDays] calendar days.
Map<int, double> rollingStdev(
  Map<int, double> series,
  List<int> sortedDays,
  int windowDays,
) {
  final result = <int, double>{};
  for (var i = 0; i < sortedDays.length; i++) {
    final dk = sortedDays[i];
    if (!series.containsKey(dk)) continue;
    final cutoff = dk - windowDays * 86400;
    final values = <double>[];
    for (var j = i; j >= 0; j--) {
      final prev = sortedDays[j];
      if (prev < cutoff) break;
      if (series.containsKey(prev)) values.add(series[prev]!);
    }
    if (values.length >= 2) {
      result[dk] = sampleStdev(values);
    }
  }
  return result;
}

/// Sample standard deviation.
double sampleStdev(List<double> values) {
  if (values.length < 2) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final sumSq = values.fold(0.0, (s, v) => s + (v - mean) * (v - mean));
  return sqrt(sumSq / (values.length - 1));
}

/// First derivative: change per 30.4167 days (monthly velocity).
Map<int, double> velocity(
  Map<int, double> series,
  List<int> sortedDays,
) {
  final result = <int, double>{};
  int? prevDk;
  double? prevVal;
  for (final dk in sortedDays) {
    if (!series.containsKey(dk)) continue;
    final val = series[dk]!;
    if (prevDk != null && prevVal != null) {
      final daysDiff = (dk - prevDk!) / 86400;
      if (daysDiff > 0) {
        result[dk] = (val - prevVal!) / daysDiff * 30.4167;
      }
    }
    prevDk = dk;
    prevVal = val;
  }
  return result;
}

/// Service that computes all derived metrics from raw data.
class DerivedMetricsService {
  DerivedMetrics compute({
    required RawTimeSeriesData raw,
    required List<RegisteredEvent> registeredEvents,
    required Map<String, String> configs,
  }) {
    final sortedDays = raw.sortedDayKeys;
    if (sortedDays.isEmpty) return const DerivedMetrics();

    // Parse config values with defaults
    final taxRate = double.tryParse(configs['TAX_RATE'] ?? '') ?? 0.26;
    final rtSmaWindow = int.tryParse(configs['RT_SMA_WINDOW'] ?? '') ?? 90;
    final netPlSmaWindow = int.tryParse(configs['NET_PL_SMA_WINDOW'] ?? '') ?? 90;
    final expenseSmaWindow = int.tryParse(configs['EXPENSE_SMA_WINDOW'] ?? '') ?? 90;
    final ralWindow = int.tryParse(configs['RAL_WINDOW'] ?? '') ?? 365;
    final volWindow = int.tryParse(configs['VOL_WINDOW'] ?? '') ?? 252;

    // Pre-sort registered events by date
    final sortedEvents = List<RegisteredEvent>.from(registeredEvents)
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Build cumulative sums from registered events ──
    final cumGains = <int, double>{};
    final cumExtraCash = <int, double>{};
    final cumSales = <int, double>{};
    final cumIncome = <int, double>{}; // stipendio + entrata + incasso
    var runGains = 0.0;
    var runExtraCash = 0.0;
    var runSales = 0.0;
    var runIncome = 0.0;

    for (final ev in sortedEvents) {
      final dk = _toDayKey(ev.date);
      final type = ev.type.name;
      if (type == 'vendita' || type == 'incasso') {
        runGains += ev.amount;
        cumGains[dk] = runGains;
      }
      if (type == 'donazione' || type == 'entrata') {
        runExtraCash += ev.amount;
        cumExtraCash[dk] = runExtraCash;
      }
      if (type == 'vendita') {
        runSales += ev.amount;
        cumSales[dk] = runSales;
      }
      if (type == 'stipendio' || type == 'entrata' || type == 'incasso') {
        runIncome += ev.amount;
        cumIncome[dk] = runIncome;
      }
    }

    // ── Pre-compute carry-forward totals for each day ──
    final totalCash = <int, double>{};
    final totalInvested = <int, double>{};
    final totalMarket = <int, double>{};
    final totalAdj = <int, double>{};
    final totalIncAdj = <int, double>{};

    double runCash = 0, runInv = 0, runMkt = 0, runAdj = 0, runIncAdj = 0;
    // Account balances: carry-forward per account
    final acctLast = <int, double>{};
    final invLast = <int, double>{};
    final mktLast = <int, double>{};
    final adjLast = <int, double>{};
    final incAdjLast = <int, double>{};

    for (final dk in sortedDays) {
      // Update carry-forward values
      for (final entry in raw.accountBalances.entries) {
        if (entry.value.containsKey(dk)) acctLast[entry.key] = entry.value[dk]!;
      }
      for (final entry in raw.assetInvested.entries) {
        if (entry.value.containsKey(dk)) invLast[entry.key] = entry.value[dk]!;
      }
      for (final entry in raw.assetMarketValue.entries) {
        if (entry.value.containsKey(dk)) mktLast[entry.key] = entry.value[dk]!;
      }
      for (final entry in raw.adjustments.entries) {
        if (entry.value.containsKey(dk)) adjLast[entry.key] = entry.value[dk]!;
      }
      for (final entry in raw.incomeAdjustments.entries) {
        if (entry.value.containsKey(dk)) incAdjLast[entry.key] = entry.value[dk]!;
      }

      totalCash[dk] = acctLast.values.fold(0.0, (s, v) => s + v);
      totalInvested[dk] = invLast.values.fold(0.0, (s, v) => s + v);
      totalMarket[dk] = mktLast.values.fold(0.0, (s, v) => s + v);
      totalAdj[dk] = adjLast.values.fold(0.0, (s, v) => s + v);
      totalIncAdj[dk] = incAdjLast.values.fold(0.0, (s, v) => s + v);
    }

    // Helper to get carry-forward cumulative value
    double _cumAt(Map<int, double> cumMap, int dayKey) {
      double last = 0;
      for (final dk in sortedDays) {
        if (dk > dayKey) break;
        if (cumMap.containsKey(dk)) last = cumMap[dk]!;
      }
      return last;
    }

    // ════════════════════════════════════════════════════
    // Tier 1: P/L
    // ════════════════════════════════════════════════════
    final grossPL = <int, double>{};
    final netPL = <int, double>{};
    final plATPercent = <int, double>{};
    final plPTFPercent = <int, double>{};
    final plATToZero = <int, double>{};

    for (final dk in sortedDays) {
      final invested = totalInvested[dk] ?? 0;
      final market = totalMarket[dk] ?? 0;
      final cash = totalCash[dk] ?? 0;
      final adj = totalAdj[dk] ?? 0;
      final incAdj = totalIncAdj[dk] ?? 0;

      // Gross P/L = market - invested
      final gpl = market - invested;
      grossPL[dk] = gpl;

      // Net P/L = min(PL * (1 - taxRate), PL) — tax only on gains
      netPL[dk] = gpl > 0 ? gpl * (1 - taxRate) : gpl;

      // Asset Totale = cash + market + adj + incAdj
      final at = cash + market + adj + incAdj;
      // PPP (Patrimonio Potere Proprio) — needs cumGains and cumExtraCash
      final gains = _cumAt(cumGains, dk);
      final extraCash = _cumAt(cumExtraCash, dk);
      final ppp = invested + cash - gains - extraCash;
      // RT = Risparmio Totale
      final rt = invested + cash - gains - extraCash;

      // P/L AT% = (AT - PPP) / (RT + extraCash) - 1
      final rtPlusExtra = rt + extraCash;
      if (rtPlusExtra != 0 && at > 0) {
        plATPercent[dk] = (at - ppp) / rtPlusExtra - 1;
      }

      // P/L PTF% — portfolio level
      final sales = _cumAt(cumSales, dk);
      final totalInv = invested + sales;
      if (totalInv > 0) {
        plPTFPercent[dk] = (market + gains + sales) / totalInv - 1;
      }

      // P/L AT→0% = -plAT% / (1 + plAT%)
      final plat = plATPercent[dk];
      if (plat != null && (1 + plat) != 0) {
        plATToZero[dk] = -plat / (1 + plat);
      }
    }

    // ════════════════════════════════════════════════════
    // Tier 2: Savings
    // ════════════════════════════════════════════════════
    final risparTotale = <int, double>{};
    for (final dk in sortedDays) {
      final invested = totalInvested[dk] ?? 0;
      final cash = totalCash[dk] ?? 0;
      final gains = _cumAt(cumGains, dk);
      final extraCash = _cumAt(cumExtraCash, dk);
      risparTotale[dk] = invested + cash - gains - extraCash;
    }

    final rtSMAMap = rollingAverage(risparTotale, sortedDays, rtSmaWindow);

    final deltaSmaRT = <int, double>{};
    for (final dk in sortedDays) {
      if (risparTotale.containsKey(dk) && rtSMAMap.containsKey(dk)) {
        deltaSmaRT[dk] = risparTotale[dk]! - rtSMAMap[dk]!;
      }
    }

    // Liquidabile = cash + invested + netPL - tax haircut on PPP
    final liquidabile = <int, double>{};
    for (final dk in sortedDays) {
      final cash = totalCash[dk] ?? 0;
      final invested = totalInvested[dk] ?? 0;
      final npl = netPL[dk] ?? 0;
      final gains = _cumAt(cumGains, dk);
      final extraCash = _cumAt(cumExtraCash, dk);
      final ppp = invested + cash - gains - extraCash;
      // Tax haircut: if grossPL > 0, subtract the tax portion
      final gpl = grossPL[dk] ?? 0;
      final taxHaircut = gpl > 0 ? gpl * taxRate : 0.0;
      liquidabile[dk] = cash + invested + gpl - taxHaircut;
    }

    // ════════════════════════════════════════════════════
    // Tier 3: Velocity
    // ════════════════════════════════════════════════════
    final netPLSMAMap = rollingAverage(netPL, sortedDays, netPlSmaWindow);

    // Cumulative expenses: running sum of negative daily savings changes
    final cumExpenses = <int, double>{};
    double runExp = 0;
    int? prevDk;
    for (final dk in sortedDays) {
      if (prevDk != null && risparTotale.containsKey(dk) && risparTotale.containsKey(prevDk)) {
        final delta = risparTotale[dk]! - risparTotale[prevDk]!;
        if (delta < 0) runExp += delta.abs();
      }
      cumExpenses[dk] = runExp;
      prevDk = dk;
    }

    final smaExpensesMap = rollingAverage(cumExpenses, sortedDays, expenseSmaWindow);
    final velSpesa = velocity(smaExpensesMap, sortedDays);
    final velRisp = velocity(rtSMAMap, sortedDays);
    final velProf = velocity(netPLSMAMap, sortedDays);

    // Daily RAL: rolling income average over RAL_WINDOW
    // First build a daily income series from registered events
    final dailyIncomeSeries = <int, double>{};
    for (final ev in sortedEvents) {
      final t = ev.type.name;
      if (t == 'stipendio' || t == 'entrata' || t == 'incasso') {
        final dk = _toDayKey(ev.date);
        dailyIncomeSeries[dk] = (dailyIncomeSeries[dk] ?? 0) + ev.amount;
      }
    }
    // Annualize the rolling sum
    final dailyRALMap = <int, double>{};
    for (var i = 0; i < sortedDays.length; i++) {
      final dk = sortedDays[i];
      final cutoff = dk - ralWindow * 86400;
      var sum = 0.0;
      for (var j = i; j >= 0; j--) {
        final prev = sortedDays[j];
        if (prev < cutoff) break;
        if (dailyIncomeSeries.containsKey(prev)) sum += dailyIncomeSeries[prev]!;
      }
      final daysCovered = (dk - max(sortedDays.first, cutoff)) / 86400;
      if (daysCovered > 30) {
        dailyRALMap[dk] = sum / daysCovered * 365.25;
      }
    }

    // ════════════════════════════════════════════════════
    // Tier 4: Risk
    // ════════════════════════════════════════════════════
    // Asset Totale series for log returns
    final atSeries = <int, double>{};
    for (final dk in sortedDays) {
      final cash = totalCash[dk] ?? 0;
      final market = totalMarket[dk] ?? 0;
      final adj = totalAdj[dk] ?? 0;
      final incAdj = totalIncAdj[dk] ?? 0;
      atSeries[dk] = cash + market + adj + incAdj;
    }

    final logRet = <int, double>{};
    int? prevDk2;
    for (final dk in sortedDays) {
      if (prevDk2 != null && atSeries[dk]! > 0 && atSeries[prevDk2]! > 0) {
        logRet[dk] = log(atSeries[dk]! / atSeries[prevDk2]!);
      }
      prevDk2 = dk;
    }

    final vol = rollingStdev(logRet, sortedDays, volWindow);

    // Drawdown from ATH
    final drawdown = <int, double>{};
    double athPL = double.negativeInfinity;
    for (final dk in sortedDays) {
      final gpl = grossPL[dk] ?? 0;
      if (gpl > athPL) athPL = gpl;
      drawdown[dk] = athPL - gpl;
    }

    // ════════════════════════════════════════════════════
    // Tier 5: Period returns
    // ════════════════════════════════════════════════════
    final dplAbsAT = <int, double>{};
    final dplPctAT = <int, double>{};
    final dplAbsPTF = <int, double>{};
    final dplPctPTF = <int, double>{};
    final dplAbsRT = <int, double>{};
    final dplPctRT = <int, double>{};
    final euOverRALMap = <int, double>{};
    final entrateMap = <int, double>{};
    final usciteMap = <int, double>{};

    int? prev5;
    for (final dk in sortedDays) {
      if (prev5 != null) {
        // AT daily
        final atToday = atSeries[dk] ?? 0;
        final atPrev = atSeries[prev5] ?? 0;
        final atDelta = atToday - atPrev;
        dplAbsAT[dk] = atDelta;
        if (atPrev != 0) dplPctAT[dk] = atDelta / atPrev;

        // PTF daily — adjust for new capital
        final mktToday = totalMarket[dk] ?? 0;
        final mktPrev = totalMarket[prev5] ?? 0;
        final invToday = totalInvested[dk] ?? 0;
        final invPrev = totalInvested[prev5] ?? 0;
        final newCapital = invToday - invPrev;
        final ptfPL = mktToday - mktPrev - newCapital;
        dplAbsPTF[dk] = ptfPL;
        if (mktPrev != 0) dplPctPTF[dk] = ptfPL / mktPrev;

        // RT daily
        final rtToday = risparTotale[dk] ?? 0;
        final rtPrev = risparTotale[prev5] ?? 0;
        final rtDelta = rtToday - rtPrev;
        dplAbsRT[dk] = rtDelta;
        if (rtPrev != 0) dplPctRT[dk] = rtDelta / rtPrev;

        // EU/RAL
        final ral = dailyRALMap[dk];
        if (ral != null && ral > 0) {
          euOverRALMap[dk] = rtDelta / (ral / 365.25);
        }

        // Entrate/Uscite
        if (rtDelta > 0) {
          entrateMap[dk] = rtDelta;
        } else if (rtDelta < 0) {
          usciteMap[dk] = rtDelta;
        }
      }
      prev5 = dk;
    }

    // ════════════════════════════════════════════════════
    // Tier 6: Summary
    // ════════════════════════════════════════════════════
    final now = DateTime.now();
    final jan1Key = _toDayKey(DateTime(now.year, 1, 1));

    Map<String, double> computeYTD(Map<String, Map<int, double>> namedSeries) {
      final result = <String, double>{};
      for (final entry in namedSeries.entries) {
        if (entry.value.isEmpty) continue;
        final todayVal = entry.value[sortedDays.last] ?? 0;
        // Find closest value to Jan 1
        double jan1Val = 0;
        for (final dk in sortedDays) {
          if (dk >= jan1Key) {
            jan1Val = entry.value[dk] ?? jan1Val;
            break;
          }
          if (entry.value.containsKey(dk)) jan1Val = entry.value[dk]!;
        }
        result[entry.key] = todayVal - jan1Val;
      }
      return result;
    }

    Map<String, double> computeATH(Map<String, Map<int, double>> namedSeries) {
      final result = <String, double>{};
      for (final entry in namedSeries.entries) {
        if (entry.value.isEmpty) continue;
        result[entry.key] = entry.value.values.reduce(max);
      }
      return result;
    }

    Map<String, double> computeDrawdowns(Map<String, Map<int, double>> namedSeries) {
      final result = <String, double>{};
      for (final entry in namedSeries.entries) {
        if (entry.value.isEmpty) continue;
        final ath = entry.value.values.reduce(max);
        final current = entry.value[sortedDays.last] ?? 0;
        result[entry.key] = ath - current;
      }
      return result;
    }

    final summaryMetrics = {
      'Net Worth': atSeries,
      'Gross P/L': grossPL,
      'Net P/L': netPL,
      'Risparmio': risparTotale,
    };

    return DerivedMetrics(
      grossPL: grossPL,
      netPL: netPL,
      plATPercent: plATPercent,
      plPTFPercent: plPTFPercent,
      plATToZero: plATToZero,
      risparTotale: risparTotale,
      rtSMA: rtSMAMap,
      deltaSmaRT: deltaSmaRT,
      liquidabile: liquidabile,
      netPLSMA: netPLSMAMap,
      cumulativeExpenses: cumExpenses,
      smaExpenses: smaExpensesMap,
      velocitaSpesa: velSpesa,
      velocitaRisparmio: velRisp,
      velocitaProfitto: velProf,
      dailyRAL: dailyRALMap,
      logReturns: logRet,
      volatility: vol,
      drawdownFromATH: drawdown,
      dailyPLAbsAT: dplAbsAT,
      dailyPLPctAT: dplPctAT,
      dailyPLAbsPTF: dplAbsPTF,
      dailyPLPctPTF: dplPctPTF,
      dailyPLAbsRT: dplAbsRT,
      dailyPLPctRT: dplPctRT,
      euOverRAL: euOverRALMap,
      entrate: entrateMap,
      uscite: usciteMap,
      ytdDeltas: computeYTD(summaryMetrics),
      athValues: computeATH(summaryMetrics),
      drawdowns: computeDrawdowns(summaryMetrics),
    );
  }

  /// Compute yearly income vs expenses analysis.
  List<YearlyStats> computeYearlyStats({
    required RawTimeSeriesData raw,
    required Map<int, double> risparTotale,
    required List<RegisteredEvent> registeredEvents,
  }) {
    if (raw.sortedDayKeys.isEmpty) return [];

    final firstYear = DateTime.fromMillisecondsSinceEpoch(raw.sortedDayKeys.first * 1000).year;
    final lastYear = DateTime.now().year;

    final result = <YearlyStats>[];
    YearlyStats? prevYear;

    for (var year = firstYear; year <= lastYear; year++) {
      final jan1 = _toDayKey(DateTime(year, 1, 1));
      final dec31 = _toDayKey(DateTime(year, 12, 31));
      final isCurrentYear = year == lastYear;
      final endKey = isCurrentYear ? raw.sortedDayKeys.last : dec31;

      // Find RT at start and end of year
      double rtStart = 0, rtEnd = 0;
      for (final dk in raw.sortedDayKeys) {
        if (risparTotale.containsKey(dk)) {
          if (dk <= jan1) rtStart = risparTotale[dk]!;
          if (dk <= endKey) rtEnd = risparTotale[dk]!;
        }
      }

      // Sum income from registered events for the year
      double yearIncome = 0;
      final monthlyIncome = <int, double>{};
      final monthlyExpense = <int, double>{};

      for (final ev in registeredEvents) {
        final evYear = ev.date.year;
        if (evYear != year) continue;
        final month = ev.date.month;
        final evType = ev.type.name;
        if (evType == 'stipendio' || evType == 'entrata' || evType == 'incasso') {
          yearIncome += ev.amount;
          monthlyIncome[month] = (monthlyIncome[month] ?? 0) + ev.amount;
        }
      }

      // Expenses = income - delta(RT)
      final deltaRT = rtEnd - rtStart;
      final expenses = yearIncome - deltaRT;
      final netSavings = yearIncome - expenses;

      // Count tracked days
      final firstDayOfYear = raw.sortedDayKeys.where((dk) => dk >= jan1 && dk <= endKey);
      final trackedDays = firstDayOfYear.isEmpty
          ? 0
          : ((firstDayOfYear.last - firstDayOfYear.first) / 86400).round() + 1;

      if (trackedDays <= 0) continue;

      final daysF = trackedDays.toDouble();
      final savingsRate = yearIncome > 0 ? netSavings / yearIncome : 0.0;

      // Monthly expense breakdown from daily RT changes
      for (final dk in raw.sortedDayKeys) {
        if (dk < jan1 || dk > endKey) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(dk * 1000);
        final idx = raw.sortedDayKeys.indexOf(dk);
        if (idx > 0 && risparTotale.containsKey(dk)) {
          final prevDk = raw.sortedDayKeys[idx - 1];
          if (risparTotale.containsKey(prevDk)) {
            final delta = risparTotale[dk]! - risparTotale[prevDk]!;
            if (delta < 0) {
              monthlyExpense[dt.month] = (monthlyExpense[dt.month] ?? 0) + delta.abs();
            }
          }
        }
      }

      final stats = YearlyStats(
        year: year,
        trackedDays: trackedDays,
        income: yearIncome,
        expenses: expenses,
        netSavings: netSavings,
        savingsRate: savingsRate,
        monthlyIncome: yearIncome / (daysF / 30.4167),
        monthlyExpenses: expenses / (daysF / 30.4167),
        annualizedIncome: yearIncome * (365.0 / daysF),
        annualizedExpenses: expenses * (365.0 / daysF),
        dailyIncome: yearIncome / daysF,
        dailyExpenses: expenses / daysF,
        dailySavings: netSavings / daysF,
        yoyExpenseChange: prevYear != null ? expenses - prevYear!.expenses : 0,
        yoyExpenseChangePct: prevYear != null && prevYear!.annualizedExpenses > 0
            ? ((expenses * 365.0 / daysF) / prevYear!.annualizedExpenses - 1)
            : 0,
        yoyIncomeChangePct: prevYear != null && prevYear!.annualizedIncome > 0
            ? ((yearIncome * 365.0 / daysF) / prevYear!.annualizedIncome - 1)
            : 0,
        monthlyIncomeBreakdown: monthlyIncome,
        monthlyExpenseBreakdown: monthlyExpense,
      );

      result.add(stats);
      prevYear = stats;
    }

    return result;
  }

  static int _toDayKey(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;
}
