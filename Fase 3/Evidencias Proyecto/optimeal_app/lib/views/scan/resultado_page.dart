// lib/views/scan/resultado_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scan_provider.dart';
import 'widgets/nutriscore_ribbon.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scanProv = context.watch<ScanProvider>();

    final nutrientes = (scanProv.nutrientes ?? {}).cast<String, dynamic>();
    final unidadBase = scanProv.unidadBase ?? '';
    final porcion = scanProv.porcion ?? '';
    final baseQty = scanProv.baseQty?.toString() ?? '';
    final nutriscore = (scanProv.nutriscoreOFF ?? {}).cast<String, dynamic>();
    final sellos = (scanProv.sellosCL ?? {}).cast<String, dynamic>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Resultado del producto'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Botón para ver recomendaciones (ranking) ---
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.recommend_outlined),
                label: const Text('Ver ranking de producto'),
                onPressed: () => Navigator.pushNamed(context, '/ranking'),
              ),
            ),
            _ResumenCard(
                unidadBase: unidadBase, porcion: porcion, baseQty: baseQty),

            const SizedBox(height: 12),
            _NutriScoreCard(nutri: nutriscore),

            const SizedBox(height: 12),
            _SellosCard(sellos: sellos),
            const SizedBox(height: 12),
            _NutrientesCard(nutrientes: nutrientes),
          ],
        ),
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final String unidadBase;
  final String porcion;
  final String baseQty;

  const _ResumenCard({
    required this.unidadBase,
    required this.porcion,
    required this.baseQty,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: text.bodyMedium,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ResumenItem(title: 'Unidad base', value: unidadBase),
              _ResumenItem(title: 'Porción', value: porcion),
              _ResumenItem(title: 'Base qty', value: baseQty),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenItem extends StatelessWidget {
  final String title;
  final String value;

  const _ResumenItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.labelMedium?.copyWith(color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(value.isEmpty ? '—' : value, style: text.titleMedium),
      ],
    );
  }
}

class _NutriScoreCard extends StatelessWidget {
  final Map<String, dynamic> nutri;
  const _NutriScoreCard({required this.nutri});

