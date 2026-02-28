import 'package:flutter/material.dart';

class MoodSelectionWidget extends StatefulWidget {
  final List<String> selectedMoods;
  final Function(List<String>) onSelectionChanged;

  const MoodSelectionWidget({
    super.key,
    required this.selectedMoods,
    required this.onSelectionChanged,
  });

  @override
  State<MoodSelectionWidget> createState() => _MoodSelectionWidgetState();
}

class _MoodSelectionWidgetState extends State<MoodSelectionWidget> {
  final List<Map<String, dynamic>> _moods = [
    {'label': 'While Working Out', 'icon': '🏃'},
    {'label': 'While Working / Studying', 'icon': '💼'},
    {'label': 'To Relax / Sleep', 'icon': '😴'},
    {'label': 'At Parties', 'icon': '🎉'},
    {'label': "When I'm in Love", 'icon': '❤️'},
    {'label': "When I'm Sad", 'icon': '😢'},
    {'label': 'While Commuting', 'icon': '🚗'},
    {'label': 'In the Morning', 'icon': '🌅'},
  ];

  void _toggleMood(String moodInfo) {
    final newSelection = List<String>.from(widget.selectedMoods);
    if (newSelection.contains(moodInfo)) {
      newSelection.remove(moodInfo);
    } else {
      newSelection.add(moodInfo);
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
        children: [
          Text(
            "Select all that apply",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5, // Wide cards
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _moods.length,
            itemBuilder: (context, index) {
              final mood = _moods[index];
              final label = mood['label'] as String;
              final icon = mood['icon'] as String;
              final isSelected = widget.selectedMoods.contains(label);

              return GestureDetector(
                onTap: () => _toggleMood(label),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFFF6600).withValues(alpha: 0.15) 
                        : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFFF6600) 
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xFFFF6600) 
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
