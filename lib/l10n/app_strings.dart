import '../database/tables.dart';

/// Simple two-language (EN / IT) string table.
/// Access via [appStringsProvider] in Riverpod widgets.
class AppStrings {
  final bool _it;
  const AppStrings._({required bool italian}) : _it = italian;

  static const en = AppStrings._(italian: false);
  static const it = AppStrings._(italian: true);

  factory AppStrings.of(String langCode) {
    return langCode.startsWith('it') ? AppStrings.it : AppStrings.en;
  }

  // ── Common ──────────────────────────────────────────────
  String get cancel        => _it ? 'Annulla'          : 'Cancel';
  String get save          => _it ? 'Salva'            : 'Save';
  String get add           => _it ? 'Aggiungi'         : 'Add';
  String get edit          => _it ? 'Modifica'         : 'Edit';
  String get delete        => _it ? 'Elimina'          : 'Delete';
  String get create        => _it ? 'Crea'             : 'Create';
  String get update        => _it ? 'Aggiorna'         : 'Update';
  String get back          => _it ? 'Indietro'         : 'Back';
  String get search        => _it ? 'Cerca'            : 'Search';
  String get name          => _it ? 'Nome'             : 'Name';
  String get amount        => _it ? 'Importo'          : 'Amount';
  String get description   => _it ? 'Descrizione'      : 'Description';
  String get currency      => _it ? 'Valuta'           : 'Currency';
  String get date          => _it ? 'Data'             : 'Date';
  String get notes         => _it ? 'Note'             : 'Notes';
  String get active        => _it ? 'Attivo'           : 'Active';
  String get inactive      => _it ? 'Inattivo'         : 'Inactive';
  String get optional      => _it ? 'Opzionale'        : 'Optional';
  String get none          => _it ? 'Nessuno'          : 'None';
  String get wipe          => _it ? 'Cancella tutto'   : 'Wipe';
  String get preview       => _it ? 'Anteprima'        : 'Preview';
  String get next          => _it ? 'Avanti'           : 'Next';
  String get required      => _it ? 'Obbligatorio'     : 'Required';
  String get notMapped     => _it ? 'Non mappato'      : 'Not mapped';
  String get cannotBeUndone => _it
      ? 'Questa operazione non può essere annullata.'
      : 'This cannot be undone.';
  String error(Object e)   => 'Error: $e';
  String get invalid       => _it ? 'Non valido'          : 'Invalid';
  String get invalidNumber => _it ? 'Numero non valido'   : 'Invalid number';

  // ── App shell / navigation ──────────────────────────────
  String get navDashboard          => 'Dashboard';
  String get navAccounts           => _it ? 'Conti'             : 'Accounts';
  String get navAssets             => _it ? 'Portafoglio'       : 'Assets';
  String get navAdjustments        => _it ? 'Aggiustamenti'     : 'Adjustments';
  String get navIncome             => _it ? 'Entrate'           : 'Income';
  String get tooltipHideAmounts    => _it ? 'Nascondi importi'  : 'Hide amounts';
  String get tooltipShowAmounts    => _it ? 'Mostra importi'    : 'Show amounts';
  String get tooltipRefreshPrices  => _it ? 'Aggiorna prezzi di mercato' : 'Refresh Market Prices';
  String get tooltipSettings       => _it ? 'Impostazioni'      : 'Settings';
  String get tooltipImportFile     => _it ? 'Importa file'      : 'Import File';

  // ── Settings ────────────────────────────────────────────
  String get settingsTitle              => _it ? 'Impostazioni'               : 'Settings';
  String get settingsCurrency           => _it ? 'Valuta predefinita'         : 'Default Currency';
  String get settingsNumberFormat       => _it ? 'Formato numeri/date'        : 'Number/Date Format';
  String get settingsLanguage           => _it ? 'Lingua interfaccia'         : 'Interface Language';
  String get settingsClearCache         => _it ? 'Cancella dati in cache'     : 'Clear cached data';
  String get settingsClearCacheSubtitle => _it ? 'Prezzi, tassi di cambio, composizione' : 'Prices, exchange rates, composition';
  String get settingsClearButton        => _it ? 'Cancella'                   : 'Clear';
  String get settingsCacheCleared       => _it ? 'Dati in cache cancellati'   : 'Cached data cleared';
  String get settingsExportDb          => _it ? 'Esporta DB'                : 'Export DB';
  String get settingsImportDb          => _it ? 'Importa DB'                : 'Import DB';
  String get settingsExportSuccess     => _it ? 'Database esportato'        : 'Database exported';
  String get settingsImportSuccess     => _it ? 'Database importato'        : 'Database imported';
  String get settingsImportWarningTitle => _it ? 'Sostituire il database?'  : 'Replace database?';
  String get settingsImportWarningBody => _it ? 'Tutti i dati attuali verranno sostituiti. Vuoi esportare prima?' : 'All current data will be replaced. Export first?';
  String get settingsExportFirst       => _it ? 'Esporta prima'             : 'Export First';
  String get settingsReplaceAnyway     => _it ? 'Sostituisci'               : 'Replace';

  // ── Import/Export DB ──────────────────────────────────────
  String get tooltipImportExportDb    => _it ? 'Importa/Esporta Database'   : 'Import/Export Database';
  String get importExportTitle        => _it ? 'Importa / Esporta Database' : 'Import / Export Database';
  String get importExportExportHint   => _it ? 'Salva una copia del database' : 'Save a copy of your database';
  String get importExportImportHint   => _it ? 'Sostituisci con un file esterno' : 'Replace with an external file';
  String get importExportBackupDrive       => _it ? 'Backup su Google Drive'      : 'Backup to Google Drive';
  String get importExportBackupDriveHint   => _it ? 'Carica il database corrente su Drive (sovrascrive il backup precedente)' : 'Upload current database to Drive (overwrites previous backup)';
  String get importExportRestoreDrive      => _it ? 'Ripristina da Google Drive' : 'Restore from Google Drive';
  String get importExportRestoreDriveHint  => _it ? 'Sostituisci il database locale con il backup di Drive' : 'Replace local database with the Drive backup';
  String get importExportSignInFirst       => _it ? 'Accedi a Google Drive nelle Impostazioni per usare backup/restore' : 'Sign in to Google Drive in Settings to use backup/restore';
  String get importExportBackupConfirmTitle => _it ? 'Backup su Google Drive?' : 'Backup to Google Drive?';
  String importExportBackupConfirmBody(String? remoteInfo) {
    final base = _it ? 'Il backup attuale su Drive verra sostituito.' : 'The current Drive backup will be overwritten.';
    if (remoteInfo == null) return base + (_it ? '\nNessun backup esistente.' : '\nNo existing backup.');
    return '$base\n${_it ? 'Backup esistente' : 'Existing backup'}: $remoteInfo';
  }
  String get importExportBackupSuccess     => _it ? 'Backup completato'         : 'Backup complete';
  String get importExportBackupFailed      => _it ? 'Backup fallito'            : 'Backup failed';
  String get importExportRestoreConfirmTitle => _it ? 'Ripristinare da Google Drive?' : 'Restore from Google Drive?';
  String importExportRestoreConfirmBody(String? remoteInfo) {
    final base = _it ? 'Il database locale verra sostituito con il backup di Drive.' : 'Your local database will be replaced by the Drive backup.';
    if (remoteInfo == null) return base + (_it ? '\nNessun backup trovato su Drive.' : '\nNo backup found on Drive.');
    return '$base\n${_it ? 'Backup' : 'Backup'}: $remoteInfo';
  }
  String get importExportRestoreSuccess    => _it ? 'Database ripristinato da Drive' : 'Database restored from Drive';
  String get importExportRestoreFailed     => _it ? 'Ripristino fallito'        : 'Restore failed';
  String get importExportRestoreEmpty      => _it ? 'Nessun backup trovato su Drive' : 'No backup found on Drive';
  String importExportRemoteInfo(String size, String date, String? device) {
    final dev = device != null ? ', $device' : '';
    return '$size, $date$dev';
  }

  // ── Landing page ──────────────────────────────────────────
  String get landingTitle             => _it ? 'Benvenuto in FinanceCopilot' : 'Welcome to FinanceCopilot';
  String get landingSubtitle          => _it ? 'Il tuo database e vuoto. Come vuoi iniziare?' : 'Your database is empty. How would you like to start?';
  String get landingImportDb          => _it ? 'Importa Database Esistente' : 'Import Existing Database';
  String get landingStartFresh        => _it ? 'Inizia da zero'             : 'Start Fresh';
  String get landingSyncDrive         => _it ? 'Sincronizza con Google Drive' : 'Sync with Google Drive';
  String get landingSyncProgress      => _it ? 'Sincronizzazione in corso...'  : 'Syncing your data...';

