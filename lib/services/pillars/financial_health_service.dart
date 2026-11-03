import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/cash_flow_explanation.dart' show ExplainRecord;
import 'package:finance_copilot/services/pillars/health_balance_sheet.dart';
import 'package:finance_copilot/services/pillars/pillar_performance.dart';
import 'package:finance_copilot/utils/chart_math.dart' as chart_math;
import 'package:finance_copilot/utils/formatters.dart' as fmt;

// ── Rating system ──

enum Rating { ottimo, buono, sufficiente, scarso, na }

extension RatingExt on Rating {
  String label(AppStrings s) => switch (this) {
    Rating.ottimo => s.ratingOttimo,
    Rating.buono => s.ratingBuono,
    Rating.sufficiente => s.ratingSufficiente,
    Rating.scarso => s.ratingScarso,
    Rating.na => s.ratingNa,
  };

  Color get color => switch (this) {
    Rating.ottimo => const Color(0xFF4CAF50),
    Rating.buono => const Color(0xFF2196F3),
    Rating.sufficiente => const Color(0xFFFF9800),
    Rating.scarso => const Color(0xFFF44336),
    Rating.na => Colors.grey,
  };

  int get score => switch (this) {
    Rating.ottimo => 100,
    Rating.buono => 75,
    Rating.sufficiente => 50,
    Rating.scarso => 25,
    Rating.na => 0,
  };
}

// ── KPI data model ──

class HealthKpi {
  final String name;
  final double? value;
  final String unit; // '%', ' mesi', 'x', etc.
  final Rating rating;
  final String description;
  final String formula; // e.g. "Cash / Net Worth x 100\n15.000 / 100.000 x 100"

  /// When set, the info dialog renders this rich span instead of [formula].
  final TextSpan? formulaRich;

  /// An amount of money shown in place of [value] as the headline of the card.
  /// It is position size, so privacy mode masks it.
  final String? amountLabel;

  /// A line under the name saying more about the headline: shape, not
  /// magnitude, so privacy mode leaves it readable.
  final String? subtitle;

  /// Whether the figures in [formula] are position size, masked in privacy mode
  /// below the symbolic first line. False when they are only percentages.
  final bool formulaFiguresPrivate;

  const HealthKpi({
    required this.name,
    this.value,
    this.unit = '%',
    this.rating = Rating.na,
    this.description = '',
    this.formula = '',
    this.formulaRich,
    this.amountLabel,
    this.subtitle,
    this.formulaFiguresPrivate = true,
  });
}

class KpiCategory {
  final String name;
  final List<HealthKpi> kpis;

  const KpiCategory({required this.name, required this.kpis});

  /// Mean points of the rated KPIs; null when none is rated.
  double? get score => categoryScore(kpis);

  Rating get overallRating => categoryRating(kpis);
}

// ── Rating scales and scores ──

/// Rating of a value that is better the higher it is: [buono] or more is
/// Excellent, [suff] Good, [scarso] Fair, below it Poor.
Rating rateNormal(double value, double scarso, double suff, double buono) {
  if (value >= buono) return Rating.ottimo;
  if (value >= suff) return Rating.buono;
  if (value >= scarso) return Rating.sufficiente;
  return Rating.scarso;
}

/// Rating of a value that is better the lower it is: under [excellent] (up to
/// it when [inclusive]) is Excellent, then [good], then [fair], above it Poor.
Rating rateLowerBetter(double value, double excellent, double good, double fair, {bool inclusive = false}) {
  bool within(double limit) => inclusive ? value <= limit : value < limit;
  if (within(excellent)) return Rating.ottimo;
  if (within(good)) return Rating.buono;
  if (within(fair)) return Rating.sufficiente;
  return Rating.scarso;
}

/// Mean points of the rated [kpis]; null when none is rated.
double? categoryScore(List<HealthKpi> kpis) {
  final rated = kpis.where((k) => k.rating != Rating.na).toList();
  if (rated.isEmpty) return null;
  return rated.map((k) => k.rating.score).reduce((a, b) => a + b) / rated.length;
}

