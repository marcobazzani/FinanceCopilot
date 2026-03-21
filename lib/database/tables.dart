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

enum ValuationMethod { marketPrice, eventDriven, balance }

enum EventType {
  buy,
  sell,
  dividend,
  split,
  vest,
  contribute,
  interest,
  revalue,
  transferIn,
  transferOut,
}

enum DepreciationMethod { linear, decliningBalance, custom }

enum DepreciationDirection { forward, backward }

enum StepFrequency { weekly, monthly, quarterly, yearly }

enum RegisteredEventType {
  stipendio,
  entrata,
  incasso,
  vendita,
  donazione,
  rimborso,
}

// ──────────────────────────────────────────────
// Tables
// ──────────────────────────────────────────────

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => textEnum<AccountType>().withDefault(Constant(AccountType.bank.name))();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  TextColumn get institution => text().withDefault(const Constant(''))();
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
  IntColumn get depreciationId => integer().nullable()();
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

class DepreciationSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().nullable().references(Transactions, #id)();
  TextColumn get assetName => text()();
  TextColumn get assetCategory => text()();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  TextColumn get method => textEnum<DepreciationMethod>()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  DateTimeColumn get expenseDate => dateTime().nullable()();
  IntColumn get usefulLifeMonths => integer()();
  TextColumn get direction => textEnum<DepreciationDirection>()();
  TextColumn get stepFrequency => textEnum<StepFrequency>().withDefault(Constant(StepFrequency.monthly.name))();
  IntColumn get bufferId => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class DepreciationEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scheduleId => integer().references(DepreciationSchedules, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  RealColumn get cumulative => real()();
  RealColumn get remaining => real()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {scheduleId, date},
      ];
}

class Buffers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real().nullable()();
  IntColumn get linkedDepreciationId => integer().nullable().references(DepreciationSchedules, #id)();
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

class IncomeAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3).withDefault(const Constant('EUR'))();
  DateTimeColumn get incomeDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class IncomeAdjustmentExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get adjustmentId => integer().references(IncomeAdjustments, #id)();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Incomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get description => text().withDefault(const Constant(''))();
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
