// Weighted TER of a portfolio: one helper shared by the Health tab and the
// Assets Overview. A fund without a TER on record has an unknown cost, so it
// is left out of both sides of the average and counted; an instrument that
// never charges a TER (a stock, a bond, cash, …) weighs in at zero cost.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/financial_health_service.dart';
import 'package:finance_copilot/services/portfolio/allocation_computation_service.dart';

Asset _asset(int id, {InstrumentType type = InstrumentType.etf, double? ter}) => Asset(
  id: id,
  name: 'A$id',
  assetType: AssetType.stockEtf,
  instrumentType: type,
  assetClass: AssetClass.equity,
  intermediaryId: 1,
  assetGroup: '',
  currency: 'EUR',
  valuationMethod: ValuationMethod.marketPrice,
  ter: ter,
  isActive: true,
  includeInSavings: true,
  sortOrder: 0,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  group('computeWeightedTer', () {
    test('value-weighted over funds with a TER and instruments without one', () {
      final r = computeWeightedTer(
        [_asset(1, ter: 0.2), _asset(2, ter: 0.5), _asset(3, type: InstrumentType.stock)],
        {1: 6000, 2: 3000, 3: 1000},
      );
      expect(r.ter, closeTo(0.27, 1e-12));
      expect(r.annualCost, closeTo(27, 1e-9));
      expect(r.unknownTerFunds, 0);
    });

    test('every TER-charging instrument without a TER is left out and counted', () {
      final r = computeWeightedTer(
        [
          _asset(1, ter: 0.2),
          _asset(2),
          _asset(3, type: InstrumentType.etc),
          _asset(4, type: InstrumentType.fund),
          _asset(5, type: InstrumentType.pension),
        ],
        {1: 1000, 2: 1000, 3: 1000, 4: 1000, 5: 1000},
      );
      expect(r.ter, closeTo(0.2, 1e-12));
      expect(r.unknownTerFunds, 4);
    });

    test('a known 0% TER is a free fund, not an unknown one', () {
      final r = computeWeightedTer([_asset(1, ter: 0), _asset(2, ter: 0.4)], {1: 1000, 2: 1000});
      expect(r.ter, closeTo(0.2, 1e-12));
      expect(r.unknownTerFunds, 0);
    });

    test('holdings without a positive value are skipped, not counted', () {
      final r = computeWeightedTer([_asset(1, ter: 0.2), _asset(2), _asset(3, ter: 1)], {1: 1000, 3: -50});
      expect(r.ter, closeTo(0.2, 1e-12));
      expect(r.unknownTerFunds, 0, reason: 'asset 2 has no value to weigh at all');
    });

    test('nothing to weigh: no TER rather than a free portfolio', () {
      expect(computeWeightedTer(const [], const {}).ter, isNull);
      final onlyUnknown = computeWeightedTer([_asset(1)], {1: 5000});
      expect(onlyUnknown.ter, isNull);
      expect(onlyUnknown.unknownTerFunds, 1);
    });
  });

  group('rateTer', () {
    test('bands: ≤ 0.20 excellent, ≤ 0.50 good, ≤ 1.00 fair, above poor', () {
      expect(rateTer(0.0), Rating.ottimo);
      expect(rateTer(0.2), Rating.ottimo);
      expect(rateTer(0.21), Rating.buono);
      expect(rateTer(0.5), Rating.buono);
      expect(rateTer(0.51), Rating.sufficiente);
      expect(rateTer(1.0), Rating.sufficiente);
      expect(rateTer(1.01), Rating.scarso);
    });
  });
}
