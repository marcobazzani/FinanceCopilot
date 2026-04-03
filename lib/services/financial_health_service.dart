import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';

// ── Rating system ──

enum Rating { ottimo, buono, sufficiente, scarso, alto, na }

extension RatingExt on Rating {
  String label(AppStrings s) => switch (this) {
    Rating.ottimo => s.ratingOttimo,
    Rating.buono => s.ratingBuono,
    Rating.sufficiente => s.ratingSufficiente,
    Rating.scarso => s.ratingScarso,
    Rating.alto => s.ratingAlto,
    Rating.na => s.ratingNa,
  };

  Color get color => switch (this) {
    Rating.ottimo => const Color(0xFF4CAF50),
    Rating.buono => const Color(0xFF2196F3),
    Rating.sufficiente => const Color(0xFFFF9800),
    Rating.scarso => const Color(0xFFF44336),
    Rating.alto => const Color(0xFF4CAF50),
    Rating.na => Colors.grey,
  };

  int get score => switch (this) {
    Rating.ottimo => 100,
    Rating.buono || Rating.alto => 75,
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
  final String formula; // e.g. "Cash / Net Worth x 100 = 15.000 / 100.000 x 100"

  const HealthKpi({
    required this.name,
    this.value,
    this.unit = '%',
    this.rating = Rating.na,
    this.description = '',
    this.formula = '',
  });
}

class KpiCategory {
  final String name;
  final List<HealthKpi> kpis;
  final Rating overallRating;

