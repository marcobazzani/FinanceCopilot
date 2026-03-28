import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_strings.dart';
import '../../../services/open_banking/enable_banking_config.dart';
import '../../../services/open_banking/open_banking_providers.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/logger.dart';
import 'connect_bank_screen.dart';
import 'setup_screen.dart';

final _log = getLogger('ConnectionsScreen');

/// Manages existing Open Banking connections and allows adding new ones.
class OpenBankingConnectionsScreen extends ConsumerStatefulWidget {
  const OpenBankingConnectionsScreen({super.key});

  @override
  ConsumerState<OpenBankingConnectionsScreen> createState() =>
      _OpenBankingConnectionsScreenState();
}

class _OpenBankingConnectionsScreenState
    extends ConsumerState<OpenBankingConnectionsScreen> {
  EnableBankingConfig? _config;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await EnableBankingConfig.load();
    if (mounted) setState(() { _config = config; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.obConnectionsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Not configured yet — redirect to setup
    if (_config == null) {
      return const OpenBankingSetupScreen();
    }

    final sessions = _config!.sessions;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.obConnectionsTitle),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: s.obSyncNow,
              onPressed: _syncAll,
            ),
        ],
      ),
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(s.obNoConnections),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(s.obConnectBank),
                    onPressed: _addConnection,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...sessions.map((session) => _SessionCard(
                      session: session,
                      config: _config!,
                      onSync: () => _syncSession(session),
                      onRemove: () => _removeSession(session),
                      onToggleAccount: (account) => _toggleAccount(account),
                    )),
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(s.obConnectBank),
                    onPressed: _addConnection,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _addConnection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ConnectBankScreen()),
    );
    if (result == true) _loadConfig();
  }

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    try {
      final service = ref.read(enableBankingServiceProvider);
      await service.init();
      final result = await service.syncAll();
      _log.info('Sync complete: ${result.transactionsImported} tx imported');
      await _loadConfig();
    } catch (e) {
      _log.warning('Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncSession(BankSession session) async {
    // Sync just this session (re-uses syncAll for simplicity)
    await _syncAll();
  }

  Future<void> _removeSession(BankSession session) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.obRemoveConnection),
        content: Text(s.obRemoveConfirm(session.aspspName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(enableBankingServiceProvider);
    await service.init();
    await service.removeSession(session.sessionId);
    await _loadConfig();
  }

  Future<void> _toggleAccount(BankAccount account) async {
    account.included = !account.included;
    await _config!.save();
    setState(() {});
  }
}

class _SessionCard extends ConsumerWidget {
  final BankSession session;
  final EnableBankingConfig config;
  final VoidCallback onSync;
  final VoidCallback onRemove;
  final ValueChanged<BankAccount> onToggleAccount;

  const _SessionCard({
    required this.session,
    required this.config,
    required this.onSync,
    required this.onRemove,
    required this.onToggleAccount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    final isExpired = session.isExpired;
    final df = DateFormat.yMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.aspspName} (${session.aspspCountry})',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isExpired ? Icons.error : Icons.check_circle,
                            size: 14,
                            color: isExpired ? theme.colorScheme.error : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired ? s.obExpired : s.obActive,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isExpired ? theme.colorScheme.error : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${s.obExpiresOn}: ${df.format(session.validUntil)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (session.lastSyncedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${s.obLastSync}: ${_relativeTime(session.lastSyncedAt!, s)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'sync') onSync();
                    if (v == 'remove') onRemove();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'sync', child: Text(s.obSyncNow)),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(s.obRemoveConnection,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            // Accounts list
            ...session.accounts.map((account) => _AccountRow(
                  account: account,
                  onToggle: () => onToggleAccount(account),
                )),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt, AppStrings s) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return s.obJustNow;
    if (diff.inMinutes < 60) return s.obMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.obHoursAgo(diff.inHours);
    return s.obDaysAgo(diff.inDays);
  }
}

class _AccountRow extends StatelessWidget {
  final BankAccount account;
  final VoidCallback onToggle;

  const _AccountRow({required this.account, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iban = account.iban.isNotEmpty ? _maskIban(account.iban) : account.uid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(iban, style: theme.textTheme.bodyMedium)),
          Text(account.currency, style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          Switch(
            value: account.included,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }

  static String _maskIban(String iban) {
    if (iban.length <= 8) return iban;
    return '${iban.substring(0, 4)}...${iban.substring(iban.length - 4)}';
  }
}
