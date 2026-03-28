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
  String get appTitle              => 'FinanceCopilot';
  String get navDashboard          => 'Dashboard';
  String get navAccounts           => _it ? 'Conti'             : 'Accounts';
  String get navAssets             => _it ? 'Portafoglio'       : 'Assets';
  String get navAdjustments        => _it ? 'Aggiustamenti'     : 'Adjustments';
  String get navIncome             => _it ? 'Entrate'           : 'Income';
  String get tooltipHideAmounts    => _it ? 'Nascondi importi'  : 'Hide amounts';
  String get tooltipShowAmounts    => _it ? 'Mostra importi'    : 'Show amounts';
  String get tooltipRefreshPrices  => _it ? 'Aggiorna prezzi di mercato' : 'Refresh Market Prices';
  String get tooltipChangeDatabase => _it ? 'Cambia database'   : 'Change Database';
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

  // ── Dashboard ───────────────────────────────────────────
  String get dashTabOverall      => _it ? 'Generale'         : 'Overall';
  String get dashTabCashFlow     => _it ? 'Flussi di cassa'  : 'Cash Flow';
  String get dashTabAllocation   => _it ? 'Allocazione'      : 'Allocation';
  String get dashNoData          => _it
      ? 'Nessun dato. Importa transazioni o aggiungi attività per iniziare.'
      : 'No data yet. Import transactions or add assets to get started.';
  String get dashShowComponents  => _it ? 'Mostra componenti'  : 'Show components';
  String get dashHideComponents  => _it ? 'Nascondi componenti': 'Hide components';
  String get dashResetZoom       => _it ? 'Reset zoom'         : 'Reset zoom';
  String get dashNotEnoughData   => _it ? 'Dati insufficienti per il grafico' : 'Not enough data to plot';
  String get dashAssets          => _it ? 'Attività'           : 'Assets';
  String get dashPriceChanges    => _it ? 'Variazioni prezzo'  : 'Price Changes';
  String get dashNoPriceData     => _it ? 'Nessun dato di prezzo disponibile' : 'No price data available';
  String get dashTotals          => _it ? 'Totali'             : 'Totals';
  String get dashTotalAssets     => _it ? 'Patrimonio totale'  : 'Total Assets';
  String get dashCash            => _it ? 'Liquidità'          : 'Cash';
  String get dashSaving          => _it ? 'Risparmi'           : 'Saving';
  String get dashInvested        => _it ? 'Investito'          : 'Invested';
  String get dashPortfolio       => _it ? 'Portafoglio'        : 'Portfolio';
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
  String get maLabel             => 'MA:';
  String nTransactions(int n)    => _it ? '$n transazioni'     : '$n transactions';

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
  String get colYTD           => 'YTD';
  String get eoyLabel         => _it ? '  Pre. anno~'   : '  EOY~';
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
  String get tooltipReindexDedup      => _it ? 'Reindicizza chiavi dedup'   : 'Reindex Dedup Keys';
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
  String get noImportedTransactions   => _it
      ? 'Nessuna transazione importata con metadati trovata.'
      : 'No imported transactions with metadata found.';
  String get reindexDedupTitle        => _it ? 'Reindicizza chiavi dedup'   : 'Reindex Dedup Keys';
  String withMetadata(int n)          => _it ? '$n con metadati.'           : '$n with metadata.';
  String get selectDedupColumns       => _it ? 'Seleziona colonne per hash dedup:' : 'Select columns for dedup hash:';
  String get dedupHashHelp            => _it
      ? "L'hash identifica univocamente una riga. I duplicati con lo stesso hash verranno rimossi."
      : 'The hash uniquely identifies a row. Duplicates with the same hash will be removed.';
  String get previewFirstRow          => _it ? 'Anteprima (prima riga):'    : 'Preview (first row):';
  String get reindexButton            => _it ? 'Reindicizza e rimuovi duplicati' : 'Reindex & Remove Duplicates';
  String reindexResult(int u, int d)  => _it
      ? 'Reindicizzate $u righe. Rimossi $d duplicati.'
      : 'Reindexed $u hashes. Removed $d duplicates.';
  String get noTransactionsToRecalc   => _it ? 'Nessuna transazione da ricalcolare.' : 'No transactions to recalculate.';
  String get recalcBalanceTitle       => _it ? 'Ricalcola saldo'            : 'Recalculate Balance';
  String get recalcBalanceHelp        => _it
      ? 'Scegli come calcolare il saldo per ogni transazione.'
      : 'Choose how to compute balanceAfter for each transaction.';
  String get recalcNone               => _it ? 'Nessuno'            : 'None';
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
  String get createAssetTitle    => _it ? 'Crea attività'                     : 'Create Asset';
  String symbolLabel(String s)   => 'Symbol: $s';
  String typeLabel(String t)     => _it ? 'Tipo: $t'                          : 'Type: $t';
  String get stockExchange       => _it ? 'Borsa valori'                      : 'Stock Exchange';
  String get newAssetManualTitle => _it ? 'Nuova attività (manuale)'           : 'New Asset (Manual)';
  String get identifierLabel     => _it ? 'Identificatore (ISIN, ticker, ecc.)' : 'Identifier (ISIN, ticker, etc.)';
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
  String hashLabel(String h)           => 'Hash: $h';

  // ── Transaction Edit ─────────────────────────────────────
  String get editTransactionTitle   => _it ? 'Modifica transazione'  : 'Edit Transaction';
  String get newTransactionTitle    => _it ? 'Nuova transazione'      : 'New Transaction';
  String get fullDescription        => _it ? 'Descrizione completa'   : 'Full Description';
  String get balanceAfter           => _it ? 'Saldo successivo'       : 'Balance After';
  String get statusLabel            => _it ? 'Stato'                  : 'Status';
  String get createTransaction      => _it ? 'Crea transazione'       : 'Create Transaction';
  String get deleteTransactionTitle => _it ? 'Elimina transazione?'   : 'Delete Transaction?';

  // ── Capex / Adjustments ──────────────────────────────────
  String get capexTabSavingSpent     => _it ? 'Spese dilazionate'      : 'Spread Expenses';
  String get capexTabDonationSpent   => _it ? 'Donazioni / Eredità'    : 'Donations / Inheritance';
  String get noSpreadAdjustments     => _it
      ? 'Nessun aggiustamento dilazionato.\nAggiungi un elemento per distribuire grandi spese nel tempo.'
      : 'No spread adjustments yet.\nAdd an item to spread large expenses over time.';
  String get noIncomeAdjustments     => _it
      ? 'Nessun aggiustamento entrate.\nAggiungi una donazione o importo forfait da sottrarre dal patrimonio netto.'
      : 'No income adjustments yet.\nAdd a donation or lump sum to subtract from net worth.';
  String expLabel(String d)          => _it ? 'Spesa: $d'              : 'Exp: $d';

  // ── Capex Detail ─────────────────────────────────────────
  String get tooltipRegenerateEntries => _it ? 'Rigenera voci'         : 'Regenerate Entries';
  String get entriesRegenerated       => _it ? 'Voci rigenerate.'      : 'Entries regenerated.';
  String get savingEvents             => _it ? 'Eventi risparmio'      : 'Saving Events';
  String get tooltipAddReimbursement  => _it ? 'Aggiungi rimborso'     : 'Add Reimbursement';
  String get reimbursementEnabled     => _it ? 'Rimborso abilitato.'   : 'Reimbursement tracking enabled.';
  String get enableReimbursements     => _it ? 'Abilita rimborsi'      : 'Enable Reimbursements';
  String get noEventsCapex            => _it ? 'Nessun evento.'        : 'No events yet.';
  String totalReimbursed(String amt)  => _it ? 'Totale rimborsato: $amt' : 'Total reimbursed: $amt';
  String get addReimbursementTitle    => _it ? 'Aggiungi rimborso'     : 'Add Reimbursement';
  String get reimbursementFromHint    => _it ? 'es. Da Marco'          : 'e.g. From John';
  String get deleteReimbursementTitle => _it ? 'Elimina rimborso?'     : 'Delete Reimbursement?';
  String get deleteAdjustmentTitle    => _it ? 'Elimina aggiustamento?': 'Delete Adjustment?';
  String deleteAdjustmentConfirm(String n) => _it
      ? 'Eliminare "$n" e tutte le voci?\nQuesta operazione non può essere annullata.'
      : 'Delete "$n" and all its entries?\nThis cannot be undone.';
  String get totalLabel          => _it ? 'Totale'             : 'Total';
  String get expenseLabel        => _it ? 'Spesa'              : 'Expense';
  String get spreadLabel         => _it ? 'Distribuzione'      : 'Spread';
  String get reimbursement       => _it ? 'Rimborso'           : 'Reimbursement';
  String cumulativeRemaining(String cum, String rem) => _it
      ? 'Cumulativo: $cum · Rimanente: $rem'
      : 'Cumulative: $cum · Remaining: $rem';
  String datePrefix(String d)    => _it ? 'Data: $d'           : 'Date: $d';

  // ── Capex Edit ───────────────────────────────────────────
  String get editAdjustmentTitle  => _it ? 'Modifica aggiustamento'   : 'Edit Adjustment';
  String get newAdjustmentTitle   => _it ? 'Nuovo aggiustamento'       : 'New Adjustment';
  String get capexNameHint        => _it ? 'es. Auto, Ristrutturazione cucina' : 'e.g. Car, Kitchen renovation';
  String get totalAmount          => _it ? 'Importo totale'            : 'Total Amount';
  String rateLabel(String b, String c) => _it ? 'Tasso $b/$c'         : 'Rate $b/$c';
  String get reimbursements       => _it ? 'Rimborsi'                  : 'Reimbursements';
  String get stepFrequency        => _it ? 'Frequenza step'            : 'Step Frequency';
  String get directionBackward    => _it ? 'Indietro'                  : 'Backward';
  String get directionForward     => _it ? 'Avanti'                    : 'Forward';
  String get directionStartSteps  => _it ? 'Inizio + Steps'            : 'Start + Steps';
  String get numberOfSteps        => _it ? 'Numero di step'            : 'Number of Steps';
  String get saveAndAddAnother    => _it ? 'Salva e aggiungi altro'    : 'Save & Add Another';
  String get editReimbursementTitle => _it ? 'Modifica rimborso'       : 'Edit Reimbursement';
  String get savedAddAnother      => _it ? 'Salvato! Aggiungine un altro.' : 'Saved! Add another.';
  String get expenseDateLabel     => _it ? 'Data spesa'                : 'Expense Date';
  String get expenseDateHelp     => _it ? 'Data spesa (quando il denaro è uscito)' : 'Expense Date (when money left)';
  String effectiveAmountToSpread(String amt, String sym) => _it
      ? 'Importo effettivo da distribuire: $amt $sym'
      : 'Effective amount to spread: $amt $sym';
  String get spreadBackwardHelp  => _it
      ? 'Distribuzione risparmi dalla data inizio fino alla data spesa'
      : 'Spread savings from start date up to expense date';
  String get spreadForwardHelp   => _it
      ? 'Distribuzione costo dalla data spesa alla data fine'
      : 'Spread cost from expense date to end date';
  String get spreadStartStepsHelp => _it
      ? 'Distribuzione dalla data inizio per N step'
      : 'Spread from start date for N steps';
  String stepsFromTo(int n, String from, String to) => _it
      ? '$n step da $from a $to'
      : '$n steps from $from to $to';
  String get startDate           => _it ? 'Data inizio'               : 'Start Date';
  String get endDate             => _it ? 'Data fine'                 : 'End Date';
  String get minOne              => _it ? 'Min 1'                     : 'Min 1';

  // ── Capex Screen ────────────────────────────────────────
  String reimbLabel(String amt)  => _it ? 'Rimb: $amt'                : 'Reimb: $amt';
  String nSteps(int n, String range) => _it ? '$n step · $range'      : '$n steps · $range';
  String incomeLabel(String amt) => _it ? 'Reddito: $amt'             : 'Income: $amt';
  String spentRemaining(String spent, String rem) => _it
      ? 'Speso: $spent · Rimanente: $rem'
      : 'Spent: $spent · Remaining: $rem';

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
  String get invalidDateOrAmount   => _it ? 'Data o importo non valido' : 'Invalid date or amount';
  String get deleteIncomeTitle     => _it ? 'Elimina reddito?'          : 'Delete Income?';
  String deleteIncomeConfirm(String amt, String cur, String d) => _it
      ? 'Eliminare $amt $cur del $d?'
      : 'Delete $amt $cur from $d?';
  String get dateFormatHint        => _it ? 'Data (gg/MM/aaaa)'         : 'Date (dd/MM/yyyy)';
  String get importFromFileTooltip => _it ? 'Importa da file'           : 'Import from file';

  // ── Income Adjustment Detail ──────────────────────────────
  String get expensesLabel          => _it ? 'Spese'                    : 'Expenses';
  String get tooltipAddExpense      => _it ? 'Aggiungi spesa'           : 'Add Expense';
  String get noExpensesYet          => _it
      ? 'Nessuna spesa. Aggiungila quando spendi questi soldi.'
      : 'No expenses yet. Add when you spend this money.';
  String get addExpenseTitle        => _it ? 'Aggiungi spesa'           : 'Add Expense';
  String get expenseHint            => _it ? 'es. Mobili, Viaggio'      : 'e.g. Furniture, Travel';
  String get deleteExpenseTitle     => _it ? 'Elimina spesa?'           : 'Delete Expense?';
  String get deleteIncomeAdjTitle   => _it ? 'Elimina aggiustamento reddito?' : 'Delete Income Adjustment?';
  String deleteIncomeAdjConfirm(String n) => _it
      ? 'Eliminare "$n" e tutte le spese?\nQuesta operazione non può essere annullata.'
      : 'Delete "$n" and all its expenses?\nThis cannot be undone.';
  String get incomeChip          => _it ? 'Reddito'                   : 'Income';
  String get incomeDateFieldLabel => _it ? 'Data reddito'             : 'Income Date';
  String get spentLabel          => _it ? 'Speso'                     : 'Spent';
  String get remainingLabel      => _it ? 'Rimanente'                 : 'Remaining';

  // ── Income Adjustment Edit ────────────────────────────────
  String get editIncomeAdjTitle   => _it ? 'Modifica aggiustamento reddito' : 'Edit Income Adjustment';
  String get newIncomeAdjTitle    => _it ? 'Nuovo aggiustamento reddito'     : 'New Income Adjustment';
  String get incomeAdjNameHint    => _it ? 'es. Donazione, Eredità'          : 'e.g. Donation, Inheritance';
  String get remaining            => _it ? 'Rimanente: '                      : 'Remaining: ';
  String get editExpenseTitle     => _it ? 'Modifica spesa'                   : 'Edit Expense';
  String get incomeDateLabel      => _it ? 'Data reddito'                     : 'Income Date';
  String get incomeDateHelp      => _it ? 'Data reddito (quando il denaro è arrivato)' : 'Income Date (when money arrived)';
  String spentOf(String spent, String total) => _it ? 'Speso: $spent / $total' : 'Spent: $spent / $total';
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
  String get dedupKeyColumns       => _it ? 'Colonne chiave dedup'   : 'Dedup key columns';
  String get dedupKeyHelp          => _it
      ? 'Seleziona le colonne che identificano una riga unica (i duplicati verranno saltati)'
      : 'Select which columns identify a unique row (duplicates will be skipped)';
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
  String get noAccountsCreate      => _it ? 'Nessun conto. Creane uno prima.' : 'No accounts yet. Create one first.';
  String get createAccount         => _it ? 'Crea conto'               : 'Create Account';
  String get newAccount            => _it ? '+ Nuovo conto'            : '+ New Account';
  String get noAssetsCreate        => _it ? 'Nessuna attività. Creane una prima.' : 'No assets yet. Create one first.';
  String get createAsset            => _it ? 'Crea attività'            : 'Create Asset';
  String get newAsset              => _it ? '+ Nuova attività'         : '+ New Asset';
  String get lookingUpIsin         => _it ? 'Ricerca ISIN...'          : 'Looking up ISIN...';
  String get isinNotFound          => _it ? 'ISIN non trovato'         : 'ISIN not found';
  String get isinHint              => _it ? 'es. IE00B4L5Y983'         : 'e.g. IE00B4L5Y983';

  // ── Import Result ───────────────────────────────────────
  String get importComplete        => _it ? 'Importazione completata'  : 'Import Complete';
  String get totalRowsLabel        => _it ? 'Righe totali'             : 'Total rows';
  String get importedLabel         => _it ? 'Importate'                : 'Imported';
  String get replacedOverlap       => _it ? 'Sostituite (sovrapposizione)' : 'Replaced (overlap)';
  String get skippedLabel          => _it ? 'Saltate'                  : 'Skipped';
  String andMore(int n)            => _it ? '... e altri $n'           : '... and $n more';
  String get importAnother         => _it ? 'Importa un altro'         : 'Import Another';
  String get done                  => _it ? 'Fatto'                    : 'Done';

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

  // ── Allocation ───────────────────────────────────────────
  String get noMarketValues    => _it ? 'Nessun valore di mercato disponibile.' : 'No market values available.';
  String get noData            => _it ? 'Nessun dato'               : 'No data';
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
  String get assetTypeStock            => _it ? 'Azione'                         : 'Stock';
  String get assetTypeStockEtf         => _it ? 'ETF Azionario'                  : 'Stock ETF';
  String get assetTypeBondEtf          => _it ? 'ETF Obbligazionario'            : 'Bond ETF';
  String get assetTypeCommodityEtf     => _it ? 'ETF Commodity'                  : 'Commodity ETF';
  String get assetTypeGoldEtc          => _it ? 'ETC Oro'                        : 'Gold ETC';
  String get assetTypeMoneyMarketEtf   => _it ? 'ETF Monetario'                  : 'Money Market ETF';
  String get assetTypeCrypto           => 'Crypto';
  String get assetTypeCash             => _it ? 'Liquidità'                      : 'Cash';
  String get assetTypePension          => _it ? 'Pensione'                       : 'Pension';
  String get assetTypeDeposit          => _it ? 'Deposito'                       : 'Deposit';
  String get assetTypeRealEstate       => _it ? 'Immobili'                       : 'Real Estate';
  String get assetTypeAlternative      => _it ? 'Alternativo'                    : 'Alternative';
  String get assetTypeLiability        => _it ? 'Passività'                      : 'Liability';
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

  // ── DB Picker ────────────────────────────────────────────
  String get dbPickerTitle        => _it ? 'Apri un database'        : 'Open a Database';
  String get dbPickerOpenFile     => _it ? 'Apri file...'            : 'Open File...';
  String get dbPickerNewProject   => _it ? 'Nuovo progetto'          : 'New Project';
  String get dbPickerCreateDemo   => _it ? 'Crea DB demo'            : 'Create Demo DB';
  String get dbPickerGenerating   => _it ? 'Generazione...'          : 'Generating...';
  String dbPickerDemoFailed(Object e) => _it
      ? 'Errore generazione demo DB: $e'
      : 'Failed to generate demo DB: $e';
  String get dbPickerRecent       => _it ? 'Recenti'                 : 'Recent';
  String get dbPickerRemoveRecent => _it ? 'Rimuovi dai recenti'     : 'Remove from recent';
  String updateAvailable(String v) => _it ? 'Aggiornamento disponibile - $v' : 'Update Available - $v';
  String get changesLabel        => _it ? 'Modifiche:'               : 'Changes:';
  String get newVersionAvailable => _it ? 'È disponibile una nuova versione.' : 'A new version is available.';
  String downloadingProgress(int pct) => _it ? 'Download... $pct%'   : 'Downloading... $pct%';
  String get later               => _it ? 'Più tardi'                : 'Later';
  String get updateAndRestart    => _it ? 'Aggiorna e riavvia'       : 'Update & Restart';
  String updateFailed(Object e)  => _it ? 'Aggiornamento fallito: $e': 'Update failed: $e';
  String get openDatabase        => _it ? 'Apri database'            : 'Open Database';
  String get createNewProject    => _it ? 'Crea nuovo progetto'      : 'Create new project';
  String get chooseDemoFolder    => _it ? 'Scegli cartella per database demo' : 'Choose folder for demo database';

  // ── Main / App Shell ────────────────────────────────────
  String dbOpenFailed(Object e)  => _it ? 'Impossibile aprire il database:\n$e' : 'Failed to open database:\n$e';
  String get backToPicker        => _it ? 'Torna alla selezione'     : 'Back to picker';
  String get noNetworkRetry      => _it ? 'Nessuna rete - tocca per riprovare' : 'No network - tap to retry';
  String get systemDefault       => _it ? 'Predefinito di sistema'   : 'System Default';

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

  // ── Open Banking ───────────────────────────────────────
  String get obSetupTitle         => _it ? 'Collega i tuoi conti bancari'     : 'Connect your bank accounts';
  String get obStep1Title         => _it ? 'Crea account'                      : 'Create Account';
  String get obStep1Desc          => _it ? 'Per iniziare, crea un account gratuito su Enable Banking.' : 'To get started, create a free account on Enable Banking.';
  String get obStep1Instructions  => _it
      ? '1. Clicca il pulsante qui sotto\n2. Inserisci la tua email\n3. Clicca il link di verifica nell\'email'
      : '1. Click the button below\n2. Enter your email\n3. Click the verification link in the email';
  String get obCreateAccount      => _it ? 'Crea account Enable Banking'       : 'Create Enable Banking account';
  String get obStep2Title         => _it ? 'Registra applicazione'             : 'Register Application';
  String get obStep2Desc          => _it ? 'Registra un\'applicazione per ottenere le credenziali API.' : 'Register an application to get API credentials.';
  String get obStep2Instructions  => _it
      ? '1. Nella dashboard, vai su "API applications"\n2. Clicca "Add a new application"\n3. Nome: "FinanceCopilot"\n4. URL di redirect: financecopilot://callback\n5. Clicca "Register" e scarica il file .pem'
      : '1. In the dashboard, go to "API applications"\n2. Click "Add a new application"\n3. Name: "FinanceCopilot"\n4. Redirect URL: financecopilot://callback\n5. Click "Register" and download the .pem file';
  String get obOpenDashboard      => _it ? 'Apri Dashboard Enable Banking'     : 'Open Enable Banking Dashboard';
  String get obStep3Title         => _it ? 'Importa credenziali'               : 'Import Credentials';
  String get obStep3Desc          => _it ? 'Importa le credenziali nell\'app.' : 'Import credentials into the app.';
  String get obNoPemSelected      => _it ? 'Nessun file .pem selezionato'      : 'No .pem file selected';
  String get obSelectPem          => _it ? 'Seleziona .pem'                    : 'Select .pem';
  String get obAppIdLabel         => 'App ID (UUID)';
  String get obAppIdHelper        => _it ? 'Rilevato automaticamente dal nome del file .pem' : 'Auto-detected from .pem filename';
  String get obVerifyAndSave      => _it ? 'Verifica e Salva'                  : 'Verify & Save';
  String get obStep4Title         => _it ? 'Completato'                        : 'Complete';
  String get obSetupComplete      => _it ? 'Configurazione completata!'        : 'Setup complete!';
  String get obConnectFirstBank   => _it ? 'Collega la tua prima banca'        : 'Connect your first bank';
  String get obConnectionsTitle   => _it ? 'Connessioni Bancarie'              : 'Bank Connections';
  String get obConnectBank        => _it ? 'Collega banca'                     : 'Connect bank';
  String get obNoConnections      => _it ? 'Nessuna connessione bancaria.'     : 'No bank connections.';
  String get obCountry            => _it ? 'Paese:'                            : 'Country:';
  String obBankLogin(String bank) => _it ? 'Accesso a $bank'                   : 'Login to $bank';
  String get obConnectionSuccess  => _it ? 'Connessione riuscita'              : 'Connection Successful';
  String obConnectedTo(String bank) => _it ? 'Connesso a $bank'               : 'Connected to $bank';
  String obAccountsFound(int n)   => _it ? '$n conti trovati:'                 : '$n accounts found:';
  String get obSyncNow            => _it ? 'Sincronizza ora'                   : 'Sync now';
  String get obRemoveConnection   => _it ? 'Rimuovi connessione'               : 'Remove connection';
  String obRemoveConfirm(String bank) => _it
      ? 'Rimuovere la connessione a $bank? I conti e le transazioni importate rimarranno.'
      : 'Remove connection to $bank? Imported accounts and transactions will remain.';
  String get obActive             => _it ? 'Attiva'                            : 'Active';
  String get obExpired            => _it ? 'Scaduta'                           : 'Expired';
  String get obExpiresOn          => _it ? 'Scade il'                          : 'Expires';
  String get obLastSync           => _it ? 'Ultimo sync'                       : 'Last sync';
  String get obJustNow            => _it ? 'Adesso'                            : 'Just now';
  String obMinutesAgo(int n)      => _it ? '$n min fa'                         : '$n min ago';
  String obHoursAgo(int n)        => _it ? '$n ore fa'                         : '$n hours ago';
  String obDaysAgo(int n)         => _it ? '$n giorni fa'                      : '$n days ago';
  String get obOpenBanking        => 'Open Banking';
  String get obLinkAccountsDesc   => _it
      ? 'Per ogni conto bancario, scegli se collegarlo a un conto esistente o crearne uno nuovo.'
      : 'For each bank account, choose to link it to an existing account or create a new one.';
  String get obLinkTo             => _it ? 'Collega a'                         : 'Link to';
  String get obCreateNewAccount   => _it ? '+ Crea nuovo conto'               : '+ Create new account';
  String get obSkipAccount        => _it ? 'Salta (non importare)'            : 'Skip (do not import)';
}
