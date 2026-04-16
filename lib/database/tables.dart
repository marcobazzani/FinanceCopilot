import 'package:drift/drift.dart';

// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

enum AccountType { bank, broker, crypto }

enum TransactionStatus { pending, settled, cancelled }

enum ExpenseType { opex, capex }

enum CategoryType { income, expense, transfer, reimbursement }

enum AssetType {
  stock,
  stockEtf,
  bondEtf,
  commEtf,
  goldEtc,
  monEtf,
  crypto,
  cash,
  pension,
  deposit,
  realEstate,
  alternative,
  liability,
}

enum InstrumentType {
  stock,        // Azione — Individual equity
  bond,         // Obbligazione — Individual bond
  etf,          // ETF — Exchange-Traded Fund
  etc,          // ETC — Exchange-Traded Commodity
  fund,         // Fondo — Open/closed-end fund
  pension,      // Fondo pensione — Pension fund
  crypto,       // Crypto — Cryptocurrency
  cash,         // Liquidità — Bank account / cash
  deposit,      // Deposito — Term deposit
  realEstate,   // Immobile — Property
  alternative,  // Alternativo — Art, collectibles, etc.
  liability,    // Passività — Debt / mortgage
}

enum AssetClass {
  equity,       // Azionario
  fixedIncome,  // Obbligazionario
  commodities,  // Materie Prime
  moneyMarket,  // Monetario
  cash,         // Liquidità
  crypto,       // Crypto
  realEstate,   // Immobiliare
  alternative,  // Alternativi
  multiAsset,   // Misto — Multi-asset / balanced
}

/// Map investing.com type prefixes (lowercase, singular) to classification.
const _investingTypeMap = <String, (InstrumentType, AssetClass)>{
  'etf':            (InstrumentType.etf,    AssetClass.equity),
  'etc':            (InstrumentType.etc,    AssetClass.commodities),
  'etn':            (InstrumentType.etf,    AssetClass.equity),
  'stock':          (InstrumentType.stock,  AssetClass.equity),
  'equity':         (InstrumentType.stock,  AssetClass.equity),
  'bond':           (InstrumentType.bond,   AssetClass.fixedIncome),
  'fund':           (InstrumentType.fund,   AssetClass.multiAsset),
  'crypto':         (InstrumentType.crypto, AssetClass.crypto),
  // Italian fallbacks (in case Investing.com returns localized types)
  'azione':         (InstrumentType.stock,  AssetClass.equity),
  'titolo':         (InstrumentType.stock,  AssetClass.equity),
  'obbligazione':   (InstrumentType.bond,   AssetClass.fixedIncome),
  'fondo':          (InstrumentType.fund,   AssetClass.multiAsset),
  'criptovaluta':   (InstrumentType.crypto, AssetClass.crypto),
};

/// Classify instrument type + asset class from an investing.com type string.
/// [prefix] should be lowercase, singular (e.g. "etf", "stock", "bond").
(InstrumentType, AssetClass) classifyFromInvestingType(String prefix) =>
    _investingTypeMap[prefix] ?? (InstrumentType.etf, AssetClass.equity);

/// Default asset class for a given instrument type.
/// Used when external classification is unavailable.
AssetClass defaultAssetClassFor(InstrumentType inst) => switch (inst) {
  InstrumentType.bond  => AssetClass.fixedIncome,
  InstrumentType.etc   => AssetClass.commodities,
  InstrumentType.crypto => AssetClass.crypto,
  InstrumentType.fund  => AssetClass.multiAsset,
  _                    => AssetClass.equity,
};

enum ValuationMethod { marketPrice, eventDriven, balance }

enum EventType {
  buy,
  sell,
  revalue,
}

enum IncomeType { income, refund, salary, donation, coupon, other }

enum StepFrequency { weekly, monthly, quarterly, yearly }

enum RegisteredEventType {
  stipendio,
  entrata,
  incasso,
  vendita,
  donazione,
  rimborso,
}

