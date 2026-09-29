import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

// Pins the user-visible label of every asset type, valuation method,
// instrument type and asset class, in both languages: the label tables are
// exhaustive switches, so a new enum value cannot compile without its label.
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  test('asset type labels', () {
    expect(
      [for (final t in AssetType.values) en.assetTypeLabel(t)],
      [
        'Stock',
        'Stock ETF',
        'Bond ETF',
        'Commodity ETF',
        'Gold ETC',
        'Money-market ETF',
        'Crypto',
        'Cash',
        'Pension',
        'Deposit',
        'Real estate',
        'Alternative',
        'Liability',
      ],
    );
    expect(
      [for (final t in AssetType.values) it.assetTypeLabel(t)],
      [
        'Azione',
        'ETF azionario',
        'ETF obbligazionario',
        'ETF materie prime',
        'ETC oro',
        'ETF monetario',
        'Cripto',
        'Liquidità',
        'Fondo pensione',
        'Deposito',
        'Immobile',
        'Alternativo',
        'Passività',
      ],
    );
  });

  test('valuation method labels', () {
    expect([for (final m in ValuationMethod.values) en.valuationMethodLabel(m)], ['Market price', 'Event-driven (manual)']);
    expect([for (final m in ValuationMethod.values) it.valuationMethodLabel(m)], ['Prezzo di mercato', 'Manuale (eventi)']);
  });

  test('instrument type labels', () {
    expect(
      [for (final t in InstrumentType.values) en.instrumentTypeLabel(t)],
      [
        'Stock',
        'Bond',
        'ETF',
        'ETC',
        'Fund',
        'Pension Fund',
        'Crypto',
        'Cash',
        'Deposit',
        'Real Estate',
        'Alternative',
        'Liability',
      ],
    );
    expect(
      [for (final t in InstrumentType.values) it.instrumentTypeLabel(t)],
      [
        'Azione',
        'Obbligazione',
        'ETF',
        'ETC',
        'Fondo',
        'Fondo pensione',
        'Cripto',
        'Liquidità',
        'Deposito',
        'Immobile',
        'Alternativo',
        'Passività',
      ],
    );
  });

  test('asset class labels', () {
    expect(
      [for (final c in AssetClass.values) en.assetClassLabel(c)],
      [
        'Equity',
        'Fixed Income',
        'Commodities',
        'Money Market',
        'Cash',
        'Crypto',
        'Real Estate',
        'Alternative',
        'Multi-Asset',
      ],
    );
    expect(
      [for (final c in AssetClass.values) it.assetClassLabel(c)],
      [
        'Azionario',
        'Obbligazionario',
        'Materie prime',
        'Monetario',
        'Liquidità',
        'Cripto',
        'Immobiliare',
        'Alternativi',
        'Misto',
      ],
    );
  });
}
