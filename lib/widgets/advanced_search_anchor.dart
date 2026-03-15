import 'package:flutter/material.dart';

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final dynamic originalObject;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    this.originalObject,
  });
}

class AdvancedSearchAnchor extends StatefulWidget {
  final String hintText;
  final Future<List<SearchResult>> Function(String) onSearchQuery;
  final ValueChanged<SearchResult> onResultSelected;
  final VoidCallback? onClear;

  const AdvancedSearchAnchor({
    super.key,
    required this.hintText,
    required this.onSearchQuery,
    required this.onResultSelected,
    this.onClear,
  });

  @override
  State<AdvancedSearchAnchor> createState() => _AdvancedSearchAnchorState();
}

class _AdvancedSearchAnchorState extends State<AdvancedSearchAnchor> {
  final SearchController _controller = SearchController();
  List<SearchResult> _lastResults = [];
  bool _isLoading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() async {
    final query = _controller.text;
    if (query == _lastQuery) return;

    _lastQuery = query;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _lastResults = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await widget.onSearchQuery(query);
      if (mounted && query == _controller.text) {
        setState(() {
          _lastResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      builder: (context, controller) {
        return SearchBar(
          controller: controller,
          hintText: widget.hintText,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16.0),
          ),
          onTap: () {
            controller.openView();
          },
          leading: const Icon(Icons.search, color: Colors.white54),
          trailing: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _controller.clear();
                  if (widget.onClear != null) widget.onClear!();
                },
                icon: const Icon(Icons.clear, color: Colors.white54),
              ),
          ],
          backgroundColor: WidgetStatePropertyAll(
              const Color(0xFF1E293B).withValues(alpha: 0.5)),
          textStyle:
              const WidgetStatePropertyAll(TextStyle(color: Colors.white)),
          hintStyle:
              const WidgetStatePropertyAll(TextStyle(color: Colors.white54)),
        );
      },
      suggestionsBuilder: (context, controller) {
        if (_lastResults.isEmpty) {
          return [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Comece a digitar para pesquisar...',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          ];
        }

        // Group results by category
        final Map<String, List<SearchResult>> grouped = {};
        for (var res in _lastResults) {
          grouped.putIfAbsent(res.category, () => []).add(res);
        }

        final List<Widget> items = [];
        grouped.forEach((category, results) {
          items.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF00D1FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
          items.addAll(results.map((res) => ListTile(
                leading: Icon(res.icon, color: Colors.white70),
                title: Text(res.title,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(res.subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  controller.closeView(res.title);
                  widget.onResultSelected(res);
                },
              )));
        });

        return items;
      },
      viewBackgroundColor: const Color(0xFF0F172A),
    );
  }
}