  Color _colorForGrade(String g, BuildContext context) {
    switch (g.toUpperCase()) {
      case 'A':
        return Colors.green.shade600;
      case 'B':
        return Colors.lightGreen.shade700;
      case 'C':
        return Colors.orange.shade700;
      case 'D':
        return Colors.deepOrange.shade700;
      case 'E':
        return Colors.red.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Estructura esperada: { nutriscore: { letter, final_score, inputs_100, neg_points, pos_points } }
    final root = nutri;
    final nested = (root['nutriscore'] is Map)
        ? (root['nutriscore'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final letter = (root['letter'] ?? nested['letter'] ?? '').toString();
    final score =
        (root['score'] ?? root['final_score'] ?? nested['final_score']);

    final neg = (nested['neg_points'] is Map)
        ? (nested['neg_points'] as Map).cast<String, dynamic>()
        : null;
    final pos = (nested['pos_points'] is Map)
        ? (nested['pos_points'] as Map).cast<String, dynamic>()
        : null;
    final inputs = (nested['inputs_100'] is Map)
        ? (nested['inputs_100'] as Map).cast<String, dynamic>()
        : null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _colorForGrade(letter, context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    letter.isEmpty ? '?' : letter.toUpperCase(),
                    style: text.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nutri-Score', style: text.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        letter.isEmpty
                            ? 'Sin información de Nutri-Score.'
                            : 'Letra: ${letter.toUpperCase()}${score != null ? '  •  Puntaje: $score' : ''}',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (letter.isNotEmpty) ...[
              const SizedBox(height: 12),
              NutriScoreRibbon(activeLetter: letter),
            ],

            // Detalle limpio (listas) en vez de JSON crudo
            if (neg != null || pos != null || inputs != null) ...[
              const SizedBox(height: 12),
              _NutriScoreDetail(neg: neg, pos: pos, inputs: inputs),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutriScoreDetail extends StatelessWidget {
  final Map<String, dynamic>? neg;
  final Map<String, dynamic>? pos;
  final Map<String, dynamic>? inputs;

  const _NutriScoreDetail({this.neg, this.pos, this.inputs});

  // Alias para etiquetas más humanas (puedes ampliar este diccionario)
  static const Map<String, String> _alias = {
    'energy_kj': 'Energía (kJ)',
    'energy_kcal': 'Energía (kcal)',
    'sugars': 'Azúcares (g)',
    'sodium': 'Sodio (mg)',
    'salt': 'Sal (g)',
    'sat_fat': 'Grasa saturada (g)',
    'saturated_fat': 'Grasa saturada (g)',
    'fiber': 'Fibra (g)',
    'protein': 'Proteínas (g)',
    'fruit_veg_nuts_pct': 'Frutas/Verduras/Frutos secos (%)',
  };

  String _labelize(String k) {
    final ak = _alias[k];
    if (ak != null) return ak;
    final s = k.replaceAll('_', ' ').trim();
    return s.isEmpty
        ? '—'
        : s
            .split(' ')
            .map((w) => w.isEmpty
                ? w
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
  }

  String _fmtVal(Object? v) {
    if (v == null) return '—';
    if (v is num) {
      return (v % 1 == 0) ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    return v.toString();
  }

  Widget _kvRow(BuildContext ctx, String left, String right) {
    final text = Theme.of(ctx).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(left, style: text.bodySmall)),
          if (right.isNotEmpty) Text(right, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _section(BuildContext ctx, String title, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(ctx).textTheme;

    final items = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 0,
      color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...items.map((e) {
              final k = _labelize(e.key);
              final v = e.value;

              if (v is Map) {
                final sub = v.cast<String, dynamic>().entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...sub.map((s) => _kvRow(
                          ctx, '• ${_labelize(s.key)}', _fmtVal(s.value))),
                    ],
                  ),
                );
              } else if (v is List) {
                if (v.isEmpty) return _kvRow(ctx, k, '—');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...v.map((item) => _kvRow(ctx, '• ${_fmtVal(item)}', '')),
                    ],
                  ),
                );
              }

              return _kvRow(ctx, k, _fmtVal(v));
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (inputs != null && inputs!.isNotEmpty)
          _section(context, 'Entradas (por 100)', inputs),
        if (neg != null && neg!.isNotEmpty)
          _section(context, 'Puntos negativos', neg),
        if (pos != null && pos!.isNotEmpty)
          _section(context, 'Puntos positivos', pos),
      ],
    );
  }
}

class _SellosCard extends StatelessWidget {
  final Map<String, dynamic> sellos;
  const _SellosCard({required this.sellos});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Estructura: { sellos_chile: { sellos: [], cumple_sin_sellos: bool, valores_100: {...} } }
    final sc = (sellos['sellos_chile'] is Map)
        ? (sellos['sellos_chile'] as Map).cast<String, dynamic>()
        : sellos;

    final List sel = (sc['sellos'] is List) ? (sc['sellos'] as List) : const [];
    final bool sinSellos = (sc['cumple_sin_sellos'] == true) || sel.isEmpty;
    final Map<String, dynamic> valores100 = (sc['valores_100'] is Map)
        ? (sc['valores_100'] as Map).cast<String, dynamic>()
        : const {};

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sellos (Chile)', style: text.titleLarge),
            const SizedBox(height: 8),
            if (sinSellos)
              Text('Sin sellos', style: text.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sel.map((e) {
                  final label = e.toString().replaceAll('_', ' ').toUpperCase();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: text.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (valores100.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Valores100Table(valores: valores100),
            ],
          ],
        ),
      ),
    );
  }
}

class _Valores100Table extends StatelessWidget {
  final Map<String, dynamic> valores;
  const _Valores100Table({required this.valores});

  @override
  Widget build(BuildContext context) {
    final entries = valores.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    String fmt(Object? v) {
      if (v is num) return (v % 1 == 0) ? v.toInt().toString() : v.toString();
      return v?.toString() ?? '—';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Valor (100)')),
          DataColumn(label: Text('Cantidad')),
        ],
        rows: entries
            .map((e) => DataRow(cells: [
                  DataCell(Text(e.key)),
                  DataCell(Text(fmt(e.value))),
                ]))
            .toList(),
      ),
    );
  }
}

class _NutrientesCard extends StatelessWidget {
  final Map<String, dynamic> nutrientes;
  const _NutrientesCard({required this.nutrientes});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Espera: { nutriente: { por_base: num, por_porcion: num } } o nutriente: num
    final filas = <_NutrienteFila>[];
    nutrientes.forEach((k, v) {
      if (v is Map) {
        final base = (v['por_base'] as num?)?.toDouble();
        final porcion = (v['por_porcion'] as num?)?.toDouble();
        filas
            .add(_NutrienteFila(nombre: k, porBase: base, porPorcion: porcion));
      } else if (v is num) {
        filas.add(
            _NutrienteFila(nombre: k, porBase: v.toDouble(), porPorcion: null));
      }
    });

    filas.sort((a, b) => a.nombre.compareTo(b.nombre));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrientes', style: text.titleLarge),
            const SizedBox(height: 8),
            if (filas.isEmpty)
              Text('Sin datos de nutrientes', style: text.bodyMedium)
            else
              _NutrientesTable(filas: filas),
          ],
        ),
      ),
    );
  }
}

class _NutrienteFila {
  final String nombre;
  final double? porBase;
  final double? porPorcion;
  _NutrienteFila({required this.nombre, this.porBase, this.porPorcion});
}

class _NutrientesTable extends StatelessWidget {
  final List<_NutrienteFila> filas;
  const _NutrientesTable({required this.filas});

  String _fmt(num? v) =>
      v == null ? '—' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nutriente')),
          DataColumn(label: Text('Por base')),
          DataColumn(label: Text('Por porción')),
        ],
        rows: filas.map((f) {
          return DataRow(cells: [
            DataCell(Text(f.nombre)),
            DataCell(Text(_fmt(f.porBase))),
            DataCell(Text(_fmt(f.porPorcion))),
          ]);
        }).toList(),
      ),
    );
  }
}