  // ── Wipe DB ──────────────────────────────────────────
  String get settingsWipeDb           => _it ? 'Cancella database'          : 'Wipe Database';
  String get settingsWipeDbSubtitle   => _it ? 'Esporta e cancella tutti i dati. Irreversibile.' : 'Export and delete all data. This cannot be undone.';
  String get settingsWipeButton       => _it ? 'Esporta e cancella'         : 'Export & Wipe';
  String get settingsWipeCancelled    => _it ? 'Esporta prima annullato -- database non cancellato' : 'Export cancelled -- database not wiped';
  String get settingsWipeConfirmTitle => _it ? 'Sei sicuro?'                : 'Are you sure?';
  String get settingsWipeConfirmBody  => _it ? 'Il database e stato esportato. Tutti i dati verranno eliminati definitivamente.' : 'Your database has been exported. All data will be permanently deleted.';
  String get settingsWipeConfirm      => _it ? 'Cancella definitivamente'   : 'Delete Permanently';

  // ── Google Drive Sync ──────────────────────────────────
  String get settingsGoogleDrive      => _it ? 'Google Drive Sync'           : 'Google Drive Sync';
  String get settingsSyncSignIn       => _it ? 'Accedi con Google'           : 'Sign in with Google';
  String get settingsSyncSignOut      => _it ? 'Esci'                        : 'Sign out';
  String settingsSyncSignedIn(String email) => _it ? 'Sincronizzato con $email' : 'Synced with $email';
  String get syncReauthNeeded          => _it ? 'Accedi di nuovo a Google Drive per continuare la sincronizzazione' : 'Please sign in to Google Drive again to continue syncing';

  // ── Sync Conflict ──────────────────────────────────

  // ── Dashboard ───────────────────────────────────────────
  String get dashTabHistory      => _it ? 'Storico'           : 'History';
  String get dashTabCashFlow     => _it ? 'Flussi di cassa'  : 'Cash Flow';
  String get dashTabAssetsOverview => _it ? 'Panoramica Asset' : 'Assets Overview';
  String get dashTabHealth       => _it ? 'Salute'            : 'Health';

  // ── Financial Health ──
  String get healthInvestmentCosts => _it ? 'Costi degli investimenti' : 'Investment Costs';
  String get healthAsset           => _it ? 'Strumento'               : 'Asset';
  String get healthTer             => 'TER';
  String get healthMarketValue     => _it ? 'Valore'                  : 'Value';
  String get healthAnnualCost      => _it ? 'Costo annuo'             : 'Annual Cost';
  String get healthNoTer           => _it ? 'Nessun TER disponibile'  : 'No TER data available';
  String get healthWeightedTer     => _it ? 'TER medio ponderato'     : 'Weighted Avg TER';

  // ── Health KPIs ──
  String get healthSummary         => _it ? 'Riepilogo'               : 'Summary';
  String get healthKpis            => _it ? 'Indicatori ed Indici'    : 'KPIs & Indices';
  String get healthPerformance     => _it ? 'Performance e Diversificazione' : 'Performance & Diversification';
  String get kpiToday              => _it ? 'Oggi'                   : 'Today';
  String get kpiYtd                => _it ? 'Da inizio anno'         : 'YTD';
  String get kpiAllTime            => _it ? 'Dall\'inizio'           : 'All Time';
  String get healthDetails         => _it ? 'Dettagli'                : 'Details';

  // Ratings
  String get ratingOttimo          => _it ? 'Ottimo'                  : 'Excellent';
  String get ratingBuono           => _it ? 'Buono'                   : 'Good';
  String get ratingSufficiente     => _it ? 'Sufficiente'             : 'Fair';
  String get ratingScarso          => _it ? 'Scarso'                  : 'Poor';
  String get ratingAlto            => _it ? 'Alto'                    : 'High';
  String get ratingNa              => _it ? 'N/D'                     : 'N/A';

  // Category headers
  String get healthCatLiquidity    => _it ? 'Liquidità'               : 'Liquidity';
  String get healthCatWealth       => _it ? 'Finanziari e Ricchezza'  : 'Financial & Wealth';

  // KPI names
  String get kpiLiquidityRatio     => _it ? 'Indice di liquidità patrimoniale' : 'Net Worth Liquidity Ratio';
  String get kpiExpenseCoverage    => _it ? 'Indice di copertura delle spese'  : 'Expense Coverage';
  String get kpiSavingsRate        => _it ? 'Tasso di risparmio'               : 'Savings Rate';
  String get kpiInvestmentWeight   => _it ? 'Peso del capitale investito'      : 'Investment Weight';
  String get kpiLiquidAssetRatio   => _it ? 'Indice di liquidabilità patrimoniale' : 'Liquid Asset Ratio';
  String get kpiIncomeToWealth     => _it ? 'Tasso disproporzione entrate/patrimonio' : 'Income-to-Wealth Ratio';