/// The rating a score of 0-100 stands for.
Rating ratingOfScore(double score) {
  if (score >= 87) return Rating.ottimo;
  if (score >= 62) return Rating.buono;
  if (score >= 37) return Rating.sufficiente;
  return Rating.scarso;
}

Rating categoryRating(List<HealthKpi> kpis) {
  final score = categoryScore(kpis);
  return score == null ? Rating.na : ratingOfScore(score);
}

/// The summary score: the mean of the scores of the [categories] (each one the
/// mean of its rated KPIs), so every category weighs the same whatever its
/// number of KPIs. A category with nothing rated takes no part; nothing rated
/// at all leaves no score.
({double? score, Rating rating}) overallHealth(Iterable<KpiCategory> categories) {
  final scores = [
    for (final category in categories) ?category.score,
  ];
  if (scores.isEmpty) return (score: null, rating: Rating.na);
  final score = scores.reduce((a, b) => a + b) / scores.length;
  return (score: score, rating: ratingOfScore(score));
}

// ── KPI computation ──

/// Income of the last 12 months: the [records] dated after the same day a year
/// ago, up to and including [today]. Whole days, not whole calendar months: a
/// window of months loses the salary of the month it starts in on the first
/// day of the month and gains the next one only when it is paid.
double incomeOverLastYear(Iterable<ExplainRecord> records, DateTime today) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(today.year - 1, today.month, today.day);
  var total = 0.0;
  for (final record in records) {
    final day = DateTime(record.date.year, record.date.month, record.date.day);
    if (day.isAfter(start) && !day.isAfter(end)) total += record.amount;
  }
  return total;
}

