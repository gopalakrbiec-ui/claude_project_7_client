import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../repositories/prompts_repository.dart';

/// Collapsible group tabs + chip grid for keyword tag selection.
/// [groups] should have the orientation group filtered out (it's handled
/// by the aspect ratio selector separately).
class KeywordTagPicker extends StatefulWidget {
  const KeywordTagPicker({
    super.key,
    required this.groups,
    required this.selected,
    required this.onToggle,
  });

  final List<KeywordGroup> groups;
  final Set<String> selected;
  final void Function(String tagKey) onToggle;

  @override
  State<KeywordTagPicker> createState() => _KeywordTagPickerState();
}

class _KeywordTagPickerState extends State<KeywordTagPicker> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final groups =
        widget.groups.where((g) => !g.isOrientation).toList();
    if (groups.isEmpty) return const SizedBox.shrink();

    if (_activeIndex >= groups.length) _activeIndex = 0;
    final active = groups[_activeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Group tab row ──────────────────────────────────────────────────
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final group = groups[i];
              final isActive = i == _activeIndex;
              final count = group.tags
                  .where((t) => widget.selected.contains(t.key))
                  .length;
              return GestureDetector(
                onTap: () => setState(() => _activeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? kSaffron.withValues(alpha: 0.10)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? kSaffron : Colors.grey.shade300,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(group.emoji,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        group.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? kSaffron
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: kSaffron,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // ── Tag chips for active group ──────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: active.tags.map((tag) {
            final sel = widget.selected.contains(tag.key);
            return GestureDetector(
              onTap: () => widget.onToggle(tag.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? kSaffron : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? kSaffron : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  tag.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // ── Selection summary ───────────────────────────────────────────────
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${widget.selected.length} tag${widget.selected.length > 1 ? 's' : ''} selected',
            style: const TextStyle(
              fontSize: 12,
              color: kSaffron,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
