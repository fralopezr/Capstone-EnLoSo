// lib/providers/scan_provider.dart
import 'package:flutter/material.dart';
import '../services/api.service.dart';

class ScanProvider extends ChangeNotifier {
  final AuthService authService;

  bool _loading = false;
  Map<String, dynamic>? _sellosCL;
  Map<String, dynamic>? _nutriscoreOFF;

  // Campos para la página de resultado
  Map<String, dynamic>? _nutrientes;
  String? _unidadBase;
  String? _porcion;
  double? _baseQty; // ← antes dynamic: tipamos como número

  ScanProvider({required this.authService});

  // Getters
  bool get loading => _loading;
  Map<String, dynamic>? get sellosCL => _sellosCL;
  Map<String, dynamic>? get nutriscoreOFF => _nutriscoreOFF;
  Map<String, dynamic>? get nutrientes => _nutrientes;
  String? get unidadBase => _unidadBase;
  String? get porcion => _porcion;
  double? get baseQty => _baseQty;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  /// Permite asignar datos manualmente al provider
  void setResultData({
    required Map<String, dynamic> nutrientes,
    required String unidadBase,
    dynamic porcion,            // ← aceptar num o String
    num? baseQty,               // ← tipar num y guardar como double
    Map<String, dynamic>? nutriscoreOFF,
    Map<String, dynamic>? sellosCL,
  }) {
    _nutrientes   = nutrientes;
    _unidadBase   = unidadBase.toString();
    _porcion      = porcion == null ? null : porcion.toString(); // ← blindaje
    _baseQty      = baseQty?.toDouble();
    _nutriscoreOFF = nutriscoreOFF;
    _sellosCL      = sellosCL;
    notifyListeners();
  }

  /// Llama al endpoint OCR de análisis de imagen
  Future<Map<String, dynamic>> analyzeOCR(Map<String, dynamic> payload) async {
    _setLoading(true);
    try {
      final resp = await authService.analyzeImage(payload);

      // Normalización segura de tipos
      _nutrientes = (resp['nutrientes'] as Map?)?.cast<String, dynamic>() ?? {};
      _unidadBase = (resp['unidad_base'] ?? '').toString();

      final porcionDyn = resp['porcion'];
      _porcion = porcionDyn == null ? null : porcionDyn.toString(); // ← evita double->String? error

      _baseQty = (resp['base_qty'] as num?)?.toDouble(); // ← num -> double

      notifyListeners();
      return {'ok': true, 'data': resp};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  /// Llama al endpoint de análisis de sellos chilenos
  Future<Map<String, dynamic>> analizarSellosCL({
    required String unidadBase,
    required Map<String, dynamic> nutrientes,
  }) async {
    _setLoading(true);
    try {
      final resp = await authService.analizarSellosCL(
        unidadBase: unidadBase,
        nutrientes: nutrientes,
      );
      _sellosCL = resp;
      notifyListeners();
      return {'ok': true, 'data': resp};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  /// Llama al endpoint de cálculo de Nutri-Score (versión OFF)
  Future<Map<String, dynamic>> calcularNutriscoreOFF({
    required String unidadBase,
    required Map<String, dynamic> nutrientes,
  }) async {
    _setLoading(true);
    try {
      final resp = await authService.calcularNutriscoreOFF(
        unidadBase: unidadBase,
        nutrientes: nutrientes,
      );
      _nutriscoreOFF = resp;
      notifyListeners();
      return {'ok': true, 'data': resp};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  /// Limpia los resultados anteriores
  void clearResults() {
    _sellosCL = null;
    _nutriscoreOFF = null;
    _nutrientes = null;
    _unidadBase = null;
    _porcion = null;
    _baseQty = null;
    notifyListeners();
  }
}