  // KPI descriptions by rating
  String kpiLiquidityDesc(String rating) => _it
      ? (rating == 'ottimo' ? 'Ottima liquidità! Hai un buon cuscinetto per le emergenze.'
        : rating == 'buono' ? 'Buona liquidità, sei in una posizione solida.'
        : rating == 'sufficiente' ? 'La tua liquidità è sufficiente, ma fai attenzione a spese impreviste.'
        : 'Liquidità bassa. Valuta di aumentare le riserve di emergenza.')
      : (rating == 'ottimo' ? 'Excellent liquidity! You have a good emergency cushion.'
        : rating == 'buono' ? 'Good liquidity, you are in a solid position.'
        : rating == 'sufficiente' ? 'Liquidity is fair, but watch out for unexpected expenses.'
        : 'Low liquidity. Consider building up emergency reserves.');
  String kpiCoverageDesc(int months) => _it
      ? 'La tua liquidità copre le tue spese per $months mesi.'
      : 'Your cash covers your expenses for $months months.';
  String kpiSavingsDesc(String rating) => _it
      ? (rating == 'ottimo' ? 'Sei in un\'ottima situazione! Puoi dedicarti ad altri aspetti della tua vita finanziaria.'
        : rating == 'buono' ? 'Buon tasso di risparmio, continua così!'
        : rating == 'sufficiente' ? 'Tasso di risparmio nella media, cerca di migliorarlo.'
        : 'Tasso di risparmio basso. Cerca di ridurre le spese non essenziali.')
      : (rating == 'ottimo' ? 'Excellent! You can focus on other aspects of your financial life.'
        : rating == 'buono' ? 'Good savings rate, keep it up!'
        : rating == 'sufficiente' ? 'Average savings rate, try to improve it.'
        : 'Low savings rate. Try reducing non-essential expenses.');
  String kpiInvestWeightDesc(String rating) => _it
      ? 'I tuoi investimenti finanziari hanno il giusto spazio nel tuo patrimonio complessivo.'
      : 'Your financial investments have the right weight in your overall wealth.';
  String kpiLiquidAssetDesc(String rating) => _it
      ? (rating == 'ottimo' || rating == 'buono'
        ? 'Gran parte del tuo patrimonio è liquidabile in breve tempo: le spese impreviste non sono un problema.'
        : 'Una parte significativa del tuo patrimonio non è facilmente liquidabile.')
      : (rating == 'ottimo' || rating == 'buono'
        ? 'Most of your wealth is quickly convertible to cash: unexpected expenses are manageable.'
        : 'A significant portion of your wealth is not easily convertible to cash.');
  String kpiIncomeWealthDesc(String rating) => _it
      ? (rating == 'ottimo' || rating == 'buono'
        ? 'Le tue entrate sono proporzionate al tuo patrimonio.'
        : 'Le tue entrate sono troppo basse rispetto al tuo patrimonio. Fai attenzione ai tuoi investimenti.')
      : (rating == 'ottimo' || rating == 'buono'
        ? 'Your income is proportional to your wealth.'
        : 'Your income is too low relative to your wealth. Pay attention to your investments.');
  String get dashNoData          => _it
      ? 'Nessun dato. Importa transazioni o aggiungi attività per iniziare.'
      : 'No data yet. Import transactions or add assets to get started.';
  String get dashNotEnoughData   => _it ? 'Dati insufficienti per il grafico' : 'Not enough data to plot';
  String get dashAssets          => _it ? 'Attività'           : 'Assets';
  String get dashPriceChanges    => _it ? 'Variazioni prezzo'  : 'Price Changes';
  String get dashNoPriceData     => _it ? 'Nessun dato di prezzo disponibile' : 'No price data available';
  String get dashTotals          => _it ? 'Totali'             : 'Totals';
  String get dashCash            => _it ? 'Liquidità'          : 'Cash';
  String get dashSaving          => _it ? 'Risparmi'           : 'Saving';
  String get dashPortfolio       => _it ? 'Portafoglio'        : 'Portfolio';
  String get dashLiquidInvestments => _it ? 'Investimenti liquidi' : 'Liquid Investments';
  // ── Chart editor (configurable History-tab charts) ──
  String get chartNewTitle         => _it ? 'Nuovo grafico'         : 'New Chart';
  String get moveUp                => _it ? 'Sposta su'              : 'Move up';
  String get moveDown              => _it ? 'Sposta giù'             : 'Move down';
  String get chartNewCustom        => _it ? 'Grafico personalizzato…' : 'Custom chart…';
  String chartRestoreRole(String name) => _it ? 'Ripristina $name' : 'Restore $name';
  String get chartEditTitle        => _it ? 'Modifica grafico'      : 'Edit Chart';
  String get chartTitleLabel       => _it ? 'Titolo grafico'        : 'Chart title';
  String get chartSectionAccounts  => _it ? 'Conti'                 : 'Accounts';
  String get chartSectionAssets    => _it ? 'Attività'              : 'Assets';
  String get chartSectionOutflowAdj => _it ? 'Aggiustamenti in uscita' : 'Outflow Adjustments';
  String get chartSectionInflowAdj  => _it ? 'Aggiustamenti in entrata': 'Inflow Adjustments';
  String get chartSectionEphemeralAdj => _it ? 'Aggiustamenti effimeri' : 'Ephemeral Adjustments';
  String get chartAssetInvested    => _it ? 'Investito'             : 'Invested';
  String get chartAssetMarket      => _it ? 'Mercato'               : 'Market';
  String get chartAssetGain        => _it ? 'Guadagno'              : 'Gain';
  String get chartAdjValue         => _it ? 'Valore'                : 'Value';
  String get chartAdjEvents        => _it ? 'Eventi'                : 'Events';
  String get chartSelectAll        => _it ? 'Seleziona tutto'       : 'Select All';
  String get chartDeselectAll      => _it ? 'Deseleziona tutto'     : 'Deselect All';
  String get chartCombineNewTitle  => _it ? 'Combina grafici'       : 'Combine Charts';
  String get chartCombineEditTitle => _it ? 'Modifica combinazione' : 'Edit Combined Chart';
  String get chartCombineTitleLabel=> _it ? 'Titolo combinazione'   : 'Combined chart title';
  String get chartCombinePickHint  => _it ? 'Seleziona 2+ grafici:' : 'Select charts to combine (2+):';
  String get chartCombineAutoAll     => _it ? 'Includi automaticamente tutti i grafici' : 'Auto-include all charts';
  String get chartCombineAutoAllHint => _it
      ? 'La combinazione si aggiorna quando aggiungi o rimuovi grafici.'
      : 'The overlay updates as you add or remove charts.';
  String get chartDeleteTitle      => _it ? 'Elimina grafico?'      : 'Delete Chart?';
  String chartDeleteConfirm(String t) => _it ? 'Eliminare "$t"?' : 'Delete "$t"?';
  String get chartResetDefaults      => _it ? 'Ripristina predefiniti' : 'Reset to Defaults';
  String get chartResetConfirmTitle  => _it ? 'Ripristinare i grafici predefiniti?' : 'Reset charts to defaults?';
  String get chartResetConfirmBody   => _it
      ? 'Tutti i grafici attuali saranno cancellati e sostituiti dai predefiniti.'
      : 'All current charts will be deleted and replaced with the defaults.';
  String get chartExportTitle        => _it ? 'Esporta configurazione' : 'Export config';
  String get chartExportInstructions => _it
      ? 'Copiato negli appunti. Per renderlo il nuovo predefinito per tutti gli utenti:\n1. Apri assets/default_charts.json nell\'editor.\n2. Sostituisci il contenuto con quello degli appunti.\n3. flutter pub get && flutter build …\n4. Esegui il commit della modifica.'
      : 'Copied to clipboard. To make this the new default for every user:\n1. Open assets/default_charts.json in your editor.\n2. Replace its contents with the clipboard.\n3. flutter pub get && flutter build …\n4. Commit the asset change.';
  String get chartExportPartialTitle => _it ? 'Esportazione non possibile' : 'Cannot export';
  String chartExportPartialBody(String reason) => _it
      ? 'Almeno un grafico ha una selezione parziale di una categoria, quindi non può essere espresso senza id specifici. Modifica i grafici in modo che ogni sezione sia tutta selezionata o tutta deselezionata.\n\n$reason'
      : 'At least one chart has a partial category selection so it cannot be expressed without specific ids. Edit the charts so every section is fully selected or fully cleared.\n\n$reason';
  String get cfVelocity          => _it ? 'Velocità'           : 'Velocity';
  String get colTotal            => _it ? 'Totale'             : 'Total';
  String get colAvg              => _it ? 'Media'              : 'Avg';
  String get legendAccounts      => _it ? 'Conti'              : 'Accounts';
  String get legendSpreadAdj     => _it ? 'Agg. dilaz.'        : 'Spread Adj.';
  String get legendIncomeAdj     => _it ? 'Agg. reddito'       : 'Income Adj.';
  String get legendTotal         => _it ? 'Totale'             : 'Total';
  String get showComponents      => _it ? 'Mostra componenti'  : 'Show components';
  String get hideComponents      => _it ? 'Nascondi componenti': 'Hide components';
  String get resetZoom           => 'Reset zoom';
  String get colAsset            => _it ? 'Attività'           : 'Asset';
  String get colPrice            => _it ? 'Prezzo'             : 'Price';

  // ── Dashboard cash-flow chart titles ────────────────────
  String get chartYearlyBarTitle          => _it ? 'Entrate / Uscite / Risparmio per Anno'   : 'Income / Expenses / Savings per Year';
  String get chartMonthlyAvgTitle         => _it ? 'Medie Mensili per Anno'                  : 'Monthly Averages per Year';
  String get chartMonthlyIncomeTitle      => _it ? 'Entrate per Mese (per Anno)'              : 'Income by Month (per Year)';
  String get chartMonthlyExpensesTitle    => _it ? 'Uscite per Mese (per Anno)'               : 'Expenses by Month (per Year)';
  String get chartYearlySummaryTitle      => _it ? 'Riepilogo Annuale'                        : 'Yearly Summary';
  String get chartMonthlyIncTableTitle    => _it ? 'Entrate Mensili per Anno (tabella)'       : 'Monthly Income by Year (table)';
  String get chartMonthlyExpTableTitle    => _it ? 'Uscite Mensili per Anno (tabella)'        : 'Monthly Expenses by Year (table)';
  String get chartYoYTitle                => _it ? 'Variazione YoY Entrate'                   : 'YoY Income Changes';
  String get allSeriesHidden              => _it ? 'Tutte le serie nascoste'                   : 'All series hidden';

  // ── Dashboard table column headers ───────────────────────
  String get colYear          => _it ? 'Anno'           : 'Year';
  String get colIncome        => _it ? 'Entrate'        : 'Income';
  String get colExpenses      => _it ? 'Uscite'         : 'Expenses';
  String get colSavings       => _it ? 'Risparmi'       : 'Savings';
  String get colRate          => 'Rate%';
  String get colAvgMonthInc   => _it ? 'Media/Mese Ent.' : 'Avg/Mo Inc';
  String get colAvgMonthExp   => _it ? 'Media/Mese Usc.' : 'Avg/Mo Exp';
  String get colDailyInc      => _it ? 'Giorn. Ent.'   : 'Daily Inc';
  String get colDailyExp      => _it ? 'Giorn. Usc.'   : 'Daily Exp';
  String get colMonth         => _it ? 'Mese'           : 'Month';
  String get eoyLabel         => _it ? '  Pre. anno~'   : '  EOY~';
  String get eoyFormula       => _it
      ? 'Formula: totale anno prec. × progresso anno corr. ÷ stesso periodo anno prec.'
      : 'Formula: prev year total × current year progress ÷ prev year same period';
  String get needMoreYears    => _it ? 'Necessari almeno 2 anni di dati.' : 'Need at least 2 years of data.';

