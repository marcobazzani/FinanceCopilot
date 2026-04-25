// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $IntermediariesTable extends Intermediaries
    with TableInfo<$IntermediariesTable, Intermediary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntermediariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _defaultImportLocaleMeta =
      const VerificationMeta('defaultImportLocale');
  @override
  late final GeneratedColumn<String> defaultImportLocale =
      GeneratedColumn<String>(
        'default_import_locale',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortOrder,
    defaultImportLocale,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intermediaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Intermediary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('default_import_locale')) {
      context.handle(
        _defaultImportLocaleMeta,
        defaultImportLocale.isAcceptableOrUnknown(
          data['default_import_locale']!,
          _defaultImportLocaleMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Intermediary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Intermediary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      defaultImportLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_import_locale'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $IntermediariesTable createAlias(String alias) {
    return $IntermediariesTable(attachedDatabase, alias);
  }
}

class Intermediary extends DataClass implements Insertable<Intermediary> {
  final int id;
  final String name;
  final int sortOrder;

  /// Number-format locale used to parse asset-event imports under this
  /// intermediary (e.g. 'it_IT', 'en_US'). NULL means "Auto — use the
  /// app locale".
  final String? defaultImportLocale;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Intermediary({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.defaultImportLocale,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || defaultImportLocale != null) {
      map['default_import_locale'] = Variable<String>(defaultImportLocale);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  IntermediariesCompanion toCompanion(bool nullToAbsent) {
    return IntermediariesCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      defaultImportLocale: defaultImportLocale == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultImportLocale),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Intermediary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Intermediary(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      defaultImportLocale: serializer.fromJson<String?>(
        json['defaultImportLocale'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'defaultImportLocale': serializer.toJson<String?>(defaultImportLocale),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Intermediary copyWith({
    int? id,
    String? name,
    int? sortOrder,
    Value<String?> defaultImportLocale = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Intermediary(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    defaultImportLocale: defaultImportLocale.present
        ? defaultImportLocale.value
        : this.defaultImportLocale,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Intermediary copyWithCompanion(IntermediariesCompanion data) {
    return Intermediary(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      defaultImportLocale: data.defaultImportLocale.present
          ? data.defaultImportLocale.value
          : this.defaultImportLocale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Intermediary(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('defaultImportLocale: $defaultImportLocale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sortOrder,
    defaultImportLocale,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Intermediary &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.defaultImportLocale == this.defaultImportLocale &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class IntermediariesCompanion extends UpdateCompanion<Intermediary> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<String?> defaultImportLocale;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const IntermediariesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.defaultImportLocale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  IntermediariesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.defaultImportLocale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Intermediary> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<String>? defaultImportLocale,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (defaultImportLocale != null)
        'default_import_locale': defaultImportLocale,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  IntermediariesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<String?>? defaultImportLocale,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return IntermediariesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      defaultImportLocale: defaultImportLocale ?? this.defaultImportLocale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (defaultImportLocale.present) {
      map['default_import_locale'] = Variable<String>(
        defaultImportLocale.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntermediariesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('defaultImportLocale: $defaultImportLocale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(AccountType.bank.name),
      ).withConverter<AccountType>($AccountsTable.$convertertype);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _intermediaryIdMeta = const VerificationMeta(
    'intermediaryId',
  );
  @override
  late final GeneratedColumn<int> intermediaryId = GeneratedColumn<int>(
    'intermediary_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES intermediaries (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _includeInNetWorthMeta = const VerificationMeta(
    'includeInNetWorth',
  );
  @override
  late final GeneratedColumn<bool> includeInNetWorth = GeneratedColumn<bool>(
    'include_in_net_worth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_net_worth" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    currency,
    institution,
    intermediaryId,
    isActive,
    includeInNetWorth,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    }
    if (data.containsKey('intermediary_id')) {
      context.handle(
        _intermediaryIdMeta,
        intermediaryId.isAcceptableOrUnknown(
          data['intermediary_id']!,
          _intermediaryIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('include_in_net_worth')) {
      context.handle(
        _includeInNetWorthMeta,
        includeInNetWorth.isAcceptableOrUnknown(
          data['include_in_net_worth']!,
          _includeInNetWorthMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $AccountsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      )!,
      intermediaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intermediary_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      includeInNetWorth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_net_worth'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final String name;
  final AccountType type;
  final String currency;
  final String institution;
  final int? intermediaryId;
  final bool isActive;
  final bool includeInNetWorth;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.institution,
    this.intermediaryId,
    required this.isActive,
    required this.includeInNetWorth,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>($AccountsTable.$convertertype.toSql(type));
    }
    map['currency'] = Variable<String>(currency);
    map['institution'] = Variable<String>(institution);
    if (!nullToAbsent || intermediaryId != null) {
      map['intermediary_id'] = Variable<int>(intermediaryId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['include_in_net_worth'] = Variable<bool>(includeInNetWorth);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      institution: Value(institution),
      intermediaryId: intermediaryId == null && nullToAbsent
          ? const Value.absent()
          : Value(intermediaryId),
      isActive: Value(isActive),
      includeInNetWorth: Value(includeInNetWorth),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $AccountsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      currency: serializer.fromJson<String>(json['currency']),
      institution: serializer.fromJson<String>(json['institution']),
      intermediaryId: serializer.fromJson<int?>(json['intermediaryId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      includeInNetWorth: serializer.fromJson<bool>(json['includeInNetWorth']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $AccountsTable.$convertertype.toJson(type),
      ),
      'currency': serializer.toJson<String>(currency),
      'institution': serializer.toJson<String>(institution),
      'intermediaryId': serializer.toJson<int?>(intermediaryId),
      'isActive': serializer.toJson<bool>(isActive),
      'includeInNetWorth': serializer.toJson<bool>(includeInNetWorth),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    String? currency,
    String? institution,
    Value<int?> intermediaryId = const Value.absent(),
    bool? isActive,
    bool? includeInNetWorth,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    institution: institution ?? this.institution,
    intermediaryId: intermediaryId.present
        ? intermediaryId.value
        : this.intermediaryId,
    isActive: isActive ?? this.isActive,
    includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      intermediaryId: data.intermediaryId.present
          ? data.intermediaryId.value
          : this.intermediaryId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      includeInNetWorth: data.includeInNetWorth.present
          ? data.includeInNetWorth.value
          : this.includeInNetWorth,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('institution: $institution, ')
          ..write('intermediaryId: $intermediaryId, ')
          ..write('isActive: $isActive, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    currency,
    institution,
    intermediaryId,
    isActive,
    includeInNetWorth,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.institution == this.institution &&
          other.intermediaryId == this.intermediaryId &&
          other.isActive == this.isActive &&
          other.includeInNetWorth == this.includeInNetWorth &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> name;
  final Value<AccountType> type;
  final Value<String> currency;
  final Value<String> institution;
  final Value<int?> intermediaryId;
  final Value<bool> isActive;
  final Value<bool> includeInNetWorth;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.institution = const Value.absent(),
    this.intermediaryId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.includeInNetWorth = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.institution = const Value.absent(),
    this.intermediaryId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.includeInNetWorth = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<String>? institution,
    Expression<int>? intermediaryId,
    Expression<bool>? isActive,
    Expression<bool>? includeInNetWorth,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (institution != null) 'institution': institution,
      if (intermediaryId != null) 'intermediary_id': intermediaryId,
      if (isActive != null) 'is_active': isActive,
      if (includeInNetWorth != null) 'include_in_net_worth': includeInNetWorth,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<AccountType>? type,
    Value<String>? currency,
    Value<String>? institution,
    Value<int?>? intermediaryId,
    Value<bool>? isActive,
    Value<bool>? includeInNetWorth,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      institution: institution ?? this.institution,
      intermediaryId: intermediaryId ?? this.intermediaryId,
      isActive: isActive ?? this.isActive,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AccountsTable.$convertertype.toSql(type.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (intermediaryId.present) {
      map['intermediary_id'] = Variable<int>(intermediaryId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (includeInNetWorth.present) {
      map['include_in_net_worth'] = Variable<bool>(includeInNetWorth.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('institution: $institution, ')
          ..write('intermediaryId: $intermediaryId, ')
          ..write('isActive: $isActive, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryType>($CategoriesTable.$convertertype);
  static const VerificationMeta _isEssentialMeta = const VerificationMeta(
    'isEssential',
  );
  @override
  late final GeneratedColumn<bool> isEssential = GeneratedColumn<bool>(
    'is_essential',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_essential" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseType?, String>
  defaultExpenseType = GeneratedColumn<String>(
    'default_expense_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ExpenseType?>($CategoriesTable.$converterdefaultExpenseTypen);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    isEssential,
    defaultExpenseType,
    icon,
    color,
    parentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_essential')) {
      context.handle(
        _isEssentialMeta,
        isEssential.isAcceptableOrUnknown(
          data['is_essential']!,
          _isEssentialMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $CategoriesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      isEssential: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_essential'],
      )!,
      defaultExpenseType: $CategoriesTable.$converterdefaultExpenseTypen
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}default_expense_type'],
            ),
          ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, String, String> $convertertype =
      const EnumNameConverter<CategoryType>(CategoryType.values);
  static JsonTypeConverter2<ExpenseType, String, String>
  $converterdefaultExpenseType = const EnumNameConverter<ExpenseType>(
    ExpenseType.values,
  );
  static JsonTypeConverter2<ExpenseType?, String?, String?>
  $converterdefaultExpenseTypen = JsonTypeConverter2.asNullable(
    $converterdefaultExpenseType,
  );
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final CategoryType type;
  final bool isEssential;
  final ExpenseType? defaultExpenseType;
  final String? icon;
  final String? color;
  final int? parentId;
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.isEssential,
    this.defaultExpenseType,
    this.icon,
    this.color,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>(
        $CategoriesTable.$convertertype.toSql(type),
      );
    }
    map['is_essential'] = Variable<bool>(isEssential);
    if (!nullToAbsent || defaultExpenseType != null) {
      map['default_expense_type'] = Variable<String>(
        $CategoriesTable.$converterdefaultExpenseTypen.toSql(
          defaultExpenseType,
        ),
      );
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      isEssential: Value(isEssential),
      defaultExpenseType: defaultExpenseType == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultExpenseType),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $CategoriesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      isEssential: serializer.fromJson<bool>(json['isEssential']),
      defaultExpenseType: $CategoriesTable.$converterdefaultExpenseTypen
          .fromJson(serializer.fromJson<String?>(json['defaultExpenseType'])),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      parentId: serializer.fromJson<int?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $CategoriesTable.$convertertype.toJson(type),
      ),
      'isEssential': serializer.toJson<bool>(isEssential),
      'defaultExpenseType': serializer.toJson<String?>(
        $CategoriesTable.$converterdefaultExpenseTypen.toJson(
          defaultExpenseType,
        ),
      ),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'parentId': serializer.toJson<int?>(parentId),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    CategoryType? type,
    bool? isEssential,
    Value<ExpenseType?> defaultExpenseType = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<int?> parentId = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    isEssential: isEssential ?? this.isEssential,
    defaultExpenseType: defaultExpenseType.present
        ? defaultExpenseType.value
        : this.defaultExpenseType,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      isEssential: data.isEssential.present
          ? data.isEssential.value
          : this.isEssential,
      defaultExpenseType: data.defaultExpenseType.present
          ? data.defaultExpenseType.value
          : this.defaultExpenseType,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('isEssential: $isEssential, ')
          ..write('defaultExpenseType: $defaultExpenseType, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    isEssential,
    defaultExpenseType,
    icon,
    color,
    parentId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.isEssential == this.isEssential &&
          other.defaultExpenseType == this.defaultExpenseType &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.parentId == this.parentId);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<CategoryType> type;
  final Value<bool> isEssential;
  final Value<ExpenseType?> defaultExpenseType;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<int?> parentId;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.isEssential = const Value.absent(),
    this.defaultExpenseType = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required CategoryType type,
    this.isEssential = const Value.absent(),
    this.defaultExpenseType = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.parentId = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<bool>? isEssential,
    Expression<String>? defaultExpenseType,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (isEssential != null) 'is_essential': isEssential,
      if (defaultExpenseType != null)
        'default_expense_type': defaultExpenseType,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<CategoryType>? type,
    Value<bool>? isEssential,
    Value<ExpenseType?>? defaultExpenseType,
    Value<String?>? icon,
    Value<String?>? color,
    Value<int?>? parentId,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isEssential: isEssential ?? this.isEssential,
      defaultExpenseType: defaultExpenseType ?? this.defaultExpenseType,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $CategoriesTable.$convertertype.toSql(type.value),
      );
    }
    if (isEssential.present) {
      map['is_essential'] = Variable<bool>(isEssential.value);
    }
    if (defaultExpenseType.present) {
      map['default_expense_type'] = Variable<String>(
        $CategoriesTable.$converterdefaultExpenseTypen.toSql(
          defaultExpenseType.value,
        ),
      );
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('isEssential: $isEssential, ')
          ..write('defaultExpenseType: $defaultExpenseType, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _operationDateMeta = const VerificationMeta(
    'operationDate',
  );
  @override
  late final GeneratedColumn<DateTime> operationDate =
      GeneratedColumn<DateTime>(
        'operation_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<DateTime> valueDate = GeneratedColumn<DateTime>(
    'value_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceAfterMeta = const VerificationMeta(
    'balanceAfter',
  );
  @override
  late final GeneratedColumn<double> balanceAfter = GeneratedColumn<double>(
    'balance_after',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionFullMeta = const VerificationMeta(
    'descriptionFull',
  );
  @override
  late final GeneratedColumn<String> descriptionFull = GeneratedColumn<String>(
    'description_full',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(TransactionStatus.settled.name),
  ).withConverter<TransactionStatus>($TransactionsTable.$converterstatus);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseType?, String>
  expenseType = GeneratedColumn<String>(
    'expense_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ExpenseType?>($TransactionsTable.$converterexpenseTypen);
  static const VerificationMeta _rawMetadataMeta = const VerificationMeta(
    'rawMetadata',
  );
  @override
  late final GeneratedColumn<String> rawMetadata = GeneratedColumn<String>(
    'raw_metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importHashMeta = const VerificationMeta(
    'importHash',
  );
  @override
  late final GeneratedColumn<String> importHash = GeneratedColumn<String>(
    'import_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    operationDate,
    valueDate,
    amount,
    balanceAfter,
    description,
    descriptionFull,
    status,
    categoryId,
    currency,
    tags,
    expenseType,
    rawMetadata,
    importHash,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('operation_date')) {
      context.handle(
        _operationDateMeta,
        operationDate.isAcceptableOrUnknown(
          data['operation_date']!,
          _operationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationDateMeta);
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_valueDateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('balance_after')) {
      context.handle(
        _balanceAfterMeta,
        balanceAfter.isAcceptableOrUnknown(
          data['balance_after']!,
          _balanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('description_full')) {
      context.handle(
        _descriptionFullMeta,
        descriptionFull.isAcceptableOrUnknown(
          data['description_full']!,
          _descriptionFullMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('raw_metadata')) {
      context.handle(
        _rawMetadataMeta,
        rawMetadata.isAcceptableOrUnknown(
          data['raw_metadata']!,
          _rawMetadataMeta,
        ),
      );
    }
    if (data.containsKey('import_hash')) {
      context.handle(
        _importHashMeta,
        importHash.isAcceptableOrUnknown(data['import_hash']!, _importHashMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      operationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}operation_date'],
      )!,
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}value_date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      balanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}balance_after'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      descriptionFull: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description_full'],
      ),
      status: $TransactionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      expenseType: $TransactionsTable.$converterexpenseTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}expense_type'],
        ),
      ),
      rawMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_metadata'],
      ),
      importHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_hash'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionStatus, String, String>
  $converterstatus = const EnumNameConverter<TransactionStatus>(
    TransactionStatus.values,
  );
  static JsonTypeConverter2<ExpenseType, String, String> $converterexpenseType =
      const EnumNameConverter<ExpenseType>(ExpenseType.values);
  static JsonTypeConverter2<ExpenseType?, String?, String?>
  $converterexpenseTypen = JsonTypeConverter2.asNullable($converterexpenseType);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final int accountId;
  final DateTime operationDate;
  final DateTime valueDate;
  final double amount;
  final double? balanceAfter;
  final String description;
  final String? descriptionFull;
  final TransactionStatus status;
  final int? categoryId;
  final String currency;
  final String tags;
  final ExpenseType? expenseType;
  final String? rawMetadata;
  final String? importHash;
  final DateTime createdAt;
  const Transaction({
    required this.id,
    required this.accountId,
    required this.operationDate,
    required this.valueDate,
    required this.amount,
    this.balanceAfter,
    required this.description,
    this.descriptionFull,
    required this.status,
    this.categoryId,
    required this.currency,
    required this.tags,
    this.expenseType,
    this.rawMetadata,
    this.importHash,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['operation_date'] = Variable<DateTime>(operationDate);
    map['value_date'] = Variable<DateTime>(valueDate);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || balanceAfter != null) {
      map['balance_after'] = Variable<double>(balanceAfter);
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || descriptionFull != null) {
      map['description_full'] = Variable<String>(descriptionFull);
    }
    {
      map['status'] = Variable<String>(
        $TransactionsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['currency'] = Variable<String>(currency);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || expenseType != null) {
      map['expense_type'] = Variable<String>(
        $TransactionsTable.$converterexpenseTypen.toSql(expenseType),
      );
    }
    if (!nullToAbsent || rawMetadata != null) {
      map['raw_metadata'] = Variable<String>(rawMetadata);
    }
    if (!nullToAbsent || importHash != null) {
      map['import_hash'] = Variable<String>(importHash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      operationDate: Value(operationDate),
      valueDate: Value(valueDate),
      amount: Value(amount),
      balanceAfter: balanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceAfter),
      description: Value(description),
      descriptionFull: descriptionFull == null && nullToAbsent
          ? const Value.absent()
          : Value(descriptionFull),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      currency: Value(currency),
      tags: Value(tags),
      expenseType: expenseType == null && nullToAbsent
          ? const Value.absent()
          : Value(expenseType),
      rawMetadata: rawMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(rawMetadata),
      importHash: importHash == null && nullToAbsent
          ? const Value.absent()
          : Value(importHash),
      createdAt: Value(createdAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      operationDate: serializer.fromJson<DateTime>(json['operationDate']),
      valueDate: serializer.fromJson<DateTime>(json['valueDate']),
      amount: serializer.fromJson<double>(json['amount']),
      balanceAfter: serializer.fromJson<double?>(json['balanceAfter']),
      description: serializer.fromJson<String>(json['description']),
      descriptionFull: serializer.fromJson<String?>(json['descriptionFull']),
      status: $TransactionsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      currency: serializer.fromJson<String>(json['currency']),
      tags: serializer.fromJson<String>(json['tags']),
      expenseType: $TransactionsTable.$converterexpenseTypen.fromJson(
        serializer.fromJson<String?>(json['expenseType']),
      ),
      rawMetadata: serializer.fromJson<String?>(json['rawMetadata']),
      importHash: serializer.fromJson<String?>(json['importHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'operationDate': serializer.toJson<DateTime>(operationDate),
      'valueDate': serializer.toJson<DateTime>(valueDate),
      'amount': serializer.toJson<double>(amount),
      'balanceAfter': serializer.toJson<double?>(balanceAfter),
      'description': serializer.toJson<String>(description),
      'descriptionFull': serializer.toJson<String?>(descriptionFull),
      'status': serializer.toJson<String>(
        $TransactionsTable.$converterstatus.toJson(status),
      ),
      'categoryId': serializer.toJson<int?>(categoryId),
      'currency': serializer.toJson<String>(currency),
      'tags': serializer.toJson<String>(tags),
      'expenseType': serializer.toJson<String?>(
        $TransactionsTable.$converterexpenseTypen.toJson(expenseType),
      ),
      'rawMetadata': serializer.toJson<String?>(rawMetadata),
      'importHash': serializer.toJson<String?>(importHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Transaction copyWith({
    int? id,
    int? accountId,
    DateTime? operationDate,
    DateTime? valueDate,
    double? amount,
    Value<double?> balanceAfter = const Value.absent(),
    String? description,
    Value<String?> descriptionFull = const Value.absent(),
    TransactionStatus? status,
    Value<int?> categoryId = const Value.absent(),
    String? currency,
    String? tags,
    Value<ExpenseType?> expenseType = const Value.absent(),
    Value<String?> rawMetadata = const Value.absent(),
    Value<String?> importHash = const Value.absent(),
    DateTime? createdAt,
  }) => Transaction(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    operationDate: operationDate ?? this.operationDate,
    valueDate: valueDate ?? this.valueDate,
    amount: amount ?? this.amount,
    balanceAfter: balanceAfter.present ? balanceAfter.value : this.balanceAfter,
    description: description ?? this.description,
    descriptionFull: descriptionFull.present
        ? descriptionFull.value
        : this.descriptionFull,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    currency: currency ?? this.currency,
    tags: tags ?? this.tags,
    expenseType: expenseType.present ? expenseType.value : this.expenseType,
    rawMetadata: rawMetadata.present ? rawMetadata.value : this.rawMetadata,
    importHash: importHash.present ? importHash.value : this.importHash,
    createdAt: createdAt ?? this.createdAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      operationDate: data.operationDate.present
          ? data.operationDate.value
          : this.operationDate,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      amount: data.amount.present ? data.amount.value : this.amount,
      balanceAfter: data.balanceAfter.present
          ? data.balanceAfter.value
          : this.balanceAfter,
      description: data.description.present
          ? data.description.value
          : this.description,
      descriptionFull: data.descriptionFull.present
          ? data.descriptionFull.value
          : this.descriptionFull,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      currency: data.currency.present ? data.currency.value : this.currency,
      tags: data.tags.present ? data.tags.value : this.tags,
      expenseType: data.expenseType.present
          ? data.expenseType.value
          : this.expenseType,
      rawMetadata: data.rawMetadata.present
          ? data.rawMetadata.value
          : this.rawMetadata,
      importHash: data.importHash.present
          ? data.importHash.value
          : this.importHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('operationDate: $operationDate, ')
          ..write('valueDate: $valueDate, ')
          ..write('amount: $amount, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('description: $description, ')
          ..write('descriptionFull: $descriptionFull, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('currency: $currency, ')
          ..write('tags: $tags, ')
          ..write('expenseType: $expenseType, ')
          ..write('rawMetadata: $rawMetadata, ')
          ..write('importHash: $importHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    operationDate,
    valueDate,
    amount,
    balanceAfter,
    description,
    descriptionFull,
    status,
    categoryId,
    currency,
    tags,
    expenseType,
    rawMetadata,
    importHash,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.operationDate == this.operationDate &&
          other.valueDate == this.valueDate &&
          other.amount == this.amount &&
          other.balanceAfter == this.balanceAfter &&
          other.description == this.description &&
          other.descriptionFull == this.descriptionFull &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.currency == this.currency &&
          other.tags == this.tags &&
          other.expenseType == this.expenseType &&
          other.rawMetadata == this.rawMetadata &&
          other.importHash == this.importHash &&
          other.createdAt == this.createdAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<DateTime> operationDate;
  final Value<DateTime> valueDate;
  final Value<double> amount;
  final Value<double?> balanceAfter;
  final Value<String> description;
  final Value<String?> descriptionFull;
  final Value<TransactionStatus> status;
  final Value<int?> categoryId;
  final Value<String> currency;
  final Value<String> tags;
  final Value<ExpenseType?> expenseType;
  final Value<String?> rawMetadata;
  final Value<String?> importHash;
  final Value<DateTime> createdAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.operationDate = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.amount = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.description = const Value.absent(),
    this.descriptionFull = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.currency = const Value.absent(),
    this.tags = const Value.absent(),
    this.expenseType = const Value.absent(),
    this.rawMetadata = const Value.absent(),
    this.importHash = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required DateTime operationDate,
    required DateTime valueDate,
    required double amount,
    this.balanceAfter = const Value.absent(),
    this.description = const Value.absent(),
    this.descriptionFull = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.currency = const Value.absent(),
    this.tags = const Value.absent(),
    this.expenseType = const Value.absent(),
    this.rawMetadata = const Value.absent(),
    this.importHash = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : accountId = Value(accountId),
       operationDate = Value(operationDate),
       valueDate = Value(valueDate),
       amount = Value(amount);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<DateTime>? operationDate,
    Expression<DateTime>? valueDate,
    Expression<double>? amount,
    Expression<double>? balanceAfter,
    Expression<String>? description,
    Expression<String>? descriptionFull,
    Expression<String>? status,
    Expression<int>? categoryId,
    Expression<String>? currency,
    Expression<String>? tags,
    Expression<String>? expenseType,
    Expression<String>? rawMetadata,
    Expression<String>? importHash,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (operationDate != null) 'operation_date': operationDate,
      if (valueDate != null) 'value_date': valueDate,
      if (amount != null) 'amount': amount,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (description != null) 'description': description,
      if (descriptionFull != null) 'description_full': descriptionFull,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (currency != null) 'currency': currency,
      if (tags != null) 'tags': tags,
      if (expenseType != null) 'expense_type': expenseType,
      if (rawMetadata != null) 'raw_metadata': rawMetadata,
      if (importHash != null) 'import_hash': importHash,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<DateTime>? operationDate,
    Value<DateTime>? valueDate,
    Value<double>? amount,
    Value<double?>? balanceAfter,
    Value<String>? description,
    Value<String?>? descriptionFull,
    Value<TransactionStatus>? status,
    Value<int?>? categoryId,
    Value<String>? currency,
    Value<String>? tags,
    Value<ExpenseType?>? expenseType,
    Value<String?>? rawMetadata,
    Value<String?>? importHash,
    Value<DateTime>? createdAt,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      operationDate: operationDate ?? this.operationDate,
      valueDate: valueDate ?? this.valueDate,
      amount: amount ?? this.amount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      descriptionFull: descriptionFull ?? this.descriptionFull,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      currency: currency ?? this.currency,
      tags: tags ?? this.tags,
      expenseType: expenseType ?? this.expenseType,
      rawMetadata: rawMetadata ?? this.rawMetadata,
      importHash: importHash ?? this.importHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (operationDate.present) {
      map['operation_date'] = Variable<DateTime>(operationDate.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<DateTime>(valueDate.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (balanceAfter.present) {
      map['balance_after'] = Variable<double>(balanceAfter.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (descriptionFull.present) {
      map['description_full'] = Variable<String>(descriptionFull.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TransactionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (expenseType.present) {
      map['expense_type'] = Variable<String>(
        $TransactionsTable.$converterexpenseTypen.toSql(expenseType.value),
      );
    }
    if (rawMetadata.present) {
      map['raw_metadata'] = Variable<String>(rawMetadata.value);
    }
    if (importHash.present) {
      map['import_hash'] = Variable<String>(importHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('operationDate: $operationDate, ')
          ..write('valueDate: $valueDate, ')
          ..write('amount: $amount, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('description: $description, ')
          ..write('descriptionFull: $descriptionFull, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('currency: $currency, ')
          ..write('tags: $tags, ')
          ..write('expenseType: $expenseType, ')
          ..write('rawMetadata: $rawMetadata, ')
          ..write('importHash: $importHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AutoCategorizationRulesTable extends AutoCategorizationRules
    with TableInfo<$AutoCategorizationRulesTable, AutoCategorizationRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AutoCategorizationRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pattern,
    categoryId,
    priority,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'auto_categorization_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<AutoCategorizationRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AutoCategorizationRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AutoCategorizationRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AutoCategorizationRulesTable createAlias(String alias) {
    return $AutoCategorizationRulesTable(attachedDatabase, alias);
  }
}

class AutoCategorizationRule extends DataClass
    implements Insertable<AutoCategorizationRule> {
  final int id;
  final String pattern;
  final int categoryId;
  final int priority;
  final bool isActive;
  final DateTime createdAt;
  const AutoCategorizationRule({
    required this.id,
    required this.pattern,
    required this.categoryId,
    required this.priority,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['pattern'] = Variable<String>(pattern);
    map['category_id'] = Variable<int>(categoryId);
    map['priority'] = Variable<int>(priority);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AutoCategorizationRulesCompanion toCompanion(bool nullToAbsent) {
    return AutoCategorizationRulesCompanion(
      id: Value(id),
      pattern: Value(pattern),
      categoryId: Value(categoryId),
      priority: Value(priority),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory AutoCategorizationRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AutoCategorizationRule(
      id: serializer.fromJson<int>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      priority: serializer.fromJson<int>(json['priority']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pattern': serializer.toJson<String>(pattern),
      'categoryId': serializer.toJson<int>(categoryId),
      'priority': serializer.toJson<int>(priority),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AutoCategorizationRule copyWith({
    int? id,
    String? pattern,
    int? categoryId,
    int? priority,
    bool? isActive,
    DateTime? createdAt,
  }) => AutoCategorizationRule(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    categoryId: categoryId ?? this.categoryId,
    priority: priority ?? this.priority,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  AutoCategorizationRule copyWithCompanion(
    AutoCategorizationRulesCompanion data,
  ) {
    return AutoCategorizationRule(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      priority: data.priority.present ? data.priority.value : this.priority,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AutoCategorizationRule(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, pattern, categoryId, priority, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutoCategorizationRule &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.categoryId == this.categoryId &&
          other.priority == this.priority &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class AutoCategorizationRulesCompanion
    extends UpdateCompanion<AutoCategorizationRule> {
  final Value<int> id;
  final Value<String> pattern;
  final Value<int> categoryId;
  final Value<int> priority;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const AutoCategorizationRulesCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.priority = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AutoCategorizationRulesCompanion.insert({
    this.id = const Value.absent(),
    required String pattern,
    required int categoryId,
    this.priority = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : pattern = Value(pattern),
       categoryId = Value(categoryId);
  static Insertable<AutoCategorizationRule> custom({
    Expression<int>? id,
    Expression<String>? pattern,
    Expression<int>? categoryId,
    Expression<int>? priority,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (categoryId != null) 'category_id': categoryId,
      if (priority != null) 'priority': priority,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AutoCategorizationRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? pattern,
    Value<int>? categoryId,
    Value<int>? priority,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return AutoCategorizationRulesCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AutoCategorizationRulesCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AssetsTable extends Assets with TableInfo<$AssetsTable, Asset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isinMeta = const VerificationMeta('isin');
  @override
  late final GeneratedColumn<String> isin = GeneratedColumn<String>(
    'isin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AssetType, String> assetType =
      GeneratedColumn<String>(
        'asset_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AssetType>($AssetsTable.$converterassetType);
  @override
  late final GeneratedColumnWithTypeConverter<InstrumentType, String>
  instrumentType = GeneratedColumn<String>(
    'instrument_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(InstrumentType.etf.name),
  ).withConverter<InstrumentType>($AssetsTable.$converterinstrumentType);
  @override
  late final GeneratedColumnWithTypeConverter<AssetClass, String> assetClass =
      GeneratedColumn<String>(
        'asset_class',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(AssetClass.equity.name),
      ).withConverter<AssetClass>($AssetsTable.$converterassetClass);
  static const VerificationMeta _intermediaryIdMeta = const VerificationMeta(
    'intermediaryId',
  );
  @override
  late final GeneratedColumn<int> intermediaryId = GeneratedColumn<int>(
    'intermediary_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES intermediaries (id)',
    ),
  );
  static const VerificationMeta _assetGroupMeta = const VerificationMeta(
    'assetGroup',
  );
  @override
  late final GeneratedColumn<String> assetGroup = GeneratedColumn<String>(
    'asset_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _exchangeMeta = const VerificationMeta(
    'exchange',
  );
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
    'exchange',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yahooTickerMeta = const VerificationMeta(
    'yahooTicker',
  );
  @override
  late final GeneratedColumn<String> yahooTicker = GeneratedColumn<String>(
    'yahoo_ticker',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectorMeta = const VerificationMeta('sector');
  @override
  late final GeneratedColumn<String> sector = GeneratedColumn<String>(
    'sector',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _terMeta = const VerificationMeta('ter');
  @override
  late final GeneratedColumn<double> ter = GeneratedColumn<double>(
    'ter',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxRateMeta = const VerificationMeta(
    'taxRate',
  );
  @override
  late final GeneratedColumn<double> taxRate = GeneratedColumn<double>(
    'tax_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ValuationMethod, String>
  valuationMethod = GeneratedColumn<String>(
    'valuation_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ValuationMethod>($AssetsTable.$convertervaluationMethod);
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _includeInNetWorthMeta = const VerificationMeta(
    'includeInNetWorth',
  );
  @override
  late final GeneratedColumn<bool> includeInNetWorth = GeneratedColumn<bool>(
    'include_in_net_worth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_net_worth" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ticker,
    isin,
    assetType,
    instrumentType,
    assetClass,
    intermediaryId,
    assetGroup,
    currency,
    exchange,
    yahooTicker,
    country,
    region,
    sector,
    ter,
    taxRate,
    valuationMethod,
    isActive,
    includeInNetWorth,
    sortOrder,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Asset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    }
    if (data.containsKey('isin')) {
      context.handle(
        _isinMeta,
        isin.isAcceptableOrUnknown(data['isin']!, _isinMeta),
      );
    }
    if (data.containsKey('intermediary_id')) {
      context.handle(
        _intermediaryIdMeta,
        intermediaryId.isAcceptableOrUnknown(
          data['intermediary_id']!,
          _intermediaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intermediaryIdMeta);
    }
    if (data.containsKey('asset_group')) {
      context.handle(
        _assetGroupMeta,
        assetGroup.isAcceptableOrUnknown(data['asset_group']!, _assetGroupMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('exchange')) {
      context.handle(
        _exchangeMeta,
        exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta),
      );
    }
    if (data.containsKey('yahoo_ticker')) {
      context.handle(
        _yahooTickerMeta,
        yahooTicker.isAcceptableOrUnknown(
          data['yahoo_ticker']!,
          _yahooTickerMeta,
        ),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('sector')) {
      context.handle(
        _sectorMeta,
        sector.isAcceptableOrUnknown(data['sector']!, _sectorMeta),
      );
    }
    if (data.containsKey('ter')) {
      context.handle(
        _terMeta,
        ter.isAcceptableOrUnknown(data['ter']!, _terMeta),
      );
    }
    if (data.containsKey('tax_rate')) {
      context.handle(
        _taxRateMeta,
        taxRate.isAcceptableOrUnknown(data['tax_rate']!, _taxRateMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('include_in_net_worth')) {
      context.handle(
        _includeInNetWorthMeta,
        includeInNetWorth.isAcceptableOrUnknown(
          data['include_in_net_worth']!,
          _includeInNetWorthMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Asset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Asset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      ),
      isin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isin'],
      ),
      assetType: $AssetsTable.$converterassetType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}asset_type'],
        )!,
      ),
      instrumentType: $AssetsTable.$converterinstrumentType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}instrument_type'],
        )!,
      ),
      assetClass: $AssetsTable.$converterassetClass.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}asset_class'],
        )!,
      ),
      intermediaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intermediary_id'],
      )!,
      assetGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_group'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      exchange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange'],
      ),
      yahooTicker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}yahoo_ticker'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      sector: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sector'],
      ),
      ter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ter'],
      ),
      taxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_rate'],
      ),
      valuationMethod: $AssetsTable.$convertervaluationMethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}valuation_method'],
        )!,
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      includeInNetWorth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_net_worth'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AssetType, String, String> $converterassetType =
      const EnumNameConverter<AssetType>(AssetType.values);
  static JsonTypeConverter2<InstrumentType, String, String>
  $converterinstrumentType = const EnumNameConverter<InstrumentType>(
    InstrumentType.values,
  );
  static JsonTypeConverter2<AssetClass, String, String> $converterassetClass =
      const EnumNameConverter<AssetClass>(AssetClass.values);
  static JsonTypeConverter2<ValuationMethod, String, String>
  $convertervaluationMethod = const EnumNameConverter<ValuationMethod>(
    ValuationMethod.values,
  );
}

class Asset extends DataClass implements Insertable<Asset> {
  final int id;
  final String name;
  final String? ticker;
  final String? isin;
  final AssetType assetType;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final int intermediaryId;
  final String assetGroup;
  final String currency;
  final String? exchange;
  final String? yahooTicker;
  final String? country;
  final String? region;
  final String? sector;
  final double? ter;
  final double? taxRate;
  final ValuationMethod valuationMethod;
  final bool isActive;
  final bool includeInNetWorth;
  final int sortOrder;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Asset({
    required this.id,
    required this.name,
    this.ticker,
    this.isin,
    required this.assetType,
    required this.instrumentType,
    required this.assetClass,
    required this.intermediaryId,
    required this.assetGroup,
    required this.currency,
    this.exchange,
    this.yahooTicker,
    this.country,
    this.region,
    this.sector,
    this.ter,
    this.taxRate,
    required this.valuationMethod,
    required this.isActive,
    required this.includeInNetWorth,
    required this.sortOrder,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || ticker != null) {
      map['ticker'] = Variable<String>(ticker);
    }
    if (!nullToAbsent || isin != null) {
      map['isin'] = Variable<String>(isin);
    }
    {
      map['asset_type'] = Variable<String>(
        $AssetsTable.$converterassetType.toSql(assetType),
      );
    }
    {
      map['instrument_type'] = Variable<String>(
        $AssetsTable.$converterinstrumentType.toSql(instrumentType),
      );
    }
    {
      map['asset_class'] = Variable<String>(
        $AssetsTable.$converterassetClass.toSql(assetClass),
      );
    }
    map['intermediary_id'] = Variable<int>(intermediaryId);
    map['asset_group'] = Variable<String>(assetGroup);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || exchange != null) {
      map['exchange'] = Variable<String>(exchange);
    }
    if (!nullToAbsent || yahooTicker != null) {
      map['yahoo_ticker'] = Variable<String>(yahooTicker);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || sector != null) {
      map['sector'] = Variable<String>(sector);
    }
    if (!nullToAbsent || ter != null) {
      map['ter'] = Variable<double>(ter);
    }
    if (!nullToAbsent || taxRate != null) {
      map['tax_rate'] = Variable<double>(taxRate);
    }
    {
      map['valuation_method'] = Variable<String>(
        $AssetsTable.$convertervaluationMethod.toSql(valuationMethod),
      );
    }
    map['is_active'] = Variable<bool>(isActive);
    map['include_in_net_worth'] = Variable<bool>(includeInNetWorth);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      name: Value(name),
      ticker: ticker == null && nullToAbsent
          ? const Value.absent()
          : Value(ticker),
      isin: isin == null && nullToAbsent ? const Value.absent() : Value(isin),
      assetType: Value(assetType),
      instrumentType: Value(instrumentType),
      assetClass: Value(assetClass),
      intermediaryId: Value(intermediaryId),
      assetGroup: Value(assetGroup),
      currency: Value(currency),
      exchange: exchange == null && nullToAbsent
          ? const Value.absent()
          : Value(exchange),
      yahooTicker: yahooTicker == null && nullToAbsent
          ? const Value.absent()
          : Value(yahooTicker),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      sector: sector == null && nullToAbsent
          ? const Value.absent()
          : Value(sector),
      ter: ter == null && nullToAbsent ? const Value.absent() : Value(ter),
      taxRate: taxRate == null && nullToAbsent
          ? const Value.absent()
          : Value(taxRate),
      valuationMethod: Value(valuationMethod),
      isActive: Value(isActive),
      includeInNetWorth: Value(includeInNetWorth),
      sortOrder: Value(sortOrder),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Asset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Asset(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ticker: serializer.fromJson<String?>(json['ticker']),
      isin: serializer.fromJson<String?>(json['isin']),
      assetType: $AssetsTable.$converterassetType.fromJson(
        serializer.fromJson<String>(json['assetType']),
      ),
      instrumentType: $AssetsTable.$converterinstrumentType.fromJson(
        serializer.fromJson<String>(json['instrumentType']),
      ),
      assetClass: $AssetsTable.$converterassetClass.fromJson(
        serializer.fromJson<String>(json['assetClass']),
      ),
      intermediaryId: serializer.fromJson<int>(json['intermediaryId']),
      assetGroup: serializer.fromJson<String>(json['assetGroup']),
      currency: serializer.fromJson<String>(json['currency']),
      exchange: serializer.fromJson<String?>(json['exchange']),
      yahooTicker: serializer.fromJson<String?>(json['yahooTicker']),
      country: serializer.fromJson<String?>(json['country']),
      region: serializer.fromJson<String?>(json['region']),
      sector: serializer.fromJson<String?>(json['sector']),
      ter: serializer.fromJson<double?>(json['ter']),
      taxRate: serializer.fromJson<double?>(json['taxRate']),
      valuationMethod: $AssetsTable.$convertervaluationMethod.fromJson(
        serializer.fromJson<String>(json['valuationMethod']),
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
      includeInNetWorth: serializer.fromJson<bool>(json['includeInNetWorth']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'ticker': serializer.toJson<String?>(ticker),
      'isin': serializer.toJson<String?>(isin),
      'assetType': serializer.toJson<String>(
        $AssetsTable.$converterassetType.toJson(assetType),
      ),
      'instrumentType': serializer.toJson<String>(
        $AssetsTable.$converterinstrumentType.toJson(instrumentType),
      ),
      'assetClass': serializer.toJson<String>(
        $AssetsTable.$converterassetClass.toJson(assetClass),
      ),
      'intermediaryId': serializer.toJson<int>(intermediaryId),
      'assetGroup': serializer.toJson<String>(assetGroup),
      'currency': serializer.toJson<String>(currency),
      'exchange': serializer.toJson<String?>(exchange),
      'yahooTicker': serializer.toJson<String?>(yahooTicker),
      'country': serializer.toJson<String?>(country),
      'region': serializer.toJson<String?>(region),
      'sector': serializer.toJson<String?>(sector),
      'ter': serializer.toJson<double?>(ter),
      'taxRate': serializer.toJson<double?>(taxRate),
      'valuationMethod': serializer.toJson<String>(
        $AssetsTable.$convertervaluationMethod.toJson(valuationMethod),
      ),
      'isActive': serializer.toJson<bool>(isActive),
      'includeInNetWorth': serializer.toJson<bool>(includeInNetWorth),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Asset copyWith({
    int? id,
    String? name,
    Value<String?> ticker = const Value.absent(),
    Value<String?> isin = const Value.absent(),
    AssetType? assetType,
    InstrumentType? instrumentType,
    AssetClass? assetClass,
    int? intermediaryId,
    String? assetGroup,
    String? currency,
    Value<String?> exchange = const Value.absent(),
    Value<String?> yahooTicker = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<String?> region = const Value.absent(),
    Value<String?> sector = const Value.absent(),
    Value<double?> ter = const Value.absent(),
    Value<double?> taxRate = const Value.absent(),
    ValuationMethod? valuationMethod,
    bool? isActive,
    bool? includeInNetWorth,
    int? sortOrder,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Asset(
    id: id ?? this.id,
    name: name ?? this.name,
    ticker: ticker.present ? ticker.value : this.ticker,
    isin: isin.present ? isin.value : this.isin,
    assetType: assetType ?? this.assetType,
    instrumentType: instrumentType ?? this.instrumentType,
    assetClass: assetClass ?? this.assetClass,
    intermediaryId: intermediaryId ?? this.intermediaryId,
    assetGroup: assetGroup ?? this.assetGroup,
    currency: currency ?? this.currency,
    exchange: exchange.present ? exchange.value : this.exchange,
    yahooTicker: yahooTicker.present ? yahooTicker.value : this.yahooTicker,
    country: country.present ? country.value : this.country,
    region: region.present ? region.value : this.region,
    sector: sector.present ? sector.value : this.sector,
    ter: ter.present ? ter.value : this.ter,
    taxRate: taxRate.present ? taxRate.value : this.taxRate,
    valuationMethod: valuationMethod ?? this.valuationMethod,
    isActive: isActive ?? this.isActive,
    includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
    sortOrder: sortOrder ?? this.sortOrder,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Asset copyWithCompanion(AssetsCompanion data) {
    return Asset(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      isin: data.isin.present ? data.isin.value : this.isin,
      assetType: data.assetType.present ? data.assetType.value : this.assetType,
      instrumentType: data.instrumentType.present
          ? data.instrumentType.value
          : this.instrumentType,
      assetClass: data.assetClass.present
          ? data.assetClass.value
          : this.assetClass,
      intermediaryId: data.intermediaryId.present
          ? data.intermediaryId.value
          : this.intermediaryId,
      assetGroup: data.assetGroup.present
          ? data.assetGroup.value
          : this.assetGroup,
      currency: data.currency.present ? data.currency.value : this.currency,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      yahooTicker: data.yahooTicker.present
          ? data.yahooTicker.value
          : this.yahooTicker,
      country: data.country.present ? data.country.value : this.country,
      region: data.region.present ? data.region.value : this.region,
      sector: data.sector.present ? data.sector.value : this.sector,
      ter: data.ter.present ? data.ter.value : this.ter,
      taxRate: data.taxRate.present ? data.taxRate.value : this.taxRate,
      valuationMethod: data.valuationMethod.present
          ? data.valuationMethod.value
          : this.valuationMethod,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      includeInNetWorth: data.includeInNetWorth.present
          ? data.includeInNetWorth.value
          : this.includeInNetWorth,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Asset(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ticker: $ticker, ')
          ..write('isin: $isin, ')
          ..write('assetType: $assetType, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('intermediaryId: $intermediaryId, ')
          ..write('assetGroup: $assetGroup, ')
          ..write('currency: $currency, ')
          ..write('exchange: $exchange, ')
          ..write('yahooTicker: $yahooTicker, ')
          ..write('country: $country, ')
          ..write('region: $region, ')
          ..write('sector: $sector, ')
          ..write('ter: $ter, ')
          ..write('taxRate: $taxRate, ')
          ..write('valuationMethod: $valuationMethod, ')
          ..write('isActive: $isActive, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    ticker,
    isin,
    assetType,
    instrumentType,
    assetClass,
    intermediaryId,
    assetGroup,
    currency,
    exchange,
    yahooTicker,
    country,
    region,
    sector,
    ter,
    taxRate,
    valuationMethod,
    isActive,
    includeInNetWorth,
    sortOrder,
    notes,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Asset &&
          other.id == this.id &&
          other.name == this.name &&
          other.ticker == this.ticker &&
          other.isin == this.isin &&
          other.assetType == this.assetType &&
          other.instrumentType == this.instrumentType &&
          other.assetClass == this.assetClass &&
          other.intermediaryId == this.intermediaryId &&
          other.assetGroup == this.assetGroup &&
          other.currency == this.currency &&
          other.exchange == this.exchange &&
          other.yahooTicker == this.yahooTicker &&
          other.country == this.country &&
          other.region == this.region &&
          other.sector == this.sector &&
          other.ter == this.ter &&
          other.taxRate == this.taxRate &&
          other.valuationMethod == this.valuationMethod &&
          other.isActive == this.isActive &&
          other.includeInNetWorth == this.includeInNetWorth &&
          other.sortOrder == this.sortOrder &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AssetsCompanion extends UpdateCompanion<Asset> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> ticker;
  final Value<String?> isin;
  final Value<AssetType> assetType;
  final Value<InstrumentType> instrumentType;
  final Value<AssetClass> assetClass;
  final Value<int> intermediaryId;
  final Value<String> assetGroup;
  final Value<String> currency;
  final Value<String?> exchange;
  final Value<String?> yahooTicker;
  final Value<String?> country;
  final Value<String?> region;
  final Value<String?> sector;
  final Value<double?> ter;
  final Value<double?> taxRate;
  final Value<ValuationMethod> valuationMethod;
  final Value<bool> isActive;
  final Value<bool> includeInNetWorth;
  final Value<int> sortOrder;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ticker = const Value.absent(),
    this.isin = const Value.absent(),
    this.assetType = const Value.absent(),
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    this.intermediaryId = const Value.absent(),
    this.assetGroup = const Value.absent(),
    this.currency = const Value.absent(),
    this.exchange = const Value.absent(),
    this.yahooTicker = const Value.absent(),
    this.country = const Value.absent(),
    this.region = const Value.absent(),
    this.sector = const Value.absent(),
    this.ter = const Value.absent(),
    this.taxRate = const Value.absent(),
    this.valuationMethod = const Value.absent(),
    this.isActive = const Value.absent(),
    this.includeInNetWorth = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AssetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.ticker = const Value.absent(),
    this.isin = const Value.absent(),
    required AssetType assetType,
    this.instrumentType = const Value.absent(),
    this.assetClass = const Value.absent(),
    required int intermediaryId,
    this.assetGroup = const Value.absent(),
    this.currency = const Value.absent(),
    this.exchange = const Value.absent(),
    this.yahooTicker = const Value.absent(),
    this.country = const Value.absent(),
    this.region = const Value.absent(),
    this.sector = const Value.absent(),
    this.ter = const Value.absent(),
    this.taxRate = const Value.absent(),
    required ValuationMethod valuationMethod,
    this.isActive = const Value.absent(),
    this.includeInNetWorth = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       assetType = Value(assetType),
       intermediaryId = Value(intermediaryId),
       valuationMethod = Value(valuationMethod);
  static Insertable<Asset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? ticker,
    Expression<String>? isin,
    Expression<String>? assetType,
    Expression<String>? instrumentType,
    Expression<String>? assetClass,
    Expression<int>? intermediaryId,
    Expression<String>? assetGroup,
    Expression<String>? currency,
    Expression<String>? exchange,
    Expression<String>? yahooTicker,
    Expression<String>? country,
    Expression<String>? region,
    Expression<String>? sector,
    Expression<double>? ter,
    Expression<double>? taxRate,
    Expression<String>? valuationMethod,
    Expression<bool>? isActive,
    Expression<bool>? includeInNetWorth,
    Expression<int>? sortOrder,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ticker != null) 'ticker': ticker,
      if (isin != null) 'isin': isin,
      if (assetType != null) 'asset_type': assetType,
      if (instrumentType != null) 'instrument_type': instrumentType,
      if (assetClass != null) 'asset_class': assetClass,
      if (intermediaryId != null) 'intermediary_id': intermediaryId,
      if (assetGroup != null) 'asset_group': assetGroup,
      if (currency != null) 'currency': currency,
      if (exchange != null) 'exchange': exchange,
      if (yahooTicker != null) 'yahoo_ticker': yahooTicker,
      if (country != null) 'country': country,
      if (region != null) 'region': region,
      if (sector != null) 'sector': sector,
      if (ter != null) 'ter': ter,
      if (taxRate != null) 'tax_rate': taxRate,
      if (valuationMethod != null) 'valuation_method': valuationMethod,
      if (isActive != null) 'is_active': isActive,
      if (includeInNetWorth != null) 'include_in_net_worth': includeInNetWorth,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AssetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? ticker,
    Value<String?>? isin,
    Value<AssetType>? assetType,
    Value<InstrumentType>? instrumentType,
    Value<AssetClass>? assetClass,
    Value<int>? intermediaryId,
    Value<String>? assetGroup,
    Value<String>? currency,
    Value<String?>? exchange,
    Value<String?>? yahooTicker,
    Value<String?>? country,
    Value<String?>? region,
    Value<String?>? sector,
    Value<double?>? ter,
    Value<double?>? taxRate,
    Value<ValuationMethod>? valuationMethod,
    Value<bool>? isActive,
    Value<bool>? includeInNetWorth,
    Value<int>? sortOrder,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AssetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      isin: isin ?? this.isin,
      assetType: assetType ?? this.assetType,
      instrumentType: instrumentType ?? this.instrumentType,
      assetClass: assetClass ?? this.assetClass,
      intermediaryId: intermediaryId ?? this.intermediaryId,
      assetGroup: assetGroup ?? this.assetGroup,
      currency: currency ?? this.currency,
      exchange: exchange ?? this.exchange,
      yahooTicker: yahooTicker ?? this.yahooTicker,
      country: country ?? this.country,
      region: region ?? this.region,
      sector: sector ?? this.sector,
      ter: ter ?? this.ter,
      taxRate: taxRate ?? this.taxRate,
      valuationMethod: valuationMethod ?? this.valuationMethod,
      isActive: isActive ?? this.isActive,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (isin.present) {
      map['isin'] = Variable<String>(isin.value);
    }
    if (assetType.present) {
      map['asset_type'] = Variable<String>(
        $AssetsTable.$converterassetType.toSql(assetType.value),
      );
    }
    if (instrumentType.present) {
      map['instrument_type'] = Variable<String>(
        $AssetsTable.$converterinstrumentType.toSql(instrumentType.value),
      );
    }
    if (assetClass.present) {
      map['asset_class'] = Variable<String>(
        $AssetsTable.$converterassetClass.toSql(assetClass.value),
      );
    }
    if (intermediaryId.present) {
      map['intermediary_id'] = Variable<int>(intermediaryId.value);
    }
    if (assetGroup.present) {
      map['asset_group'] = Variable<String>(assetGroup.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (yahooTicker.present) {
      map['yahoo_ticker'] = Variable<String>(yahooTicker.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (sector.present) {
      map['sector'] = Variable<String>(sector.value);
    }
    if (ter.present) {
      map['ter'] = Variable<double>(ter.value);
    }
    if (taxRate.present) {
      map['tax_rate'] = Variable<double>(taxRate.value);
    }
    if (valuationMethod.present) {
      map['valuation_method'] = Variable<String>(
        $AssetsTable.$convertervaluationMethod.toSql(valuationMethod.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (includeInNetWorth.present) {
      map['include_in_net_worth'] = Variable<bool>(includeInNetWorth.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ticker: $ticker, ')
          ..write('isin: $isin, ')
          ..write('assetType: $assetType, ')
          ..write('instrumentType: $instrumentType, ')
          ..write('assetClass: $assetClass, ')
          ..write('intermediaryId: $intermediaryId, ')
          ..write('assetGroup: $assetGroup, ')
          ..write('currency: $currency, ')
          ..write('exchange: $exchange, ')
          ..write('yahooTicker: $yahooTicker, ')
          ..write('country: $country, ')
          ..write('region: $region, ')
          ..write('sector: $sector, ')
          ..write('ter: $ter, ')
          ..write('taxRate: $taxRate, ')
          ..write('valuationMethod: $valuationMethod, ')
          ..write('isActive: $isActive, ')
          ..write('includeInNetWorth: $includeInNetWorth, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AssetEventsTable extends AssetEvents
    with TableInfo<$AssetEventsTable, AssetEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assets (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<DateTime> valueDate = GeneratedColumn<DateTime>(
    'value_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventType>($AssetEventsTable.$convertertype);
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _exchangeRateMeta = const VerificationMeta(
    'exchangeRate',
  );
  @override
  late final GeneratedColumn<double> exchangeRate = GeneratedColumn<double>(
    'exchange_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commissionMeta = const VerificationMeta(
    'commission',
  );
  @override
  late final GeneratedColumn<double> commission = GeneratedColumn<double>(
    'commission',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxWithheldMeta = const VerificationMeta(
    'taxWithheld',
  );
  @override
  late final GeneratedColumn<double> taxWithheld = GeneratedColumn<double>(
    'tax_withheld',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawMetadataMeta = const VerificationMeta(
    'rawMetadata',
  );
  @override
  late final GeneratedColumn<String> rawMetadata = GeneratedColumn<String>(
    'raw_metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importHashMeta = const VerificationMeta(
    'importHash',
  );
  @override
  late final GeneratedColumn<String> importHash = GeneratedColumn<String>(
    'import_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    date,
    valueDate,
    type,
    quantity,
    price,
    amount,
    currency,
    exchangeRate,
    commission,
    taxWithheld,
    source,
    notes,
    rawMetadata,
    importHash,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_valueDateMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('exchange_rate')) {
      context.handle(
        _exchangeRateMeta,
        exchangeRate.isAcceptableOrUnknown(
          data['exchange_rate']!,
          _exchangeRateMeta,
        ),
      );
    }
    if (data.containsKey('commission')) {
      context.handle(
        _commissionMeta,
        commission.isAcceptableOrUnknown(data['commission']!, _commissionMeta),
      );
    }
    if (data.containsKey('tax_withheld')) {
      context.handle(
        _taxWithheldMeta,
        taxWithheld.isAcceptableOrUnknown(
          data['tax_withheld']!,
          _taxWithheldMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('raw_metadata')) {
      context.handle(
        _rawMetadataMeta,
        rawMetadata.isAcceptableOrUnknown(
          data['raw_metadata']!,
          _rawMetadataMeta,
        ),
      );
    }
    if (data.containsKey('import_hash')) {
      context.handle(
        _importHashMeta,
        importHash.isAcceptableOrUnknown(data['import_hash']!, _importHashMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asset_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}value_date'],
      )!,
      type: $AssetEventsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      exchangeRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exchange_rate'],
      ),
      commission: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}commission'],
      ),
      taxWithheld: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_withheld'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      rawMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_metadata'],
      ),
      importHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_hash'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AssetEventsTable createAlias(String alias) {
    return $AssetEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventType, String, String> $convertertype =
      const EnumNameConverter<EventType>(EventType.values);
}

class AssetEvent extends DataClass implements Insertable<AssetEvent> {
  final int id;
  final int assetId;
  final DateTime date;
  final DateTime valueDate;
  final EventType type;
  final double? quantity;
  final double? price;
  final double amount;
  final String currency;
  final double? exchangeRate;
  final double? commission;
  final double? taxWithheld;
  final String? source;
  final String? notes;
  final String? rawMetadata;
  final String? importHash;
  final DateTime createdAt;
  const AssetEvent({
    required this.id,
    required this.assetId,
    required this.date,
    required this.valueDate,
    required this.type,
    this.quantity,
    this.price,
    required this.amount,
    required this.currency,
    this.exchangeRate,
    this.commission,
    this.taxWithheld,
    this.source,
    this.notes,
    this.rawMetadata,
    this.importHash,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<int>(assetId);
    map['date'] = Variable<DateTime>(date);
    map['value_date'] = Variable<DateTime>(valueDate);
    {
      map['type'] = Variable<String>(
        $AssetEventsTable.$convertertype.toSql(type),
      );
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || exchangeRate != null) {
      map['exchange_rate'] = Variable<double>(exchangeRate);
    }
    if (!nullToAbsent || commission != null) {
      map['commission'] = Variable<double>(commission);
    }
    if (!nullToAbsent || taxWithheld != null) {
      map['tax_withheld'] = Variable<double>(taxWithheld);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || rawMetadata != null) {
      map['raw_metadata'] = Variable<String>(rawMetadata);
    }
    if (!nullToAbsent || importHash != null) {
      map['import_hash'] = Variable<String>(importHash);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssetEventsCompanion toCompanion(bool nullToAbsent) {
    return AssetEventsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      date: Value(date),
      valueDate: Value(valueDate),
      type: Value(type),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      amount: Value(amount),
      currency: Value(currency),
      exchangeRate: exchangeRate == null && nullToAbsent
          ? const Value.absent()
          : Value(exchangeRate),
      commission: commission == null && nullToAbsent
          ? const Value.absent()
          : Value(commission),
      taxWithheld: taxWithheld == null && nullToAbsent
          ? const Value.absent()
          : Value(taxWithheld),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      rawMetadata: rawMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(rawMetadata),
      importHash: importHash == null && nullToAbsent
          ? const Value.absent()
          : Value(importHash),
      createdAt: Value(createdAt),
    );
  }

  factory AssetEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetEvent(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<int>(json['assetId']),
      date: serializer.fromJson<DateTime>(json['date']),
      valueDate: serializer.fromJson<DateTime>(json['valueDate']),
      type: $AssetEventsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      quantity: serializer.fromJson<double?>(json['quantity']),
      price: serializer.fromJson<double?>(json['price']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      exchangeRate: serializer.fromJson<double?>(json['exchangeRate']),
      commission: serializer.fromJson<double?>(json['commission']),
      taxWithheld: serializer.fromJson<double?>(json['taxWithheld']),
      source: serializer.fromJson<String?>(json['source']),
      notes: serializer.fromJson<String?>(json['notes']),
      rawMetadata: serializer.fromJson<String?>(json['rawMetadata']),
      importHash: serializer.fromJson<String?>(json['importHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<int>(assetId),
      'date': serializer.toJson<DateTime>(date),
      'valueDate': serializer.toJson<DateTime>(valueDate),
      'type': serializer.toJson<String>(
        $AssetEventsTable.$convertertype.toJson(type),
      ),
      'quantity': serializer.toJson<double?>(quantity),
      'price': serializer.toJson<double?>(price),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'exchangeRate': serializer.toJson<double?>(exchangeRate),
      'commission': serializer.toJson<double?>(commission),
      'taxWithheld': serializer.toJson<double?>(taxWithheld),
      'source': serializer.toJson<String?>(source),
      'notes': serializer.toJson<String?>(notes),
      'rawMetadata': serializer.toJson<String?>(rawMetadata),
      'importHash': serializer.toJson<String?>(importHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AssetEvent copyWith({
    int? id,
    int? assetId,
    DateTime? date,
    DateTime? valueDate,
    EventType? type,
    Value<double?> quantity = const Value.absent(),
    Value<double?> price = const Value.absent(),
    double? amount,
    String? currency,
    Value<double?> exchangeRate = const Value.absent(),
    Value<double?> commission = const Value.absent(),
    Value<double?> taxWithheld = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> rawMetadata = const Value.absent(),
    Value<String?> importHash = const Value.absent(),
    DateTime? createdAt,
  }) => AssetEvent(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    date: date ?? this.date,
    valueDate: valueDate ?? this.valueDate,
    type: type ?? this.type,
    quantity: quantity.present ? quantity.value : this.quantity,
    price: price.present ? price.value : this.price,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    exchangeRate: exchangeRate.present ? exchangeRate.value : this.exchangeRate,
    commission: commission.present ? commission.value : this.commission,
    taxWithheld: taxWithheld.present ? taxWithheld.value : this.taxWithheld,
    source: source.present ? source.value : this.source,
    notes: notes.present ? notes.value : this.notes,
    rawMetadata: rawMetadata.present ? rawMetadata.value : this.rawMetadata,
    importHash: importHash.present ? importHash.value : this.importHash,
    createdAt: createdAt ?? this.createdAt,
  );
  AssetEvent copyWithCompanion(AssetEventsCompanion data) {
    return AssetEvent(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      date: data.date.present ? data.date.value : this.date,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      type: data.type.present ? data.type.value : this.type,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      exchangeRate: data.exchangeRate.present
          ? data.exchangeRate.value
          : this.exchangeRate,
      commission: data.commission.present
          ? data.commission.value
          : this.commission,
      taxWithheld: data.taxWithheld.present
          ? data.taxWithheld.value
          : this.taxWithheld,
      source: data.source.present ? data.source.value : this.source,
      notes: data.notes.present ? data.notes.value : this.notes,
      rawMetadata: data.rawMetadata.present
          ? data.rawMetadata.value
          : this.rawMetadata,
      importHash: data.importHash.present
          ? data.importHash.value
          : this.importHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetEvent(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('valueDate: $valueDate, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('commission: $commission, ')
          ..write('taxWithheld: $taxWithheld, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('rawMetadata: $rawMetadata, ')
          ..write('importHash: $importHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    date,
    valueDate,
    type,
    quantity,
    price,
    amount,
    currency,
    exchangeRate,
    commission,
    taxWithheld,
    source,
    notes,
    rawMetadata,
    importHash,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetEvent &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.date == this.date &&
          other.valueDate == this.valueDate &&
          other.type == this.type &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.exchangeRate == this.exchangeRate &&
          other.commission == this.commission &&
          other.taxWithheld == this.taxWithheld &&
          other.source == this.source &&
          other.notes == this.notes &&
          other.rawMetadata == this.rawMetadata &&
          other.importHash == this.importHash &&
          other.createdAt == this.createdAt);
}

class AssetEventsCompanion extends UpdateCompanion<AssetEvent> {
  final Value<int> id;
  final Value<int> assetId;
  final Value<DateTime> date;
  final Value<DateTime> valueDate;
  final Value<EventType> type;
  final Value<double?> quantity;
  final Value<double?> price;
  final Value<double> amount;
  final Value<String> currency;
  final Value<double?> exchangeRate;
  final Value<double?> commission;
  final Value<double?> taxWithheld;
  final Value<String?> source;
  final Value<String?> notes;
  final Value<String?> rawMetadata;
  final Value<String?> importHash;
  final Value<DateTime> createdAt;
  const AssetEventsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.date = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.type = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.commission = const Value.absent(),
    this.taxWithheld = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.rawMetadata = const Value.absent(),
    this.importHash = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AssetEventsCompanion.insert({
    this.id = const Value.absent(),
    required int assetId,
    required DateTime date,
    required DateTime valueDate,
    required EventType type,
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    required double amount,
    this.currency = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.commission = const Value.absent(),
    this.taxWithheld = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.rawMetadata = const Value.absent(),
    this.importHash = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : assetId = Value(assetId),
       date = Value(date),
       valueDate = Value(valueDate),
       type = Value(type),
       amount = Value(amount);
  static Insertable<AssetEvent> custom({
    Expression<int>? id,
    Expression<int>? assetId,
    Expression<DateTime>? date,
    Expression<DateTime>? valueDate,
    Expression<String>? type,
    Expression<double>? quantity,
    Expression<double>? price,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<double>? exchangeRate,
    Expression<double>? commission,
    Expression<double>? taxWithheld,
    Expression<String>? source,
    Expression<String>? notes,
    Expression<String>? rawMetadata,
    Expression<String>? importHash,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (date != null) 'date': date,
      if (valueDate != null) 'value_date': valueDate,
      if (type != null) 'type': type,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (commission != null) 'commission': commission,
      if (taxWithheld != null) 'tax_withheld': taxWithheld,
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes,
      if (rawMetadata != null) 'raw_metadata': rawMetadata,
      if (importHash != null) 'import_hash': importHash,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AssetEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? assetId,
    Value<DateTime>? date,
    Value<DateTime>? valueDate,
    Value<EventType>? type,
    Value<double?>? quantity,
    Value<double?>? price,
    Value<double>? amount,
    Value<String>? currency,
    Value<double?>? exchangeRate,
    Value<double?>? commission,
    Value<double?>? taxWithheld,
    Value<String?>? source,
    Value<String?>? notes,
    Value<String?>? rawMetadata,
    Value<String?>? importHash,
    Value<DateTime>? createdAt,
  }) {
    return AssetEventsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      date: date ?? this.date,
      valueDate: valueDate ?? this.valueDate,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      commission: commission ?? this.commission,
      taxWithheld: taxWithheld ?? this.taxWithheld,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      rawMetadata: rawMetadata ?? this.rawMetadata,
      importHash: importHash ?? this.importHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<DateTime>(valueDate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AssetEventsTable.$convertertype.toSql(type.value),
      );
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (exchangeRate.present) {
      map['exchange_rate'] = Variable<double>(exchangeRate.value);
    }
    if (commission.present) {
      map['commission'] = Variable<double>(commission.value);
    }
    if (taxWithheld.present) {
      map['tax_withheld'] = Variable<double>(taxWithheld.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rawMetadata.present) {
      map['raw_metadata'] = Variable<String>(rawMetadata.value);
    }
    if (importHash.present) {
      map['import_hash'] = Variable<String>(importHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetEventsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('valueDate: $valueDate, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('commission: $commission, ')
          ..write('taxWithheld: $taxWithheld, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('rawMetadata: $rawMetadata, ')
          ..write('importHash: $importHash, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AssetSnapshotsTable extends AssetSnapshots
    with TableInfo<$AssetSnapshotsTable, AssetSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assets (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _investedMeta = const VerificationMeta(
    'invested',
  );
  @override
  late final GeneratedColumn<double> invested = GeneratedColumn<double>(
    'invested',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _growthMeta = const VerificationMeta('growth');
  @override
  late final GeneratedColumn<double> growth = GeneratedColumn<double>(
    'growth',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _growthPercentMeta = const VerificationMeta(
    'growthPercent',
  );
  @override
  late final GeneratedColumn<double> growthPercent = GeneratedColumn<double>(
    'growth_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterTaxValueMeta = const VerificationMeta(
    'afterTaxValue',
  );
  @override
  late final GeneratedColumn<double> afterTaxValue = GeneratedColumn<double>(
    'after_tax_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    date,
    value,
    invested,
    growth,
    growthPercent,
    afterTaxValue,
    quantity,
    price,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('invested')) {
      context.handle(
        _investedMeta,
        invested.isAcceptableOrUnknown(data['invested']!, _investedMeta),
      );
    } else if (isInserting) {
      context.missing(_investedMeta);
    }
    if (data.containsKey('growth')) {
      context.handle(
        _growthMeta,
        growth.isAcceptableOrUnknown(data['growth']!, _growthMeta),
      );
    } else if (isInserting) {
      context.missing(_growthMeta);
    }
    if (data.containsKey('growth_percent')) {
      context.handle(
        _growthPercentMeta,
        growthPercent.isAcceptableOrUnknown(
          data['growth_percent']!,
          _growthPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_growthPercentMeta);
    }
    if (data.containsKey('after_tax_value')) {
      context.handle(
        _afterTaxValueMeta,
        afterTaxValue.isAcceptableOrUnknown(
          data['after_tax_value']!,
          _afterTaxValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterTaxValueMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {assetId, date},
  ];
  @override
  AssetSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asset_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      invested: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}invested'],
      )!,
      growth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}growth'],
      )!,
      growthPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}growth_percent'],
      )!,
      afterTaxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}after_tax_value'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      ),
    );
  }

  @override
  $AssetSnapshotsTable createAlias(String alias) {
    return $AssetSnapshotsTable(attachedDatabase, alias);
  }
}

class AssetSnapshot extends DataClass implements Insertable<AssetSnapshot> {
  final int id;
  final int assetId;
  final DateTime date;
  final double value;
  final double invested;
  final double growth;
  final double growthPercent;
  final double afterTaxValue;
  final double? quantity;
  final double? price;
  const AssetSnapshot({
    required this.id,
    required this.assetId,
    required this.date,
    required this.value,
    required this.invested,
    required this.growth,
    required this.growthPercent,
    required this.afterTaxValue,
    this.quantity,
    this.price,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<int>(assetId);
    map['date'] = Variable<DateTime>(date);
    map['value'] = Variable<double>(value);
    map['invested'] = Variable<double>(invested);
    map['growth'] = Variable<double>(growth);
    map['growth_percent'] = Variable<double>(growthPercent);
    map['after_tax_value'] = Variable<double>(afterTaxValue);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    return map;
  }

  AssetSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return AssetSnapshotsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      date: Value(date),
      value: Value(value),
      invested: Value(invested),
      growth: Value(growth),
      growthPercent: Value(growthPercent),
      afterTaxValue: Value(afterTaxValue),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
    );
  }

  factory AssetSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetSnapshot(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<int>(json['assetId']),
      date: serializer.fromJson<DateTime>(json['date']),
      value: serializer.fromJson<double>(json['value']),
      invested: serializer.fromJson<double>(json['invested']),
      growth: serializer.fromJson<double>(json['growth']),
      growthPercent: serializer.fromJson<double>(json['growthPercent']),
      afterTaxValue: serializer.fromJson<double>(json['afterTaxValue']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      price: serializer.fromJson<double?>(json['price']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<int>(assetId),
      'date': serializer.toJson<DateTime>(date),
      'value': serializer.toJson<double>(value),
      'invested': serializer.toJson<double>(invested),
      'growth': serializer.toJson<double>(growth),
      'growthPercent': serializer.toJson<double>(growthPercent),
      'afterTaxValue': serializer.toJson<double>(afterTaxValue),
      'quantity': serializer.toJson<double?>(quantity),
      'price': serializer.toJson<double?>(price),
    };
  }

  AssetSnapshot copyWith({
    int? id,
    int? assetId,
    DateTime? date,
    double? value,
    double? invested,
    double? growth,
    double? growthPercent,
    double? afterTaxValue,
    Value<double?> quantity = const Value.absent(),
    Value<double?> price = const Value.absent(),
  }) => AssetSnapshot(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    date: date ?? this.date,
    value: value ?? this.value,
    invested: invested ?? this.invested,
    growth: growth ?? this.growth,
    growthPercent: growthPercent ?? this.growthPercent,
    afterTaxValue: afterTaxValue ?? this.afterTaxValue,
    quantity: quantity.present ? quantity.value : this.quantity,
    price: price.present ? price.value : this.price,
  );
  AssetSnapshot copyWithCompanion(AssetSnapshotsCompanion data) {
    return AssetSnapshot(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      date: data.date.present ? data.date.value : this.date,
      value: data.value.present ? data.value.value : this.value,
      invested: data.invested.present ? data.invested.value : this.invested,
      growth: data.growth.present ? data.growth.value : this.growth,
      growthPercent: data.growthPercent.present
          ? data.growthPercent.value
          : this.growthPercent,
      afterTaxValue: data.afterTaxValue.present
          ? data.afterTaxValue.value
          : this.afterTaxValue,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetSnapshot(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('invested: $invested, ')
          ..write('growth: $growth, ')
          ..write('growthPercent: $growthPercent, ')
          ..write('afterTaxValue: $afterTaxValue, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    date,
    value,
    invested,
    growth,
    growthPercent,
    afterTaxValue,
    quantity,
    price,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetSnapshot &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.date == this.date &&
          other.value == this.value &&
          other.invested == this.invested &&
          other.growth == this.growth &&
          other.growthPercent == this.growthPercent &&
          other.afterTaxValue == this.afterTaxValue &&
          other.quantity == this.quantity &&
          other.price == this.price);
}

class AssetSnapshotsCompanion extends UpdateCompanion<AssetSnapshot> {
  final Value<int> id;
  final Value<int> assetId;
  final Value<DateTime> date;
  final Value<double> value;
  final Value<double> invested;
  final Value<double> growth;
  final Value<double> growthPercent;
  final Value<double> afterTaxValue;
  final Value<double?> quantity;
  final Value<double?> price;
  const AssetSnapshotsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.date = const Value.absent(),
    this.value = const Value.absent(),
    this.invested = const Value.absent(),
    this.growth = const Value.absent(),
    this.growthPercent = const Value.absent(),
    this.afterTaxValue = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
  });
  AssetSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required int assetId,
    required DateTime date,
    required double value,
    required double invested,
    required double growth,
    required double growthPercent,
    required double afterTaxValue,
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
  }) : assetId = Value(assetId),
       date = Value(date),
       value = Value(value),
       invested = Value(invested),
       growth = Value(growth),
       growthPercent = Value(growthPercent),
       afterTaxValue = Value(afterTaxValue);
  static Insertable<AssetSnapshot> custom({
    Expression<int>? id,
    Expression<int>? assetId,
    Expression<DateTime>? date,
    Expression<double>? value,
    Expression<double>? invested,
    Expression<double>? growth,
    Expression<double>? growthPercent,
    Expression<double>? afterTaxValue,
    Expression<double>? quantity,
    Expression<double>? price,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (date != null) 'date': date,
      if (value != null) 'value': value,
      if (invested != null) 'invested': invested,
      if (growth != null) 'growth': growth,
      if (growthPercent != null) 'growth_percent': growthPercent,
      if (afterTaxValue != null) 'after_tax_value': afterTaxValue,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
    });
  }

  AssetSnapshotsCompanion copyWith({
    Value<int>? id,
    Value<int>? assetId,
    Value<DateTime>? date,
    Value<double>? value,
    Value<double>? invested,
    Value<double>? growth,
    Value<double>? growthPercent,
    Value<double>? afterTaxValue,
    Value<double?>? quantity,
    Value<double?>? price,
  }) {
    return AssetSnapshotsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      date: date ?? this.date,
      value: value ?? this.value,
      invested: invested ?? this.invested,
      growth: growth ?? this.growth,
      growthPercent: growthPercent ?? this.growthPercent,
      afterTaxValue: afterTaxValue ?? this.afterTaxValue,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (invested.present) {
      map['invested'] = Variable<double>(invested.value);
    }
    if (growth.present) {
      map['growth'] = Variable<double>(growth.value);
    }
    if (growthPercent.present) {
      map['growth_percent'] = Variable<double>(growthPercent.value);
    }
    if (afterTaxValue.present) {
      map['after_tax_value'] = Variable<double>(afterTaxValue.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('invested: $invested, ')
          ..write('growth: $growth, ')
          ..write('growthPercent: $growthPercent, ')
          ..write('afterTaxValue: $afterTaxValue, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price')
          ..write(')'))
        .toString();
  }
}

class $BuffersTable extends Buffers with TableInfo<$BuffersTable, Buffer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuffersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
    'target_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedEventIdMeta = const VerificationMeta(
    'linkedEventId',
  );
  @override
  late final GeneratedColumn<int> linkedEventId = GeneratedColumn<int>(
    'linked_event_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    targetAmount,
    linkedEventId,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buffers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Buffer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    }
    if (data.containsKey('linked_event_id')) {
      context.handle(
        _linkedEventIdMeta,
        linkedEventId.isAcceptableOrUnknown(
          data['linked_event_id']!,
          _linkedEventIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Buffer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Buffer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_amount'],
      ),
      linkedEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_event_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BuffersTable createAlias(String alias) {
    return $BuffersTable(attachedDatabase, alias);
  }
}

class Buffer extends DataClass implements Insertable<Buffer> {
  final int id;
  final String name;
  final double? targetAmount;
  final int? linkedEventId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Buffer({
    required this.id,
    required this.name,
    this.targetAmount,
    this.linkedEventId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || targetAmount != null) {
      map['target_amount'] = Variable<double>(targetAmount);
    }
    if (!nullToAbsent || linkedEventId != null) {
      map['linked_event_id'] = Variable<int>(linkedEventId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BuffersCompanion toCompanion(bool nullToAbsent) {
    return BuffersCompanion(
      id: Value(id),
      name: Value(name),
      targetAmount: targetAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(targetAmount),
      linkedEventId: linkedEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedEventId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Buffer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Buffer(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      targetAmount: serializer.fromJson<double?>(json['targetAmount']),
      linkedEventId: serializer.fromJson<int?>(json['linkedEventId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'targetAmount': serializer.toJson<double?>(targetAmount),
      'linkedEventId': serializer.toJson<int?>(linkedEventId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Buffer copyWith({
    int? id,
    String? name,
    Value<double?> targetAmount = const Value.absent(),
    Value<int?> linkedEventId = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Buffer(
    id: id ?? this.id,
    name: name ?? this.name,
    targetAmount: targetAmount.present ? targetAmount.value : this.targetAmount,
    linkedEventId: linkedEventId.present
        ? linkedEventId.value
        : this.linkedEventId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Buffer copyWithCompanion(BuffersCompanion data) {
    return Buffer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      linkedEventId: data.linkedEventId.present
          ? data.linkedEventId.value
          : this.linkedEventId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Buffer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('linkedEventId: $linkedEventId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    targetAmount,
    linkedEventId,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Buffer &&
          other.id == this.id &&
          other.name == this.name &&
          other.targetAmount == this.targetAmount &&
          other.linkedEventId == this.linkedEventId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BuffersCompanion extends UpdateCompanion<Buffer> {
  final Value<int> id;
  final Value<String> name;
  final Value<double?> targetAmount;
  final Value<int?> linkedEventId;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BuffersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.linkedEventId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BuffersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.targetAmount = const Value.absent(),
    this.linkedEventId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Buffer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? targetAmount,
    Expression<int>? linkedEventId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (linkedEventId != null) 'linked_event_id': linkedEventId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BuffersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double?>? targetAmount,
    Value<int?>? linkedEventId,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BuffersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      linkedEventId: linkedEventId ?? this.linkedEventId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (linkedEventId.present) {
      map['linked_event_id'] = Variable<int>(linkedEventId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuffersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('linkedEventId: $linkedEventId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BufferTransactionsTable extends BufferTransactions
    with TableInfo<$BufferTransactionsTable, BufferTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BufferTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bufferIdMeta = const VerificationMeta(
    'bufferId',
  );
  @override
  late final GeneratedColumn<int> bufferId = GeneratedColumn<int>(
    'buffer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES buffers (id)',
    ),
  );
  static const VerificationMeta _operationDateMeta = const VerificationMeta(
    'operationDate',
  );
  @override
  late final GeneratedColumn<DateTime> operationDate =
      GeneratedColumn<DateTime>(
        'operation_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<DateTime> valueDate = GeneratedColumn<DateTime>(
    'value_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _balanceAfterMeta = const VerificationMeta(
    'balanceAfter',
  );
  @override
  late final GeneratedColumn<double> balanceAfter = GeneratedColumn<double>(
    'balance_after',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPayrollMeta = const VerificationMeta(
    'isPayroll',
  );
  @override
  late final GeneratedColumn<bool> isPayroll = GeneratedColumn<bool>(
    'is_payroll',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_payroll" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isForceLastMeta = const VerificationMeta(
    'isForceLast',
  );
  @override
  late final GeneratedColumn<bool> isForceLast = GeneratedColumn<bool>(
    'is_force_last',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_force_last" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isReimbursementMeta = const VerificationMeta(
    'isReimbursement',
  );
  @override
  late final GeneratedColumn<bool> isReimbursement = GeneratedColumn<bool>(
    'is_reimbursement',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reimbursement" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _linkedTransactionIdMeta =
      const VerificationMeta('linkedTransactionId');
  @override
  late final GeneratedColumn<int> linkedTransactionId = GeneratedColumn<int>(
    'linked_transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bufferId,
    operationDate,
    valueDate,
    description,
    amount,
    currency,
    balanceAfter,
    isPayroll,
    isForceLast,
    isReimbursement,
    linkedTransactionId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buffer_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BufferTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('buffer_id')) {
      context.handle(
        _bufferIdMeta,
        bufferId.isAcceptableOrUnknown(data['buffer_id']!, _bufferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bufferIdMeta);
    }
    if (data.containsKey('operation_date')) {
      context.handle(
        _operationDateMeta,
        operationDate.isAcceptableOrUnknown(
          data['operation_date']!,
          _operationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationDateMeta);
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_valueDateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('balance_after')) {
      context.handle(
        _balanceAfterMeta,
        balanceAfter.isAcceptableOrUnknown(
          data['balance_after']!,
          _balanceAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceAfterMeta);
    }
    if (data.containsKey('is_payroll')) {
      context.handle(
        _isPayrollMeta,
        isPayroll.isAcceptableOrUnknown(data['is_payroll']!, _isPayrollMeta),
      );
    }
    if (data.containsKey('is_force_last')) {
      context.handle(
        _isForceLastMeta,
        isForceLast.isAcceptableOrUnknown(
          data['is_force_last']!,
          _isForceLastMeta,
        ),
      );
    }
    if (data.containsKey('is_reimbursement')) {
      context.handle(
        _isReimbursementMeta,
        isReimbursement.isAcceptableOrUnknown(
          data['is_reimbursement']!,
          _isReimbursementMeta,
        ),
      );
    }
    if (data.containsKey('linked_transaction_id')) {
      context.handle(
        _linkedTransactionIdMeta,
        linkedTransactionId.isAcceptableOrUnknown(
          data['linked_transaction_id']!,
          _linkedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BufferTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BufferTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bufferId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_id'],
      )!,
      operationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}operation_date'],
      )!,
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}value_date'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      balanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}balance_after'],
      )!,
      isPayroll: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_payroll'],
      )!,
      isForceLast: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_force_last'],
      )!,
      isReimbursement: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reimbursement'],
      )!,
      linkedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BufferTransactionsTable createAlias(String alias) {
    return $BufferTransactionsTable(attachedDatabase, alias);
  }
}

class BufferTransaction extends DataClass
    implements Insertable<BufferTransaction> {
  final int id;
  final int bufferId;
  final DateTime operationDate;
  final DateTime valueDate;
  final String description;
  final double amount;
  final String currency;
  final double balanceAfter;
  final bool isPayroll;
  final bool isForceLast;
  final bool isReimbursement;
  final int? linkedTransactionId;
  final DateTime createdAt;
  const BufferTransaction({
    required this.id,
    required this.bufferId,
    required this.operationDate,
    required this.valueDate,
    required this.description,
    required this.amount,
    required this.currency,
    required this.balanceAfter,
    required this.isPayroll,
    required this.isForceLast,
    required this.isReimbursement,
    this.linkedTransactionId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['buffer_id'] = Variable<int>(bufferId);
    map['operation_date'] = Variable<DateTime>(operationDate);
    map['value_date'] = Variable<DateTime>(valueDate);
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['balance_after'] = Variable<double>(balanceAfter);
    map['is_payroll'] = Variable<bool>(isPayroll);
    map['is_force_last'] = Variable<bool>(isForceLast);
    map['is_reimbursement'] = Variable<bool>(isReimbursement);
    if (!nullToAbsent || linkedTransactionId != null) {
      map['linked_transaction_id'] = Variable<int>(linkedTransactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BufferTransactionsCompanion toCompanion(bool nullToAbsent) {
    return BufferTransactionsCompanion(
      id: Value(id),
      bufferId: Value(bufferId),
      operationDate: Value(operationDate),
      valueDate: Value(valueDate),
      description: Value(description),
      amount: Value(amount),
      currency: Value(currency),
      balanceAfter: Value(balanceAfter),
      isPayroll: Value(isPayroll),
      isForceLast: Value(isForceLast),
      isReimbursement: Value(isReimbursement),
      linkedTransactionId: linkedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTransactionId),
      createdAt: Value(createdAt),
    );
  }

  factory BufferTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BufferTransaction(
      id: serializer.fromJson<int>(json['id']),
      bufferId: serializer.fromJson<int>(json['bufferId']),
      operationDate: serializer.fromJson<DateTime>(json['operationDate']),
      valueDate: serializer.fromJson<DateTime>(json['valueDate']),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      balanceAfter: serializer.fromJson<double>(json['balanceAfter']),
      isPayroll: serializer.fromJson<bool>(json['isPayroll']),
      isForceLast: serializer.fromJson<bool>(json['isForceLast']),
      isReimbursement: serializer.fromJson<bool>(json['isReimbursement']),
      linkedTransactionId: serializer.fromJson<int?>(
        json['linkedTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bufferId': serializer.toJson<int>(bufferId),
      'operationDate': serializer.toJson<DateTime>(operationDate),
      'valueDate': serializer.toJson<DateTime>(valueDate),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'balanceAfter': serializer.toJson<double>(balanceAfter),
      'isPayroll': serializer.toJson<bool>(isPayroll),
      'isForceLast': serializer.toJson<bool>(isForceLast),
      'isReimbursement': serializer.toJson<bool>(isReimbursement),
      'linkedTransactionId': serializer.toJson<int?>(linkedTransactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BufferTransaction copyWith({
    int? id,
    int? bufferId,
    DateTime? operationDate,
    DateTime? valueDate,
    String? description,
    double? amount,
    String? currency,
    double? balanceAfter,
    bool? isPayroll,
    bool? isForceLast,
    bool? isReimbursement,
    Value<int?> linkedTransactionId = const Value.absent(),
    DateTime? createdAt,
  }) => BufferTransaction(
    id: id ?? this.id,
    bufferId: bufferId ?? this.bufferId,
    operationDate: operationDate ?? this.operationDate,
    valueDate: valueDate ?? this.valueDate,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    balanceAfter: balanceAfter ?? this.balanceAfter,
    isPayroll: isPayroll ?? this.isPayroll,
    isForceLast: isForceLast ?? this.isForceLast,
    isReimbursement: isReimbursement ?? this.isReimbursement,
    linkedTransactionId: linkedTransactionId.present
        ? linkedTransactionId.value
        : this.linkedTransactionId,
    createdAt: createdAt ?? this.createdAt,
  );
  BufferTransaction copyWithCompanion(BufferTransactionsCompanion data) {
    return BufferTransaction(
      id: data.id.present ? data.id.value : this.id,
      bufferId: data.bufferId.present ? data.bufferId.value : this.bufferId,
      operationDate: data.operationDate.present
          ? data.operationDate.value
          : this.operationDate,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      balanceAfter: data.balanceAfter.present
          ? data.balanceAfter.value
          : this.balanceAfter,
      isPayroll: data.isPayroll.present ? data.isPayroll.value : this.isPayroll,
      isForceLast: data.isForceLast.present
          ? data.isForceLast.value
          : this.isForceLast,
      isReimbursement: data.isReimbursement.present
          ? data.isReimbursement.value
          : this.isReimbursement,
      linkedTransactionId: data.linkedTransactionId.present
          ? data.linkedTransactionId.value
          : this.linkedTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BufferTransaction(')
          ..write('id: $id, ')
          ..write('bufferId: $bufferId, ')
          ..write('operationDate: $operationDate, ')
          ..write('valueDate: $valueDate, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('isPayroll: $isPayroll, ')
          ..write('isForceLast: $isForceLast, ')
          ..write('isReimbursement: $isReimbursement, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bufferId,
    operationDate,
    valueDate,
    description,
    amount,
    currency,
    balanceAfter,
    isPayroll,
    isForceLast,
    isReimbursement,
    linkedTransactionId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BufferTransaction &&
          other.id == this.id &&
          other.bufferId == this.bufferId &&
          other.operationDate == this.operationDate &&
          other.valueDate == this.valueDate &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.balanceAfter == this.balanceAfter &&
          other.isPayroll == this.isPayroll &&
          other.isForceLast == this.isForceLast &&
          other.isReimbursement == this.isReimbursement &&
          other.linkedTransactionId == this.linkedTransactionId &&
          other.createdAt == this.createdAt);
}

class BufferTransactionsCompanion extends UpdateCompanion<BufferTransaction> {
  final Value<int> id;
  final Value<int> bufferId;
  final Value<DateTime> operationDate;
  final Value<DateTime> valueDate;
  final Value<String> description;
  final Value<double> amount;
  final Value<String> currency;
  final Value<double> balanceAfter;
  final Value<bool> isPayroll;
  final Value<bool> isForceLast;
  final Value<bool> isReimbursement;
  final Value<int?> linkedTransactionId;
  final Value<DateTime> createdAt;
  const BufferTransactionsCompanion({
    this.id = const Value.absent(),
    this.bufferId = const Value.absent(),
    this.operationDate = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.isPayroll = const Value.absent(),
    this.isForceLast = const Value.absent(),
    this.isReimbursement = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BufferTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int bufferId,
    required DateTime operationDate,
    required DateTime valueDate,
    this.description = const Value.absent(),
    required double amount,
    this.currency = const Value.absent(),
    required double balanceAfter,
    this.isPayroll = const Value.absent(),
    this.isForceLast = const Value.absent(),
    this.isReimbursement = const Value.absent(),
    this.linkedTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : bufferId = Value(bufferId),
       operationDate = Value(operationDate),
       valueDate = Value(valueDate),
       amount = Value(amount),
       balanceAfter = Value(balanceAfter);
  static Insertable<BufferTransaction> custom({
    Expression<int>? id,
    Expression<int>? bufferId,
    Expression<DateTime>? operationDate,
    Expression<DateTime>? valueDate,
    Expression<String>? description,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<double>? balanceAfter,
    Expression<bool>? isPayroll,
    Expression<bool>? isForceLast,
    Expression<bool>? isReimbursement,
    Expression<int>? linkedTransactionId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bufferId != null) 'buffer_id': bufferId,
      if (operationDate != null) 'operation_date': operationDate,
      if (valueDate != null) 'value_date': valueDate,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (isPayroll != null) 'is_payroll': isPayroll,
      if (isForceLast != null) 'is_force_last': isForceLast,
      if (isReimbursement != null) 'is_reimbursement': isReimbursement,
      if (linkedTransactionId != null)
        'linked_transaction_id': linkedTransactionId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BufferTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? bufferId,
    Value<DateTime>? operationDate,
    Value<DateTime>? valueDate,
    Value<String>? description,
    Value<double>? amount,
    Value<String>? currency,
    Value<double>? balanceAfter,
    Value<bool>? isPayroll,
    Value<bool>? isForceLast,
    Value<bool>? isReimbursement,
    Value<int?>? linkedTransactionId,
    Value<DateTime>? createdAt,
  }) {
    return BufferTransactionsCompanion(
      id: id ?? this.id,
      bufferId: bufferId ?? this.bufferId,
      operationDate: operationDate ?? this.operationDate,
      valueDate: valueDate ?? this.valueDate,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      isPayroll: isPayroll ?? this.isPayroll,
      isForceLast: isForceLast ?? this.isForceLast,
      isReimbursement: isReimbursement ?? this.isReimbursement,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bufferId.present) {
      map['buffer_id'] = Variable<int>(bufferId.value);
    }
    if (operationDate.present) {
      map['operation_date'] = Variable<DateTime>(operationDate.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<DateTime>(valueDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (balanceAfter.present) {
      map['balance_after'] = Variable<double>(balanceAfter.value);
    }
    if (isPayroll.present) {
      map['is_payroll'] = Variable<bool>(isPayroll.value);
    }
    if (isForceLast.present) {
      map['is_force_last'] = Variable<bool>(isForceLast.value);
    }
    if (isReimbursement.present) {
      map['is_reimbursement'] = Variable<bool>(isReimbursement.value);
    }
    if (linkedTransactionId.present) {
      map['linked_transaction_id'] = Variable<int>(linkedTransactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BufferTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('bufferId: $bufferId, ')
          ..write('operationDate: $operationDate, ')
          ..write('valueDate: $valueDate, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('isPayroll: $isPayroll, ')
          ..write('isForceLast: $isForceLast, ')
          ..write('isReimbursement: $isReimbursement, ')
          ..write('linkedTransactionId: $linkedTransactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MarketPricesTable extends MarketPrices
    with TableInfo<$MarketPricesTable, MarketPrice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarketPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assets (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closePriceMeta = const VerificationMeta(
    'closePrice',
  );
  @override
  late final GeneratedColumn<double> closePrice = GeneratedColumn<double>(
    'close_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetId, date, closePrice, currency];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'market_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarketPrice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('close_price')) {
      context.handle(
        _closePriceMeta,
        closePrice.isAcceptableOrUnknown(data['close_price']!, _closePriceMeta),
      );
    } else if (isInserting) {
      context.missing(_closePriceMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId, date};
  @override
  MarketPrice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarketPrice(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asset_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      closePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}close_price'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
    );
  }

  @override
  $MarketPricesTable createAlias(String alias) {
    return $MarketPricesTable(attachedDatabase, alias);
  }
}

class MarketPrice extends DataClass implements Insertable<MarketPrice> {
  final int assetId;
  final DateTime date;
  final double closePrice;
  final String currency;
  const MarketPrice({
    required this.assetId,
    required this.date,
    required this.closePrice,
    required this.currency,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<int>(assetId);
    map['date'] = Variable<DateTime>(date);
    map['close_price'] = Variable<double>(closePrice);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  MarketPricesCompanion toCompanion(bool nullToAbsent) {
    return MarketPricesCompanion(
      assetId: Value(assetId),
      date: Value(date),
      closePrice: Value(closePrice),
      currency: Value(currency),
    );
  }

  factory MarketPrice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarketPrice(
      assetId: serializer.fromJson<int>(json['assetId']),
      date: serializer.fromJson<DateTime>(json['date']),
      closePrice: serializer.fromJson<double>(json['closePrice']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<int>(assetId),
      'date': serializer.toJson<DateTime>(date),
      'closePrice': serializer.toJson<double>(closePrice),
      'currency': serializer.toJson<String>(currency),
    };
  }

  MarketPrice copyWith({
    int? assetId,
    DateTime? date,
    double? closePrice,
    String? currency,
  }) => MarketPrice(
    assetId: assetId ?? this.assetId,
    date: date ?? this.date,
    closePrice: closePrice ?? this.closePrice,
    currency: currency ?? this.currency,
  );
  MarketPrice copyWithCompanion(MarketPricesCompanion data) {
    return MarketPrice(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      date: data.date.present ? data.date.value : this.date,
      closePrice: data.closePrice.present
          ? data.closePrice.value
          : this.closePrice,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarketPrice(')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('closePrice: $closePrice, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, date, closePrice, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarketPrice &&
          other.assetId == this.assetId &&
          other.date == this.date &&
          other.closePrice == this.closePrice &&
          other.currency == this.currency);
}

class MarketPricesCompanion extends UpdateCompanion<MarketPrice> {
  final Value<int> assetId;
  final Value<DateTime> date;
  final Value<double> closePrice;
  final Value<String> currency;
  final Value<int> rowid;
  const MarketPricesCompanion({
    this.assetId = const Value.absent(),
    this.date = const Value.absent(),
    this.closePrice = const Value.absent(),
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarketPricesCompanion.insert({
    required int assetId,
    required DateTime date,
    required double closePrice,
    required String currency,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       date = Value(date),
       closePrice = Value(closePrice),
       currency = Value(currency);
  static Insertable<MarketPrice> custom({
    Expression<int>? assetId,
    Expression<DateTime>? date,
    Expression<double>? closePrice,
    Expression<String>? currency,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (date != null) 'date': date,
      if (closePrice != null) 'close_price': closePrice,
      if (currency != null) 'currency': currency,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarketPricesCompanion copyWith({
    Value<int>? assetId,
    Value<DateTime>? date,
    Value<double>? closePrice,
    Value<String>? currency,
    Value<int>? rowid,
  }) {
    return MarketPricesCompanion(
      assetId: assetId ?? this.assetId,
      date: date ?? this.date,
      closePrice: closePrice ?? this.closePrice,
      currency: currency ?? this.currency,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (closePrice.present) {
      map['close_price'] = Variable<double>(closePrice.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarketPricesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('date: $date, ')
          ..write('closePrice: $closePrice, ')
          ..write('currency: $currency, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExchangeRatesTable extends ExchangeRates
    with TableInfo<$ExchangeRatesTable, ExchangeRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExchangeRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fromCurrencyMeta = const VerificationMeta(
    'fromCurrency',
  );
  @override
  late final GeneratedColumn<String> fromCurrency = GeneratedColumn<String>(
    'from_currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toCurrencyMeta = const VerificationMeta(
    'toCurrency',
  );
  @override
  late final GeneratedColumn<String> toCurrency = GeneratedColumn<String>(
    'to_currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [fromCurrency, toCurrency, date, rate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exchange_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExchangeRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('from_currency')) {
      context.handle(
        _fromCurrencyMeta,
        fromCurrency.isAcceptableOrUnknown(
          data['from_currency']!,
          _fromCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromCurrencyMeta);
    }
    if (data.containsKey('to_currency')) {
      context.handle(
        _toCurrencyMeta,
        toCurrency.isAcceptableOrUnknown(data['to_currency']!, _toCurrencyMeta),
      );
    } else if (isInserting) {
      context.missing(_toCurrencyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fromCurrency, toCurrency, date};
  @override
  ExchangeRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExchangeRate(
      fromCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_currency'],
      )!,
      toCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_currency'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
    );
  }

  @override
  $ExchangeRatesTable createAlias(String alias) {
    return $ExchangeRatesTable(attachedDatabase, alias);
  }
}

class ExchangeRate extends DataClass implements Insertable<ExchangeRate> {
  final String fromCurrency;
  final String toCurrency;
  final DateTime date;
  final double rate;
  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.date,
    required this.rate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['from_currency'] = Variable<String>(fromCurrency);
    map['to_currency'] = Variable<String>(toCurrency);
    map['date'] = Variable<DateTime>(date);
    map['rate'] = Variable<double>(rate);
    return map;
  }

  ExchangeRatesCompanion toCompanion(bool nullToAbsent) {
    return ExchangeRatesCompanion(
      fromCurrency: Value(fromCurrency),
      toCurrency: Value(toCurrency),
      date: Value(date),
      rate: Value(rate),
    );
  }

  factory ExchangeRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExchangeRate(
      fromCurrency: serializer.fromJson<String>(json['fromCurrency']),
      toCurrency: serializer.fromJson<String>(json['toCurrency']),
      date: serializer.fromJson<DateTime>(json['date']),
      rate: serializer.fromJson<double>(json['rate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fromCurrency': serializer.toJson<String>(fromCurrency),
      'toCurrency': serializer.toJson<String>(toCurrency),
      'date': serializer.toJson<DateTime>(date),
      'rate': serializer.toJson<double>(rate),
    };
  }

  ExchangeRate copyWith({
    String? fromCurrency,
    String? toCurrency,
    DateTime? date,
    double? rate,
  }) => ExchangeRate(
    fromCurrency: fromCurrency ?? this.fromCurrency,
    toCurrency: toCurrency ?? this.toCurrency,
    date: date ?? this.date,
    rate: rate ?? this.rate,
  );
  ExchangeRate copyWithCompanion(ExchangeRatesCompanion data) {
    return ExchangeRate(
      fromCurrency: data.fromCurrency.present
          ? data.fromCurrency.value
          : this.fromCurrency,
      toCurrency: data.toCurrency.present
          ? data.toCurrency.value
          : this.toCurrency,
      date: data.date.present ? data.date.value : this.date,
      rate: data.rate.present ? data.rate.value : this.rate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRate(')
          ..write('fromCurrency: $fromCurrency, ')
          ..write('toCurrency: $toCurrency, ')
          ..write('date: $date, ')
          ..write('rate: $rate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fromCurrency, toCurrency, date, rate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExchangeRate &&
          other.fromCurrency == this.fromCurrency &&
          other.toCurrency == this.toCurrency &&
          other.date == this.date &&
          other.rate == this.rate);
}

class ExchangeRatesCompanion extends UpdateCompanion<ExchangeRate> {
  final Value<String> fromCurrency;
  final Value<String> toCurrency;
  final Value<DateTime> date;
  final Value<double> rate;
  final Value<int> rowid;
  const ExchangeRatesCompanion({
    this.fromCurrency = const Value.absent(),
    this.toCurrency = const Value.absent(),
    this.date = const Value.absent(),
    this.rate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExchangeRatesCompanion.insert({
    required String fromCurrency,
    required String toCurrency,
    required DateTime date,
    required double rate,
    this.rowid = const Value.absent(),
  }) : fromCurrency = Value(fromCurrency),
       toCurrency = Value(toCurrency),
       date = Value(date),
       rate = Value(rate);
  static Insertable<ExchangeRate> custom({
    Expression<String>? fromCurrency,
    Expression<String>? toCurrency,
    Expression<DateTime>? date,
    Expression<double>? rate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fromCurrency != null) 'from_currency': fromCurrency,
      if (toCurrency != null) 'to_currency': toCurrency,
      if (date != null) 'date': date,
      if (rate != null) 'rate': rate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExchangeRatesCompanion copyWith({
    Value<String>? fromCurrency,
    Value<String>? toCurrency,
    Value<DateTime>? date,
    Value<double>? rate,
    Value<int>? rowid,
  }) {
    return ExchangeRatesCompanion(
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      date: date ?? this.date,
      rate: rate ?? this.rate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fromCurrency.present) {
      map['from_currency'] = Variable<String>(fromCurrency.value);
    }
    if (toCurrency.present) {
      map['to_currency'] = Variable<String>(toCurrency.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRatesCompanion(')
          ..write('fromCurrency: $fromCurrency, ')
          ..write('toCurrency: $toCurrency, ')
          ..write('date: $date, ')
          ..write('rate: $rate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RegisteredEventsTable extends RegisteredEvents
    with TableInfo<$RegisteredEventsTable, RegisteredEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegisteredEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RegisteredEventType, String>
  type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RegisteredEventType>($RegisteredEventsTable.$convertertype);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPersonalMeta = const VerificationMeta(
    'isPersonal',
  );
  @override
  late final GeneratedColumn<bool> isPersonal = GeneratedColumn<bool>(
    'is_personal',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_personal" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    type,
    description,
    amount,
    isPersonal,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registered_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegisteredEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('is_personal')) {
      context.handle(
        _isPersonalMeta,
        isPersonal.isAcceptableOrUnknown(data['is_personal']!, _isPersonalMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegisteredEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegisteredEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      type: $RegisteredEventsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      isPersonal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_personal'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RegisteredEventsTable createAlias(String alias) {
    return $RegisteredEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RegisteredEventType, String, String>
  $convertertype = const EnumNameConverter<RegisteredEventType>(
    RegisteredEventType.values,
  );
}

class RegisteredEvent extends DataClass implements Insertable<RegisteredEvent> {
  final int id;
  final DateTime date;
  final RegisteredEventType type;
  final String description;
  final double amount;
  final bool isPersonal;
  final DateTime createdAt;
  const RegisteredEvent({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.isPersonal,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    {
      map['type'] = Variable<String>(
        $RegisteredEventsTable.$convertertype.toSql(type),
      );
    }
    map['description'] = Variable<String>(description);
    map['amount'] = Variable<double>(amount);
    map['is_personal'] = Variable<bool>(isPersonal);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RegisteredEventsCompanion toCompanion(bool nullToAbsent) {
    return RegisteredEventsCompanion(
      id: Value(id),
      date: Value(date),
      type: Value(type),
      description: Value(description),
      amount: Value(amount),
      isPersonal: Value(isPersonal),
      createdAt: Value(createdAt),
    );
  }

  factory RegisteredEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegisteredEvent(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      type: $RegisteredEventsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      description: serializer.fromJson<String>(json['description']),
      amount: serializer.fromJson<double>(json['amount']),
      isPersonal: serializer.fromJson<bool>(json['isPersonal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'type': serializer.toJson<String>(
        $RegisteredEventsTable.$convertertype.toJson(type),
      ),
      'description': serializer.toJson<String>(description),
      'amount': serializer.toJson<double>(amount),
      'isPersonal': serializer.toJson<bool>(isPersonal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RegisteredEvent copyWith({
    int? id,
    DateTime? date,
    RegisteredEventType? type,
    String? description,
    double? amount,
    bool? isPersonal,
    DateTime? createdAt,
  }) => RegisteredEvent(
    id: id ?? this.id,
    date: date ?? this.date,
    type: type ?? this.type,
    description: description ?? this.description,
    amount: amount ?? this.amount,
    isPersonal: isPersonal ?? this.isPersonal,
    createdAt: createdAt ?? this.createdAt,
  );
  RegisteredEvent copyWithCompanion(RegisteredEventsCompanion data) {
    return RegisteredEvent(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      description: data.description.present
          ? data.description.value
          : this.description,
      amount: data.amount.present ? data.amount.value : this.amount,
      isPersonal: data.isPersonal.present
          ? data.isPersonal.value
          : this.isPersonal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegisteredEvent(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('isPersonal: $isPersonal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, type, description, amount, isPersonal, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegisteredEvent &&
          other.id == this.id &&
          other.date == this.date &&
          other.type == this.type &&
          other.description == this.description &&
          other.amount == this.amount &&
          other.isPersonal == this.isPersonal &&
          other.createdAt == this.createdAt);
}

class RegisteredEventsCompanion extends UpdateCompanion<RegisteredEvent> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<RegisteredEventType> type;
  final Value<String> description;
  final Value<double> amount;
  final Value<bool> isPersonal;
  final Value<DateTime> createdAt;
  const RegisteredEventsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.amount = const Value.absent(),
    this.isPersonal = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RegisteredEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required RegisteredEventType type,
    this.description = const Value.absent(),
    required double amount,
    this.isPersonal = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : date = Value(date),
       type = Value(type),
       amount = Value(amount);
  static Insertable<RegisteredEvent> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? type,
    Expression<String>? description,
    Expression<double>? amount,
    Expression<bool>? isPersonal,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (isPersonal != null) 'is_personal': isPersonal,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RegisteredEventsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<RegisteredEventType>? type,
    Value<String>? description,
    Value<double>? amount,
    Value<bool>? isPersonal,
    Value<DateTime>? createdAt,
  }) {
    return RegisteredEventsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      isPersonal: isPersonal ?? this.isPersonal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $RegisteredEventsTable.$convertertype.toSql(type.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (isPersonal.present) {
      map['is_personal'] = Variable<bool>(isPersonal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegisteredEventsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('amount: $amount, ')
          ..write('isPersonal: $isPersonal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $HealthReimbursementsTable extends HealthReimbursements
    with TableInfo<$HealthReimbursementsTable, HealthReimbursement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthReimbursementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceNumberMeta = const VerificationMeta(
    'invoiceNumber',
  );
  @override
  late final GeneratedColumn<String> invoiceNumber = GeneratedColumn<String>(
    'invoice_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentDateMeta = const VerificationMeta(
    'documentDate',
  );
  @override
  late final GeneratedColumn<DateTime> documentDate = GeneratedColumn<DateTime>(
    'document_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimAmountMeta = const VerificationMeta(
    'claimAmount',
  );
  @override
  late final GeneratedColumn<double> claimAmount = GeneratedColumn<double>(
    'claim_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beneficiaryMeta = const VerificationMeta(
    'beneficiary',
  );
  @override
  late final GeneratedColumn<String> beneficiary = GeneratedColumn<String>(
    'beneficiary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reimbursedAmountMeta = const VerificationMeta(
    'reimbursedAmount',
  );
  @override
  late final GeneratedColumn<double> reimbursedAmount = GeneratedColumn<double>(
    'reimbursed_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reimbursementDateMeta = const VerificationMeta(
    'reimbursementDate',
  );
  @override
  late final GeneratedColumn<DateTime> reimbursementDate =
      GeneratedColumn<DateTime>(
        'reimbursement_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _paidAmountMeta = const VerificationMeta(
    'paidAmount',
  );
  @override
  late final GeneratedColumn<double> paidAmount = GeneratedColumn<double>(
    'paid_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uncoveredAmountMeta = const VerificationMeta(
    'uncoveredAmount',
  );
  @override
  late final GeneratedColumn<double> uncoveredAmount = GeneratedColumn<double>(
    'uncovered_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reimbursementPercentMeta =
      const VerificationMeta('reimbursementPercent');
  @override
  late final GeneratedColumn<double> reimbursementPercent =
      GeneratedColumn<double>(
        'reimbursement_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _processingDaysMeta = const VerificationMeta(
    'processingDays',
  );
  @override
  late final GeneratedColumn<int> processingDays = GeneratedColumn<int>(
    'processing_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCoveredMeta = const VerificationMeta(
    'isCovered',
  );
  @override
  late final GeneratedColumn<bool> isCovered = GeneratedColumn<bool>(
    'is_covered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_covered" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    invoiceNumber,
    documentDate,
    claimAmount,
    beneficiary,
    reimbursedAmount,
    reimbursementDate,
    paidAmount,
    uncoveredAmount,
    reimbursementPercent,
    processingDays,
    isCovered,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_reimbursements';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthReimbursement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('invoice_number')) {
      context.handle(
        _invoiceNumberMeta,
        invoiceNumber.isAcceptableOrUnknown(
          data['invoice_number']!,
          _invoiceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_invoiceNumberMeta);
    }
    if (data.containsKey('document_date')) {
      context.handle(
        _documentDateMeta,
        documentDate.isAcceptableOrUnknown(
          data['document_date']!,
          _documentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentDateMeta);
    }
    if (data.containsKey('claim_amount')) {
      context.handle(
        _claimAmountMeta,
        claimAmount.isAcceptableOrUnknown(
          data['claim_amount']!,
          _claimAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_claimAmountMeta);
    }
    if (data.containsKey('beneficiary')) {
      context.handle(
        _beneficiaryMeta,
        beneficiary.isAcceptableOrUnknown(
          data['beneficiary']!,
          _beneficiaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beneficiaryMeta);
    }
    if (data.containsKey('reimbursed_amount')) {
      context.handle(
        _reimbursedAmountMeta,
        reimbursedAmount.isAcceptableOrUnknown(
          data['reimbursed_amount']!,
          _reimbursedAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reimbursedAmountMeta);
    }
    if (data.containsKey('reimbursement_date')) {
      context.handle(
        _reimbursementDateMeta,
        reimbursementDate.isAcceptableOrUnknown(
          data['reimbursement_date']!,
          _reimbursementDateMeta,
        ),
      );
    }
    if (data.containsKey('paid_amount')) {
      context.handle(
        _paidAmountMeta,
        paidAmount.isAcceptableOrUnknown(data['paid_amount']!, _paidAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_paidAmountMeta);
    }
    if (data.containsKey('uncovered_amount')) {
      context.handle(
        _uncoveredAmountMeta,
        uncoveredAmount.isAcceptableOrUnknown(
          data['uncovered_amount']!,
          _uncoveredAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_uncoveredAmountMeta);
    }
    if (data.containsKey('reimbursement_percent')) {
      context.handle(
        _reimbursementPercentMeta,
        reimbursementPercent.isAcceptableOrUnknown(
          data['reimbursement_percent']!,
          _reimbursementPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reimbursementPercentMeta);
    }
    if (data.containsKey('processing_days')) {
      context.handle(
        _processingDaysMeta,
        processingDays.isAcceptableOrUnknown(
          data['processing_days']!,
          _processingDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processingDaysMeta);
    }
    if (data.containsKey('is_covered')) {
      context.handle(
        _isCoveredMeta,
        isCovered.isAcceptableOrUnknown(data['is_covered']!, _isCoveredMeta),
      );
    } else if (isInserting) {
      context.missing(_isCoveredMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthReimbursement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthReimbursement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      invoiceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_number'],
      )!,
      documentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}document_date'],
      )!,
      claimAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}claim_amount'],
      )!,
      beneficiary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beneficiary'],
      )!,
      reimbursedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reimbursed_amount'],
      )!,
      reimbursementDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reimbursement_date'],
      ),
      paidAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}paid_amount'],
      )!,
      uncoveredAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}uncovered_amount'],
      )!,
      reimbursementPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reimbursement_percent'],
      )!,
      processingDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processing_days'],
      )!,
      isCovered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_covered'],
      )!,
    );
  }

  @override
  $HealthReimbursementsTable createAlias(String alias) {
    return $HealthReimbursementsTable(attachedDatabase, alias);
  }
}

class HealthReimbursement extends DataClass
    implements Insertable<HealthReimbursement> {
  final int id;
  final String provider;
  final String invoiceNumber;
  final DateTime documentDate;
  final double claimAmount;
  final String beneficiary;
  final double reimbursedAmount;
  final DateTime? reimbursementDate;
  final double paidAmount;
  final double uncoveredAmount;
  final double reimbursementPercent;
  final int processingDays;
  final bool isCovered;
  const HealthReimbursement({
    required this.id,
    required this.provider,
    required this.invoiceNumber,
    required this.documentDate,
    required this.claimAmount,
    required this.beneficiary,
    required this.reimbursedAmount,
    this.reimbursementDate,
    required this.paidAmount,
    required this.uncoveredAmount,
    required this.reimbursementPercent,
    required this.processingDays,
    required this.isCovered,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider'] = Variable<String>(provider);
    map['invoice_number'] = Variable<String>(invoiceNumber);
    map['document_date'] = Variable<DateTime>(documentDate);
    map['claim_amount'] = Variable<double>(claimAmount);
    map['beneficiary'] = Variable<String>(beneficiary);
    map['reimbursed_amount'] = Variable<double>(reimbursedAmount);
    if (!nullToAbsent || reimbursementDate != null) {
      map['reimbursement_date'] = Variable<DateTime>(reimbursementDate);
    }
    map['paid_amount'] = Variable<double>(paidAmount);
    map['uncovered_amount'] = Variable<double>(uncoveredAmount);
    map['reimbursement_percent'] = Variable<double>(reimbursementPercent);
    map['processing_days'] = Variable<int>(processingDays);
    map['is_covered'] = Variable<bool>(isCovered);
    return map;
  }

  HealthReimbursementsCompanion toCompanion(bool nullToAbsent) {
    return HealthReimbursementsCompanion(
      id: Value(id),
      provider: Value(provider),
      invoiceNumber: Value(invoiceNumber),
      documentDate: Value(documentDate),
      claimAmount: Value(claimAmount),
      beneficiary: Value(beneficiary),
      reimbursedAmount: Value(reimbursedAmount),
      reimbursementDate: reimbursementDate == null && nullToAbsent
          ? const Value.absent()
          : Value(reimbursementDate),
      paidAmount: Value(paidAmount),
      uncoveredAmount: Value(uncoveredAmount),
      reimbursementPercent: Value(reimbursementPercent),
      processingDays: Value(processingDays),
      isCovered: Value(isCovered),
    );
  }

  factory HealthReimbursement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthReimbursement(
      id: serializer.fromJson<int>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      invoiceNumber: serializer.fromJson<String>(json['invoiceNumber']),
      documentDate: serializer.fromJson<DateTime>(json['documentDate']),
      claimAmount: serializer.fromJson<double>(json['claimAmount']),
      beneficiary: serializer.fromJson<String>(json['beneficiary']),
      reimbursedAmount: serializer.fromJson<double>(json['reimbursedAmount']),
      reimbursementDate: serializer.fromJson<DateTime?>(
        json['reimbursementDate'],
      ),
      paidAmount: serializer.fromJson<double>(json['paidAmount']),
      uncoveredAmount: serializer.fromJson<double>(json['uncoveredAmount']),
      reimbursementPercent: serializer.fromJson<double>(
        json['reimbursementPercent'],
      ),
      processingDays: serializer.fromJson<int>(json['processingDays']),
      isCovered: serializer.fromJson<bool>(json['isCovered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'provider': serializer.toJson<String>(provider),
      'invoiceNumber': serializer.toJson<String>(invoiceNumber),
      'documentDate': serializer.toJson<DateTime>(documentDate),
      'claimAmount': serializer.toJson<double>(claimAmount),
      'beneficiary': serializer.toJson<String>(beneficiary),
      'reimbursedAmount': serializer.toJson<double>(reimbursedAmount),
      'reimbursementDate': serializer.toJson<DateTime?>(reimbursementDate),
      'paidAmount': serializer.toJson<double>(paidAmount),
      'uncoveredAmount': serializer.toJson<double>(uncoveredAmount),
      'reimbursementPercent': serializer.toJson<double>(reimbursementPercent),
      'processingDays': serializer.toJson<int>(processingDays),
      'isCovered': serializer.toJson<bool>(isCovered),
    };
  }

  HealthReimbursement copyWith({
    int? id,
    String? provider,
    String? invoiceNumber,
    DateTime? documentDate,
    double? claimAmount,
    String? beneficiary,
    double? reimbursedAmount,
    Value<DateTime?> reimbursementDate = const Value.absent(),
    double? paidAmount,
    double? uncoveredAmount,
    double? reimbursementPercent,
    int? processingDays,
    bool? isCovered,
  }) => HealthReimbursement(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    documentDate: documentDate ?? this.documentDate,
    claimAmount: claimAmount ?? this.claimAmount,
    beneficiary: beneficiary ?? this.beneficiary,
    reimbursedAmount: reimbursedAmount ?? this.reimbursedAmount,
    reimbursementDate: reimbursementDate.present
        ? reimbursementDate.value
        : this.reimbursementDate,
    paidAmount: paidAmount ?? this.paidAmount,
    uncoveredAmount: uncoveredAmount ?? this.uncoveredAmount,
    reimbursementPercent: reimbursementPercent ?? this.reimbursementPercent,
    processingDays: processingDays ?? this.processingDays,
    isCovered: isCovered ?? this.isCovered,
  );
  HealthReimbursement copyWithCompanion(HealthReimbursementsCompanion data) {
    return HealthReimbursement(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      invoiceNumber: data.invoiceNumber.present
          ? data.invoiceNumber.value
          : this.invoiceNumber,
      documentDate: data.documentDate.present
          ? data.documentDate.value
          : this.documentDate,
      claimAmount: data.claimAmount.present
          ? data.claimAmount.value
          : this.claimAmount,
      beneficiary: data.beneficiary.present
          ? data.beneficiary.value
          : this.beneficiary,
      reimbursedAmount: data.reimbursedAmount.present
          ? data.reimbursedAmount.value
          : this.reimbursedAmount,
      reimbursementDate: data.reimbursementDate.present
          ? data.reimbursementDate.value
          : this.reimbursementDate,
      paidAmount: data.paidAmount.present
          ? data.paidAmount.value
          : this.paidAmount,
      uncoveredAmount: data.uncoveredAmount.present
          ? data.uncoveredAmount.value
          : this.uncoveredAmount,
      reimbursementPercent: data.reimbursementPercent.present
          ? data.reimbursementPercent.value
          : this.reimbursementPercent,
      processingDays: data.processingDays.present
          ? data.processingDays.value
          : this.processingDays,
      isCovered: data.isCovered.present ? data.isCovered.value : this.isCovered,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthReimbursement(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('documentDate: $documentDate, ')
          ..write('claimAmount: $claimAmount, ')
          ..write('beneficiary: $beneficiary, ')
          ..write('reimbursedAmount: $reimbursedAmount, ')
          ..write('reimbursementDate: $reimbursementDate, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('uncoveredAmount: $uncoveredAmount, ')
          ..write('reimbursementPercent: $reimbursementPercent, ')
          ..write('processingDays: $processingDays, ')
          ..write('isCovered: $isCovered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    invoiceNumber,
    documentDate,
    claimAmount,
    beneficiary,
    reimbursedAmount,
    reimbursementDate,
    paidAmount,
    uncoveredAmount,
    reimbursementPercent,
    processingDays,
    isCovered,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthReimbursement &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.invoiceNumber == this.invoiceNumber &&
          other.documentDate == this.documentDate &&
          other.claimAmount == this.claimAmount &&
          other.beneficiary == this.beneficiary &&
          other.reimbursedAmount == this.reimbursedAmount &&
          other.reimbursementDate == this.reimbursementDate &&
          other.paidAmount == this.paidAmount &&
          other.uncoveredAmount == this.uncoveredAmount &&
          other.reimbursementPercent == this.reimbursementPercent &&
          other.processingDays == this.processingDays &&
          other.isCovered == this.isCovered);
}

class HealthReimbursementsCompanion
    extends UpdateCompanion<HealthReimbursement> {
  final Value<int> id;
  final Value<String> provider;
  final Value<String> invoiceNumber;
  final Value<DateTime> documentDate;
  final Value<double> claimAmount;
  final Value<String> beneficiary;
  final Value<double> reimbursedAmount;
  final Value<DateTime?> reimbursementDate;
  final Value<double> paidAmount;
  final Value<double> uncoveredAmount;
  final Value<double> reimbursementPercent;
  final Value<int> processingDays;
  final Value<bool> isCovered;
  const HealthReimbursementsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.documentDate = const Value.absent(),
    this.claimAmount = const Value.absent(),
    this.beneficiary = const Value.absent(),
    this.reimbursedAmount = const Value.absent(),
    this.reimbursementDate = const Value.absent(),
    this.paidAmount = const Value.absent(),
    this.uncoveredAmount = const Value.absent(),
    this.reimbursementPercent = const Value.absent(),
    this.processingDays = const Value.absent(),
    this.isCovered = const Value.absent(),
  });
  HealthReimbursementsCompanion.insert({
    this.id = const Value.absent(),
    required String provider,
    required String invoiceNumber,
    required DateTime documentDate,
    required double claimAmount,
    required String beneficiary,
    required double reimbursedAmount,
    this.reimbursementDate = const Value.absent(),
    required double paidAmount,
    required double uncoveredAmount,
    required double reimbursementPercent,
    required int processingDays,
    required bool isCovered,
  }) : provider = Value(provider),
       invoiceNumber = Value(invoiceNumber),
       documentDate = Value(documentDate),
       claimAmount = Value(claimAmount),
       beneficiary = Value(beneficiary),
       reimbursedAmount = Value(reimbursedAmount),
       paidAmount = Value(paidAmount),
       uncoveredAmount = Value(uncoveredAmount),
       reimbursementPercent = Value(reimbursementPercent),
       processingDays = Value(processingDays),
       isCovered = Value(isCovered);
  static Insertable<HealthReimbursement> custom({
    Expression<int>? id,
    Expression<String>? provider,
    Expression<String>? invoiceNumber,
    Expression<DateTime>? documentDate,
    Expression<double>? claimAmount,
    Expression<String>? beneficiary,
    Expression<double>? reimbursedAmount,
    Expression<DateTime>? reimbursementDate,
    Expression<double>? paidAmount,
    Expression<double>? uncoveredAmount,
    Expression<double>? reimbursementPercent,
    Expression<int>? processingDays,
    Expression<bool>? isCovered,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (documentDate != null) 'document_date': documentDate,
      if (claimAmount != null) 'claim_amount': claimAmount,
      if (beneficiary != null) 'beneficiary': beneficiary,
      if (reimbursedAmount != null) 'reimbursed_amount': reimbursedAmount,
      if (reimbursementDate != null) 'reimbursement_date': reimbursementDate,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (uncoveredAmount != null) 'uncovered_amount': uncoveredAmount,
      if (reimbursementPercent != null)
        'reimbursement_percent': reimbursementPercent,
      if (processingDays != null) 'processing_days': processingDays,
      if (isCovered != null) 'is_covered': isCovered,
    });
  }

  HealthReimbursementsCompanion copyWith({
    Value<int>? id,
    Value<String>? provider,
    Value<String>? invoiceNumber,
    Value<DateTime>? documentDate,
    Value<double>? claimAmount,
    Value<String>? beneficiary,
    Value<double>? reimbursedAmount,
    Value<DateTime?>? reimbursementDate,
    Value<double>? paidAmount,
    Value<double>? uncoveredAmount,
    Value<double>? reimbursementPercent,
    Value<int>? processingDays,
    Value<bool>? isCovered,
  }) {
    return HealthReimbursementsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      documentDate: documentDate ?? this.documentDate,
      claimAmount: claimAmount ?? this.claimAmount,
      beneficiary: beneficiary ?? this.beneficiary,
      reimbursedAmount: reimbursedAmount ?? this.reimbursedAmount,
      reimbursementDate: reimbursementDate ?? this.reimbursementDate,
      paidAmount: paidAmount ?? this.paidAmount,
      uncoveredAmount: uncoveredAmount ?? this.uncoveredAmount,
      reimbursementPercent: reimbursementPercent ?? this.reimbursementPercent,
      processingDays: processingDays ?? this.processingDays,
      isCovered: isCovered ?? this.isCovered,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (invoiceNumber.present) {
      map['invoice_number'] = Variable<String>(invoiceNumber.value);
    }
    if (documentDate.present) {
      map['document_date'] = Variable<DateTime>(documentDate.value);
    }
    if (claimAmount.present) {
      map['claim_amount'] = Variable<double>(claimAmount.value);
    }
    if (beneficiary.present) {
      map['beneficiary'] = Variable<String>(beneficiary.value);
    }
    if (reimbursedAmount.present) {
      map['reimbursed_amount'] = Variable<double>(reimbursedAmount.value);
    }
    if (reimbursementDate.present) {
      map['reimbursement_date'] = Variable<DateTime>(reimbursementDate.value);
    }
    if (paidAmount.present) {
      map['paid_amount'] = Variable<double>(paidAmount.value);
    }
    if (uncoveredAmount.present) {
      map['uncovered_amount'] = Variable<double>(uncoveredAmount.value);
    }
    if (reimbursementPercent.present) {
      map['reimbursement_percent'] = Variable<double>(
        reimbursementPercent.value,
      );
    }
    if (processingDays.present) {
      map['processing_days'] = Variable<int>(processingDays.value);
    }
    if (isCovered.present) {
      map['is_covered'] = Variable<bool>(isCovered.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthReimbursementsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('documentDate: $documentDate, ')
          ..write('claimAmount: $claimAmount, ')
          ..write('beneficiary: $beneficiary, ')
          ..write('reimbursedAmount: $reimbursedAmount, ')
          ..write('reimbursementDate: $reimbursementDate, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('uncoveredAmount: $uncoveredAmount, ')
          ..write('reimbursementPercent: $reimbursementPercent, ')
          ..write('processingDays: $processingDays, ')
          ..write('isCovered: $isCovered')
          ..write(')'))
        .toString();
  }
}

class $AppConfigsTable extends AppConfigs
    with TableInfo<$AppConfigsTable, AppConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppConfig(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
    );
  }

  @override
  $AppConfigsTable createAlias(String alias) {
    return $AppConfigsTable(attachedDatabase, alias);
  }
}

class AppConfig extends DataClass implements Insertable<AppConfig> {
  final String key;
  final String value;
  final String description;
  const AppConfig({
    required this.key,
    required this.value,
    required this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['description'] = Variable<String>(description);
    return map;
  }

  AppConfigsCompanion toCompanion(bool nullToAbsent) {
    return AppConfigsCompanion(
      key: Value(key),
      value: Value(value),
      description: Value(description),
    );
  }

  factory AppConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppConfig(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'description': serializer.toJson<String>(description),
    };
  }

  AppConfig copyWith({String? key, String? value, String? description}) =>
      AppConfig(
        key: key ?? this.key,
        value: value ?? this.value,
        description: description ?? this.description,
      );
  AppConfig copyWithCompanion(AppConfigsCompanion data) {
    return AppConfig(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppConfig(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppConfig &&
          other.key == this.key &&
          other.value == this.value &&
          other.description == this.description);
}

class AppConfigsCompanion extends UpdateCompanion<AppConfig> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> description;
  final Value<int> rowid;
  const AppConfigsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppConfigsCompanion.insert({
    required String key,
    required String value,
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppConfig> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppConfigsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<String>? description,
    Value<int>? rowid,
  }) {
    return AppConfigsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportConfigsTable extends ImportConfigs
    with TableInfo<$ImportConfigsTable, ImportConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _skipRowsMeta = const VerificationMeta(
    'skipRows',
  );
  @override
  late final GeneratedColumn<int> skipRows = GeneratedColumn<int>(
    'skip_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mappingsJsonMeta = const VerificationMeta(
    'mappingsJson',
  );
  @override
  late final GeneratedColumn<String> mappingsJson = GeneratedColumn<String>(
    'mappings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _formulaJsonMeta = const VerificationMeta(
    'formulaJson',
  );
  @override
  late final GeneratedColumn<String> formulaJson = GeneratedColumn<String>(
    'formula_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _hashColumnsJsonMeta = const VerificationMeta(
    'hashColumnsJson',
  );
  @override
  late final GeneratedColumn<String> hashColumnsJson = GeneratedColumn<String>(
    'hash_columns_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _numberLocaleMeta = const VerificationMeta(
    'numberLocale',
  );
  @override
  late final GeneratedColumn<String> numberLocale = GeneratedColumn<String>(
    'number_locale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    skipRows,
    mappingsJson,
    formulaJson,
    hashColumnsJson,
    numberLocale,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('skip_rows')) {
      context.handle(
        _skipRowsMeta,
        skipRows.isAcceptableOrUnknown(data['skip_rows']!, _skipRowsMeta),
      );
    }
    if (data.containsKey('mappings_json')) {
      context.handle(
        _mappingsJsonMeta,
        mappingsJson.isAcceptableOrUnknown(
          data['mappings_json']!,
          _mappingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('formula_json')) {
      context.handle(
        _formulaJsonMeta,
        formulaJson.isAcceptableOrUnknown(
          data['formula_json']!,
          _formulaJsonMeta,
        ),
      );
    }
    if (data.containsKey('hash_columns_json')) {
      context.handle(
        _hashColumnsJsonMeta,
        hashColumnsJson.isAcceptableOrUnknown(
          data['hash_columns_json']!,
          _hashColumnsJsonMeta,
        ),
      );
    }
    if (data.containsKey('number_locale')) {
      context.handle(
        _numberLocaleMeta,
        numberLocale.isAcceptableOrUnknown(
          data['number_locale']!,
          _numberLocaleMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      skipRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skip_rows'],
      )!,
      mappingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mappings_json'],
      )!,
      formulaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formula_json'],
      )!,
      hashColumnsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash_columns_json'],
      )!,
      numberLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number_locale'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ImportConfigsTable createAlias(String alias) {
    return $ImportConfigsTable(attachedDatabase, alias);
  }
}

class ImportConfig extends DataClass implements Insertable<ImportConfig> {
  final int id;
  final int accountId;
  final int skipRows;
  final String mappingsJson;
  final String formulaJson;
  final String hashColumnsJson;

  /// Number-format locale used to parse this account's import files
  /// (e.g. 'it_IT', 'en_US'). NULL means "Auto — use the app locale".
  final String? numberLocale;
  final DateTime updatedAt;
  const ImportConfig({
    required this.id,
    required this.accountId,
    required this.skipRows,
    required this.mappingsJson,
    required this.formulaJson,
    required this.hashColumnsJson,
    this.numberLocale,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['skip_rows'] = Variable<int>(skipRows);
    map['mappings_json'] = Variable<String>(mappingsJson);
    map['formula_json'] = Variable<String>(formulaJson);
    map['hash_columns_json'] = Variable<String>(hashColumnsJson);
    if (!nullToAbsent || numberLocale != null) {
      map['number_locale'] = Variable<String>(numberLocale);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ImportConfigsCompanion toCompanion(bool nullToAbsent) {
    return ImportConfigsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      skipRows: Value(skipRows),
      mappingsJson: Value(mappingsJson),
      formulaJson: Value(formulaJson),
      hashColumnsJson: Value(hashColumnsJson),
      numberLocale: numberLocale == null && nullToAbsent
          ? const Value.absent()
          : Value(numberLocale),
      updatedAt: Value(updatedAt),
    );
  }

  factory ImportConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportConfig(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      skipRows: serializer.fromJson<int>(json['skipRows']),
      mappingsJson: serializer.fromJson<String>(json['mappingsJson']),
      formulaJson: serializer.fromJson<String>(json['formulaJson']),
      hashColumnsJson: serializer.fromJson<String>(json['hashColumnsJson']),
      numberLocale: serializer.fromJson<String?>(json['numberLocale']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'skipRows': serializer.toJson<int>(skipRows),
      'mappingsJson': serializer.toJson<String>(mappingsJson),
      'formulaJson': serializer.toJson<String>(formulaJson),
      'hashColumnsJson': serializer.toJson<String>(hashColumnsJson),
      'numberLocale': serializer.toJson<String?>(numberLocale),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ImportConfig copyWith({
    int? id,
    int? accountId,
    int? skipRows,
    String? mappingsJson,
    String? formulaJson,
    String? hashColumnsJson,
    Value<String?> numberLocale = const Value.absent(),
    DateTime? updatedAt,
  }) => ImportConfig(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    skipRows: skipRows ?? this.skipRows,
    mappingsJson: mappingsJson ?? this.mappingsJson,
    formulaJson: formulaJson ?? this.formulaJson,
    hashColumnsJson: hashColumnsJson ?? this.hashColumnsJson,
    numberLocale: numberLocale.present ? numberLocale.value : this.numberLocale,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ImportConfig copyWithCompanion(ImportConfigsCompanion data) {
    return ImportConfig(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      skipRows: data.skipRows.present ? data.skipRows.value : this.skipRows,
      mappingsJson: data.mappingsJson.present
          ? data.mappingsJson.value
          : this.mappingsJson,
      formulaJson: data.formulaJson.present
          ? data.formulaJson.value
          : this.formulaJson,
      hashColumnsJson: data.hashColumnsJson.present
          ? data.hashColumnsJson.value
          : this.hashColumnsJson,
      numberLocale: data.numberLocale.present
          ? data.numberLocale.value
          : this.numberLocale,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportConfig(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('skipRows: $skipRows, ')
          ..write('mappingsJson: $mappingsJson, ')
          ..write('formulaJson: $formulaJson, ')
          ..write('hashColumnsJson: $hashColumnsJson, ')
          ..write('numberLocale: $numberLocale, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    skipRows,
    mappingsJson,
    formulaJson,
    hashColumnsJson,
    numberLocale,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportConfig &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.skipRows == this.skipRows &&
          other.mappingsJson == this.mappingsJson &&
          other.formulaJson == this.formulaJson &&
          other.hashColumnsJson == this.hashColumnsJson &&
          other.numberLocale == this.numberLocale &&
          other.updatedAt == this.updatedAt);
}

class ImportConfigsCompanion extends UpdateCompanion<ImportConfig> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> skipRows;
  final Value<String> mappingsJson;
  final Value<String> formulaJson;
  final Value<String> hashColumnsJson;
  final Value<String?> numberLocale;
  final Value<DateTime> updatedAt;
  const ImportConfigsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.skipRows = const Value.absent(),
    this.mappingsJson = const Value.absent(),
    this.formulaJson = const Value.absent(),
    this.hashColumnsJson = const Value.absent(),
    this.numberLocale = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ImportConfigsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    this.skipRows = const Value.absent(),
    this.mappingsJson = const Value.absent(),
    this.formulaJson = const Value.absent(),
    this.hashColumnsJson = const Value.absent(),
    this.numberLocale = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<ImportConfig> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? skipRows,
    Expression<String>? mappingsJson,
    Expression<String>? formulaJson,
    Expression<String>? hashColumnsJson,
    Expression<String>? numberLocale,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (skipRows != null) 'skip_rows': skipRows,
      if (mappingsJson != null) 'mappings_json': mappingsJson,
      if (formulaJson != null) 'formula_json': formulaJson,
      if (hashColumnsJson != null) 'hash_columns_json': hashColumnsJson,
      if (numberLocale != null) 'number_locale': numberLocale,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ImportConfigsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? skipRows,
    Value<String>? mappingsJson,
    Value<String>? formulaJson,
    Value<String>? hashColumnsJson,
    Value<String?>? numberLocale,
    Value<DateTime>? updatedAt,
  }) {
    return ImportConfigsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      skipRows: skipRows ?? this.skipRows,
      mappingsJson: mappingsJson ?? this.mappingsJson,
      formulaJson: formulaJson ?? this.formulaJson,
      hashColumnsJson: hashColumnsJson ?? this.hashColumnsJson,
      numberLocale: numberLocale ?? this.numberLocale,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (skipRows.present) {
      map['skip_rows'] = Variable<int>(skipRows.value);
    }
    if (mappingsJson.present) {
      map['mappings_json'] = Variable<String>(mappingsJson.value);
    }
    if (formulaJson.present) {
      map['formula_json'] = Variable<String>(formulaJson.value);
    }
    if (hashColumnsJson.present) {
      map['hash_columns_json'] = Variable<String>(hashColumnsJson.value);
    }
    if (numberLocale.present) {
      map['number_locale'] = Variable<String>(numberLocale.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportConfigsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('skipRows: $skipRows, ')
          ..write('mappingsJson: $mappingsJson, ')
          ..write('formulaJson: $formulaJson, ')
          ..write('hashColumnsJson: $hashColumnsJson, ')
          ..write('numberLocale: $numberLocale, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $IncomesTable extends Incomes with TableInfo<$IncomesTable, Income> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueDateMeta = const VerificationMeta(
    'valueDate',
  );
  @override
  late final GeneratedColumn<DateTime> valueDate = GeneratedColumn<DateTime>(
    'value_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<IncomeType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(IncomeType.income.name),
      ).withConverter<IncomeType>($IncomesTable.$convertertype);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    valueDate,
    amount,
    type,
    currency,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incomes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Income> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value_date')) {
      context.handle(
        _valueDateMeta,
        valueDate.isAcceptableOrUnknown(data['value_date']!, _valueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_valueDateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Income map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Income(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      valueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}value_date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      type: $IncomesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $IncomesTable createAlias(String alias) {
    return $IncomesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<IncomeType, String, String> $convertertype =
      const EnumNameConverter<IncomeType>(IncomeType.values);
}

class Income extends DataClass implements Insertable<Income> {
  final int id;
  final DateTime date;
  final DateTime valueDate;
  final double amount;
  final IncomeType type;
  final String currency;
  final DateTime createdAt;
  const Income({
    required this.id,
    required this.date,
    required this.valueDate,
    required this.amount,
    required this.type,
    required this.currency,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['value_date'] = Variable<DateTime>(valueDate);
    map['amount'] = Variable<double>(amount);
    {
      map['type'] = Variable<String>($IncomesTable.$convertertype.toSql(type));
    }
    map['currency'] = Variable<String>(currency);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  IncomesCompanion toCompanion(bool nullToAbsent) {
    return IncomesCompanion(
      id: Value(id),
      date: Value(date),
      valueDate: Value(valueDate),
      amount: Value(amount),
      type: Value(type),
      currency: Value(currency),
      createdAt: Value(createdAt),
    );
  }

  factory Income.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Income(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      valueDate: serializer.fromJson<DateTime>(json['valueDate']),
      amount: serializer.fromJson<double>(json['amount']),
      type: $IncomesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      currency: serializer.fromJson<String>(json['currency']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'valueDate': serializer.toJson<DateTime>(valueDate),
      'amount': serializer.toJson<double>(amount),
      'type': serializer.toJson<String>(
        $IncomesTable.$convertertype.toJson(type),
      ),
      'currency': serializer.toJson<String>(currency),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Income copyWith({
    int? id,
    DateTime? date,
    DateTime? valueDate,
    double? amount,
    IncomeType? type,
    String? currency,
    DateTime? createdAt,
  }) => Income(
    id: id ?? this.id,
    date: date ?? this.date,
    valueDate: valueDate ?? this.valueDate,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    createdAt: createdAt ?? this.createdAt,
  );
  Income copyWithCompanion(IncomesCompanion data) {
    return Income(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      valueDate: data.valueDate.present ? data.valueDate.value : this.valueDate,
      amount: data.amount.present ? data.amount.value : this.amount,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Income(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('valueDate: $valueDate, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, valueDate, amount, type, currency, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Income &&
          other.id == this.id &&
          other.date == this.date &&
          other.valueDate == this.valueDate &&
          other.amount == this.amount &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.createdAt == this.createdAt);
}

class IncomesCompanion extends UpdateCompanion<Income> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<DateTime> valueDate;
  final Value<double> amount;
  final Value<IncomeType> type;
  final Value<String> currency;
  final Value<DateTime> createdAt;
  const IncomesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.valueDate = const Value.absent(),
    this.amount = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  IncomesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required DateTime valueDate,
    required double amount,
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : date = Value(date),
       valueDate = Value(valueDate),
       amount = Value(amount);
  static Insertable<Income> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<DateTime>? valueDate,
    Expression<double>? amount,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (valueDate != null) 'value_date': valueDate,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  IncomesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<DateTime>? valueDate,
    Value<double>? amount,
    Value<IncomeType>? type,
    Value<String>? currency,
    Value<DateTime>? createdAt,
  }) {
    return IncomesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      valueDate: valueDate ?? this.valueDate,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (valueDate.present) {
      map['value_date'] = Variable<DateTime>(valueDate.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $IncomesTable.$convertertype.toSql(type.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncomesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('valueDate: $valueDate, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AssetCompositionsTable extends AssetCompositions
    with TableInfo<$AssetCompositionsTable, AssetComposition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetCompositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<int> assetId = GeneratedColumn<int>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assets (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    type,
    name,
    weight,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_compositions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetComposition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetComposition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetComposition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asset_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AssetCompositionsTable createAlias(String alias) {
    return $AssetCompositionsTable(attachedDatabase, alias);
  }
}

class AssetComposition extends DataClass
    implements Insertable<AssetComposition> {
  final int id;
  final int assetId;
  final String type;
  final String name;
  final double weight;
  final DateTime updatedAt;
  const AssetComposition({
    required this.id,
    required this.assetId,
    required this.type,
    required this.name,
    required this.weight,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<int>(assetId);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['weight'] = Variable<double>(weight);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssetCompositionsCompanion toCompanion(bool nullToAbsent) {
    return AssetCompositionsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      type: Value(type),
      name: Value(name),
      weight: Value(weight),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssetComposition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetComposition(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<int>(json['assetId']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      weight: serializer.fromJson<double>(json['weight']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<int>(assetId),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'weight': serializer.toJson<double>(weight),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssetComposition copyWith({
    int? id,
    int? assetId,
    String? type,
    String? name,
    double? weight,
    DateTime? updatedAt,
  }) => AssetComposition(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    type: type ?? this.type,
    name: name ?? this.name,
    weight: weight ?? this.weight,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssetComposition copyWithCompanion(AssetCompositionsCompanion data) {
    return AssetComposition(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      weight: data.weight.present ? data.weight.value : this.weight,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetComposition(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('weight: $weight, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, assetId, type, name, weight, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetComposition &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.type == this.type &&
          other.name == this.name &&
          other.weight == this.weight &&
          other.updatedAt == this.updatedAt);
}

class AssetCompositionsCompanion extends UpdateCompanion<AssetComposition> {
  final Value<int> id;
  final Value<int> assetId;
  final Value<String> type;
  final Value<String> name;
  final Value<double> weight;
  final Value<DateTime> updatedAt;
  const AssetCompositionsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.weight = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AssetCompositionsCompanion.insert({
    this.id = const Value.absent(),
    required int assetId,
    required String type,
    required String name,
    required double weight,
    this.updatedAt = const Value.absent(),
  }) : assetId = Value(assetId),
       type = Value(type),
       name = Value(name),
       weight = Value(weight);
  static Insertable<AssetComposition> custom({
    Expression<int>? id,
    Expression<int>? assetId,
    Expression<String>? type,
    Expression<String>? name,
    Expression<double>? weight,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (weight != null) 'weight': weight,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AssetCompositionsCompanion copyWith({
    Value<int>? id,
    Value<int>? assetId,
    Value<String>? type,
    Value<String>? name,
    Value<double>? weight,
    Value<DateTime>? updatedAt,
  }) {
    return AssetCompositionsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      type: type ?? this.type,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetCompositionsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('weight: $weight, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ExtraordinaryEventsTable extends ExtraordinaryEvents
    with TableInfo<$ExtraordinaryEventsTable, ExtraordinaryEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtraordinaryEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventDirection, String>
  direction =
      GeneratedColumn<String>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventDirection>(
        $ExtraordinaryEventsTable.$converterdirection,
      );
  @override
  late final GeneratedColumnWithTypeConverter<EventTreatment, String>
  treatment =
      GeneratedColumn<String>(
        'treatment',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventTreatment>(
        $ExtraordinaryEventsTable.$convertertreatment,
      );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<StepFrequency?, String>
  stepFrequency =
      GeneratedColumn<String>(
        'step_frequency',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<StepFrequency?>(
        $ExtraordinaryEventsTable.$converterstepFrequencyn,
      );
  static const VerificationMeta _spreadStartMeta = const VerificationMeta(
    'spreadStart',
  );
  @override
  late final GeneratedColumn<DateTime> spreadStart = GeneratedColumn<DateTime>(
    'spread_start',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spreadEndMeta = const VerificationMeta(
    'spreadEnd',
  );
  @override
  late final GeneratedColumn<DateTime> spreadEnd = GeneratedColumn<DateTime>(
    'spread_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bufferIdMeta = const VerificationMeta(
    'bufferId',
  );
  @override
  late final GeneratedColumn<int> bufferId = GeneratedColumn<int>(
    'buffer_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES buffers (id)',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isEphemeralMeta = const VerificationMeta(
    'isEphemeral',
  );
  @override
  late final GeneratedColumn<bool> isEphemeral = GeneratedColumn<bool>(
    'is_ephemeral',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_ephemeral" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    direction,
    treatment,
    totalAmount,
    currency,
    eventDate,
    transactionId,
    stepFrequency,
    spreadStart,
    spreadEnd,
    bufferId,
    notes,
    isActive,
    isEphemeral,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extraordinary_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtraordinaryEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    } else if (isInserting) {
      context.missing(_eventDateMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('spread_start')) {
      context.handle(
        _spreadStartMeta,
        spreadStart.isAcceptableOrUnknown(
          data['spread_start']!,
          _spreadStartMeta,
        ),
      );
    }
    if (data.containsKey('spread_end')) {
      context.handle(
        _spreadEndMeta,
        spreadEnd.isAcceptableOrUnknown(data['spread_end']!, _spreadEndMeta),
      );
    }
    if (data.containsKey('buffer_id')) {
      context.handle(
        _bufferIdMeta,
        bufferId.isAcceptableOrUnknown(data['buffer_id']!, _bufferIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_ephemeral')) {
      context.handle(
        _isEphemeralMeta,
        isEphemeral.isAcceptableOrUnknown(
          data['is_ephemeral']!,
          _isEphemeralMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtraordinaryEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtraordinaryEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      direction: $ExtraordinaryEventsTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      treatment: $ExtraordinaryEventsTable.$convertertreatment.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}treatment'],
        )!,
      ),
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      ),
      stepFrequency: $ExtraordinaryEventsTable.$converterstepFrequencyn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}step_frequency'],
        ),
      ),
      spreadStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}spread_start'],
      ),
      spreadEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}spread_end'],
      ),
      bufferId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isEphemeral: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_ephemeral'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExtraordinaryEventsTable createAlias(String alias) {
    return $ExtraordinaryEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventDirection, String, String>
  $converterdirection = const EnumNameConverter<EventDirection>(
    EventDirection.values,
  );
  static JsonTypeConverter2<EventTreatment, String, String>
  $convertertreatment = const EnumNameConverter<EventTreatment>(
    EventTreatment.values,
  );
  static JsonTypeConverter2<StepFrequency, String, String>
  $converterstepFrequency = const EnumNameConverter<StepFrequency>(
    StepFrequency.values,
  );
  static JsonTypeConverter2<StepFrequency?, String?, String?>
  $converterstepFrequencyn = JsonTypeConverter2.asNullable(
    $converterstepFrequency,
  );
}

class ExtraordinaryEvent extends DataClass
    implements Insertable<ExtraordinaryEvent> {
  final int id;
  final String name;
  final EventDirection direction;
  final EventTreatment treatment;
  final double totalAmount;
  final String currency;
  final DateTime eventDate;
  final int? transactionId;
  final StepFrequency? stepFrequency;
  final DateTime? spreadStart;
  final DateTime? spreadEnd;
  final int? bufferId;
  final String? notes;
  final bool isActive;

  /// Inflow-only flag for "money I don't have but can spend" — i.e. a line
  /// of credit. Ephemeral inflows belong to Cash (negated) but never to
  /// Saving. Only meaningful for direction=inflow + treatment=instant.
  final bool isEphemeral;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ExtraordinaryEvent({
    required this.id,
    required this.name,
    required this.direction,
    required this.treatment,
    required this.totalAmount,
    required this.currency,
    required this.eventDate,
    this.transactionId,
    this.stepFrequency,
    this.spreadStart,
    this.spreadEnd,
    this.bufferId,
    this.notes,
    required this.isActive,
    required this.isEphemeral,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['direction'] = Variable<String>(
        $ExtraordinaryEventsTable.$converterdirection.toSql(direction),
      );
    }
    {
      map['treatment'] = Variable<String>(
        $ExtraordinaryEventsTable.$convertertreatment.toSql(treatment),
      );
    }
    map['total_amount'] = Variable<double>(totalAmount);
    map['currency'] = Variable<String>(currency);
    map['event_date'] = Variable<DateTime>(eventDate);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    if (!nullToAbsent || stepFrequency != null) {
      map['step_frequency'] = Variable<String>(
        $ExtraordinaryEventsTable.$converterstepFrequencyn.toSql(stepFrequency),
      );
    }
    if (!nullToAbsent || spreadStart != null) {
      map['spread_start'] = Variable<DateTime>(spreadStart);
    }
    if (!nullToAbsent || spreadEnd != null) {
      map['spread_end'] = Variable<DateTime>(spreadEnd);
    }
    if (!nullToAbsent || bufferId != null) {
      map['buffer_id'] = Variable<int>(bufferId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['is_ephemeral'] = Variable<bool>(isEphemeral);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExtraordinaryEventsCompanion toCompanion(bool nullToAbsent) {
    return ExtraordinaryEventsCompanion(
      id: Value(id),
      name: Value(name),
      direction: Value(direction),
      treatment: Value(treatment),
      totalAmount: Value(totalAmount),
      currency: Value(currency),
      eventDate: Value(eventDate),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      stepFrequency: stepFrequency == null && nullToAbsent
          ? const Value.absent()
          : Value(stepFrequency),
      spreadStart: spreadStart == null && nullToAbsent
          ? const Value.absent()
          : Value(spreadStart),
      spreadEnd: spreadEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(spreadEnd),
      bufferId: bufferId == null && nullToAbsent
          ? const Value.absent()
          : Value(bufferId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isActive: Value(isActive),
      isEphemeral: Value(isEphemeral),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExtraordinaryEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtraordinaryEvent(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      direction: $ExtraordinaryEventsTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      treatment: $ExtraordinaryEventsTable.$convertertreatment.fromJson(
        serializer.fromJson<String>(json['treatment']),
      ),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      currency: serializer.fromJson<String>(json['currency']),
      eventDate: serializer.fromJson<DateTime>(json['eventDate']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      stepFrequency: $ExtraordinaryEventsTable.$converterstepFrequencyn
          .fromJson(serializer.fromJson<String?>(json['stepFrequency'])),
      spreadStart: serializer.fromJson<DateTime?>(json['spreadStart']),
      spreadEnd: serializer.fromJson<DateTime?>(json['spreadEnd']),
      bufferId: serializer.fromJson<int?>(json['bufferId']),
      notes: serializer.fromJson<String?>(json['notes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isEphemeral: serializer.fromJson<bool>(json['isEphemeral']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'direction': serializer.toJson<String>(
        $ExtraordinaryEventsTable.$converterdirection.toJson(direction),
      ),
      'treatment': serializer.toJson<String>(
        $ExtraordinaryEventsTable.$convertertreatment.toJson(treatment),
      ),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'currency': serializer.toJson<String>(currency),
      'eventDate': serializer.toJson<DateTime>(eventDate),
      'transactionId': serializer.toJson<int?>(transactionId),
      'stepFrequency': serializer.toJson<String?>(
        $ExtraordinaryEventsTable.$converterstepFrequencyn.toJson(
          stepFrequency,
        ),
      ),
      'spreadStart': serializer.toJson<DateTime?>(spreadStart),
      'spreadEnd': serializer.toJson<DateTime?>(spreadEnd),
      'bufferId': serializer.toJson<int?>(bufferId),
      'notes': serializer.toJson<String?>(notes),
      'isActive': serializer.toJson<bool>(isActive),
      'isEphemeral': serializer.toJson<bool>(isEphemeral),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExtraordinaryEvent copyWith({
    int? id,
    String? name,
    EventDirection? direction,
    EventTreatment? treatment,
    double? totalAmount,
    String? currency,
    DateTime? eventDate,
    Value<int?> transactionId = const Value.absent(),
    Value<StepFrequency?> stepFrequency = const Value.absent(),
    Value<DateTime?> spreadStart = const Value.absent(),
    Value<DateTime?> spreadEnd = const Value.absent(),
    Value<int?> bufferId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? isActive,
    bool? isEphemeral,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExtraordinaryEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    direction: direction ?? this.direction,
    treatment: treatment ?? this.treatment,
    totalAmount: totalAmount ?? this.totalAmount,
    currency: currency ?? this.currency,
    eventDate: eventDate ?? this.eventDate,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    stepFrequency: stepFrequency.present
        ? stepFrequency.value
        : this.stepFrequency,
    spreadStart: spreadStart.present ? spreadStart.value : this.spreadStart,
    spreadEnd: spreadEnd.present ? spreadEnd.value : this.spreadEnd,
    bufferId: bufferId.present ? bufferId.value : this.bufferId,
    notes: notes.present ? notes.value : this.notes,
    isActive: isActive ?? this.isActive,
    isEphemeral: isEphemeral ?? this.isEphemeral,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExtraordinaryEvent copyWithCompanion(ExtraordinaryEventsCompanion data) {
    return ExtraordinaryEvent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      direction: data.direction.present ? data.direction.value : this.direction,
      treatment: data.treatment.present ? data.treatment.value : this.treatment,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      currency: data.currency.present ? data.currency.value : this.currency,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      stepFrequency: data.stepFrequency.present
          ? data.stepFrequency.value
          : this.stepFrequency,
      spreadStart: data.spreadStart.present
          ? data.spreadStart.value
          : this.spreadStart,
      spreadEnd: data.spreadEnd.present ? data.spreadEnd.value : this.spreadEnd,
      bufferId: data.bufferId.present ? data.bufferId.value : this.bufferId,
      notes: data.notes.present ? data.notes.value : this.notes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isEphemeral: data.isEphemeral.present
          ? data.isEphemeral.value
          : this.isEphemeral,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtraordinaryEvent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('direction: $direction, ')
          ..write('treatment: $treatment, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currency: $currency, ')
          ..write('eventDate: $eventDate, ')
          ..write('transactionId: $transactionId, ')
          ..write('stepFrequency: $stepFrequency, ')
          ..write('spreadStart: $spreadStart, ')
          ..write('spreadEnd: $spreadEnd, ')
          ..write('bufferId: $bufferId, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('isEphemeral: $isEphemeral, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    direction,
    treatment,
    totalAmount,
    currency,
    eventDate,
    transactionId,
    stepFrequency,
    spreadStart,
    spreadEnd,
    bufferId,
    notes,
    isActive,
    isEphemeral,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtraordinaryEvent &&
          other.id == this.id &&
          other.name == this.name &&
          other.direction == this.direction &&
          other.treatment == this.treatment &&
          other.totalAmount == this.totalAmount &&
          other.currency == this.currency &&
          other.eventDate == this.eventDate &&
          other.transactionId == this.transactionId &&
          other.stepFrequency == this.stepFrequency &&
          other.spreadStart == this.spreadStart &&
          other.spreadEnd == this.spreadEnd &&
          other.bufferId == this.bufferId &&
          other.notes == this.notes &&
          other.isActive == this.isActive &&
          other.isEphemeral == this.isEphemeral &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExtraordinaryEventsCompanion extends UpdateCompanion<ExtraordinaryEvent> {
  final Value<int> id;
  final Value<String> name;
  final Value<EventDirection> direction;
  final Value<EventTreatment> treatment;
  final Value<double> totalAmount;
  final Value<String> currency;
  final Value<DateTime> eventDate;
  final Value<int?> transactionId;
  final Value<StepFrequency?> stepFrequency;
  final Value<DateTime?> spreadStart;
  final Value<DateTime?> spreadEnd;
  final Value<int?> bufferId;
  final Value<String?> notes;
  final Value<bool> isActive;
  final Value<bool> isEphemeral;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ExtraordinaryEventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.direction = const Value.absent(),
    this.treatment = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.currency = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.stepFrequency = const Value.absent(),
    this.spreadStart = const Value.absent(),
    this.spreadEnd = const Value.absent(),
    this.bufferId = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isEphemeral = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ExtraordinaryEventsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required EventDirection direction,
    required EventTreatment treatment,
    required double totalAmount,
    this.currency = const Value.absent(),
    required DateTime eventDate,
    this.transactionId = const Value.absent(),
    this.stepFrequency = const Value.absent(),
    this.spreadStart = const Value.absent(),
    this.spreadEnd = const Value.absent(),
    this.bufferId = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isEphemeral = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       direction = Value(direction),
       treatment = Value(treatment),
       totalAmount = Value(totalAmount),
       eventDate = Value(eventDate);
  static Insertable<ExtraordinaryEvent> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? direction,
    Expression<String>? treatment,
    Expression<double>? totalAmount,
    Expression<String>? currency,
    Expression<DateTime>? eventDate,
    Expression<int>? transactionId,
    Expression<String>? stepFrequency,
    Expression<DateTime>? spreadStart,
    Expression<DateTime>? spreadEnd,
    Expression<int>? bufferId,
    Expression<String>? notes,
    Expression<bool>? isActive,
    Expression<bool>? isEphemeral,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (direction != null) 'direction': direction,
      if (treatment != null) 'treatment': treatment,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (currency != null) 'currency': currency,
      if (eventDate != null) 'event_date': eventDate,
      if (transactionId != null) 'transaction_id': transactionId,
      if (stepFrequency != null) 'step_frequency': stepFrequency,
      if (spreadStart != null) 'spread_start': spreadStart,
      if (spreadEnd != null) 'spread_end': spreadEnd,
      if (bufferId != null) 'buffer_id': bufferId,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      if (isEphemeral != null) 'is_ephemeral': isEphemeral,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ExtraordinaryEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<EventDirection>? direction,
    Value<EventTreatment>? treatment,
    Value<double>? totalAmount,
    Value<String>? currency,
    Value<DateTime>? eventDate,
    Value<int?>? transactionId,
    Value<StepFrequency?>? stepFrequency,
    Value<DateTime?>? spreadStart,
    Value<DateTime?>? spreadEnd,
    Value<int?>? bufferId,
    Value<String?>? notes,
    Value<bool>? isActive,
    Value<bool>? isEphemeral,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ExtraordinaryEventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      direction: direction ?? this.direction,
      treatment: treatment ?? this.treatment,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      eventDate: eventDate ?? this.eventDate,
      transactionId: transactionId ?? this.transactionId,
      stepFrequency: stepFrequency ?? this.stepFrequency,
      spreadStart: spreadStart ?? this.spreadStart,
      spreadEnd: spreadEnd ?? this.spreadEnd,
      bufferId: bufferId ?? this.bufferId,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isEphemeral: isEphemeral ?? this.isEphemeral,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $ExtraordinaryEventsTable.$converterdirection.toSql(direction.value),
      );
    }
    if (treatment.present) {
      map['treatment'] = Variable<String>(
        $ExtraordinaryEventsTable.$convertertreatment.toSql(treatment.value),
      );
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (stepFrequency.present) {
      map['step_frequency'] = Variable<String>(
        $ExtraordinaryEventsTable.$converterstepFrequencyn.toSql(
          stepFrequency.value,
        ),
      );
    }
    if (spreadStart.present) {
      map['spread_start'] = Variable<DateTime>(spreadStart.value);
    }
    if (spreadEnd.present) {
      map['spread_end'] = Variable<DateTime>(spreadEnd.value);
    }
    if (bufferId.present) {
      map['buffer_id'] = Variable<int>(bufferId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isEphemeral.present) {
      map['is_ephemeral'] = Variable<bool>(isEphemeral.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtraordinaryEventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('direction: $direction, ')
          ..write('treatment: $treatment, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currency: $currency, ')
          ..write('eventDate: $eventDate, ')
          ..write('transactionId: $transactionId, ')
          ..write('stepFrequency: $stepFrequency, ')
          ..write('spreadStart: $spreadStart, ')
          ..write('spreadEnd: $spreadEnd, ')
          ..write('bufferId: $bufferId, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('isEphemeral: $isEphemeral, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ExtraordinaryEventEntriesTable extends ExtraordinaryEventEntries
    with TableInfo<$ExtraordinaryEventEntriesTable, ExtraordinaryEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtraordinaryEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES extraordinary_events (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventEntryKind, String>
  entryKind =
      GeneratedColumn<String>(
        'entry_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EventEntryKind>(
        $ExtraordinaryEventEntriesTable.$converterentryKind,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cumulativeMeta = const VerificationMeta(
    'cumulative',
  );
  @override
  late final GeneratedColumn<double> cumulative = GeneratedColumn<double>(
    'cumulative',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remainingMeta = const VerificationMeta(
    'remaining',
  );
  @override
  late final GeneratedColumn<double> remaining = GeneratedColumn<double>(
    'remaining',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    date,
    amount,
    entryKind,
    description,
    cumulative,
    remaining,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extraordinary_event_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtraordinaryEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cumulative')) {
      context.handle(
        _cumulativeMeta,
        cumulative.isAcceptableOrUnknown(data['cumulative']!, _cumulativeMeta),
      );
    }
    if (data.containsKey('remaining')) {
      context.handle(
        _remainingMeta,
        remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtraordinaryEventEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtraordinaryEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      entryKind: $ExtraordinaryEventEntriesTable.$converterentryKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entry_kind'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      cumulative: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cumulative'],
      ),
      remaining: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExtraordinaryEventEntriesTable createAlias(String alias) {
    return $ExtraordinaryEventEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventEntryKind, String, String>
  $converterentryKind = const EnumNameConverter<EventEntryKind>(
    EventEntryKind.values,
  );
}

class ExtraordinaryEventEntry extends DataClass
    implements Insertable<ExtraordinaryEventEntry> {
  final int id;
  final int eventId;
  final DateTime date;
  final double amount;
  final EventEntryKind entryKind;
  final String description;
  final double? cumulative;
  final double? remaining;
  final DateTime createdAt;
  const ExtraordinaryEventEntry({
    required this.id,
    required this.eventId,
    required this.date,
    required this.amount,
    required this.entryKind,
    required this.description,
    this.cumulative,
    this.remaining,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['date'] = Variable<DateTime>(date);
    map['amount'] = Variable<double>(amount);
    {
      map['entry_kind'] = Variable<String>(
        $ExtraordinaryEventEntriesTable.$converterentryKind.toSql(entryKind),
      );
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || cumulative != null) {
      map['cumulative'] = Variable<double>(cumulative);
    }
    if (!nullToAbsent || remaining != null) {
      map['remaining'] = Variable<double>(remaining);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExtraordinaryEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return ExtraordinaryEventEntriesCompanion(
      id: Value(id),
      eventId: Value(eventId),
      date: Value(date),
      amount: Value(amount),
      entryKind: Value(entryKind),
      description: Value(description),
      cumulative: cumulative == null && nullToAbsent
          ? const Value.absent()
          : Value(cumulative),
      remaining: remaining == null && nullToAbsent
          ? const Value.absent()
          : Value(remaining),
      createdAt: Value(createdAt),
    );
  }

  factory ExtraordinaryEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtraordinaryEventEntry(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amount: serializer.fromJson<double>(json['amount']),
      entryKind: $ExtraordinaryEventEntriesTable.$converterentryKind.fromJson(
        serializer.fromJson<String>(json['entryKind']),
      ),
      description: serializer.fromJson<String>(json['description']),
      cumulative: serializer.fromJson<double?>(json['cumulative']),
      remaining: serializer.fromJson<double?>(json['remaining']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'date': serializer.toJson<DateTime>(date),
      'amount': serializer.toJson<double>(amount),
      'entryKind': serializer.toJson<String>(
        $ExtraordinaryEventEntriesTable.$converterentryKind.toJson(entryKind),
      ),
      'description': serializer.toJson<String>(description),
      'cumulative': serializer.toJson<double?>(cumulative),
      'remaining': serializer.toJson<double?>(remaining),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExtraordinaryEventEntry copyWith({
    int? id,
    int? eventId,
    DateTime? date,
    double? amount,
    EventEntryKind? entryKind,
    String? description,
    Value<double?> cumulative = const Value.absent(),
    Value<double?> remaining = const Value.absent(),
    DateTime? createdAt,
  }) => ExtraordinaryEventEntry(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    entryKind: entryKind ?? this.entryKind,
    description: description ?? this.description,
    cumulative: cumulative.present ? cumulative.value : this.cumulative,
    remaining: remaining.present ? remaining.value : this.remaining,
    createdAt: createdAt ?? this.createdAt,
  );
  ExtraordinaryEventEntry copyWithCompanion(
    ExtraordinaryEventEntriesCompanion data,
  ) {
    return ExtraordinaryEventEntry(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      date: data.date.present ? data.date.value : this.date,
      amount: data.amount.present ? data.amount.value : this.amount,
      entryKind: data.entryKind.present ? data.entryKind.value : this.entryKind,
      description: data.description.present
          ? data.description.value
          : this.description,
      cumulative: data.cumulative.present
          ? data.cumulative.value
          : this.cumulative,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtraordinaryEventEntry(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('entryKind: $entryKind, ')
          ..write('description: $description, ')
          ..write('cumulative: $cumulative, ')
          ..write('remaining: $remaining, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    date,
    amount,
    entryKind,
    description,
    cumulative,
    remaining,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtraordinaryEventEntry &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.date == this.date &&
          other.amount == this.amount &&
          other.entryKind == this.entryKind &&
          other.description == this.description &&
          other.cumulative == this.cumulative &&
          other.remaining == this.remaining &&
          other.createdAt == this.createdAt);
}

class ExtraordinaryEventEntriesCompanion
    extends UpdateCompanion<ExtraordinaryEventEntry> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<DateTime> date;
  final Value<double> amount;
  final Value<EventEntryKind> entryKind;
  final Value<String> description;
  final Value<double?> cumulative;
  final Value<double?> remaining;
  final Value<DateTime> createdAt;
  const ExtraordinaryEventEntriesCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.date = const Value.absent(),
    this.amount = const Value.absent(),
    this.entryKind = const Value.absent(),
    this.description = const Value.absent(),
    this.cumulative = const Value.absent(),
    this.remaining = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExtraordinaryEventEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required DateTime date,
    required double amount,
    required EventEntryKind entryKind,
    this.description = const Value.absent(),
    this.cumulative = const Value.absent(),
    this.remaining = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : eventId = Value(eventId),
       date = Value(date),
       amount = Value(amount),
       entryKind = Value(entryKind);
  static Insertable<ExtraordinaryEventEntry> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<DateTime>? date,
    Expression<double>? amount,
    Expression<String>? entryKind,
    Expression<String>? description,
    Expression<double>? cumulative,
    Expression<double>? remaining,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (date != null) 'date': date,
      if (amount != null) 'amount': amount,
      if (entryKind != null) 'entry_kind': entryKind,
      if (description != null) 'description': description,
      if (cumulative != null) 'cumulative': cumulative,
      if (remaining != null) 'remaining': remaining,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExtraordinaryEventEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? eventId,
    Value<DateTime>? date,
    Value<double>? amount,
    Value<EventEntryKind>? entryKind,
    Value<String>? description,
    Value<double?>? cumulative,
    Value<double?>? remaining,
    Value<DateTime>? createdAt,
  }) {
    return ExtraordinaryEventEntriesCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      entryKind: entryKind ?? this.entryKind,
      description: description ?? this.description,
      cumulative: cumulative ?? this.cumulative,
      remaining: remaining ?? this.remaining,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (entryKind.present) {
      map['entry_kind'] = Variable<String>(
        $ExtraordinaryEventEntriesTable.$converterentryKind.toSql(
          entryKind.value,
        ),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (cumulative.present) {
      map['cumulative'] = Variable<double>(cumulative.value);
    }
    if (remaining.present) {
      map['remaining'] = Variable<double>(remaining.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtraordinaryEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('entryKind: $entryKind, ')
          ..write('description: $description, ')
          ..write('cumulative: $cumulative, ')
          ..write('remaining: $remaining, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $IntermediariesTable intermediaries = $IntermediariesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $AutoCategorizationRulesTable autoCategorizationRules =
      $AutoCategorizationRulesTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $AssetEventsTable assetEvents = $AssetEventsTable(this);
  late final $AssetSnapshotsTable assetSnapshots = $AssetSnapshotsTable(this);
  late final $BuffersTable buffers = $BuffersTable(this);
  late final $BufferTransactionsTable bufferTransactions =
      $BufferTransactionsTable(this);
  late final $MarketPricesTable marketPrices = $MarketPricesTable(this);
  late final $ExchangeRatesTable exchangeRates = $ExchangeRatesTable(this);
  late final $RegisteredEventsTable registeredEvents = $RegisteredEventsTable(
    this,
  );
  late final $HealthReimbursementsTable healthReimbursements =
      $HealthReimbursementsTable(this);
  late final $AppConfigsTable appConfigs = $AppConfigsTable(this);
  late final $ImportConfigsTable importConfigs = $ImportConfigsTable(this);
  late final $IncomesTable incomes = $IncomesTable(this);
  late final $AssetCompositionsTable assetCompositions =
      $AssetCompositionsTable(this);
  late final $ExtraordinaryEventsTable extraordinaryEvents =
      $ExtraordinaryEventsTable(this);
  late final $ExtraordinaryEventEntriesTable extraordinaryEventEntries =
      $ExtraordinaryEventEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    intermediaries,
    accounts,
    categories,
    transactions,
    autoCategorizationRules,
    assets,
    assetEvents,
    assetSnapshots,
    buffers,
    bufferTransactions,
    marketPrices,
    exchangeRates,
    registeredEvents,
    healthReimbursements,
    appConfigs,
    importConfigs,
    incomes,
    assetCompositions,
    extraordinaryEvents,
    extraordinaryEventEntries,
  ];
}

typedef $$IntermediariesTableCreateCompanionBuilder =
    IntermediariesCompanion Function({
      Value<int> id,
      required String name,
      Value<int> sortOrder,
      Value<String?> defaultImportLocale,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$IntermediariesTableUpdateCompanionBuilder =
    IntermediariesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<String?> defaultImportLocale,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$IntermediariesTableReferences
    extends BaseReferences<_$AppDatabase, $IntermediariesTable, Intermediary> {
  $$IntermediariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$AccountsTable, List<Account>> _accountsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.accounts,
    aliasName: $_aliasNameGenerator(
      db.intermediaries.id,
      db.accounts.intermediaryId,
    ),
  );

  $$AccountsTableProcessedTableManager get accountsRefs {
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.intermediaryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_accountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssetsTable, List<Asset>> _assetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.assets,
    aliasName: $_aliasNameGenerator(
      db.intermediaries.id,
      db.assets.intermediaryId,
    ),
  );

  $$AssetsTableProcessedTableManager get assetsRefs {
    final manager = $$AssetsTableTableManager(
      $_db,
      $_db.assets,
    ).filter((f) => f.intermediaryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_assetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IntermediariesTableFilterComposer
    extends Composer<_$AppDatabase, $IntermediariesTable> {
  $$IntermediariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultImportLocale => $composableBuilder(
    column: $table.defaultImportLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> accountsRefs(
    Expression<bool> Function($$AccountsTableFilterComposer f) f,
  ) {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.intermediaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assetsRefs(
    Expression<bool> Function($$AssetsTableFilterComposer f) f,
  ) {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.intermediaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableFilterComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IntermediariesTableOrderingComposer
    extends Composer<_$AppDatabase, $IntermediariesTable> {
  $$IntermediariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultImportLocale => $composableBuilder(
    column: $table.defaultImportLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntermediariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IntermediariesTable> {
  $$IntermediariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get defaultImportLocale => $composableBuilder(
    column: $table.defaultImportLocale,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> accountsRefs<T extends Object>(
    Expression<T> Function($$AccountsTableAnnotationComposer a) f,
  ) {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.intermediaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assetsRefs<T extends Object>(
    Expression<T> Function($$AssetsTableAnnotationComposer a) f,
  ) {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.intermediaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IntermediariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IntermediariesTable,
          Intermediary,
          $$IntermediariesTableFilterComposer,
          $$IntermediariesTableOrderingComposer,
          $$IntermediariesTableAnnotationComposer,
          $$IntermediariesTableCreateCompanionBuilder,
          $$IntermediariesTableUpdateCompanionBuilder,
          (Intermediary, $$IntermediariesTableReferences),
          Intermediary,
          PrefetchHooks Function({bool accountsRefs, bool assetsRefs})
        > {
  $$IntermediariesTableTableManager(
    _$AppDatabase db,
    $IntermediariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntermediariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntermediariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntermediariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> defaultImportLocale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => IntermediariesCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                defaultImportLocale: defaultImportLocale,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<String?> defaultImportLocale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => IntermediariesCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                defaultImportLocale: defaultImportLocale,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IntermediariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountsRefs = false, assetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (accountsRefs) db.accounts,
                if (assetsRefs) db.assets,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (accountsRefs)
                    await $_getPrefetchedData<
                      Intermediary,
                      $IntermediariesTable,
                      Account
                    >(
                      currentTable: table,
                      referencedTable: $$IntermediariesTableReferences
                          ._accountsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$IntermediariesTableReferences(
                            db,
                            table,
                            p0,
                          ).accountsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.intermediaryId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (assetsRefs)
                    await $_getPrefetchedData<
                      Intermediary,
                      $IntermediariesTable,
                      Asset
                    >(
                      currentTable: table,
                      referencedTable: $$IntermediariesTableReferences
                          ._assetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$IntermediariesTableReferences(
                            db,
                            table,
                            p0,
                          ).assetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.intermediaryId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$IntermediariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IntermediariesTable,
      Intermediary,
      $$IntermediariesTableFilterComposer,
      $$IntermediariesTableOrderingComposer,
      $$IntermediariesTableAnnotationComposer,
      $$IntermediariesTableCreateCompanionBuilder,
      $$IntermediariesTableUpdateCompanionBuilder,
      (Intermediary, $$IntermediariesTableReferences),
      Intermediary,
      PrefetchHooks Function({bool accountsRefs, bool assetsRefs})
    >;
typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      required String name,
      Value<AccountType> type,
      Value<String> currency,
      Value<String> institution,
      Value<int?> intermediaryId,
      Value<bool> isActive,
      Value<bool> includeInNetWorth,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<AccountType> type,
      Value<String> currency,
      Value<String> institution,
      Value<int?> intermediaryId,
      Value<bool> isActive,
      Value<bool> includeInNetWorth,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IntermediariesTable _intermediaryIdTable(_$AppDatabase db) =>
      db.intermediaries.createAlias(
        $_aliasNameGenerator(db.accounts.intermediaryId, db.intermediaries.id),
      );

  $$IntermediariesTableProcessedTableManager? get intermediaryId {
    final $_column = $_itemColumn<int>('intermediary_id');
    if ($_column == null) return null;
    final manager = $$IntermediariesTableTableManager(
      $_db,
      $_db.intermediaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_intermediaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.transactions.accountId),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportConfigsTable, List<ImportConfig>>
  _importConfigsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.importConfigs,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.importConfigs.accountId),
  );

  $$ImportConfigsTableProcessedTableManager get importConfigsRefs {
    final manager = $$ImportConfigsTableTableManager(
      $_db,
      $_db.importConfigs,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_importConfigsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountType, AccountType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$IntermediariesTableFilterComposer get intermediaryId {
    final $$IntermediariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableFilterComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importConfigsRefs(
    Expression<bool> Function($$ImportConfigsTableFilterComposer f) f,
  ) {
    final $$ImportConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importConfigs,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportConfigsTableFilterComposer(
            $db: $db,
            $table: $db.importConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$IntermediariesTableOrderingComposer get intermediaryId {
    final $$IntermediariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableOrderingComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$IntermediariesTableAnnotationComposer get intermediaryId {
    final $$IntermediariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableAnnotationComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> importConfigsRefs<T extends Object>(
    Expression<T> Function($$ImportConfigsTableAnnotationComposer a) f,
  ) {
    final $$ImportConfigsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importConfigs,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportConfigsTableAnnotationComposer(
            $db: $db,
            $table: $db.importConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool intermediaryId,
            bool transactionsRefs,
            bool importConfigsRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountType> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<int?> intermediaryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> includeInNetWorth = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                intermediaryId: intermediaryId,
                isActive: isActive,
                includeInNetWorth: includeInNetWorth,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<AccountType> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<int?> intermediaryId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> includeInNetWorth = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                intermediaryId: intermediaryId,
                isActive: isActive,
                includeInNetWorth: includeInNetWorth,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                intermediaryId = false,
                transactionsRefs = false,
                importConfigsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (importConfigsRefs) db.importConfigs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (intermediaryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.intermediaryId,
                                    referencedTable: $$AccountsTableReferences
                                        ._intermediaryIdTable(db),
                                    referencedColumn: $$AccountsTableReferences
                                        ._intermediaryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (importConfigsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          ImportConfig
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._importConfigsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).importConfigsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool intermediaryId,
        bool transactionsRefs,
        bool importConfigsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required CategoryType type,
      Value<bool> isEssential,
      Value<ExpenseType?> defaultExpenseType,
      Value<String?> icon,
      Value<String?> color,
      Value<int?> parentId,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<CategoryType> type,
      Value<bool> isEssential,
      Value<ExpenseType?> defaultExpenseType,
      Value<String?> icon,
      Value<String?> color,
      Value<int?> parentId,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _parentIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.categories.parentId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.transactions.categoryId,
    ),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $AutoCategorizationRulesTable,
    List<AutoCategorizationRule>
  >
  _autoCategorizationRulesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.autoCategorizationRules,
        aliasName: $_aliasNameGenerator(
          db.categories.id,
          db.autoCategorizationRules.categoryId,
        ),
      );

  $$AutoCategorizationRulesTableProcessedTableManager
  get autoCategorizationRulesRefs {
    final manager = $$AutoCategorizationRulesTableTableManager(
      $_db,
      $_db.autoCategorizationRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _autoCategorizationRulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExpenseType?, ExpenseType, String>
  get defaultExpenseType => $composableBuilder(
    column: $table.defaultExpenseType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get parentId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> autoCategorizationRulesRefs(
    Expression<bool> Function($$AutoCategorizationRulesTableFilterComposer f) f,
  ) {
    final $$AutoCategorizationRulesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.autoCategorizationRules,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AutoCategorizationRulesTableFilterComposer(
                $db: $db,
                $table: $db.autoCategorizationRules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultExpenseType => $composableBuilder(
    column: $table.defaultExpenseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get parentId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isEssential => $composableBuilder(
    column: $table.isEssential,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ExpenseType?, String>
  get defaultExpenseType => $composableBuilder(
    column: $table.defaultExpenseType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get parentId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> autoCategorizationRulesRefs<T extends Object>(
    Expression<T> Function($$AutoCategorizationRulesTableAnnotationComposer a)
    f,
  ) {
    final $$AutoCategorizationRulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.autoCategorizationRules,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AutoCategorizationRulesTableAnnotationComposer(
                $db: $db,
                $table: $db.autoCategorizationRules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool parentId,
            bool transactionsRefs,
            bool autoCategorizationRulesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<CategoryType> type = const Value.absent(),
                Value<bool> isEssential = const Value.absent(),
                Value<ExpenseType?> defaultExpenseType = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                type: type,
                isEssential: isEssential,
                defaultExpenseType: defaultExpenseType,
                icon: icon,
                color: color,
                parentId: parentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required CategoryType type,
                Value<bool> isEssential = const Value.absent(),
                Value<ExpenseType?> defaultExpenseType = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                isEssential: isEssential,
                defaultExpenseType: defaultExpenseType,
                icon: icon,
                color: color,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentId = false,
                transactionsRefs = false,
                autoCategorizationRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (autoCategorizationRulesRefs) db.autoCategorizationRules,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable: $$CategoriesTableReferences
                                        ._parentIdTable(db),
                                    referencedColumn:
                                        $$CategoriesTableReferences
                                            ._parentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (autoCategorizationRulesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          AutoCategorizationRule
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._autoCategorizationRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).autoCategorizationRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool parentId,
        bool transactionsRefs,
        bool autoCategorizationRulesRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required int accountId,
      required DateTime operationDate,
      required DateTime valueDate,
      required double amount,
      Value<double?> balanceAfter,
      Value<String> description,
      Value<String?> descriptionFull,
      Value<TransactionStatus> status,
      Value<int?> categoryId,
      Value<String> currency,
      Value<String> tags,
      Value<ExpenseType?> expenseType,
      Value<String?> rawMetadata,
      Value<String?> importHash,
      Value<DateTime> createdAt,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<DateTime> operationDate,
      Value<DateTime> valueDate,
      Value<double> amount,
      Value<double?> balanceAfter,
      Value<String> description,
      Value<String?> descriptionFull,
      Value<TransactionStatus> status,
      Value<int?> categoryId,
      Value<String> currency,
      Value<String> tags,
      Value<ExpenseType?> expenseType,
      Value<String?> rawMetadata,
      Value<String?> importHash,
      Value<DateTime> createdAt,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.transactions.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.transactions.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BufferTransactionsTable, List<BufferTransaction>>
  _bufferTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.bufferTransactions,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.bufferTransactions.linkedTransactionId,
        ),
      );

  $$BufferTransactionsTableProcessedTableManager get bufferTransactionsRefs {
    final manager =
        $$BufferTransactionsTableTableManager(
          $_db,
          $_db.bufferTransactions,
        ).filter(
          (f) => f.linkedTransactionId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _bufferTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ExtraordinaryEventsTable,
    List<ExtraordinaryEvent>
  >
  _extraordinaryEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.extraordinaryEvents,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.extraordinaryEvents.transactionId,
        ),
      );

  $$ExtraordinaryEventsTableProcessedTableManager get extraordinaryEventsRefs {
    final manager = $$ExtraordinaryEventsTableTableManager(
      $_db,
      $_db.extraordinaryEvents,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _extraordinaryEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descriptionFull => $composableBuilder(
    column: $table.descriptionFull,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionStatus, TransactionStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExpenseType?, ExpenseType, String>
  get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> bufferTransactionsRefs(
    Expression<bool> Function($$BufferTransactionsTableFilterComposer f) f,
  ) {
    final $$BufferTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bufferTransactions,
      getReferencedColumn: (t) => t.linkedTransactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BufferTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.bufferTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> extraordinaryEventsRefs(
    Expression<bool> Function($$ExtraordinaryEventsTableFilterComposer f) f,
  ) {
    final $$ExtraordinaryEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extraordinaryEvents,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtraordinaryEventsTableFilterComposer(
            $db: $db,
            $table: $db.extraordinaryEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionFull => $composableBuilder(
    column: $table.descriptionFull,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expenseType => $composableBuilder(
    column: $table.expenseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get descriptionFull => $composableBuilder(
    column: $table.descriptionFull,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TransactionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExpenseType?, String> get expenseType =>
      $composableBuilder(
        column: $table.expenseType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> bufferTransactionsRefs<T extends Object>(
    Expression<T> Function($$BufferTransactionsTableAnnotationComposer a) f,
  ) {
    final $$BufferTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.bufferTransactions,
          getReferencedColumn: (t) => t.linkedTransactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BufferTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.bufferTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> extraordinaryEventsRefs<T extends Object>(
    Expression<T> Function($$ExtraordinaryEventsTableAnnotationComposer a) f,
  ) {
    final $$ExtraordinaryEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.extraordinaryEvents,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.extraordinaryEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool accountId,
            bool categoryId,
            bool bufferTransactionsRefs,
            bool extraordinaryEventsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<DateTime> operationDate = const Value.absent(),
                Value<DateTime> valueDate = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<double?> balanceAfter = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> descriptionFull = const Value.absent(),
                Value<TransactionStatus> status = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<ExpenseType?> expenseType = const Value.absent(),
                Value<String?> rawMetadata = const Value.absent(),
                Value<String?> importHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                accountId: accountId,
                operationDate: operationDate,
                valueDate: valueDate,
                amount: amount,
                balanceAfter: balanceAfter,
                description: description,
                descriptionFull: descriptionFull,
                status: status,
                categoryId: categoryId,
                currency: currency,
                tags: tags,
                expenseType: expenseType,
                rawMetadata: rawMetadata,
                importHash: importHash,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required DateTime operationDate,
                required DateTime valueDate,
                required double amount,
                Value<double?> balanceAfter = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> descriptionFull = const Value.absent(),
                Value<TransactionStatus> status = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<ExpenseType?> expenseType = const Value.absent(),
                Value<String?> rawMetadata = const Value.absent(),
                Value<String?> importHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                operationDate: operationDate,
                valueDate: valueDate,
                amount: amount,
                balanceAfter: balanceAfter,
                description: description,
                descriptionFull: descriptionFull,
                status: status,
                categoryId: categoryId,
                currency: currency,
                tags: tags,
                expenseType: expenseType,
                rawMetadata: rawMetadata,
                importHash: importHash,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                categoryId = false,
                bufferTransactionsRefs = false,
                extraordinaryEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bufferTransactionsRefs) db.bufferTransactions,
                    if (extraordinaryEventsRefs) db.extraordinaryEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bufferTransactionsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          BufferTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._bufferTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).bufferTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedTransactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (extraordinaryEventsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          ExtraordinaryEvent
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._extraordinaryEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).extraordinaryEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({
        bool accountId,
        bool categoryId,
        bool bufferTransactionsRefs,
        bool extraordinaryEventsRefs,
      })
    >;
typedef $$AutoCategorizationRulesTableCreateCompanionBuilder =
    AutoCategorizationRulesCompanion Function({
      Value<int> id,
      required String pattern,
      required int categoryId,
      Value<int> priority,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$AutoCategorizationRulesTableUpdateCompanionBuilder =
    AutoCategorizationRulesCompanion Function({
      Value<int> id,
      Value<String> pattern,
      Value<int> categoryId,
      Value<int> priority,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

final class $$AutoCategorizationRulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AutoCategorizationRulesTable,
          AutoCategorizationRule
        > {
  $$AutoCategorizationRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(
          db.autoCategorizationRules.categoryId,
          db.categories.id,
        ),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AutoCategorizationRulesTableFilterComposer
    extends Composer<_$AppDatabase, $AutoCategorizationRulesTable> {
  $$AutoCategorizationRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AutoCategorizationRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $AutoCategorizationRulesTable> {
  $$AutoCategorizationRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AutoCategorizationRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AutoCategorizationRulesTable> {
  $$AutoCategorizationRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AutoCategorizationRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AutoCategorizationRulesTable,
          AutoCategorizationRule,
          $$AutoCategorizationRulesTableFilterComposer,
          $$AutoCategorizationRulesTableOrderingComposer,
          $$AutoCategorizationRulesTableAnnotationComposer,
          $$AutoCategorizationRulesTableCreateCompanionBuilder,
          $$AutoCategorizationRulesTableUpdateCompanionBuilder,
          (AutoCategorizationRule, $$AutoCategorizationRulesTableReferences),
          AutoCategorizationRule,
          PrefetchHooks Function({bool categoryId})
        > {
  $$AutoCategorizationRulesTableTableManager(
    _$AppDatabase db,
    $AutoCategorizationRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AutoCategorizationRulesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AutoCategorizationRulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AutoCategorizationRulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AutoCategorizationRulesCompanion(
                id: id,
                pattern: pattern,
                categoryId: categoryId,
                priority: priority,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String pattern,
                required int categoryId,
                Value<int> priority = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AutoCategorizationRulesCompanion.insert(
                id: id,
                pattern: pattern,
                categoryId: categoryId,
                priority: priority,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AutoCategorizationRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$AutoCategorizationRulesTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$AutoCategorizationRulesTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AutoCategorizationRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AutoCategorizationRulesTable,
      AutoCategorizationRule,
      $$AutoCategorizationRulesTableFilterComposer,
      $$AutoCategorizationRulesTableOrderingComposer,
      $$AutoCategorizationRulesTableAnnotationComposer,
      $$AutoCategorizationRulesTableCreateCompanionBuilder,
      $$AutoCategorizationRulesTableUpdateCompanionBuilder,
      (AutoCategorizationRule, $$AutoCategorizationRulesTableReferences),
      AutoCategorizationRule,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$AssetsTableCreateCompanionBuilder =
    AssetsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> ticker,
      Value<String?> isin,
      required AssetType assetType,
      Value<InstrumentType> instrumentType,
      Value<AssetClass> assetClass,
      required int intermediaryId,
      Value<String> assetGroup,
      Value<String> currency,
      Value<String?> exchange,
      Value<String?> yahooTicker,
      Value<String?> country,
      Value<String?> region,
      Value<String?> sector,
      Value<double?> ter,
      Value<double?> taxRate,
      required ValuationMethod valuationMethod,
      Value<bool> isActive,
      Value<bool> includeInNetWorth,
      Value<int> sortOrder,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$AssetsTableUpdateCompanionBuilder =
    AssetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> ticker,
      Value<String?> isin,
      Value<AssetType> assetType,
      Value<InstrumentType> instrumentType,
      Value<AssetClass> assetClass,
      Value<int> intermediaryId,
      Value<String> assetGroup,
      Value<String> currency,
      Value<String?> exchange,
      Value<String?> yahooTicker,
      Value<String?> country,
      Value<String?> region,
      Value<String?> sector,
      Value<double?> ter,
      Value<double?> taxRate,
      Value<ValuationMethod> valuationMethod,
      Value<bool> isActive,
      Value<bool> includeInNetWorth,
      Value<int> sortOrder,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AssetsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetsTable, Asset> {
  $$AssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IntermediariesTable _intermediaryIdTable(_$AppDatabase db) =>
      db.intermediaries.createAlias(
        $_aliasNameGenerator(db.assets.intermediaryId, db.intermediaries.id),
      );

  $$IntermediariesTableProcessedTableManager get intermediaryId {
    final $_column = $_itemColumn<int>('intermediary_id')!;

    final manager = $$IntermediariesTableTableManager(
      $_db,
      $_db.intermediaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_intermediaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AssetEventsTable, List<AssetEvent>>
  _assetEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.assetEvents,
    aliasName: $_aliasNameGenerator(db.assets.id, db.assetEvents.assetId),
  );

  $$AssetEventsTableProcessedTableManager get assetEventsRefs {
    final manager = $$AssetEventsTableTableManager(
      $_db,
      $_db.assetEvents,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_assetEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssetSnapshotsTable, List<AssetSnapshot>>
  _assetSnapshotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.assetSnapshots,
    aliasName: $_aliasNameGenerator(db.assets.id, db.assetSnapshots.assetId),
  );

  $$AssetSnapshotsTableProcessedTableManager get assetSnapshotsRefs {
    final manager = $$AssetSnapshotsTableTableManager(
      $_db,
      $_db.assetSnapshots,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_assetSnapshotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MarketPricesTable, List<MarketPrice>>
  _marketPricesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.marketPrices,
    aliasName: $_aliasNameGenerator(db.assets.id, db.marketPrices.assetId),
  );

  $$MarketPricesTableProcessedTableManager get marketPricesRefs {
    final manager = $$MarketPricesTableTableManager(
      $_db,
      $_db.marketPrices,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_marketPricesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssetCompositionsTable, List<AssetComposition>>
  _assetCompositionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assetCompositions,
        aliasName: $_aliasNameGenerator(
          db.assets.id,
          db.assetCompositions.assetId,
        ),
      );

  $$AssetCompositionsTableProcessedTableManager get assetCompositionsRefs {
    final manager = $$AssetCompositionsTableTableManager(
      $_db,
      $_db.assetCompositions,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assetCompositionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AssetsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isin => $composableBuilder(
    column: $table.isin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AssetType, AssetType, String> get assetType =>
      $composableBuilder(
        column: $table.assetType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<InstrumentType, InstrumentType, String>
  get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AssetClass, AssetClass, String>
  get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get assetGroup => $composableBuilder(
    column: $table.assetGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yahooTicker => $composableBuilder(
    column: $table.yahooTicker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sector => $composableBuilder(
    column: $table.sector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ter => $composableBuilder(
    column: $table.ter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ValuationMethod, ValuationMethod, String>
  get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$IntermediariesTableFilterComposer get intermediaryId {
    final $$IntermediariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableFilterComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> assetEventsRefs(
    Expression<bool> Function($$AssetEventsTableFilterComposer f) f,
  ) {
    final $$AssetEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetEvents,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetEventsTableFilterComposer(
            $db: $db,
            $table: $db.assetEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assetSnapshotsRefs(
    Expression<bool> Function($$AssetSnapshotsTableFilterComposer f) f,
  ) {
    final $$AssetSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetSnapshots,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.assetSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> marketPricesRefs(
    Expression<bool> Function($$MarketPricesTableFilterComposer f) f,
  ) {
    final $$MarketPricesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.marketPrices,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarketPricesTableFilterComposer(
            $db: $db,
            $table: $db.marketPrices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assetCompositionsRefs(
    Expression<bool> Function($$AssetCompositionsTableFilterComposer f) f,
  ) {
    final $$AssetCompositionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetCompositions,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetCompositionsTableFilterComposer(
            $db: $db,
            $table: $db.assetCompositions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isin => $composableBuilder(
    column: $table.isin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetType => $composableBuilder(
    column: $table.assetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instrumentType => $composableBuilder(
    column: $table.instrumentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetClass => $composableBuilder(
    column: $table.assetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetGroup => $composableBuilder(
    column: $table.assetGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yahooTicker => $composableBuilder(
    column: $table.yahooTicker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sector => $composableBuilder(
    column: $table.sector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ter => $composableBuilder(
    column: $table.ter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$IntermediariesTableOrderingComposer get intermediaryId {
    final $$IntermediariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableOrderingComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get isin =>
      $composableBuilder(column: $table.isin, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AssetType, String> get assetType =>
      $composableBuilder(column: $table.assetType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InstrumentType, String> get instrumentType =>
      $composableBuilder(
        column: $table.instrumentType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<AssetClass, String> get assetClass =>
      $composableBuilder(
        column: $table.assetClass,
        builder: (column) => column,
      );

  GeneratedColumn<String> get assetGroup => $composableBuilder(
    column: $table.assetGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<String> get yahooTicker => $composableBuilder(
    column: $table.yahooTicker,
    builder: (column) => column,
  );

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get sector =>
      $composableBuilder(column: $table.sector, builder: (column) => column);

  GeneratedColumn<double> get ter =>
      $composableBuilder(column: $table.ter, builder: (column) => column);

  GeneratedColumn<double> get taxRate =>
      $composableBuilder(column: $table.taxRate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ValuationMethod, String>
  get valuationMethod => $composableBuilder(
    column: $table.valuationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get includeInNetWorth => $composableBuilder(
    column: $table.includeInNetWorth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$IntermediariesTableAnnotationComposer get intermediaryId {
    final $$IntermediariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.intermediaryId,
      referencedTable: $db.intermediaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IntermediariesTableAnnotationComposer(
            $db: $db,
            $table: $db.intermediaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> assetEventsRefs<T extends Object>(
    Expression<T> Function($$AssetEventsTableAnnotationComposer a) f,
  ) {
    final $$AssetEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetEvents,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.assetEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assetSnapshotsRefs<T extends Object>(
    Expression<T> Function($$AssetSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$AssetSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assetSnapshots,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.assetSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> marketPricesRefs<T extends Object>(
    Expression<T> Function($$MarketPricesTableAnnotationComposer a) f,
  ) {
    final $$MarketPricesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.marketPrices,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarketPricesTableAnnotationComposer(
            $db: $db,
            $table: $db.marketPrices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assetCompositionsRefs<T extends Object>(
    Expression<T> Function($$AssetCompositionsTableAnnotationComposer a) f,
  ) {
    final $$AssetCompositionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assetCompositions,
          getReferencedColumn: (t) => t.assetId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssetCompositionsTableAnnotationComposer(
                $db: $db,
                $table: $db.assetCompositions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetsTable,
          Asset,
          $$AssetsTableFilterComposer,
          $$AssetsTableOrderingComposer,
          $$AssetsTableAnnotationComposer,
          $$AssetsTableCreateCompanionBuilder,
          $$AssetsTableUpdateCompanionBuilder,
          (Asset, $$AssetsTableReferences),
          Asset,
          PrefetchHooks Function({
            bool intermediaryId,
            bool assetEventsRefs,
            bool assetSnapshotsRefs,
            bool marketPricesRefs,
            bool assetCompositionsRefs,
          })
        > {
  $$AssetsTableTableManager(_$AppDatabase db, $AssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> ticker = const Value.absent(),
                Value<String?> isin = const Value.absent(),
                Value<AssetType> assetType = const Value.absent(),
                Value<InstrumentType> instrumentType = const Value.absent(),
                Value<AssetClass> assetClass = const Value.absent(),
                Value<int> intermediaryId = const Value.absent(),
                Value<String> assetGroup = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> exchange = const Value.absent(),
                Value<String?> yahooTicker = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> sector = const Value.absent(),
                Value<double?> ter = const Value.absent(),
                Value<double?> taxRate = const Value.absent(),
                Value<ValuationMethod> valuationMethod = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> includeInNetWorth = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AssetsCompanion(
                id: id,
                name: name,
                ticker: ticker,
                isin: isin,
                assetType: assetType,
                instrumentType: instrumentType,
                assetClass: assetClass,
                intermediaryId: intermediaryId,
                assetGroup: assetGroup,
                currency: currency,
                exchange: exchange,
                yahooTicker: yahooTicker,
                country: country,
                region: region,
                sector: sector,
                ter: ter,
                taxRate: taxRate,
                valuationMethod: valuationMethod,
                isActive: isActive,
                includeInNetWorth: includeInNetWorth,
                sortOrder: sortOrder,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> ticker = const Value.absent(),
                Value<String?> isin = const Value.absent(),
                required AssetType assetType,
                Value<InstrumentType> instrumentType = const Value.absent(),
                Value<AssetClass> assetClass = const Value.absent(),
                required int intermediaryId,
                Value<String> assetGroup = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> exchange = const Value.absent(),
                Value<String?> yahooTicker = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> sector = const Value.absent(),
                Value<double?> ter = const Value.absent(),
                Value<double?> taxRate = const Value.absent(),
                required ValuationMethod valuationMethod,
                Value<bool> isActive = const Value.absent(),
                Value<bool> includeInNetWorth = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AssetsCompanion.insert(
                id: id,
                name: name,
                ticker: ticker,
                isin: isin,
                assetType: assetType,
                instrumentType: instrumentType,
                assetClass: assetClass,
                intermediaryId: intermediaryId,
                assetGroup: assetGroup,
                currency: currency,
                exchange: exchange,
                yahooTicker: yahooTicker,
                country: country,
                region: region,
                sector: sector,
                ter: ter,
                taxRate: taxRate,
                valuationMethod: valuationMethod,
                isActive: isActive,
                includeInNetWorth: includeInNetWorth,
                sortOrder: sortOrder,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$AssetsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                intermediaryId = false,
                assetEventsRefs = false,
                assetSnapshotsRefs = false,
                marketPricesRefs = false,
                assetCompositionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (assetEventsRefs) db.assetEvents,
                    if (assetSnapshotsRefs) db.assetSnapshots,
                    if (marketPricesRefs) db.marketPrices,
                    if (assetCompositionsRefs) db.assetCompositions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (intermediaryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.intermediaryId,
                                    referencedTable: $$AssetsTableReferences
                                        ._intermediaryIdTable(db),
                                    referencedColumn: $$AssetsTableReferences
                                        ._intermediaryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (assetEventsRefs)
                        await $_getPrefetchedData<
                          Asset,
                          $AssetsTable,
                          AssetEvent
                        >(
                          currentTable: table,
                          referencedTable: $$AssetsTableReferences
                              ._assetEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).assetEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (assetSnapshotsRefs)
                        await $_getPrefetchedData<
                          Asset,
                          $AssetsTable,
                          AssetSnapshot
                        >(
                          currentTable: table,
                          referencedTable: $$AssetsTableReferences
                              ._assetSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).assetSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (marketPricesRefs)
                        await $_getPrefetchedData<
                          Asset,
                          $AssetsTable,
                          MarketPrice
                        >(
                          currentTable: table,
                          referencedTable: $$AssetsTableReferences
                              ._marketPricesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).marketPricesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (assetCompositionsRefs)
                        await $_getPrefetchedData<
                          Asset,
                          $AssetsTable,
                          AssetComposition
                        >(
                          currentTable: table,
                          referencedTable: $$AssetsTableReferences
                              ._assetCompositionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).assetCompositionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetsTable,
      Asset,
      $$AssetsTableFilterComposer,
      $$AssetsTableOrderingComposer,
      $$AssetsTableAnnotationComposer,
      $$AssetsTableCreateCompanionBuilder,
      $$AssetsTableUpdateCompanionBuilder,
      (Asset, $$AssetsTableReferences),
      Asset,
      PrefetchHooks Function({
        bool intermediaryId,
        bool assetEventsRefs,
        bool assetSnapshotsRefs,
        bool marketPricesRefs,
        bool assetCompositionsRefs,
      })
    >;
typedef $$AssetEventsTableCreateCompanionBuilder =
    AssetEventsCompanion Function({
      Value<int> id,
      required int assetId,
      required DateTime date,
      required DateTime valueDate,
      required EventType type,
      Value<double?> quantity,
      Value<double?> price,
      required double amount,
      Value<String> currency,
      Value<double?> exchangeRate,
      Value<double?> commission,
      Value<double?> taxWithheld,
      Value<String?> source,
      Value<String?> notes,
      Value<String?> rawMetadata,
      Value<String?> importHash,
      Value<DateTime> createdAt,
    });
typedef $$AssetEventsTableUpdateCompanionBuilder =
    AssetEventsCompanion Function({
      Value<int> id,
      Value<int> assetId,
      Value<DateTime> date,
      Value<DateTime> valueDate,
      Value<EventType> type,
      Value<double?> quantity,
      Value<double?> price,
      Value<double> amount,
      Value<String> currency,
      Value<double?> exchangeRate,
      Value<double?> commission,
      Value<double?> taxWithheld,
      Value<String?> source,
      Value<String?> notes,
      Value<String?> rawMetadata,
      Value<String?> importHash,
      Value<DateTime> createdAt,
    });

final class $$AssetEventsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetEventsTable, AssetEvent> {
  $$AssetEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
    $_aliasNameGenerator(db.assetEvents.assetId, db.assets.id),
  );

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager(
      $_db,
      $_db.assets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssetEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetEventsTable> {
  $$AssetEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventType, EventType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxWithheld => $composableBuilder(
    column: $table.taxWithheld,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableFilterComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetEventsTable> {
  $$AssetEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxWithheld => $composableBuilder(
    column: $table.taxWithheld,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableOrderingComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetEventsTable> {
  $$AssetEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get commission => $composableBuilder(
    column: $table.commission,
    builder: (column) => column,
  );

  GeneratedColumn<double> get taxWithheld => $composableBuilder(
    column: $table.taxWithheld,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get rawMetadata => $composableBuilder(
    column: $table.rawMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetEventsTable,
          AssetEvent,
          $$AssetEventsTableFilterComposer,
          $$AssetEventsTableOrderingComposer,
          $$AssetEventsTableAnnotationComposer,
          $$AssetEventsTableCreateCompanionBuilder,
          $$AssetEventsTableUpdateCompanionBuilder,
          (AssetEvent, $$AssetEventsTableReferences),
          AssetEvent,
          PrefetchHooks Function({bool assetId})
        > {
  $$AssetEventsTableTableManager(_$AppDatabase db, $AssetEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> assetId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DateTime> valueDate = const Value.absent(),
                Value<EventType> type = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double?> exchangeRate = const Value.absent(),
                Value<double?> commission = const Value.absent(),
                Value<double?> taxWithheld = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> rawMetadata = const Value.absent(),
                Value<String?> importHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AssetEventsCompanion(
                id: id,
                assetId: assetId,
                date: date,
                valueDate: valueDate,
                type: type,
                quantity: quantity,
                price: price,
                amount: amount,
                currency: currency,
                exchangeRate: exchangeRate,
                commission: commission,
                taxWithheld: taxWithheld,
                source: source,
                notes: notes,
                rawMetadata: rawMetadata,
                importHash: importHash,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int assetId,
                required DateTime date,
                required DateTime valueDate,
                required EventType type,
                Value<double?> quantity = const Value.absent(),
                Value<double?> price = const Value.absent(),
                required double amount,
                Value<String> currency = const Value.absent(),
                Value<double?> exchangeRate = const Value.absent(),
                Value<double?> commission = const Value.absent(),
                Value<double?> taxWithheld = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> rawMetadata = const Value.absent(),
                Value<String?> importHash = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AssetEventsCompanion.insert(
                id: id,
                assetId: assetId,
                date: date,
                valueDate: valueDate,
                type: type,
                quantity: quantity,
                price: price,
                amount: amount,
                currency: currency,
                exchangeRate: exchangeRate,
                commission: commission,
                taxWithheld: taxWithheld,
                source: source,
                notes: notes,
                rawMetadata: rawMetadata,
                importHash: importHash,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$AssetEventsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn: $$AssetEventsTableReferences
                                    ._assetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssetEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetEventsTable,
      AssetEvent,
      $$AssetEventsTableFilterComposer,
      $$AssetEventsTableOrderingComposer,
      $$AssetEventsTableAnnotationComposer,
      $$AssetEventsTableCreateCompanionBuilder,
      $$AssetEventsTableUpdateCompanionBuilder,
      (AssetEvent, $$AssetEventsTableReferences),
      AssetEvent,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$AssetSnapshotsTableCreateCompanionBuilder =
    AssetSnapshotsCompanion Function({
      Value<int> id,
      required int assetId,
      required DateTime date,
      required double value,
      required double invested,
      required double growth,
      required double growthPercent,
      required double afterTaxValue,
      Value<double?> quantity,
      Value<double?> price,
    });
typedef $$AssetSnapshotsTableUpdateCompanionBuilder =
    AssetSnapshotsCompanion Function({
      Value<int> id,
      Value<int> assetId,
      Value<DateTime> date,
      Value<double> value,
      Value<double> invested,
      Value<double> growth,
      Value<double> growthPercent,
      Value<double> afterTaxValue,
      Value<double?> quantity,
      Value<double?> price,
    });

final class $$AssetSnapshotsTableReferences
    extends BaseReferences<_$AppDatabase, $AssetSnapshotsTable, AssetSnapshot> {
  $$AssetSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
    $_aliasNameGenerator(db.assetSnapshots.assetId, db.assets.id),
  );

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager(
      $_db,
      $_db.assets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssetSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetSnapshotsTable> {
  $$AssetSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get invested => $composableBuilder(
    column: $table.invested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get growth => $composableBuilder(
    column: $table.growth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get growthPercent => $composableBuilder(
    column: $table.growthPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get afterTaxValue => $composableBuilder(
    column: $table.afterTaxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableFilterComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetSnapshotsTable> {
  $$AssetSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get invested => $composableBuilder(
    column: $table.invested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get growth => $composableBuilder(
    column: $table.growth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get growthPercent => $composableBuilder(
    column: $table.growthPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get afterTaxValue => $composableBuilder(
    column: $table.afterTaxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableOrderingComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetSnapshotsTable> {
  $$AssetSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<double> get invested =>
      $composableBuilder(column: $table.invested, builder: (column) => column);

  GeneratedColumn<double> get growth =>
      $composableBuilder(column: $table.growth, builder: (column) => column);

  GeneratedColumn<double> get growthPercent => $composableBuilder(
    column: $table.growthPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get afterTaxValue => $composableBuilder(
    column: $table.afterTaxValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetSnapshotsTable,
          AssetSnapshot,
          $$AssetSnapshotsTableFilterComposer,
          $$AssetSnapshotsTableOrderingComposer,
          $$AssetSnapshotsTableAnnotationComposer,
          $$AssetSnapshotsTableCreateCompanionBuilder,
          $$AssetSnapshotsTableUpdateCompanionBuilder,
          (AssetSnapshot, $$AssetSnapshotsTableReferences),
          AssetSnapshot,
          PrefetchHooks Function({bool assetId})
        > {
  $$AssetSnapshotsTableTableManager(
    _$AppDatabase db,
    $AssetSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> assetId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<double> invested = const Value.absent(),
                Value<double> growth = const Value.absent(),
                Value<double> growthPercent = const Value.absent(),
                Value<double> afterTaxValue = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<double?> price = const Value.absent(),
              }) => AssetSnapshotsCompanion(
                id: id,
                assetId: assetId,
                date: date,
                value: value,
                invested: invested,
                growth: growth,
                growthPercent: growthPercent,
                afterTaxValue: afterTaxValue,
                quantity: quantity,
                price: price,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int assetId,
                required DateTime date,
                required double value,
                required double invested,
                required double growth,
                required double growthPercent,
                required double afterTaxValue,
                Value<double?> quantity = const Value.absent(),
                Value<double?> price = const Value.absent(),
              }) => AssetSnapshotsCompanion.insert(
                id: id,
                assetId: assetId,
                date: date,
                value: value,
                invested: invested,
                growth: growth,
                growthPercent: growthPercent,
                afterTaxValue: afterTaxValue,
                quantity: quantity,
                price: price,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$AssetSnapshotsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn:
                                    $$AssetSnapshotsTableReferences
                                        ._assetIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssetSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetSnapshotsTable,
      AssetSnapshot,
      $$AssetSnapshotsTableFilterComposer,
      $$AssetSnapshotsTableOrderingComposer,
      $$AssetSnapshotsTableAnnotationComposer,
      $$AssetSnapshotsTableCreateCompanionBuilder,
      $$AssetSnapshotsTableUpdateCompanionBuilder,
      (AssetSnapshot, $$AssetSnapshotsTableReferences),
      AssetSnapshot,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$BuffersTableCreateCompanionBuilder =
    BuffersCompanion Function({
      Value<int> id,
      required String name,
      Value<double?> targetAmount,
      Value<int?> linkedEventId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$BuffersTableUpdateCompanionBuilder =
    BuffersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double?> targetAmount,
      Value<int?> linkedEventId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$BuffersTableReferences
    extends BaseReferences<_$AppDatabase, $BuffersTable, Buffer> {
  $$BuffersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BufferTransactionsTable, List<BufferTransaction>>
  _bufferTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.bufferTransactions,
        aliasName: $_aliasNameGenerator(
          db.buffers.id,
          db.bufferTransactions.bufferId,
        ),
      );

  $$BufferTransactionsTableProcessedTableManager get bufferTransactionsRefs {
    final manager = $$BufferTransactionsTableTableManager(
      $_db,
      $_db.bufferTransactions,
    ).filter((f) => f.bufferId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bufferTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ExtraordinaryEventsTable,
    List<ExtraordinaryEvent>
  >
  _extraordinaryEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.extraordinaryEvents,
        aliasName: $_aliasNameGenerator(
          db.buffers.id,
          db.extraordinaryEvents.bufferId,
        ),
      );

  $$ExtraordinaryEventsTableProcessedTableManager get extraordinaryEventsRefs {
    final manager = $$ExtraordinaryEventsTableTableManager(
      $_db,
      $_db.extraordinaryEvents,
    ).filter((f) => f.bufferId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _extraordinaryEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BuffersTableFilterComposer
    extends Composer<_$AppDatabase, $BuffersTable> {
  $$BuffersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linkedEventId => $composableBuilder(
    column: $table.linkedEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bufferTransactionsRefs(
    Expression<bool> Function($$BufferTransactionsTableFilterComposer f) f,
  ) {
    final $$BufferTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bufferTransactions,
      getReferencedColumn: (t) => t.bufferId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BufferTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.bufferTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> extraordinaryEventsRefs(
    Expression<bool> Function($$ExtraordinaryEventsTableFilterComposer f) f,
  ) {
    final $$ExtraordinaryEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extraordinaryEvents,
      getReferencedColumn: (t) => t.bufferId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtraordinaryEventsTableFilterComposer(
            $db: $db,
            $table: $db.extraordinaryEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BuffersTableOrderingComposer
    extends Composer<_$AppDatabase, $BuffersTable> {
  $$BuffersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linkedEventId => $composableBuilder(
    column: $table.linkedEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BuffersTableAnnotationComposer
    extends Composer<_$AppDatabase, $BuffersTable> {
  $$BuffersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get linkedEventId => $composableBuilder(
    column: $table.linkedEventId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> bufferTransactionsRefs<T extends Object>(
    Expression<T> Function($$BufferTransactionsTableAnnotationComposer a) f,
  ) {
    final $$BufferTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.bufferTransactions,
          getReferencedColumn: (t) => t.bufferId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BufferTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.bufferTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> extraordinaryEventsRefs<T extends Object>(
    Expression<T> Function($$ExtraordinaryEventsTableAnnotationComposer a) f,
  ) {
    final $$ExtraordinaryEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.extraordinaryEvents,
          getReferencedColumn: (t) => t.bufferId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.extraordinaryEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BuffersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BuffersTable,
          Buffer,
          $$BuffersTableFilterComposer,
          $$BuffersTableOrderingComposer,
          $$BuffersTableAnnotationComposer,
          $$BuffersTableCreateCompanionBuilder,
          $$BuffersTableUpdateCompanionBuilder,
          (Buffer, $$BuffersTableReferences),
          Buffer,
          PrefetchHooks Function({
            bool bufferTransactionsRefs,
            bool extraordinaryEventsRefs,
          })
        > {
  $$BuffersTableTableManager(_$AppDatabase db, $BuffersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuffersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuffersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuffersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> targetAmount = const Value.absent(),
                Value<int?> linkedEventId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BuffersCompanion(
                id: id,
                name: name,
                targetAmount: targetAmount,
                linkedEventId: linkedEventId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double?> targetAmount = const Value.absent(),
                Value<int?> linkedEventId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BuffersCompanion.insert(
                id: id,
                name: name,
                targetAmount: targetAmount,
                linkedEventId: linkedEventId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BuffersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                bufferTransactionsRefs = false,
                extraordinaryEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bufferTransactionsRefs) db.bufferTransactions,
                    if (extraordinaryEventsRefs) db.extraordinaryEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bufferTransactionsRefs)
                        await $_getPrefetchedData<
                          Buffer,
                          $BuffersTable,
                          BufferTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$BuffersTableReferences
                              ._bufferTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BuffersTableReferences(
                                db,
                                table,
                                p0,
                              ).bufferTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bufferId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (extraordinaryEventsRefs)
                        await $_getPrefetchedData<
                          Buffer,
                          $BuffersTable,
                          ExtraordinaryEvent
                        >(
                          currentTable: table,
                          referencedTable: $$BuffersTableReferences
                              ._extraordinaryEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BuffersTableReferences(
                                db,
                                table,
                                p0,
                              ).extraordinaryEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bufferId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BuffersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BuffersTable,
      Buffer,
      $$BuffersTableFilterComposer,
      $$BuffersTableOrderingComposer,
      $$BuffersTableAnnotationComposer,
      $$BuffersTableCreateCompanionBuilder,
      $$BuffersTableUpdateCompanionBuilder,
      (Buffer, $$BuffersTableReferences),
      Buffer,
      PrefetchHooks Function({
        bool bufferTransactionsRefs,
        bool extraordinaryEventsRefs,
      })
    >;
typedef $$BufferTransactionsTableCreateCompanionBuilder =
    BufferTransactionsCompanion Function({
      Value<int> id,
      required int bufferId,
      required DateTime operationDate,
      required DateTime valueDate,
      Value<String> description,
      required double amount,
      Value<String> currency,
      required double balanceAfter,
      Value<bool> isPayroll,
      Value<bool> isForceLast,
      Value<bool> isReimbursement,
      Value<int?> linkedTransactionId,
      Value<DateTime> createdAt,
    });
typedef $$BufferTransactionsTableUpdateCompanionBuilder =
    BufferTransactionsCompanion Function({
      Value<int> id,
      Value<int> bufferId,
      Value<DateTime> operationDate,
      Value<DateTime> valueDate,
      Value<String> description,
      Value<double> amount,
      Value<String> currency,
      Value<double> balanceAfter,
      Value<bool> isPayroll,
      Value<bool> isForceLast,
      Value<bool> isReimbursement,
      Value<int?> linkedTransactionId,
      Value<DateTime> createdAt,
    });

final class $$BufferTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $BufferTransactionsTable,
          BufferTransaction
        > {
  $$BufferTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BuffersTable _bufferIdTable(_$AppDatabase db) =>
      db.buffers.createAlias(
        $_aliasNameGenerator(db.bufferTransactions.bufferId, db.buffers.id),
      );

  $$BuffersTableProcessedTableManager get bufferId {
    final $_column = $_itemColumn<int>('buffer_id')!;

    final manager = $$BuffersTableTableManager(
      $_db,
      $_db.buffers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bufferIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _linkedTransactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.bufferTransactions.linkedTransactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager? get linkedTransactionId {
    final $_column = $_itemColumn<int>('linked_transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedTransactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BufferTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $BufferTransactionsTable> {
  $$BufferTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPayroll => $composableBuilder(
    column: $table.isPayroll,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForceLast => $composableBuilder(
    column: $table.isForceLast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReimbursement => $composableBuilder(
    column: $table.isReimbursement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BuffersTableFilterComposer get bufferId {
    final $$BuffersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableFilterComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get linkedTransactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BufferTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BufferTransactionsTable> {
  $$BufferTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPayroll => $composableBuilder(
    column: $table.isPayroll,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForceLast => $composableBuilder(
    column: $table.isForceLast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReimbursement => $composableBuilder(
    column: $table.isReimbursement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BuffersTableOrderingComposer get bufferId {
    final $$BuffersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableOrderingComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get linkedTransactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BufferTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BufferTransactionsTable> {
  $$BufferTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get operationDate => $composableBuilder(
    column: $table.operationDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPayroll =>
      $composableBuilder(column: $table.isPayroll, builder: (column) => column);

  GeneratedColumn<bool> get isForceLast => $composableBuilder(
    column: $table.isForceLast,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isReimbursement => $composableBuilder(
    column: $table.isReimbursement,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BuffersTableAnnotationComposer get bufferId {
    final $$BuffersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableAnnotationComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get linkedTransactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BufferTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BufferTransactionsTable,
          BufferTransaction,
          $$BufferTransactionsTableFilterComposer,
          $$BufferTransactionsTableOrderingComposer,
          $$BufferTransactionsTableAnnotationComposer,
          $$BufferTransactionsTableCreateCompanionBuilder,
          $$BufferTransactionsTableUpdateCompanionBuilder,
          (BufferTransaction, $$BufferTransactionsTableReferences),
          BufferTransaction,
          PrefetchHooks Function({bool bufferId, bool linkedTransactionId})
        > {
  $$BufferTransactionsTableTableManager(
    _$AppDatabase db,
    $BufferTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BufferTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BufferTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BufferTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bufferId = const Value.absent(),
                Value<DateTime> operationDate = const Value.absent(),
                Value<DateTime> valueDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> balanceAfter = const Value.absent(),
                Value<bool> isPayroll = const Value.absent(),
                Value<bool> isForceLast = const Value.absent(),
                Value<bool> isReimbursement = const Value.absent(),
                Value<int?> linkedTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BufferTransactionsCompanion(
                id: id,
                bufferId: bufferId,
                operationDate: operationDate,
                valueDate: valueDate,
                description: description,
                amount: amount,
                currency: currency,
                balanceAfter: balanceAfter,
                isPayroll: isPayroll,
                isForceLast: isForceLast,
                isReimbursement: isReimbursement,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bufferId,
                required DateTime operationDate,
                required DateTime valueDate,
                Value<String> description = const Value.absent(),
                required double amount,
                Value<String> currency = const Value.absent(),
                required double balanceAfter,
                Value<bool> isPayroll = const Value.absent(),
                Value<bool> isForceLast = const Value.absent(),
                Value<bool> isReimbursement = const Value.absent(),
                Value<int?> linkedTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BufferTransactionsCompanion.insert(
                id: id,
                bufferId: bufferId,
                operationDate: operationDate,
                valueDate: valueDate,
                description: description,
                amount: amount,
                currency: currency,
                balanceAfter: balanceAfter,
                isPayroll: isPayroll,
                isForceLast: isForceLast,
                isReimbursement: isReimbursement,
                linkedTransactionId: linkedTransactionId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BufferTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bufferId = false, linkedTransactionId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bufferId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bufferId,
                                    referencedTable:
                                        $$BufferTransactionsTableReferences
                                            ._bufferIdTable(db),
                                    referencedColumn:
                                        $$BufferTransactionsTableReferences
                                            ._bufferIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (linkedTransactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedTransactionId,
                                    referencedTable:
                                        $$BufferTransactionsTableReferences
                                            ._linkedTransactionIdTable(db),
                                    referencedColumn:
                                        $$BufferTransactionsTableReferences
                                            ._linkedTransactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$BufferTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BufferTransactionsTable,
      BufferTransaction,
      $$BufferTransactionsTableFilterComposer,
      $$BufferTransactionsTableOrderingComposer,
      $$BufferTransactionsTableAnnotationComposer,
      $$BufferTransactionsTableCreateCompanionBuilder,
      $$BufferTransactionsTableUpdateCompanionBuilder,
      (BufferTransaction, $$BufferTransactionsTableReferences),
      BufferTransaction,
      PrefetchHooks Function({bool bufferId, bool linkedTransactionId})
    >;
typedef $$MarketPricesTableCreateCompanionBuilder =
    MarketPricesCompanion Function({
      required int assetId,
      required DateTime date,
      required double closePrice,
      required String currency,
      Value<int> rowid,
    });
typedef $$MarketPricesTableUpdateCompanionBuilder =
    MarketPricesCompanion Function({
      Value<int> assetId,
      Value<DateTime> date,
      Value<double> closePrice,
      Value<String> currency,
      Value<int> rowid,
    });

final class $$MarketPricesTableReferences
    extends BaseReferences<_$AppDatabase, $MarketPricesTable, MarketPrice> {
  $$MarketPricesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
    $_aliasNameGenerator(db.marketPrices.assetId, db.assets.id),
  );

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager(
      $_db,
      $_db.assets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MarketPricesTableFilterComposer
    extends Composer<_$AppDatabase, $MarketPricesTable> {
  $$MarketPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get closePrice => $composableBuilder(
    column: $table.closePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableFilterComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarketPricesTableOrderingComposer
    extends Composer<_$AppDatabase, $MarketPricesTable> {
  $$MarketPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get closePrice => $composableBuilder(
    column: $table.closePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableOrderingComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarketPricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarketPricesTable> {
  $$MarketPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get closePrice => $composableBuilder(
    column: $table.closePrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarketPricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarketPricesTable,
          MarketPrice,
          $$MarketPricesTableFilterComposer,
          $$MarketPricesTableOrderingComposer,
          $$MarketPricesTableAnnotationComposer,
          $$MarketPricesTableCreateCompanionBuilder,
          $$MarketPricesTableUpdateCompanionBuilder,
          (MarketPrice, $$MarketPricesTableReferences),
          MarketPrice,
          PrefetchHooks Function({bool assetId})
        > {
  $$MarketPricesTableTableManager(_$AppDatabase db, $MarketPricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarketPricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarketPricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarketPricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> assetId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> closePrice = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarketPricesCompanion(
                assetId: assetId,
                date: date,
                closePrice: closePrice,
                currency: currency,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int assetId,
                required DateTime date,
                required double closePrice,
                required String currency,
                Value<int> rowid = const Value.absent(),
              }) => MarketPricesCompanion.insert(
                assetId: assetId,
                date: date,
                closePrice: closePrice,
                currency: currency,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MarketPricesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$MarketPricesTableReferences
                                    ._assetIdTable(db),
                                referencedColumn: $$MarketPricesTableReferences
                                    ._assetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MarketPricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarketPricesTable,
      MarketPrice,
      $$MarketPricesTableFilterComposer,
      $$MarketPricesTableOrderingComposer,
      $$MarketPricesTableAnnotationComposer,
      $$MarketPricesTableCreateCompanionBuilder,
      $$MarketPricesTableUpdateCompanionBuilder,
      (MarketPrice, $$MarketPricesTableReferences),
      MarketPrice,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$ExchangeRatesTableCreateCompanionBuilder =
    ExchangeRatesCompanion Function({
      required String fromCurrency,
      required String toCurrency,
      required DateTime date,
      required double rate,
      Value<int> rowid,
    });
typedef $$ExchangeRatesTableUpdateCompanionBuilder =
    ExchangeRatesCompanion Function({
      Value<String> fromCurrency,
      Value<String> toCurrency,
      Value<DateTime> date,
      Value<double> rate,
      Value<int> rowid,
    });

class $$ExchangeRatesTableFilterComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fromCurrency => $composableBuilder(
    column: $table.fromCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toCurrency => $composableBuilder(
    column: $table.toCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExchangeRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fromCurrency => $composableBuilder(
    column: $table.fromCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toCurrency => $composableBuilder(
    column: $table.toCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExchangeRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fromCurrency => $composableBuilder(
    column: $table.fromCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toCurrency => $composableBuilder(
    column: $table.toCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);
}

class $$ExchangeRatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExchangeRatesTable,
          ExchangeRate,
          $$ExchangeRatesTableFilterComposer,
          $$ExchangeRatesTableOrderingComposer,
          $$ExchangeRatesTableAnnotationComposer,
          $$ExchangeRatesTableCreateCompanionBuilder,
          $$ExchangeRatesTableUpdateCompanionBuilder,
          (
            ExchangeRate,
            BaseReferences<_$AppDatabase, $ExchangeRatesTable, ExchangeRate>,
          ),
          ExchangeRate,
          PrefetchHooks Function()
        > {
  $$ExchangeRatesTableTableManager(_$AppDatabase db, $ExchangeRatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExchangeRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExchangeRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExchangeRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fromCurrency = const Value.absent(),
                Value<String> toCurrency = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                date: date,
                rate: rate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fromCurrency,
                required String toCurrency,
                required DateTime date,
                required double rate,
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion.insert(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                date: date,
                rate: rate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExchangeRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExchangeRatesTable,
      ExchangeRate,
      $$ExchangeRatesTableFilterComposer,
      $$ExchangeRatesTableOrderingComposer,
      $$ExchangeRatesTableAnnotationComposer,
      $$ExchangeRatesTableCreateCompanionBuilder,
      $$ExchangeRatesTableUpdateCompanionBuilder,
      (
        ExchangeRate,
        BaseReferences<_$AppDatabase, $ExchangeRatesTable, ExchangeRate>,
      ),
      ExchangeRate,
      PrefetchHooks Function()
    >;
typedef $$RegisteredEventsTableCreateCompanionBuilder =
    RegisteredEventsCompanion Function({
      Value<int> id,
      required DateTime date,
      required RegisteredEventType type,
      Value<String> description,
      required double amount,
      Value<bool> isPersonal,
      Value<DateTime> createdAt,
    });
typedef $$RegisteredEventsTableUpdateCompanionBuilder =
    RegisteredEventsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<RegisteredEventType> type,
      Value<String> description,
      Value<double> amount,
      Value<bool> isPersonal,
      Value<DateTime> createdAt,
    });

class $$RegisteredEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RegisteredEventsTable> {
  $$RegisteredEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    RegisteredEventType,
    RegisteredEventType,
    String
  >
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPersonal => $composableBuilder(
    column: $table.isPersonal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RegisteredEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RegisteredEventsTable> {
  $$RegisteredEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPersonal => $composableBuilder(
    column: $table.isPersonal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RegisteredEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RegisteredEventsTable> {
  $$RegisteredEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RegisteredEventType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<bool> get isPersonal => $composableBuilder(
    column: $table.isPersonal,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RegisteredEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RegisteredEventsTable,
          RegisteredEvent,
          $$RegisteredEventsTableFilterComposer,
          $$RegisteredEventsTableOrderingComposer,
          $$RegisteredEventsTableAnnotationComposer,
          $$RegisteredEventsTableCreateCompanionBuilder,
          $$RegisteredEventsTableUpdateCompanionBuilder,
          (
            RegisteredEvent,
            BaseReferences<
              _$AppDatabase,
              $RegisteredEventsTable,
              RegisteredEvent
            >,
          ),
          RegisteredEvent,
          PrefetchHooks Function()
        > {
  $$RegisteredEventsTableTableManager(
    _$AppDatabase db,
    $RegisteredEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegisteredEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegisteredEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegisteredEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<RegisteredEventType> type = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<bool> isPersonal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RegisteredEventsCompanion(
                id: id,
                date: date,
                type: type,
                description: description,
                amount: amount,
                isPersonal: isPersonal,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required RegisteredEventType type,
                Value<String> description = const Value.absent(),
                required double amount,
                Value<bool> isPersonal = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RegisteredEventsCompanion.insert(
                id: id,
                date: date,
                type: type,
                description: description,
                amount: amount,
                isPersonal: isPersonal,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RegisteredEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RegisteredEventsTable,
      RegisteredEvent,
      $$RegisteredEventsTableFilterComposer,
      $$RegisteredEventsTableOrderingComposer,
      $$RegisteredEventsTableAnnotationComposer,
      $$RegisteredEventsTableCreateCompanionBuilder,
      $$RegisteredEventsTableUpdateCompanionBuilder,
      (
        RegisteredEvent,
        BaseReferences<_$AppDatabase, $RegisteredEventsTable, RegisteredEvent>,
      ),
      RegisteredEvent,
      PrefetchHooks Function()
    >;
typedef $$HealthReimbursementsTableCreateCompanionBuilder =
    HealthReimbursementsCompanion Function({
      Value<int> id,
      required String provider,
      required String invoiceNumber,
      required DateTime documentDate,
      required double claimAmount,
      required String beneficiary,
      required double reimbursedAmount,
      Value<DateTime?> reimbursementDate,
      required double paidAmount,
      required double uncoveredAmount,
      required double reimbursementPercent,
      required int processingDays,
      required bool isCovered,
    });
typedef $$HealthReimbursementsTableUpdateCompanionBuilder =
    HealthReimbursementsCompanion Function({
      Value<int> id,
      Value<String> provider,
      Value<String> invoiceNumber,
      Value<DateTime> documentDate,
      Value<double> claimAmount,
      Value<String> beneficiary,
      Value<double> reimbursedAmount,
      Value<DateTime?> reimbursementDate,
      Value<double> paidAmount,
      Value<double> uncoveredAmount,
      Value<double> reimbursementPercent,
      Value<int> processingDays,
      Value<bool> isCovered,
    });

class $$HealthReimbursementsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthReimbursementsTable> {
  $$HealthReimbursementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get documentDate => $composableBuilder(
    column: $table.documentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get claimAmount => $composableBuilder(
    column: $table.claimAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiary => $composableBuilder(
    column: $table.beneficiary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reimbursedAmount => $composableBuilder(
    column: $table.reimbursedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get uncoveredAmount => $composableBuilder(
    column: $table.uncoveredAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reimbursementPercent => $composableBuilder(
    column: $table.reimbursementPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processingDays => $composableBuilder(
    column: $table.processingDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCovered => $composableBuilder(
    column: $table.isCovered,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HealthReimbursementsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthReimbursementsTable> {
  $$HealthReimbursementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get documentDate => $composableBuilder(
    column: $table.documentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get claimAmount => $composableBuilder(
    column: $table.claimAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiary => $composableBuilder(
    column: $table.beneficiary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reimbursedAmount => $composableBuilder(
    column: $table.reimbursedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get uncoveredAmount => $composableBuilder(
    column: $table.uncoveredAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reimbursementPercent => $composableBuilder(
    column: $table.reimbursementPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processingDays => $composableBuilder(
    column: $table.processingDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCovered => $composableBuilder(
    column: $table.isCovered,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthReimbursementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthReimbursementsTable> {
  $$HealthReimbursementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get documentDate => $composableBuilder(
    column: $table.documentDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get claimAmount => $composableBuilder(
    column: $table.claimAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beneficiary => $composableBuilder(
    column: $table.beneficiary,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reimbursedAmount => $composableBuilder(
    column: $table.reimbursedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get uncoveredAmount => $composableBuilder(
    column: $table.uncoveredAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reimbursementPercent => $composableBuilder(
    column: $table.reimbursementPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processingDays => $composableBuilder(
    column: $table.processingDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCovered =>
      $composableBuilder(column: $table.isCovered, builder: (column) => column);
}

class $$HealthReimbursementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthReimbursementsTable,
          HealthReimbursement,
          $$HealthReimbursementsTableFilterComposer,
          $$HealthReimbursementsTableOrderingComposer,
          $$HealthReimbursementsTableAnnotationComposer,
          $$HealthReimbursementsTableCreateCompanionBuilder,
          $$HealthReimbursementsTableUpdateCompanionBuilder,
          (
            HealthReimbursement,
            BaseReferences<
              _$AppDatabase,
              $HealthReimbursementsTable,
              HealthReimbursement
            >,
          ),
          HealthReimbursement,
          PrefetchHooks Function()
        > {
  $$HealthReimbursementsTableTableManager(
    _$AppDatabase db,
    $HealthReimbursementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthReimbursementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthReimbursementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HealthReimbursementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> invoiceNumber = const Value.absent(),
                Value<DateTime> documentDate = const Value.absent(),
                Value<double> claimAmount = const Value.absent(),
                Value<String> beneficiary = const Value.absent(),
                Value<double> reimbursedAmount = const Value.absent(),
                Value<DateTime?> reimbursementDate = const Value.absent(),
                Value<double> paidAmount = const Value.absent(),
                Value<double> uncoveredAmount = const Value.absent(),
                Value<double> reimbursementPercent = const Value.absent(),
                Value<int> processingDays = const Value.absent(),
                Value<bool> isCovered = const Value.absent(),
              }) => HealthReimbursementsCompanion(
                id: id,
                provider: provider,
                invoiceNumber: invoiceNumber,
                documentDate: documentDate,
                claimAmount: claimAmount,
                beneficiary: beneficiary,
                reimbursedAmount: reimbursedAmount,
                reimbursementDate: reimbursementDate,
                paidAmount: paidAmount,
                uncoveredAmount: uncoveredAmount,
                reimbursementPercent: reimbursementPercent,
                processingDays: processingDays,
                isCovered: isCovered,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String provider,
                required String invoiceNumber,
                required DateTime documentDate,
                required double claimAmount,
                required String beneficiary,
                required double reimbursedAmount,
                Value<DateTime?> reimbursementDate = const Value.absent(),
                required double paidAmount,
                required double uncoveredAmount,
                required double reimbursementPercent,
                required int processingDays,
                required bool isCovered,
              }) => HealthReimbursementsCompanion.insert(
                id: id,
                provider: provider,
                invoiceNumber: invoiceNumber,
                documentDate: documentDate,
                claimAmount: claimAmount,
                beneficiary: beneficiary,
                reimbursedAmount: reimbursedAmount,
                reimbursementDate: reimbursementDate,
                paidAmount: paidAmount,
                uncoveredAmount: uncoveredAmount,
                reimbursementPercent: reimbursementPercent,
                processingDays: processingDays,
                isCovered: isCovered,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HealthReimbursementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthReimbursementsTable,
      HealthReimbursement,
      $$HealthReimbursementsTableFilterComposer,
      $$HealthReimbursementsTableOrderingComposer,
      $$HealthReimbursementsTableAnnotationComposer,
      $$HealthReimbursementsTableCreateCompanionBuilder,
      $$HealthReimbursementsTableUpdateCompanionBuilder,
      (
        HealthReimbursement,
        BaseReferences<
          _$AppDatabase,
          $HealthReimbursementsTable,
          HealthReimbursement
        >,
      ),
      HealthReimbursement,
      PrefetchHooks Function()
    >;
typedef $$AppConfigsTableCreateCompanionBuilder =
    AppConfigsCompanion Function({
      required String key,
      required String value,
      Value<String> description,
      Value<int> rowid,
    });
typedef $$AppConfigsTableUpdateCompanionBuilder =
    AppConfigsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<String> description,
      Value<int> rowid,
    });

class $$AppConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$AppConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppConfigsTable,
          AppConfig,
          $$AppConfigsTableFilterComposer,
          $$AppConfigsTableOrderingComposer,
          $$AppConfigsTableAnnotationComposer,
          $$AppConfigsTableCreateCompanionBuilder,
          $$AppConfigsTableUpdateCompanionBuilder,
          (
            AppConfig,
            BaseReferences<_$AppDatabase, $AppConfigsTable, AppConfig>,
          ),
          AppConfig,
          PrefetchHooks Function()
        > {
  $$AppConfigsTableTableManager(_$AppDatabase db, $AppConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppConfigsCompanion(
                key: key,
                value: value,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<String> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppConfigsCompanion.insert(
                key: key,
                value: value,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppConfigsTable,
      AppConfig,
      $$AppConfigsTableFilterComposer,
      $$AppConfigsTableOrderingComposer,
      $$AppConfigsTableAnnotationComposer,
      $$AppConfigsTableCreateCompanionBuilder,
      $$AppConfigsTableUpdateCompanionBuilder,
      (AppConfig, BaseReferences<_$AppDatabase, $AppConfigsTable, AppConfig>),
      AppConfig,
      PrefetchHooks Function()
    >;
typedef $$ImportConfigsTableCreateCompanionBuilder =
    ImportConfigsCompanion Function({
      Value<int> id,
      required int accountId,
      Value<int> skipRows,
      Value<String> mappingsJson,
      Value<String> formulaJson,
      Value<String> hashColumnsJson,
      Value<String?> numberLocale,
      Value<DateTime> updatedAt,
    });
typedef $$ImportConfigsTableUpdateCompanionBuilder =
    ImportConfigsCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<int> skipRows,
      Value<String> mappingsJson,
      Value<String> formulaJson,
      Value<String> hashColumnsJson,
      Value<String?> numberLocale,
      Value<DateTime> updatedAt,
    });

final class $$ImportConfigsTableReferences
    extends BaseReferences<_$AppDatabase, $ImportConfigsTable, ImportConfig> {
  $$ImportConfigsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.importConfigs.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportConfigsTable> {
  $$ImportConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipRows => $composableBuilder(
    column: $table.skipRows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mappingsJson => $composableBuilder(
    column: $table.mappingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formulaJson => $composableBuilder(
    column: $table.formulaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hashColumnsJson => $composableBuilder(
    column: $table.hashColumnsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numberLocale => $composableBuilder(
    column: $table.numberLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportConfigsTable> {
  $$ImportConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipRows => $composableBuilder(
    column: $table.skipRows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mappingsJson => $composableBuilder(
    column: $table.mappingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formulaJson => $composableBuilder(
    column: $table.formulaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hashColumnsJson => $composableBuilder(
    column: $table.hashColumnsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numberLocale => $composableBuilder(
    column: $table.numberLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportConfigsTable> {
  $$ImportConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get skipRows =>
      $composableBuilder(column: $table.skipRows, builder: (column) => column);

  GeneratedColumn<String> get mappingsJson => $composableBuilder(
    column: $table.mappingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formulaJson => $composableBuilder(
    column: $table.formulaJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hashColumnsJson => $composableBuilder(
    column: $table.hashColumnsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get numberLocale => $composableBuilder(
    column: $table.numberLocale,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportConfigsTable,
          ImportConfig,
          $$ImportConfigsTableFilterComposer,
          $$ImportConfigsTableOrderingComposer,
          $$ImportConfigsTableAnnotationComposer,
          $$ImportConfigsTableCreateCompanionBuilder,
          $$ImportConfigsTableUpdateCompanionBuilder,
          (ImportConfig, $$ImportConfigsTableReferences),
          ImportConfig,
          PrefetchHooks Function({bool accountId})
        > {
  $$ImportConfigsTableTableManager(_$AppDatabase db, $ImportConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> skipRows = const Value.absent(),
                Value<String> mappingsJson = const Value.absent(),
                Value<String> formulaJson = const Value.absent(),
                Value<String> hashColumnsJson = const Value.absent(),
                Value<String?> numberLocale = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ImportConfigsCompanion(
                id: id,
                accountId: accountId,
                skipRows: skipRows,
                mappingsJson: mappingsJson,
                formulaJson: formulaJson,
                hashColumnsJson: hashColumnsJson,
                numberLocale: numberLocale,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                Value<int> skipRows = const Value.absent(),
                Value<String> mappingsJson = const Value.absent(),
                Value<String> formulaJson = const Value.absent(),
                Value<String> hashColumnsJson = const Value.absent(),
                Value<String?> numberLocale = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ImportConfigsCompanion.insert(
                id: id,
                accountId: accountId,
                skipRows: skipRows,
                mappingsJson: mappingsJson,
                formulaJson: formulaJson,
                hashColumnsJson: hashColumnsJson,
                numberLocale: numberLocale,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ImportConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$ImportConfigsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$ImportConfigsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportConfigsTable,
      ImportConfig,
      $$ImportConfigsTableFilterComposer,
      $$ImportConfigsTableOrderingComposer,
      $$ImportConfigsTableAnnotationComposer,
      $$ImportConfigsTableCreateCompanionBuilder,
      $$ImportConfigsTableUpdateCompanionBuilder,
      (ImportConfig, $$ImportConfigsTableReferences),
      ImportConfig,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$IncomesTableCreateCompanionBuilder =
    IncomesCompanion Function({
      Value<int> id,
      required DateTime date,
      required DateTime valueDate,
      required double amount,
      Value<IncomeType> type,
      Value<String> currency,
      Value<DateTime> createdAt,
    });
typedef $$IncomesTableUpdateCompanionBuilder =
    IncomesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<DateTime> valueDate,
      Value<double> amount,
      Value<IncomeType> type,
      Value<String> currency,
      Value<DateTime> createdAt,
    });

class $$IncomesTableFilterComposer
    extends Composer<_$AppDatabase, $IncomesTable> {
  $$IncomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<IncomeType, IncomeType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IncomesTableOrderingComposer
    extends Composer<_$AppDatabase, $IncomesTable> {
  $$IncomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valueDate => $composableBuilder(
    column: $table.valueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IncomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IncomesTable> {
  $$IncomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get valueDate =>
      $composableBuilder(column: $table.valueDate, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<IncomeType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$IncomesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IncomesTable,
          Income,
          $$IncomesTableFilterComposer,
          $$IncomesTableOrderingComposer,
          $$IncomesTableAnnotationComposer,
          $$IncomesTableCreateCompanionBuilder,
          $$IncomesTableUpdateCompanionBuilder,
          (Income, BaseReferences<_$AppDatabase, $IncomesTable, Income>),
          Income,
          PrefetchHooks Function()
        > {
  $$IncomesTableTableManager(_$AppDatabase db, $IncomesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncomesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DateTime> valueDate = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<IncomeType> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => IncomesCompanion(
                id: id,
                date: date,
                valueDate: valueDate,
                amount: amount,
                type: type,
                currency: currency,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required DateTime valueDate,
                required double amount,
                Value<IncomeType> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => IncomesCompanion.insert(
                id: id,
                date: date,
                valueDate: valueDate,
                amount: amount,
                type: type,
                currency: currency,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IncomesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IncomesTable,
      Income,
      $$IncomesTableFilterComposer,
      $$IncomesTableOrderingComposer,
      $$IncomesTableAnnotationComposer,
      $$IncomesTableCreateCompanionBuilder,
      $$IncomesTableUpdateCompanionBuilder,
      (Income, BaseReferences<_$AppDatabase, $IncomesTable, Income>),
      Income,
      PrefetchHooks Function()
    >;
typedef $$AssetCompositionsTableCreateCompanionBuilder =
    AssetCompositionsCompanion Function({
      Value<int> id,
      required int assetId,
      required String type,
      required String name,
      required double weight,
      Value<DateTime> updatedAt,
    });
typedef $$AssetCompositionsTableUpdateCompanionBuilder =
    AssetCompositionsCompanion Function({
      Value<int> id,
      Value<int> assetId,
      Value<String> type,
      Value<String> name,
      Value<double> weight,
      Value<DateTime> updatedAt,
    });

final class $$AssetCompositionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssetCompositionsTable,
          AssetComposition
        > {
  $$AssetCompositionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
    $_aliasNameGenerator(db.assetCompositions.assetId, db.assets.id),
  );

  $$AssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<int>('asset_id')!;

    final manager = $$AssetsTableTableManager(
      $_db,
      $_db.assets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssetCompositionsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetCompositionsTable> {
  $$AssetCompositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AssetsTableFilterComposer get assetId {
    final $$AssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableFilterComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetCompositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetCompositionsTable> {
  $$AssetCompositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssetsTableOrderingComposer get assetId {
    final $$AssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableOrderingComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetCompositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetCompositionsTable> {
  $$AssetCompositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AssetsTableAnnotationComposer get assetId {
    final $$AssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.assets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.assets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssetCompositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetCompositionsTable,
          AssetComposition,
          $$AssetCompositionsTableFilterComposer,
          $$AssetCompositionsTableOrderingComposer,
          $$AssetCompositionsTableAnnotationComposer,
          $$AssetCompositionsTableCreateCompanionBuilder,
          $$AssetCompositionsTableUpdateCompanionBuilder,
          (AssetComposition, $$AssetCompositionsTableReferences),
          AssetComposition,
          PrefetchHooks Function({bool assetId})
        > {
  $$AssetCompositionsTableTableManager(
    _$AppDatabase db,
    $AssetCompositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetCompositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetCompositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetCompositionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> assetId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AssetCompositionsCompanion(
                id: id,
                assetId: assetId,
                type: type,
                name: name,
                weight: weight,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int assetId,
                required String type,
                required String name,
                required double weight,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AssetCompositionsCompanion.insert(
                id: id,
                assetId: assetId,
                type: type,
                name: name,
                weight: weight,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssetCompositionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable:
                                    $$AssetCompositionsTableReferences
                                        ._assetIdTable(db),
                                referencedColumn:
                                    $$AssetCompositionsTableReferences
                                        ._assetIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssetCompositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetCompositionsTable,
      AssetComposition,
      $$AssetCompositionsTableFilterComposer,
      $$AssetCompositionsTableOrderingComposer,
      $$AssetCompositionsTableAnnotationComposer,
      $$AssetCompositionsTableCreateCompanionBuilder,
      $$AssetCompositionsTableUpdateCompanionBuilder,
      (AssetComposition, $$AssetCompositionsTableReferences),
      AssetComposition,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$ExtraordinaryEventsTableCreateCompanionBuilder =
    ExtraordinaryEventsCompanion Function({
      Value<int> id,
      required String name,
      required EventDirection direction,
      required EventTreatment treatment,
      required double totalAmount,
      Value<String> currency,
      required DateTime eventDate,
      Value<int?> transactionId,
      Value<StepFrequency?> stepFrequency,
      Value<DateTime?> spreadStart,
      Value<DateTime?> spreadEnd,
      Value<int?> bufferId,
      Value<String?> notes,
      Value<bool> isActive,
      Value<bool> isEphemeral,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ExtraordinaryEventsTableUpdateCompanionBuilder =
    ExtraordinaryEventsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<EventDirection> direction,
      Value<EventTreatment> treatment,
      Value<double> totalAmount,
      Value<String> currency,
      Value<DateTime> eventDate,
      Value<int?> transactionId,
      Value<StepFrequency?> stepFrequency,
      Value<DateTime?> spreadStart,
      Value<DateTime?> spreadEnd,
      Value<int?> bufferId,
      Value<String?> notes,
      Value<bool> isActive,
      Value<bool> isEphemeral,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ExtraordinaryEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExtraordinaryEventsTable,
          ExtraordinaryEvent
        > {
  $$ExtraordinaryEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.extraordinaryEvents.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<int>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BuffersTable _bufferIdTable(_$AppDatabase db) =>
      db.buffers.createAlias(
        $_aliasNameGenerator(db.extraordinaryEvents.bufferId, db.buffers.id),
      );

  $$BuffersTableProcessedTableManager? get bufferId {
    final $_column = $_itemColumn<int>('buffer_id');
    if ($_column == null) return null;
    final manager = $$BuffersTableTableManager(
      $_db,
      $_db.buffers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bufferIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ExtraordinaryEventEntriesTable,
    List<ExtraordinaryEventEntry>
  >
  _extraordinaryEventEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.extraordinaryEventEntries,
        aliasName: $_aliasNameGenerator(
          db.extraordinaryEvents.id,
          db.extraordinaryEventEntries.eventId,
        ),
      );

  $$ExtraordinaryEventEntriesTableProcessedTableManager
  get extraordinaryEventEntriesRefs {
    final manager = $$ExtraordinaryEventEntriesTableTableManager(
      $_db,
      $_db.extraordinaryEventEntries,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _extraordinaryEventEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExtraordinaryEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventsTable> {
  $$ExtraordinaryEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventDirection, EventDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<EventTreatment, EventTreatment, String>
  get treatment => $composableBuilder(
    column: $table.treatment,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StepFrequency?, StepFrequency, String>
  get stepFrequency => $composableBuilder(
    column: $table.stepFrequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get spreadStart => $composableBuilder(
    column: $table.spreadStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get spreadEnd => $composableBuilder(
    column: $table.spreadEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEphemeral => $composableBuilder(
    column: $table.isEphemeral,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BuffersTableFilterComposer get bufferId {
    final $$BuffersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableFilterComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> extraordinaryEventEntriesRefs(
    Expression<bool> Function($$ExtraordinaryEventEntriesTableFilterComposer f)
    f,
  ) {
    final $$ExtraordinaryEventEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.extraordinaryEventEntries,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventEntriesTableFilterComposer(
                $db: $db,
                $table: $db.extraordinaryEventEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExtraordinaryEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventsTable> {
  $$ExtraordinaryEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treatment => $composableBuilder(
    column: $table.treatment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepFrequency => $composableBuilder(
    column: $table.stepFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get spreadStart => $composableBuilder(
    column: $table.spreadStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get spreadEnd => $composableBuilder(
    column: $table.spreadEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEphemeral => $composableBuilder(
    column: $table.isEphemeral,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BuffersTableOrderingComposer get bufferId {
    final $$BuffersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableOrderingComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtraordinaryEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventsTable> {
  $$ExtraordinaryEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventTreatment, String> get treatment =>
      $composableBuilder(column: $table.treatment, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StepFrequency?, String> get stepFrequency =>
      $composableBuilder(
        column: $table.stepFrequency,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get spreadStart => $composableBuilder(
    column: $table.spreadStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get spreadEnd =>
      $composableBuilder(column: $table.spreadEnd, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isEphemeral => $composableBuilder(
    column: $table.isEphemeral,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BuffersTableAnnotationComposer get bufferId {
    final $$BuffersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bufferId,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BuffersTableAnnotationComposer(
            $db: $db,
            $table: $db.buffers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> extraordinaryEventEntriesRefs<T extends Object>(
    Expression<T> Function($$ExtraordinaryEventEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$ExtraordinaryEventEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.extraordinaryEventEntries,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.extraordinaryEventEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExtraordinaryEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtraordinaryEventsTable,
          ExtraordinaryEvent,
          $$ExtraordinaryEventsTableFilterComposer,
          $$ExtraordinaryEventsTableOrderingComposer,
          $$ExtraordinaryEventsTableAnnotationComposer,
          $$ExtraordinaryEventsTableCreateCompanionBuilder,
          $$ExtraordinaryEventsTableUpdateCompanionBuilder,
          (ExtraordinaryEvent, $$ExtraordinaryEventsTableReferences),
          ExtraordinaryEvent,
          PrefetchHooks Function({
            bool transactionId,
            bool bufferId,
            bool extraordinaryEventEntriesRefs,
          })
        > {
  $$ExtraordinaryEventsTableTableManager(
    _$AppDatabase db,
    $ExtraordinaryEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtraordinaryEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtraordinaryEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExtraordinaryEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<EventDirection> direction = const Value.absent(),
                Value<EventTreatment> treatment = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> eventDate = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<StepFrequency?> stepFrequency = const Value.absent(),
                Value<DateTime?> spreadStart = const Value.absent(),
                Value<DateTime?> spreadEnd = const Value.absent(),
                Value<int?> bufferId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isEphemeral = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ExtraordinaryEventsCompanion(
                id: id,
                name: name,
                direction: direction,
                treatment: treatment,
                totalAmount: totalAmount,
                currency: currency,
                eventDate: eventDate,
                transactionId: transactionId,
                stepFrequency: stepFrequency,
                spreadStart: spreadStart,
                spreadEnd: spreadEnd,
                bufferId: bufferId,
                notes: notes,
                isActive: isActive,
                isEphemeral: isEphemeral,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required EventDirection direction,
                required EventTreatment treatment,
                required double totalAmount,
                Value<String> currency = const Value.absent(),
                required DateTime eventDate,
                Value<int?> transactionId = const Value.absent(),
                Value<StepFrequency?> stepFrequency = const Value.absent(),
                Value<DateTime?> spreadStart = const Value.absent(),
                Value<DateTime?> spreadEnd = const Value.absent(),
                Value<int?> bufferId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isEphemeral = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ExtraordinaryEventsCompanion.insert(
                id: id,
                name: name,
                direction: direction,
                treatment: treatment,
                totalAmount: totalAmount,
                currency: currency,
                eventDate: eventDate,
                transactionId: transactionId,
                stepFrequency: stepFrequency,
                spreadStart: spreadStart,
                spreadEnd: spreadEnd,
                bufferId: bufferId,
                notes: notes,
                isActive: isActive,
                isEphemeral: isEphemeral,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExtraordinaryEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionId = false,
                bufferId = false,
                extraordinaryEventEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (extraordinaryEventEntriesRefs)
                      db.extraordinaryEventEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable:
                                        $$ExtraordinaryEventsTableReferences
                                            ._transactionIdTable(db),
                                    referencedColumn:
                                        $$ExtraordinaryEventsTableReferences
                                            ._transactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (bufferId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bufferId,
                                    referencedTable:
                                        $$ExtraordinaryEventsTableReferences
                                            ._bufferIdTable(db),
                                    referencedColumn:
                                        $$ExtraordinaryEventsTableReferences
                                            ._bufferIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (extraordinaryEventEntriesRefs)
                        await $_getPrefetchedData<
                          ExtraordinaryEvent,
                          $ExtraordinaryEventsTable,
                          ExtraordinaryEventEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ExtraordinaryEventsTableReferences
                              ._extraordinaryEventEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExtraordinaryEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).extraordinaryEventEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExtraordinaryEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtraordinaryEventsTable,
      ExtraordinaryEvent,
      $$ExtraordinaryEventsTableFilterComposer,
      $$ExtraordinaryEventsTableOrderingComposer,
      $$ExtraordinaryEventsTableAnnotationComposer,
      $$ExtraordinaryEventsTableCreateCompanionBuilder,
      $$ExtraordinaryEventsTableUpdateCompanionBuilder,
      (ExtraordinaryEvent, $$ExtraordinaryEventsTableReferences),
      ExtraordinaryEvent,
      PrefetchHooks Function({
        bool transactionId,
        bool bufferId,
        bool extraordinaryEventEntriesRefs,
      })
    >;
typedef $$ExtraordinaryEventEntriesTableCreateCompanionBuilder =
    ExtraordinaryEventEntriesCompanion Function({
      Value<int> id,
      required int eventId,
      required DateTime date,
      required double amount,
      required EventEntryKind entryKind,
      Value<String> description,
      Value<double?> cumulative,
      Value<double?> remaining,
      Value<DateTime> createdAt,
    });
typedef $$ExtraordinaryEventEntriesTableUpdateCompanionBuilder =
    ExtraordinaryEventEntriesCompanion Function({
      Value<int> id,
      Value<int> eventId,
      Value<DateTime> date,
      Value<double> amount,
      Value<EventEntryKind> entryKind,
      Value<String> description,
      Value<double?> cumulative,
      Value<double?> remaining,
      Value<DateTime> createdAt,
    });

final class $$ExtraordinaryEventEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExtraordinaryEventEntriesTable,
          ExtraordinaryEventEntry
        > {
  $$ExtraordinaryEventEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExtraordinaryEventsTable _eventIdTable(_$AppDatabase db) =>
      db.extraordinaryEvents.createAlias(
        $_aliasNameGenerator(
          db.extraordinaryEventEntries.eventId,
          db.extraordinaryEvents.id,
        ),
      );

  $$ExtraordinaryEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$ExtraordinaryEventsTableTableManager(
      $_db,
      $_db.extraordinaryEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExtraordinaryEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventEntriesTable> {
  $$ExtraordinaryEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventEntryKind, EventEntryKind, String>
  get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ExtraordinaryEventsTableFilterComposer get eventId {
    final $$ExtraordinaryEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.extraordinaryEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtraordinaryEventsTableFilterComposer(
            $db: $db,
            $table: $db.extraordinaryEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtraordinaryEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventEntriesTable> {
  $$ExtraordinaryEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKind => $composableBuilder(
    column: $table.entryKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExtraordinaryEventsTableOrderingComposer get eventId {
    final $$ExtraordinaryEventsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.eventId,
          referencedTable: $db.extraordinaryEvents,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventsTableOrderingComposer(
                $db: $db,
                $table: $db.extraordinaryEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ExtraordinaryEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtraordinaryEventEntriesTable> {
  $$ExtraordinaryEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventEntryKind, String> get entryKind =>
      $composableBuilder(column: $table.entryKind, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => column,
  );

  GeneratedColumn<double> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ExtraordinaryEventsTableAnnotationComposer get eventId {
    final $$ExtraordinaryEventsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.eventId,
          referencedTable: $db.extraordinaryEvents,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtraordinaryEventsTableAnnotationComposer(
                $db: $db,
                $table: $db.extraordinaryEvents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ExtraordinaryEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtraordinaryEventEntriesTable,
          ExtraordinaryEventEntry,
          $$ExtraordinaryEventEntriesTableFilterComposer,
          $$ExtraordinaryEventEntriesTableOrderingComposer,
          $$ExtraordinaryEventEntriesTableAnnotationComposer,
          $$ExtraordinaryEventEntriesTableCreateCompanionBuilder,
          $$ExtraordinaryEventEntriesTableUpdateCompanionBuilder,
          (ExtraordinaryEventEntry, $$ExtraordinaryEventEntriesTableReferences),
          ExtraordinaryEventEntry,
          PrefetchHooks Function({bool eventId})
        > {
  $$ExtraordinaryEventEntriesTableTableManager(
    _$AppDatabase db,
    $ExtraordinaryEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtraordinaryEventEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExtraordinaryEventEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExtraordinaryEventEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> eventId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<EventEntryKind> entryKind = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double?> cumulative = const Value.absent(),
                Value<double?> remaining = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExtraordinaryEventEntriesCompanion(
                id: id,
                eventId: eventId,
                date: date,
                amount: amount,
                entryKind: entryKind,
                description: description,
                cumulative: cumulative,
                remaining: remaining,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int eventId,
                required DateTime date,
                required double amount,
                required EventEntryKind entryKind,
                Value<String> description = const Value.absent(),
                Value<double?> cumulative = const Value.absent(),
                Value<double?> remaining = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExtraordinaryEventEntriesCompanion.insert(
                id: id,
                eventId: eventId,
                date: date,
                amount: amount,
                entryKind: entryKind,
                description: description,
                cumulative: cumulative,
                remaining: remaining,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExtraordinaryEventEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable:
                                    $$ExtraordinaryEventEntriesTableReferences
                                        ._eventIdTable(db),
                                referencedColumn:
                                    $$ExtraordinaryEventEntriesTableReferences
                                        ._eventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExtraordinaryEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtraordinaryEventEntriesTable,
      ExtraordinaryEventEntry,
      $$ExtraordinaryEventEntriesTableFilterComposer,
      $$ExtraordinaryEventEntriesTableOrderingComposer,
      $$ExtraordinaryEventEntriesTableAnnotationComposer,
      $$ExtraordinaryEventEntriesTableCreateCompanionBuilder,
      $$ExtraordinaryEventEntriesTableUpdateCompanionBuilder,
      (ExtraordinaryEventEntry, $$ExtraordinaryEventEntriesTableReferences),
      ExtraordinaryEventEntry,
      PrefetchHooks Function({bool eventId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$IntermediariesTableTableManager get intermediaries =>
      $$IntermediariesTableTableManager(_db, _db.intermediaries);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$AutoCategorizationRulesTableTableManager get autoCategorizationRules =>
      $$AutoCategorizationRulesTableTableManager(
        _db,
        _db.autoCategorizationRules,
      );
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
  $$AssetEventsTableTableManager get assetEvents =>
      $$AssetEventsTableTableManager(_db, _db.assetEvents);
  $$AssetSnapshotsTableTableManager get assetSnapshots =>
      $$AssetSnapshotsTableTableManager(_db, _db.assetSnapshots);
  $$BuffersTableTableManager get buffers =>
      $$BuffersTableTableManager(_db, _db.buffers);
  $$BufferTransactionsTableTableManager get bufferTransactions =>
      $$BufferTransactionsTableTableManager(_db, _db.bufferTransactions);
  $$MarketPricesTableTableManager get marketPrices =>
      $$MarketPricesTableTableManager(_db, _db.marketPrices);
  $$ExchangeRatesTableTableManager get exchangeRates =>
      $$ExchangeRatesTableTableManager(_db, _db.exchangeRates);
  $$RegisteredEventsTableTableManager get registeredEvents =>
      $$RegisteredEventsTableTableManager(_db, _db.registeredEvents);
  $$HealthReimbursementsTableTableManager get healthReimbursements =>
      $$HealthReimbursementsTableTableManager(_db, _db.healthReimbursements);
  $$AppConfigsTableTableManager get appConfigs =>
      $$AppConfigsTableTableManager(_db, _db.appConfigs);
  $$ImportConfigsTableTableManager get importConfigs =>
      $$ImportConfigsTableTableManager(_db, _db.importConfigs);
  $$IncomesTableTableManager get incomes =>
      $$IncomesTableTableManager(_db, _db.incomes);
  $$AssetCompositionsTableTableManager get assetCompositions =>
      $$AssetCompositionsTableTableManager(_db, _db.assetCompositions);
  $$ExtraordinaryEventsTableTableManager get extraordinaryEvents =>
      $$ExtraordinaryEventsTableTableManager(_db, _db.extraordinaryEvents);
  $$ExtraordinaryEventEntriesTableTableManager get extraordinaryEventEntries =>
      $$ExtraordinaryEventEntriesTableTableManager(
        _db,
        _db.extraordinaryEventEntries,
      );
}
