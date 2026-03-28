import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;

import '../../database/database.dart';
import '../../utils/logger.dart';
import 'enable_banking_config.dart';

final _log = getLogger('EnableBankingService');

const _baseUrl = 'https://api.enablebanking.com';

/// Direct REST client for Enable Banking API.
/// JWT is generated locally from PEM private key — no server required.
class EnableBankingService {
  final AppDatabase _db;
  final Dio _dio;
  EnableBankingConfig? _config;

  EnableBankingService(this._db) : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  /// Load config from disk. Returns false if not configured.
  Future<bool> init() async {
    _config = await EnableBankingConfig.load();
    return _config != null;
  }

  EnableBankingConfig? get config => _config;

  /// Save initial setup credentials and verify they work.
  /// Returns list of ASPSPs on success, throws on failure.
  Future<List<Map<String, dynamic>>> setupAndVerify({
    required String appId,
    required String privateKeyPath,
  }) async {
    final config = EnableBankingConfig(
      appId: appId,
      privateKeyPath: privateKeyPath,
    );
    // Test: generate JWT and fetch ASPSPs
    final jwt = await _generateJwt(config);
    final aspsps = await _fetchAspsps(jwt, 'IT');
    // If we got here, credentials work — save config
    await config.save();
    _config = config;
    _log.info('Setup verified: ${aspsps.length} ASPSPs for IT');
    return aspsps;
  }

  /// Fetch available banks for a country.
  Future<List<Map<String, dynamic>>> getAspsps(String country) async {
    final jwt = await _jwt();
    return _fetchAspsps(jwt, country);
  }

  /// Start bank authorization. Returns auth URL to open in WebView.
  Future<String> startAuth({
    required String aspspName,
    required String aspspCountry,
    required String redirectUrl,
    int validDays = 90,
  }) async {
    final jwt = await _jwt();
    final validUntil =
        DateTime.now().add(Duration(days: validDays)).toUtc().toIso8601String();
    final response = await _dio.post(
      '/auth',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      data: {
        'access': {'valid_until': validUntil},
        'aspsp': {'name': aspspName, 'country': aspspCountry},
        'redirect_url': redirectUrl,
        'psu_type': 'personal',
      },
    );
    final authUrl = response.data['url'] as String;
    _log.info('Auth started for $aspspName ($aspspCountry), redirecting to bank');
    return authUrl;
  }

