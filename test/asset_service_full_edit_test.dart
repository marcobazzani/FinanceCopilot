import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_service.dart';

/// Pins the "unlock all fields" edit path. The unlocked Edit dialog only
/// surfaces header attributes that have real read-side consumers in
/// `lib/`:
///   currency       → all FX conversions
///   assetType      → composition + dashboard bucketing
///   valuationMethod → composition sync gate, detail-screen UI
///   intermediaryId → assets-list grouping
///   taxRate        → asset_detail header badge
///   includeInNetWorth → net-worth aggregation
///
/// Composition (Asset Class / Geographic / Sector / Top Holdings) is
/// edited inline on the Composition panel via `AssetCompositions`, not
/// here. Asset.country / Asset.sector remain on the table as a fallback
/// for manual assets without composition rows; they're not exposed in
/// the unlock dialog and have no UI surface.
void main() {
  late AppDatabase db;
  late AssetService service;
  late int iid1;
  late int iid2;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetService(db);
    iid1 = await db.into(db.intermediaries).insert(
      IntermediariesCompanion.insert(name: 'Broker A'),
    );
    iid2 = await db.into(db.intermediaries).insert(
      IntermediariesCompanion.insert(name: 'Broker B'),
    );
  });

  tearDown(() async => await db.close());

  test('update round-trips every field exposed by the unlocked Edit dialog', () async {
    final id = await service.create(
      name: 'Seed',
      currency: 'EUR',
      intermediaryId: iid1,
    );

    final result = await service.update(
      id,
      AssetsCompanion(
        name: const Value('Renamed'),
        ticker: const Value('RNM'),
        isin: const Value('IE00BK5BQT80'),
        exchange: const Value('XETRA'),
        instrumentType: const Value(InstrumentType.bond),
        assetClass: const Value(AssetClass.fixedIncome),
        ter: const Value(0.07),
        isActive: const Value(false),
        // Advanced (unlock-only) fields surfaced by the UI
        assetType: const Value(AssetType.bondEtf),
        valuationMethod: const Value(ValuationMethod.balance),
        intermediaryId: Value(iid2),
        currency: const Value('USD'),
        taxRate: const Value(0.125),
        includeInNetWorth: const Value(false),
      ),
    );
    expect(result, isTrue);

    final out = await service.getById(id);
    expect(out.name, 'Renamed');
    expect(out.ticker, 'RNM');
    expect(out.isin, 'IE00BK5BQT80');
    expect(out.exchange, 'XETRA');
    expect(out.instrumentType, InstrumentType.bond);
    expect(out.assetClass, AssetClass.fixedIncome);
    expect(out.ter, 0.07);
    expect(out.isActive, isFalse);
    expect(out.assetType, AssetType.bondEtf);
    expect(out.valuationMethod, ValuationMethod.balance);
    expect(out.intermediaryId, iid2);
    expect(out.currency, 'USD');
    expect(out.taxRate, 0.125);
    expect(out.includeInNetWorth, isFalse);
  });

  test('locked path: writing only the original 8 fields leaves advanced fields unchanged', () async {
    final id = await service.create(
      name: 'Pinned',
      currency: 'EUR',
      intermediaryId: iid1,
      assetType: AssetType.pension,
      includeInNetWorth: false,
    );

    // Locked-path save: the dialog only writes the original 8 fields.
    await service.update(
      id,
      const AssetsCompanion(
        name: Value('PinnedRenamed'),
        ticker: Value('PIN'),
        isin: Value('IT0001234567'),
        exchange: Value('MIL'),
        isActive: Value(true),
        instrumentType: Value(InstrumentType.fund),
        assetClass: Value(AssetClass.equity),
        ter: Value(0.18),
      ),
    );

    final out = await service.getById(id);
    expect(out.name, 'PinnedRenamed');
    expect(out.ticker, 'PIN');
    expect(out.isin, 'IT0001234567');
    expect(out.exchange, 'MIL');
    expect(out.isActive, isTrue);
    expect(out.instrumentType, InstrumentType.fund);
    expect(out.assetClass, AssetClass.equity);
    expect(out.ter, 0.18);
    // Advanced fields untouched by locked path.
    expect(out.assetType, AssetType.pension);
    expect(out.includeInNetWorth, isFalse);
    expect(out.intermediaryId, iid1);
    expect(out.currency, 'EUR');
  });

  test('create persists the advanced parameters', () async {
    final id = await service.create(
      name: 'New',
      currency: 'CHF',
      intermediaryId: iid1,
      assetType: AssetType.crypto,
      ter: 0.0,
      taxRate: 0.26,
      isActive: true,
      includeInNetWorth: true,
    );

    final out = await service.getById(id);
    expect(out.assetType, AssetType.crypto);
    expect(out.ter, 0.0);
    expect(out.taxRate, 0.26);
    expect(out.includeInNetWorth, isTrue);
  });

  test('create defaults preserve original behavior when advanced params omitted', () async {
    // Pinning test: prior code hardcoded assetType=stockEtf and only set
    // a small set of original parameters. Confirm those defaults remain.
    final id = await service.create(
      name: 'Legacy',
      currency: 'EUR',
      intermediaryId: iid1,
    );

    final out = await service.getById(id);
    expect(out.assetType, AssetType.stockEtf);
    expect(out.valuationMethod, ValuationMethod.marketPrice);
    expect(out.isActive, isTrue);
    expect(out.includeInNetWorth, isTrue);
  });
}
