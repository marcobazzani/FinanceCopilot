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

  EnableBankingService(this._db) : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    contentType: 'application/json',
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) {
        final body = e.response?.data;
        _log.warning('API error ${e.response?.statusCode}: $body');
        // Rethrow with the server error message if available
        if (body is Map && body.containsKey('error')) {
          handler.reject(DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            message: '${body['error']}: ${body['error_description'] ?? body['message'] ?? ''}',
          ));
          return;
        }
        handler.next(e);
      },
    ));
  }

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
    _log.info('Generated JWT (first 50 chars): ${jwt.substring(0, 50)}...');
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
    final state = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await _dio.post(
      '/auth',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
      data: {
        'access': {'valid_until': validUntil},
        'aspsp': {'name': aspspName, 'country': aspspCountry},
        'redirect_url': redirectUrl,
        'psu_type': 'personal',
        'state': state,
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
    _log.info('POST /sessions response keys: ${data.keys.toList()}');
    _log.info('POST /sessions accounts raw: ${data['accounts']}');

    final sessionId = data['session_id'] as String;
    final accounts = <BankAccount>[];

    // Accounts are returned as full AccountResource objects only in POST /sessions.
    // The array may contain either Map objects or plain UID strings.
    final accountsList = data['accounts'] as List<dynamic>? ?? [];
    for (final acc in accountsList) {
      if (acc is Map<String, dynamic>) {
        // Full account resource
        final accountId = acc['account_id'];
        String iban = '';
        if (accountId is Map) {
          iban = accountId['iban'] as String? ?? '';
        }
        accounts.add(BankAccount(
          uid: acc['uid'] as String? ?? '',
          iban: iban,
          currency: acc['currency'] as String? ?? 'EUR',
        ));
      } else if (acc is String) {
        // Just a UID string — fetch details separately
        accounts.add(BankAccount(uid: acc, iban: '', currency: 'EUR'));
      }
    }

    // If accounts list was empty but session is authorized, try fetching
    // account details via GET /sessions/{id} (returns UIDs in accounts_data)
    if (accounts.isEmpty) {
      _log.info('No accounts in POST response, trying GET /sessions/$sessionId');
      final sessionData = await _dio.get(
        '/sessions/$sessionId',
        options: Options(headers: {'Authorization': 'Bearer ${await _jwt()}'}),
      );
      final sData = sessionData.data as Map<String, dynamic>;
      final accountsData = sData['accounts_data'] as List<dynamic>? ?? [];
      final accountUids = sData['accounts'] as List<dynamic>? ?? [];
      _log.info('GET /sessions accounts_data: $accountsData, accounts: $accountUids');

      // Try accounts_data first (has uid + identification_hash)
      for (final ad in accountsData) {
        if (ad is Map<String, dynamic>) {
          accounts.add(BankAccount(
            uid: ad['uid'] as String? ?? '',
            iban: '',
            currency: 'EUR',
          ));
        }
      }
      // Fall back to plain uid list
      if (accounts.isEmpty) {
        for (final uid in accountUids) {
          if (uid is String) {
            accounts.add(BankAccount(uid: uid, iban: '', currency: 'EUR'));
          }
        }
      }
    }

    // For any account without IBAN/currency, try to fetch details
    for (final account in accounts) {
      if (account.uid.isEmpty) continue;
      try {
        final details = await _dio.get(
          '/accounts/${account.uid}/details',
          options: Options(headers: {'Authorization': 'Bearer ${await _jwt()}'}),
        );
        final d = details.data as Map<String, dynamic>;
        _log.info('Account ${account.uid} details: ${d.keys}');
        final accountId = d['account_id'];
        if (accountId is Map) {
          account.iban = accountId['iban'] as String? ?? account.iban;
        }
        account.currency = d['currency'] as String? ?? account.currency;
      } catch (e) {
        _log.warning('Failed to fetch details for ${account.uid}: $e');
      }
    }

    final validUntilDate = data['access'] is Map
        ? DateTime.tryParse(data['access']['valid_until'] as String? ?? '')
        : null;

    final session = BankSession(
      sessionId: sessionId,
      aspspName: aspspName,
      aspspCountry: aspspCountry,
      validUntil: validUntilDate ?? DateTime.now().add(Duration(days: validDays)),
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

  /// Import transactions with dedup based on entry_reference or date+amount+desc hash.
  Future<int> _importTransactions(
    int accountId,
    String currency,
    List<Map<String, dynamic>> transactions,
  ) async {
    var imported = 0;
    for (final tx in transactions) {
      final date = DateTime.tryParse(
        tx['value_date'] as String? ?? tx['booking_date'] as String? ?? '',
      );
      if (date == null) continue;

      final amount = double.tryParse(
        '${tx['transaction_amount']?['amount'] ?? tx['amount'] ?? 0}',
      ) ?? 0;

      // Description: try remittance info, then creditor/debtor name (nested objects)
      final desc = tx['remittance_information_unstructured'] as String? ??
          (tx['creditor'] as Map<String, dynamic>?)?['name'] as String? ??
          (tx['debtor'] as Map<String, dynamic>?)?['name'] as String? ??
          '';

      // Dedup: prefer entry_reference (bank-assigned unique ID), fall back to hash
      final entryRef = tx['entry_reference'] as String?;
      final hashInput = entryRef ?? '${date.toIso8601String().substring(0, 10)}|$amount|$desc';
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