// Extraordinary Events — unified replacement for CAPEX + Income Adjustments.
// Two-axis model: direction (inflow/outflow) × treatment (instant/spread).
enum EventDirection { inflow, outflow }

enum EventTreatment { instant, spread }

enum EventEntryKind { scheduled, manual, reimbursement }

// ──────────────────────────────────────────────
// Tables
// ──────────────────────────────────────────────

class Intermediaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => textEnum<AccountType>().withDefault(Constant(AccountType.bank.name))();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  TextColumn get institution => text().withDefault(const Constant(''))();
  IntColumn get intermediaryId => integer().nullable().references(Intermediaries, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get includeInNetWorth => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => textEnum<CategoryType>()();
  BoolColumn get isEssential => boolean().withDefault(const Constant(false))();
  TextColumn get defaultExpenseType => textEnum<ExpenseType>().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  DateTimeColumn get operationDate => dateTime()();
  DateTimeColumn get valueDate => dateTime()();
  RealColumn get amount => real()();
  RealColumn get balanceAfter => real().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get descriptionFull => text().nullable()();
  TextColumn get status => textEnum<TransactionStatus>().withDefault(Constant(TransactionStatus.settled.name))();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array of strings
  TextColumn get expenseType => textEnum<ExpenseType>().nullable()();
  TextColumn get rawMetadata => text().nullable()(); // JSON
  TextColumn get importHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AutoCategorizationRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get ticker => text().nullable()();
  TextColumn get isin => text().nullable()();
  TextColumn get assetType => textEnum<AssetType>()();
  TextColumn get instrumentType => textEnum<InstrumentType>().withDefault(Constant(InstrumentType.etf.name))();
  TextColumn get assetClass => textEnum<AssetClass>().withDefault(Constant(AssetClass.equity.name))();
  IntColumn get intermediaryId => integer().nullable().references(Intermediaries, #id)();
  TextColumn get assetGroup => text().withDefault(const Constant(''))();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  TextColumn get exchange => text().nullable()();
  TextColumn get yahooTicker => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get sector => text().nullable()();
  RealColumn get ter => real().nullable()();
  RealColumn get taxRate => real().nullable()(); // per-asset tax rate override
  TextColumn get valuationMethod => textEnum<ValuationMethod>()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get includeInNetWorth => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class AssetEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id)();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get valueDate => dateTime()();
  TextColumn get type => textEnum<EventType>()();
  RealColumn get quantity => real().nullable()();
  RealColumn get price => real().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  RealColumn get exchangeRate => real().nullable()();
  RealColumn get commission => real().nullable()();
  RealColumn get taxWithheld => real().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get rawMetadata => text().nullable()(); // JSON
  TextColumn get importHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AssetSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get value => real()();
  RealColumn get invested => real()();
  RealColumn get growth => real()();
  RealColumn get growthPercent => real()();
  RealColumn get afterTaxValue => real()();
  RealColumn get quantity => real().nullable()();
  RealColumn get price => real().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {assetId, date},
      ];
}

