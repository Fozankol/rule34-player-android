import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../providers/feed_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();

  List<TagSuggestion> _suggestions = [];
  List<String> _history = [];
  List<String> _selectedTags = [];
  Timer? _debounceTimer;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    final feed = context.read<FeedProvider>();
    _selectedTags = List.from(feed.filterOptions.searchTags);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await _dbService.getSearchHistory();
    if (mounted) {
      setState(() {
        _history = list;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoadingSuggestions = true;
      });

      final results = await _apiService.fetchAutocomplete(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoadingSuggestions = false;
        });
      }
    });
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_selectedTags.contains(trimmed)) {
      setState(() {
        _selectedTags.add(trimmed);
        _textController.clear();
        _suggestions = [];
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  void _submitSearch() {
    final feed = context.read<FeedProvider>();
    feed.setSearchTags(_selectedTags);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F28),
        elevation: 0,
        title: TextField(
          controller: _textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Поиск тегов (напр. 3d, animation)...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _isLoadingSuggestions
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.greenAccent,
                      ),
                    ),
                  )
                : _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _textController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              _addTag(val);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _submitSearch,
            child: const Text(
              'Найти',
              style: TextStyle(
                color: Color(0xFF00C853),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Tags Chips
          if (_selectedTags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1B1B24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выбранные теги:',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedTags.map((tag) {
                      return Chip(
                        backgroundColor: const Color(0xFF00C853).withOpacity(0.2),
                        side: const BorderSide(color: Color(0xFF00C853), width: 0.8),
                        label: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                        onDeleted: () => _removeTag(tag),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Autocomplete suggestions list
          if (_suggestions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, idx) {
                  final item = _suggestions[idx];
                  return ListTile(
                    leading: const Icon(Icons.tag, color: Colors.greenAccent, size: 20),
                    title: Text(
                      item.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item.label,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.add, color: Colors.white30),
                    onTap: () => _addTag(item.value),
                  );
                },
              ),
            )
          else ...[
            // Search history
            if (_history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'История поиска',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _history.clear();
                        });
                      },
                      child: const Text(
                        'Очистить',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, idx) {
                    final item = _history[idx];
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.white30, size: 18),
                      title: Text(item, style: const TextStyle(color: Colors.white70)),
                      onTap: () => _addTag(item),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Введите название тега для поиска',
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
