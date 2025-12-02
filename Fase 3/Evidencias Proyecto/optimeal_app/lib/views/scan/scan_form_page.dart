// lib/views/scan/scan_form_page.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/labeled_text_field.dart';
import '../../services/scanner.dart';
import '../../services/api.service.dart';

import '../../views/historial/historial_page.dart';

class ScanFormPage extends StatefulWidget {
  const ScanFormPage({super.key});

  @override
  State<ScanFormPage> createState() => _ScanFormPageState();
}

class _ScanFormPageState extends State<ScanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  List<Map<String, dynamic>> _categorias = [];
  String? _selectedCategoria; // almacenará el id_categoria seleccionado
  bool _loadingCategorias = false;

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    setState(() => _loadingCategorias = true);
    try {
      final authProv = context.read<AuthProvider>();
      final api = authProv.authService;
      final resp = await api.getCategorias();
      final rawData = resp['data'];

      if (resp['ok'] == true && rawData != null) {
        // Si el backend ya devuelve {"ok": true, "data": [...]}, accedemos al interior
        final lista = (rawData is Map && rawData['data'] != null)
            ? rawData['data']
            : rawData;

        setState(() {
          _categorias = List<Map<String, dynamic>>.from(lista);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error cargando categorías: ${resp['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loadingCategorias = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _marcaCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => const Scanner()),
      );
      if (bytes == null) return;
      setState(() => _imageBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen lista desde Scanner')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al abrir Scanner: $e')));
    }
  }

  Future<void> _openGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _imageBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen lista (galería)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error galería: $e')));
    }
  }

  Future<void> _send() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona o toma una imagen.')),
      );
      return;
    }
    if (_selectedCategoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría.')),
      );
      return;
    }

    final nombre = _nombreCtrl.text.trim();
    final marca = _marcaCtrl.text.trim();

    final authProv = context.read<AuthProvider>();
    final userId = authProv.userId;

    final scanProvider = context.read<ScanProvider>();
    scanProvider.clearResults();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) OCR
      final resp = await scanProvider.analyzeOCR({
        "image_b64": base64Encode(_imageBytes!),
        if (nombre.isNotEmpty) "nombre": nombre,
        if (marca.isNotEmpty) "marca": marca,
      });

      if (!mounted) return;
      Navigator.of(context).pop();

      if (resp['ok'] != true) {
        throw Exception(resp['error'] ?? 'Error al analizar OCR');
      }

      final data = resp['data'] as Map<String, dynamic>;

      // 2) Normalizar y guardar en provider (igual que tu versión original)
      final nutrientes =
          (data['nutrientes'] as Map?)?.cast<String, dynamic>() ?? {};
      final unidadBase =
          (data['unidad_base'] ?? '').toString(); // ej: "100 g" o "100 ml"
      final porcionDyn = data['porcion'];
      final baseQtyNum = (data['base_qty'] as num?);

      scanProvider.setResultData(
        nutrientes: nutrientes,
        unidadBase: unidadBase,
        porcion: porcionDyn,
        baseQty: baseQtyNum,
      );

      // 3) Calcular Nutri-Score y Sellos SOLO para mostrar (no se insertan)
      await Future.wait([
        scanProvider.calcularNutriscoreOFF(
          unidadBase: unidadBase,
          nutrientes: nutrientes,
        ),
        scanProvider.analizarSellosCL(
          unidadBase: unidadBase,
          nutrientes: nutrientes,
        ),
      ]);

      // 4) Insertar / Match producto usando el PROVIDER (no llamar servicio directo)
      final nombreFinal = nombre.isNotEmpty
          ? nombre
          : (data['nombre']?.toString() ?? 'Sin nombre');
      final marcaFinal = marca.isNotEmpty
          ? marca
          : (data['marca']?.toString() ?? 'Desconocida');
      final unidadMedida = unidadBase.isNotEmpty ? unidadBase : null;

      final insertPayload = <String, dynamic>{
        "nombre": nombreFinal,
        "marca": marcaFinal,
        "id_categoria": _selectedCategoria,
        "usuario_creacion": userId, // el provider lo valida si viene null
        "unidad_medida": unidadMedida, // la API lo castea a enum
        // Nutrientes (el service soporta {por_base, por_porcion} o número)
        ...nutrientes,
      };

      final insertResp = await authProv.insertarProducto(
        data: insertPayload,
        useGlobalLoading: false, // ya mostramos nuestro propio diálogo antes
        refreshTop5OnSuccess: true, // refresca Top 5 para esa categoría
      );

      if (insertResp['ok'] != true) {
        final err = insertResp['error'] ?? 'Error al insertar/buscar producto';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      // El provider devuelve lo mismo que el service: { ok, status, data }
      // donde data es el JSON backend: { ok, message, data: row }
      final backend = insertResp['data'] as Map<String, dynamic>?;
      final row = backend?['data'] as Map<String, dynamic>?;

      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta inesperada del servidor')),
        );
        return;
      }

      // Mensaje según resultado
      final created = (row['created'] == true);
      final matched = (row['matched'] == true);
      final msg = created
          ? 'Producto insertado y registrado en historial'
          : (matched
              ? 'Producto existente; historial actualizado'
              : 'Operación completada');

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // 5) Ir a resultados
      if (!mounted) return;
      Navigator.pushNamed(context, '/resultado');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear etiqueta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Container(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_back_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                'Sin imagen',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    LabeledTextField(
                      label: 'Nombre',
                      controller: _nombreCtrl,
                      prefixIcon: Icons.drive_file_rename_outline,
                    ),
                    const SizedBox(height: 12),
                    LabeledTextField(
                      label: 'Marca',
                      controller: _marcaCtrl,
                      prefixIcon: Icons.local_offer_outlined,
                    ),
                    const SizedBox(height: 12),

                    //  ComboBox de Categorías
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedCategoria,
                      items: _categorias
                          .map((cat) => DropdownMenuItem<String>(
                                value: cat['id_categoria'],
                                child: Text(cat['nombre']),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoria = v),
                      validator: (v) =>
                          (v == null) ? 'Selecciona una categoría' : null,
                      isExpanded: true,
                      hint: _loadingCategorias
                          ? const Text('Cargando categorías...')
                          : const Text('Selecciona una categoría'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Enviar'),
          onPressed: _send,
        ),
      ),
    );
  }
}
