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

    final aiConfig = ref.read(aiConfigProvider).value;
    final aiKeyCtrl = TextEditingController(text: aiConfig?.apiKey ?? '');
    final aiModelCtrl = TextEditingController(text: aiConfig?.model ?? '');
    final aiRegionCtrl = TextEditingController(text: aiConfig?.region ?? '');
    final aiEndpointCtrl = TextEditingController(text: aiConfig?.endpoint ?? '');

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
                  Text(s.aiSettingsTitle, style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AiProvider>(
                    initialValue: AiProvider.bedrock,
                    decoration: InputDecoration(labelText: s.aiProvider),
                    items: const [
                      DropdownMenuItem(value: AiProvider.bedrock, child: Text('AWS Bedrock')),
                    ],
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: aiKeyCtrl,
                    obscureText: true,
                    decoration: InputDecoration(labelText: s.aiApiKey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: aiModelCtrl,
                    decoration: InputDecoration(labelText: s.aiModel, hintText: 'eu.anthropic.claude-sonnet-4-6'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: aiRegionCtrl,
                    decoration: InputDecoration(labelText: s.aiRegion, hintText: 'eu-central-1'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: aiEndpointCtrl,
                    decoration: InputDecoration(labelText: s.aiEndpoint, helperText: s.aiEndpointHelp),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.aiPrivacyNote,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bolt, size: 18),
                      label: Text(s.aiTest),
                      onPressed: () => _testAiConnection(
                        ctx,
                        s,
                        apiKey: aiKeyCtrl.text,
                        model: aiModelCtrl.text,
                        region: aiRegionCtrl.text,
                        endpoint: aiEndpointCtrl.text,
                      ),
                    ),
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
                // AI assistant provider config.
                for (final entry in <String, String>{
                  AiConfig.keyProvider: AiProvider.bedrock.name,
                  AiConfig.keyApiKey: aiKeyCtrl.text.trim(),
                  AiConfig.keyModel: aiModelCtrl.text.trim(),
                  AiConfig.keyRegion: aiRegionCtrl.text.trim(),
                  AiConfig.keyEndpoint: aiEndpointCtrl.text.trim(),
                }.entries) {
                  await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: entry.key, value: entry.value));
                }
                // Force the AI service to rebuild with the new config/connection.
                ref.invalidate(aiChatServiceProvider);
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

  /// Minimal connectivity check: builds a temporary agent from the in-dialog
  /// field values and sends a one-word prompt (no tools). Surfaces success or
  /// the provider error via a snackbar.
  Future<void> _testAiConnection(
    BuildContext ctx,
    AppStrings s, {
    required String apiKey,
    required String model,
    required String region,
    required String endpoint,
  }) async {
    final trimmedEndpoint = endpoint.trim();
    final config = AiConfig(
      provider: AiProvider.bedrock,
      apiKey: apiKey.trim(),
      model: model.trim(),
      region: region.trim(),
      endpoint: trimmedEndpoint.isEmpty ? null : trimmedEndpoint,
    );
    if (!config.isConfigured) {
      showInfoSnack(ctx, s.aiFillFields);
      return;
    }
    showInfoSnack(ctx, s.aiTesting);
    try {
      final agent = BedrockConverseAgent(config);
      final answer = await agent.run(
        'Reply with the single word OK.',
        systemPrompt: 'You are a connectivity test. Reply with the single word OK.',
        tools: const [],
      );
      if (ctx.mounted) {
        showInfoSnack(ctx, answer.text.trim().isNotEmpty ? s.aiTestOk : s.aiTestFailed('empty response'));
      }
    } catch (e) {
      if (ctx.mounted) showInfoSnack(ctx, s.aiTestFailed(e));
    }
  }
}
