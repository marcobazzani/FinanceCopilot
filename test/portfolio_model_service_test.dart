import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/pillar_service.dart';
import 'package:finance_copilot/services/portfolio_model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Portfolio model Markdown parser', () {
    test('parses full and mini Markdown files', () async {
      final full = PortfolioModelService.parseMarkdown(
        await rootBundle.loadString('PortfolioModels/2026/60-equity/portfolio.md'),
        path: 'PortfolioModels/2026/60-equity/portfolio.md',
      );
      expect(full.id, 'portfolio_2026_060_ptf');
      expect(full.year, 2026);
      expect(full.equityPercent, 60);
      expect(full.variant, PortfolioModelVariant.full);
      expect(full.items, hasLength(10));

      final mini = PortfolioModelService.parseMarkdown(
        await rootBundle.loadString('PortfolioModels/2026/60-equity/mini-portfolio.md'),
        path: 'PortfolioModels/2026/60-equity/mini-portfolio.md',
      );
      expect(mini.id, 'mini_portfolio_2026_060_ptf');
      expect(mini.variant, PortfolioModelVariant.mini);
      expect(mini.items, hasLength(3));
    });
  });

  group('PortfolioModelService', () {
    late AppDatabase db;
    late PortfolioModelService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = PortfolioModelService(db);
    });

    tearDown(() async => db.close());

    test('seeds all built-in models once and re-seeds without duplicates', () async {
      expect(await service.seedBuiltInModels(), 32);
      expect(await db.select(db.portfolioModels).get(), hasLength(32));

      await service.seedBuiltInModels();
      final models = await db.select(db.portfolioModels).get();
      expect(models, hasLength(32));

      for (final model in models) {
        final items = await service.getItems(model.id);
        final total = items.fold<double>(0, (sum, item) => sum + item.targetWeight);
        expect(total, closeTo(100, 1e-9), reason: model.id);
      }
    });

    test('custom model CRUD validates and persists ordered rows', () async {
      final id = await service.createCustomModel(
        name: 'Core',
        items: const [
          PortfolioModelInputItem(
            isin: 'IE00B4L5Y983',
            targetWeight: 60,
            description: 'World',
            preferredTicker: 'SWDA',
            preferredExchange: 'Milan',
          ),
          PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 40, description: 'Gold'),
        ],
      );
      var model = await service.getWithItems(id);
      expect(model!.model.isBuiltIn, isFalse);
      expect(model.items.map((i) => i.isin), ['IE00B4L5Y983', 'IE00B579F325']);
      expect(model.items.first.preferredTicker, 'SWDA');
      expect(model.items.first.preferredExchange, 'Milan');

      await service.updateCustomModel(
        id,
        name: 'Core updated',
        items: const [
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100, description: 'World'),
        ],
      );
      model = await service.getWithItems(id);
      expect(model!.model.name, 'Core updated');
      expect(model.items, hasLength(1));

      await service.deleteCustomModel(id);
      expect(await service.getById(id), isNull);
    });

    test('rejects invalid totals, duplicate ISINs, and malformed rows', () {
      expect(
        () => PortfolioModelService.validateItems(const [
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 60),
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 40),
        ]),
        throwsA(isA<PortfolioModelValidationException>()),
      );
      expect(
        () => PortfolioModelService.validateItems(const [
          PortfolioModelInputItem(isin: 'bad', targetWeight: 100),
        ]),
        throwsA(isA<PortfolioModelValidationException>()),
      );
      expect(
        () => PortfolioModelService.validateItems(const [
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 99),
        ]),
        throwsA(isA<PortfolioModelValidationException>()),
      );
    });

    test('computes exact-ISIN divergence with unmatched and extra rows', () async {
      final iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
      final assets = AssetService(db);
      final events = AssetEventService(db);
      final pillars = PillarService(db);
      final matchedAsset = await assets.create(
        name: 'World',
        isin: 'IE00B4L5Y983',
        currency: 'EUR',
        intermediaryId: iid,
      );
      final extraAsset = await assets.create(
        name: 'Extra',
        isin: 'IE00B579F325',
        currency: 'EUR',
        intermediaryId: iid,
      );
      await events.create(
        assetId: matchedAsset,
        date: DateTime(2026, 1, 1),
        type: EventType.buy,
        quantity: 10,
        price: 100,
        amount: 1000,
        currency: 'EUR',
      );
      await events.create(
        assetId: extraAsset,
        date: DateTime(2026, 1, 1),
        type: EventType.buy,
        quantity: 10,
        price: 100,
        amount: 1000,
        currency: 'EUR',
      );
      final modelId = await service.createCustomModel(
        name: 'Target',
        items: const [
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50),
          PortfolioModelInputItem(isin: 'IE0006WW1TQ4', targetWeight: 50),
        ],
      );
      final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
      await pillars.assign(pillarId: pillarId, assetId: matchedAsset, qty: 10);
      await pillars.assign(pillarId: pillarId, assetId: extraAsset, qty: 10);

      final divergence = await service.computeDivergenceForPillar(
        pillarId: pillarId,
        marketValuesByAssetId: {
          matchedAsset: 1000,
          extraAsset: 1000,
        },
      );
      expect(divergence, isNotNull);
      expect(divergence!.rows.first.currentWeight, closeTo(50, 1e-9));
      expect(divergence.rows.last.isUnmatched, isTrue);
      expect(divergence.extraHoldings.single.assetId, extraAsset);
    });
  });

  test('migrates v40 databases through the current schema', () async {
    final dir = await Directory.systemTemp.createTemp('fc_schema_migration_');
    final path = p.join(dir.path, 'migration.db');
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    await db.select(db.accounts).get();
    await db.close();

    final raw = sqlite.sqlite3.open(path);
    try {
      raw.execute('DROP INDEX IF EXISTS idx_pillars_portfolio_model');
      raw.execute('DROP INDEX IF EXISTS idx_portfolio_model_items_model');
      raw.execute('DROP TABLE portfolio_model_items');
      raw.execute('DROP TABLE portfolio_models');
      raw.execute('ALTER TABLE pillars DROP COLUMN portfolio_model_id');
      raw.execute('PRAGMA user_version = 40');
    } finally {
      raw.dispose();
    }

    final migrated = AppDatabase.forTesting(NativeDatabase(File(path)));
    final version = (await migrated.customSelect('PRAGMA user_version').get()).first.read<int>('user_version');
    expect(version, 43);
    final modelTables = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('portfolio_models', 'portfolio_model_items')",
        )
        .get();
    expect(modelTables, hasLength(2));
    final itemColumns = await migrated.customSelect('PRAGMA table_info(portfolio_model_items)').get();
    expect(itemColumns.map((row) => row.read<String>('name')), containsAll(['preferred_ticker', 'preferred_exchange']));
    final pillarColumns = await migrated.customSelect('PRAGMA table_info(pillars)').get();
    expect(pillarColumns.map((row) => row.read<String>('name')), contains('portfolio_model_id'));

    await migrated.close();
    await dir.delete(recursive: true);
  });
}
