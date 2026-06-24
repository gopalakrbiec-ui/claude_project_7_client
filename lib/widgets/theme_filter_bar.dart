import 'package:flutter/material.dart';

/// Horizontally-scrollable filter chip row for template themes.
/// Shows an "All" chip plus one chip per available theme.
class ThemeFilterBar extends StatelessWidget {
  const ThemeFilterBar({
    super.key,
    required this.themes,
    required this.selected,
    required this.onSelected,
  });

  final List<String> themes;
  final String? selected; // null = "All"
  final void Function(String? theme) onSelected;

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final chips = [null, ...themes]; // null = "All"

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final value = chips[i];
          final isSelected = value == selected;
          final label = value == null ? 'All' : _capitalise(value);

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