/// The Liquidity, Financial & Wealth and Debt categories, from the [sheet] of
/// balances (null: there is no net worth) and the income and expense figures.
///
/// A KPI whose inputs are missing is N/A, saying why: no balances and no
/// income are not a 0% ratio rated Poor. The ratios over the net worth are N/A
/// as well when it is zero or negative — it means nothing then, and the KPI
/// says that instead of "no data". The FIRE number joins Financial & Wealth
/// afterwards ([fireKpi]).
///
/// Monthly expenses are [estimatedAnnualExpenses] over 12 — the same yearly
/// figure the FIRE number is made from — or, while there is no previous year to
/// estimate from, the average of this year so far ([thisYearMonthlyExpenses]).
List<KpiCategory> computeKpis({
  required HealthBalanceSheet? sheet,
  required double annualIncome,
  required double annualSavings,
  required double rollingIncome,
  required double? estimatedAnnualExpenses,
  required double thisYearMonthlyExpenses,
  required AppStrings s,
  required String locale,
}) {
  final f = NumberFormat.decimalPattern(locale);
  String n(double v) => f.format(v.round());

  final monthlyExpenses = estimatedAnnualExpenses != null ? estimatedAnnualExpenses / 12 : thisYearMonthlyExpenses;

  /// [name] with no value and no rating, saying why, and only the symbolic
  /// first line of its formula: no placeholder figures.
  HealthKpi unavailable(String name, String why, String formula, {String unit = '%'}) =>
      HealthKpi(name: name, unit: unit, description: why, formula: formula);

  HealthKpi overNetWorth(String name, String formula, HealthKpi Function(HealthBalanceSheet b) build) {
    final b = sheet;
    if (b == null) return unavailable(name, s.noData, formula);
    if (b.netWorth <= 0) return unavailable(name, s.kpiNetWorthNotPositive, formula);
    return build(b);
  }

  HealthKpi overGrossAssets(String name, String formula, HealthKpi Function(HealthBalanceSheet b) build) {
    final b = sheet;
    if (b == null) return unavailable(name, s.noData, formula);
    if (b.grossAssets <= 0) return unavailable(name, s.kpiNetWorthNotPositive, formula);
    return build(b);
  }

  String grossAssetsDefinition(HealthBalanceSheet b) => s.healthDefGrossAssets(n(b.netWorth), n(b.owed));

  // -- Liquidity --
  final liquidityRatio = overNetWorth(s.kpiLiquidityRatio, s.kpiFormulaLiquidityRatio, (b) {
    final value = b.cash / b.netWorth * 100;
    final rating = rateNormal(value, 10, 15, 25);
    return HealthKpi(
      name: s.kpiLiquidityRatio,
      value: value,
      rating: rating,
      description: switch (rating) {
        Rating.ottimo => s.kpiLiquidityDescOttimo,
        Rating.buono => s.kpiLiquidityDescBuono,
        Rating.sufficiente => s.kpiLiquidityDescSufficiente,
        _ => s.kpiLiquidityDescScarso,
      },
      formula: [
        s.kpiFormulaLiquidityRatio,
        '${n(b.cash)} / ${n(b.netWorth)} x 100',
        s.healthDefCash(n(b.bankBalances), n(b.moneyMarket)),
        s.healthDefNetWorth,
      ].join('\n'),
    );
  });

  HealthKpi expenseCoverage() {
    final b = sheet;
    if (b == null || monthlyExpenses <= 0) {
      return unavailable(s.kpiExpenseCoverage, s.noData, s.kpiFormulaExpenseCoverage, unit: s.kpiUnitMonths);
    }
    final months = b.cash / monthlyExpenses;
    final unusedCredit = b.creditLines - b.overdrawnAccounts;
    return HealthKpi(
      name: s.kpiExpenseCoverage,
      value: months,
      unit: s.kpiUnitMonths,
      rating: rateNormal(months, 3, 6, 12),
      description: b.cash < 0 ? s.kpiCoverageNoCash : s.kpiCoverageDesc(months.round()),
      formula: [
        s.kpiFormulaExpenseCoverage,
        '${n(b.cash)} / ${n(monthlyExpenses)}',
        estimatedAnnualExpenses != null ? s.healthDefMonthlyExpenses(n(estimatedAnnualExpenses)) : s.healthDefMonthlyExpensesThisYear,
        s.healthDefCash(n(b.bankBalances), n(b.moneyMarket)),
        if (unusedCredit > 0) s.healthCreditLinesNote(n(unusedCredit), (unusedCredit / monthlyExpenses).round()),
      ].join('\n'),
    );
  }

  HealthKpi savingsRate() {
    if (annualIncome <= 0) return unavailable(s.kpiSavingsRate, s.noData, s.kpiFormulaSavingsRate);
    final value = annualSavings / annualIncome * 100;
    final rating = rateNormal(value, 10, 20, 40);
    return HealthKpi(
      name: s.kpiSavingsRate,
      value: value,
      rating: rating,
      description: switch (rating) {
        Rating.ottimo => s.kpiSavingsDescOttimo,
        Rating.buono => s.kpiSavingsDescBuono,
        Rating.sufficiente => s.kpiSavingsDescSufficiente,
        _ => s.kpiSavingsDescScarso,
      },
      formula: '${s.kpiFormulaSavingsRate}\n${n(annualSavings)} / ${n(annualIncome)} x 100',
    );
  }

  // -- Wealth --
  final investmentWeight = overGrossAssets(s.kpiInvestmentWeight, s.kpiFormulaInvestmentWeight, (b) {
    final value = b.investments / b.grossAssets * 100;
    final rating = rateNormal(value, 20, 40, 60);
    return HealthKpi(
      name: s.kpiInvestmentWeight,
      value: value,
      rating: rating,
      description: switch (rating) {
        Rating.ottimo => s.kpiInvestWeightDescOttimo,
        Rating.buono => s.kpiInvestWeightDescBuono,
        Rating.sufficiente => s.kpiInvestWeightDescSufficiente,
        _ => s.kpiInvestWeightDescScarso,
      },
      formula: [s.kpiFormulaInvestmentWeight, '${n(b.investments)} / ${n(b.grossAssets)} x 100', grossAssetsDefinition(b)].join('\n'),
    );
  });

  final liquidAssetRatio = overGrossAssets(s.kpiLiquidAssetRatio, s.kpiFormulaLiquidAssetRatio, (b) {
    final liquid = b.positiveBankBalances + b.liquidInvestments;
    final value = liquid / b.grossAssets * 100;
    final rating = rateNormal(value, 50, 65, 80);
    return HealthKpi(
      name: s.kpiLiquidAssetRatio,
      value: value,
      rating: rating,
      description: rating == Rating.ottimo || rating == Rating.buono ? s.kpiLiquidAssetDescGood : s.kpiLiquidAssetDescLow,
      formula: [
        s.kpiFormulaLiquidAssetRatio,
        '(${n(b.positiveBankBalances)} + ${n(b.liquidInvestments)}) / ${n(b.grossAssets)} x 100',
        grossAssetsDefinition(b),
      ].join('\n'),
    );
  });

  HealthKpi incomeToWealth() {
    final b = sheet;
    if (b == null || rollingIncome <= 0) return unavailable(s.kpiIncomeToWealth, s.noData, s.kpiFormulaIncomeToWealth);
    if (b.netWorth <= 0) return unavailable(s.kpiIncomeToWealth, s.kpiNetWorthNotPositive, s.kpiFormulaIncomeToWealth);
    final value = rollingIncome / b.netWorth * 100;
    final rating = rateNormal(value, 5, 10, 20);
    return HealthKpi(
      name: s.kpiIncomeToWealth,
      value: value,
      rating: rating,
      description: rating == Rating.ottimo || rating == Rating.buono ? s.kpiIncomeWealthDescGood : s.kpiIncomeWealthDescLow,
      formula: [s.kpiFormulaIncomeToWealth, '${n(rollingIncome)} / ${n(b.netWorth)} x 100', s.healthDefNetWorth].join('\n'),
    );
  }

  // -- Debt --
  final debtToAssets = overGrossAssets(s.kpiDebtToAssets, s.kpiFormulaDebtToAssets, (b) {
    final value = b.owed / b.grossAssets * 100;
    final rating = rateLowerBetter(value, 10, 30, 50);
    return HealthKpi(
      name: s.kpiDebtToAssets,
      value: value,
      rating: rating,
      description: switch (rating) {
        Rating.ottimo => s.kpiDebtDescOttimo,
        Rating.buono => s.kpiDebtDescBuono,
        Rating.sufficiente => s.kpiDebtDescSufficiente,
        _ => s.kpiDebtDescScarso,
      },
      formula: [
        s.kpiFormulaDebtToAssets,
        '${n(b.owed)} / ${n(b.grossAssets)} x 100',
        s.healthDefOwed(n(b.overdrawnAccounts), n(b.liabilities)),
        grossAssetsDefinition(b),
      ].join('\n'),
    );
  });

  HealthKpi creditLineUsage() {
    final b = sheet;
    if (b == null) return unavailable(s.kpiCreditLineUsage, s.noData, s.kpiFormulaCreditLineUsage);
    if (b.creditLines <= 0) return unavailable(s.kpiCreditLineUsage, s.kpiNoCreditLines, s.kpiFormulaCreditLineUsage);
    final value = b.overdrawnAccounts / b.creditLines * 100;
    final rating = rateLowerBetter(value, 25, 50, 75);
    return HealthKpi(
      name: s.kpiCreditLineUsage,
      value: value,
      rating: rating,
      description: switch (rating) {
        Rating.ottimo => s.kpiCreditUsageDescOttimo,
        Rating.buono => s.kpiCreditUsageDescBuono,
        Rating.sufficiente => s.kpiCreditUsageDescSufficiente,
        _ => s.kpiCreditUsageDescScarso,
      },
      formula: [s.kpiFormulaCreditLineUsage, '${n(b.overdrawnAccounts)} / ${n(b.creditLines)} x 100'].join('\n'),
    );
  }

  final liquidity = [liquidityRatio, expenseCoverage(), savingsRate()];
  final wealth = [investmentWeight, liquidAssetRatio, incomeToWealth()];
  final debt = [debtToAssets, creditLineUsage()];
  return [
    KpiCategory(name: s.healthCatLiquidity, kpis: liquidity),
    KpiCategory(name: s.healthCatWealth, kpis: wealth),
    KpiCategory(name: s.healthCatDebt, kpis: debt),
  ];
}

