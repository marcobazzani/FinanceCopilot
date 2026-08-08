import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_copilot/services/market/web_market_data_service.dart';
import '../../services/providers/providers.dart';
import 'isin_url_paste_recovery.dart';

/// Reusable asset search results section.
/// Shows a search field, debounces queries, and renders a result list.
/// Calls [onSelect] when the user taps a result.
///
/// When the search returns no results, optionally falls back to an
/// [IsinUrlPasteRecovery] widget so the user can paste a known URL/ISIN.
/// To enable, supply both [recoveryCacheKeyBuilder] and
/// [recoveryDefaultExchange]; otherwise a "no results" placeholder is shown.
class AssetSearchSection extends StatefulWidget {
  final WidgetRef widgetRef;
  final ValueChanged<ProviderSearchResult> onSelect;
  final String Function(String query)? recoveryCacheKeyBuilder;
  final String? recoveryDefaultExchange;

  /// Fires whenever the search returns a fresh list of results (including
  /// the empty-list case). Lets the caller derive sibling listings, etc.
  final ValueChanged<List<ProviderSearchResult>>? onResultsChanged;

  /// Fires on every search-field text change (debounced or not).
  final ValueChanged<String>? onQueryChanged;
  const AssetSearchSection({
    super.key,
    required this.widgetRef,
    required this.onSelect,
    this.recoveryCacheKeyBuilder,
    this.recoveryDefaultExchange,
    this.onResultsChanged,
    this.onQueryChanged,
  });

  @override
  State<AssetSearchSection> createState() => _AssetSearchSectionState();
}

/// Preferred dialog width for the section; clamped down on narrow screens.
const _maxWidth = 400.0;

class _AssetSearchSectionState extends State<AssetSearchSection> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ProviderSearchResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onQueryChanged?.call(query);
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      widget.onResultsChanged?.call(const []);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final service = widget.widgetRef.read(marketPriceServiceProvider) as WebMarketDataService;
      try {
        final results = await service.search(query.trim());
        if (mounted && _searchCtrl.text.trim() == query.trim()) {
          setState(() {
            _results = results;
            _searching = false;
          });
          widget.onResultsChanged?.call(results);
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.widgetRef.read(appStringsProvider);
    // TIGHT width, deliberately not a loose `maxWidth` constraint: every call
    // site is an AlertDialog, and AlertDialog measures its content's intrinsic
    // width. The results list below is a shrink-wrapping viewport that cannot
    // report intrinsics (it would have to build every child), so a loose
    // constraint made the dialog throw the moment a search returned results.
    // Sizing here rather than at each call site keeps the three dialogs
    // (create asset, edit asset, portfolio model) from drifting apart again.
    // Dialogs inset 40px per side, so never ask for more than is available.
    final available = MediaQuery.sizeOf(context).width - 80;
    return SizedBox(
      width: available <= 0 ? _maxWidth : math.min(_maxWidth, available),
      height: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: s.search,
              hintText: s.searchAssetsHint,
              prefixIcon: const Icon(Icons.search),
            ),
            autofocus: true,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(r.description, overflow: TextOverflow.ellipsis, maxLines: 1),
                    subtitle: Text(
                      '${r.symbol}  ·  ${r.type}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Text(r.flag, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () => widget.onSelect(r),
                  );
                },
              ),
            )
          else if (_searchCtrl.text.trim().length >= 3)
            Expanded(
              child: widget.recoveryCacheKeyBuilder != null && widget.recoveryDefaultExchange != null
                  ? SingleChildScrollView(
                      child: IsinUrlPasteRecovery(
                        userQuery: _searchCtrl.text.trim(),
                        cacheKey: widget.recoveryCacheKeyBuilder!(_searchCtrl.text.trim()),
                        defaultExchange: widget.recoveryDefaultExchange!,
                        onResolved: widget.onSelect,
                      ),
                    )
                  : Center(
                      child: Text(s.noResultsFound, style: const TextStyle(color: Colors.grey)),
                    ),
            )
          else
            Expanded(
              child: Center(
                child: Text(s.typeAtLeast3Chars, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}
