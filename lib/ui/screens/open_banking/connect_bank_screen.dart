import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/open_banking/enable_banking_config.dart';
import '../../../services/open_banking/open_banking_providers.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/logger.dart';

final _log = getLogger('ConnectBankScreen');

const _redirectUrl = 'https://marcobazzani.github.io/FinanceCopilot/callback.html';

/// Screen to connect a new bank: country → bank picker → WebView auth → account linking.
class ConnectBankScreen extends ConsumerStatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  ConsumerState<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends ConsumerState<ConnectBankScreen> {
  String _country = 'IT';
  List<Map<String, dynamic>> _banks = [];
  bool _loadingBanks = false;
  String? _error;

  // Auth flow state
  String? _selectedBankName;

  // Post-auth state
  BankSession? _newSession;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    setState(() {
      _loadingBanks = true;
      _error = null;
    });
    try {
      final service = ref.read(enableBankingServiceProvider);
      await service.init();
      final banks = await service.getAspsps(_country);
      if (mounted) {
        setState(() {
          _banks = banks;
          _loadingBanks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingBanks = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    if (_newSession != null) return _buildSessionResult(s);
    return _buildBankPicker(s);
  }

  Widget _buildBankPicker(AppStrings s) {
    return Scaffold(
      appBar: AppBar(title: Text(s.obConnectBank)),
      body: Column(
        children: [
          // Country selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(s.obCountry, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _country,
                  items: _countryList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _country = v);
                      _fetchBanks();
                    }
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_loadingBanks)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _BankListView(
                banks: _banks,
                onSelect: _startAuth,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionResult(AppStrings s) {
    final session = _newSession!;
    return _AccountLinkingScreen(
      session: session,
      onDone: () => Navigator.pop(context, true),
    );
  }

  Future<void> _startAuth(Map<String, dynamic> bank) async {
    final s = ref.read(appStringsProvider);
    final name = bank['name'] as String;
    setState(() {
      _selectedBankName = name;
      _error = null;

    });
    try {
      final service = ref.read(enableBankingServiceProvider);
      final authUrl = await service.startAuth(
        aspspName: name,
        aspspCountry: _country,
        redirectUrl: _redirectUrl,
      );
      // Open bank login in system browser
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);

      if (!mounted) return;
      // Show dialog to paste the authorization code
      final code = await _showCodeDialog(s);
      if (!mounted) return;

      if (code == null || code.trim().isEmpty) {
        setState(() {

          _error = null;
        });
        return;
      }
      await _completeAuth(code.trim());
    } catch (e) {
      _log.warning('Failed to start auth for $name: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<String?> _showCodeDialog(AppStrings s) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(s.obPasteCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.obPasteCodeDesc),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: s.obAuthCode,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(s.obConnect),
          ),
        ],
      ),
    );
  }

  Future<void> _completeAuth(String code) async {
    final s = ref.read(appStringsProvider);
    try {
      final service = ref.read(enableBankingServiceProvider);
      final session = await service.createSession(
        code: code,
        aspspName: _selectedBankName!,
        aspspCountry: _country,
        validDays: 90,
      );

      if (session.accounts.isEmpty) {
        // No accounts discovered — bank consent may have been skipped
        await service.removeSession(session.sessionId);
        if (mounted) {
          setState(() => _error = s.obNoAccountsDiscovered);
        }
        return;
      }

      ref.read(openBankingConfigProvider.notifier).state = service.config;
      if (mounted) setState(() => _newSession = session);
    } catch (e) {
      _log.warning('Failed to create session: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static const _countryList = [
    'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI',
    'FR', 'GB', 'GR', 'HR', 'HU', 'IE', 'IS', 'IT', 'LI', 'LT',
    'LU', 'LV', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SK', 'SI',
  ];
}

/// Searchable bank list.
class _BankListView extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _BankListView({required this.banks, required this.onSelect});

  @override
  State<_BankListView> createState() => _BankListViewState();
}

class _BankListViewState extends State<_BankListView> {
  String _query = '';

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.banks;
    final q = _query.toLowerCase();
    return widget.banks
        .where((b) => (b['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final bank = _filtered[index];
              final name = bank['name'] as String? ?? '';
              return ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text(name),
                onTap: () => widget.onSelect(bank),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// After auth, lets user link each discovered bank account to an existing
/// local account or create a new one.
class _AccountLinkingScreen extends ConsumerStatefulWidget {
  final BankSession session;
  final VoidCallback onDone;

  const _AccountLinkingScreen({required this.session, required this.onDone});

  @override
  ConsumerState<_AccountLinkingScreen> createState() => _AccountLinkingScreenState();
}

class _AccountLinkingScreenState extends ConsumerState<_AccountLinkingScreen> {
  /// Mapping: bank account uid → local account id.
  /// null = create new, _skipSentinel = skip entirely.
  static const _skipSentinel = -1;
  final Map<String, int?> _linkChoices = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.obConnectionSuccess)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.obConnectedTo(widget.session.aspspName),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(s.obLinkAccountsDesc, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Expanded(
              child: accountsAsync.when(
                data: (localAccounts) => ListView(
                  children: widget.session.accounts.map((bankAcc) {
                    final iban = bankAcc.iban.isNotEmpty
                        ? _maskIban(bankAcc.iban)
                        : bankAcc.uid.substring(0, 8);
                    final choice = _linkChoices[bankAcc.uid];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$iban (${bankAcc.currency})',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: choice,
                              decoration: InputDecoration(
                                labelText: s.obLinkTo,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(s.obCreateNewAccount),
                                ),
                                DropdownMenuItem<int?>(
                                  value: _skipSentinel,
                                  child: Text(s.obSkipAccount),
                                ),
                                ...localAccounts.map((a) => DropdownMenuItem<int?>(
                                      value: a.id,
                                      child: Text('${a.name} (${a.currency})'),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _linkChoices[bankAcc.uid] = v),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(s.error(e)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: _saving ? null : _saveLinks,
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLinks() async {
    setState(() => _saving = true);
    try {
      final accountService = ref.read(accountServiceProvider);
      final service = ref.read(enableBankingServiceProvider);

      for (final bankAcc in widget.session.accounts) {
        final linkedId = _linkChoices[bankAcc.uid];
        if (linkedId == _skipSentinel) {
          // Skip: mark as not included
          bankAcc.included = false;
          bankAcc.localAccountId = null;
        } else if (linkedId != null) {
          // Link to existing account
          bankAcc.localAccountId = linkedId;
          bankAcc.included = true;
          // Store IBAN in institution field for reference
          if (bankAcc.iban.isNotEmpty) {
            await accountService.update(
              linkedId,
              AccountsCompanion(institution: Value(bankAcc.iban)),
            );
          }
        } else {
          // Create new account
          bankAcc.included = true;
          final label = bankAcc.iban.isNotEmpty
              ? '${widget.session.aspspName} ${_maskIban(bankAcc.iban)}'
              : '${widget.session.aspspName} ${bankAcc.uid.substring(0, 8)}';
          final id = await accountService.create(
            name: label,
            currency: bankAcc.currency,
            institution: bankAcc.iban,
          );
          bankAcc.localAccountId = id;
        }
      }
      await service.config!.save();
      widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _maskIban(String iban) {
    if (iban.length <= 8) return iban;
    return '${iban.substring(0, 4)}...${iban.substring(iban.length - 4)}';
  }
}
