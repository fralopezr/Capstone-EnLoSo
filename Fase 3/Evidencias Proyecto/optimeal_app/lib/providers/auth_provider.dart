// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/api.service.dart';

class AuthProvider extends ChangeNotifier {
  AuthService authService;

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _user;
  bool _loading = false;

  // ====== Estado TOP 5 ======
  List<Map<String, dynamic>> _top5 = const [];
  Map<String, dynamic>? _top5Meta;
  String? _lastTop5Categoria;

  // ====== Estado POSICIÓN PRODUCTO ======
  Map<String, dynamic>? _posicionProducto;
  Map<String, dynamic>? _posicionMeta;
  String? _lastPosicionProductoId;
  // ======================================

  AuthProvider({required this.authService});

  // NUEVO getter directo para el ID del usuario
  String? get userId => _user?['id'];

  // getters existentes
  Map<String, dynamic>? get session => _session;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _session != null && _user != null;
  bool get loading => _loading;

  // Getters Top 5
  List<Map<String, dynamic>> get top5 => _top5;
  Map<String, dynamic>? get top5Meta => _top5Meta;
  String? get lastTop5Categoria => _lastTop5Categoria;
  bool get hasTop5 => _top5.isNotEmpty;

  // Getters POSICIÓN
  Map<String, dynamic>? get posicionProducto => _posicionProducto;
  Map<String, dynamic>? get posicionMeta => _posicionMeta;
  String? get lastPosicionProductoId => _lastPosicionProductoId;
  bool get hasPosicionProducto => _posicionProducto != null;

  void updateAuthService(AuthService newService) {
    authService = newService;
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setTop5({
    required List<Map<String, dynamic>> data,
    Map<String, dynamic>? meta,
    String? categoriaId,
  }) {
    _top5 = data;
    _top5Meta = meta;
    _lastTop5Categoria = categoriaId ?? _lastTop5Categoria;
    notifyListeners();
  }

  // helper para POSICIÓN
  void _setPosicion({
    Map<String, dynamic>? producto,
    Map<String, dynamic>? meta,
    String? idProducto,
  }) {
    _posicionProducto = producto;
    _posicionMeta = meta;
    _lastPosicionProductoId = idProducto ?? _lastPosicionProductoId;
    notifyListeners();
  }

  void setAuth({
    required Map<String, dynamic> session,
    required Map<String, dynamic> user,
  }) {
    _session = Map<String, dynamic>.from(session);
    _user = Map<String, dynamic>.from(user);

    final token = _session?['access_token'] ??
        _session?['accessToken'] ??
        _session?['token'];
    if (token is String && token.isNotEmpty) {
      authService.setAuthToken(token);
    }
    notifyListeners();
  }

  void clearAuth() {
    _session = null;
    _user = null;

    _top5 = const [];
    _top5Meta = null;
    _lastTop5Categoria = null;

    _posicionProducto = null;
    _posicionMeta = null;
    _lastPosicionProductoId = null;

    authService.setAuthToken(null);
    notifyListeners();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final resp = await authService.login(email: email, password: password);
      if (resp['ok'] == true) {
        final data = resp['data'];
        final session =
            data is Map ? (data['session'] ?? data['data']?['session']) : null;
        final user =
            data is Map ? (data['user'] ?? data['data']?['user']) : null;
        if (session != null && user != null) {
          setAuth(
            session: Map<String, dynamic>.from(session),
            user: Map<String, dynamic>.from(user),
          );
        }
      }
      return resp;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombreUsuario,
    required int codigoPreferencia,
    int codigoRol = 2,
  }) async {
    _setLoading(true);
    try {
      final resp = await authService.register(
        email: email,
        password: password,
        nombreUsuario: nombreUsuario,
        codigoPreferencia: codigoPreferencia,
        codigoRol: codigoRol,
      );
      return resp;
    } finally {
      _setLoading(false);
    }
  }

