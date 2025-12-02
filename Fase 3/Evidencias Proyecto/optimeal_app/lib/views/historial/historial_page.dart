// lib/views/historial/historial_page.dart
import 'package:flutter/material.dart';
import 'package:optimeal_app/services/historial_service.dart';
import 'package:optimeal_app/config.dart';
import 'package:provider/provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/auth_provider.dart'; // ← para ranking y posición
import '../scan/widgets/optimeal_logo_title.dart';

class HistorialPage extends StatefulWidget {
  final String idUsuario;
  const HistorialPage({super.key, required this.idUsuario});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final HistorialService historialService =
      HistorialService(baseUrl: API_BASE_LOCAL);
  late Future<List<Map<String, dynamic>>> _historialFuture;

  @override
  void initState() {
    super.initState();
    _historialFuture =
        historialService.obtenerHistorialPorUsuario(widget.idUsuario);
  }

  // Helper SOLO para capitalizar nombre, marca y categoría
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

  // dd-mm-yyyy sin dependencias
  String _fmtFechaDMY(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = v is DateTime ? v : DateTime.parse(v.toString());
      final l = dt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(l.day)}-${two(l.month)}-${l.year}';
    } catch (_) {
      return v.toString();
    }
  }

  // Construye el mapa de nutrientes desde el item del historial.
  // Asumimos base de 100 (g/ml) para cálculo de score/sellos.
  Map<String, dynamic> _nutrientesDesdeItem(Map<String, dynamic> item) {
    double? numOrNull(String k) {
      final v = item[k];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final n = double.tryParse(v.toString());
      return n;
    }

    return <String, dynamic>{
      'energia_kcal': numOrNull('energia_kcal'),
      'proteinas_g': numOrNull('proteinas_g'),
      'grasa_total_g': numOrNull('grasa_total_g'),
      'grasa_saturada_g': numOrNull('grasa_saturada_g'),
      'carbohidratos_g': numOrNull('carbohidratos_g'),
      'azucares_g': numOrNull('azucares_g'),
      'sodio_mg': numOrNull('sodio_mg'),
      // Puedes agregar más si tu cálculo los usa (fibra, etc.)
      'fibra_dietetica_g': numOrNull('fibra_dietetica_g'),
    }..removeWhere((_, v) => v == null);
  }

  Future<void> _abrirResultadoDesdeItem(
      BuildContext context, Map<String, dynamic> item) async {
    final scanProv = context.read<ScanProvider>();
    final authProv = context.read<AuthProvider>();

    // 0) Tomar id_categoria e id_producto desde el item
    final String? idCat = item['id_categoria']?.toString();
    final String? idProducto = item['id_producto']?.toString();

    // Preparar futuros opcionales para ranking y posición
    Future<Map<String, dynamic>>? rankingFuture;
    Future<Map<String, dynamic>>? posicionFuture;

    if (idCat != null && idCat.isNotEmpty) {
      rankingFuture = authProv.obtenerTop5Ranking(
        idCategoria: idCat,
        useGlobalLoading: false,
        updateState: true,
      );
    }

    if (idProducto != null && idProducto.isNotEmpty) {
      posicionFuture = authProv.obtenerPosicionProducto(
        idProducto: idProducto,
        useGlobalLoading: false,
        updateState: true,
      );
    }

    // 1) Preparar datos en provider de scan
    final nutrientes = _nutrientesDesdeItem(item);
    const unidadBase = '100 g';
    const baseQty = 100;

    scanProv.setResultData(
      nutrientes: nutrientes,
      unidadBase: unidadBase,
      porcion: null,
      baseQty: baseQty,
    );

    // 2) Calcular Nutri-Score y Sellos + (opcional) ranking + posición
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final futures = <Future>[
        scanProv.calcularNutriscoreOFF(
          unidadBase: unidadBase,
          nutrientes: nutrientes,
        ),
        scanProv.analizarSellosCL(
          unidadBase: unidadBase,
          nutrientes: nutrientes,
        ),
        if (rankingFuture != null) rankingFuture,
        if (posicionFuture != null) posicionFuture,
      ];

      await Future.wait(futures);
    } finally {
      if (mounted) Navigator.of(context).pop(); // cierra loading
    }

    // 3) Ir a resultados
    if (!mounted) return;
    Navigator.pushNamed(context, '/resultado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Escaneos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar historial'));
          } else if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos escaneados.'));
          }

          final historial = snapshot.data!;

          return ListView.builder(
            itemCount: historial.length,
            itemBuilder: (context, index) {
              final item = historial[index];

              final nombre = _toTitleCase(
                (item['nombre'] ?? 'Nombre desconocido').toString(),
              );
              final marca = _toTitleCase(
                (item['marca'] ?? 'Marca desconocida').toString(),
              );
              final categoria = _toTitleCase(
                (item['nombre_categoria'] ??
                        item['categoria'] ??
                        item['id_categoria'] ??
                        'Sin categoría')
                    .toString(),
              );
              final fecha = _fmtFechaDMY(item['fecha_creacion']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  onTap: () => _abrirResultadoDesdeItem(context, item),
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Marca: $marca'),
                        Text('Categoría: $categoria'),
                        Text('Escaneado: $fecha'),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