/// The FI Target description for [rating] (see [rateFire]).
String fireDescription(Rating rating, AppStrings s) => switch (rating) {
  Rating.ottimo => s.kpiFireDescOttimo,
  Rating.buono => s.kpiFireDescBuono,
  Rating.sufficiente => s.kpiFireDescSufficiente,
  _ => s.kpiFireDescScarso,
};

/// The FIRE number card: the number as the headline (an amount, masked in
/// privacy mode), rated on how much of it the investable net worth covers. N/A
/// without a FIRE number. [money] spells an amount with its currency.
HealthKpi fireKpi({required FireResult fire, required AppStrings s, required NumberFormat pctFmt, required String Function(double) money}) {
  if (fire.insufficientData) {
    return HealthKpi(name: s.kpiFireNumber, description: s.kpiFireInsufficientData());
  }
  return HealthKpi(
    name: s.kpiFireNumber,
    value: fire.fiNumber,
    rating: fire.rating,
    description: fireDescription(fire.rating, s),
    amountLabel: money(fire.fiNumber),
    subtitle: s.kpiFireReached('${pctFmt.format(fire.progressPct)}%'),
  );
}

/// The holding of a single stock or crypto that weighs most in the portfolio.
class LargestPosition {
  /// Its ticker (its name without one); null when no stock or crypto is held.
  final String? name;
  final double value;