  // ================== Insertar / Match Producto vía Provider ==================
  /// Envuelve `authService.insertarProducto`.
  /// - Si la operación es exitosa:
  ///   1) Refresca el Top 5 de la categoría (opcional).
  ///   2) Obtiene la posición del producto recién insertado/matcheado y
  ///      deja `_posicionProducto`, `_posicionMeta` y `_lastPosicionProductoId`.
  Future<Map<String, dynamic>> insertarProducto({
    required Map<String, dynamic> data,
    bool useGlobalLoading = true,
    bool refreshTop5OnSuccess = true,
  }) async {
    if ((data['usuario_creacion']?.toString().isEmpty ?? true) || userId == null) {
      data['usuario_creacion'] ??= userId;
    }

    if (useGlobalLoading) _setLoading(true);
    try {
      final resp = await authService.insertarProducto(data);

      if (resp['ok'] == true) {
        // 1) Refrescar Top 5
        if (refreshTop5OnSuccess) {
          final String? idCat = data['id_categoria']?.toString();
          if (idCat != null && idCat.isNotEmpty) {
            await obtenerTop5Ranking(
              idCategoria: idCat,
              useGlobalLoading: false,
              updateState: true,
            );
          }
        }

        // 2) Intentar obtener posición del producto recién insertado/matcheado
        try {
          // resp['data'] => { ok, message, data: { id_producto, matched, created, ... } }
          final dynamic outerData = resp['data'];
          final dynamic innerData =
              (outerData is Map) ? outerData['data'] : null;

          final String? idProducto = innerData is Map
              ? innerData['id_producto']?.toString()
              : null;

          if (idProducto != null && idProducto.isNotEmpty) {
            await obtenerPosicionProducto(
              idProducto: idProducto,
              useGlobalLoading: false,
              updateState: true,
            );
          }
        } catch (_) {
          // Si algo falla aquí no rompemos el flujo principal
        }
      }

      return resp;
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    } finally {
      if (useGlobalLoading) _setLoading(false);
    }
  }
  // ================================================================================

  // ================== Top 5 Ranking ==================
  /// Consume:
  /// POST https://nutri-api-1031993464059.us-west1.run.app/api/productos/ranking
  /// Body: { id_usuario, id_categoria }
  Future<Map<String, dynamic>> obtenerTop5Ranking({
    String? idUsuario,
    required String idCategoria,
    bool useGlobalLoading = true,
    bool updateState = true,
  }) async {
    final uid = (idUsuario ?? userId)?.trim();
    if (uid == null || uid.isEmpty) {
      return {'ok': false, 'error': 'Usuario no autenticado o sin ID disponible'};
    }

    if (useGlobalLoading) _setLoading(true);
    try {
      final resp = await authService.obtenerTop5Ranking(
        idUsuario: uid,
        idCategoria: idCategoria,
      );

      // resp esperado: { ok, message, data: [...], meta: {...} }
      if (resp is Map && resp['ok'] == true && updateState) {
        final List<Map<String, dynamic>> lista = (resp['data'] is List)
            ? List<Map<String, dynamic>>.from(resp['data'])
            : const <Map<String, dynamic>>[];

        final Map<String, dynamic>? meta =
            (resp['meta'] is Map) ? Map<String, dynamic>.from(resp['meta']) : null;

        _setTop5(data: lista, meta: meta, categoriaId: idCategoria);
      }

      return resp;
    } catch (e) {
      if (updateState) {
        _setTop5(data: const [], meta: null, categoriaId: idCategoria);
      }
      return {'ok': false, 'error': e.toString()};
    } finally {
      if (useGlobalLoading) _setLoading(false);
    }
  }
  // ===================================================

  // ================== POSICIÓN PRODUCTO ==================
  /// Consume:
  /// POST https://nutri-api-1031993464059.us-west1.run.app/api/productos/posicion
  /// Body: { id_usuario, id_producto }
  ///
  /// Por defecto usa el `userId` autenticado. Si `updateState` es true, guarda en
  /// `_posicionProducto`, `_posicionMeta` y `_lastPosicionProductoId`.
  Future<Map<String, dynamic>> obtenerPosicionProducto({
    String? idUsuario,
    required String idProducto,
    bool useGlobalLoading = true,
    bool updateState = true,
  }) async {
    final uid = (idUsuario ?? userId)?.trim();
    if (uid == null || uid.isEmpty) {
      return {'ok': false, 'error': 'Usuario no autenticado o sin ID disponible'};
    }

    if (useGlobalLoading) _setLoading(true);
    try {
      final resp = await authService.obtenerPosicion(
        idUsuario: uid,
        idProducto: idProducto,
      );

      // resp esperado: { ok, message, data: [ { posicion, ... } ], meta: { ... } }
      if (resp is Map && resp['ok'] == true && updateState) {
        final List<Map<String, dynamic>> lista = (resp['data'] is List)
            ? List<Map<String, dynamic>>.from(resp['data'])
            : const <Map<String, dynamic>>[];

        final Map<String, dynamic>? producto =
            lista.isNotEmpty ? lista.first : null;

        final Map<String, dynamic>? meta =
            (resp['meta'] is Map) ? Map<String, dynamic>.from(resp['meta']) : null;

        _setPosicion(
          producto: producto,
          meta: meta,
          idProducto: idProducto,
        );
      }

      return resp;
    } catch (e) {
      if (updateState) {
        _setPosicion(producto: null, meta: null, idProducto: idProducto);
      }
      return {'ok': false, 'error': e.toString()};
    } finally {
      if (useGlobalLoading) _setLoading(false);
    }
  }
  // ======================================================
}
