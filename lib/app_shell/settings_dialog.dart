part of '../main.dart';

extension _AppShellSettingsDialog on _AppShellState {
  Future<void> _showSettingsDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    var cacheCleared = false;
    await showDialog<void>(
      context: context,
      builder: (_) => _SettingsDialog(
        onCacheCleared: () => cacheCleared = true,
        // The wipe runs on the host screen: the dialog closes first, so the
        // export picker, the confirmation and its messages are not stacked
        // under (or hidden behind) the settings dialog.
        onWipe: () => _wipeDb(context),
        onSignedIn: _wireSyncCallbacks,
      ),
    );
    // Confirmed once the dialog is gone: a snack bar raised while it is open
    // renders under its modal barrier.
    if (cacheCleared && context.mounted) showInfoSnack(context, s.settingsCacheCleared);
  }
}

/// The Settings form. Owns the tax-rate controller (disposed with the dialog
/// once its closing animation is over) and saves every setting in one
/// transaction. It starts from the stored settings: until they have all
/// loaded there is no form and no Save, so a default is never written over a
/// stored value.
class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.onCacheCleared, required this.onWipe, required this.onSignedIn});

  final VoidCallback onCacheCleared;

  /// Called after the dialog has closed itself.
  final VoidCallback onWipe;
  final void Function(GoogleDriveSyncService sync) onSignedIn;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  /// Whether the form holds the stored settings (see [_load]).
  bool _loaded = false;

  /// The base currency in force when the dialog opened (the outgoing one).
  late final String _baseCurrency;
  late String _selectedCurrency;

  /// The number format the dialog opened with. Written back only when the
  /// user picks another: the stored system default shows as the locale this
  /// device resolves it to, which must not be saved as a choice.
  late final String _openedLocale;
  late String _selectedLocale;
  late String _selectedLanguage;

  /// The tax rate the dialog opened with, and the percentage its field was
  /// pre-filled with: a percentage left alone saves the stored rate as it is.
  late final double _openedTaxRate;
  late final double _openedTaxPct;

  /// The locale the tax-rate field is spelled in (the number format in force
  /// when the dialog opened), and read back in, strictly.
  late final String _taxLocale;
  final _taxRateCtrl = TextEditingController();
  final _taxFormKey = GlobalKey<FormState>();
  bool _cacheCleared = false;
  bool _saving = false;
  bool _saveFailed = false;

  /// Whether the last Drive sign-in started here did not complete. Said in
  /// the dialog: a snack bar would sit under its modal barrier.
  bool _signInFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ref.read(portableLanguageProvider);
  }

  /// Fills the form, once, from the stored settings.
  void _load({required String baseCurrency, required String locale, required double taxRate}) {
    _baseCurrency = baseCurrency;
    _selectedCurrency = baseCurrency;
    _openedLocale = ref.read(appStringsProvider).numberLocaleOptions.any((o) => o.$1 == locale) ? locale : '';
    _selectedLocale = _openedLocale;
    _openedTaxRate = taxRate;
    // The percentage without the product's float noise (0.29 × 100 is
    // 28.999999999999996), pre-filled with every digit it has
    // (fmt.editableFigure): a stored 0.123456 shows, and saves, as 12.3456,
    // not rounded to 12.346.
    _openedTaxPct = stripFloatNoise(taxRate * 100);
    _taxLocale = locale;
    _taxRateCtrl.text = fmt.editableFigure(_openedTaxPct, NumberFormat.decimalPattern(locale), locale: locale);
    _loaded = true;
  }

  @override
  void dispose() {
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _clearCache() async {
    await ref.read(marketPriceServiceProvider).clearCache();
    widget.onCacheCleared();
    if (mounted) setState(() => _cacheCleared = true);
  }

  /// Just signs in: Backup/Restore are explicit user actions in the
  /// Import/Export dialog.
  Future<void> _signIn(GoogleDriveSyncService sync) async {
    setState(() => _signInFailed = false);
    final ok = await sync.signIn();
    if (ok) widget.onSignedIn(sync);
    if (mounted) setState(() => _signInFailed = !ok);
  }

  Future<void> _save() async {
    if (!_loaded || _saving || _taxFormKey.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final db = ref.read(databaseProvider);
    // Read before the first await: the dialog may be dismissed while saving.
    final assetEvents = ref.read(assetEventServiceProvider);
    final language = ref.read(portableLanguageProvider.notifier);
    // Validated above: a percentage the locale reads, from 0 to 100.
    final taxPct = fmt.tryParseLocalized(_taxRateCtrl.text, locale: _taxLocale)!;
    // A rate left alone is written back as stored, not re-derived from its
    // percentage.
    final taxFraction = taxPct == _openedTaxPct ? _openedTaxRate : (taxPct / 100).clamp(0.0, 1.0);
    final currencyChanged = _selectedCurrency != _baseCurrency;
    try {
      // One transaction: the rate re-stamping below is only right together
      // with the new base currency, so neither may be stored without the other.
      await db.transaction(() async {
        if (currencyChanged) {
          // Stored asset-event exchange rates are quoted against the base
          // currency in force when they were written, but carry no record of
          // which one. Stamp the OUTGOING base onto the unattributed ones
          // BEFORE the new base is persisted: the rates (including ones the
          // user typed or a broker file supplied) are preserved, and consumers
          // stop trusting them for the new base instead of silently
          // misapplying them.
          final stamped = await assetEvents.stampExchangeRateBase(_baseCurrency);
          _log.info(
            'Base currency changing $_baseCurrency -> $_selectedCurrency: stamped $stamped exchange rate(s) as $_baseCurrency-quoted',
          );
        }
        await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: _selectedCurrency));
        if (_selectedLocale != _openedLocale) {
          await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'LOCALE', value: _selectedLocale));
        }
        await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'TAX_RATE', value: taxFraction.toString()));
      });
      await AppSettings.setLanguage(_selectedLanguage);
      language.state = _selectedLanguage;
      _log.info('Settings saved: currency=$_selectedCurrency, locale=$_selectedLocale, lang=$_selectedLanguage, tax=$taxFraction');
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      _log.warning('Saving settings failed', e, st);
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    if (!_loaded) {
      final baseCurrency = ref.watch(baseCurrencyProvider).value;
      final locale = ref.watch(appLocaleProvider).value;
      final taxRate = ref.watch(defaultTaxRateProvider).value;
      if (baseCurrency != null && locale != null && taxRate != null) _load(baseCurrency: baseCurrency, locale: locale, taxRate: taxRate);
    }
    final actions = [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
      FilledButton(
        onPressed: !_loaded || _saving ? null : _save,
        child: Text(s.save),
      ),
    ];
    if (!_loaded) {
      return AlertDialog(
        title: Text(s.settingsTitle),
        content: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: actions,
      );
    }
    return AlertDialog(
      title: Text(s.settingsTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: InputDecoration(labelText: s.settingsCurrency),
                items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocale,
                decoration: InputDecoration(labelText: s.settingsNumberFormat),
                items: [
                  DropdownMenuItem(value: '', child: Text(s.systemDefault)),
                  for (final (locale, label) in s.numberLocaleOptions) DropdownMenuItem(value: locale, child: Text(label)),
                ],
                onChanged: (v) => setState(() => _selectedLocale = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration: InputDecoration(labelText: s.settingsLanguage),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'it', child: Text('Italiano')),
                ],
                onChanged: (v) => setState(() => _selectedLanguage = v!),
              ),
              const SizedBox(height: 12),
              Form(
                key: _taxFormKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: TextFormField(
                  controller: _taxRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.settingsDefaultTaxRate,
                    helperText: s.settingsDefaultTaxRateHelp,
                    suffixText: '%',
                  ),
                  validator: (v) {
                    // Read strictly in the field's locale: under it_IT
                    // "12.5" is no number and "1.000" is a thousand.
                    final n = fmt.readOptionalNumber(v ?? '', locale: _taxLocale);
                    if (n.invalid) return s.invalidNumber;
                    final pct = n.value;
                    if (pct == null || pct < 0 || pct > 100) {
                      return s.settingsTaxRateInvalid;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.settingsClearCache, style: theme.textTheme.bodyMedium),
                        // Acknowledged in place: the snack bar confirming it
                        // waits until the dialog has closed.
                        Text(
                          _cacheCleared ? s.settingsCacheCleared : s.settingsClearCacheSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: _clearCache,
                    child: Text(s.settingsClearButton),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              Text(s.settingsGoogleDrive, style: theme.textTheme.titleSmall),
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
                          child: Text(s.settingsSyncSignedIn(sync.userEmail ?? ''), style: theme.textTheme.bodySmall),
                        ),
                        TextButton(
                          onPressed: () async {
                            await sync.signOut();
                            if (mounted) setState(() {});
                          },
                          child: Text(s.settingsSyncSignOut),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_outlined, size: 18),
                          label: Text(s.settingsSyncSignIn),
                          onPressed: () => _signIn(sync),
                        ),
                        if (_signInFailed) ...[
                          const SizedBox(height: 8),
                          Text(s.driveSignInFailed, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ],
                      ],
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
                        Text(s.settingsWipeDb, style: theme.textTheme.bodyMedium),
                        Text(
                          s.settingsWipeDbSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onWipe();
                    },
                    child: Text(s.settingsWipeButton),
                  ),
                ],
              ),
              if (_saveFailed) ...[
                const SizedBox(height: 16),
                Text(s.settingsSaveFailed, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }
}