  // ── Dashboard chart legend/tooltip labels ────────────────
  String get legendIncome              => _it ? 'Entrate'              : 'Income';
  String get legendExpenses            => _it ? 'Uscite'               : 'Expenses';
  String get legendSavings             => _it ? 'Risparmi'             : 'Savings';
  String get legendAvgMonthlyIncome    => _it ? 'Media Mensile Entrate': 'Avg Monthly Income';
  String get legendAvgMonthlyExpenses  => _it ? 'Media Mensile Uscite' : 'Avg Monthly Expenses';
  String get legendAvgMonthlySavings   => _it ? 'Media Mensile Risparmi':'Avg Monthly Savings';
  String get tipAvgMonthIncome         => _it ? 'Media/Mese Entrate'   : 'Avg/Mo Income';
  String get tipAvgMonthExpenses       => _it ? 'Media/Mese Uscite'    : 'Avg/Mo Expenses';
  String get tipAvgMonthSavings        => _it ? 'Media/Mese Risparmi'  : 'Avg/Mo Savings';

  // ── Accounts ────────────────────────────────────────────
  String get noAccountsYet    => _it
      ? 'Nessun conto.\nImporta un file per iniziare.'
      : 'No accounts yet.\nImport a file to get started.';
  String get newAccountTitle   => _it ? 'Nuovo conto'     : 'New Account';
  String get accountNameHint   => _it ? 'es. Fineco'      : 'e.g. Fineco';
  String get noTransactionsYet => _it ? 'Nessuna transazione' : 'No transactions yet';
  String get transactions      => _it ? 'transazioni'     : 'transactions';
  String since(String d)       => _it ? 'Dal $d'          : 'Since $d';
  String lastRecord(String d)  => _it ? 'Ultimo record $d': 'Last record $d';

  // ── Account Detail ───────────────────────────────────────
  String get tooltipRecalcBalance     => _it ? 'Ricalcola saldo'            : 'Recalculate Balance';
  String get tooltipAddTransaction    => _it ? 'Aggiungi transazione'       : 'Add Transaction';
  String get tooltipEditAccount       => _it ? 'Modifica conto'             : 'Edit Account';
  String get tooltipWipeTransactions  => _it ? 'Cancella transazioni'       : 'Wipe Transactions';
  String get tooltipDeleteAccount     => _it ? 'Elimina conto'              : 'Delete Account';
  String get searchTransactions       => _it ? 'Cerca transazioni...'       : 'Search transactions...';
  String get noTransactionsToWipe     => _it ? 'Nessuna transazione da cancellare.' : 'No transactions to wipe.';
  String get wipeAllTransactionsTitle => _it ? 'Cancellare tutte le transazioni?' : 'Wipe All Transactions?';
  String wipedTransactions(int n)     => _it
      ? 'Cancellate $n transazioni. Config. importazione preservata.'
      : 'Wiped $n transactions. Import config preserved.';
  String get deleteAccountTitle       => _it ? 'Elimina conto?'             : 'Delete Account?';
  String deleteAccountConfirm(String n) => _it
      ? 'Eliminare "$n" e tutte le transazioni?'
      : 'Delete "$n" and all transactions?';
  String get editAccountTitle         => _it ? 'Modifica conto'             : 'Edit Account';
  String get institution              => _it ? 'Istituto'                   : 'Institution';
  String get noTransactionsToRecalc   => _it ? 'Nessuna transazione da ricalcolare.' : 'No transactions to recalculate.';
  String get recalcBalanceTitle       => _it ? 'Ricalcola saldo'            : 'Recalculate Balance';
  String get recalcBalanceHelp        => _it
      ? 'Scegli come calcolare il saldo per ogni transazione.'
      : 'Choose how to compute balanceAfter for each transaction.';
  String get recalcColumn             => _it ? 'Colonna'            : 'Column';
  String get recalcCumulative         => _it ? 'Somma cumulativa'   : 'Cumulative sum';
  String get recalcFiltered           => _it ? 'Somma filtrata'     : 'Filtered sum';
  String get noTransactionsImport    => _it
      ? 'Nessuna transazione.\nImporta un file per aggiungere transazioni.'
      : 'No transactions yet.\nImport a file to add transactions.';
  String get noMatchingTransactions  => _it ? 'Nessuna transazione corrispondente.' : 'No matching transactions.';
  String get noDescription           => _it ? '(nessuna descrizione)'  : '(no description)';
  String get balance                 => _it ? 'Saldo'                  : 'Balance';
  String get records                 => _it ? 'record'                 : 'records';
  String get balanceFromColumnHelp   => _it
      ? 'Il saldo viene dalla colonna CSV importata (impostato durante l\'importazione)'
      : 'Balance is read from the imported CSV column (set during import)';
  String get balanceCumulativeHelp   => _it
      ? 'Saldo = somma progressiva degli importi dal più vecchio al più nuovo'
      : 'Balance = running sum of amount from oldest to newest';
  String get filterColumnLabel       => _it ? 'Colonna filtro:'        : 'Filter column:';
  String get includeValues           => _it ? 'Includi valori:'        : 'Include values:';
  String get all                     => _it ? 'Tutti'                  : 'All';
  String get recalculate             => _it ? 'Ricalcola'              : 'Recalculate';
  String recalculatedBalances(int n) => _it ? 'Ricalcolati $n saldi.'  : 'Recalculated $n balances.';
  String wipeTransactionsBody(String name) => _it
      ? 'Verranno eliminate tutte le transazioni da "$name" ma il conto e la configurazione importazione (mappature colonne, chiavi dedup, impostazioni saldo) verranno mantenuti.\n\n'
      : 'This will delete all transactions from "$name" but keep the account and its import configuration (column mappings, dedup keys, balance settings).\n\n';

  // ── Assets ──────────────────────────────────────────────
  String get noAssetsYet        => _it
      ? 'Nessuna attività.\nImporta eventi attività per iniziare.'
      : 'No assets yet.\nImport asset events to get started.';
  String get newAssetTitle       => _it ? 'Nuova attività'                   : 'New Asset';
  String get searchAssetsHint    => _it ? 'Nome, ISIN, ticker o ID fondo'    : 'Name, ISIN, ticker, or fund ID';
  String get noResultsFound      => _it ? 'Nessun risultato trovato'          : 'No results found';
  String get typeAtLeast3Chars   => _it ? 'Inserisci almeno 3 caratteri'      : 'Type at least 3 characters';
  String get enterManually       => _it ? 'Inserisci manualmente'             : 'Enter manually';

  // ── Instrument-not-found recovery (URL paste) ─────────────────────────
  // The literal "<query> investing.com" appears in instrumentNotFoundExplanation
  // because that is the literal search query the user must type into a search
  // engine — not a brand mention. The surrounding text refers to the source
  // generically as "il fornitore di dati di mercato" / "the market data
  // provider".
  String get instrumentNotFoundHeadline => _it
      ? 'Strumento non trovato'
      : 'Instrument not found';
  String instrumentNotFoundExplanation(String query) {
    final q = query.trim().isEmpty ? (_it ? 'lo strumento' : 'the instrument') : query.trim();
    return _it
        ? 'Cerca su Google, Bing o un altro motore di ricerca il termine "$q investing.com", apri il primo risultato sul sito del fornitore di dati di mercato e copia l\'indirizzo della pagina. Incollalo qui sotto.'
        : 'Search Google, Bing or another search engine for "$q investing.com", open the first result on the market data provider\'s site and copy the page address. Paste it below.';
  }
  String get pasteInstrumentUrlLabel => _it ? 'Indirizzo della pagina' : 'Page address';
  String get pasteUrlShort           => _it ? 'Incolla URL'             : 'Paste URL';
  String get verifyButton            => _it ? 'Verifica'                : 'Verify';
  String get urlInvalidFormat        => _it
      ? 'Indirizzo non valido. Deve iniziare con http:// o https://.'
      : 'Invalid address. It must start with http:// or https://.';
  String get urlWrongHost            => _it
      ? 'L\'indirizzo non proviene dal fornitore di dati di mercato supportato.'
      : 'The address is not from the supported market data provider.';
  String get urlUnsupportedCategory  => _it
      ? 'Categoria di strumento non supportata. Prova con un\'azione, ETF, fondo o obbligazione.'
      : 'Unsupported instrument category. Try a stock, ETF, fund or bond.';
  String get urlFetchFailed          => _it
      ? 'Impossibile raggiungere la pagina. Verifica la connessione e riprova.'
      : 'Could not reach the page. Check your connection and try again.';
  String get urlParseFailed          => _it
      ? 'Pagina trovata ma impossibile leggere i dati dello strumento. Controlla che l\'indirizzo punti alla scheda dello strumento.'
      : 'Page found but instrument data could not be read. Make sure the address points to the instrument page.';

