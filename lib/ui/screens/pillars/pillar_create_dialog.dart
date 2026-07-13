import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import '../../../l10n/app_strings.dart';
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

  /// The effective kind: use the existing pillar's kind in edit mode,
  /// otherwise use the kind passed to the dialog.
  PillarKind get _kind => widget.existing?.kind ?? widget.kind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    // Format with the user's locale so the same NumberFormat that parses
    // the field on save round-trips the value cleanly. Using `.toString()`
    // would emit Dart's "5000.0" — in IT locale that '.' parses as a
    // thousands separator and saves 50000.
    final locale = ref.read(appLocaleProvider).value ?? 'en';
    final fmtNum = NumberFormat('#0.##', locale);
    _target = TextEditingController(
      text: e?.targetValue == null ? '' : fmtNum.format(e!.targetValue),
    );
    _currency = e?.targetCurrency ?? 'EUR';
    _portfolioModelId = e?.portfolioModelId;
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
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
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
                      decoration: InputDecoration(labelText: s.pillarFieldTargetValue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(labelText: s.pillarFieldTargetCurrency),
                      items: const [
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        DropdownMenuItem(value: 'CHF', child: Text('CHF')),
                      ],
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
                      child: Text(_modelLabel(s, model)),
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
          onPressed: () => _save(context, locale, s),
          child: Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, String locale, AppStrings s) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final svc = ref.read(pillarServiceProvider);
    final isVirtual = _kind == PillarKind.virtual;
    // Virtual portfolios never have a target value.
    final targetTxt = isVirtual ? '' : _target.text.trim();
    final target = targetTxt.isEmpty ? null : fmt.tryParseLocalized(targetTxt, locale: locale);
    if (widget.existing == null) {
      await svc.create(
        name: name,
        targetValue: target,
        targetCurrency: _currency,
        portfolioModelId: _portfolioModelId,
        kind: _kind,
      );
    } else {
      await svc.update(
        widget.existing!.id,
        name: name,
        targetValue: target,
        clearTargetValue: target == null,
        targetCurrency: _currency,
        portfolioModelId: _portfolioModelId,
        clearPortfolioModel: _portfolioModelId == null,
      );
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  String _modelLabel(AppStrings s, PortfolioModel model) {
    final parts = <String>[model.name];
    if (model.year != null) parts.add(s.portfolioModelYear(model.year!));
    if (model.equityPercent != null) {
      parts.add(s.portfolioModelEquity(model.equityPercent!));
    }
    parts.add(switch (model.variant) {
      PortfolioModelVariant.full => s.portfolioModelFull,
      PortfolioModelVariant.mini => s.portfolioModelMini,
      PortfolioModelVariant.custom => s.portfolioModelCustom,
    });
    return parts.join(' · ');
  }
}