  /// Complete auth flow with the code from callback redirect.
  /// Creates a session and returns the session data with accounts.
  Future<BankSession> createSession({
    required String code,
    required String aspspName,
    required String aspspCountry,
    required int validDays,
  }) async {
    final jwt = await _jwt();
    final response = await _dio.post(
      '/sessions',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      data: {'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    final sessionId = data['session_id'] as String;
    final accounts = <BankAccount>[];

    final accountsList = data['accounts'] as List<dynamic>? ?? [];
    for (final acc in accountsList) {
      final accMap = acc as Map<String, dynamic>;
      accounts.add(BankAccount(
        uid: accMap['uid'] as String? ?? '',
        iban: accMap['iban'] as String? ?? accMap['account_id']?['iban'] as String? ?? '',
        currency: accMap['currency'] as String? ?? 'EUR',
      ));
    }

    final session = BankSession(
      sessionId: sessionId,
      aspspName: aspspName,
      aspspCountry: aspspCountry,
      validUntil: DateTime.now().add(Duration(days: validDays)),
      accounts: accounts,
    );

    // Save to config
    _config!.sessions.add(session);
    await _config!.save();
    _log.info('Session created: $sessionId with ${accounts.length} accounts');
    return session;
  }

  /// Fetch balances for a bank account.
  Future<List<Map<String, dynamic>>> getBalances(String accountUid) async {
    final jwt = await _jwt();
    final response = await _dio.get(
      '/accounts/$accountUid/balances',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
    return (response.data['balances'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  /// Fetch transactions for a bank account.
  Future<List<Map<String, dynamic>>> getTransactions(
    String accountUid, {
    String? dateFrom,
    String? dateTo,
  }) async {
    final jwt = await _jwt();
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;

    final response = await _dio.get(
      '/accounts/$accountUid/transactions',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      queryParameters: params.isNotEmpty ? params : null,
    );
    return (response.data['transactions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  /// Sync all active sessions: update balances and import new transactions.
  Future<SyncResult> syncAll() async {
    if (_config == null) return SyncResult.empty();
    var totalTx = 0;
    var totalUpdated = 0;

    for (final session in _config!.sessions) {
      if (session.isExpired) {
        _log.info('Skipping expired session: ${session.aspspName}');
        continue;
      }
      for (final account in session.accounts) {
        if (!account.included || account.localAccountId == null) continue;
        try {
          // Sync balances
          final balances = await getBalances(account.uid);
          if (balances.isNotEmpty) {
            totalUpdated++;
            _log.fine('Balances for ${account.iban}: $balances');
          }

          // Sync transactions
          final dateFrom = session.lastSyncedAt != null
              ? _formatDate(session.lastSyncedAt!.subtract(const Duration(days: 3)))
              : null;
          final transactions = await getTransactions(
            account.uid,
            dateFrom: dateFrom,
          );
          final imported = await _importTransactions(
            account.localAccountId!,
            account.currency,
            transactions,
          );
          totalTx += imported;
          _log.info('Synced ${account.iban}: $imported new transactions');
        } catch (e) {
          _log.warning('Failed to sync account ${account.iban}: $e');
        }
      }
      session.lastSyncedAt = DateTime.now();
    }
    await _config!.save();
    return SyncResult(transactionsImported: totalTx, accountsUpdated: totalUpdated);
  }

  /// Import transactions with dedup based on date + amount + description hash.
  Future<int> _importTransactions(
    int accountId,
    String currency,
    List<Map<String, dynamic>> transactions,
  ) async {
    var imported = 0;
    for (final tx in transactions) {
      final date = DateTime.tryParse(tx['value_date'] as String? ?? tx['booking_date'] as String? ?? '');
      if (date == null) continue;

      final amount = double.tryParse('${tx['transaction_amount']?['amount'] ?? tx['amount'] ?? 0}') ?? 0;
      final desc = tx['remittance_information_unstructured'] as String? ??
          tx['creditor_name'] as String? ??
          tx['debtor_name'] as String? ??
          '';

      // Dedup hash: date + amount + description
      final hashInput = '${date.toIso8601String().substring(0, 10)}|$amount|$desc';
      final hash = md5.convert(utf8.encode(hashInput)).toString();

      // Check if already imported
      final existing = await _db.customSelect(
        'SELECT id FROM transactions WHERE account_id = ? AND import_hash = ?',
        variables: [Variable.withInt(accountId), Variable.withString(hash)],
      ).get();
      if (existing.isNotEmpty) continue;

      // Determine balance after (if provided)
      final balanceAfter = double.tryParse(
        '${tx['balance_after_transaction']?['amount'] ?? ''}',
      );

      await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
        accountId: accountId,
        operationDate: date,
        valueDate: date,
        amount: amount,
        description: Value(desc),
        balanceAfter: Value(balanceAfter),
        currency: Value(currency),
        importHash: Value(hash),
        tags: const Value('["open_banking"]'),
      ));
      imported++;
    }
    return imported;
  }

  /// Delete a session and remove it from config.
  Future<void> removeSession(String sessionId) async {
    _config?.sessions.removeWhere((s) => s.sessionId == sessionId);
    await _config?.save();
    _log.info('Removed session: $sessionId');
  }

  // ── Private helpers ──────────────────────────────────

  Future<String> _jwt() async {
    if (_config == null) throw StateError('Open Banking not configured');
    return _generateJwt(_config!);
  }

  Future<String> _generateJwt(EnableBankingConfig config) async {
    final pem = await config.readPrivateKey();
    final jwt = JWT(
      {
        'iss': 'enablebanking.com',
        'aud': 'api.enablebanking.com',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      },
      header: {'kid': config.appId},
    );
    final token = jwt.sign(
      RSAPrivateKey(pem),
      algorithm: JWTAlgorithm.RS256,
    );
    return token;
  }

  Future<List<Map<String, dynamic>>> _fetchAspsps(
    String jwt,
    String country,
  ) async {
    final response = await _dio.get(
      '/aspsps',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      queryParameters: {'country': country},
    );
    return (response.data['aspsps'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class SyncResult {
  final int transactionsImported;
  final int accountsUpdated;

  const SyncResult({
    required this.transactionsImported,
    required this.accountsUpdated,
  });

  factory SyncResult.empty() => const SyncResult(transactionsImported: 0, accountsUpdated: 0);
}