  String get createAssetTitle    => _it ? 'Crea attività'                     : 'Create Asset';
  String symbolLabel(String s)   => 'Symbol: $s';
  String typeLabel(String t)     => _it ? 'Tipo: $t'                          : 'Type: $t';
  String get stockExchange       => _it ? 'Borsa valori'                      : 'Stock Exchange';
  String get newAssetManualTitle => _it ? 'Nuova attività (manuale)'           : 'New Asset (Manual)';
  String get isinLabel           => _it ? 'Identificatore (ISIN, ID fondo, ecc.)' : 'Identifier (ISIN, fund ID, etc.)';
  String get noEventsYetShort    => _it ? 'Nessun evento'            : 'No events yet';
  String nEvents(int n)          => _it ? '$n eventi'                : '$n events';
  String sinceDate(String d)     => _it ? 'Dal $d'                   : 'Since $d';
  String lastDate(String d)      => _it ? 'Ultimo $d'                : 'Last $d';

  // ── Asset Detail ─────────────────────────────────────────
  String get tooltipEditAsset    => _it ? 'Modifica attività'  : 'Edit Asset';
  String get tooltipWipeEvents   => _it ? 'Cancella eventi'    : 'Wipe Events';
  String get tooltipDeleteAsset  => _it ? 'Elimina attività'   : 'Delete Asset';
  String get eventsLabel         => _it ? 'Eventi'             : 'Events';
  String get noEventsYet         => _it
      ? 'Nessun evento.\nImporta o aggiungi eventi manualmente.'
      : 'No events yet.\nImport or add events manually.';
  String get noEventsToWipe      => _it ? 'Nessun evento da cancellare.'  : 'No events to wipe.';
  String get wipeAllEventsTitle  => _it ? 'Cancellare tutti gli eventi?'  : 'Wipe All Events?';
  String wipedEvents(int n)      => _it ? 'Cancellati $n eventi.'         : 'Wiped $n events.';
  String get deleteAssetTitle    => _it ? 'Elimina attività?'             : 'Delete Asset?';
  String deleteAssetConfirm(String n) => _it
      ? 'Eliminare "$n" e tutti i suoi eventi?\nQuesta operazione non può essere annullata.'
      : 'Delete "$n" and all its events?\nThis cannot be undone.';
  String get composition         => _it ? 'Composizione'       : 'Composition';
  String get searchAssetTitle    => _it ? 'Cerca attività'     : 'Search Asset';
  String get editAssetTitle      => _it ? 'Modifica attività'  : 'Edit Asset';
  String get tickerLabel         => 'Ticker';
  String get tickerHint          => _it ? 'es. SWDA'           : 'e.g. SWDA';
  String isinPrefix(String isin) => 'ISIN: $isin';
  String taxRateLabel(String rate) => _it ? 'Aliquota: $rate%'   : 'Tax rate: $rate%';
  String get compositionAssetClass  => _it ? 'Classe attività'   : 'Asset Class';
  String get compositionGeographic  => _it ? 'Geografica'        : 'Geographic';
  String get compositionSector      => _it ? 'Settore'           : 'Sector';
  String get compositionTopHoldings => _it ? 'Posizioni principali' : 'Top Holdings';
  String sourceLabel(String src)    => _it ? 'Fonte: $src'       : 'Source: $src';
  String wipeEventsBody(int n, String name) => _it
      ? 'Verranno eliminati tutti i $n eventi da "$name" ma l\'attività verrà mantenuta.\n\n'
      : 'This will delete all $n events from "$name" but keep the asset itself.\n\n';

  // ── Asset Event Edit ─────────────────────────────────────
  String get editEventTitle      => _it ? 'Modifica evento'    : 'Edit Event';
  String get newEventTitle       => _it ? 'Nuovo evento'       : 'New Event';
  String get eventTypeLabel      => _it ? 'Tipo evento *'      : 'Event Type *';
  String get dateRequired        => _it ? 'Data *'             : 'Date *';
  String get quantityLabel       => _it ? 'Quantità *'         : 'Quantity *';
  String get commissionLabel     => _it ? 'Commissione'        : 'Commission';
  String get rawImportData       => _it ? 'Dati importazione grezzi' : 'Raw Import Data';
  String get saveChanges         => _it ? 'Salva modifiche'    : 'Save Changes';
  String get createEvent         => _it ? 'Crea evento'        : 'Create Event';
  String get deleteEventTitle    => _it ? 'Elimina evento?'    : 'Delete Event?';
  String rateLabel2(String base, String cur) => _it ? 'Tasso $base/$cur' : 'Rate $base/$cur';
  String get exchangeRate       => _it ? 'Tasso di cambio'    : 'Exchange Rate';
  String get rateHint           => _it ? 'es. 1.085000'       : 'e.g. 1.085000';
  String get notApplicable      => 'N/A';
  String priceLabel(String suffix)     => _it ? 'Prezzo$suffix *'        : 'Price$suffix *';
  String totalAutoLabel(String suffix) => _it ? 'Totale$suffix (auto)'   : 'Total$suffix (auto)';
  String amountLabel(String suffix)    => _it ? 'Importo$suffix *'       : 'Amount$suffix *';

  // ── Transaction Edit ─────────────────────────────────────
  String get editTransactionTitle   => _it ? 'Modifica transazione'  : 'Edit Transaction';
  String get newTransactionTitle    => _it ? 'Nuova transazione'      : 'New Transaction';
  String get fullDescription        => _it ? 'Descrizione completa'   : 'Full Description';
  String get balanceAfter           => _it ? 'Saldo successivo'       : 'Balance After';
  String get statusLabel            => _it ? 'Stato'                  : 'Status';
  String get createTransaction      => _it ? 'Crea transazione'       : 'Create Transaction';
  String get deleteTransactionTitle => _it ? 'Elimina transazione?'   : 'Delete Transaction?';

  // ── Capex / Adjustments ──────────────────────────────────

  // ── Capex Detail ─────────────────────────────────────────
  String get entriesRegenerated       => _it ? 'Voci rigenerate.'      : 'Entries regenerated.';
  String get savingEvents             => _it ? 'Eventi risparmio'      : 'Saving Events';
  String get tooltipAddReimbursement  => _it ? 'Aggiungi rimborso'     : 'Add Reimbursement';
  String get enableReimbursements     => _it ? 'Abilita rimborsi'      : 'Enable Reimbursements';
  String totalReimbursed(String amt)  => _it ? 'Totale rimborsato: $amt' : 'Total reimbursed: $amt';
  String get addReimbursementTitle    => _it ? 'Aggiungi rimborso'     : 'Add Reimbursement';
  String get deleteAdjustmentTitle    => _it ? 'Elimina aggiustamento?': 'Delete Adjustment?';
  String deleteAdjustmentConfirm(String n) => _it
      ? 'Eliminare "$n" e tutte le voci?\nQuesta operazione non può essere annullata.'
      : 'Delete "$n" and all its entries?\nThis cannot be undone.';
  String get totalLabel          => _it ? 'Totale'             : 'Total';
  String get spreadLabel         => _it ? 'Distribuzione'      : 'Spread';
  String get reimbursement       => _it ? 'Rimborso'           : 'Reimbursement';
  String datePrefix(String d)    => _it ? 'Data: $d'           : 'Date: $d';