  /// Market value of every position it is measured against.
  final double total;

  const LargestPosition({required this.name, required this.value, required this.total});

  double get pct => total > 0 ? value / total * 100 : 0;
}

/// Instruments that are a bet on one name: holding one is a concentration of
/// its own. A fund, an ETF or a bond is spread over many names already.
const _singleNameInstruments = {InstrumentType.stock, InstrumentType.crypto};

/// The [LargestPosition] among the [assets] with a positive market value in
/// [values] (a position is every asset with the same ticker); null when there
/// is nothing to measure against. An asset without a value cannot be weighed
/// and is skipped.
LargestPosition? computeLargestPosition(List<Asset> assets, Map<int, double> values) {
  var total = 0.0;
  final singles = <String, double>{};
  for (final asset in assets) {
    final value = values[asset.id];
    if (value == null || value <= 0) continue;
    total += value;
    if (_singleNameInstruments.contains(asset.instrumentType)) {
      final position = asset.ticker ?? asset.name;
      singles[position] = (singles[position] ?? 0) + value;
    }
  }
  if (total <= 0) return null;
  if (singles.isEmpty) return LargestPosition(name: null, value: 0, total: total);
  final largest = singles.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return LargestPosition(name: largest.key, value: largest.value, total: total);
}

/// Largest Position card; N/A without [position]. A portfolio with no single
/// stock or crypto has nothing concentrated: 0%, Excellent.
HealthKpi largestPositionKpi({required LargestPosition? position, required AppStrings s, required String locale}) {
  if (position == null) {
    return HealthKpi(name: s.kpiLargestPosition, description: s.noData, formula: s.kpiFormulaLargestPosition);
  }
  final f = NumberFormat.decimalPattern(locale);
  String n(double v) => f.format(v.round());
  final value = position.pct;
  final rating = rateLowerBetter(value, 5, 10, 20, inclusive: true);
  return HealthKpi(
    name: s.kpiLargestPosition,
    value: value,
    rating: rating,
    description: switch (rating) {
      Rating.ottimo => s.kpiPositionDescOttimo,
      Rating.buono => s.kpiPositionDescBuono,
      Rating.sufficiente => s.kpiPositionDescSufficiente,
      _ => s.kpiPositionDescScarso,
    },
    formula: [
      s.kpiFormulaLargestPosition,
      position.name == null ? s.kpiNoSinglePositions : s.kpiLargestPositionLine(position.name!, n(position.value), n(position.total)),
    ].join('\n'),
  );
}

/// Whole days of history an annual rate needs: a shorter stretch says nothing
/// about a year.
const int kMinDaysToAnnualize = 365;

