import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/investing_com_service.dart';
import '../../services/providers/providers.dart';

/// Reusable asset search results section.
/// Shows a search field, debounces queries, and renders a result list.
/// Calls [onSelect] when the user taps a result.
class AssetSearchSection extends StatefulWidget {
  final WidgetRef widgetRef;
  final ValueChanged<InvestingSearchResult> onSelect;
  const AssetSearchSection({super.key, required this.widgetRef, required this.onSelect});

  @override
  State<AssetSearchSection> createState() => _AssetSearchSectionState();
}

class _AssetSearchSectionState extends State<AssetSearchSection> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<InvestingSearchResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final service = widget.widgetRef.read(marketPriceServiceProvider) as InvestingComService;
      try {
        final results = await service.search(query.trim());
        if (mounted && _searchCtrl.text.trim() == query.trim()) {
          setState(() {
            _results = results;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.widgetRef.read(appStringsProvider);
    return SizedBox(
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
              child: Center(
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