  // ── Extraordinary Events (unified Adjustments redesign) ──
  String get eventKindSection            => _it ? 'Tipo di evento'          : 'Event kind';
  String get eventDirectionLabel         => _it ? 'Direzione'               : 'Direction';
  String get eventDirectionInflow        => _it ? 'Entrata'                 : 'Inflow';
  String get eventDirectionOutflow       => _it ? 'Uscita'                  : 'Outflow';
  String get eventTreatmentLabel         => _it ? 'Trattamento'             : 'Treatment';
  String get eventTreatmentInstant       => _it ? 'Istantaneo'              : 'Instant';
  String get eventTreatmentSpread        => _it ? 'Dilazionato'             : 'Spread';
  String get eventEphemeralLabel         => _it ? 'Effimero (linea di credito)' : 'Ephemeral (line of credit)';
  String get eventEphemeralHelp          => _it
      ? 'Soldi che non hai ma puoi spendere: contribuiscono al Cash ma non ai Risparmi.'
      : 'Money you don\'t have but can spend: contributes to Cash but not Saving.';
  String get eventBasicsSection          => _it ? 'Dettagli'                : 'Basics';
  String get eventDateLabel              => _it ? "Data dell'evento"        : 'Event date';
  String get eventSpreadSection          => _it ? 'Dilazione'               : 'Spread';
  String get eventNotesSection           => _it ? 'Note'                    : 'Notes';
  String get notesOptional               => _it ? 'Note (opzionale)'        : 'Notes (optional)';
  String get stepFrequencyLabel          => _it ? 'Frequenza'               : 'Frequency';
  String get stepCountLabel              => _it ? 'Numero passi'            : 'Step count';
  String get spreadStartLabel            => _it ? 'Inizio dilazione'        : 'Spread start';
  String get spreadEndLabel              => _it ? 'Fine dilazione'          : 'Spread end';
  String get spreadModeBackward          => _it ? 'Risparmia prima'         : 'Save before';
  String get spreadModeForward           => _it ? 'Paga dopo'               : 'Pay after';
  String get spreadModeStartSteps        => _it ? 'Da data + passi'         : 'From date + steps';
  String spreadPreview(int n, String amt) => _it ? '$n passi × $amt'        : '$n steps × $amt';
  String get freqWeekly                  => _it ? 'Settimanale'             : 'Weekly';
  String get freqMonthly                 => _it ? 'Mensile'                 : 'Monthly';
  String get freqQuarterly               => _it ? 'Trimestrale'             : 'Quarterly';
  String get freqYearly                  => _it ? 'Annuale'                 : 'Yearly';
  String freqLabel(StepFrequency f) => switch (f) {
        StepFrequency.weekly => freqWeekly,
        StepFrequency.monthly => freqMonthly,
        StepFrequency.quarterly => freqQuarterly,
        StepFrequency.yearly => freqYearly,
      };
  String get extraordinaryEvents         => _it ? 'Eventi straordinari'     : 'Extraordinary Events';
  String get adjustmentsInfoTitle        => _it ? 'Cosa sono gli aggiustamenti' : 'What these events are';
  String get adjustmentsInfoBody         => _it
      ? 'Entrate e uscite straordinarie che non riflettono la tua capacità di risparmio '
        'quotidiana: eredità, donazioni, acquisti eccezionali, grandi ristrutturazioni. '
        'Vengono esclusi dal segnale di risparmio regolare. Le spese possono essere '
        'dilazionate nel tempo (es. auto su più anni) o tenute come evento istantaneo.'
      : 'Extraordinary inflows and outflows that don\'t reflect your day-to-day saving '
        'capacity: inheritances, donations, exceptional purchases, major renovations. '
        'They\'re excluded from the regular saving signal. Expenses can be spread over '
        'time (e.g. a car over several years) or kept as a one-shot event.';
  String get addEventEntryTitle          => _it ? 'Aggiungi voce'           : 'Add entry';
  String get regenerateEntries           => _it ? 'Rigenera voci'           : 'Regenerate entries';
  String get noEntriesYet                => _it ? 'Nessuna voce'            : 'No entries yet';
  String get descriptionOptional         => _it ? 'Descrizione (opz.)'      : 'Description (optional)';
  String get dateLabel                   => _it ? 'Data'                    : 'Date';

  // ── Capex Edit ───────────────────────────────────────────
  String get editAdjustmentTitle  => _it ? 'Modifica aggiustamento'   : 'Edit Adjustment';
  String get newAdjustmentTitle   => _it ? 'Nuovo aggiustamento'       : 'New Adjustment';
  String get totalAmount          => _it ? 'Importo totale'            : 'Total Amount';
  String get reimbursements       => _it ? 'Rimborsi'                  : 'Reimbursements';
  String get stepFrequency        => _it ? 'Frequenza step'            : 'Step Frequency';
  String get startDate           => _it ? 'Data inizio'               : 'Start Date';
  String get endDate             => _it ? 'Data fine'                 : 'End Date';

  // ── Capex Screen ────────────────────────────────────────

  // ── Income ───────────────────────────────────────────────
  String get noValidRowsClipboard  => _it ? 'Nessuna riga valida trovata negli appunti' : 'No valid rows found in clipboard';
  String pastedIncomeRecords(int n) => _it ? 'Incollati $n record reddito' : 'Pasted $n income records';
  String get noIncomeYet           => _it
      ? 'Nessun record reddito.\nAggiungi voci o incolla da Excel (Ctrl/⌘+V).'
      : 'No income records yet.\nAdd entries or paste from Excel (Ctrl/⌘+V).';
  String get addIncomeTitle        => _it ? 'Aggiungi reddito'          : 'Add Income';
  String get editIncomeTitle       => _it ? 'Modifica reddito'          : 'Edit Income';
  String get incomeTypeLabel       => _it ? 'Tipo'                      : 'Type';
  String get incomeTypeIncome      => _it ? 'Reddito'                   : 'Income';
  String get incomeTypeRefund      => _it ? 'Rimborso'                  : 'Refund';
  String get incomeTypeSalary      => _it ? 'Stipendio'                 : 'Salary';
  String get incomeTypeDonation    => _it ? 'Donazione'                 : 'Donation';
  String get incomeTypeCoupon      => _it ? 'Cedola'                    : 'Coupon';
  String get incomeTypeOther       => _it ? 'Altro reddito'             : 'Other Income';
  String get flagAsIncomeTooltip   => _it ? 'Segna come reddito'        : 'Flag as Income';
  String get flagAsIncomeTitle     => _it ? 'Segna come reddito'        : 'Flag as Income';
  String get incomeFlaggedSnack    => _it ? 'Transazione aggiunta al reddito' : 'Transaction added to income';
  String get invalidDateOrAmount   => _it ? 'Data o importo non valido' : 'Invalid date or amount';
  String get deleteIncomeTitle     => _it ? 'Elimina reddito?'          : 'Delete Income?';
  String deleteIncomeConfirm(String amt, String cur, String d) => _it
      ? 'Eliminare $amt $cur del $d?'
      : 'Delete $amt $cur from $d?';
  String get dateFormatHint        => _it ? 'Data (gg/MM/aaaa)'         : 'Date (dd/MM/yyyy)';
  String get importFromFileTooltip => _it ? 'Importa da file'           : 'Import from file';

  // ── Income Adjustment Detail ──────────────────────────────

  // ── Income Adjustment Edit ────────────────────────────────
  String get remaining            => _it ? 'Rimanente: '                      : 'Remaining: ';
  String get expense             => _it ? 'Spesa'                              : 'Expense';

  // ── Import Screen ────────────────────────────────────────
  String get importTitle          => _it ? 'Importa'                : 'Import';
  String get selectSheetTitle     => _it ? 'Seleziona foglio'       : 'Select Sheet';
  String get openFile             => _it ? 'Apri file'              : 'Open File';
  String get pasteFromClipboard   => _it ? 'Incolla dagli appunti'  : 'Paste from Clipboard';
  String get clipboardData        => _it ? 'Dati appunti'           : 'Clipboard data';
  String get importAs             => _it ? 'Importa come: '         : 'Import as: ';
  String get importTypeTransaction => _it ? 'Transazione'           : 'Transaction';
  String get importTypeAssetEvent  => _it ? 'Evento attività'       : 'Asset Event';
  String get importTypeIncome      => _it ? 'Reddito'               : 'Income';
  /// Map internal field names to user-facing labels.
  String fieldLabel(String field) => switch (field) {
    'date' => _it ? 'Data operazione' : 'Operation Date',
    'valueDate' => _it ? 'Data valuta' : 'Value Date',
    'amount' => _it ? 'Importo' : 'Amount',
    'description' => _it ? 'Descrizione' : 'Description',
    'currency' => _it ? 'Valuta' : 'Currency',
    'status' => _it ? 'Stato' : 'Status',
    'isin' => 'ISIN',
    'type' => _it ? 'Tipo' : 'Type',
    'quantity' => _it ? 'Quantita' : 'Quantity',
    'price' => _it ? 'Prezzo' : 'Price',
    'exchangeRate' => _it ? 'Tasso di cambio' : 'Exchange Rate',
    'commission' => _it ? 'Commissione' : 'Commission',
    'balanceAfter' => _it ? 'Saldo dopo' : 'Balance After',
    _ => field,
  };

  String get sameAsOperationDate    => _it ? 'Uguale a data operazione' : 'Same as operation date';

