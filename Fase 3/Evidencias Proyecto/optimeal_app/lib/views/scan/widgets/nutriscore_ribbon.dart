import 'package:flutter/material.dart';

/// Cinta Nutri-Score A–E con la letra [activeLetter] resaltada.
class NutriScoreRibbon extends StatelessWidget {
  final String? activeLetter;
  final double height;
  final double radius;

  const NutriScoreRibbon({
    super.key,
    required this.activeLetter,
    this.height = 44,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letters = const ['A', 'B', 'C', 'D', 'E'];

    // Colores clásicos aproximados Nutri-Score
    final colorByLetter = <String, Color>{
      'A': const Color(0xFF2ECC71), // verde
      'B': const Color(0xFF8BC34A), // verde lima
      'C': const Color(0xFFFFC107), // ámbar
      'D': const Color(0xFFFF9800), // naranja
      'E': const Color(0xFFE53935), // rojo
    };

    final active = (activeLetter ?? '').toUpperCase().trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Row(
        children: [
          for (final l in letters)
            Expanded(
              child: _NutriCell(
                label: l,
                color: colorByLetter[l]!,
                active: active == l,
                height: height,
                outlineColor: cs.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _NutriCell extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final double height;
  final Color outlineColor;

  const _NutriCell({
    required this.label,
    required this.color,
    required this.active,
    required this.height,
    required this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    // Si está activa: color sólido; si no: atenuado
    final bg =
        active ? color : Color.alphaBlend(Colors.white.withOpacity(.5), color);
    final textColor = active ? Colors.white : Colors.white.withOpacity(.85);
    final fontWeight = active ? FontWeight.w900 : FontWeight.w600;
    final scale = active ? 1.08 : 1.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(color: outlineColor.withOpacity(.25), width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: fontWeight,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
