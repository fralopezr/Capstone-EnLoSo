// lib/views/scan/ranking_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RankingPage extends StatefulWidget {
  final String? idCategoria;      // OPCIONAL
  final String? nombreCategoria;  // OPCIONAL, solo para título/visual

  const RankingPage({
    super.key,
    this.idCategoria,
    this.nombreCategoria,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  bool _fetching = false;
  String _nutrienteColTitle = 'Nutriente';

  // ---------- Helper para capitalizar ----------
  String _toTitleCase(String? input) {
    if (input == null) return '';
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
  // ---------------------------------------------

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _ensureTop5();
    // La posición del producto ya la deja lista el AuthProvider al insertarProducto.
  }

  Future<void> _ensureTop5() async {
    final auth = context.read<AuthProvider>();

    // 1) Param, 2) última del provider, 3) meta
    String? targetCat = widget.idCategoria ??
        auth.lastTop5Categoria ??
        (auth.top5Meta != null
            ? auth.top5Meta!['idCategoria']?.toString()
            : null);

    // Si ya tenemos top5 para esa categoría, no recargamos
    if (auth.hasTop5 &&
        targetCat != null &&
        auth.lastTop5Categoria == targetCat) return;

    if (targetCat == null) return; // sin categoría, no forzar fetch

    setState(() => _fetching = true);
    await auth.obtenerTop5Ranking(
      idCategoria: targetCat,
      useGlobalLoading: false,
      updateState: true,
    );
    if (mounted) setState(() => _fetching = false);
  }

  String _criterioLabel(String? c) {
    switch (c) {
      case 'alta_proteinas':
        return 'Alta en proteínas';
      case 'baja_calorias':
        return 'Baja en calorías';
      case 'alta_calcio':
        return 'Alta en calcio';
      case 'equilibrada':
        return 'Equilibrada';
      default:
        return c ?? '—';
    }
  }

  String _nutrienteTitulo(String? c) {
    switch (c) {
      case 'alta_proteinas':
        return 'Proteínas (g)';
      case 'baja_calorias':
        return 'Energía (kcal)';
      case 'alta_calcio':
        return 'Calcio (mg)';
      case 'equilibrada':
        return 'Score';
      default:
        return 'Nutriente';
    }
  }

  num? _valorNutriente(Map<String, dynamic> item, String? c) {
    switch (c) {
      case 'alta_proteinas':
        return item['proteinas_g'] as num?;
      case 'baja_calorias':
        return item['energia_kcal'] as num?;
      case 'alta_calcio':
        return item['calcio_mg'] as num?;
      case 'equilibrada':
        return item['score'] as num?;
      default:
        return null;
    }
  }

  String _fmtNum(num? v) {
    if (v == null) return '—';
    return (v % 1 == 0) ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  Future<void> _refresh(AuthProvider auth) async {
    final targetCat = widget.idCategoria ??
        auth.lastTop5Categoria ??
        (auth.top5Meta != null
            ? auth.top5Meta!['idCategoria']?.toString()
            : null);

    if (targetCat == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No hay categoría seleccionada para actualizar el ranking.'),
        ),
      );
      return;
    }

    setState(() => _fetching = true);

    await auth.obtenerTop5Ranking(
      idCategoria: targetCat,
      useGlobalLoading: false,
      updateState: true,
    );

    // Si hay un último producto conocido, refrescamos su posición también
    final lastProdId = auth.lastPosicionProductoId;
    if (lastProdId != null && lastProdId.isNotEmpty) {
      await auth.obtenerPosicionProducto(
        idProducto: lastProdId,
        useGlobalLoading: false,
        updateState: true,
      );
    }

    if (mounted) setState(() => _fetching = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    // criterio dominante (uniforme en la respuesta)
    final criterio =
        auth.top5.isNotEmpty ? (auth.top5.first['criterio'] as String?) : null;
    _nutrienteColTitle = _nutrienteTitulo(criterio);

    // Nombre legible de categoría: 1) desde top5, 2) del parámetro, 3) meta
    final String? catNombre = () {
      String? raw;
      if (auth.top5.isNotEmpty) {
        raw = auth.top5.first['nombre_categoria']?.toString();
      } else if (widget.nombreCategoria != null &&
          widget.nombreCategoria!.isNotEmpty) {
        raw = widget.nombreCategoria;
      } else {
        raw = auth.top5Meta?['nombre_categoria']?.toString();
      }

      if (raw == null || raw.isEmpty) return null;
      return _toTitleCase(raw);
    }();

    // Producto a resaltar: último del que el provider conoce posición
    final String? highlightedId = auth.lastPosicionProductoId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.nombreCategoria != null && widget.nombreCategoria!.isNotEmpty
              ? _toTitleCase(widget.nombreCategoria)
              : 'Ranking',
        ),
        actions: [
          if (_fetching || auth.loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(auth),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: auth.top5.isEmpty && (_fetching || auth.loading)
              ? const Center(child: CircularProgressIndicator())
              : auth.top5.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Aún no hay datos de ranking para mostrar.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _refresh(auth),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Obtener ranking'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado con criterio y categoría
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                    'Criterio: ${_criterioLabel(criterio)}'),
                                avatar: const Icon(Icons.rule, size: 18),
                              ),
                              if (catNombre != null && catNombre.isNotEmpty)
                                Chip(
                                  label: Text('Categoría: $catNombre'),
                                  avatar: const Icon(
                                    Icons.category_outlined,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Top 5 de la categoría',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),

                          // Lista de cards para el Top 5
                          ...List.generate(
                            auth.top5.length.clamp(0, 5),
                            (i) {
                              final item = auth.top5[i];
                              final isHighlighted =
                                  highlightedId != null &&
                                      item['id_producto']?.toString() ==
                                          highlightedId;

                              return _buildTop5ItemCard(
                                theme: theme,
                                index: i,
                                item: item,
                                criterio: criterio,
                                isHighlighted: isHighlighted,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mostrando ${auth.top5.length.clamp(0, 5)} de 5',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Producto destacado debajo del Top 5 (si existe)
                          if (auth.hasPosicionProducto)
                            _buildProductoDestacadoSection(
                              theme: theme,
                              auth: auth,
                              criterioDefault: criterio,
                              catNombre: catNombre,
                            ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ------- UI helpers -------

  Widget _buildTop5ItemCard({
    required ThemeData theme,
    required int index,
    required Map<String, dynamic> item,
    required String? criterio,
    required bool isHighlighted,
  }) {
    final nombre = _toTitleCase((item['nombre'] ?? '—').toString());
    final marca = _toTitleCase((item['marca'] ?? '—').toString());
    final valorNutriente = _valorNutriente(item, criterio);
    final nutrienteText = _fmtNum(valorNutriente);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(
                color: theme.colorScheme.primary,
                width: 1.6,
              )
            : BorderSide.none,
      ),
      color: isHighlighted
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nº de posición
            CircleAvatar(
              radius: 16,
              backgroundColor: isHighlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondaryContainer,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isHighlighted
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // NOMBRE + MARCA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isHighlighted ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    marca,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // BLOQUE DERECHO: valor + título nutriente
            SizedBox(
              width: 90, // ajustable
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nutrienteText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isHighlighted ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _nutrienteColTitle,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoDestacadoSection({
    required ThemeData theme,
    required AuthProvider auth,
    required String? criterioDefault,
    required String? catNombre,
  }) {
    final prod = auth.posicionProducto;
    final meta = auth.posicionMeta;

    if (prod == null) {
      return Text(
        'No se pudo obtener la posición de este producto en tu ranking.',
        style: theme.textTheme.bodyMedium,
      );
    }

    final criterioProd = (prod['criterio'] ?? criterioDefault) as String?;
    final posicion = prod['posicion'] as int?;
    final nombre = _toTitleCase((prod['nombre'] ?? '—').toString());
    final marca = _toTitleCase((prod['marca'] ?? '—').toString());
    final valorNutriente = _valorNutriente(prod, criterioProd);
    final nutrienteText = _fmtNum(valorNutriente);

    String categoriaTexto;
    if (catNombre != null && catNombre.isNotEmpty) {
      categoriaTexto = catNombre;
    } else {
      categoriaTexto = _toTitleCase(
        prod['nombre_categoria']?.toString() ?? 'tu ranking',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu producto en el ranking',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.8,
            ),
          ),
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Posición grande
                Column(
                  children: [
                    Text(
                      posicion?.toString() ?? '—',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'posición',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        marca,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _criterioLabel(criterioProd),
                                maxLines: 1,
                              ),
                            ),
                            avatar: const Icon(
                              Icons.star_rate_rounded,
                              size: 18,
                            ),
                          ),
                          if (categoriaTexto.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Categoría: $categoriaTexto',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        nutrienteText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nutrienteColTitle,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(
            'Basado en tu perfil y preferencias nutricionales.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
