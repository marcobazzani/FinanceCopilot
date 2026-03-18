// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
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
  static const VerificationMeta _depreciationIdMeta = const VerificationMeta(
    'depreciationId',
  );
  @override
  late final GeneratedColumn<int> depreciationId = GeneratedColumn<int>(
    'depreciation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    depreciationId,
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
    if (data.containsKey('depreciation_id')) {
      context.handle(
        _depreciationIdMeta,
        depreciationId.isAcceptableOrUnknown(
          data['depreciation_id']!,
          _depreciationIdMeta,
        ),
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
      depreciationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depreciation_id'],
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
  final int? depreciationId;
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
    this.depreciationId,
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
    if (!nullToAbsent || depreciationId != null) {
      map['depreciation_id'] = Variable<int>(depreciationId);
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
      depreciationId: depreciationId == null && nullToAbsent
          ? const Value.absent()
          : Value(depreciationId),
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
      depreciationId: serializer.fromJson<int?>(json['depreciationId']),
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
      'depreciationId': serializer.toJson<int?>(depreciationId),
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
    Value<int?> depreciationId = const Value.absent(),
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
    depreciationId: depreciationId.present
        ? depreciationId.value
        : this.depreciationId,
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
      depreciationId: data.depreciationId.present
          ? data.depreciationId.value
          : this.depreciationId,
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
          ..write('depreciationId: $depreciationId, ')
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
    depreciationId,
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
          other.depreciationId == this.depreciationId &&
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
  final Value<int?> depreciationId;
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
    this.depreciationId = const Value.absent(),
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
    this.depreciationId = const Value.absent(),
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
    Expression<int>? depreciationId,
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
      if (depreciationId != null) 'depreciation_id': depreciationId,
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
    Value<int?>? depreciationId,
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
      depreciationId: depreciationId ?? this.depreciationId,
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
    if (depreciationId.present) {
      map['depreciation_id'] = Variable<int>(depreciationId.value);
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
          ..write('depreciationId: $depreciationId, ')
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
       valuationMethod = Value(valuationMethod);
  static Insertable<Asset> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? ticker,
    Expression<String>? isin,
    Expression<String>? assetType,
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
       type = Value(type),
       amount = Value(amount);
  static Insertable<AssetEvent> custom({
    Expression<int>? id,
    Expression<int>? assetId,
    Expression<DateTime>? date,
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

class $PortfoliosTable extends Portfolios
    with TableInfo<$PortfoliosTable, Portfolio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfoliosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<int> modelId = GeneratedColumn<int>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    description,
    isActive,
    modelId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolios';
  @override
  VerificationContext validateIntegrity(
    Insertable<Portfolio> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
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
  Portfolio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Portfolio(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}model_id'],
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
  $PortfoliosTable createAlias(String alias) {
    return $PortfoliosTable(attachedDatabase, alias);
  }
}

class Portfolio extends DataClass implements Insertable<Portfolio> {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int? modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Portfolio({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.modelId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<int>(modelId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PortfoliosCompanion toCompanion(bool nullToAbsent) {
    return PortfoliosCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Portfolio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Portfolio(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      modelId: serializer.fromJson<int?>(json['modelId']),
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
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'modelId': serializer.toJson<int?>(modelId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Portfolio copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    Value<int?> modelId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Portfolio(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    modelId: modelId.present ? modelId.value : this.modelId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Portfolio copyWithCompanion(PortfoliosCompanion data) {
    return Portfolio(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Portfolio(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    isActive,
    modelId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Portfolio &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.modelId == this.modelId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PortfoliosCompanion extends UpdateCompanion<Portfolio> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<int?> modelId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PortfoliosCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.modelId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PortfoliosCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.modelId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Portfolio> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<int>? modelId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (modelId != null) 'model_id': modelId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PortfoliosCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<int?>? modelId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PortfoliosCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      modelId: modelId ?? this.modelId,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<int>(modelId.value);
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
    return (StringBuffer('PortfoliosCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PortfolioAssetsTable extends PortfolioAssets
    with TableInfo<$PortfolioAssetsTable, PortfolioAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _portfolioIdMeta = const VerificationMeta(
    'portfolioId',
  );
  @override
  late final GeneratedColumn<int> portfolioId = GeneratedColumn<int>(
    'portfolio_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES portfolios (id)',
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
  @override
  List<GeneratedColumn> get $columns => [portfolioId, assetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortfolioAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('portfolio_id')) {
      context.handle(
        _portfolioIdMeta,
        portfolioId.isAcceptableOrUnknown(
          data['portfolio_id']!,
          _portfolioIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_portfolioIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {portfolioId, assetId};
  @override
  PortfolioAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioAsset(
      portfolioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}portfolio_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asset_id'],
      )!,
    );
  }

  @override
  $PortfolioAssetsTable createAlias(String alias) {
    return $PortfolioAssetsTable(attachedDatabase, alias);
  }
}

class PortfolioAsset extends DataClass implements Insertable<PortfolioAsset> {
  final int portfolioId;
  final int assetId;
  const PortfolioAsset({required this.portfolioId, required this.assetId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['portfolio_id'] = Variable<int>(portfolioId);
    map['asset_id'] = Variable<int>(assetId);
    return map;
  }

  PortfolioAssetsCompanion toCompanion(bool nullToAbsent) {
    return PortfolioAssetsCompanion(
      portfolioId: Value(portfolioId),
      assetId: Value(assetId),
    );
  }

  factory PortfolioAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioAsset(
      portfolioId: serializer.fromJson<int>(json['portfolioId']),
      assetId: serializer.fromJson<int>(json['assetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'portfolioId': serializer.toJson<int>(portfolioId),
      'assetId': serializer.toJson<int>(assetId),
    };
  }

  PortfolioAsset copyWith({int? portfolioId, int? assetId}) => PortfolioAsset(
    portfolioId: portfolioId ?? this.portfolioId,
    assetId: assetId ?? this.assetId,
  );
  PortfolioAsset copyWithCompanion(PortfolioAssetsCompanion data) {
    return PortfolioAsset(
      portfolioId: data.portfolioId.present
          ? data.portfolioId.value
          : this.portfolioId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioAsset(')
          ..write('portfolioId: $portfolioId, ')
          ..write('assetId: $assetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(portfolioId, assetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioAsset &&
          other.portfolioId == this.portfolioId &&
          other.assetId == this.assetId);
}

class PortfolioAssetsCompanion extends UpdateCompanion<PortfolioAsset> {
  final Value<int> portfolioId;
  final Value<int> assetId;
  final Value<int> rowid;
  const PortfolioAssetsCompanion({
    this.portfolioId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PortfolioAssetsCompanion.insert({
    required int portfolioId,
    required int assetId,
    this.rowid = const Value.absent(),
  }) : portfolioId = Value(portfolioId),
       assetId = Value(assetId);
  static Insertable<PortfolioAsset> custom({
    Expression<int>? portfolioId,
    Expression<int>? assetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (portfolioId != null) 'portfolio_id': portfolioId,
      if (assetId != null) 'asset_id': assetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PortfolioAssetsCompanion copyWith({
    Value<int>? portfolioId,
    Value<int>? assetId,
    Value<int>? rowid,
  }) {
    return PortfolioAssetsCompanion(
      portfolioId: portfolioId ?? this.portfolioId,
      assetId: assetId ?? this.assetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (portfolioId.present) {
      map['portfolio_id'] = Variable<int>(portfolioId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<int>(assetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioAssetsCompanion(')
          ..write('portfolioId: $portfolioId, ')
          ..write('assetId: $assetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PortfolioModelsTable extends PortfolioModels
    with TableInfo<$PortfolioModelsTable, PortfolioModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortfolioModelsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allocationsMeta = const VerificationMeta(
    'allocations',
  );
  @override
  late final GeneratedColumn<String> allocations = GeneratedColumn<String>(
    'allocations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    name,
    description,
    allocations,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portfolio_models';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortfolioModel> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('allocations')) {
      context.handle(
        _allocationsMeta,
        allocations.isAcceptableOrUnknown(
          data['allocations']!,
          _allocationsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocationsMeta);
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
  PortfolioModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortfolioModel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      allocations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allocations'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PortfolioModelsTable createAlias(String alias) {
    return $PortfolioModelsTable(attachedDatabase, alias);
  }
}

class PortfolioModel extends DataClass implements Insertable<PortfolioModel> {
  final int id;
  final String name;
  final String? description;
  final String allocations;
  final DateTime createdAt;
  const PortfolioModel({
    required this.id,
    required this.name,
    this.description,
    required this.allocations,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['allocations'] = Variable<String>(allocations);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PortfolioModelsCompanion toCompanion(bool nullToAbsent) {
    return PortfolioModelsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      allocations: Value(allocations),
      createdAt: Value(createdAt),
    );
  }

  factory PortfolioModel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortfolioModel(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      allocations: serializer.fromJson<String>(json['allocations']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'allocations': serializer.toJson<String>(allocations),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PortfolioModel copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? allocations,
    DateTime? createdAt,
  }) => PortfolioModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    allocations: allocations ?? this.allocations,
    createdAt: createdAt ?? this.createdAt,
  );
  PortfolioModel copyWithCompanion(PortfolioModelsCompanion data) {
    return PortfolioModel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      allocations: data.allocations.present
          ? data.allocations.value
          : this.allocations,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioModel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('allocations: $allocations, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, allocations, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortfolioModel &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.allocations == this.allocations &&
          other.createdAt == this.createdAt);
}

class PortfolioModelsCompanion extends UpdateCompanion<PortfolioModel> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> allocations;
  final Value<DateTime> createdAt;
  const PortfolioModelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.allocations = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PortfolioModelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required String allocations,
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       allocations = Value(allocations);
  static Insertable<PortfolioModel> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? allocations,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (allocations != null) 'allocations': allocations,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PortfolioModelsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? allocations,
    Value<DateTime>? createdAt,
  }) {
    return PortfolioModelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      allocations: allocations ?? this.allocations,
      createdAt: createdAt ?? this.createdAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (allocations.present) {
      map['allocations'] = Variable<String>(allocations.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortfolioModelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('allocations: $allocations, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DailySnapshotsTable extends DailySnapshots
    with TableInfo<$DailySnapshotsTable, DailySnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySnapshotsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _accountBalancesMeta = const VerificationMeta(
    'accountBalances',
  );
  @override
  late final GeneratedColumn<String> accountBalances = GeneratedColumn<String>(
    'account_balances',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _portfolioValueMeta = const VerificationMeta(
    'portfolioValue',
  );
  @override
  late final GeneratedColumn<double> portfolioValue = GeneratedColumn<double>(
    'portfolio_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _investedAmountMeta = const VerificationMeta(
    'investedAmount',
  );
  @override
  late final GeneratedColumn<double> investedAmount = GeneratedColumn<double>(
    'invested_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _liquidCashMeta = const VerificationMeta(
    'liquidCash',
  );
  @override
  late final GeneratedColumn<double> liquidCash = GeneratedColumn<double>(
    'liquid_cash',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSavingsMeta = const VerificationMeta(
    'totalSavings',
  );
  @override
  late final GeneratedColumn<double> totalSavings = GeneratedColumn<double>(
    'total_savings',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalAssetsMeta = const VerificationMeta(
    'totalAssets',
  );
  @override
  late final GeneratedColumn<double> totalAssets = GeneratedColumn<double>(
    'total_assets',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _liquidabileMeta = const VerificationMeta(
    'liquidabile',
  );
  @override
  late final GeneratedColumn<double> liquidabile = GeneratedColumn<double>(
    'liquidabile',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _plEurMeta = const VerificationMeta('plEur');
  @override
  late final GeneratedColumn<double> plEur = GeneratedColumn<double>(
    'pl_eur',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _netPlEurMeta = const VerificationMeta(
    'netPlEur',
  );
  @override
  late final GeneratedColumn<double> netPlEur = GeneratedColumn<double>(
    'net_pl_eur',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _plAtPercentMeta = const VerificationMeta(
    'plAtPercent',
  );
  @override
  late final GeneratedColumn<double> plAtPercent = GeneratedColumn<double>(
    'pl_at_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _plPtfPercentMeta = const VerificationMeta(
    'plPtfPercent',
  );
  @override
  late final GeneratedColumn<double> plPtfPercent = GeneratedColumn<double>(
    'pl_ptf_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _periodPlEurMeta = const VerificationMeta(
    'periodPlEur',
  );
  @override
  late final GeneratedColumn<double> periodPlEur = GeneratedColumn<double>(
    'period_pl_eur',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _periodPlAtPercentMeta = const VerificationMeta(
    'periodPlAtPercent',
  );
  @override
  late final GeneratedColumn<double> periodPlAtPercent =
      GeneratedColumn<double>(
        'period_pl_at_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _periodPlPtfPercentMeta =
      const VerificationMeta('periodPlPtfPercent');
  @override
  late final GeneratedColumn<double> periodPlPtfPercent =
      GeneratedColumn<double>(
        'period_pl_ptf_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _logReturnMeta = const VerificationMeta(
    'logReturn',
  );
  @override
  late final GeneratedColumn<double> logReturn = GeneratedColumn<double>(
    'log_return',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _smaSavingsMeta = const VerificationMeta(
    'smaSavings',
  );
  @override
  late final GeneratedColumn<double> smaSavings = GeneratedColumn<double>(
    'sma_savings',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _smaExpensesMeta = const VerificationMeta(
    'smaExpenses',
  );
  @override
  late final GeneratedColumn<double> smaExpenses = GeneratedColumn<double>(
    'sma_expenses',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _smaNetPlMeta = const VerificationMeta(
    'smaNetPl',
  );
  @override
  late final GeneratedColumn<double> smaNetPl = GeneratedColumn<double>(
    'sma_net_pl',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _annualizedVolatilityMeta =
      const VerificationMeta('annualizedVolatility');
  @override
  late final GeneratedColumn<double> annualizedVolatility =
      GeneratedColumn<double>(
        'annualized_volatility',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _deltaSmaRtMeta = const VerificationMeta(
    'deltaSmaRt',
  );
  @override
  late final GeneratedColumn<double> deltaSmaRt = GeneratedColumn<double>(
    'delta_sma_rt',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _incomeMeta = const VerificationMeta('income');
  @override
  late final GeneratedColumn<double> income = GeneratedColumn<double>(
    'income',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expensesMeta = const VerificationMeta(
    'expenses',
  );
  @override
  late final GeneratedColumn<double> expenses = GeneratedColumn<double>(
    'expenses',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cumulativeExpensesMeta =
      const VerificationMeta('cumulativeExpenses');
  @override
  late final GeneratedColumn<double> cumulativeExpenses =
      GeneratedColumn<double>(
        'cumulative_expenses',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _expensesAdjustedMeta = const VerificationMeta(
    'expensesAdjusted',
  );
  @override
  late final GeneratedColumn<double> expensesAdjusted = GeneratedColumn<double>(
    'expenses_adjusted',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reimbursementsRegisteredMeta =
      const VerificationMeta('reimbursementsRegistered');
  @override
  late final GeneratedColumn<double> reimbursementsRegistered =
      GeneratedColumn<double>(
        'reimbursements_registered',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _incomeRegisteredMeta = const VerificationMeta(
    'incomeRegistered',
  );
  @override
  late final GeneratedColumn<double> incomeRegistered = GeneratedColumn<double>(
    'income_registered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gainsRegisteredMeta = const VerificationMeta(
    'gainsRegistered',
  );
  @override
  late final GeneratedColumn<double> gainsRegistered = GeneratedColumn<double>(
    'gains_registered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _salesRegisteredMeta = const VerificationMeta(
    'salesRegistered',
  );
  @override
  late final GeneratedColumn<double> salesRegistered = GeneratedColumn<double>(
    'sales_registered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraCashMeta = const VerificationMeta(
    'extraCash',
  );
  @override
  late final GeneratedColumn<double> extraCash = GeneratedColumn<double>(
    'extra_cash',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _spendingVelocityMeta = const VerificationMeta(
    'spendingVelocity',
  );
  @override
  late final GeneratedColumn<double> spendingVelocity = GeneratedColumn<double>(
    'spending_velocity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _savingsVelocityMeta = const VerificationMeta(
    'savingsVelocity',
  );
  @override
  late final GeneratedColumn<double> savingsVelocity = GeneratedColumn<double>(
    'savings_velocity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _profitVelocityMeta = const VerificationMeta(
    'profitVelocity',
  );
  @override
  late final GeneratedColumn<double> profitVelocity = GeneratedColumn<double>(
    'profit_velocity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dailyRalMeta = const VerificationMeta(
    'dailyRal',
  );
  @override
  late final GeneratedColumn<double> dailyRal = GeneratedColumn<double>(
    'daily_ral',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _euOverRalMeta = const VerificationMeta(
    'euOverRal',
  );
  @override
  late final GeneratedColumn<double> euOverRal = GeneratedColumn<double>(
    'eu_over_ral',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pensionValueMeta = const VerificationMeta(
    'pensionValue',
  );
  @override
  late final GeneratedColumn<double> pensionValue = GeneratedColumn<double>(
    'pension_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _diffHthMeta = const VerificationMeta(
    'diffHth',
  );
  @override
  late final GeneratedColumn<double> diffHth = GeneratedColumn<double>(
    'diff_hth',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rtAtRatioMeta = const VerificationMeta(
    'rtAtRatio',
  );
  @override
  late final GeneratedColumn<double> rtAtRatio = GeneratedColumn<double>(
    'rt_at_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    accountBalances,
    portfolioValue,
    investedAmount,
    liquidCash,
    totalSavings,
    totalAssets,
    liquidabile,
    plEur,
    netPlEur,
    plAtPercent,
    plPtfPercent,
    periodPlEur,
    periodPlAtPercent,
    periodPlPtfPercent,
    logReturn,
    smaSavings,
    smaExpenses,
    smaNetPl,
    annualizedVolatility,
    deltaSmaRt,
    income,
    expenses,
    cumulativeExpenses,
    expensesAdjusted,
    reimbursementsRegistered,
    incomeRegistered,
    gainsRegistered,
    salesRegistered,
    extraCash,
    spendingVelocity,
    savingsVelocity,
    profitVelocity,
    dailyRal,
    euOverRal,
    pensionValue,
    diffHth,
    rtAtRatio,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySnapshot> instance, {
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
    if (data.containsKey('account_balances')) {
      context.handle(
        _accountBalancesMeta,
        accountBalances.isAcceptableOrUnknown(
          data['account_balances']!,
          _accountBalancesMeta,
        ),
      );
    }
    if (data.containsKey('portfolio_value')) {
      context.handle(
        _portfolioValueMeta,
        portfolioValue.isAcceptableOrUnknown(
          data['portfolio_value']!,
          _portfolioValueMeta,
        ),
      );
    }
    if (data.containsKey('invested_amount')) {
      context.handle(
        _investedAmountMeta,
        investedAmount.isAcceptableOrUnknown(
          data['invested_amount']!,
          _investedAmountMeta,
        ),
      );
    }
    if (data.containsKey('liquid_cash')) {
      context.handle(
        _liquidCashMeta,
        liquidCash.isAcceptableOrUnknown(data['liquid_cash']!, _liquidCashMeta),
      );
    }
    if (data.containsKey('total_savings')) {
      context.handle(
        _totalSavingsMeta,
        totalSavings.isAcceptableOrUnknown(
          data['total_savings']!,
          _totalSavingsMeta,
        ),
      );
    }
    if (data.containsKey('total_assets')) {
      context.handle(
        _totalAssetsMeta,
        totalAssets.isAcceptableOrUnknown(
          data['total_assets']!,
          _totalAssetsMeta,
        ),
      );
    }
    if (data.containsKey('liquidabile')) {
      context.handle(
        _liquidabileMeta,
        liquidabile.isAcceptableOrUnknown(
          data['liquidabile']!,
          _liquidabileMeta,
        ),
      );
    }
    if (data.containsKey('pl_eur')) {
      context.handle(
        _plEurMeta,
        plEur.isAcceptableOrUnknown(data['pl_eur']!, _plEurMeta),
      );
    }
    if (data.containsKey('net_pl_eur')) {
      context.handle(
        _netPlEurMeta,
        netPlEur.isAcceptableOrUnknown(data['net_pl_eur']!, _netPlEurMeta),
      );
    }
    if (data.containsKey('pl_at_percent')) {
      context.handle(
        _plAtPercentMeta,
        plAtPercent.isAcceptableOrUnknown(
          data['pl_at_percent']!,
          _plAtPercentMeta,
        ),
      );
    }
    if (data.containsKey('pl_ptf_percent')) {
      context.handle(
        _plPtfPercentMeta,
        plPtfPercent.isAcceptableOrUnknown(
          data['pl_ptf_percent']!,
          _plPtfPercentMeta,
        ),
      );
    }
    if (data.containsKey('period_pl_eur')) {
      context.handle(
        _periodPlEurMeta,
        periodPlEur.isAcceptableOrUnknown(
          data['period_pl_eur']!,
          _periodPlEurMeta,
        ),
      );
    }
    if (data.containsKey('period_pl_at_percent')) {
      context.handle(
        _periodPlAtPercentMeta,
        periodPlAtPercent.isAcceptableOrUnknown(
          data['period_pl_at_percent']!,
          _periodPlAtPercentMeta,
        ),
      );
    }
    if (data.containsKey('period_pl_ptf_percent')) {
      context.handle(
        _periodPlPtfPercentMeta,
        periodPlPtfPercent.isAcceptableOrUnknown(
          data['period_pl_ptf_percent']!,
          _periodPlPtfPercentMeta,
        ),
      );
    }
    if (data.containsKey('log_return')) {
      context.handle(
        _logReturnMeta,
        logReturn.isAcceptableOrUnknown(data['log_return']!, _logReturnMeta),
      );
    }
    if (data.containsKey('sma_savings')) {
      context.handle(
        _smaSavingsMeta,
        smaSavings.isAcceptableOrUnknown(data['sma_savings']!, _smaSavingsMeta),
      );
    }
    if (data.containsKey('sma_expenses')) {
      context.handle(
        _smaExpensesMeta,
        smaExpenses.isAcceptableOrUnknown(
          data['sma_expenses']!,
          _smaExpensesMeta,
        ),
      );
    }
    if (data.containsKey('sma_net_pl')) {
      context.handle(
        _smaNetPlMeta,
        smaNetPl.isAcceptableOrUnknown(data['sma_net_pl']!, _smaNetPlMeta),
      );
    }
    if (data.containsKey('annualized_volatility')) {
      context.handle(
        _annualizedVolatilityMeta,
        annualizedVolatility.isAcceptableOrUnknown(
          data['annualized_volatility']!,
          _annualizedVolatilityMeta,
        ),
      );
    }
    if (data.containsKey('delta_sma_rt')) {
      context.handle(
        _deltaSmaRtMeta,
        deltaSmaRt.isAcceptableOrUnknown(
          data['delta_sma_rt']!,
          _deltaSmaRtMeta,
        ),
      );
    }
    if (data.containsKey('income')) {
      context.handle(
        _incomeMeta,
        income.isAcceptableOrUnknown(data['income']!, _incomeMeta),
      );
    }
    if (data.containsKey('expenses')) {
      context.handle(
        _expensesMeta,
        expenses.isAcceptableOrUnknown(data['expenses']!, _expensesMeta),
      );
    }
    if (data.containsKey('cumulative_expenses')) {
      context.handle(
        _cumulativeExpensesMeta,
        cumulativeExpenses.isAcceptableOrUnknown(
          data['cumulative_expenses']!,
          _cumulativeExpensesMeta,
        ),
      );
    }
    if (data.containsKey('expenses_adjusted')) {
      context.handle(
        _expensesAdjustedMeta,
        expensesAdjusted.isAcceptableOrUnknown(
          data['expenses_adjusted']!,
          _expensesAdjustedMeta,
        ),
      );
    }
    if (data.containsKey('reimbursements_registered')) {
      context.handle(
        _reimbursementsRegisteredMeta,
        reimbursementsRegistered.isAcceptableOrUnknown(
          data['reimbursements_registered']!,
          _reimbursementsRegisteredMeta,
        ),
      );
    }
    if (data.containsKey('income_registered')) {
      context.handle(
        _incomeRegisteredMeta,
        incomeRegistered.isAcceptableOrUnknown(
          data['income_registered']!,
          _incomeRegisteredMeta,
        ),
      );
    }
    if (data.containsKey('gains_registered')) {
      context.handle(
        _gainsRegisteredMeta,
        gainsRegistered.isAcceptableOrUnknown(
          data['gains_registered']!,
          _gainsRegisteredMeta,
        ),
      );
    }
    if (data.containsKey('sales_registered')) {
      context.handle(
        _salesRegisteredMeta,
        salesRegistered.isAcceptableOrUnknown(
          data['sales_registered']!,
          _salesRegisteredMeta,
        ),
      );
    }
    if (data.containsKey('extra_cash')) {
      context.handle(
        _extraCashMeta,
        extraCash.isAcceptableOrUnknown(data['extra_cash']!, _extraCashMeta),
      );
    }
    if (data.containsKey('spending_velocity')) {
      context.handle(
        _spendingVelocityMeta,
        spendingVelocity.isAcceptableOrUnknown(
          data['spending_velocity']!,
          _spendingVelocityMeta,
        ),
      );
    }
    if (data.containsKey('savings_velocity')) {
      context.handle(
        _savingsVelocityMeta,
        savingsVelocity.isAcceptableOrUnknown(
          data['savings_velocity']!,
          _savingsVelocityMeta,
        ),
      );
    }
    if (data.containsKey('profit_velocity')) {
      context.handle(
        _profitVelocityMeta,
        profitVelocity.isAcceptableOrUnknown(
          data['profit_velocity']!,
          _profitVelocityMeta,
        ),
      );
    }
    if (data.containsKey('daily_ral')) {
      context.handle(
        _dailyRalMeta,
        dailyRal.isAcceptableOrUnknown(data['daily_ral']!, _dailyRalMeta),
      );
    }
    if (data.containsKey('eu_over_ral')) {
      context.handle(
        _euOverRalMeta,
        euOverRal.isAcceptableOrUnknown(data['eu_over_ral']!, _euOverRalMeta),
      );
    }
    if (data.containsKey('pension_value')) {
      context.handle(
        _pensionValueMeta,
        pensionValue.isAcceptableOrUnknown(
          data['pension_value']!,
          _pensionValueMeta,
        ),
      );
    }
    if (data.containsKey('diff_hth')) {
      context.handle(
        _diffHthMeta,
        diffHth.isAcceptableOrUnknown(data['diff_hth']!, _diffHthMeta),
      );
    }
    if (data.containsKey('rt_at_ratio')) {
      context.handle(
        _rtAtRatioMeta,
        rtAtRatio.isAcceptableOrUnknown(data['rt_at_ratio']!, _rtAtRatioMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailySnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      accountBalances: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_balances'],
      )!,
      portfolioValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}portfolio_value'],
      )!,
      investedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}invested_amount'],
      )!,
      liquidCash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}liquid_cash'],
      )!,
      totalSavings: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_savings'],
      )!,
      totalAssets: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_assets'],
      )!,
      liquidabile: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}liquidabile'],
      )!,
      plEur: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pl_eur'],
      )!,
      netPlEur: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}net_pl_eur'],
      )!,
      plAtPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pl_at_percent'],
      )!,
      plPtfPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pl_ptf_percent'],
      )!,
      periodPlEur: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}period_pl_eur'],
      )!,
      periodPlAtPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}period_pl_at_percent'],
      )!,
      periodPlPtfPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}period_pl_ptf_percent'],
      )!,
      logReturn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}log_return'],
      )!,
      smaSavings: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sma_savings'],
      )!,
      smaExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sma_expenses'],
      )!,
      smaNetPl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sma_net_pl'],
      )!,
      annualizedVolatility: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}annualized_volatility'],
      )!,
      deltaSmaRt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_sma_rt'],
      )!,
      income: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}income'],
      )!,
      expenses: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}expenses'],
      )!,
      cumulativeExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cumulative_expenses'],
      )!,
      expensesAdjusted: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}expenses_adjusted'],
      )!,
      reimbursementsRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reimbursements_registered'],
      )!,
      incomeRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}income_registered'],
      )!,
      gainsRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gains_registered'],
      )!,
      salesRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sales_registered'],
      )!,
      extraCash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}extra_cash'],
      )!,
      spendingVelocity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}spending_velocity'],
      )!,
      savingsVelocity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}savings_velocity'],
      )!,
      profitVelocity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}profit_velocity'],
      )!,
      dailyRal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}daily_ral'],
      )!,
      euOverRal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}eu_over_ral'],
      )!,
      pensionValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pension_value'],
      )!,
      diffHth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diff_hth'],
      )!,
      rtAtRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rt_at_ratio'],
      )!,
    );
  }

  @override
  $DailySnapshotsTable createAlias(String alias) {
    return $DailySnapshotsTable(attachedDatabase, alias);
  }
}

class DailySnapshot extends DataClass implements Insertable<DailySnapshot> {
  final int id;
  final DateTime date;
  final String accountBalances;
  final double portfolioValue;
  final double investedAmount;
  final double liquidCash;
  final double totalSavings;
  final double totalAssets;
  final double liquidabile;
  final double plEur;
  final double netPlEur;
  final double plAtPercent;
  final double plPtfPercent;
  final double periodPlEur;
  final double periodPlAtPercent;
  final double periodPlPtfPercent;
  final double logReturn;
  final double smaSavings;
  final double smaExpenses;
  final double smaNetPl;
  final double annualizedVolatility;
  final double deltaSmaRt;
  final double income;
  final double expenses;
  final double cumulativeExpenses;
  final double expensesAdjusted;
  final double reimbursementsRegistered;
  final double incomeRegistered;
  final double gainsRegistered;
  final double salesRegistered;
  final double extraCash;
  final double spendingVelocity;
  final double savingsVelocity;
  final double profitVelocity;
  final double dailyRal;
  final double euOverRal;
  final double pensionValue;
  final double diffHth;
  final double rtAtRatio;
  const DailySnapshot({
    required this.id,
    required this.date,
    required this.accountBalances,
    required this.portfolioValue,
    required this.investedAmount,
    required this.liquidCash,
    required this.totalSavings,
    required this.totalAssets,
    required this.liquidabile,
    required this.plEur,
    required this.netPlEur,
    required this.plAtPercent,
    required this.plPtfPercent,
    required this.periodPlEur,
    required this.periodPlAtPercent,
    required this.periodPlPtfPercent,
    required this.logReturn,
    required this.smaSavings,
    required this.smaExpenses,
    required this.smaNetPl,
    required this.annualizedVolatility,
    required this.deltaSmaRt,
    required this.income,
    required this.expenses,
    required this.cumulativeExpenses,
    required this.expensesAdjusted,
    required this.reimbursementsRegistered,
    required this.incomeRegistered,
    required this.gainsRegistered,
    required this.salesRegistered,
    required this.extraCash,
    required this.spendingVelocity,
    required this.savingsVelocity,
    required this.profitVelocity,
    required this.dailyRal,
    required this.euOverRal,
    required this.pensionValue,
    required this.diffHth,
    required this.rtAtRatio,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['account_balances'] = Variable<String>(accountBalances);
    map['portfolio_value'] = Variable<double>(portfolioValue);
    map['invested_amount'] = Variable<double>(investedAmount);
    map['liquid_cash'] = Variable<double>(liquidCash);
    map['total_savings'] = Variable<double>(totalSavings);
    map['total_assets'] = Variable<double>(totalAssets);
    map['liquidabile'] = Variable<double>(liquidabile);
    map['pl_eur'] = Variable<double>(plEur);
    map['net_pl_eur'] = Variable<double>(netPlEur);
    map['pl_at_percent'] = Variable<double>(plAtPercent);
    map['pl_ptf_percent'] = Variable<double>(plPtfPercent);
    map['period_pl_eur'] = Variable<double>(periodPlEur);
    map['period_pl_at_percent'] = Variable<double>(periodPlAtPercent);
    map['period_pl_ptf_percent'] = Variable<double>(periodPlPtfPercent);
    map['log_return'] = Variable<double>(logReturn);
    map['sma_savings'] = Variable<double>(smaSavings);
    map['sma_expenses'] = Variable<double>(smaExpenses);
    map['sma_net_pl'] = Variable<double>(smaNetPl);
    map['annualized_volatility'] = Variable<double>(annualizedVolatility);
    map['delta_sma_rt'] = Variable<double>(deltaSmaRt);
    map['income'] = Variable<double>(income);
    map['expenses'] = Variable<double>(expenses);
    map['cumulative_expenses'] = Variable<double>(cumulativeExpenses);
    map['expenses_adjusted'] = Variable<double>(expensesAdjusted);
    map['reimbursements_registered'] = Variable<double>(
      reimbursementsRegistered,
    );
    map['income_registered'] = Variable<double>(incomeRegistered);
    map['gains_registered'] = Variable<double>(gainsRegistered);
    map['sales_registered'] = Variable<double>(salesRegistered);
    map['extra_cash'] = Variable<double>(extraCash);
    map['spending_velocity'] = Variable<double>(spendingVelocity);
    map['savings_velocity'] = Variable<double>(savingsVelocity);
    map['profit_velocity'] = Variable<double>(profitVelocity);
    map['daily_ral'] = Variable<double>(dailyRal);
    map['eu_over_ral'] = Variable<double>(euOverRal);
    map['pension_value'] = Variable<double>(pensionValue);
    map['diff_hth'] = Variable<double>(diffHth);
    map['rt_at_ratio'] = Variable<double>(rtAtRatio);
    return map;
  }

  DailySnapshotsCompanion toCompanion(bool nullToAbsent) {
    return DailySnapshotsCompanion(
      id: Value(id),
      date: Value(date),
      accountBalances: Value(accountBalances),
      portfolioValue: Value(portfolioValue),
      investedAmount: Value(investedAmount),
      liquidCash: Value(liquidCash),
      totalSavings: Value(totalSavings),
      totalAssets: Value(totalAssets),
      liquidabile: Value(liquidabile),
      plEur: Value(plEur),
      netPlEur: Value(netPlEur),
      plAtPercent: Value(plAtPercent),
      plPtfPercent: Value(plPtfPercent),
      periodPlEur: Value(periodPlEur),
      periodPlAtPercent: Value(periodPlAtPercent),
      periodPlPtfPercent: Value(periodPlPtfPercent),
      logReturn: Value(logReturn),
      smaSavings: Value(smaSavings),
      smaExpenses: Value(smaExpenses),
      smaNetPl: Value(smaNetPl),
      annualizedVolatility: Value(annualizedVolatility),
      deltaSmaRt: Value(deltaSmaRt),
      income: Value(income),
      expenses: Value(expenses),
      cumulativeExpenses: Value(cumulativeExpenses),
      expensesAdjusted: Value(expensesAdjusted),
      reimbursementsRegistered: Value(reimbursementsRegistered),
      incomeRegistered: Value(incomeRegistered),
      gainsRegistered: Value(gainsRegistered),
      salesRegistered: Value(salesRegistered),
      extraCash: Value(extraCash),
      spendingVelocity: Value(spendingVelocity),
      savingsVelocity: Value(savingsVelocity),
      profitVelocity: Value(profitVelocity),
      dailyRal: Value(dailyRal),
      euOverRal: Value(euOverRal),
      pensionValue: Value(pensionValue),
      diffHth: Value(diffHth),
      rtAtRatio: Value(rtAtRatio),
    );
  }

  factory DailySnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySnapshot(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      accountBalances: serializer.fromJson<String>(json['accountBalances']),
      portfolioValue: serializer.fromJson<double>(json['portfolioValue']),
      investedAmount: serializer.fromJson<double>(json['investedAmount']),
      liquidCash: serializer.fromJson<double>(json['liquidCash']),
      totalSavings: serializer.fromJson<double>(json['totalSavings']),
      totalAssets: serializer.fromJson<double>(json['totalAssets']),
      liquidabile: serializer.fromJson<double>(json['liquidabile']),
      plEur: serializer.fromJson<double>(json['plEur']),
      netPlEur: serializer.fromJson<double>(json['netPlEur']),
      plAtPercent: serializer.fromJson<double>(json['plAtPercent']),
      plPtfPercent: serializer.fromJson<double>(json['plPtfPercent']),
      periodPlEur: serializer.fromJson<double>(json['periodPlEur']),
      periodPlAtPercent: serializer.fromJson<double>(json['periodPlAtPercent']),
      periodPlPtfPercent: serializer.fromJson<double>(
        json['periodPlPtfPercent'],
      ),
      logReturn: serializer.fromJson<double>(json['logReturn']),
      smaSavings: serializer.fromJson<double>(json['smaSavings']),
      smaExpenses: serializer.fromJson<double>(json['smaExpenses']),
      smaNetPl: serializer.fromJson<double>(json['smaNetPl']),
      annualizedVolatility: serializer.fromJson<double>(
        json['annualizedVolatility'],
      ),
      deltaSmaRt: serializer.fromJson<double>(json['deltaSmaRt']),
      income: serializer.fromJson<double>(json['income']),
      expenses: serializer.fromJson<double>(json['expenses']),
      cumulativeExpenses: serializer.fromJson<double>(
        json['cumulativeExpenses'],
      ),
      expensesAdjusted: serializer.fromJson<double>(json['expensesAdjusted']),
      reimbursementsRegistered: serializer.fromJson<double>(
        json['reimbursementsRegistered'],
      ),
      incomeRegistered: serializer.fromJson<double>(json['incomeRegistered']),
      gainsRegistered: serializer.fromJson<double>(json['gainsRegistered']),
      salesRegistered: serializer.fromJson<double>(json['salesRegistered']),
      extraCash: serializer.fromJson<double>(json['extraCash']),
      spendingVelocity: serializer.fromJson<double>(json['spendingVelocity']),
      savingsVelocity: serializer.fromJson<double>(json['savingsVelocity']),
      profitVelocity: serializer.fromJson<double>(json['profitVelocity']),
      dailyRal: serializer.fromJson<double>(json['dailyRal']),
      euOverRal: serializer.fromJson<double>(json['euOverRal']),
      pensionValue: serializer.fromJson<double>(json['pensionValue']),
      diffHth: serializer.fromJson<double>(json['diffHth']),
      rtAtRatio: serializer.fromJson<double>(json['rtAtRatio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'accountBalances': serializer.toJson<String>(accountBalances),
      'portfolioValue': serializer.toJson<double>(portfolioValue),
      'investedAmount': serializer.toJson<double>(investedAmount),
      'liquidCash': serializer.toJson<double>(liquidCash),
      'totalSavings': serializer.toJson<double>(totalSavings),
      'totalAssets': serializer.toJson<double>(totalAssets),
      'liquidabile': serializer.toJson<double>(liquidabile),
      'plEur': serializer.toJson<double>(plEur),
      'netPlEur': serializer.toJson<double>(netPlEur),
      'plAtPercent': serializer.toJson<double>(plAtPercent),
      'plPtfPercent': serializer.toJson<double>(plPtfPercent),
      'periodPlEur': serializer.toJson<double>(periodPlEur),
      'periodPlAtPercent': serializer.toJson<double>(periodPlAtPercent),
      'periodPlPtfPercent': serializer.toJson<double>(periodPlPtfPercent),
      'logReturn': serializer.toJson<double>(logReturn),
      'smaSavings': serializer.toJson<double>(smaSavings),
      'smaExpenses': serializer.toJson<double>(smaExpenses),
      'smaNetPl': serializer.toJson<double>(smaNetPl),
      'annualizedVolatility': serializer.toJson<double>(annualizedVolatility),
      'deltaSmaRt': serializer.toJson<double>(deltaSmaRt),
      'income': serializer.toJson<double>(income),
      'expenses': serializer.toJson<double>(expenses),
      'cumulativeExpenses': serializer.toJson<double>(cumulativeExpenses),
      'expensesAdjusted': serializer.toJson<double>(expensesAdjusted),
      'reimbursementsRegistered': serializer.toJson<double>(
        reimbursementsRegistered,
      ),
      'incomeRegistered': serializer.toJson<double>(incomeRegistered),
      'gainsRegistered': serializer.toJson<double>(gainsRegistered),
      'salesRegistered': serializer.toJson<double>(salesRegistered),
      'extraCash': serializer.toJson<double>(extraCash),
      'spendingVelocity': serializer.toJson<double>(spendingVelocity),
      'savingsVelocity': serializer.toJson<double>(savingsVelocity),
      'profitVelocity': serializer.toJson<double>(profitVelocity),
      'dailyRal': serializer.toJson<double>(dailyRal),
      'euOverRal': serializer.toJson<double>(euOverRal),
      'pensionValue': serializer.toJson<double>(pensionValue),
      'diffHth': serializer.toJson<double>(diffHth),
      'rtAtRatio': serializer.toJson<double>(rtAtRatio),
    };
  }

  DailySnapshot copyWith({
    int? id,
    DateTime? date,
    String? accountBalances,
    double? portfolioValue,
    double? investedAmount,
    double? liquidCash,
    double? totalSavings,
    double? totalAssets,
    double? liquidabile,
    double? plEur,
    double? netPlEur,
    double? plAtPercent,
    double? plPtfPercent,
    double? periodPlEur,
    double? periodPlAtPercent,
    double? periodPlPtfPercent,
    double? logReturn,
    double? smaSavings,
    double? smaExpenses,
    double? smaNetPl,
    double? annualizedVolatility,
    double? deltaSmaRt,
    double? income,
    double? expenses,
    double? cumulativeExpenses,
    double? expensesAdjusted,
    double? reimbursementsRegistered,
    double? incomeRegistered,
    double? gainsRegistered,
    double? salesRegistered,
    double? extraCash,
    double? spendingVelocity,
    double? savingsVelocity,
    double? profitVelocity,
    double? dailyRal,
    double? euOverRal,
    double? pensionValue,
    double? diffHth,
    double? rtAtRatio,
  }) => DailySnapshot(
    id: id ?? this.id,
    date: date ?? this.date,
    accountBalances: accountBalances ?? this.accountBalances,
    portfolioValue: portfolioValue ?? this.portfolioValue,
    investedAmount: investedAmount ?? this.investedAmount,
    liquidCash: liquidCash ?? this.liquidCash,
    totalSavings: totalSavings ?? this.totalSavings,
    totalAssets: totalAssets ?? this.totalAssets,
    liquidabile: liquidabile ?? this.liquidabile,
    plEur: plEur ?? this.plEur,
    netPlEur: netPlEur ?? this.netPlEur,
    plAtPercent: plAtPercent ?? this.plAtPercent,
    plPtfPercent: plPtfPercent ?? this.plPtfPercent,
    periodPlEur: periodPlEur ?? this.periodPlEur,
    periodPlAtPercent: periodPlAtPercent ?? this.periodPlAtPercent,
    periodPlPtfPercent: periodPlPtfPercent ?? this.periodPlPtfPercent,
    logReturn: logReturn ?? this.logReturn,
    smaSavings: smaSavings ?? this.smaSavings,
    smaExpenses: smaExpenses ?? this.smaExpenses,
    smaNetPl: smaNetPl ?? this.smaNetPl,
    annualizedVolatility: annualizedVolatility ?? this.annualizedVolatility,
    deltaSmaRt: deltaSmaRt ?? this.deltaSmaRt,
    income: income ?? this.income,
    expenses: expenses ?? this.expenses,
    cumulativeExpenses: cumulativeExpenses ?? this.cumulativeExpenses,
    expensesAdjusted: expensesAdjusted ?? this.expensesAdjusted,
    reimbursementsRegistered:
        reimbursementsRegistered ?? this.reimbursementsRegistered,
    incomeRegistered: incomeRegistered ?? this.incomeRegistered,
    gainsRegistered: gainsRegistered ?? this.gainsRegistered,
    salesRegistered: salesRegistered ?? this.salesRegistered,
    extraCash: extraCash ?? this.extraCash,
    spendingVelocity: spendingVelocity ?? this.spendingVelocity,
    savingsVelocity: savingsVelocity ?? this.savingsVelocity,
    profitVelocity: profitVelocity ?? this.profitVelocity,
    dailyRal: dailyRal ?? this.dailyRal,
    euOverRal: euOverRal ?? this.euOverRal,
    pensionValue: pensionValue ?? this.pensionValue,
    diffHth: diffHth ?? this.diffHth,
    rtAtRatio: rtAtRatio ?? this.rtAtRatio,
  );
  DailySnapshot copyWithCompanion(DailySnapshotsCompanion data) {
    return DailySnapshot(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      accountBalances: data.accountBalances.present
          ? data.accountBalances.value
          : this.accountBalances,
      portfolioValue: data.portfolioValue.present
          ? data.portfolioValue.value
          : this.portfolioValue,
      investedAmount: data.investedAmount.present
          ? data.investedAmount.value
          : this.investedAmount,
      liquidCash: data.liquidCash.present
          ? data.liquidCash.value
          : this.liquidCash,
      totalSavings: data.totalSavings.present
          ? data.totalSavings.value
          : this.totalSavings,
      totalAssets: data.totalAssets.present
          ? data.totalAssets.value
          : this.totalAssets,
      liquidabile: data.liquidabile.present
          ? data.liquidabile.value
          : this.liquidabile,
      plEur: data.plEur.present ? data.plEur.value : this.plEur,
      netPlEur: data.netPlEur.present ? data.netPlEur.value : this.netPlEur,
      plAtPercent: data.plAtPercent.present
          ? data.plAtPercent.value
          : this.plAtPercent,
      plPtfPercent: data.plPtfPercent.present
          ? data.plPtfPercent.value
          : this.plPtfPercent,
      periodPlEur: data.periodPlEur.present
          ? data.periodPlEur.value
          : this.periodPlEur,
      periodPlAtPercent: data.periodPlAtPercent.present
          ? data.periodPlAtPercent.value
          : this.periodPlAtPercent,
      periodPlPtfPercent: data.periodPlPtfPercent.present
          ? data.periodPlPtfPercent.value
          : this.periodPlPtfPercent,
      logReturn: data.logReturn.present ? data.logReturn.value : this.logReturn,
      smaSavings: data.smaSavings.present
          ? data.smaSavings.value
          : this.smaSavings,
      smaExpenses: data.smaExpenses.present
          ? data.smaExpenses.value
          : this.smaExpenses,
      smaNetPl: data.smaNetPl.present ? data.smaNetPl.value : this.smaNetPl,
      annualizedVolatility: data.annualizedVolatility.present
          ? data.annualizedVolatility.value
          : this.annualizedVolatility,
      deltaSmaRt: data.deltaSmaRt.present
          ? data.deltaSmaRt.value
          : this.deltaSmaRt,
      income: data.income.present ? data.income.value : this.income,
      expenses: data.expenses.present ? data.expenses.value : this.expenses,
      cumulativeExpenses: data.cumulativeExpenses.present
          ? data.cumulativeExpenses.value
          : this.cumulativeExpenses,
      expensesAdjusted: data.expensesAdjusted.present
          ? data.expensesAdjusted.value
          : this.expensesAdjusted,
      reimbursementsRegistered: data.reimbursementsRegistered.present
          ? data.reimbursementsRegistered.value
          : this.reimbursementsRegistered,
      incomeRegistered: data.incomeRegistered.present
          ? data.incomeRegistered.value
          : this.incomeRegistered,
      gainsRegistered: data.gainsRegistered.present
          ? data.gainsRegistered.value
          : this.gainsRegistered,
      salesRegistered: data.salesRegistered.present
          ? data.salesRegistered.value
          : this.salesRegistered,
      extraCash: data.extraCash.present ? data.extraCash.value : this.extraCash,
      spendingVelocity: data.spendingVelocity.present
          ? data.spendingVelocity.value
          : this.spendingVelocity,
      savingsVelocity: data.savingsVelocity.present
          ? data.savingsVelocity.value
          : this.savingsVelocity,
      profitVelocity: data.profitVelocity.present
          ? data.profitVelocity.value
          : this.profitVelocity,
      dailyRal: data.dailyRal.present ? data.dailyRal.value : this.dailyRal,
      euOverRal: data.euOverRal.present ? data.euOverRal.value : this.euOverRal,
      pensionValue: data.pensionValue.present
          ? data.pensionValue.value
          : this.pensionValue,
      diffHth: data.diffHth.present ? data.diffHth.value : this.diffHth,
      rtAtRatio: data.rtAtRatio.present ? data.rtAtRatio.value : this.rtAtRatio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySnapshot(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('accountBalances: $accountBalances, ')
          ..write('portfolioValue: $portfolioValue, ')
          ..write('investedAmount: $investedAmount, ')
          ..write('liquidCash: $liquidCash, ')
          ..write('totalSavings: $totalSavings, ')
          ..write('totalAssets: $totalAssets, ')
          ..write('liquidabile: $liquidabile, ')
          ..write('plEur: $plEur, ')
          ..write('netPlEur: $netPlEur, ')
          ..write('plAtPercent: $plAtPercent, ')
          ..write('plPtfPercent: $plPtfPercent, ')
          ..write('periodPlEur: $periodPlEur, ')
          ..write('periodPlAtPercent: $periodPlAtPercent, ')
          ..write('periodPlPtfPercent: $periodPlPtfPercent, ')
          ..write('logReturn: $logReturn, ')
          ..write('smaSavings: $smaSavings, ')
          ..write('smaExpenses: $smaExpenses, ')
          ..write('smaNetPl: $smaNetPl, ')
          ..write('annualizedVolatility: $annualizedVolatility, ')
          ..write('deltaSmaRt: $deltaSmaRt, ')
          ..write('income: $income, ')
          ..write('expenses: $expenses, ')
          ..write('cumulativeExpenses: $cumulativeExpenses, ')
          ..write('expensesAdjusted: $expensesAdjusted, ')
          ..write('reimbursementsRegistered: $reimbursementsRegistered, ')
          ..write('incomeRegistered: $incomeRegistered, ')
          ..write('gainsRegistered: $gainsRegistered, ')
          ..write('salesRegistered: $salesRegistered, ')
          ..write('extraCash: $extraCash, ')
          ..write('spendingVelocity: $spendingVelocity, ')
          ..write('savingsVelocity: $savingsVelocity, ')
          ..write('profitVelocity: $profitVelocity, ')
          ..write('dailyRal: $dailyRal, ')
          ..write('euOverRal: $euOverRal, ')
          ..write('pensionValue: $pensionValue, ')
          ..write('diffHth: $diffHth, ')
          ..write('rtAtRatio: $rtAtRatio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    date,
    accountBalances,
    portfolioValue,
    investedAmount,
    liquidCash,
    totalSavings,
    totalAssets,
    liquidabile,
    plEur,
    netPlEur,
    plAtPercent,
    plPtfPercent,
    periodPlEur,
    periodPlAtPercent,
    periodPlPtfPercent,
    logReturn,
    smaSavings,
    smaExpenses,
    smaNetPl,
    annualizedVolatility,
    deltaSmaRt,
    income,
    expenses,
    cumulativeExpenses,
    expensesAdjusted,
    reimbursementsRegistered,
    incomeRegistered,
    gainsRegistered,
    salesRegistered,
    extraCash,
    spendingVelocity,
    savingsVelocity,
    profitVelocity,
    dailyRal,
    euOverRal,
    pensionValue,
    diffHth,
    rtAtRatio,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySnapshot &&
          other.id == this.id &&
          other.date == this.date &&
          other.accountBalances == this.accountBalances &&
          other.portfolioValue == this.portfolioValue &&
          other.investedAmount == this.investedAmount &&
          other.liquidCash == this.liquidCash &&
          other.totalSavings == this.totalSavings &&
          other.totalAssets == this.totalAssets &&
          other.liquidabile == this.liquidabile &&
          other.plEur == this.plEur &&
          other.netPlEur == this.netPlEur &&
          other.plAtPercent == this.plAtPercent &&
          other.plPtfPercent == this.plPtfPercent &&
          other.periodPlEur == this.periodPlEur &&
          other.periodPlAtPercent == this.periodPlAtPercent &&
          other.periodPlPtfPercent == this.periodPlPtfPercent &&
          other.logReturn == this.logReturn &&
          other.smaSavings == this.smaSavings &&
          other.smaExpenses == this.smaExpenses &&
          other.smaNetPl == this.smaNetPl &&
          other.annualizedVolatility == this.annualizedVolatility &&
          other.deltaSmaRt == this.deltaSmaRt &&
          other.income == this.income &&
          other.expenses == this.expenses &&
          other.cumulativeExpenses == this.cumulativeExpenses &&
          other.expensesAdjusted == this.expensesAdjusted &&
          other.reimbursementsRegistered == this.reimbursementsRegistered &&
          other.incomeRegistered == this.incomeRegistered &&
          other.gainsRegistered == this.gainsRegistered &&
          other.salesRegistered == this.salesRegistered &&
          other.extraCash == this.extraCash &&
          other.spendingVelocity == this.spendingVelocity &&
          other.savingsVelocity == this.savingsVelocity &&
          other.profitVelocity == this.profitVelocity &&
          other.dailyRal == this.dailyRal &&
          other.euOverRal == this.euOverRal &&
          other.pensionValue == this.pensionValue &&
          other.diffHth == this.diffHth &&
          other.rtAtRatio == this.rtAtRatio);
}

class DailySnapshotsCompanion extends UpdateCompanion<DailySnapshot> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> accountBalances;
  final Value<double> portfolioValue;
  final Value<double> investedAmount;
  final Value<double> liquidCash;
  final Value<double> totalSavings;
  final Value<double> totalAssets;
  final Value<double> liquidabile;
  final Value<double> plEur;
  final Value<double> netPlEur;
  final Value<double> plAtPercent;
  final Value<double> plPtfPercent;
  final Value<double> periodPlEur;
  final Value<double> periodPlAtPercent;
  final Value<double> periodPlPtfPercent;
  final Value<double> logReturn;
  final Value<double> smaSavings;
  final Value<double> smaExpenses;
  final Value<double> smaNetPl;
  final Value<double> annualizedVolatility;
  final Value<double> deltaSmaRt;
  final Value<double> income;
  final Value<double> expenses;
  final Value<double> cumulativeExpenses;
  final Value<double> expensesAdjusted;
  final Value<double> reimbursementsRegistered;
  final Value<double> incomeRegistered;
  final Value<double> gainsRegistered;
  final Value<double> salesRegistered;
  final Value<double> extraCash;
  final Value<double> spendingVelocity;
  final Value<double> savingsVelocity;
  final Value<double> profitVelocity;
  final Value<double> dailyRal;
  final Value<double> euOverRal;
  final Value<double> pensionValue;
  final Value<double> diffHth;
  final Value<double> rtAtRatio;
  const DailySnapshotsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.accountBalances = const Value.absent(),
    this.portfolioValue = const Value.absent(),
    this.investedAmount = const Value.absent(),
    this.liquidCash = const Value.absent(),
    this.totalSavings = const Value.absent(),
    this.totalAssets = const Value.absent(),
    this.liquidabile = const Value.absent(),
    this.plEur = const Value.absent(),
    this.netPlEur = const Value.absent(),
    this.plAtPercent = const Value.absent(),
    this.plPtfPercent = const Value.absent(),
    this.periodPlEur = const Value.absent(),
    this.periodPlAtPercent = const Value.absent(),
    this.periodPlPtfPercent = const Value.absent(),
    this.logReturn = const Value.absent(),
    this.smaSavings = const Value.absent(),
    this.smaExpenses = const Value.absent(),
    this.smaNetPl = const Value.absent(),
    this.annualizedVolatility = const Value.absent(),
    this.deltaSmaRt = const Value.absent(),
    this.income = const Value.absent(),
    this.expenses = const Value.absent(),
    this.cumulativeExpenses = const Value.absent(),
    this.expensesAdjusted = const Value.absent(),
    this.reimbursementsRegistered = const Value.absent(),
    this.incomeRegistered = const Value.absent(),
    this.gainsRegistered = const Value.absent(),
    this.salesRegistered = const Value.absent(),
    this.extraCash = const Value.absent(),
    this.spendingVelocity = const Value.absent(),
    this.savingsVelocity = const Value.absent(),
    this.profitVelocity = const Value.absent(),
    this.dailyRal = const Value.absent(),
    this.euOverRal = const Value.absent(),
    this.pensionValue = const Value.absent(),
    this.diffHth = const Value.absent(),
    this.rtAtRatio = const Value.absent(),
  });
  DailySnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    this.accountBalances = const Value.absent(),
    this.portfolioValue = const Value.absent(),
    this.investedAmount = const Value.absent(),
    this.liquidCash = const Value.absent(),
    this.totalSavings = const Value.absent(),
    this.totalAssets = const Value.absent(),
    this.liquidabile = const Value.absent(),
    this.plEur = const Value.absent(),
    this.netPlEur = const Value.absent(),
    this.plAtPercent = const Value.absent(),
    this.plPtfPercent = const Value.absent(),
    this.periodPlEur = const Value.absent(),
    this.periodPlAtPercent = const Value.absent(),
    this.periodPlPtfPercent = const Value.absent(),
    this.logReturn = const Value.absent(),
    this.smaSavings = const Value.absent(),
    this.smaExpenses = const Value.absent(),
    this.smaNetPl = const Value.absent(),
    this.annualizedVolatility = const Value.absent(),
    this.deltaSmaRt = const Value.absent(),
    this.income = const Value.absent(),
    this.expenses = const Value.absent(),
    this.cumulativeExpenses = const Value.absent(),
    this.expensesAdjusted = const Value.absent(),
    this.reimbursementsRegistered = const Value.absent(),
    this.incomeRegistered = const Value.absent(),
    this.gainsRegistered = const Value.absent(),
    this.salesRegistered = const Value.absent(),
    this.extraCash = const Value.absent(),
    this.spendingVelocity = const Value.absent(),
    this.savingsVelocity = const Value.absent(),
    this.profitVelocity = const Value.absent(),
    this.dailyRal = const Value.absent(),
    this.euOverRal = const Value.absent(),
    this.pensionValue = const Value.absent(),
    this.diffHth = const Value.absent(),
    this.rtAtRatio = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailySnapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? accountBalances,
    Expression<double>? portfolioValue,
    Expression<double>? investedAmount,
    Expression<double>? liquidCash,
    Expression<double>? totalSavings,
    Expression<double>? totalAssets,
    Expression<double>? liquidabile,
    Expression<double>? plEur,
    Expression<double>? netPlEur,
    Expression<double>? plAtPercent,
    Expression<double>? plPtfPercent,
    Expression<double>? periodPlEur,
    Expression<double>? periodPlAtPercent,
    Expression<double>? periodPlPtfPercent,
    Expression<double>? logReturn,
    Expression<double>? smaSavings,
    Expression<double>? smaExpenses,
    Expression<double>? smaNetPl,
    Expression<double>? annualizedVolatility,
    Expression<double>? deltaSmaRt,
    Expression<double>? income,
    Expression<double>? expenses,
    Expression<double>? cumulativeExpenses,
    Expression<double>? expensesAdjusted,
    Expression<double>? reimbursementsRegistered,
    Expression<double>? incomeRegistered,
    Expression<double>? gainsRegistered,
    Expression<double>? salesRegistered,
    Expression<double>? extraCash,
    Expression<double>? spendingVelocity,
    Expression<double>? savingsVelocity,
    Expression<double>? profitVelocity,
    Expression<double>? dailyRal,
    Expression<double>? euOverRal,
    Expression<double>? pensionValue,
    Expression<double>? diffHth,
    Expression<double>? rtAtRatio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (accountBalances != null) 'account_balances': accountBalances,
      if (portfolioValue != null) 'portfolio_value': portfolioValue,
      if (investedAmount != null) 'invested_amount': investedAmount,
      if (liquidCash != null) 'liquid_cash': liquidCash,
      if (totalSavings != null) 'total_savings': totalSavings,
      if (totalAssets != null) 'total_assets': totalAssets,
      if (liquidabile != null) 'liquidabile': liquidabile,
      if (plEur != null) 'pl_eur': plEur,
      if (netPlEur != null) 'net_pl_eur': netPlEur,
      if (plAtPercent != null) 'pl_at_percent': plAtPercent,
      if (plPtfPercent != null) 'pl_ptf_percent': plPtfPercent,
      if (periodPlEur != null) 'period_pl_eur': periodPlEur,
      if (periodPlAtPercent != null) 'period_pl_at_percent': periodPlAtPercent,
      if (periodPlPtfPercent != null)
        'period_pl_ptf_percent': periodPlPtfPercent,
      if (logReturn != null) 'log_return': logReturn,
      if (smaSavings != null) 'sma_savings': smaSavings,
      if (smaExpenses != null) 'sma_expenses': smaExpenses,
      if (smaNetPl != null) 'sma_net_pl': smaNetPl,
      if (annualizedVolatility != null)
        'annualized_volatility': annualizedVolatility,
      if (deltaSmaRt != null) 'delta_sma_rt': deltaSmaRt,
      if (income != null) 'income': income,
      if (expenses != null) 'expenses': expenses,
      if (cumulativeExpenses != null) 'cumulative_expenses': cumulativeExpenses,
      if (expensesAdjusted != null) 'expenses_adjusted': expensesAdjusted,
      if (reimbursementsRegistered != null)
        'reimbursements_registered': reimbursementsRegistered,
      if (incomeRegistered != null) 'income_registered': incomeRegistered,
      if (gainsRegistered != null) 'gains_registered': gainsRegistered,
      if (salesRegistered != null) 'sales_registered': salesRegistered,
      if (extraCash != null) 'extra_cash': extraCash,
      if (spendingVelocity != null) 'spending_velocity': spendingVelocity,
      if (savingsVelocity != null) 'savings_velocity': savingsVelocity,
      if (profitVelocity != null) 'profit_velocity': profitVelocity,
      if (dailyRal != null) 'daily_ral': dailyRal,
      if (euOverRal != null) 'eu_over_ral': euOverRal,
      if (pensionValue != null) 'pension_value': pensionValue,
      if (diffHth != null) 'diff_hth': diffHth,
      if (rtAtRatio != null) 'rt_at_ratio': rtAtRatio,
    });
  }

  DailySnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? accountBalances,
    Value<double>? portfolioValue,
    Value<double>? investedAmount,
    Value<double>? liquidCash,
    Value<double>? totalSavings,
    Value<double>? totalAssets,
    Value<double>? liquidabile,
    Value<double>? plEur,
    Value<double>? netPlEur,
    Value<double>? plAtPercent,
    Value<double>? plPtfPercent,
    Value<double>? periodPlEur,
    Value<double>? periodPlAtPercent,
    Value<double>? periodPlPtfPercent,
    Value<double>? logReturn,
    Value<double>? smaSavings,
    Value<double>? smaExpenses,
    Value<double>? smaNetPl,
    Value<double>? annualizedVolatility,
    Value<double>? deltaSmaRt,
    Value<double>? income,
    Value<double>? expenses,
    Value<double>? cumulativeExpenses,
    Value<double>? expensesAdjusted,
    Value<double>? reimbursementsRegistered,
    Value<double>? incomeRegistered,
    Value<double>? gainsRegistered,
    Value<double>? salesRegistered,
    Value<double>? extraCash,
    Value<double>? spendingVelocity,
    Value<double>? savingsVelocity,
    Value<double>? profitVelocity,
    Value<double>? dailyRal,
    Value<double>? euOverRal,
    Value<double>? pensionValue,
    Value<double>? diffHth,
    Value<double>? rtAtRatio,
  }) {
    return DailySnapshotsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      accountBalances: accountBalances ?? this.accountBalances,
      portfolioValue: portfolioValue ?? this.portfolioValue,
      investedAmount: investedAmount ?? this.investedAmount,
      liquidCash: liquidCash ?? this.liquidCash,
      totalSavings: totalSavings ?? this.totalSavings,
      totalAssets: totalAssets ?? this.totalAssets,
      liquidabile: liquidabile ?? this.liquidabile,
      plEur: plEur ?? this.plEur,
      netPlEur: netPlEur ?? this.netPlEur,
      plAtPercent: plAtPercent ?? this.plAtPercent,
      plPtfPercent: plPtfPercent ?? this.plPtfPercent,
      periodPlEur: periodPlEur ?? this.periodPlEur,
      periodPlAtPercent: periodPlAtPercent ?? this.periodPlAtPercent,
      periodPlPtfPercent: periodPlPtfPercent ?? this.periodPlPtfPercent,
      logReturn: logReturn ?? this.logReturn,
      smaSavings: smaSavings ?? this.smaSavings,
      smaExpenses: smaExpenses ?? this.smaExpenses,
      smaNetPl: smaNetPl ?? this.smaNetPl,
      annualizedVolatility: annualizedVolatility ?? this.annualizedVolatility,
      deltaSmaRt: deltaSmaRt ?? this.deltaSmaRt,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      cumulativeExpenses: cumulativeExpenses ?? this.cumulativeExpenses,
      expensesAdjusted: expensesAdjusted ?? this.expensesAdjusted,
      reimbursementsRegistered:
          reimbursementsRegistered ?? this.reimbursementsRegistered,
      incomeRegistered: incomeRegistered ?? this.incomeRegistered,
      gainsRegistered: gainsRegistered ?? this.gainsRegistered,
      salesRegistered: salesRegistered ?? this.salesRegistered,
      extraCash: extraCash ?? this.extraCash,
      spendingVelocity: spendingVelocity ?? this.spendingVelocity,
      savingsVelocity: savingsVelocity ?? this.savingsVelocity,
      profitVelocity: profitVelocity ?? this.profitVelocity,
      dailyRal: dailyRal ?? this.dailyRal,
      euOverRal: euOverRal ?? this.euOverRal,
      pensionValue: pensionValue ?? this.pensionValue,
      diffHth: diffHth ?? this.diffHth,
      rtAtRatio: rtAtRatio ?? this.rtAtRatio,
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
    if (accountBalances.present) {
      map['account_balances'] = Variable<String>(accountBalances.value);
    }
    if (portfolioValue.present) {
      map['portfolio_value'] = Variable<double>(portfolioValue.value);
    }
    if (investedAmount.present) {
      map['invested_amount'] = Variable<double>(investedAmount.value);
    }
    if (liquidCash.present) {
      map['liquid_cash'] = Variable<double>(liquidCash.value);
    }
    if (totalSavings.present) {
      map['total_savings'] = Variable<double>(totalSavings.value);
    }
    if (totalAssets.present) {
      map['total_assets'] = Variable<double>(totalAssets.value);
    }
    if (liquidabile.present) {
      map['liquidabile'] = Variable<double>(liquidabile.value);
    }
    if (plEur.present) {
      map['pl_eur'] = Variable<double>(plEur.value);
    }
    if (netPlEur.present) {
      map['net_pl_eur'] = Variable<double>(netPlEur.value);
    }
    if (plAtPercent.present) {
      map['pl_at_percent'] = Variable<double>(plAtPercent.value);
    }
    if (plPtfPercent.present) {
      map['pl_ptf_percent'] = Variable<double>(plPtfPercent.value);
    }
    if (periodPlEur.present) {
      map['period_pl_eur'] = Variable<double>(periodPlEur.value);
    }
    if (periodPlAtPercent.present) {
      map['period_pl_at_percent'] = Variable<double>(periodPlAtPercent.value);
    }
    if (periodPlPtfPercent.present) {
      map['period_pl_ptf_percent'] = Variable<double>(periodPlPtfPercent.value);
    }
    if (logReturn.present) {
      map['log_return'] = Variable<double>(logReturn.value);
    }
    if (smaSavings.present) {
      map['sma_savings'] = Variable<double>(smaSavings.value);
    }
    if (smaExpenses.present) {
      map['sma_expenses'] = Variable<double>(smaExpenses.value);
    }
    if (smaNetPl.present) {
      map['sma_net_pl'] = Variable<double>(smaNetPl.value);
    }
    if (annualizedVolatility.present) {
      map['annualized_volatility'] = Variable<double>(
        annualizedVolatility.value,
      );
    }
    if (deltaSmaRt.present) {
      map['delta_sma_rt'] = Variable<double>(deltaSmaRt.value);
    }
    if (income.present) {
      map['income'] = Variable<double>(income.value);
    }
    if (expenses.present) {
      map['expenses'] = Variable<double>(expenses.value);
    }
    if (cumulativeExpenses.present) {
      map['cumulative_expenses'] = Variable<double>(cumulativeExpenses.value);
    }
    if (expensesAdjusted.present) {
      map['expenses_adjusted'] = Variable<double>(expensesAdjusted.value);
    }
    if (reimbursementsRegistered.present) {
      map['reimbursements_registered'] = Variable<double>(
        reimbursementsRegistered.value,
      );
    }
    if (incomeRegistered.present) {
      map['income_registered'] = Variable<double>(incomeRegistered.value);
    }
    if (gainsRegistered.present) {
      map['gains_registered'] = Variable<double>(gainsRegistered.value);
    }
    if (salesRegistered.present) {
      map['sales_registered'] = Variable<double>(salesRegistered.value);
    }
    if (extraCash.present) {
      map['extra_cash'] = Variable<double>(extraCash.value);
    }
    if (spendingVelocity.present) {
      map['spending_velocity'] = Variable<double>(spendingVelocity.value);
    }
    if (savingsVelocity.present) {
      map['savings_velocity'] = Variable<double>(savingsVelocity.value);
    }
    if (profitVelocity.present) {
      map['profit_velocity'] = Variable<double>(profitVelocity.value);
    }
    if (dailyRal.present) {
      map['daily_ral'] = Variable<double>(dailyRal.value);
    }
    if (euOverRal.present) {
      map['eu_over_ral'] = Variable<double>(euOverRal.value);
    }
    if (pensionValue.present) {
      map['pension_value'] = Variable<double>(pensionValue.value);
    }
    if (diffHth.present) {
      map['diff_hth'] = Variable<double>(diffHth.value);
    }
    if (rtAtRatio.present) {
      map['rt_at_ratio'] = Variable<double>(rtAtRatio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('accountBalances: $accountBalances, ')
          ..write('portfolioValue: $portfolioValue, ')
          ..write('investedAmount: $investedAmount, ')
          ..write('liquidCash: $liquidCash, ')
          ..write('totalSavings: $totalSavings, ')
          ..write('totalAssets: $totalAssets, ')
          ..write('liquidabile: $liquidabile, ')
          ..write('plEur: $plEur, ')
          ..write('netPlEur: $netPlEur, ')
          ..write('plAtPercent: $plAtPercent, ')
          ..write('plPtfPercent: $plPtfPercent, ')
          ..write('periodPlEur: $periodPlEur, ')
          ..write('periodPlAtPercent: $periodPlAtPercent, ')
          ..write('periodPlPtfPercent: $periodPlPtfPercent, ')
          ..write('logReturn: $logReturn, ')
          ..write('smaSavings: $smaSavings, ')
          ..write('smaExpenses: $smaExpenses, ')
          ..write('smaNetPl: $smaNetPl, ')
          ..write('annualizedVolatility: $annualizedVolatility, ')
          ..write('deltaSmaRt: $deltaSmaRt, ')
          ..write('income: $income, ')
          ..write('expenses: $expenses, ')
          ..write('cumulativeExpenses: $cumulativeExpenses, ')
          ..write('expensesAdjusted: $expensesAdjusted, ')
          ..write('reimbursementsRegistered: $reimbursementsRegistered, ')
          ..write('incomeRegistered: $incomeRegistered, ')
          ..write('gainsRegistered: $gainsRegistered, ')
          ..write('salesRegistered: $salesRegistered, ')
          ..write('extraCash: $extraCash, ')
          ..write('spendingVelocity: $spendingVelocity, ')
          ..write('savingsVelocity: $savingsVelocity, ')
          ..write('profitVelocity: $profitVelocity, ')
          ..write('dailyRal: $dailyRal, ')
          ..write('euOverRal: $euOverRal, ')
          ..write('pensionValue: $pensionValue, ')
          ..write('diffHth: $diffHth, ')
          ..write('rtAtRatio: $rtAtRatio')
          ..write(')'))
        .toString();
  }
}

class $DepreciationSchedulesTable extends DepreciationSchedules
    with TableInfo<$DepreciationSchedulesTable, DepreciationSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DepreciationSchedulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _assetNameMeta = const VerificationMeta(
    'assetName',
  );
  @override
  late final GeneratedColumn<String> assetName = GeneratedColumn<String>(
    'asset_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetCategoryMeta = const VerificationMeta(
    'assetCategory',
  );
  @override
  late final GeneratedColumn<String> assetCategory = GeneratedColumn<String>(
    'asset_category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  late final GeneratedColumnWithTypeConverter<DepreciationMethod, String>
  method =
      GeneratedColumn<String>(
        'method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DepreciationMethod>(
        $DepreciationSchedulesTable.$convertermethod,
      );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseDateMeta = const VerificationMeta(
    'expenseDate',
  );
  @override
  late final GeneratedColumn<DateTime> expenseDate = GeneratedColumn<DateTime>(
    'expense_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usefulLifeMonthsMeta = const VerificationMeta(
    'usefulLifeMonths',
  );
  @override
  late final GeneratedColumn<int> usefulLifeMonths = GeneratedColumn<int>(
    'useful_life_months',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DepreciationDirection, String>
  direction =
      GeneratedColumn<String>(
        'direction',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DepreciationDirection>(
        $DepreciationSchedulesTable.$converterdirection,
      );
  @override
  late final GeneratedColumnWithTypeConverter<StepFrequency, String>
  stepFrequency =
      GeneratedColumn<String>(
        'step_frequency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(StepFrequency.monthly.name),
      ).withConverter<StepFrequency>(
        $DepreciationSchedulesTable.$converterstepFrequency,
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
    transactionId,
    assetName,
    assetCategory,
    totalAmount,
    currency,
    method,
    startDate,
    endDate,
    expenseDate,
    usefulLifeMonths,
    direction,
    stepFrequency,
    bufferId,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'depreciation_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<DepreciationSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('asset_name')) {
      context.handle(
        _assetNameMeta,
        assetName.isAcceptableOrUnknown(data['asset_name']!, _assetNameMeta),
      );
    } else if (isInserting) {
      context.missing(_assetNameMeta);
    }
    if (data.containsKey('asset_category')) {
      context.handle(
        _assetCategoryMeta,
        assetCategory.isAcceptableOrUnknown(
          data['asset_category']!,
          _assetCategoryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetCategoryMeta);
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
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('expense_date')) {
      context.handle(
        _expenseDateMeta,
        expenseDate.isAcceptableOrUnknown(
          data['expense_date']!,
          _expenseDateMeta,
        ),
      );
    }
    if (data.containsKey('useful_life_months')) {
      context.handle(
        _usefulLifeMonthsMeta,
        usefulLifeMonths.isAcceptableOrUnknown(
          data['useful_life_months']!,
          _usefulLifeMonthsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usefulLifeMonthsMeta);
    }
    if (data.containsKey('buffer_id')) {
      context.handle(
        _bufferIdMeta,
        bufferId.isAcceptableOrUnknown(data['buffer_id']!, _bufferIdMeta),
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
  DepreciationSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DepreciationSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      ),
      assetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_name'],
      )!,
      assetCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_category'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      method: $DepreciationSchedulesTable.$convertermethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}method'],
        )!,
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      expenseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expense_date'],
      ),
      usefulLifeMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}useful_life_months'],
      )!,
      direction: $DepreciationSchedulesTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      stepFrequency: $DepreciationSchedulesTable.$converterstepFrequency
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}step_frequency'],
            )!,
          ),
      bufferId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buffer_id'],
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
  $DepreciationSchedulesTable createAlias(String alias) {
    return $DepreciationSchedulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DepreciationMethod, String, String>
  $convertermethod = const EnumNameConverter<DepreciationMethod>(
    DepreciationMethod.values,
  );
  static JsonTypeConverter2<DepreciationDirection, String, String>
  $converterdirection = const EnumNameConverter<DepreciationDirection>(
    DepreciationDirection.values,
  );
  static JsonTypeConverter2<StepFrequency, String, String>
  $converterstepFrequency = const EnumNameConverter<StepFrequency>(
    StepFrequency.values,
  );
}

class DepreciationSchedule extends DataClass
    implements Insertable<DepreciationSchedule> {
  final int id;
  final int? transactionId;
  final String assetName;
  final String assetCategory;
  final double totalAmount;
  final String currency;
  final DepreciationMethod method;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? expenseDate;
  final int usefulLifeMonths;
  final DepreciationDirection direction;
  final StepFrequency stepFrequency;
  final int? bufferId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DepreciationSchedule({
    required this.id,
    this.transactionId,
    required this.assetName,
    required this.assetCategory,
    required this.totalAmount,
    required this.currency,
    required this.method,
    required this.startDate,
    required this.endDate,
    this.expenseDate,
    required this.usefulLifeMonths,
    required this.direction,
    required this.stepFrequency,
    this.bufferId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['asset_name'] = Variable<String>(assetName);
    map['asset_category'] = Variable<String>(assetCategory);
    map['total_amount'] = Variable<double>(totalAmount);
    map['currency'] = Variable<String>(currency);
    {
      map['method'] = Variable<String>(
        $DepreciationSchedulesTable.$convertermethod.toSql(method),
      );
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    if (!nullToAbsent || expenseDate != null) {
      map['expense_date'] = Variable<DateTime>(expenseDate);
    }
    map['useful_life_months'] = Variable<int>(usefulLifeMonths);
    {
      map['direction'] = Variable<String>(
        $DepreciationSchedulesTable.$converterdirection.toSql(direction),
      );
    }
    {
      map['step_frequency'] = Variable<String>(
        $DepreciationSchedulesTable.$converterstepFrequency.toSql(
          stepFrequency,
        ),
      );
    }
    if (!nullToAbsent || bufferId != null) {
      map['buffer_id'] = Variable<int>(bufferId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DepreciationSchedulesCompanion toCompanion(bool nullToAbsent) {
    return DepreciationSchedulesCompanion(
      id: Value(id),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      assetName: Value(assetName),
      assetCategory: Value(assetCategory),
      totalAmount: Value(totalAmount),
      currency: Value(currency),
      method: Value(method),
      startDate: Value(startDate),
      endDate: Value(endDate),
      expenseDate: expenseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expenseDate),
      usefulLifeMonths: Value(usefulLifeMonths),
      direction: Value(direction),
      stepFrequency: Value(stepFrequency),
      bufferId: bufferId == null && nullToAbsent
          ? const Value.absent()
          : Value(bufferId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DepreciationSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DepreciationSchedule(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      assetName: serializer.fromJson<String>(json['assetName']),
      assetCategory: serializer.fromJson<String>(json['assetCategory']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      currency: serializer.fromJson<String>(json['currency']),
      method: $DepreciationSchedulesTable.$convertermethod.fromJson(
        serializer.fromJson<String>(json['method']),
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      expenseDate: serializer.fromJson<DateTime?>(json['expenseDate']),
      usefulLifeMonths: serializer.fromJson<int>(json['usefulLifeMonths']),
      direction: $DepreciationSchedulesTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      stepFrequency: $DepreciationSchedulesTable.$converterstepFrequency
          .fromJson(serializer.fromJson<String>(json['stepFrequency'])),
      bufferId: serializer.fromJson<int?>(json['bufferId']),
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
      'transactionId': serializer.toJson<int?>(transactionId),
      'assetName': serializer.toJson<String>(assetName),
      'assetCategory': serializer.toJson<String>(assetCategory),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'currency': serializer.toJson<String>(currency),
      'method': serializer.toJson<String>(
        $DepreciationSchedulesTable.$convertermethod.toJson(method),
      ),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'expenseDate': serializer.toJson<DateTime?>(expenseDate),
      'usefulLifeMonths': serializer.toJson<int>(usefulLifeMonths),
      'direction': serializer.toJson<String>(
        $DepreciationSchedulesTable.$converterdirection.toJson(direction),
      ),
      'stepFrequency': serializer.toJson<String>(
        $DepreciationSchedulesTable.$converterstepFrequency.toJson(
          stepFrequency,
        ),
      ),
      'bufferId': serializer.toJson<int?>(bufferId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DepreciationSchedule copyWith({
    int? id,
    Value<int?> transactionId = const Value.absent(),
    String? assetName,
    String? assetCategory,
    double? totalAmount,
    String? currency,
    DepreciationMethod? method,
    DateTime? startDate,
    DateTime? endDate,
    Value<DateTime?> expenseDate = const Value.absent(),
    int? usefulLifeMonths,
    DepreciationDirection? direction,
    StepFrequency? stepFrequency,
    Value<int?> bufferId = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DepreciationSchedule(
    id: id ?? this.id,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    assetName: assetName ?? this.assetName,
    assetCategory: assetCategory ?? this.assetCategory,
    totalAmount: totalAmount ?? this.totalAmount,
    currency: currency ?? this.currency,
    method: method ?? this.method,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    expenseDate: expenseDate.present ? expenseDate.value : this.expenseDate,
    usefulLifeMonths: usefulLifeMonths ?? this.usefulLifeMonths,
    direction: direction ?? this.direction,
    stepFrequency: stepFrequency ?? this.stepFrequency,
    bufferId: bufferId.present ? bufferId.value : this.bufferId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DepreciationSchedule copyWithCompanion(DepreciationSchedulesCompanion data) {
    return DepreciationSchedule(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      assetName: data.assetName.present ? data.assetName.value : this.assetName,
      assetCategory: data.assetCategory.present
          ? data.assetCategory.value
          : this.assetCategory,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      currency: data.currency.present ? data.currency.value : this.currency,
      method: data.method.present ? data.method.value : this.method,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      expenseDate: data.expenseDate.present
          ? data.expenseDate.value
          : this.expenseDate,
      usefulLifeMonths: data.usefulLifeMonths.present
          ? data.usefulLifeMonths.value
          : this.usefulLifeMonths,
      direction: data.direction.present ? data.direction.value : this.direction,
      stepFrequency: data.stepFrequency.present
          ? data.stepFrequency.value
          : this.stepFrequency,
      bufferId: data.bufferId.present ? data.bufferId.value : this.bufferId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DepreciationSchedule(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('assetName: $assetName, ')
          ..write('assetCategory: $assetCategory, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currency: $currency, ')
          ..write('method: $method, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('usefulLifeMonths: $usefulLifeMonths, ')
          ..write('direction: $direction, ')
          ..write('stepFrequency: $stepFrequency, ')
          ..write('bufferId: $bufferId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    assetName,
    assetCategory,
    totalAmount,
    currency,
    method,
    startDate,
    endDate,
    expenseDate,
    usefulLifeMonths,
    direction,
    stepFrequency,
    bufferId,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DepreciationSchedule &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.assetName == this.assetName &&
          other.assetCategory == this.assetCategory &&
          other.totalAmount == this.totalAmount &&
          other.currency == this.currency &&
          other.method == this.method &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.expenseDate == this.expenseDate &&
          other.usefulLifeMonths == this.usefulLifeMonths &&
          other.direction == this.direction &&
          other.stepFrequency == this.stepFrequency &&
          other.bufferId == this.bufferId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DepreciationSchedulesCompanion
    extends UpdateCompanion<DepreciationSchedule> {
  final Value<int> id;
  final Value<int?> transactionId;
  final Value<String> assetName;
  final Value<String> assetCategory;
  final Value<double> totalAmount;
  final Value<String> currency;
  final Value<DepreciationMethod> method;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<DateTime?> expenseDate;
  final Value<int> usefulLifeMonths;
  final Value<DepreciationDirection> direction;
  final Value<StepFrequency> stepFrequency;
  final Value<int?> bufferId;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DepreciationSchedulesCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.assetName = const Value.absent(),
    this.assetCategory = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.currency = const Value.absent(),
    this.method = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.expenseDate = const Value.absent(),
    this.usefulLifeMonths = const Value.absent(),
    this.direction = const Value.absent(),
    this.stepFrequency = const Value.absent(),
    this.bufferId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DepreciationSchedulesCompanion.insert({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    required String assetName,
    required String assetCategory,
    required double totalAmount,
    this.currency = const Value.absent(),
    required DepreciationMethod method,
    required DateTime startDate,
    required DateTime endDate,
    this.expenseDate = const Value.absent(),
    required int usefulLifeMonths,
    required DepreciationDirection direction,
    this.stepFrequency = const Value.absent(),
    this.bufferId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : assetName = Value(assetName),
       assetCategory = Value(assetCategory),
       totalAmount = Value(totalAmount),
       method = Value(method),
       startDate = Value(startDate),
       endDate = Value(endDate),
       usefulLifeMonths = Value(usefulLifeMonths),
       direction = Value(direction);
  static Insertable<DepreciationSchedule> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<String>? assetName,
    Expression<String>? assetCategory,
    Expression<double>? totalAmount,
    Expression<String>? currency,
    Expression<String>? method,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? expenseDate,
    Expression<int>? usefulLifeMonths,
    Expression<String>? direction,
    Expression<String>? stepFrequency,
    Expression<int>? bufferId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (assetName != null) 'asset_name': assetName,
      if (assetCategory != null) 'asset_category': assetCategory,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (currency != null) 'currency': currency,
      if (method != null) 'method': method,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (expenseDate != null) 'expense_date': expenseDate,
      if (usefulLifeMonths != null) 'useful_life_months': usefulLifeMonths,
      if (direction != null) 'direction': direction,
      if (stepFrequency != null) 'step_frequency': stepFrequency,
      if (bufferId != null) 'buffer_id': bufferId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DepreciationSchedulesCompanion copyWith({
    Value<int>? id,
    Value<int?>? transactionId,
    Value<String>? assetName,
    Value<String>? assetCategory,
    Value<double>? totalAmount,
    Value<String>? currency,
    Value<DepreciationMethod>? method,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<DateTime?>? expenseDate,
    Value<int>? usefulLifeMonths,
    Value<DepreciationDirection>? direction,
    Value<StepFrequency>? stepFrequency,
    Value<int?>? bufferId,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DepreciationSchedulesCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      assetName: assetName ?? this.assetName,
      assetCategory: assetCategory ?? this.assetCategory,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      expenseDate: expenseDate ?? this.expenseDate,
      usefulLifeMonths: usefulLifeMonths ?? this.usefulLifeMonths,
      direction: direction ?? this.direction,
      stepFrequency: stepFrequency ?? this.stepFrequency,
      bufferId: bufferId ?? this.bufferId,
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
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (assetName.present) {
      map['asset_name'] = Variable<String>(assetName.value);
    }
    if (assetCategory.present) {
      map['asset_category'] = Variable<String>(assetCategory.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(
        $DepreciationSchedulesTable.$convertermethod.toSql(method.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (expenseDate.present) {
      map['expense_date'] = Variable<DateTime>(expenseDate.value);
    }
    if (usefulLifeMonths.present) {
      map['useful_life_months'] = Variable<int>(usefulLifeMonths.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $DepreciationSchedulesTable.$converterdirection.toSql(direction.value),
      );
    }
    if (stepFrequency.present) {
      map['step_frequency'] = Variable<String>(
        $DepreciationSchedulesTable.$converterstepFrequency.toSql(
          stepFrequency.value,
        ),
      );
    }
    if (bufferId.present) {
      map['buffer_id'] = Variable<int>(bufferId.value);
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
    return (StringBuffer('DepreciationSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('assetName: $assetName, ')
          ..write('assetCategory: $assetCategory, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('currency: $currency, ')
          ..write('method: $method, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('expenseDate: $expenseDate, ')
          ..write('usefulLifeMonths: $usefulLifeMonths, ')
          ..write('direction: $direction, ')
          ..write('stepFrequency: $stepFrequency, ')
          ..write('bufferId: $bufferId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DepreciationEntriesTable extends DepreciationEntries
    with TableInfo<$DepreciationEntriesTable, DepreciationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DepreciationEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<int> scheduleId = GeneratedColumn<int>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES depreciation_schedules (id)',
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
  static const VerificationMeta _cumulativeMeta = const VerificationMeta(
    'cumulative',
  );
  @override
  late final GeneratedColumn<double> cumulative = GeneratedColumn<double>(
    'cumulative',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingMeta = const VerificationMeta(
    'remaining',
  );
  @override
  late final GeneratedColumn<double> remaining = GeneratedColumn<double>(
    'remaining',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduleId,
    date,
    amount,
    cumulative,
    remaining,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'depreciation_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DepreciationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
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
    if (data.containsKey('cumulative')) {
      context.handle(
        _cumulativeMeta,
        cumulative.isAcceptableOrUnknown(data['cumulative']!, _cumulativeMeta),
      );
    } else if (isInserting) {
      context.missing(_cumulativeMeta);
    }
    if (data.containsKey('remaining')) {
      context.handle(
        _remainingMeta,
        remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta),
      );
    } else if (isInserting) {
      context.missing(_remainingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scheduleId, date},
  ];
  @override
  DepreciationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DepreciationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      cumulative: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cumulative'],
      )!,
      remaining: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining'],
      )!,
    );
  }

  @override
  $DepreciationEntriesTable createAlias(String alias) {
    return $DepreciationEntriesTable(attachedDatabase, alias);
  }
}

class DepreciationEntry extends DataClass
    implements Insertable<DepreciationEntry> {
  final int id;
  final int scheduleId;
  final DateTime date;
  final double amount;
  final double cumulative;
  final double remaining;
  const DepreciationEntry({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.amount,
    required this.cumulative,
    required this.remaining,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schedule_id'] = Variable<int>(scheduleId);
    map['date'] = Variable<DateTime>(date);
    map['amount'] = Variable<double>(amount);
    map['cumulative'] = Variable<double>(cumulative);
    map['remaining'] = Variable<double>(remaining);
    return map;
  }

  DepreciationEntriesCompanion toCompanion(bool nullToAbsent) {
    return DepreciationEntriesCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      date: Value(date),
      amount: Value(amount),
      cumulative: Value(cumulative),
      remaining: Value(remaining),
    );
  }

  factory DepreciationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DepreciationEntry(
      id: serializer.fromJson<int>(json['id']),
      scheduleId: serializer.fromJson<int>(json['scheduleId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amount: serializer.fromJson<double>(json['amount']),
      cumulative: serializer.fromJson<double>(json['cumulative']),
      remaining: serializer.fromJson<double>(json['remaining']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduleId': serializer.toJson<int>(scheduleId),
      'date': serializer.toJson<DateTime>(date),
      'amount': serializer.toJson<double>(amount),
      'cumulative': serializer.toJson<double>(cumulative),
      'remaining': serializer.toJson<double>(remaining),
    };
  }

  DepreciationEntry copyWith({
    int? id,
    int? scheduleId,
    DateTime? date,
    double? amount,
    double? cumulative,
    double? remaining,
  }) => DepreciationEntry(
    id: id ?? this.id,
    scheduleId: scheduleId ?? this.scheduleId,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    cumulative: cumulative ?? this.cumulative,
    remaining: remaining ?? this.remaining,
  );
  DepreciationEntry copyWithCompanion(DepreciationEntriesCompanion data) {
    return DepreciationEntry(
      id: data.id.present ? data.id.value : this.id,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      date: data.date.present ? data.date.value : this.date,
      amount: data.amount.present ? data.amount.value : this.amount,
      cumulative: data.cumulative.present
          ? data.cumulative.value
          : this.cumulative,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DepreciationEntry(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('cumulative: $cumulative, ')
          ..write('remaining: $remaining')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scheduleId, date, amount, cumulative, remaining);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DepreciationEntry &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.date == this.date &&
          other.amount == this.amount &&
          other.cumulative == this.cumulative &&
          other.remaining == this.remaining);
}

class DepreciationEntriesCompanion extends UpdateCompanion<DepreciationEntry> {
  final Value<int> id;
  final Value<int> scheduleId;
  final Value<DateTime> date;
  final Value<double> amount;
  final Value<double> cumulative;
  final Value<double> remaining;
  const DepreciationEntriesCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.date = const Value.absent(),
    this.amount = const Value.absent(),
    this.cumulative = const Value.absent(),
    this.remaining = const Value.absent(),
  });
  DepreciationEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int scheduleId,
    required DateTime date,
    required double amount,
    required double cumulative,
    required double remaining,
  }) : scheduleId = Value(scheduleId),
       date = Value(date),
       amount = Value(amount),
       cumulative = Value(cumulative),
       remaining = Value(remaining);
  static Insertable<DepreciationEntry> custom({
    Expression<int>? id,
    Expression<int>? scheduleId,
    Expression<DateTime>? date,
    Expression<double>? amount,
    Expression<double>? cumulative,
    Expression<double>? remaining,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (date != null) 'date': date,
      if (amount != null) 'amount': amount,
      if (cumulative != null) 'cumulative': cumulative,
      if (remaining != null) 'remaining': remaining,
    });
  }

  DepreciationEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? scheduleId,
    Value<DateTime>? date,
    Value<double>? amount,
    Value<double>? cumulative,
    Value<double>? remaining,
  }) {
    return DepreciationEntriesCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      cumulative: cumulative ?? this.cumulative,
      remaining: remaining ?? this.remaining,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<int>(scheduleId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (cumulative.present) {
      map['cumulative'] = Variable<double>(cumulative.value);
    }
    if (remaining.present) {
      map['remaining'] = Variable<double>(remaining.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DepreciationEntriesCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('date: $date, ')
          ..write('amount: $amount, ')
          ..write('cumulative: $cumulative, ')
          ..write('remaining: $remaining')
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
  static const VerificationMeta _linkedDepreciationIdMeta =
      const VerificationMeta('linkedDepreciationId');
  @override
  late final GeneratedColumn<int> linkedDepreciationId = GeneratedColumn<int>(
    'linked_depreciation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES depreciation_schedules (id)',
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
    linkedDepreciationId,
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
    if (data.containsKey('linked_depreciation_id')) {
      context.handle(
        _linkedDepreciationIdMeta,
        linkedDepreciationId.isAcceptableOrUnknown(
          data['linked_depreciation_id']!,
          _linkedDepreciationIdMeta,
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
      linkedDepreciationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_depreciation_id'],
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
  final int? linkedDepreciationId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Buffer({
    required this.id,
    required this.name,
    this.targetAmount,
    this.linkedDepreciationId,
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
    if (!nullToAbsent || linkedDepreciationId != null) {
      map['linked_depreciation_id'] = Variable<int>(linkedDepreciationId);
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
      linkedDepreciationId: linkedDepreciationId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedDepreciationId),
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
      linkedDepreciationId: serializer.fromJson<int?>(
        json['linkedDepreciationId'],
      ),
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
      'linkedDepreciationId': serializer.toJson<int?>(linkedDepreciationId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Buffer copyWith({
    int? id,
    String? name,
    Value<double?> targetAmount = const Value.absent(),
    Value<int?> linkedDepreciationId = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Buffer(
    id: id ?? this.id,
    name: name ?? this.name,
    targetAmount: targetAmount.present ? targetAmount.value : this.targetAmount,
    linkedDepreciationId: linkedDepreciationId.present
        ? linkedDepreciationId.value
        : this.linkedDepreciationId,
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
      linkedDepreciationId: data.linkedDepreciationId.present
          ? data.linkedDepreciationId.value
          : this.linkedDepreciationId,
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
          ..write('linkedDepreciationId: $linkedDepreciationId, ')
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
    linkedDepreciationId,
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
          other.linkedDepreciationId == this.linkedDepreciationId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BuffersCompanion extends UpdateCompanion<Buffer> {
  final Value<int> id;
  final Value<String> name;
  final Value<double?> targetAmount;
  final Value<int?> linkedDepreciationId;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BuffersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.linkedDepreciationId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BuffersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.targetAmount = const Value.absent(),
    this.linkedDepreciationId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Buffer> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? targetAmount,
    Expression<int>? linkedDepreciationId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (linkedDepreciationId != null)
        'linked_depreciation_id': linkedDepreciationId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BuffersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double?>? targetAmount,
    Value<int?>? linkedDepreciationId,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BuffersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      linkedDepreciationId: linkedDepreciationId ?? this.linkedDepreciationId,
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
    if (linkedDepreciationId.present) {
      map['linked_depreciation_id'] = Variable<int>(linkedDepreciationId.value);
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
          ..write('linkedDepreciationId: $linkedDepreciationId, ')
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

class $PerformanceSummariesTable extends PerformanceSummaries
    with TableInfo<$PerformanceSummariesTable, PerformanceSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PerformanceSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plAtPercentMeta = const VerificationMeta(
    'plAtPercent',
  );
  @override
  late final GeneratedColumn<double> plAtPercent = GeneratedColumn<double>(
    'pl_at_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plPtfPercentMeta = const VerificationMeta(
    'plPtfPercent',
  );
  @override
  late final GeneratedColumn<double> plPtfPercent = GeneratedColumn<double>(
    'pl_ptf_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eoyPlEurMeta = const VerificationMeta(
    'eoyPlEur',
  );
  @override
  late final GeneratedColumn<double> eoyPlEur = GeneratedColumn<double>(
    'eoy_pl_eur',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yoyDiffEurMeta = const VerificationMeta(
    'yoyDiffEur',
  );
  @override
  late final GeneratedColumn<double> yoyDiffEur = GeneratedColumn<double>(
    'yoy_diff_eur',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _absoluteReturnMeta = const VerificationMeta(
    'absoluteReturn',
  );
  @override
  late final GeneratedColumn<double> absoluteReturn = GeneratedColumn<double>(
    'absolute_return',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reverseCompoundMeta = const VerificationMeta(
    'reverseCompound',
  );
  @override
  late final GeneratedColumn<double> reverseCompound = GeneratedColumn<double>(
    'reverse_compound',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isYtdMeta = const VerificationMeta('isYtd');
  @override
  late final GeneratedColumn<bool> isYtd = GeneratedColumn<bool>(
    'is_ytd',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_ytd" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    year,
    month,
    plAtPercent,
    plPtfPercent,
    eoyPlEur,
    yoyDiffEur,
    absoluteReturn,
    reverseCompound,
    isYtd,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'performance_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PerformanceSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('pl_at_percent')) {
      context.handle(
        _plAtPercentMeta,
        plAtPercent.isAcceptableOrUnknown(
          data['pl_at_percent']!,
          _plAtPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plAtPercentMeta);
    }
    if (data.containsKey('pl_ptf_percent')) {
      context.handle(
        _plPtfPercentMeta,
        plPtfPercent.isAcceptableOrUnknown(
          data['pl_ptf_percent']!,
          _plPtfPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plPtfPercentMeta);
    }
    if (data.containsKey('eoy_pl_eur')) {
      context.handle(
        _eoyPlEurMeta,
        eoyPlEur.isAcceptableOrUnknown(data['eoy_pl_eur']!, _eoyPlEurMeta),
      );
    } else if (isInserting) {
      context.missing(_eoyPlEurMeta);
    }
    if (data.containsKey('yoy_diff_eur')) {
      context.handle(
        _yoyDiffEurMeta,
        yoyDiffEur.isAcceptableOrUnknown(
          data['yoy_diff_eur']!,
          _yoyDiffEurMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_yoyDiffEurMeta);
    }
    if (data.containsKey('absolute_return')) {
      context.handle(
        _absoluteReturnMeta,
        absoluteReturn.isAcceptableOrUnknown(
          data['absolute_return']!,
          _absoluteReturnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_absoluteReturnMeta);
    }
    if (data.containsKey('reverse_compound')) {
      context.handle(
        _reverseCompoundMeta,
        reverseCompound.isAcceptableOrUnknown(
          data['reverse_compound']!,
          _reverseCompoundMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reverseCompoundMeta);
    }
    if (data.containsKey('is_ytd')) {
      context.handle(
        _isYtdMeta,
        isYtd.isAcceptableOrUnknown(data['is_ytd']!, _isYtdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {year, month},
  ];
  @override
  PerformanceSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PerformanceSummary(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      ),
      plAtPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pl_at_percent'],
      )!,
      plPtfPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pl_ptf_percent'],
      )!,
      eoyPlEur: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}eoy_pl_eur'],
      )!,
      yoyDiffEur: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}yoy_diff_eur'],
      )!,
      absoluteReturn: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}absolute_return'],
      )!,
      reverseCompound: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reverse_compound'],
      )!,
      isYtd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_ytd'],
      )!,
    );
  }

  @override
  $PerformanceSummariesTable createAlias(String alias) {
    return $PerformanceSummariesTable(attachedDatabase, alias);
  }
}

class PerformanceSummary extends DataClass
    implements Insertable<PerformanceSummary> {
  final int year;
  final int? month;
  final double plAtPercent;
  final double plPtfPercent;
  final double eoyPlEur;
  final double yoyDiffEur;
  final double absoluteReturn;
  final double reverseCompound;
  final bool isYtd;
  const PerformanceSummary({
    required this.year,
    this.month,
    required this.plAtPercent,
    required this.plPtfPercent,
    required this.eoyPlEur,
    required this.yoyDiffEur,
    required this.absoluteReturn,
    required this.reverseCompound,
    required this.isYtd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<int>(month);
    }
    map['pl_at_percent'] = Variable<double>(plAtPercent);
    map['pl_ptf_percent'] = Variable<double>(plPtfPercent);
    map['eoy_pl_eur'] = Variable<double>(eoyPlEur);
    map['yoy_diff_eur'] = Variable<double>(yoyDiffEur);
    map['absolute_return'] = Variable<double>(absoluteReturn);
    map['reverse_compound'] = Variable<double>(reverseCompound);
    map['is_ytd'] = Variable<bool>(isYtd);
    return map;
  }

  PerformanceSummariesCompanion toCompanion(bool nullToAbsent) {
    return PerformanceSummariesCompanion(
      year: Value(year),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      plAtPercent: Value(plAtPercent),
      plPtfPercent: Value(plPtfPercent),
      eoyPlEur: Value(eoyPlEur),
      yoyDiffEur: Value(yoyDiffEur),
      absoluteReturn: Value(absoluteReturn),
      reverseCompound: Value(reverseCompound),
      isYtd: Value(isYtd),
    );
  }

  factory PerformanceSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PerformanceSummary(
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int?>(json['month']),
      plAtPercent: serializer.fromJson<double>(json['plAtPercent']),
      plPtfPercent: serializer.fromJson<double>(json['plPtfPercent']),
      eoyPlEur: serializer.fromJson<double>(json['eoyPlEur']),
      yoyDiffEur: serializer.fromJson<double>(json['yoyDiffEur']),
      absoluteReturn: serializer.fromJson<double>(json['absoluteReturn']),
      reverseCompound: serializer.fromJson<double>(json['reverseCompound']),
      isYtd: serializer.fromJson<bool>(json['isYtd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int?>(month),
      'plAtPercent': serializer.toJson<double>(plAtPercent),
      'plPtfPercent': serializer.toJson<double>(plPtfPercent),
      'eoyPlEur': serializer.toJson<double>(eoyPlEur),
      'yoyDiffEur': serializer.toJson<double>(yoyDiffEur),
      'absoluteReturn': serializer.toJson<double>(absoluteReturn),
      'reverseCompound': serializer.toJson<double>(reverseCompound),
      'isYtd': serializer.toJson<bool>(isYtd),
    };
  }

  PerformanceSummary copyWith({
    int? year,
    Value<int?> month = const Value.absent(),
    double? plAtPercent,
    double? plPtfPercent,
    double? eoyPlEur,
    double? yoyDiffEur,
    double? absoluteReturn,
    double? reverseCompound,
    bool? isYtd,
  }) => PerformanceSummary(
    year: year ?? this.year,
    month: month.present ? month.value : this.month,
    plAtPercent: plAtPercent ?? this.plAtPercent,
    plPtfPercent: plPtfPercent ?? this.plPtfPercent,
    eoyPlEur: eoyPlEur ?? this.eoyPlEur,
    yoyDiffEur: yoyDiffEur ?? this.yoyDiffEur,
    absoluteReturn: absoluteReturn ?? this.absoluteReturn,
    reverseCompound: reverseCompound ?? this.reverseCompound,
    isYtd: isYtd ?? this.isYtd,
  );
  PerformanceSummary copyWithCompanion(PerformanceSummariesCompanion data) {
    return PerformanceSummary(
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      plAtPercent: data.plAtPercent.present
          ? data.plAtPercent.value
          : this.plAtPercent,
      plPtfPercent: data.plPtfPercent.present
          ? data.plPtfPercent.value
          : this.plPtfPercent,
      eoyPlEur: data.eoyPlEur.present ? data.eoyPlEur.value : this.eoyPlEur,
      yoyDiffEur: data.yoyDiffEur.present
          ? data.yoyDiffEur.value
          : this.yoyDiffEur,
      absoluteReturn: data.absoluteReturn.present
          ? data.absoluteReturn.value
          : this.absoluteReturn,
      reverseCompound: data.reverseCompound.present
          ? data.reverseCompound.value
          : this.reverseCompound,
      isYtd: data.isYtd.present ? data.isYtd.value : this.isYtd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PerformanceSummary(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('plAtPercent: $plAtPercent, ')
          ..write('plPtfPercent: $plPtfPercent, ')
          ..write('eoyPlEur: $eoyPlEur, ')
          ..write('yoyDiffEur: $yoyDiffEur, ')
          ..write('absoluteReturn: $absoluteReturn, ')
          ..write('reverseCompound: $reverseCompound, ')
          ..write('isYtd: $isYtd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    year,
    month,
    plAtPercent,
    plPtfPercent,
    eoyPlEur,
    yoyDiffEur,
    absoluteReturn,
    reverseCompound,
    isYtd,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PerformanceSummary &&
          other.year == this.year &&
          other.month == this.month &&
          other.plAtPercent == this.plAtPercent &&
          other.plPtfPercent == this.plPtfPercent &&
          other.eoyPlEur == this.eoyPlEur &&
          other.yoyDiffEur == this.yoyDiffEur &&
          other.absoluteReturn == this.absoluteReturn &&
          other.reverseCompound == this.reverseCompound &&
          other.isYtd == this.isYtd);
}

class PerformanceSummariesCompanion
    extends UpdateCompanion<PerformanceSummary> {
  final Value<int> year;
  final Value<int?> month;
  final Value<double> plAtPercent;
  final Value<double> plPtfPercent;
  final Value<double> eoyPlEur;
  final Value<double> yoyDiffEur;
  final Value<double> absoluteReturn;
  final Value<double> reverseCompound;
  final Value<bool> isYtd;
  final Value<int> rowid;
  const PerformanceSummariesCompanion({
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.plAtPercent = const Value.absent(),
    this.plPtfPercent = const Value.absent(),
    this.eoyPlEur = const Value.absent(),
    this.yoyDiffEur = const Value.absent(),
    this.absoluteReturn = const Value.absent(),
    this.reverseCompound = const Value.absent(),
    this.isYtd = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PerformanceSummariesCompanion.insert({
    required int year,
    this.month = const Value.absent(),
    required double plAtPercent,
    required double plPtfPercent,
    required double eoyPlEur,
    required double yoyDiffEur,
    required double absoluteReturn,
    required double reverseCompound,
    this.isYtd = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : year = Value(year),
       plAtPercent = Value(plAtPercent),
       plPtfPercent = Value(plPtfPercent),
       eoyPlEur = Value(eoyPlEur),
       yoyDiffEur = Value(yoyDiffEur),
       absoluteReturn = Value(absoluteReturn),
       reverseCompound = Value(reverseCompound);
  static Insertable<PerformanceSummary> custom({
    Expression<int>? year,
    Expression<int>? month,
    Expression<double>? plAtPercent,
    Expression<double>? plPtfPercent,
    Expression<double>? eoyPlEur,
    Expression<double>? yoyDiffEur,
    Expression<double>? absoluteReturn,
    Expression<double>? reverseCompound,
    Expression<bool>? isYtd,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (plAtPercent != null) 'pl_at_percent': plAtPercent,
      if (plPtfPercent != null) 'pl_ptf_percent': plPtfPercent,
      if (eoyPlEur != null) 'eoy_pl_eur': eoyPlEur,
      if (yoyDiffEur != null) 'yoy_diff_eur': yoyDiffEur,
      if (absoluteReturn != null) 'absolute_return': absoluteReturn,
      if (reverseCompound != null) 'reverse_compound': reverseCompound,
      if (isYtd != null) 'is_ytd': isYtd,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PerformanceSummariesCompanion copyWith({
    Value<int>? year,
    Value<int?>? month,
    Value<double>? plAtPercent,
    Value<double>? plPtfPercent,
    Value<double>? eoyPlEur,
    Value<double>? yoyDiffEur,
    Value<double>? absoluteReturn,
    Value<double>? reverseCompound,
    Value<bool>? isYtd,
    Value<int>? rowid,
  }) {
    return PerformanceSummariesCompanion(
      year: year ?? this.year,
      month: month ?? this.month,
      plAtPercent: plAtPercent ?? this.plAtPercent,
      plPtfPercent: plPtfPercent ?? this.plPtfPercent,
      eoyPlEur: eoyPlEur ?? this.eoyPlEur,
      yoyDiffEur: yoyDiffEur ?? this.yoyDiffEur,
      absoluteReturn: absoluteReturn ?? this.absoluteReturn,
      reverseCompound: reverseCompound ?? this.reverseCompound,
      isYtd: isYtd ?? this.isYtd,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (plAtPercent.present) {
      map['pl_at_percent'] = Variable<double>(plAtPercent.value);
    }
    if (plPtfPercent.present) {
      map['pl_ptf_percent'] = Variable<double>(plPtfPercent.value);
    }
    if (eoyPlEur.present) {
      map['eoy_pl_eur'] = Variable<double>(eoyPlEur.value);
    }
    if (yoyDiffEur.present) {
      map['yoy_diff_eur'] = Variable<double>(yoyDiffEur.value);
    }
    if (absoluteReturn.present) {
      map['absolute_return'] = Variable<double>(absoluteReturn.value);
    }
    if (reverseCompound.present) {
      map['reverse_compound'] = Variable<double>(reverseCompound.value);
    }
    if (isYtd.present) {
      map['is_ytd'] = Variable<bool>(isYtd.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PerformanceSummariesCompanion(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('plAtPercent: $plAtPercent, ')
          ..write('plPtfPercent: $plPtfPercent, ')
          ..write('eoyPlEur: $eoyPlEur, ')
          ..write('yoyDiffEur: $yoyDiffEur, ')
          ..write('absoluteReturn: $absoluteReturn, ')
          ..write('reverseCompound: $reverseCompound, ')
          ..write('isYtd: $isYtd, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarDaysTable extends CalendarDays
    with TableInfo<$CalendarDaysTable, CalendarDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBankHolidayMeta = const VerificationMeta(
    'isBankHoliday',
  );
  @override
  late final GeneratedColumn<bool> isBankHoliday = GeneratedColumn<bool>(
    'is_bank_holiday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bank_holiday" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCompanyHolidayMeta = const VerificationMeta(
    'isCompanyHoliday',
  );
  @override
  late final GeneratedColumn<bool> isCompanyHoliday = GeneratedColumn<bool>(
    'is_company_holiday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_company_holiday" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _holidayNameMeta = const VerificationMeta(
    'holidayName',
  );
  @override
  late final GeneratedColumn<String> holidayName = GeneratedColumn<String>(
    'holiday_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isWorkingDayMeta = const VerificationMeta(
    'isWorkingDay',
  );
  @override
  late final GeneratedColumn<bool> isWorkingDay = GeneratedColumn<bool>(
    'is_working_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_working_day" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _monthWorkingDaysMeta = const VerificationMeta(
    'monthWorkingDays',
  );
  @override
  late final GeneratedColumn<int> monthWorkingDays = GeneratedColumn<int>(
    'month_working_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    isBankHoliday,
    isCompanyHoliday,
    holidayName,
    isWorkingDay,
    monthWorkingDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('is_bank_holiday')) {
      context.handle(
        _isBankHolidayMeta,
        isBankHoliday.isAcceptableOrUnknown(
          data['is_bank_holiday']!,
          _isBankHolidayMeta,
        ),
      );
    }
    if (data.containsKey('is_company_holiday')) {
      context.handle(
        _isCompanyHolidayMeta,
        isCompanyHoliday.isAcceptableOrUnknown(
          data['is_company_holiday']!,
          _isCompanyHolidayMeta,
        ),
      );
    }
    if (data.containsKey('holiday_name')) {
      context.handle(
        _holidayNameMeta,
        holidayName.isAcceptableOrUnknown(
          data['holiday_name']!,
          _holidayNameMeta,
        ),
      );
    }
    if (data.containsKey('is_working_day')) {
      context.handle(
        _isWorkingDayMeta,
        isWorkingDay.isAcceptableOrUnknown(
          data['is_working_day']!,
          _isWorkingDayMeta,
        ),
      );
    }
    if (data.containsKey('month_working_days')) {
      context.handle(
        _monthWorkingDaysMeta,
        monthWorkingDays.isAcceptableOrUnknown(
          data['month_working_days']!,
          _monthWorkingDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  CalendarDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarDay(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      isBankHoliday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bank_holiday'],
      )!,
      isCompanyHoliday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_company_holiday'],
      )!,
      holidayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holiday_name'],
      ),
      isWorkingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_working_day'],
      )!,
      monthWorkingDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_working_days'],
      )!,
    );
  }

  @override
  $CalendarDaysTable createAlias(String alias) {
    return $CalendarDaysTable(attachedDatabase, alias);
  }
}

class CalendarDay extends DataClass implements Insertable<CalendarDay> {
  final DateTime date;
  final bool isBankHoliday;
  final bool isCompanyHoliday;
  final String? holidayName;
  final bool isWorkingDay;
  final int monthWorkingDays;
  const CalendarDay({
    required this.date,
    required this.isBankHoliday,
    required this.isCompanyHoliday,
    this.holidayName,
    required this.isWorkingDay,
    required this.monthWorkingDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['is_bank_holiday'] = Variable<bool>(isBankHoliday);
    map['is_company_holiday'] = Variable<bool>(isCompanyHoliday);
    if (!nullToAbsent || holidayName != null) {
      map['holiday_name'] = Variable<String>(holidayName);
    }
    map['is_working_day'] = Variable<bool>(isWorkingDay);
    map['month_working_days'] = Variable<int>(monthWorkingDays);
    return map;
  }

  CalendarDaysCompanion toCompanion(bool nullToAbsent) {
    return CalendarDaysCompanion(
      date: Value(date),
      isBankHoliday: Value(isBankHoliday),
      isCompanyHoliday: Value(isCompanyHoliday),
      holidayName: holidayName == null && nullToAbsent
          ? const Value.absent()
          : Value(holidayName),
      isWorkingDay: Value(isWorkingDay),
      monthWorkingDays: Value(monthWorkingDays),
    );
  }

  factory CalendarDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarDay(
      date: serializer.fromJson<DateTime>(json['date']),
      isBankHoliday: serializer.fromJson<bool>(json['isBankHoliday']),
      isCompanyHoliday: serializer.fromJson<bool>(json['isCompanyHoliday']),
      holidayName: serializer.fromJson<String?>(json['holidayName']),
      isWorkingDay: serializer.fromJson<bool>(json['isWorkingDay']),
      monthWorkingDays: serializer.fromJson<int>(json['monthWorkingDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'isBankHoliday': serializer.toJson<bool>(isBankHoliday),
      'isCompanyHoliday': serializer.toJson<bool>(isCompanyHoliday),
      'holidayName': serializer.toJson<String?>(holidayName),
      'isWorkingDay': serializer.toJson<bool>(isWorkingDay),
      'monthWorkingDays': serializer.toJson<int>(monthWorkingDays),
    };
  }

  CalendarDay copyWith({
    DateTime? date,
    bool? isBankHoliday,
    bool? isCompanyHoliday,
    Value<String?> holidayName = const Value.absent(),
    bool? isWorkingDay,
    int? monthWorkingDays,
  }) => CalendarDay(
    date: date ?? this.date,
    isBankHoliday: isBankHoliday ?? this.isBankHoliday,
    isCompanyHoliday: isCompanyHoliday ?? this.isCompanyHoliday,
    holidayName: holidayName.present ? holidayName.value : this.holidayName,
    isWorkingDay: isWorkingDay ?? this.isWorkingDay,
    monthWorkingDays: monthWorkingDays ?? this.monthWorkingDays,
  );
  CalendarDay copyWithCompanion(CalendarDaysCompanion data) {
    return CalendarDay(
      date: data.date.present ? data.date.value : this.date,
      isBankHoliday: data.isBankHoliday.present
          ? data.isBankHoliday.value
          : this.isBankHoliday,
      isCompanyHoliday: data.isCompanyHoliday.present
          ? data.isCompanyHoliday.value
          : this.isCompanyHoliday,
      holidayName: data.holidayName.present
          ? data.holidayName.value
          : this.holidayName,
      isWorkingDay: data.isWorkingDay.present
          ? data.isWorkingDay.value
          : this.isWorkingDay,
      monthWorkingDays: data.monthWorkingDays.present
          ? data.monthWorkingDays.value
          : this.monthWorkingDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarDay(')
          ..write('date: $date, ')
          ..write('isBankHoliday: $isBankHoliday, ')
          ..write('isCompanyHoliday: $isCompanyHoliday, ')
          ..write('holidayName: $holidayName, ')
          ..write('isWorkingDay: $isWorkingDay, ')
          ..write('monthWorkingDays: $monthWorkingDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    isBankHoliday,
    isCompanyHoliday,
    holidayName,
    isWorkingDay,
    monthWorkingDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarDay &&
          other.date == this.date &&
          other.isBankHoliday == this.isBankHoliday &&
          other.isCompanyHoliday == this.isCompanyHoliday &&
          other.holidayName == this.holidayName &&
          other.isWorkingDay == this.isWorkingDay &&
          other.monthWorkingDays == this.monthWorkingDays);
}

class CalendarDaysCompanion extends UpdateCompanion<CalendarDay> {
  final Value<DateTime> date;
  final Value<bool> isBankHoliday;
  final Value<bool> isCompanyHoliday;
  final Value<String?> holidayName;
  final Value<bool> isWorkingDay;
  final Value<int> monthWorkingDays;
  final Value<int> rowid;
  const CalendarDaysCompanion({
    this.date = const Value.absent(),
    this.isBankHoliday = const Value.absent(),
    this.isCompanyHoliday = const Value.absent(),
    this.holidayName = const Value.absent(),
    this.isWorkingDay = const Value.absent(),
    this.monthWorkingDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarDaysCompanion.insert({
    required DateTime date,
    this.isBankHoliday = const Value.absent(),
    this.isCompanyHoliday = const Value.absent(),
    this.holidayName = const Value.absent(),
    this.isWorkingDay = const Value.absent(),
    this.monthWorkingDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<CalendarDay> custom({
    Expression<DateTime>? date,
    Expression<bool>? isBankHoliday,
    Expression<bool>? isCompanyHoliday,
    Expression<String>? holidayName,
    Expression<bool>? isWorkingDay,
    Expression<int>? monthWorkingDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (isBankHoliday != null) 'is_bank_holiday': isBankHoliday,
      if (isCompanyHoliday != null) 'is_company_holiday': isCompanyHoliday,
      if (holidayName != null) 'holiday_name': holidayName,
      if (isWorkingDay != null) 'is_working_day': isWorkingDay,
      if (monthWorkingDays != null) 'month_working_days': monthWorkingDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarDaysCompanion copyWith({
    Value<DateTime>? date,
    Value<bool>? isBankHoliday,
    Value<bool>? isCompanyHoliday,
    Value<String?>? holidayName,
    Value<bool>? isWorkingDay,
    Value<int>? monthWorkingDays,
    Value<int>? rowid,
  }) {
    return CalendarDaysCompanion(
      date: date ?? this.date,
      isBankHoliday: isBankHoliday ?? this.isBankHoliday,
      isCompanyHoliday: isCompanyHoliday ?? this.isCompanyHoliday,
      holidayName: holidayName ?? this.holidayName,
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
      monthWorkingDays: monthWorkingDays ?? this.monthWorkingDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (isBankHoliday.present) {
      map['is_bank_holiday'] = Variable<bool>(isBankHoliday.value);
    }
    if (isCompanyHoliday.present) {
      map['is_company_holiday'] = Variable<bool>(isCompanyHoliday.value);
    }
    if (holidayName.present) {
      map['holiday_name'] = Variable<String>(holidayName.value);
    }
    if (isWorkingDay.present) {
      map['is_working_day'] = Variable<bool>(isWorkingDay.value);
    }
    if (monthWorkingDays.present) {
      map['month_working_days'] = Variable<int>(monthWorkingDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarDaysCompanion(')
          ..write('date: $date, ')
          ..write('isBankHoliday: $isBankHoliday, ')
          ..write('isCompanyHoliday: $isCompanyHoliday, ')
          ..write('holidayName: $holidayName, ')
          ..write('isWorkingDay: $isWorkingDay, ')
          ..write('monthWorkingDays: $monthWorkingDays, ')
          ..write('rowid: $rowid')
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
  final DateTime updatedAt;
  const ImportConfig({
    required this.id,
    required this.accountId,
    required this.skipRows,
    required this.mappingsJson,
    required this.formulaJson,
    required this.hashColumnsJson,
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
    DateTime? updatedAt,
  }) => ImportConfig(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    skipRows: skipRows ?? this.skipRows,
    mappingsJson: mappingsJson ?? this.mappingsJson,
    formulaJson: formulaJson ?? this.formulaJson,
    hashColumnsJson: hashColumnsJson ?? this.hashColumnsJson,
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
          other.updatedAt == this.updatedAt);
}

class ImportConfigsCompanion extends UpdateCompanion<ImportConfig> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> skipRows;
  final Value<String> mappingsJson;
  final Value<String> formulaJson;
  final Value<String> hashColumnsJson;
  final Value<DateTime> updatedAt;
  const ImportConfigsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.skipRows = const Value.absent(),
    this.mappingsJson = const Value.absent(),
    this.formulaJson = const Value.absent(),
    this.hashColumnsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ImportConfigsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    this.skipRows = const Value.absent(),
    this.mappingsJson = const Value.absent(),
    this.formulaJson = const Value.absent(),
    this.hashColumnsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<ImportConfig> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? skipRows,
    Expression<String>? mappingsJson,
    Expression<String>? formulaJson,
    Expression<String>? hashColumnsJson,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (skipRows != null) 'skip_rows': skipRows,
      if (mappingsJson != null) 'mappings_json': mappingsJson,
      if (formulaJson != null) 'formula_json': formulaJson,
      if (hashColumnsJson != null) 'hash_columns_json': hashColumnsJson,
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
    Value<DateTime>? updatedAt,
  }) {
    return ImportConfigsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      skipRows: skipRows ?? this.skipRows,
      mappingsJson: mappingsJson ?? this.mappingsJson,
      formulaJson: formulaJson ?? this.formulaJson,
      hashColumnsJson: hashColumnsJson ?? this.hashColumnsJson,
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
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $AutoCategorizationRulesTable autoCategorizationRules =
      $AutoCategorizationRulesTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $AssetEventsTable assetEvents = $AssetEventsTable(this);
  late final $AssetSnapshotsTable assetSnapshots = $AssetSnapshotsTable(this);
  late final $PortfoliosTable portfolios = $PortfoliosTable(this);
  late final $PortfolioAssetsTable portfolioAssets = $PortfolioAssetsTable(
    this,
  );
  late final $PortfolioModelsTable portfolioModels = $PortfolioModelsTable(
    this,
  );
  late final $DailySnapshotsTable dailySnapshots = $DailySnapshotsTable(this);
  late final $DepreciationSchedulesTable depreciationSchedules =
      $DepreciationSchedulesTable(this);
  late final $DepreciationEntriesTable depreciationEntries =
      $DepreciationEntriesTable(this);
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
  late final $PerformanceSummariesTable performanceSummaries =
      $PerformanceSummariesTable(this);
  late final $CalendarDaysTable calendarDays = $CalendarDaysTable(this);
  late final $AppConfigsTable appConfigs = $AppConfigsTable(this);
  late final $ImportConfigsTable importConfigs = $ImportConfigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    transactions,
    autoCategorizationRules,
    assets,
    assetEvents,
    assetSnapshots,
    portfolios,
    portfolioAssets,
    portfolioModels,
    dailySnapshots,
    depreciationSchedules,
    depreciationEntries,
    buffers,
    bufferTransactions,
    marketPrices,
    exchangeRates,
    registeredEvents,
    healthReimbursements,
    performanceSummaries,
    calendarDays,
    appConfigs,
    importConfigs,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      required String name,
      Value<AccountType> type,
      Value<String> currency,
      Value<String> institution,
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
      Value<bool> isActive,
      Value<bool> includeInNetWorth,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

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
              ({transactionsRefs = false, importConfigsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (importConfigsRefs) db.importConfigs,
                  ],
                  addJoins: null,
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
      PrefetchHooks Function({bool transactionsRefs, bool importConfigsRefs})
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
      Value<int?> depreciationId,
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
      Value<int?> depreciationId,
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

  static MultiTypedResultKey<
    $DepreciationSchedulesTable,
    List<DepreciationSchedule>
  >
  _depreciationSchedulesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.depreciationSchedules,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.depreciationSchedules.transactionId,
        ),
      );

  $$DepreciationSchedulesTableProcessedTableManager
  get depreciationSchedulesRefs {
    final manager = $$DepreciationSchedulesTableTableManager(
      $_db,
      $_db.depreciationSchedules,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _depreciationSchedulesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<int> get depreciationId => $composableBuilder(
    column: $table.depreciationId,
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

  Expression<bool> depreciationSchedulesRefs(
    Expression<bool> Function($$DepreciationSchedulesTableFilterComposer f) f,
  ) {
    final $$DepreciationSchedulesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableFilterComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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

  ColumnOrderings<int> get depreciationId => $composableBuilder(
    column: $table.depreciationId,
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

  GeneratedColumn<int> get depreciationId => $composableBuilder(
    column: $table.depreciationId,
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

  Expression<T> depreciationSchedulesRefs<T extends Object>(
    Expression<T> Function($$DepreciationSchedulesTableAnnotationComposer a) f,
  ) {
    final $$DepreciationSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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
            bool depreciationSchedulesRefs,
            bool bufferTransactionsRefs,
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
                Value<int?> depreciationId = const Value.absent(),
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
                depreciationId: depreciationId,
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
                Value<int?> depreciationId = const Value.absent(),
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
                depreciationId: depreciationId,
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
                depreciationSchedulesRefs = false,
                bufferTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (depreciationSchedulesRefs) db.depreciationSchedules,
                    if (bufferTransactionsRefs) db.bufferTransactions,
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
                      if (depreciationSchedulesRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          DepreciationSchedule
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._depreciationSchedulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).depreciationSchedulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
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
        bool depreciationSchedulesRefs,
        bool bufferTransactionsRefs,
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

  static MultiTypedResultKey<$PortfolioAssetsTable, List<PortfolioAsset>>
  _portfolioAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.portfolioAssets,
    aliasName: $_aliasNameGenerator(db.assets.id, db.portfolioAssets.assetId),
  );

  $$PortfolioAssetsTableProcessedTableManager get portfolioAssetsRefs {
    final manager = $$PortfolioAssetsTableTableManager(
      $_db,
      $_db.portfolioAssets,
    ).filter((f) => f.assetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _portfolioAssetsRefsTable($_db),
    );
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

  Expression<bool> portfolioAssetsRefs(
    Expression<bool> Function($$PortfolioAssetsTableFilterComposer f) f,
  ) {
    final $$PortfolioAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portfolioAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioAssetsTableFilterComposer(
            $db: $db,
            $table: $db.portfolioAssets,
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

  Expression<T> portfolioAssetsRefs<T extends Object>(
    Expression<T> Function($$PortfolioAssetsTableAnnotationComposer a) f,
  ) {
    final $$PortfolioAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portfolioAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.portfolioAssets,
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
            bool assetEventsRefs,
            bool assetSnapshotsRefs,
            bool portfolioAssetsRefs,
            bool marketPricesRefs,
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
                assetEventsRefs = false,
                assetSnapshotsRefs = false,
                portfolioAssetsRefs = false,
                marketPricesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (assetEventsRefs) db.assetEvents,
                    if (assetSnapshotsRefs) db.assetSnapshots,
                    if (portfolioAssetsRefs) db.portfolioAssets,
                    if (marketPricesRefs) db.marketPrices,
                  ],
                  addJoins: null,
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
                      if (portfolioAssetsRefs)
                        await $_getPrefetchedData<
                          Asset,
                          $AssetsTable,
                          PortfolioAsset
                        >(
                          currentTable: table,
                          referencedTable: $$AssetsTableReferences
                              ._portfolioAssetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).portfolioAssetsRefs,
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
        bool assetEventsRefs,
        bool assetSnapshotsRefs,
        bool portfolioAssetsRefs,
        bool marketPricesRefs,
      })
    >;
typedef $$AssetEventsTableCreateCompanionBuilder =
    AssetEventsCompanion Function({
      Value<int> id,
      required int assetId,
      required DateTime date,
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
typedef $$PortfoliosTableCreateCompanionBuilder =
    PortfoliosCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      Value<bool> isActive,
      Value<int?> modelId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$PortfoliosTableUpdateCompanionBuilder =
    PortfoliosCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<bool> isActive,
      Value<int?> modelId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$PortfoliosTableReferences
    extends BaseReferences<_$AppDatabase, $PortfoliosTable, Portfolio> {
  $$PortfoliosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PortfolioAssetsTable, List<PortfolioAsset>>
  _portfolioAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.portfolioAssets,
    aliasName: $_aliasNameGenerator(
      db.portfolios.id,
      db.portfolioAssets.portfolioId,
    ),
  );

  $$PortfolioAssetsTableProcessedTableManager get portfolioAssetsRefs {
    final manager = $$PortfolioAssetsTableTableManager(
      $_db,
      $_db.portfolioAssets,
    ).filter((f) => f.portfolioId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _portfolioAssetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PortfoliosTableFilterComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modelId => $composableBuilder(
    column: $table.modelId,
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

  Expression<bool> portfolioAssetsRefs(
    Expression<bool> Function($$PortfolioAssetsTableFilterComposer f) f,
  ) {
    final $$PortfolioAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portfolioAssets,
      getReferencedColumn: (t) => t.portfolioId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioAssetsTableFilterComposer(
            $db: $db,
            $table: $db.portfolioAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PortfoliosTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modelId => $composableBuilder(
    column: $table.modelId,
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

class $$PortfoliosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfoliosTable> {
  $$PortfoliosTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> portfolioAssetsRefs<T extends Object>(
    Expression<T> Function($$PortfolioAssetsTableAnnotationComposer a) f,
  ) {
    final $$PortfolioAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.portfolioAssets,
      getReferencedColumn: (t) => t.portfolioId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfolioAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.portfolioAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PortfoliosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfoliosTable,
          Portfolio,
          $$PortfoliosTableFilterComposer,
          $$PortfoliosTableOrderingComposer,
          $$PortfoliosTableAnnotationComposer,
          $$PortfoliosTableCreateCompanionBuilder,
          $$PortfoliosTableUpdateCompanionBuilder,
          (Portfolio, $$PortfoliosTableReferences),
          Portfolio,
          PrefetchHooks Function({bool portfolioAssetsRefs})
        > {
  $$PortfoliosTableTableManager(_$AppDatabase db, $PortfoliosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfoliosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfoliosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfoliosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> modelId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PortfoliosCompanion(
                id: id,
                name: name,
                description: description,
                isActive: isActive,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> modelId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PortfoliosCompanion.insert(
                id: id,
                name: name,
                description: description,
                isActive: isActive,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortfoliosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({portfolioAssetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (portfolioAssetsRefs) db.portfolioAssets,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (portfolioAssetsRefs)
                    await $_getPrefetchedData<
                      Portfolio,
                      $PortfoliosTable,
                      PortfolioAsset
                    >(
                      currentTable: table,
                      referencedTable: $$PortfoliosTableReferences
                          ._portfolioAssetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PortfoliosTableReferences(
                            db,
                            table,
                            p0,
                          ).portfolioAssetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.portfolioId == item.id,
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

typedef $$PortfoliosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfoliosTable,
      Portfolio,
      $$PortfoliosTableFilterComposer,
      $$PortfoliosTableOrderingComposer,
      $$PortfoliosTableAnnotationComposer,
      $$PortfoliosTableCreateCompanionBuilder,
      $$PortfoliosTableUpdateCompanionBuilder,
      (Portfolio, $$PortfoliosTableReferences),
      Portfolio,
      PrefetchHooks Function({bool portfolioAssetsRefs})
    >;
typedef $$PortfolioAssetsTableCreateCompanionBuilder =
    PortfolioAssetsCompanion Function({
      required int portfolioId,
      required int assetId,
      Value<int> rowid,
    });
typedef $$PortfolioAssetsTableUpdateCompanionBuilder =
    PortfolioAssetsCompanion Function({
      Value<int> portfolioId,
      Value<int> assetId,
      Value<int> rowid,
    });

final class $$PortfolioAssetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PortfolioAssetsTable, PortfolioAsset> {
  $$PortfolioAssetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PortfoliosTable _portfolioIdTable(_$AppDatabase db) =>
      db.portfolios.createAlias(
        $_aliasNameGenerator(db.portfolioAssets.portfolioId, db.portfolios.id),
      );

  $$PortfoliosTableProcessedTableManager get portfolioId {
    final $_column = $_itemColumn<int>('portfolio_id')!;

    final manager = $$PortfoliosTableTableManager(
      $_db,
      $_db.portfolios,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_portfolioIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AssetsTable _assetIdTable(_$AppDatabase db) => db.assets.createAlias(
    $_aliasNameGenerator(db.portfolioAssets.assetId, db.assets.id),
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

class $$PortfolioAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PortfoliosTableFilterComposer get portfolioId {
    final $$PortfoliosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.portfolioId,
      referencedTable: $db.portfolios,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfoliosTableFilterComposer(
            $db: $db,
            $table: $db.portfolios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$PortfolioAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PortfoliosTableOrderingComposer get portfolioId {
    final $$PortfoliosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.portfolioId,
      referencedTable: $db.portfolios,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfoliosTableOrderingComposer(
            $db: $db,
            $table: $db.portfolios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$PortfolioAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioAssetsTable> {
  $$PortfolioAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PortfoliosTableAnnotationComposer get portfolioId {
    final $$PortfoliosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.portfolioId,
      referencedTable: $db.portfolios,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PortfoliosTableAnnotationComposer(
            $db: $db,
            $table: $db.portfolios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$PortfolioAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfolioAssetsTable,
          PortfolioAsset,
          $$PortfolioAssetsTableFilterComposer,
          $$PortfolioAssetsTableOrderingComposer,
          $$PortfolioAssetsTableAnnotationComposer,
          $$PortfolioAssetsTableCreateCompanionBuilder,
          $$PortfolioAssetsTableUpdateCompanionBuilder,
          (PortfolioAsset, $$PortfolioAssetsTableReferences),
          PortfolioAsset,
          PrefetchHooks Function({bool portfolioId, bool assetId})
        > {
  $$PortfolioAssetsTableTableManager(
    _$AppDatabase db,
    $PortfolioAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfolioAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> portfolioId = const Value.absent(),
                Value<int> assetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PortfolioAssetsCompanion(
                portfolioId: portfolioId,
                assetId: assetId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int portfolioId,
                required int assetId,
                Value<int> rowid = const Value.absent(),
              }) => PortfolioAssetsCompanion.insert(
                portfolioId: portfolioId,
                assetId: assetId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PortfolioAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({portfolioId = false, assetId = false}) {
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
                    if (portfolioId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.portfolioId,
                                referencedTable:
                                    $$PortfolioAssetsTableReferences
                                        ._portfolioIdTable(db),
                                referencedColumn:
                                    $$PortfolioAssetsTableReferences
                                        ._portfolioIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable:
                                    $$PortfolioAssetsTableReferences
                                        ._assetIdTable(db),
                                referencedColumn:
                                    $$PortfolioAssetsTableReferences
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

typedef $$PortfolioAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfolioAssetsTable,
      PortfolioAsset,
      $$PortfolioAssetsTableFilterComposer,
      $$PortfolioAssetsTableOrderingComposer,
      $$PortfolioAssetsTableAnnotationComposer,
      $$PortfolioAssetsTableCreateCompanionBuilder,
      $$PortfolioAssetsTableUpdateCompanionBuilder,
      (PortfolioAsset, $$PortfolioAssetsTableReferences),
      PortfolioAsset,
      PrefetchHooks Function({bool portfolioId, bool assetId})
    >;
typedef $$PortfolioModelsTableCreateCompanionBuilder =
    PortfolioModelsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      required String allocations,
      Value<DateTime> createdAt,
    });
typedef $$PortfolioModelsTableUpdateCompanionBuilder =
    PortfolioModelsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<String> allocations,
      Value<DateTime> createdAt,
    });

class $$PortfolioModelsTableFilterComposer
    extends Composer<_$AppDatabase, $PortfolioModelsTable> {
  $$PortfolioModelsTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PortfolioModelsTableOrderingComposer
    extends Composer<_$AppDatabase, $PortfolioModelsTable> {
  $$PortfolioModelsTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PortfolioModelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PortfolioModelsTable> {
  $$PortfolioModelsTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get allocations => $composableBuilder(
    column: $table.allocations,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PortfolioModelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PortfolioModelsTable,
          PortfolioModel,
          $$PortfolioModelsTableFilterComposer,
          $$PortfolioModelsTableOrderingComposer,
          $$PortfolioModelsTableAnnotationComposer,
          $$PortfolioModelsTableCreateCompanionBuilder,
          $$PortfolioModelsTableUpdateCompanionBuilder,
          (
            PortfolioModel,
            BaseReferences<
              _$AppDatabase,
              $PortfolioModelsTable,
              PortfolioModel
            >,
          ),
          PortfolioModel,
          PrefetchHooks Function()
        > {
  $$PortfolioModelsTableTableManager(
    _$AppDatabase db,
    $PortfolioModelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortfolioModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortfolioModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortfolioModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> allocations = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PortfolioModelsCompanion(
                id: id,
                name: name,
                description: description,
                allocations: allocations,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required String allocations,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PortfolioModelsCompanion.insert(
                id: id,
                name: name,
                description: description,
                allocations: allocations,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PortfolioModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PortfolioModelsTable,
      PortfolioModel,
      $$PortfolioModelsTableFilterComposer,
      $$PortfolioModelsTableOrderingComposer,
      $$PortfolioModelsTableAnnotationComposer,
      $$PortfolioModelsTableCreateCompanionBuilder,
      $$PortfolioModelsTableUpdateCompanionBuilder,
      (
        PortfolioModel,
        BaseReferences<_$AppDatabase, $PortfolioModelsTable, PortfolioModel>,
      ),
      PortfolioModel,
      PrefetchHooks Function()
    >;
typedef $$DailySnapshotsTableCreateCompanionBuilder =
    DailySnapshotsCompanion Function({
      Value<int> id,
      required DateTime date,
      Value<String> accountBalances,
      Value<double> portfolioValue,
      Value<double> investedAmount,
      Value<double> liquidCash,
      Value<double> totalSavings,
      Value<double> totalAssets,
      Value<double> liquidabile,
      Value<double> plEur,
      Value<double> netPlEur,
      Value<double> plAtPercent,
      Value<double> plPtfPercent,
      Value<double> periodPlEur,
      Value<double> periodPlAtPercent,
      Value<double> periodPlPtfPercent,
      Value<double> logReturn,
      Value<double> smaSavings,
      Value<double> smaExpenses,
      Value<double> smaNetPl,
      Value<double> annualizedVolatility,
      Value<double> deltaSmaRt,
      Value<double> income,
      Value<double> expenses,
      Value<double> cumulativeExpenses,
      Value<double> expensesAdjusted,
      Value<double> reimbursementsRegistered,
      Value<double> incomeRegistered,
      Value<double> gainsRegistered,
      Value<double> salesRegistered,
      Value<double> extraCash,
      Value<double> spendingVelocity,
      Value<double> savingsVelocity,
      Value<double> profitVelocity,
      Value<double> dailyRal,
      Value<double> euOverRal,
      Value<double> pensionValue,
      Value<double> diffHth,
      Value<double> rtAtRatio,
    });
typedef $$DailySnapshotsTableUpdateCompanionBuilder =
    DailySnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> accountBalances,
      Value<double> portfolioValue,
      Value<double> investedAmount,
      Value<double> liquidCash,
      Value<double> totalSavings,
      Value<double> totalAssets,
      Value<double> liquidabile,
      Value<double> plEur,
      Value<double> netPlEur,
      Value<double> plAtPercent,
      Value<double> plPtfPercent,
      Value<double> periodPlEur,
      Value<double> periodPlAtPercent,
      Value<double> periodPlPtfPercent,
      Value<double> logReturn,
      Value<double> smaSavings,
      Value<double> smaExpenses,
      Value<double> smaNetPl,
      Value<double> annualizedVolatility,
      Value<double> deltaSmaRt,
      Value<double> income,
      Value<double> expenses,
      Value<double> cumulativeExpenses,
      Value<double> expensesAdjusted,
      Value<double> reimbursementsRegistered,
      Value<double> incomeRegistered,
      Value<double> gainsRegistered,
      Value<double> salesRegistered,
      Value<double> extraCash,
      Value<double> spendingVelocity,
      Value<double> savingsVelocity,
      Value<double> profitVelocity,
      Value<double> dailyRal,
      Value<double> euOverRal,
      Value<double> pensionValue,
      Value<double> diffHth,
      Value<double> rtAtRatio,
    });

class $$DailySnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $DailySnapshotsTable> {
  $$DailySnapshotsTableFilterComposer({
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

  ColumnFilters<String> get accountBalances => $composableBuilder(
    column: $table.accountBalances,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get portfolioValue => $composableBuilder(
    column: $table.portfolioValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get investedAmount => $composableBuilder(
    column: $table.investedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get liquidCash => $composableBuilder(
    column: $table.liquidCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalSavings => $composableBuilder(
    column: $table.totalSavings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get liquidabile => $composableBuilder(
    column: $table.liquidabile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plEur => $composableBuilder(
    column: $table.plEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get netPlEur => $composableBuilder(
    column: $table.netPlEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get periodPlEur => $composableBuilder(
    column: $table.periodPlEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get periodPlAtPercent => $composableBuilder(
    column: $table.periodPlAtPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get periodPlPtfPercent => $composableBuilder(
    column: $table.periodPlPtfPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get logReturn => $composableBuilder(
    column: $table.logReturn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get smaSavings => $composableBuilder(
    column: $table.smaSavings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get smaExpenses => $composableBuilder(
    column: $table.smaExpenses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get smaNetPl => $composableBuilder(
    column: $table.smaNetPl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get annualizedVolatility => $composableBuilder(
    column: $table.annualizedVolatility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get deltaSmaRt => $composableBuilder(
    column: $table.deltaSmaRt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get income => $composableBuilder(
    column: $table.income,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expenses => $composableBuilder(
    column: $table.expenses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cumulativeExpenses => $composableBuilder(
    column: $table.cumulativeExpenses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expensesAdjusted => $composableBuilder(
    column: $table.expensesAdjusted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reimbursementsRegistered => $composableBuilder(
    column: $table.reimbursementsRegistered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get incomeRegistered => $composableBuilder(
    column: $table.incomeRegistered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gainsRegistered => $composableBuilder(
    column: $table.gainsRegistered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salesRegistered => $composableBuilder(
    column: $table.salesRegistered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get extraCash => $composableBuilder(
    column: $table.extraCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get spendingVelocity => $composableBuilder(
    column: $table.spendingVelocity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get savingsVelocity => $composableBuilder(
    column: $table.savingsVelocity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get profitVelocity => $composableBuilder(
    column: $table.profitVelocity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dailyRal => $composableBuilder(
    column: $table.dailyRal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get euOverRal => $composableBuilder(
    column: $table.euOverRal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pensionValue => $composableBuilder(
    column: $table.pensionValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diffHth => $composableBuilder(
    column: $table.diffHth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rtAtRatio => $composableBuilder(
    column: $table.rtAtRatio,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailySnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySnapshotsTable> {
  $$DailySnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get accountBalances => $composableBuilder(
    column: $table.accountBalances,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get portfolioValue => $composableBuilder(
    column: $table.portfolioValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get investedAmount => $composableBuilder(
    column: $table.investedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get liquidCash => $composableBuilder(
    column: $table.liquidCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalSavings => $composableBuilder(
    column: $table.totalSavings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get liquidabile => $composableBuilder(
    column: $table.liquidabile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plEur => $composableBuilder(
    column: $table.plEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get netPlEur => $composableBuilder(
    column: $table.netPlEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get periodPlEur => $composableBuilder(
    column: $table.periodPlEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get periodPlAtPercent => $composableBuilder(
    column: $table.periodPlAtPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get periodPlPtfPercent => $composableBuilder(
    column: $table.periodPlPtfPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get logReturn => $composableBuilder(
    column: $table.logReturn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get smaSavings => $composableBuilder(
    column: $table.smaSavings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get smaExpenses => $composableBuilder(
    column: $table.smaExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get smaNetPl => $composableBuilder(
    column: $table.smaNetPl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get annualizedVolatility => $composableBuilder(
    column: $table.annualizedVolatility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deltaSmaRt => $composableBuilder(
    column: $table.deltaSmaRt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get income => $composableBuilder(
    column: $table.income,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expenses => $composableBuilder(
    column: $table.expenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cumulativeExpenses => $composableBuilder(
    column: $table.cumulativeExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expensesAdjusted => $composableBuilder(
    column: $table.expensesAdjusted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reimbursementsRegistered => $composableBuilder(
    column: $table.reimbursementsRegistered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get incomeRegistered => $composableBuilder(
    column: $table.incomeRegistered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gainsRegistered => $composableBuilder(
    column: $table.gainsRegistered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salesRegistered => $composableBuilder(
    column: $table.salesRegistered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get extraCash => $composableBuilder(
    column: $table.extraCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get spendingVelocity => $composableBuilder(
    column: $table.spendingVelocity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get savingsVelocity => $composableBuilder(
    column: $table.savingsVelocity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get profitVelocity => $composableBuilder(
    column: $table.profitVelocity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dailyRal => $composableBuilder(
    column: $table.dailyRal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get euOverRal => $composableBuilder(
    column: $table.euOverRal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pensionValue => $composableBuilder(
    column: $table.pensionValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diffHth => $composableBuilder(
    column: $table.diffHth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rtAtRatio => $composableBuilder(
    column: $table.rtAtRatio,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailySnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySnapshotsTable> {
  $$DailySnapshotsTableAnnotationComposer({
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

  GeneratedColumn<String> get accountBalances => $composableBuilder(
    column: $table.accountBalances,
    builder: (column) => column,
  );

  GeneratedColumn<double> get portfolioValue => $composableBuilder(
    column: $table.portfolioValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get investedAmount => $composableBuilder(
    column: $table.investedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get liquidCash => $composableBuilder(
    column: $table.liquidCash,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalSavings => $composableBuilder(
    column: $table.totalSavings,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalAssets => $composableBuilder(
    column: $table.totalAssets,
    builder: (column) => column,
  );

  GeneratedColumn<double> get liquidabile => $composableBuilder(
    column: $table.liquidabile,
    builder: (column) => column,
  );

  GeneratedColumn<double> get plEur =>
      $composableBuilder(column: $table.plEur, builder: (column) => column);

  GeneratedColumn<double> get netPlEur =>
      $composableBuilder(column: $table.netPlEur, builder: (column) => column);

  GeneratedColumn<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get periodPlEur => $composableBuilder(
    column: $table.periodPlEur,
    builder: (column) => column,
  );

  GeneratedColumn<double> get periodPlAtPercent => $composableBuilder(
    column: $table.periodPlAtPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get periodPlPtfPercent => $composableBuilder(
    column: $table.periodPlPtfPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get logReturn =>
      $composableBuilder(column: $table.logReturn, builder: (column) => column);

  GeneratedColumn<double> get smaSavings => $composableBuilder(
    column: $table.smaSavings,
    builder: (column) => column,
  );

  GeneratedColumn<double> get smaExpenses => $composableBuilder(
    column: $table.smaExpenses,
    builder: (column) => column,
  );

  GeneratedColumn<double> get smaNetPl =>
      $composableBuilder(column: $table.smaNetPl, builder: (column) => column);

  GeneratedColumn<double> get annualizedVolatility => $composableBuilder(
    column: $table.annualizedVolatility,
    builder: (column) => column,
  );

  GeneratedColumn<double> get deltaSmaRt => $composableBuilder(
    column: $table.deltaSmaRt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get income =>
      $composableBuilder(column: $table.income, builder: (column) => column);

  GeneratedColumn<double> get expenses =>
      $composableBuilder(column: $table.expenses, builder: (column) => column);

  GeneratedColumn<double> get cumulativeExpenses => $composableBuilder(
    column: $table.cumulativeExpenses,
    builder: (column) => column,
  );

  GeneratedColumn<double> get expensesAdjusted => $composableBuilder(
    column: $table.expensesAdjusted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reimbursementsRegistered => $composableBuilder(
    column: $table.reimbursementsRegistered,
    builder: (column) => column,
  );

  GeneratedColumn<double> get incomeRegistered => $composableBuilder(
    column: $table.incomeRegistered,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gainsRegistered => $composableBuilder(
    column: $table.gainsRegistered,
    builder: (column) => column,
  );

  GeneratedColumn<double> get salesRegistered => $composableBuilder(
    column: $table.salesRegistered,
    builder: (column) => column,
  );

  GeneratedColumn<double> get extraCash =>
      $composableBuilder(column: $table.extraCash, builder: (column) => column);

  GeneratedColumn<double> get spendingVelocity => $composableBuilder(
    column: $table.spendingVelocity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get savingsVelocity => $composableBuilder(
    column: $table.savingsVelocity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get profitVelocity => $composableBuilder(
    column: $table.profitVelocity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dailyRal =>
      $composableBuilder(column: $table.dailyRal, builder: (column) => column);

  GeneratedColumn<double> get euOverRal =>
      $composableBuilder(column: $table.euOverRal, builder: (column) => column);

  GeneratedColumn<double> get pensionValue => $composableBuilder(
    column: $table.pensionValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get diffHth =>
      $composableBuilder(column: $table.diffHth, builder: (column) => column);

  GeneratedColumn<double> get rtAtRatio =>
      $composableBuilder(column: $table.rtAtRatio, builder: (column) => column);
}

class $$DailySnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailySnapshotsTable,
          DailySnapshot,
          $$DailySnapshotsTableFilterComposer,
          $$DailySnapshotsTableOrderingComposer,
          $$DailySnapshotsTableAnnotationComposer,
          $$DailySnapshotsTableCreateCompanionBuilder,
          $$DailySnapshotsTableUpdateCompanionBuilder,
          (
            DailySnapshot,
            BaseReferences<_$AppDatabase, $DailySnapshotsTable, DailySnapshot>,
          ),
          DailySnapshot,
          PrefetchHooks Function()
        > {
  $$DailySnapshotsTableTableManager(
    _$AppDatabase db,
    $DailySnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> accountBalances = const Value.absent(),
                Value<double> portfolioValue = const Value.absent(),
                Value<double> investedAmount = const Value.absent(),
                Value<double> liquidCash = const Value.absent(),
                Value<double> totalSavings = const Value.absent(),
                Value<double> totalAssets = const Value.absent(),
                Value<double> liquidabile = const Value.absent(),
                Value<double> plEur = const Value.absent(),
                Value<double> netPlEur = const Value.absent(),
                Value<double> plAtPercent = const Value.absent(),
                Value<double> plPtfPercent = const Value.absent(),
                Value<double> periodPlEur = const Value.absent(),
                Value<double> periodPlAtPercent = const Value.absent(),
                Value<double> periodPlPtfPercent = const Value.absent(),
                Value<double> logReturn = const Value.absent(),
                Value<double> smaSavings = const Value.absent(),
                Value<double> smaExpenses = const Value.absent(),
                Value<double> smaNetPl = const Value.absent(),
                Value<double> annualizedVolatility = const Value.absent(),
                Value<double> deltaSmaRt = const Value.absent(),
                Value<double> income = const Value.absent(),
                Value<double> expenses = const Value.absent(),
                Value<double> cumulativeExpenses = const Value.absent(),
                Value<double> expensesAdjusted = const Value.absent(),
                Value<double> reimbursementsRegistered = const Value.absent(),
                Value<double> incomeRegistered = const Value.absent(),
                Value<double> gainsRegistered = const Value.absent(),
                Value<double> salesRegistered = const Value.absent(),
                Value<double> extraCash = const Value.absent(),
                Value<double> spendingVelocity = const Value.absent(),
                Value<double> savingsVelocity = const Value.absent(),
                Value<double> profitVelocity = const Value.absent(),
                Value<double> dailyRal = const Value.absent(),
                Value<double> euOverRal = const Value.absent(),
                Value<double> pensionValue = const Value.absent(),
                Value<double> diffHth = const Value.absent(),
                Value<double> rtAtRatio = const Value.absent(),
              }) => DailySnapshotsCompanion(
                id: id,
                date: date,
                accountBalances: accountBalances,
                portfolioValue: portfolioValue,
                investedAmount: investedAmount,
                liquidCash: liquidCash,
                totalSavings: totalSavings,
                totalAssets: totalAssets,
                liquidabile: liquidabile,
                plEur: plEur,
                netPlEur: netPlEur,
                plAtPercent: plAtPercent,
                plPtfPercent: plPtfPercent,
                periodPlEur: periodPlEur,
                periodPlAtPercent: periodPlAtPercent,
                periodPlPtfPercent: periodPlPtfPercent,
                logReturn: logReturn,
                smaSavings: smaSavings,
                smaExpenses: smaExpenses,
                smaNetPl: smaNetPl,
                annualizedVolatility: annualizedVolatility,
                deltaSmaRt: deltaSmaRt,
                income: income,
                expenses: expenses,
                cumulativeExpenses: cumulativeExpenses,
                expensesAdjusted: expensesAdjusted,
                reimbursementsRegistered: reimbursementsRegistered,
                incomeRegistered: incomeRegistered,
                gainsRegistered: gainsRegistered,
                salesRegistered: salesRegistered,
                extraCash: extraCash,
                spendingVelocity: spendingVelocity,
                savingsVelocity: savingsVelocity,
                profitVelocity: profitVelocity,
                dailyRal: dailyRal,
                euOverRal: euOverRal,
                pensionValue: pensionValue,
                diffHth: diffHth,
                rtAtRatio: rtAtRatio,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                Value<String> accountBalances = const Value.absent(),
                Value<double> portfolioValue = const Value.absent(),
                Value<double> investedAmount = const Value.absent(),
                Value<double> liquidCash = const Value.absent(),
                Value<double> totalSavings = const Value.absent(),
                Value<double> totalAssets = const Value.absent(),
                Value<double> liquidabile = const Value.absent(),
                Value<double> plEur = const Value.absent(),
                Value<double> netPlEur = const Value.absent(),
                Value<double> plAtPercent = const Value.absent(),
                Value<double> plPtfPercent = const Value.absent(),
                Value<double> periodPlEur = const Value.absent(),
                Value<double> periodPlAtPercent = const Value.absent(),
                Value<double> periodPlPtfPercent = const Value.absent(),
                Value<double> logReturn = const Value.absent(),
                Value<double> smaSavings = const Value.absent(),
                Value<double> smaExpenses = const Value.absent(),
                Value<double> smaNetPl = const Value.absent(),
                Value<double> annualizedVolatility = const Value.absent(),
                Value<double> deltaSmaRt = const Value.absent(),
                Value<double> income = const Value.absent(),
                Value<double> expenses = const Value.absent(),
                Value<double> cumulativeExpenses = const Value.absent(),
                Value<double> expensesAdjusted = const Value.absent(),
                Value<double> reimbursementsRegistered = const Value.absent(),
                Value<double> incomeRegistered = const Value.absent(),
                Value<double> gainsRegistered = const Value.absent(),
                Value<double> salesRegistered = const Value.absent(),
                Value<double> extraCash = const Value.absent(),
                Value<double> spendingVelocity = const Value.absent(),
                Value<double> savingsVelocity = const Value.absent(),
                Value<double> profitVelocity = const Value.absent(),
                Value<double> dailyRal = const Value.absent(),
                Value<double> euOverRal = const Value.absent(),
                Value<double> pensionValue = const Value.absent(),
                Value<double> diffHth = const Value.absent(),
                Value<double> rtAtRatio = const Value.absent(),
              }) => DailySnapshotsCompanion.insert(
                id: id,
                date: date,
                accountBalances: accountBalances,
                portfolioValue: portfolioValue,
                investedAmount: investedAmount,
                liquidCash: liquidCash,
                totalSavings: totalSavings,
                totalAssets: totalAssets,
                liquidabile: liquidabile,
                plEur: plEur,
                netPlEur: netPlEur,
                plAtPercent: plAtPercent,
                plPtfPercent: plPtfPercent,
                periodPlEur: periodPlEur,
                periodPlAtPercent: periodPlAtPercent,
                periodPlPtfPercent: periodPlPtfPercent,
                logReturn: logReturn,
                smaSavings: smaSavings,
                smaExpenses: smaExpenses,
                smaNetPl: smaNetPl,
                annualizedVolatility: annualizedVolatility,
                deltaSmaRt: deltaSmaRt,
                income: income,
                expenses: expenses,
                cumulativeExpenses: cumulativeExpenses,
                expensesAdjusted: expensesAdjusted,
                reimbursementsRegistered: reimbursementsRegistered,
                incomeRegistered: incomeRegistered,
                gainsRegistered: gainsRegistered,
                salesRegistered: salesRegistered,
                extraCash: extraCash,
                spendingVelocity: spendingVelocity,
                savingsVelocity: savingsVelocity,
                profitVelocity: profitVelocity,
                dailyRal: dailyRal,
                euOverRal: euOverRal,
                pensionValue: pensionValue,
                diffHth: diffHth,
                rtAtRatio: rtAtRatio,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailySnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailySnapshotsTable,
      DailySnapshot,
      $$DailySnapshotsTableFilterComposer,
      $$DailySnapshotsTableOrderingComposer,
      $$DailySnapshotsTableAnnotationComposer,
      $$DailySnapshotsTableCreateCompanionBuilder,
      $$DailySnapshotsTableUpdateCompanionBuilder,
      (
        DailySnapshot,
        BaseReferences<_$AppDatabase, $DailySnapshotsTable, DailySnapshot>,
      ),
      DailySnapshot,
      PrefetchHooks Function()
    >;
typedef $$DepreciationSchedulesTableCreateCompanionBuilder =
    DepreciationSchedulesCompanion Function({
      Value<int> id,
      Value<int?> transactionId,
      required String assetName,
      required String assetCategory,
      required double totalAmount,
      Value<String> currency,
      required DepreciationMethod method,
      required DateTime startDate,
      required DateTime endDate,
      Value<DateTime?> expenseDate,
      required int usefulLifeMonths,
      required DepreciationDirection direction,
      Value<StepFrequency> stepFrequency,
      Value<int?> bufferId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$DepreciationSchedulesTableUpdateCompanionBuilder =
    DepreciationSchedulesCompanion Function({
      Value<int> id,
      Value<int?> transactionId,
      Value<String> assetName,
      Value<String> assetCategory,
      Value<double> totalAmount,
      Value<String> currency,
      Value<DepreciationMethod> method,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<DateTime?> expenseDate,
      Value<int> usefulLifeMonths,
      Value<DepreciationDirection> direction,
      Value<StepFrequency> stepFrequency,
      Value<int?> bufferId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$DepreciationSchedulesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DepreciationSchedulesTable,
          DepreciationSchedule
        > {
  $$DepreciationSchedulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.depreciationSchedules.transactionId,
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

  static MultiTypedResultKey<$DepreciationEntriesTable, List<DepreciationEntry>>
  _depreciationEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.depreciationEntries,
        aliasName: $_aliasNameGenerator(
          db.depreciationSchedules.id,
          db.depreciationEntries.scheduleId,
        ),
      );

  $$DepreciationEntriesTableProcessedTableManager get depreciationEntriesRefs {
    final manager = $$DepreciationEntriesTableTableManager(
      $_db,
      $_db.depreciationEntries,
    ).filter((f) => f.scheduleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _depreciationEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BuffersTable, List<Buffer>> _buffersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.buffers,
    aliasName: $_aliasNameGenerator(
      db.depreciationSchedules.id,
      db.buffers.linkedDepreciationId,
    ),
  );

  $$BuffersTableProcessedTableManager get buffersRefs {
    final manager = $$BuffersTableTableManager($_db, $_db.buffers).filter(
      (f) => f.linkedDepreciationId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_buffersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DepreciationSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $DepreciationSchedulesTable> {
  $$DepreciationSchedulesTableFilterComposer({
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

  ColumnFilters<String> get assetName => $composableBuilder(
    column: $table.assetName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetCategory => $composableBuilder(
    column: $table.assetCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DepreciationMethod, DepreciationMethod, String>
  get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usefulLifeMonths => $composableBuilder(
    column: $table.usefulLifeMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    DepreciationDirection,
    DepreciationDirection,
    String
  >
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<StepFrequency, StepFrequency, String>
  get stepFrequency => $composableBuilder(
    column: $table.stepFrequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get bufferId => $composableBuilder(
    column: $table.bufferId,
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

  Expression<bool> depreciationEntriesRefs(
    Expression<bool> Function($$DepreciationEntriesTableFilterComposer f) f,
  ) {
    final $$DepreciationEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.depreciationEntries,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DepreciationEntriesTableFilterComposer(
            $db: $db,
            $table: $db.depreciationEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> buffersRefs(
    Expression<bool> Function($$BuffersTableFilterComposer f) f,
  ) {
    final $$BuffersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.linkedDepreciationId,
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
    return f(composer);
  }
}

class $$DepreciationSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $DepreciationSchedulesTable> {
  $$DepreciationSchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get assetName => $composableBuilder(
    column: $table.assetName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetCategory => $composableBuilder(
    column: $table.assetCategory,
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

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usefulLifeMonths => $composableBuilder(
    column: $table.usefulLifeMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepFrequency => $composableBuilder(
    column: $table.stepFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bufferId => $composableBuilder(
    column: $table.bufferId,
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
}

class $$DepreciationSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DepreciationSchedulesTable> {
  $$DepreciationSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetName =>
      $composableBuilder(column: $table.assetName, builder: (column) => column);

  GeneratedColumn<String> get assetCategory => $composableBuilder(
    column: $table.assetCategory,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DepreciationMethod, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get expenseDate => $composableBuilder(
    column: $table.expenseDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get usefulLifeMonths => $composableBuilder(
    column: $table.usefulLifeMonths,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DepreciationDirection, String>
  get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StepFrequency, String> get stepFrequency =>
      $composableBuilder(
        column: $table.stepFrequency,
        builder: (column) => column,
      );

  GeneratedColumn<int> get bufferId =>
      $composableBuilder(column: $table.bufferId, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

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

  Expression<T> depreciationEntriesRefs<T extends Object>(
    Expression<T> Function($$DepreciationEntriesTableAnnotationComposer a) f,
  ) {
    final $$DepreciationEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.depreciationEntries,
          getReferencedColumn: (t) => t.scheduleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.depreciationEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> buffersRefs<T extends Object>(
    Expression<T> Function($$BuffersTableAnnotationComposer a) f,
  ) {
    final $$BuffersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.buffers,
      getReferencedColumn: (t) => t.linkedDepreciationId,
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
    return f(composer);
  }
}

class $$DepreciationSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DepreciationSchedulesTable,
          DepreciationSchedule,
          $$DepreciationSchedulesTableFilterComposer,
          $$DepreciationSchedulesTableOrderingComposer,
          $$DepreciationSchedulesTableAnnotationComposer,
          $$DepreciationSchedulesTableCreateCompanionBuilder,
          $$DepreciationSchedulesTableUpdateCompanionBuilder,
          (DepreciationSchedule, $$DepreciationSchedulesTableReferences),
          DepreciationSchedule,
          PrefetchHooks Function({
            bool transactionId,
            bool depreciationEntriesRefs,
            bool buffersRefs,
          })
        > {
  $$DepreciationSchedulesTableTableManager(
    _$AppDatabase db,
    $DepreciationSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DepreciationSchedulesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DepreciationSchedulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DepreciationSchedulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<String> assetName = const Value.absent(),
                Value<String> assetCategory = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DepreciationMethod> method = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<DateTime?> expenseDate = const Value.absent(),
                Value<int> usefulLifeMonths = const Value.absent(),
                Value<DepreciationDirection> direction = const Value.absent(),
                Value<StepFrequency> stepFrequency = const Value.absent(),
                Value<int?> bufferId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DepreciationSchedulesCompanion(
                id: id,
                transactionId: transactionId,
                assetName: assetName,
                assetCategory: assetCategory,
                totalAmount: totalAmount,
                currency: currency,
                method: method,
                startDate: startDate,
                endDate: endDate,
                expenseDate: expenseDate,
                usefulLifeMonths: usefulLifeMonths,
                direction: direction,
                stepFrequency: stepFrequency,
                bufferId: bufferId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                required String assetName,
                required String assetCategory,
                required double totalAmount,
                Value<String> currency = const Value.absent(),
                required DepreciationMethod method,
                required DateTime startDate,
                required DateTime endDate,
                Value<DateTime?> expenseDate = const Value.absent(),
                required int usefulLifeMonths,
                required DepreciationDirection direction,
                Value<StepFrequency> stepFrequency = const Value.absent(),
                Value<int?> bufferId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DepreciationSchedulesCompanion.insert(
                id: id,
                transactionId: transactionId,
                assetName: assetName,
                assetCategory: assetCategory,
                totalAmount: totalAmount,
                currency: currency,
                method: method,
                startDate: startDate,
                endDate: endDate,
                expenseDate: expenseDate,
                usefulLifeMonths: usefulLifeMonths,
                direction: direction,
                stepFrequency: stepFrequency,
                bufferId: bufferId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DepreciationSchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionId = false,
                depreciationEntriesRefs = false,
                buffersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (depreciationEntriesRefs) db.depreciationEntries,
                    if (buffersRefs) db.buffers,
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
                                        $$DepreciationSchedulesTableReferences
                                            ._transactionIdTable(db),
                                    referencedColumn:
                                        $$DepreciationSchedulesTableReferences
                                            ._transactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (depreciationEntriesRefs)
                        await $_getPrefetchedData<
                          DepreciationSchedule,
                          $DepreciationSchedulesTable,
                          DepreciationEntry
                        >(
                          currentTable: table,
                          referencedTable:
                              $$DepreciationSchedulesTableReferences
                                  ._depreciationEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DepreciationSchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).depreciationEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scheduleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (buffersRefs)
                        await $_getPrefetchedData<
                          DepreciationSchedule,
                          $DepreciationSchedulesTable,
                          Buffer
                        >(
                          currentTable: table,
                          referencedTable:
                              $$DepreciationSchedulesTableReferences
                                  ._buffersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DepreciationSchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).buffersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedDepreciationId == item.id,
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

typedef $$DepreciationSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DepreciationSchedulesTable,
      DepreciationSchedule,
      $$DepreciationSchedulesTableFilterComposer,
      $$DepreciationSchedulesTableOrderingComposer,
      $$DepreciationSchedulesTableAnnotationComposer,
      $$DepreciationSchedulesTableCreateCompanionBuilder,
      $$DepreciationSchedulesTableUpdateCompanionBuilder,
      (DepreciationSchedule, $$DepreciationSchedulesTableReferences),
      DepreciationSchedule,
      PrefetchHooks Function({
        bool transactionId,
        bool depreciationEntriesRefs,
        bool buffersRefs,
      })
    >;
typedef $$DepreciationEntriesTableCreateCompanionBuilder =
    DepreciationEntriesCompanion Function({
      Value<int> id,
      required int scheduleId,
      required DateTime date,
      required double amount,
      required double cumulative,
      required double remaining,
    });
typedef $$DepreciationEntriesTableUpdateCompanionBuilder =
    DepreciationEntriesCompanion Function({
      Value<int> id,
      Value<int> scheduleId,
      Value<DateTime> date,
      Value<double> amount,
      Value<double> cumulative,
      Value<double> remaining,
    });

final class $$DepreciationEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DepreciationEntriesTable,
          DepreciationEntry
        > {
  $$DepreciationEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DepreciationSchedulesTable _scheduleIdTable(_$AppDatabase db) =>
      db.depreciationSchedules.createAlias(
        $_aliasNameGenerator(
          db.depreciationEntries.scheduleId,
          db.depreciationSchedules.id,
        ),
      );

  $$DepreciationSchedulesTableProcessedTableManager get scheduleId {
    final $_column = $_itemColumn<int>('schedule_id')!;

    final manager = $$DepreciationSchedulesTableTableManager(
      $_db,
      $_db.depreciationSchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DepreciationEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DepreciationEntriesTable> {
  $$DepreciationEntriesTableFilterComposer({
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

  ColumnFilters<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnFilters(column),
  );

  $$DepreciationSchedulesTableFilterComposer get scheduleId {
    final $$DepreciationSchedulesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableFilterComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DepreciationEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DepreciationEntriesTable> {
  $$DepreciationEntriesTableOrderingComposer({
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

  ColumnOrderings<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnOrderings(column),
  );

  $$DepreciationSchedulesTableOrderingComposer get scheduleId {
    final $$DepreciationSchedulesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableOrderingComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DepreciationEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DepreciationEntriesTable> {
  $$DepreciationEntriesTableAnnotationComposer({
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

  GeneratedColumn<double> get cumulative => $composableBuilder(
    column: $table.cumulative,
    builder: (column) => column,
  );

  GeneratedColumn<double> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);

  $$DepreciationSchedulesTableAnnotationComposer get scheduleId {
    final $$DepreciationSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DepreciationEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DepreciationEntriesTable,
          DepreciationEntry,
          $$DepreciationEntriesTableFilterComposer,
          $$DepreciationEntriesTableOrderingComposer,
          $$DepreciationEntriesTableAnnotationComposer,
          $$DepreciationEntriesTableCreateCompanionBuilder,
          $$DepreciationEntriesTableUpdateCompanionBuilder,
          (DepreciationEntry, $$DepreciationEntriesTableReferences),
          DepreciationEntry,
          PrefetchHooks Function({bool scheduleId})
        > {
  $$DepreciationEntriesTableTableManager(
    _$AppDatabase db,
    $DepreciationEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DepreciationEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DepreciationEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DepreciationEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scheduleId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<double> cumulative = const Value.absent(),
                Value<double> remaining = const Value.absent(),
              }) => DepreciationEntriesCompanion(
                id: id,
                scheduleId: scheduleId,
                date: date,
                amount: amount,
                cumulative: cumulative,
                remaining: remaining,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scheduleId,
                required DateTime date,
                required double amount,
                required double cumulative,
                required double remaining,
              }) => DepreciationEntriesCompanion.insert(
                id: id,
                scheduleId: scheduleId,
                date: date,
                amount: amount,
                cumulative: cumulative,
                remaining: remaining,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DepreciationEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scheduleId = false}) {
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
                    if (scheduleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scheduleId,
                                referencedTable:
                                    $$DepreciationEntriesTableReferences
                                        ._scheduleIdTable(db),
                                referencedColumn:
                                    $$DepreciationEntriesTableReferences
                                        ._scheduleIdTable(db)
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

typedef $$DepreciationEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DepreciationEntriesTable,
      DepreciationEntry,
      $$DepreciationEntriesTableFilterComposer,
      $$DepreciationEntriesTableOrderingComposer,
      $$DepreciationEntriesTableAnnotationComposer,
      $$DepreciationEntriesTableCreateCompanionBuilder,
      $$DepreciationEntriesTableUpdateCompanionBuilder,
      (DepreciationEntry, $$DepreciationEntriesTableReferences),
      DepreciationEntry,
      PrefetchHooks Function({bool scheduleId})
    >;
typedef $$BuffersTableCreateCompanionBuilder =
    BuffersCompanion Function({
      Value<int> id,
      required String name,
      Value<double?> targetAmount,
      Value<int?> linkedDepreciationId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$BuffersTableUpdateCompanionBuilder =
    BuffersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double?> targetAmount,
      Value<int?> linkedDepreciationId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$BuffersTableReferences
    extends BaseReferences<_$AppDatabase, $BuffersTable, Buffer> {
  $$BuffersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DepreciationSchedulesTable _linkedDepreciationIdTable(
    _$AppDatabase db,
  ) => db.depreciationSchedules.createAlias(
    $_aliasNameGenerator(
      db.buffers.linkedDepreciationId,
      db.depreciationSchedules.id,
    ),
  );

  $$DepreciationSchedulesTableProcessedTableManager? get linkedDepreciationId {
    final $_column = $_itemColumn<int>('linked_depreciation_id');
    if ($_column == null) return null;
    final manager = $$DepreciationSchedulesTableTableManager(
      $_db,
      $_db.depreciationSchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _linkedDepreciationIdTable($_db),
    );
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

  $$DepreciationSchedulesTableFilterComposer get linkedDepreciationId {
    final $$DepreciationSchedulesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.linkedDepreciationId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableFilterComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
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

  $$DepreciationSchedulesTableOrderingComposer get linkedDepreciationId {
    final $$DepreciationSchedulesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.linkedDepreciationId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableOrderingComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
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

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DepreciationSchedulesTableAnnotationComposer get linkedDepreciationId {
    final $$DepreciationSchedulesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.linkedDepreciationId,
          referencedTable: $db.depreciationSchedules,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DepreciationSchedulesTableAnnotationComposer(
                $db: $db,
                $table: $db.depreciationSchedules,
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
            bool linkedDepreciationId,
            bool bufferTransactionsRefs,
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
                Value<int?> linkedDepreciationId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BuffersCompanion(
                id: id,
                name: name,
                targetAmount: targetAmount,
                linkedDepreciationId: linkedDepreciationId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double?> targetAmount = const Value.absent(),
                Value<int?> linkedDepreciationId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BuffersCompanion.insert(
                id: id,
                name: name,
                targetAmount: targetAmount,
                linkedDepreciationId: linkedDepreciationId,
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
              ({linkedDepreciationId = false, bufferTransactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bufferTransactionsRefs) db.bufferTransactions,
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
                        if (linkedDepreciationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedDepreciationId,
                                    referencedTable: $$BuffersTableReferences
                                        ._linkedDepreciationIdTable(db),
                                    referencedColumn: $$BuffersTableReferences
                                        ._linkedDepreciationIdTable(db)
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
        bool linkedDepreciationId,
        bool bufferTransactionsRefs,
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
typedef $$PerformanceSummariesTableCreateCompanionBuilder =
    PerformanceSummariesCompanion Function({
      required int year,
      Value<int?> month,
      required double plAtPercent,
      required double plPtfPercent,
      required double eoyPlEur,
      required double yoyDiffEur,
      required double absoluteReturn,
      required double reverseCompound,
      Value<bool> isYtd,
      Value<int> rowid,
    });
typedef $$PerformanceSummariesTableUpdateCompanionBuilder =
    PerformanceSummariesCompanion Function({
      Value<int> year,
      Value<int?> month,
      Value<double> plAtPercent,
      Value<double> plPtfPercent,
      Value<double> eoyPlEur,
      Value<double> yoyDiffEur,
      Value<double> absoluteReturn,
      Value<double> reverseCompound,
      Value<bool> isYtd,
      Value<int> rowid,
    });

class $$PerformanceSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $PerformanceSummariesTable> {
  $$PerformanceSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get eoyPlEur => $composableBuilder(
    column: $table.eoyPlEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get yoyDiffEur => $composableBuilder(
    column: $table.yoyDiffEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get absoluteReturn => $composableBuilder(
    column: $table.absoluteReturn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reverseCompound => $composableBuilder(
    column: $table.reverseCompound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isYtd => $composableBuilder(
    column: $table.isYtd,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PerformanceSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $PerformanceSummariesTable> {
  $$PerformanceSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get eoyPlEur => $composableBuilder(
    column: $table.eoyPlEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get yoyDiffEur => $composableBuilder(
    column: $table.yoyDiffEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get absoluteReturn => $composableBuilder(
    column: $table.absoluteReturn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reverseCompound => $composableBuilder(
    column: $table.reverseCompound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isYtd => $composableBuilder(
    column: $table.isYtd,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PerformanceSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PerformanceSummariesTable> {
  $$PerformanceSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<double> get plAtPercent => $composableBuilder(
    column: $table.plAtPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get plPtfPercent => $composableBuilder(
    column: $table.plPtfPercent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get eoyPlEur =>
      $composableBuilder(column: $table.eoyPlEur, builder: (column) => column);

  GeneratedColumn<double> get yoyDiffEur => $composableBuilder(
    column: $table.yoyDiffEur,
    builder: (column) => column,
  );

  GeneratedColumn<double> get absoluteReturn => $composableBuilder(
    column: $table.absoluteReturn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reverseCompound => $composableBuilder(
    column: $table.reverseCompound,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isYtd =>
      $composableBuilder(column: $table.isYtd, builder: (column) => column);
}

class $$PerformanceSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PerformanceSummariesTable,
          PerformanceSummary,
          $$PerformanceSummariesTableFilterComposer,
          $$PerformanceSummariesTableOrderingComposer,
          $$PerformanceSummariesTableAnnotationComposer,
          $$PerformanceSummariesTableCreateCompanionBuilder,
          $$PerformanceSummariesTableUpdateCompanionBuilder,
          (
            PerformanceSummary,
            BaseReferences<
              _$AppDatabase,
              $PerformanceSummariesTable,
              PerformanceSummary
            >,
          ),
          PerformanceSummary,
          PrefetchHooks Function()
        > {
  $$PerformanceSummariesTableTableManager(
    _$AppDatabase db,
    $PerformanceSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PerformanceSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PerformanceSummariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PerformanceSummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int?> month = const Value.absent(),
                Value<double> plAtPercent = const Value.absent(),
                Value<double> plPtfPercent = const Value.absent(),
                Value<double> eoyPlEur = const Value.absent(),
                Value<double> yoyDiffEur = const Value.absent(),
                Value<double> absoluteReturn = const Value.absent(),
                Value<double> reverseCompound = const Value.absent(),
                Value<bool> isYtd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerformanceSummariesCompanion(
                year: year,
                month: month,
                plAtPercent: plAtPercent,
                plPtfPercent: plPtfPercent,
                eoyPlEur: eoyPlEur,
                yoyDiffEur: yoyDiffEur,
                absoluteReturn: absoluteReturn,
                reverseCompound: reverseCompound,
                isYtd: isYtd,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int year,
                Value<int?> month = const Value.absent(),
                required double plAtPercent,
                required double plPtfPercent,
                required double eoyPlEur,
                required double yoyDiffEur,
                required double absoluteReturn,
                required double reverseCompound,
                Value<bool> isYtd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerformanceSummariesCompanion.insert(
                year: year,
                month: month,
                plAtPercent: plAtPercent,
                plPtfPercent: plPtfPercent,
                eoyPlEur: eoyPlEur,
                yoyDiffEur: yoyDiffEur,
                absoluteReturn: absoluteReturn,
                reverseCompound: reverseCompound,
                isYtd: isYtd,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PerformanceSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PerformanceSummariesTable,
      PerformanceSummary,
      $$PerformanceSummariesTableFilterComposer,
      $$PerformanceSummariesTableOrderingComposer,
      $$PerformanceSummariesTableAnnotationComposer,
      $$PerformanceSummariesTableCreateCompanionBuilder,
      $$PerformanceSummariesTableUpdateCompanionBuilder,
      (
        PerformanceSummary,
        BaseReferences<
          _$AppDatabase,
          $PerformanceSummariesTable,
          PerformanceSummary
        >,
      ),
      PerformanceSummary,
      PrefetchHooks Function()
    >;
typedef $$CalendarDaysTableCreateCompanionBuilder =
    CalendarDaysCompanion Function({
      required DateTime date,
      Value<bool> isBankHoliday,
      Value<bool> isCompanyHoliday,
      Value<String?> holidayName,
      Value<bool> isWorkingDay,
      Value<int> monthWorkingDays,
      Value<int> rowid,
    });
typedef $$CalendarDaysTableUpdateCompanionBuilder =
    CalendarDaysCompanion Function({
      Value<DateTime> date,
      Value<bool> isBankHoliday,
      Value<bool> isCompanyHoliday,
      Value<String?> holidayName,
      Value<bool> isWorkingDay,
      Value<int> monthWorkingDays,
      Value<int> rowid,
    });

class $$CalendarDaysTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarDaysTable> {
  $$CalendarDaysTableFilterComposer({
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

  ColumnFilters<bool> get isBankHoliday => $composableBuilder(
    column: $table.isBankHoliday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompanyHoliday => $composableBuilder(
    column: $table.isCompanyHoliday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holidayName => $composableBuilder(
    column: $table.holidayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isWorkingDay => $composableBuilder(
    column: $table.isWorkingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthWorkingDays => $composableBuilder(
    column: $table.monthWorkingDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarDaysTable> {
  $$CalendarDaysTableOrderingComposer({
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

  ColumnOrderings<bool> get isBankHoliday => $composableBuilder(
    column: $table.isBankHoliday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompanyHoliday => $composableBuilder(
    column: $table.isCompanyHoliday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holidayName => $composableBuilder(
    column: $table.holidayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isWorkingDay => $composableBuilder(
    column: $table.isWorkingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthWorkingDays => $composableBuilder(
    column: $table.monthWorkingDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarDaysTable> {
  $$CalendarDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get isBankHoliday => $composableBuilder(
    column: $table.isBankHoliday,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompanyHoliday => $composableBuilder(
    column: $table.isCompanyHoliday,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holidayName => $composableBuilder(
    column: $table.holidayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isWorkingDay => $composableBuilder(
    column: $table.isWorkingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthWorkingDays => $composableBuilder(
    column: $table.monthWorkingDays,
    builder: (column) => column,
  );
}

class $$CalendarDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarDaysTable,
          CalendarDay,
          $$CalendarDaysTableFilterComposer,
          $$CalendarDaysTableOrderingComposer,
          $$CalendarDaysTableAnnotationComposer,
          $$CalendarDaysTableCreateCompanionBuilder,
          $$CalendarDaysTableUpdateCompanionBuilder,
          (
            CalendarDay,
            BaseReferences<_$AppDatabase, $CalendarDaysTable, CalendarDay>,
          ),
          CalendarDay,
          PrefetchHooks Function()
        > {
  $$CalendarDaysTableTableManager(_$AppDatabase db, $CalendarDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<bool> isBankHoliday = const Value.absent(),
                Value<bool> isCompanyHoliday = const Value.absent(),
                Value<String?> holidayName = const Value.absent(),
                Value<bool> isWorkingDay = const Value.absent(),
                Value<int> monthWorkingDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarDaysCompanion(
                date: date,
                isBankHoliday: isBankHoliday,
                isCompanyHoliday: isCompanyHoliday,
                holidayName: holidayName,
                isWorkingDay: isWorkingDay,
                monthWorkingDays: monthWorkingDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                Value<bool> isBankHoliday = const Value.absent(),
                Value<bool> isCompanyHoliday = const Value.absent(),
                Value<String?> holidayName = const Value.absent(),
                Value<bool> isWorkingDay = const Value.absent(),
                Value<int> monthWorkingDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarDaysCompanion.insert(
                date: date,
                isBankHoliday: isBankHoliday,
                isCompanyHoliday: isCompanyHoliday,
                holidayName: holidayName,
                isWorkingDay: isWorkingDay,
                monthWorkingDays: monthWorkingDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarDaysTable,
      CalendarDay,
      $$CalendarDaysTableFilterComposer,
      $$CalendarDaysTableOrderingComposer,
      $$CalendarDaysTableAnnotationComposer,
      $$CalendarDaysTableCreateCompanionBuilder,
      $$CalendarDaysTableUpdateCompanionBuilder,
      (
        CalendarDay,
        BaseReferences<_$AppDatabase, $CalendarDaysTable, CalendarDay>,
      ),
      CalendarDay,
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
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ImportConfigsCompanion(
                id: id,
                accountId: accountId,
                skipRows: skipRows,
                mappingsJson: mappingsJson,
                formulaJson: formulaJson,
                hashColumnsJson: hashColumnsJson,
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
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ImportConfigsCompanion.insert(
                id: id,
                accountId: accountId,
                skipRows: skipRows,
                mappingsJson: mappingsJson,
                formulaJson: formulaJson,
                hashColumnsJson: hashColumnsJson,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
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
  $$PortfoliosTableTableManager get portfolios =>
      $$PortfoliosTableTableManager(_db, _db.portfolios);
  $$PortfolioAssetsTableTableManager get portfolioAssets =>
      $$PortfolioAssetsTableTableManager(_db, _db.portfolioAssets);
  $$PortfolioModelsTableTableManager get portfolioModels =>
      $$PortfolioModelsTableTableManager(_db, _db.portfolioModels);
  $$DailySnapshotsTableTableManager get dailySnapshots =>
      $$DailySnapshotsTableTableManager(_db, _db.dailySnapshots);
  $$DepreciationSchedulesTableTableManager get depreciationSchedules =>
      $$DepreciationSchedulesTableTableManager(_db, _db.depreciationSchedules);
  $$DepreciationEntriesTableTableManager get depreciationEntries =>
      $$DepreciationEntriesTableTableManager(_db, _db.depreciationEntries);
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
  $$PerformanceSummariesTableTableManager get performanceSummaries =>
      $$PerformanceSummariesTableTableManager(_db, _db.performanceSummaries);
  $$CalendarDaysTableTableManager get calendarDays =>
      $$CalendarDaysTableTableManager(_db, _db.calendarDays);
  $$AppConfigsTableTableManager get appConfigs =>
      $$AppConfigsTableTableManager(_db, _db.appConfigs);
  $$ImportConfigsTableTableManager get importConfigs =>
      $$ImportConfigsTableTableManager(_db, _db.importConfigs);
}