/// Annualized Return card: the time-weighted return of [snapshot] per year,
/// since its first investment. N/A without a [snapshot] to measure, and until
/// there is a year of history to annualize.
HealthKpi annualizedReturnKpi({required PillarPerformanceSnapshot? snapshot, required AppStrings s, required String locale}) {
  final cagr = snapshot?.cagr;
  final twrr = snapshot?.twrr;
  final since = snapshot?.inceptionDate;
  if (snapshot == null ||
      cagr == null ||
      twrr == null ||
      since == null ||
      chart_math.calendarDaysBetween(since, snapshot.asOfDate) < kMinDaysToAnnualize) {
    return HealthKpi(name: s.kpiAnnualizedReturn, description: s.kpiAnnualizedReturnNeedsYear, formula: s.kpiFormulaAnnualizedReturn);
  }
  final pct = NumberFormat('0.0', locale);
  final pctYear = NumberFormat('0.00', locale);
  final value = cagr * 100;
  final rating = rateNormal(value, 0, 2, 5);
  return HealthKpi(
    name: s.kpiAnnualizedReturn,
    value: value,
    rating: rating,
    description: switch (rating) {
      Rating.ottimo => s.kpiReturnDescOttimo,
      Rating.buono => s.kpiReturnDescBuono,
      Rating.sufficiente => s.kpiReturnDescSufficiente,
      _ => s.kpiReturnDescScarso,
    },
    formula: [
      s.kpiFormulaAnnualizedReturn,
      s.kpiReturnSince(fmt.fullDateFormat(locale).format(since), '${twrr >= 0 ? '+' : ''}${pct.format(twrr * 100)}%'),
      s.kpiReturnPerYear('${pctYear.format(value)}%'),
    ].join('\n'),
    formulaFiguresPrivate: false,
  );
}

/// Rate a weighted TER (%): the cheaper, the better.
Rating rateTer(double ter) => ter <= 0.2
    ? Rating.ottimo
    : ter <= 0.5
    ? Rating.buono
    : ter <= 1.0
    ? Rating.sufficiente
    : Rating.scarso;

// ── FIRE (Financial Independence, Retire Early) ──

/// Default Safe Withdrawal Rate (%), used when no user override is set.
const double kDefaultFireSwrPct = 2.75;

/// Result of a FIRE computation.
class FireResult {
  /// The FIRE number, the portfolio that pays the expenses for good:
  /// annualExpenses / (swrPct / 100).
  final double fiNumber;

  /// Current progress toward the FIRE number.
  final double progressPct;

  /// Rating for the progress.
  final Rating rating;

  /// True when the inputs were insufficient (e.g. no expenses) so the
  /// caller should mark the KPI as N/A.
  final bool insufficientData;

  const FireResult({
    required this.fiNumber,
    required this.progressPct,
    required this.rating,
    required this.insufficientData,
  });
}

/// Compute FIRE progress from the investable net worth, annual expenses and SWR%.
///
/// Returns insufficientData=true when [annualExpenses] <= 0 or [swrPct] <= 0,
/// because the FIRE number is undefined.
FireResult computeFire({
  required double netWorth,
  required double annualExpenses,
  required double swrPct,
}) {
  if (annualExpenses <= 0 || swrPct <= 0) {
    return const FireResult(
      fiNumber: 0,
      progressPct: 0,
      rating: Rating.na,
      insufficientData: true,
    );
  }
  final fiNumber = annualExpenses / (swrPct / 100);
  final progressPct = fiNumber > 0 ? max(0.0, netWorth / fiNumber * 100).toDouble() : 0.0;
  return FireResult(
    fiNumber: fiNumber,
    progressPct: progressPct,
    rating: rateFire(progressPct),
    insufficientData: false,
  );
}

/// Rate FIRE progress.
Rating rateFire(double progressPct) {
  if (progressPct >= 100) return Rating.ottimo;
  if (progressPct >= 50) return Rating.buono;
  if (progressPct >= 25) return Rating.sufficiente;
  return Rating.scarso;
}