  const KpiCategory({required this.name, required this.kpis, required this.overallRating});
}

// ── KPI computation ──

Rating rateNormal(double value, double scarso, double suff, double buono) {
  if (value >= buono) return Rating.ottimo;
  if (value >= suff) return Rating.buono;
  if (value >= scarso) return Rating.sufficiente;
  return Rating.scarso;
}

Rating categoryRating(List<HealthKpi> kpis) {
  final rated = kpis.where((k) => k.rating != Rating.na).toList();
  if (rated.isEmpty) return Rating.na;
  final avg = rated.map((k) => k.rating.score).reduce((a, b) => a + b) / rated.length;
  if (avg >= 87) return Rating.ottimo;
  if (avg >= 62) return Rating.buono;
  if (avg >= 37) return Rating.sufficiente;
  return Rating.scarso;
}

List<KpiCategory> computeKpis({
  required double cash,
  required double investments,
  required double annualIncome,
  required double annualExpenses,
  required double annualSavings,
  required double monthlyExpenses,
  required AppStrings s,
  required String locale,
}) {
  final f = NumberFormat.decimalPattern(locale);
  String n(double v) => f.format(v.round());

  final grossAssets = cash + investments;
  final netWorth = grossAssets;

  // -- Liquidity --
  final liquidityRatio = netWorth > 0 ? cash / netWorth * 100 : 0.0;
  final liquidityRating = rateNormal(liquidityRatio, 10, 15, 25);

  final coverageMonths = monthlyExpenses > 0 ? cash / monthlyExpenses : 0.0;
  final coverageRating = rateNormal(coverageMonths, 3, 6, 12);

  final savingsRate = annualIncome > 0 ? annualSavings / annualIncome * 100 : 0.0;
  final savingsRating = rateNormal(savingsRate, 10, 20, 40);

  final liquidityKpis = [
    HealthKpi(
      name: s.kpiLiquidityRatio,
      value: liquidityRatio,
      rating: liquidityRating,
      description: s.kpiLiquidityDesc(liquidityRating == Rating.ottimo ? 'ottimo' : liquidityRating == Rating.buono ? 'buono' : liquidityRating == Rating.sufficiente ? 'sufficiente' : 'scarso'),
      formula: 'Cash / Net Worth x 100\n${n(cash)} / ${n(netWorth)} x 100',
    ),
    HealthKpi(
      name: s.kpiExpenseCoverage,
      value: coverageMonths,
      unit: unitMonths(s),
      rating: coverageRating,
      description: s.kpiCoverageDesc(coverageMonths.round()),
      formula: 'Cash / Monthly Expenses\n${n(cash)} / ${n(monthlyExpenses)}',
    ),
    HealthKpi(
      name: s.kpiSavingsRate,
      value: savingsRate,
      rating: savingsRating,
      description: s.kpiSavingsDesc(savingsRating == Rating.ottimo ? 'ottimo' : savingsRating == Rating.buono ? 'buono' : savingsRating == Rating.sufficiente ? 'sufficiente' : 'scarso'),
      formula: 'Savings / Income x 100\n${n(annualSavings)} / ${n(annualIncome)} x 100',
    ),
  ];

  // -- Wealth --
  final investWeight = grossAssets > 0 ? investments / grossAssets * 100 : 0.0;
  final investWeightRating = investWeight >= 60 ? Rating.alto : rateNormal(investWeight, 20, 40, 60);

  final liquidAssetRatio = grossAssets > 0 ? (cash + investments) / grossAssets * 100 : 0.0;
  final liquidAssetRating = rateNormal(liquidAssetRatio, 50, 65, 80);

  final incomeToWealth = netWorth > 0 ? annualIncome / netWorth * 100 : 0.0;
  final incomeToWealthRating = rateNormal(incomeToWealth, 5, 10, 20);

  final wealthKpis = [
    HealthKpi(
      name: s.kpiInvestmentWeight,
      value: investWeight,
      rating: investWeightRating,
      description: s.kpiInvestWeightDesc(investWeightRating.name),
      formula: 'Investments / Gross Assets x 100\n${n(investments)} / ${n(grossAssets)} x 100',
    ),
    HealthKpi(
      name: s.kpiLiquidAssetRatio,
      value: liquidAssetRatio,
      rating: liquidAssetRating,
      description: s.kpiLiquidAssetDesc(liquidAssetRating == Rating.ottimo || liquidAssetRating == Rating.buono ? 'ottimo' : 'altro'),
      formula: '(Cash + Investments) / Gross Assets x 100\n(${n(cash)} + ${n(investments)}) / ${n(grossAssets)} x 100',
    ),
    HealthKpi(
      name: s.kpiIncomeToWealth,
      value: incomeToWealth,
      rating: incomeToWealthRating,
      description: s.kpiIncomeWealthDesc(incomeToWealthRating == Rating.ottimo || incomeToWealthRating == Rating.buono ? 'ottimo' : 'altro'),
      formula: 'Income / Net Worth x 100\n${n(annualIncome)} / ${n(netWorth)} x 100',
    ),
  ];

  return [
    KpiCategory(name: s.healthCatLiquidity, kpis: liquidityKpis, overallRating: categoryRating(liquidityKpis)),
    KpiCategory(name: s.healthCatWealth, kpis: wealthKpis, overallRating: categoryRating(wealthKpis)),
  ];
}

String unitMonths(AppStrings s) => s.ratingOttimo == 'Ottimo' ? ' mesi' : ' months';

/// Compute portfolio price change % from a list of (previousValue, currentValue) pairs.
/// Each pair represents an asset's base-currency value at the reference date vs today.
double computePriceChangePct(List<(double prev, double now)> assetValues) {
  final totalPrev = assetValues.fold(0.0, (s, v) => s + v.$1);
  final totalNow = assetValues.fold(0.0, (s, v) => s + v.$2);
  return totalPrev > 0 ? (totalNow - totalPrev) / totalPrev * 100 : 0.0;
}

/// Rate a price change percentage.
Rating ratePriceChange(double pct) =>
    pct >= 10 ? Rating.ottimo : pct >= 0 ? Rating.buono : pct >= -10 ? Rating.sufficiente : Rating.scarso;

/// Compute HHI (Herfindahl-Hirschman Index) from a map of holding values.
/// Returns 0-10000. Lower = more diversified.
double computeHhi(Map<String, double> holdingValues) {
  final total = holdingValues.values.fold(0.0, (a, b) => a + b);
  if (total <= 0) return 0;
  return holdingValues.values.fold(0.0, (sum, v) => sum + pow(v / total, 2)) * 10000;
}

/// Rate an HHI value.
Rating rateHhi(double hhi) =>
    hhi < 1500 ? Rating.ottimo : hhi < 2500 ? Rating.buono : Rating.scarso;
