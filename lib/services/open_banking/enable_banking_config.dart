import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../utils/logger.dart';

final _log = getLogger('EnableBankingConfig');

/// Persisted Open Banking configuration stored in
/// ~/.config/FinanceCopilot/open_banking.json (macOS)
/// %APPDATA%\FinanceCopilot\open_banking.json (Windows)
class EnableBankingConfig {
  String appId;
  String privateKeyPath;
  List<BankSession> sessions;

  EnableBankingConfig({
    required this.appId,
    required this.privateKeyPath,
    this.sessions = const [],
  });

  static final _configDir = Directory(
    p.join(
      Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.',
      '.config',
      'FinanceCopilot',
    ),
  );

  static File get _file => File(p.join(_configDir.path, 'open_banking.json'));

  /// Returns null if not configured yet.
  static Future<EnableBankingConfig?> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return EnableBankingConfig._fromJson(json);
    } catch (e) {
      _log.warning('Failed to load open banking config: $e');
      return null;
    }
  }

  Future<void> save() async {
    if (!await _configDir.exists()) await _configDir.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_toJson()),
    );
    _log.info('Open banking config saved');
  }

  /// Read the PEM private key from disk.
  Future<String> readPrivateKey() async {
    final file = File(privateKeyPath);
    if (!await file.exists()) {
      throw FileSystemException('Private key not found', privateKeyPath);
    }
    return file.readAsString();
  }

  factory EnableBankingConfig._fromJson(Map<String, dynamic> json) {
    return EnableBankingConfig(
      appId: json['app_id'] as String? ?? '',
      privateKeyPath: json['private_key_path'] as String? ?? '',
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map((s) => BankSession._fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> _toJson() => {
        'provider': 'enable_banking',
        'app_id': appId,
        'private_key_path': privateKeyPath,
        'sessions': sessions.map((s) => s._toJson()).toList(),
      };
}

class BankSession {
  String sessionId;
  String aspspName;
  String aspspCountry;
  DateTime validUntil;
  DateTime? lastSyncedAt;
  List<BankAccount> accounts;

  BankSession({
    required this.sessionId,
    required this.aspspName,
    required this.aspspCountry,
    required this.validUntil,
    this.lastSyncedAt,
    this.accounts = const [],
  });

  bool get isExpired => validUntil.isBefore(DateTime.now());

  factory BankSession._fromJson(Map<String, dynamic> json) {
    return BankSession(
      sessionId: json['session_id'] as String? ?? '',
      aspspName: json['aspsp_name'] as String? ?? '',
      aspspCountry: json['aspsp_country'] as String? ?? '',
      validUntil: DateTime.parse(json['valid_until'] as String),
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
      accounts: (json['accounts'] as List<dynamic>?)
              ?.map((a) => BankAccount._fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> _toJson() => {
        'session_id': sessionId,
        'aspsp_name': aspspName,
        'aspsp_country': aspspCountry,
        'valid_until': validUntil.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'accounts': accounts.map((a) => a._toJson()).toList(),
      };
}

class BankAccount {
  String uid;
  int? localAccountId;
  String iban;
  String currency;
  bool included;

  BankAccount({
    required this.uid,
    this.localAccountId,
    required this.iban,
    required this.currency,
    this.included = true,
  });

  factory BankAccount._fromJson(Map<String, dynamic> json) {
    return BankAccount(
      uid: json['uid'] as String? ?? '',
      localAccountId: json['local_account_id'] as int?,
      iban: json['iban'] as String? ?? '',
      currency: json['currency'] as String? ?? 'EUR',
      included: json['included'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toJson() => {
        'uid': uid,
        'local_account_id': localAccountId,
        'iban': iban,
        'currency': currency,
        'included': included,
      };
}