  String get skipRows              => _it ? 'Salta righe: '         : 'Skip rows: ';
  String get skipRowsHelp          => _it
      ? 'Salta N righe prima della riga di intestazione'
      : 'Skip N rows before the header row';
  String get noHeaderRow           => _it
      ? 'Nessuna riga di intestazione (usa numeri di colonna)'
      : 'No header row (use column numbers)';
  String mapColumnsTitle(int c, int r) => _it
      ? 'Mappa colonne ($c colonne, $r righe)'
      : 'Map columns ($c columns, $r rows)';
  String get unmappedHelp          => _it
      ? 'Le colonne non mappate vengono salvate come metadati'
      : 'Unmapped columns are stored as metadata';
  String previewRows(int n)        => _it ? 'Anteprima ($n righe)'   : 'Preview ($n rows)';
  String get first5Rows            => _it ? 'Prime 5 righe'          : 'First 5 rows';
  String hiddenRows(int n)         => _it ? '⋯ $n righe nascoste ⋯' : '⋯ $n rows hidden ⋯';
  String get last5Rows             => _it ? 'Ultime 5 righe'         : 'Last 5 rows';
  String get addColumn             => _it ? 'Aggiungi colonna'       : 'Add column';
  String get balancePerRow         => _it ? 'Saldo per riga'         : 'Balance per row';
  String get balancePerRowHelp     => _it
      ? 'Come calcolare il saldo per ogni transazione'
      : 'How to compute balanceAfter for each transaction';
  String get balanceFromColumn     => _it ? 'Da colonna'             : 'From column';
  String get filterColumn          => _it ? 'Colonna filtro'         : 'Filter column';
  String get selectColumn          => _it ? 'Seleziona colonna'      : 'Select column';
  String get fileEmpty             => _it ? 'Il file è vuoto o non ha righe dati.' : 'File is empty or has no data rows.';
  String fileEmptyAfterSkip(int n) => _it ? 'Il file è vuoto dopo aver saltato $n righe.' : 'File is empty after skipping $n rows.';
  String errorReparsingFile(Object e) => _it ? 'Errore nel riparsificare il file: $e' : 'Error re-parsing file: $e';
  String get clipboardEmpty        => _it ? 'Appunti vuoti'            : 'Clipboard is empty';
  String get noDataRowsClipboard   => _it ? 'Nessuna riga dati negli appunti' : 'No data rows found in clipboard';
  String errorParsingClipboard(Object e) => _it ? 'Errore nel parsificare gli appunti: $e' : 'Error parsing clipboard: $e';
  String get selectAccount         => _it ? 'Seleziona conto'          : 'Select Account';
  String get importSummary         => _it ? 'Riepilogo importazione'   : 'Import Summary';
  String get numberFormatLabel     => _it ? 'Formato numeri'           : 'Number format';
  String sourceFile(String name)   => _it ? 'Origine: $name'           : 'Source: $name';
  String get clipboard             => _it ? 'Appunti'                  : 'Clipboard';
  String rowCount(int n)           => _it ? 'Righe: $n'                : 'Rows: $n';
  String get targetAssetEvents     => _it ? 'Eventi attività'          : 'Asset Events';
  String get targetTransactions    => _it ? 'Transazioni'              : 'Transactions';
  String get mappingsLabel         => _it ? 'Mappature:'               : 'Mappings:';
  String get assetsAndExchange     => _it ? 'Attività & Borsa:'        : 'Assets & Exchange:';
  String get lookingUpExchanges    => _it ? 'Ricerca borse...'         : 'Looking up exchanges...';
  String get defaultExchange       => _it ? 'Borsa predefinita: '      : 'Default exchange: ';
  String get auto                  => 'Auto';
  String nEventsCount(int n)       => _it ? '$n eventi'                : '$n events';
  String get notFound              => _it ? '(non trovato)'            : '(not found)';
  String importingProgress(int done, int total) => _it
      ? 'Importazione $done / $total righe...'
      : 'Importing $done / $total rows...';
  String get importButton          => _it ? 'Importa'                  : 'Import';
  String get savedConfigDetected   => _it ? 'Configurazione salvata trovata per questo conto' : 'Saved configuration detected for this account';
  String get headerPreviewTitle    => _it ? 'Anteprima file'             : 'File preview';
  String get headerPreviewHelp     => _it
      ? 'Verifica che le intestazioni siano allineate. Se le righe non corrispondono, usa "Modifica" per regolare "Salta righe".'
      : 'Check that the headers line up. If rows look off, tap "Let me edit" to adjust skip rows.';
  String get letMeEdit             => _it ? 'Modifica'                  : 'Let me edit';
  String get noAccountsCreate      => _it ? 'Nessun conto. Creane uno prima.' : 'No accounts yet. Create one first.';
  String get createAccount         => _it ? 'Crea conto'               : 'Create Account';
  String get newAccount            => _it ? '+ Nuovo conto'            : '+ New Account';
  String get createAsset            => _it ? 'Crea attività'            : 'Create Asset';

  // ── Import Result ───────────────────────────────────────
  String get importComplete        => _it ? 'Importazione completata'  : 'Import Complete';
  String get totalRowsLabel        => _it ? 'Righe totali'             : 'Total rows';
  String get importedLabel         => _it ? 'Importate'                : 'Imported';
  String get replacedOverlap       => _it ? 'Sostituite (sovrapposizione)' : 'Replaced (overlap)';
  String get skippedLabel          => _it ? 'Saltate'                  : 'Skipped';
  String andMore(int n)            => _it ? '... e altri $n'           : '... and $n more';
  String get importAnother         => _it ? 'Importa un altro'         : 'Import Another';
  String get done                  => _it ? 'Fatto'                    : 'Done';

  // ── Import Preview ──────────────────────────────────────
  String get importPreviewTitle    => _it ? 'Anteprima importazione'   : 'Import Preview';
  String get predictedBalance      => _it ? 'Saldo previsto'           : 'Predicted balance';
  String get importAmountSum       => _it ? 'Somma importi'            : 'Import amount sum';
  String get rowsToReplace         => _it ? 'Righe da sostituire'      : 'Rows to replace';
  String get parsedRowsLabel       => _it ? 'Righe analizzate'         : 'Parsed rows';
  String get computingPreview      => _it ? 'Calcolo anteprima...'     : 'Computing preview...';
  String get netQuantity           => _it ? 'Qtà netta'                : 'Net qty';
  String get buysLabel             => _it ? 'Acquisti'                 : 'Buys';
  String get sellsLabel            => _it ? 'Vendite'                  : 'Sells';
  String get assetLabel            => _it ? 'Attività'                 : 'Asset';

  // ── Column Mapper ───────────────────────────────────────
  String get modeLabel             => _it ? 'Modalità: '               : 'Mode: ';
  String get modeHistoric          => _it ? 'Storico'                  : 'Historic';
  String get modeCurrent           => _it ? 'Attuale'                  : 'Current';
  String get dateExchangeRequired  => _it ? 'Data e tasso di cambio obbligatori' : 'Date & exchange rate required';
  String get dateDefaultsToday     => _it ? 'La data predefinita è oggi, tasso auto-recuperato' : 'Date defaults to today, rate auto-fetched';
  String get qtyTimesPrice         => _it ? 'quantità x prezzo'        : 'quantity x price';
  String get autoCalc              => _it ? 'Auto calc'                : 'Auto calc';
  String get combineMultipleColumns => _it ? 'Combina più colonne'     : 'Combine multiple columns';
  String get useSingleColumn       => _it ? 'Usa colonna singola'      : 'Use single column';
  String get sepLabel              => 'Sep:';
  String get fromColumn            => _it ? 'Da colonna'               : 'From column';
  String get fromSign              => _it ? 'Dal segno (+/-)'          : 'From sign (+/-)';
  String get buyLabel              => _it ? 'Acquisto'                 : 'Buy';
  String get sellLabel             => _it ? 'Vendita'                  : 'Sell';
  String get signBasedHelp         => _it
      ? 'Quantità o importo negativo = Vendita, positivo = Acquisto'
      : 'Negative quantity or amount = Sell, positive = Buy';
  String get computedLabel         => _it ? 'Calcolato'                : 'Computed';
  String get buySellAllRequired    => _it ? 'Ogni valore deve essere assegnato a Acquisto o Vendita' : 'Every value must be assigned to Buy or Sell';

  // ── Allocation ───────────────────────────────────────────
  String get noMarketValues    => _it ? 'Nessun valore di mercato disponibile.' : 'No market values available.';
  String get noData            => _it ? 'Nessun dato'               : 'No data';
  String get noDataYet         => _it ? 'Nessun dato ancora.'       : 'No data yet.';
  String get marketOpen        => _it ? 'Mercato aperto'            : 'Market open';
  String get marketClosed      => _it ? 'Mercato chiuso'            : 'Market closed';
  String get currentValue      => _it ? 'Valore attuale'            : 'Current Value';