class Buffers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real().nullable()();
  // Points to ExtraordinaryEvents.id for reimbursement buckets on spread events.
  // (Legacy name was linked_depreciation_id — renamed in schema v28.)
  IntColumn get linkedEventId => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class BufferTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bufferId => integer().references(Buffers, #id)();
  DateTimeColumn get operationDate => dateTime()();
  DateTimeColumn get valueDate => dateTime()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get amount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  RealColumn get balanceAfter => real()();
  BoolColumn get isPayroll => boolean().withDefault(const Constant(false))();
  BoolColumn get isForceLast => boolean().withDefault(const Constant(false))();
  BoolColumn get isReimbursement => boolean().withDefault(const Constant(false))();
  IntColumn get linkedTransactionId => integer().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class MarketPrices extends Table {
  IntColumn get assetId => integer().references(Assets, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get closePrice => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();

  @override
  Set<Column> get primaryKey => {assetId, date};
}

class ExchangeRates extends Table {
  TextColumn get fromCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get toCurrency => text().withLength(min: 3, max: 3)();
  DateTimeColumn get date => dateTime()();
  RealColumn get rate => real()();

  @override
  Set<Column> get primaryKey => {fromCurrency, toCurrency, date};
}

class RegisteredEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => textEnum<RegisteredEventType>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get amount => real()();
  BoolColumn get isPersonal => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class HealthReimbursements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get invoiceNumber => text()();
  DateTimeColumn get documentDate => dateTime()();
  RealColumn get claimAmount => real()();
  TextColumn get beneficiary => text()();
  RealColumn get reimbursedAmount => real()();
  DateTimeColumn get reimbursementDate => dateTime().nullable()();
  RealColumn get paidAmount => real()();
  RealColumn get uncoveredAmount => real()();
  RealColumn get reimbursementPercent => real()();
  IntColumn get processingDays => integer()();
  BoolColumn get isCovered => boolean()();
}

class AppConfigs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {key};
}

class DashboardCharts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get widgetType => text().withDefault(const Constant('chart'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get seriesJson => text()(); // JSON array of series configs
  TextColumn get sourceChartIds => text().nullable()(); // JSON array of chart IDs, e.g. "[1,3]"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Incomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get valueDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get type => textEnum<IncomeType>().withDefault(Constant(IncomeType.income.name))();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stores per-account import configuration (column mappings, skip rows, etc.)
class ImportConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get skipRows => integer().withDefault(const Constant(0))();
  TextColumn get mappingsJson => text().withDefault(const Constant('{}'))(); // JSON: {targetField: sourceColumn}
  TextColumn get formulaJson => text().withDefault(const Constant('[]'))(); // JSON: [{operator, sourceColumn}]
  TextColumn get hashColumnsJson => text().withDefault(const Constant('[]'))(); // JSON: [col1, col2, ...]
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// ETF composition breakdown (country/sector/holding weights from justETF).
class AssetCompositions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get assetId => integer().references(Assets, #id)();
  TextColumn get type => text()();   // 'country', 'sector', 'holding'
  TextColumn get name => text()();   // e.g. 'United States', 'Technology'
  RealColumn get weight => real()(); // percentage, e.g. 67.33
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Extraordinary Events — unified bucket for things excluded from the pure
/// savings-capacity signal. Replaces DepreciationSchedules + IncomeAdjustments.
///
/// Two orthogonal axes:
///   direction: inflow (non-earned money) | outflow (non-lifestyle spending)
///   treatment: instant (one-shot on eventDate) | spread (amortize via entries)
class ExtraordinaryEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get direction => textEnum<EventDirection>()();
  TextColumn get treatment => textEnum<EventTreatment>()();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  DateTimeColumn get eventDate => dateTime()(); // purchase date / income date
  IntColumn get transactionId => integer().nullable().references(Transactions, #id)();

  // Spread-only fields (null when treatment == instant)
  TextColumn get stepFrequency => textEnum<StepFrequency>().nullable()();
  DateTimeColumn get spreadStart => dateTime().nullable()();
  DateTimeColumn get spreadEnd => dateTime().nullable()();
  IntColumn get bufferId => integer().nullable().references(Buffers, #id)();

  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Counter-delta entries tied to an ExtraordinaryEvent.
/// `amount` is stored SIGNED — the sign reflects the direction semantics,
/// not the sign the user typed. Chart delta-map sums `amount` as-is.
///   scheduled outflow entry: amount < 0 (reduces saving across spread)
///   manual    inflow  entry: amount > 0 (restores saving as lump is spent)
///   reimbursement entry:    amount < 0 (always reduces saving further)
class ExtraordinaryEventEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer().references(ExtraordinaryEvents, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get entryKind => textEnum<EventEntryKind>()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get cumulative => real().nullable()(); // cached for scheduled entries
  RealColumn get remaining => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
