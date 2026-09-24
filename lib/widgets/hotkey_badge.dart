import 'package:flutter/material.dart';
import '../theme/tide_colors.dart';

class HotkeyBadge extends StatelessWidget {
  final String shortcutText;
  final bool isHighlighted;

  const HotkeyBadge({
    super.key,
    required this.shortcutText,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = shortcutText.split(' ').where((s) => s.isNotEmpty).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tokens.map((token) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isHighlighted ? TideColors.brand.withValues(alpha: 0.1) : TideColors.bgSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlighted ? TideColors.brand.withValues(alpha: 0.4) : TideColors.border,
              width: 1,
            ),
          ),
          child: Text(
            token,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isHighlighted ? TideColors.brand : TideColors.text,
            ),
          ),
        );
      }).toList(),
    );
  }
}