  // ── Import wizard ──────────────────────────────────────────
  String get buySellDetection  => _it ? 'Rilevamento Acquisto / Vendita' : 'Buy / Sell Detection';
  String get mapBuySell        => _it ? 'Mappa valori in Acquisto / Vendita:' : 'Map values to Buy / Sell:';
  String get feeCommission     => _it ? 'Commissione'               : 'Fee / Commission';
  String get balanceColumn     => _it ? 'Colonna saldo:'            : 'Balance column:';
  String get amountRequired    => _it ? 'importo *'                 : 'amount *';
  String get concentrationRisk => _it ? 'Rischio concentrazione'    : 'Concentration Risk';
  String get unclassified      => _it ? 'Non classificato'          : 'Unclassified';
  String get allocGeographic   => _it ? 'Allocazione geografica'    : 'Geographic Allocation';
  String get allocSector       => _it ? 'Allocazione settoriale'    : 'Sector Allocation';
  String get allocAssetClass   => _it ? 'Asset class'               : 'Asset Class';
  String get allocInstrument   => _it ? 'Tipo strumento'            : 'Instrument Type';
  String get allocCurrency     => _it ? 'Esposizione valutaria'     : 'Currency Exposure';
  String get allocTopHoldings  => _it ? 'Principali posizioni'      : 'Top Holdings';
  String get allocPortfolioVal => _it ? 'Valore portafoglio'        : 'Portfolio Value';
  String get allocHoldings     => _it ? 'Posizioni'                 : 'Holdings';
  String get allocWellDiversified       => _it ? 'Ben diversificato'              : 'Well diversified';
  String get allocModeratelyConcentrated => _it ? 'Moderatamente concentrato'     : 'Moderately concentrated';
  String get allocHighlyConcentrated    => _it ? 'Altamente concentrato'          : 'Highly concentrated';

  // ── Instrument Type labels ──
  String get instrumentStock           => _it ? 'Azione'                         : 'Stock';
  String get instrumentBond            => _it ? 'Obbligazione'                   : 'Bond';
  String get instrumentEtf             => 'ETF';
  String get instrumentEtc             => 'ETC';
  String get instrumentFund            => _it ? 'Fondo'                          : 'Fund';
  String get instrumentPension         => _it ? 'Fondo pensione'                 : 'Pension Fund';
  String get instrumentCrypto          => 'Crypto';
  String get instrumentCash            => _it ? 'Liquidità'                      : 'Cash';
  String get instrumentDeposit         => _it ? 'Deposito'                       : 'Deposit';
  String get instrumentRealEstate      => _it ? 'Immobile'                       : 'Real Estate';
  String get instrumentAlternative     => _it ? 'Alternativo'                    : 'Alternative';
  String get instrumentLiability       => _it ? 'Passività'                      : 'Liability';

  // ── Asset Class labels ──
  String get assetClassEquity          => _it ? 'Azionario'                      : 'Equity';
  String get assetClassFixedIncome     => _it ? 'Obbligazionario'                : 'Fixed Income';
  String get assetClassCommodities     => _it ? 'Materie prime'                  : 'Commodities';
  String get assetClassMoneyMarket     => _it ? 'Monetario'                      : 'Money Market';
  String get assetClassCash            => _it ? 'Liquidità'                      : 'Cash';
  String get assetClassCrypto          => 'Crypto';
  String get assetClassRealEstate      => _it ? 'Immobiliare'                    : 'Real Estate';
  String get assetClassAlternative     => _it ? 'Alternativi'                    : 'Alternative';
  String get assetClassMultiAsset      => _it ? 'Misto'                          : 'Multi-Asset';

  // ── Legacy asset type labels (kept for backward compat) ──
  String get top1                      => 'Top 1';
  String get top3                      => 'Top 3';
  String get top5                      => 'Top 5';

  String instrumentTypeLabel(InstrumentType t) => {
    InstrumentType.stock:       instrumentStock,
    InstrumentType.bond:        instrumentBond,
    InstrumentType.etf:         instrumentEtf,
    InstrumentType.etc:         instrumentEtc,
    InstrumentType.fund:        instrumentFund,
    InstrumentType.pension:     instrumentPension,
    InstrumentType.crypto:      instrumentCrypto,
    InstrumentType.cash:        instrumentCash,
    InstrumentType.deposit:     instrumentDeposit,
    InstrumentType.realEstate:  instrumentRealEstate,
    InstrumentType.alternative: instrumentAlternative,
    InstrumentType.liability:   instrumentLiability,
  }[t]!;

  String assetClassLabel(AssetClass c) => {
    AssetClass.equity:      assetClassEquity,
    AssetClass.fixedIncome: assetClassFixedIncome,
    AssetClass.commodities: assetClassCommodities,
    AssetClass.moneyMarket: assetClassMoneyMarket,
    AssetClass.cash:        assetClassCash,
    AssetClass.crypto:      assetClassCrypto,
    AssetClass.realEstate:  assetClassRealEstate,
    AssetClass.alternative: assetClassAlternative,
    AssetClass.multiAsset:  assetClassMultiAsset,
  }[c]!;

  // ── Intermediaries ─────────────────────────────────────────
  String get vsATH                 => _it ? 'vs Max'                    : 'vs ATH';
  String get value                 => _it ? 'Valore'                    : 'Value';
  String get intermediary          => _it ? 'Intermediario'             : 'Intermediary';
  String get intermediaries        => _it ? 'Intermediari'              : 'Intermediaries';
  String get addIntermediary       => _it ? 'Aggiungi intermediario'    : 'Add Intermediary';
  String get editIntermediary      => _it ? 'Modifica intermediario'    : 'Edit Intermediary';
  String get deleteIntermediary    => _it ? 'Elimina intermediario'     : 'Delete Intermediary';
  String get intermediaryName      => _it ? 'Nome intermediario'        : 'Intermediary Name';
  String get unassigned            => _it ? 'Non assegnato'             : 'Unassigned';
  String deleteIntermediaryConfirm(String name) => _it
      ? 'Eliminare "$name"? Conti e strumenti verranno spostati in "Non assegnato".'
      : 'Delete "$name"? Accounts and assets will be moved to "Unassigned".';
  String get selectIntermediary    => _it ? 'Seleziona intermediario'   : 'Select Intermediary';
  String get selectIntermediaryEmpty => _it ? 'Nessun intermediario. Creane uno per procedere.' : 'No intermediary yet. Create one to continue.';
  String get close                 => _it ? 'Chiudi'                    : 'Close';

  // ── Multi-select ─────────────────────────────────────────
  String nSelected(int n)          => _it ? '$n selezionati'            : '$n selected';
  String get selectAll             => _it ? 'Seleziona tutto'           : 'Select all';
  String get deselectAll           => _it ? 'Deseleziona tutto'         : 'Deselect all';
  String get bulkDeleteTitle       => _it ? 'Eliminare gli elementi?'   : 'Delete items?';
  String bulkDeleteBody(int n)     => _it
      ? 'Verranno eliminati $n elementi. Operazione irreversibile.'
      : '$n items will be permanently deleted. This cannot be undone.';

  // ── DB Picker ────────────────────────────────────────────

  // ── Main / App Shell ────────────────────────────────────
  String get noNetworkRetry      => _it ? 'Nessuna rete - tocca per riprovare' : 'No network - tap to retry';

  // ── Bug Reporter / Ticketer ────────────────────────────
  String get ticketerTitle        => _it ? 'Segnala un bug'            : 'Report a Bug';
  String get ticketerConfirmDesc  => _it
      ? 'Questa operazione:\n• Nasconderà gli importi\n• Catturerà uno screenshot\n• Raccoglierà i log della sessione\n• Aprirà una segnalazione GitHub nel browser'
      : 'This will:\n• Hide amounts\n• Take a screenshot\n• Collect session logs\n• Open a GitHub issue in your browser';
  String get ticketerLoginReminder => _it
      ? 'Assicurati di aver effettuato l\'accesso a GitHub nel tuo browser predefinito.'
      : 'Make sure you are logged into GitHub in your default browser.';
  String get ticketerContinue     => _it ? 'Continua'                  : 'Continue';
  String get ticketerClose        => _it ? 'Chiudi'                    : 'Close';
  String get ticketerOpenIssue    => _it ? 'Apri segnalazione GitHub'  : 'Open GitHub Issue';
  String get ticketerFilesSaved    => _it ? 'File salvati sul Desktop:'  : 'Files saved to Desktop:';
  String get ticketerUploadReminder => _it
      ? 'Apri la cartella, poi trascina i file nella segnalazione GitHub.'
      : 'Open the folder, then drag the files into the GitHub issue.';
  String get ticketerRevealFile   => _it ? 'Apri cartella'             : 'Show in Finder';
  String get ticketerTapToPreview => _it ? 'Tocca per ingrandire e verificare' : 'Tap to enlarge and verify';
  String get ticketerScreenshotBanner => _it
      ? 'Questo screenshot deve essere caricato nella segnalazione GitHub'
      : 'This screenshot must be uploaded to the GitHub issue';
  String get ticketerDescriptionLabel => _it ? 'Descrizione del problema' : 'Describe the issue';
  String get ticketerStepsLabel   => _it ? 'Passaggi per riprodurre'   : 'Steps to reproduce';
  String get ticketerStepsHint    => _it ? '1. Apri...\n2. Clicca...'  : '1. Open...\n2. Click...';
}
