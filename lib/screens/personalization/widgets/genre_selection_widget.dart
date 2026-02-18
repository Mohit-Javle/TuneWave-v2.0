import 'package:flutter/material.dart';

class GenreSelectionWidget extends StatefulWidget {
  final List<String> selectedGenres;
  final Function(List<String>) onSelectionChanged;

  const GenreSelectionWidget({
    super.key,
    required this.selectedGenres,
    required this.onSelectionChanged,
  });

  @override
  State<GenreSelectionWidget> createState() => _GenreSelectionWidgetState();
}

class _GenreSelectionWidgetState extends State<GenreSelectionWidget> {
  final List<String> _allGenres = [
    'Pop',
    'Hip Hop',
    'Punjabi',
    'Bollywood',
    'Rock',
    'Classical',
    'Jazz',
    'Electronic',
    'R&B',
    'Devotional',
    'Folk',
    'Indie',
  ];

  void _toggleGenre(String genre) {
    final newSelection = List<String>.from(widget.selectedGenres);
    if (newSelection.contains(genre)) {
      newSelection.remove(genre);
    } else {
      newSelection.add(genre);
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Pick at least 3 genres",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _allGenres.map((genre) {
              final isSelected = widget.selectedGenres.contains(genre);
              return FilterChip(
                label: Text(genre),
                selected: isSelected,
                onSelected: (_) => _toggleGenre(genre),
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                selectedColor: const Color(0xFFFF6600),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFFF6600) : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            "${widget.selectedGenres.length} of ${_allGenres.length} selected",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
