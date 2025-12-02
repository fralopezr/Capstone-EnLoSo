// lib/views/scan/widgets/optimeal_logo_title.dart
import 'package:flutter/material.dart';

class OptimealLogoTitle extends StatelessWidget {
  final bool showText;
  final double logoSize;

  const OptimealLogoTitle({
    super.key,
    this.showText = true,
    this.logoSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final children = <Widget>[
      Image.asset(
        'lib/assets/optimeal_logo.png',
        height: logoSize,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.fastfood, size: logoSize, color: cs.primary),
      )
    ];

    if (showText) {
      children.addAll([
        const SizedBox(width: 8),
        const Text(
          'OptiMeal',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
