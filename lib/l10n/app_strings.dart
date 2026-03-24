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

  // ── Income Adjustment Edit ────────────────────────────────
  String get editIncomeAdjTitle   => _it ? 'Modifica aggiustamento reddito' : 'Edit Income Adjustment';
  String get newIncomeAdjTitle    => _it ? 'Nuovo aggiustamento reddito'     : 'New Income Adjustment';
  String get incomeAdjNameHint    => _it ? 'es. Donazione, Eredità'          : 'e.g. Donation, Inheritance';
  String get remaining            => _it ? 'Rimanente: '                      : 'Remaining: ';
  String get editExpenseTitle     => _it ? 'Modifica spesa'                   : 'Edit Expense';
  String get incomeDateLabel      => _it ? 'Data reddito'                     : 'Income Date';

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

  // ── Allocation ───────────────────────────────────────────
  String get noMarketValues    => _it ? 'Nessun valore di mercato disponibile.' : 'No market values available.';
  String get noData            => _it ? 'Nessun dato'               : 'No data';
  String get concentrationRisk => _it ? 'Rischio concentrazione'    : 'Concentration Risk';
  String get unclassified      => _it ? 'Non classificato'          : 'Unclassified';
  String get allocGeographic   => _it ? 'Allocazione geografica'    : 'Geographic Allocation';
  String get allocSector       => _it ? 'Allocazione settoriale'    : 'Sector Allocation';
  String get allocAssetType    => _it ? 'Tipo di attività'          : 'Asset Type';
  String get allocCurrency     => _it ? 'Esposizione valutaria'     : 'Currency Exposure';
  String get allocTopHoldings  => _it ? 'Principali posizioni'      : 'Top Holdings';
  String get allocPortfolioVal => _it ? 'Valore portafoglio'        : 'Portfolio Value';
  String get allocHoldings     => _it ? 'Posizioni'                 : 'Holdings';
  String get allocWellDiversified       => _it ? 'Ben diversificato'              : 'Well diversified';
  String get allocModeratelyConcentrated => _it ? 'Moderatamente concentrato'     : 'Moderately concentrated';
  String get allocHighlyConcentrated    => _it ? 'Altamente concentrato'          : 'Highly concentrated';

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
  String get dbPickerGuideMe      => _it ? 'Inizia il tour'           : 'Start Tour';
  String get guideMeChooseFolder  => _it ? 'Scegli una cartella per i file demo' : 'Choose a folder for demo files';
  String get guideMeDialogTitle  => _it ? 'Tour guidato'                       : 'Guided Tour';
  String get guideMeDialogBody   => _it
      ? 'Questo tour ti guiderà passo dopo passo nella configurazione di FinanceCopilot.\n\n'
        'Verranno creati dei file CSV demo e un database vuoto per esercitarti con le importazioni.\n\n'
        'I file demo verranno salvati in:'
      : 'This tour will walk you through setting up FinanceCopilot step by step.\n\n'
        'Demo CSV files and an empty database will be created so you can practice importing data.\n\n'
        'Demo files will be saved to:';
  String get guideMeStart        => _it ? 'Inizia il tour'                     : 'Start Tour';
  String get guideMeChangePath   => _it ? 'Cambia cartella...'                 : 'Change folder...';

  // ── Guided Tour ─────────────────────────────────────────
  String get tourStepNewProject     => _it ? 'Clicca qui per creare un nuovo database' : 'Click here to create a new database';
  String get tourStepNavAccounts    => _it ? 'Vai ai Conti per importare le transazioni' : 'Go to Accounts to import transactions';
  String get tourStepAccountsImport => _it ? 'Clicca per importare il file transazioni demo' : 'Click to import the demo transactions file';
  String get tourStepNavAssets      => _it ? 'Vai agli Investimenti per importare gli eventi' : 'Go to Assets to import events';
  String get tourStepAssetsImport   => _it ? 'Clicca per importare il file eventi demo' : 'Click to import the demo asset events file';
  String get tourStepNavAdjustments => _it ? 'Vai agli Aggiustamenti per creare una rettifica' : 'Go to Adjustments to create one';
  String get tourStepAdjustmentsFab => _it ? 'Clicca per creare un nuovo aggiustamento' : 'Click to create a new adjustment';
  String get tourStepNavIncome      => _it ? 'Vai al Reddito per importare i dati' : 'Go to Income to import records';
  String get tourStepIncomeImport   => _it ? 'Clicca per importare il file reddito demo' : 'Click to import the demo income file';
  String get tourComplete           => _it ? 'Tutto pronto! Esplora la tua dashboard.' : "You're all set! Explore your dashboard.";
  String get tourSkip               => _it ? 'Salta il tour'            : 'Skip Tour';
  String tourTxNoFile(String path)   => _it
      ? 'Clicca "Apri file" e seleziona demo_transactions.csv dalla cartella:\n$path'
      : 'Click "Open File" and select demo_transactions.csv from:\n$path';
  String get tourTxSkipRows         => _it
      ? 'Questo file ha 5 righe di intestazione prima dei dati. Imposta "Salta righe" a 5 per ignorarle.'
      : 'This file has 5 header rows before the actual data. Set "Skip rows" to 5 to ignore them.';
  String get tourTxMapDate          => _it
      ? 'Mappa il campo "date" alla colonna "Data Operazione" dal menu a tendina.'
      : 'Map the "date" field to the "Data Operazione" column from the dropdown.';
  String get tourTxMapAmount        => _it
      ? 'Il file ha colonne separate per crediti (Entrate) e debiti (Uscite). Clicca "Formula" per combinarle: aggiungi +Entrate e −Uscite per calcolare l\'importo netto.'
      : 'This file has separate credit/debit columns. Click "Formula" to combine them: add +Entrate and −Uscite to compute the net amount.';
  String get tourTxMapDescription   => _it
      ? 'Mappa il campo "description" alla colonna "Descrizione".'
      : 'Map the "description" field to the "Descrizione" column.';
  String get tourTxBalance          => _it
      ? '"Saldo per riga" calcola il saldo dopo ogni transazione.\n"Da colonna" = prende il saldo dal CSV.\n"Somma cumulativa" = lo calcola automaticamente.\n"Somma filtrata" = come cumulativa ma filtra per stato (es. solo "Executed").'
      : '"Balance per row" computes the balance after each transaction.\n"From column" = takes it from the CSV.\n"Cumulative sum" = computes it automatically.\n"Filtered sum" = like cumulative but filters by status (e.g. only "Executed").';
  String get tourTxDedup            => _it
      ? 'Le "Colonne chiave dedup" servono per evitare duplicati. Seleziona le colonne che identificano univocamente una riga. Se reimporti lo stesso file in futuro, le righe già presenti verranno saltate automaticamente.'
      : '"Dedup key columns" prevent duplicates when re-importing. Select columns that uniquely identify a row. If you re-import the same file later, rows already in the database will be skipped automatically.';
  String get tourTxNext             => _it
      ? 'Tutto pronto! Premi Avanti per procedere al riepilogo.'
      : 'All set! Press Next to proceed to the summary.';
  String get tourContinue           => _it ? 'Continua'                      : 'Continue';
  String tourAssetNoFile(String path) => _it
      ? '1/4 — Clicca "Apri file" e seleziona demo_asset_events.csv dalla cartella:\n$path'
      : '1/4 — Click "Open File" and select demo_asset_events.csv from:\n$path';
  String get tourAssetMapping       => _it
      ? '2/4 — Mappa le colonne: "Codice ISIN" → isin, "Operazione" → type, "Quantità" → quantity, "Prezzo" → price, "Controvalore" → amount, "Commissione" → fee (colonna), "Divisa" → currency, "Cambio" → exchangeRate. Poi premi Avanti.'
      : '2/4 — Map columns: "Codice ISIN" → isin, "Operazione" → type, "Quantità" → quantity, "Prezzo" → price, "Controvalore" → amount, "Commissione" → fee (column), "Divisa" → currency, "Cambio" → exchangeRate. Then press Next.';
  String tourIncomeNoFile(String path) => _it
      ? '1/4 — Clicca "Apri file" e seleziona demo_income.csv dalla cartella:\n$path'
      : '1/4 — Click "Open File" and select demo_income.csv from:\n$path';
  String get tourIncomeMapping      => _it
      ? '2/4 — Le colonne dovrebbero mapparsi automaticamente. Verifica la mappatura e premi Avanti.'
      : '2/4 — Columns should auto-map. Verify the mapping and press Next.';
  String get tourImportStep2        => _it
      ? '3/4 — Controlla il riepilogo. Per le transazioni, seleziona o crea un conto. Poi premi Importa.'
      : '3/4 — Review the summary. For transactions, select or create an account. Then press Import.';
  String get tourImportStep3        => _it
      ? '4/4 — Importazione completata! Premi Fatto per tornare indietro e continuare il tour.'
      : '4/4 — Import complete! Press Done to go back and continue the tour.';
  String get tourGotIt              => _it ? 'Ho capito!'               : 'Got it!';
}
