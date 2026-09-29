import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/market/exchange_rate_service.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/formatters.dart' as fmt;

class PillarCreateDialog extends ConsumerStatefulWidget {
  final Pillar? existing;

  /// When creating a new pillar, specifies whether it is a standard partition
  /// pillar or a virtual (overlapping) portfolio. Ignored in edit mode
  /// (the kind of an existing pillar is never changed).
  final PillarKind kind;

  const PillarCreateDialog({super.key, this.existing, this.kind = PillarKind.standard});

  @override
  ConsumerState<PillarCreateDialog> createState() => _PillarCreateDialogState();
}

class _PillarCreateDialogState extends ConsumerState<PillarCreateDialog> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late String _currency;
  String? _portfolioModelId;

  /// A save is running: the Create/Save button is disabled so a second tap
  /// cannot store the pillar twice.
  bool _saving = false;

  /// The target text the locale could not read at the last save attempt:
  /// flagged on the field until edited, and nothing was saved.
  bool _targetInvalid = false;

  /// The locale the target is pre-filled in and read back with: the stored
  /// one, adopted once it has loaded — null until then, and Save waits.
  String? _locale;

  /// The effective kind: use the existing pillar's kind in edit mode,
  /// otherwise use the kind passed to the dialog.
  PillarKind get _kind => widget.existing?.kind ?? widget.kind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController();
    ref.listenManual(appLocaleProvider, (_, next) => _adoptLocale(next.value), fireImmediately: true);
    _currency = e?.targetCurrency ?? 'EUR';
    _portfolioModelId = e?.portfolioModelId;
  }

  /// Adopts the first [locale] that loads and pre-fills the stored target in
  /// it, formatted with the NumberFormat that parses the field on save:
  /// `.toString()` would emit Dart's "5000.0", which it_IT reads as 50000.
  /// Every digit of the stored target (fmt.editableFigure): a target left
  /// alone saves unchanged, not rounded to two decimals. Text typed meanwhile
  /// is kept.
  void _adoptLocale(String? locale) {
    if (locale == null || _locale != null) return;
    setState(() => _locale = locale);
    final target = widget.existing?.targetValue;
    if (target == null || _target.text.isNotEmpty) return;
    _target.text = fmt.editableFigure(target, NumberFormat('#0.##', locale), locale: locale);
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final locale = _locale;
    final modelsAsync = ref.watch(portfolioModelsProvider);
    final isEdit = widget.existing != null;
    final isVirtual = _kind == PillarKind.virtual;

    final title = isEdit
        ? (isVirtual ? s.virtualPortfolioEditTitle : s.pillarEditTitle)
        : (isVirtual ? s.virtualPortfolioCreateTitle : s.pillarCreateTitle);

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: s.pillarFieldName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            // Objective (target value + currency) is only shown for standard pillars.
            if (!isVirtual) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: s.pillarFieldTargetValue,
                        errorText: _targetInvalid ? s.invalidNumber : null,
                      ),
                      onChanged: (_) {
                        if (_targetInvalid) setState(() => _targetInvalid = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(labelText: s.pillarFieldTargetCurrency),
                      items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            modelsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(s.error(e)),
              data: (models) => DropdownButtonFormField<String?>(
                initialValue: _portfolioModelId,
                decoration: InputDecoration(labelText: s.portfolioModelField),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(s.portfolioModelNone),
                  ),
                  for (final model in models)
                    DropdownMenuItem<String?>(
                      value: model.id,
                      child: Text(portfolioModelSummary(s, model, withName: true)),
                    ),
                ],
                onChanged: (v) => setState(() => _portfolioModelId = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _saving || locale == null ? null : () => _save(context, locale, s),
          child: Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, String locale, AppStrings s) async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // Virtual portfolios never have a target value. An empty field means no
    // target; text the locale cannot read is flagged, never saved as "none".
    final target = fmt.readOptionalNumber(_kind == PillarKind.virtual ? '' : _target.text, locale: locale);
    if (target.invalid) {
      setState(() => _targetInvalid = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = ref.read(pillarServiceProvider);
      if (widget.existing == null) {
        await svc.create(
          name: name,
          targetValue: target.value,
          targetCurrency: _currency,
          portfolioModelId: _portfolioModelId,
          kind: _kind,
        );
      } else {
        await svc.update(
          widget.existing!.id,
          name: name,
          targetValue: target.value,
          clearTargetValue: target.value == null,
          targetCurrency: _currency,
          portfolioModelId: _portfolioModelId,
          clearPortfolioModel: _portfolioModelId == null,
        );
      }
      if (context.mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Display name of a portfolio model [variant].
String portfolioModelVariantLabel(AppStrings s, PortfolioModelVariant variant) => switch (variant) {
  PortfolioModelVariant.full => s.portfolioModelFull,
  PortfolioModelVariant.mini => s.portfolioModelMini,
  PortfolioModelVariant.custom => s.portfolioModelCustom,
};

/// One-line summary of a portfolio model, "Year · equity · variant", for
/// every list of models; [withName] puts the model name first (the picker,
/// where the name is not shown beside it).
String portfolioModelSummary(AppStrings s, PortfolioModel model, {bool withName = false}) => [
  if (withName) model.name,
  if (model.year != null) s.portfolioModelYear(model.year!),
  if (model.equityPercent != null) s.portfolioModelEquity(model.equityPercent!),
  portfolioModelVariantLabel(s, model.variant),
].join(' · ');

/// Stored exchange rate turning an amount in `pair.$1` into `pair.$2` as of
/// today; null when none is stored.
final _storedRateProvider = FutureProvider.family<double?, (String, String)>((ref, pair) {
  ref.watch(priceRefreshCounter); // rates are synced with the prices
  final today = ref.watch(currentDateProvider);
  return ref.watch(exchangeRateServiceProvider).getRate(pair.$1, pair.$2, today);
});

/// [pillar]'s target in [baseCurrency], the currency its value is measured in:
/// the target itself when it is already in that currency, else converted at
/// today's stored rate. Null without a target, while the rate loads, or when
/// no rate is stored — the progress is then unknown, never measured across
/// currencies.
double? pillarTargetInBase(WidgetRef ref, Pillar pillar, String baseCurrency) {
  final target = pillar.targetValue;
  if (target == null || target <= 0) return null;
  if (pillar.targetCurrency == baseCurrency) return target;
  final rate = ref.watch(_storedRateProvider((pillar.targetCurrency, baseCurrency))).value;
  return rate == null ? null : target * rate;
}
