part of '../main.dart';

extension _AppShellSettingsDialog on _AppShellState {
  Future<void> _showSettingsDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final db = ref.read(databaseProvider);
    final baseCurrency = ref.read(baseCurrencyProvider).value ?? 'EUR';
    final currentLocale = ref.read(appLocaleProvider).value ?? '';
    final currentTaxRate = ref.read(defaultTaxRateProvider).value ?? kDefaultTaxRate;

    var selectedCurrency = baseCurrency;
    var selectedLocale = _localeOptions.any((o) => o.$1 == currentLocale) ? currentLocale : '';
    var selectedLanguage = ref.read(portableLanguageProvider);
    final taxRateCtrl = TextEditingController(
      text: (currentTaxRate * 100).toStringAsFixed(
        (currentTaxRate * 100) == (currentTaxRate * 100).truncateToDouble() ? 0 : 2,
      ),
    );
    final taxFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.settingsTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCurrency,
                    decoration: InputDecoration(labelText: s.settingsCurrency),
                    items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCurrency = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLocale,
                    decoration: InputDecoration(labelText: s.settingsNumberFormat),
                    items: _localeOptions.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))).toList(),
                    onChanged: (v) => setDialogState(() => selectedLocale = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    decoration: InputDecoration(labelText: s.settingsLanguage),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'it', child: Text('Italiano')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedLanguage = v!),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: taxFormKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: TextFormField(
                      controller: taxRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: s.settingsDefaultTaxRate,
                        helperText: s.settingsDefaultTaxRateHelp,
                        suffixText: '%',
                      ),
                      validator: (v) {
                        final n = fmt.parseFlexibleNumber(v ?? '');
                        if (n == null || n < 0 || n > 100) {
                          return s.settingsTaxRateInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.settingsClearCache, style: Theme.of(ctx).textTheme.bodyMedium),
                            Text(
                              s.settingsClearCacheSubtitle,
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                          side: BorderSide(color: Theme.of(ctx).colorScheme.error),
                        ),
                        onPressed: () async {
                          await ref.read(marketPriceServiceProvider).clearCache();
                          if (ctx.mounted) showInfoSnack(ctx, s.settingsCacheCleared);
                        },
                        child: Text(s.settingsClearButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(s.settingsGoogleDrive, style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final sync = ref.read(googleDriveSyncProvider);
                      if (sync.isSignedIn) {
                        return Row(
                          children: [
                            const Icon(Icons.cloud_done, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.settingsSyncSignedIn(sync.userEmail ?? ''), style: Theme.of(ctx).textTheme.bodySmall),
                            ),
                            TextButton(
                              onPressed: () async {
                                await sync.signOut();
                                setDialogState(() {});
                              },
                              child: Text(s.settingsSyncSignOut),
                            ),
                          ],
                        );
                      } else {
                        return OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_outlined, size: 18),
                          label: Text(s.settingsSyncSignIn),
                          onPressed: () async {
                            final ok = await sync.signIn();
                            if (ok) {
                              // Just sign in. Backup/Restore are explicit user
                              // actions in the Import/Export dialog.
                              _wireSyncCallbacks(sync);
                              setDialogState(() {});
                            }
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.settingsWipeDb, style: Theme.of(ctx).textTheme.bodyMedium),
                            Text(
                              s.settingsWipeDbSubtitle,
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                          side: BorderSide(color: Theme.of(ctx).colorScheme.error),
                        ),
                        onPressed: () => _wipeDb(ctx),
                        child: Text(s.settingsWipeButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                if (taxFormKey.currentState?.validate() != true) return;
                final taxPct = fmt.parseFlexibleNumber(taxRateCtrl.text)!;
                final taxFraction = (taxPct / 100).clamp(0.0, 1.0);
                await db
                    .into(db.appConfigs)
                    .insertOnConflictUpdate(
                      AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: selectedCurrency),
                    );
                await db
                    .into(db.appConfigs)
                    .insertOnConflictUpdate(
                      AppConfigsCompanion.insert(key: 'LOCALE', value: selectedLocale),
                    );
                await db
                    .into(db.appConfigs)
                    .insertOnConflictUpdate(
                      AppConfigsCompanion.insert(key: 'TAX_RATE', value: taxFraction.toString()),
                    );
                await AppSettings.setLanguage(selectedLanguage);
                ref.read(portableLanguageProvider.notifier).state = selectedLanguage;
                _log.info('Settings saved: currency=$selectedCurrency, locale=$selectedLocale, lang=$selectedLanguage, tax=$taxFraction');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}
