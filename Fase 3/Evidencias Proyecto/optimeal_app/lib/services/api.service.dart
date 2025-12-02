// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl;
  final Duration _timeout;
  String? _authToken;

  AuthService({required this.baseUrl, Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 1000);

  /// Permite setear token para futuras peticiones
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers() {
    final map = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null && _authToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_authToken';
    }
    return map;
  }

  Map<String, dynamic> _parseResponse(http.Response resp) {
    try {
      final decoded = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      return {'ok': ok, 'status': resp.statusCode, 'data': decoded};
    } catch (e) {
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      return {'ok': ok, 'status': resp.statusCode, 'data': resp.body};
    }
  }

  // ----------------- Auth Endpoints -----------------
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombreUsuario,
    required int codigoPreferencia,
    int codigoRol = 2,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final body = jsonEncode({
      'email': email,
      'password': password,
      'nombre_usuario': nombreUsuario,
      'codigo_preferencia': codigoPreferencia,
      'codigo_rol': codigoRol.toString(),
    });

    try {
      final resp = await http
          .post(url, headers: _headers(), body: body)
          .timeout(_timeout);
      final parsed = _parseResponse(resp);
      if (parsed['ok'] == true) return {'ok': true, 'data': parsed['data']};
      return {
        'ok': false,
        'status': parsed['status'],
        'error': parsed['data'] ?? 'Error de registro'
      };
    } on SocketException {
      return {'ok': false, 'error': 'Sin conexión (SocketException)'};
    } on TimeoutException {
      return {'ok': false, 'error': 'Tiempo de espera agotado (timeout)'};
    } catch (e) {
      return {'ok': false, 'error': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final body = jsonEncode({'email': email, 'password': password});

    try {
      final resp = await http
          .post(url, headers: _headers(), body: body)
          .timeout(_timeout);
      final parsed = _parseResponse(resp);
      if (parsed['ok'] == true) return {'ok': true, 'data': parsed['data']};
      return {
        'ok': false,
        'status': parsed['status'],
        'error': parsed['data'] ?? 'Credenciales inválidas'
      };
    } on SocketException {
      return {'ok': false, 'error': 'Sin conexión (SocketException)'};
    } on TimeoutException {
      return {'ok': false, 'error': 'Tiempo de espera agotado (timeout)'};
    } catch (e) {
      return {'ok': false, 'error': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> checkEmail({required String email}) async {
    final url = Uri.parse('$baseUrl/api/auth/check-email');
    final body = jsonEncode({'email': email});

    try {
      final resp = await http
          .post(url, headers: _headers(), body: body)
          .timeout(_timeout);
      final parsed = _parseResponse(resp);
      if (parsed['ok'] == true) return {'ok': true, 'data': parsed['data']};
      return {
        'ok': false,
        'status': parsed['status'],
        'error': parsed['data'] ?? 'Error al verificar email'
      };
    } on SocketException {
      return {'ok': false, 'error': 'Sin conexión (SocketException)'};
    } on TimeoutException {
      return {'ok': false, 'error': 'Tiempo de espera agotado (timeout)'};
    } catch (e) {
      return {'ok': false, 'error': 'Error inesperado: $e'};
    }
  }

  // ----------------- Nutri API -----------------
  Future<Map<String, dynamic>> analizarSellosCL({
    required String unidadBase,
    required Map<String, dynamic> nutrientes,
  }) async {
    final url = Uri.parse(
        'https://nutri-api-1031993464059.us-west1.run.app/api/sellos-cl');
    final body =
        jsonEncode({'unidad_base': unidadBase, 'nutrientes': nutrientes});

    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300)
        return jsonDecode(resp.body);
      throw HttpException('Error ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw Exception('Sin conexión (SocketException)');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (timeout)');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  Future<Map<String, dynamic>> calcularNutriscoreOFF({
    required String unidadBase,
    required Map<String, dynamic> nutrientes,
  }) async {
    final url = Uri.parse(
        'https://nutri-api-1031993464059.us-west1.run.app/api/nutriscore-off');
    final body =
        jsonEncode({'unidad_base': unidadBase, 'nutrientes': nutrientes});

    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300)
        return jsonDecode(resp.body);
      throw HttpException('Error ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw Exception('Sin conexión (SocketException)');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (timeout)');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// ----------------- NUEVO: analizar imagen OCR -----------------
  Future<Map<String, dynamic>> analyzeImage(
      Map<String, dynamic> payload) async {
    final url = Uri.parse(
        'https://ocr-api-1031993464059.us-west1.run.app/analyze'); // endpoint OCR local
    final body = jsonEncode(payload);

    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);
      if (resp.statusCode >= 200 && resp.statusCode < 300)
        return jsonDecode(resp.body);
      throw HttpException('Error ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw Exception('Sin conexión (SocketException)');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (timeout)');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Inserta producto en BD (Node API que invoca el RPC en Supabase)
Future<Map<String, dynamic>> insertarProducto(Map<String, dynamic> data) async {
  final url = Uri.parse('$baseUrl/api/productos/insert');

  // helper: toma {por_base, por_porcion} o valor simple y lo convierte a num
  num? _numOrNull(dynamic v) {
    final raw = (v is Map<String, dynamic>) ? (v['por_base'] ?? null) : v;
    if (raw == null || raw == '') return null;
    if (raw is num) return raw;
    final parsed = num.tryParse(raw.toString());
    return parsed;
  }

  // Validación mínima requerida por la API
  final nombre = data['nombre']?.toString();
  final marca = data['marca']?.toString();
  final idCategoria = data['id_categoria']?.toString();
  final usuarioCreacion = data['usuario_creacion']?.toString();

  if (nombre == null || marca == null || idCategoria == null || usuarioCreacion == null) {
    return {
      'ok': false,
      'error': 'Faltan campos obligatorios: nombre, marca, id_categoria, usuario_creacion'
    };
  }

  // Normaliza unidad de medida (la API igual lo limpia y castea a enum)
  final unidad = data['unidad_medida']?.toString().trim().toLowerCase();

  // Construye el body que espera tu endpoint Node (parámetros nombrados del RPC)
  final body = jsonEncode({
    'nombre': nombre,
    'marca': marca,
    'id_categoria': idCategoria,

    'energia_kcal': _numOrNull(data['energia_kcal']),
    'proteinas_g': _numOrNull(data['proteinas_g']),
    'grasa_total_g': _numOrNull(data['grasa_total_g']),
    'carbohidratos_g': _numOrNull(data['carbohidratos_g']),
    'azucares_g': _numOrNull(data['azucares_g']),
    'sodio_mg': _numOrNull(data['sodio_mg']),

    'grasa_saturada_g': _numOrNull(data['grasa_saturada_g']),
    'grasa_trans_g': _numOrNull(data['grasa_trans_g']),
    'grasa_monoinsat_g': _numOrNull(data['grasa_monoinsat_g']),
    'grasa_poliinsat_g': _numOrNull(data['grasa_poliinsat_g']),
    'colesterol_mg': _numOrNull(data['colesterol_mg']),
    'fibra_dietetica_g': _numOrNull(data['fibra_dietetica_g']),
    'calcio_mg': _numOrNull(data['calcio_mg']),
    'fosforo_mg': _numOrNull(data['fosforo_mg']),
    'hierro_mg': _numOrNull(data['hierro_mg']),
    'potasio_mg': _numOrNull(data['potasio_mg']),
    'vitamina_c_mg': _numOrNull(data['vitamina_c_mg']),

    'usuario_creacion': usuarioCreacion, // requerido por la API (historial)
    'unidad_medida': unidad,             // ej: 'g' | 'ml' | '100 g' | '100 ml'
    // puedes incluir opcionales si quieres: p_min_sim, fechas, usuario_modificacion...
  });

  try {
    final resp = await http
        .post(url, headers: _headers(), body: body)
        .timeout(_timeout);

    final parsed = _parseResponse(resp);

    if (parsed['ok'] == true) {
      // La API devuelve { ok, message, data: { id_producto, matched, created, sim_score, motivo } }
      final payload = parsed['data'] ?? {};
      return {
        'ok': true,
        'status': parsed['status'],
        'data': payload,
      };
    } else {
      return {
        'ok': false,
        'status': parsed['status'],
        'error': parsed['data']?['error'] ?? parsed['data'] ?? 'Error al insertar/buscar producto',
      };
    }
  } on SocketException {
    return {'ok': false, 'error': 'Sin conexión'};
  } on TimeoutException {
    return {'ok': false, 'error': 'Tiempo de espera agotado'};
  } catch (e) {
    return {'ok': false, 'error': e.toString()};
  }
}


  Future<Map<String, dynamic>> getCategorias() async {
    final url = Uri.parse('$baseUrl/api/categorias/list');
    final resp = await http.get(url).timeout(_timeout);
    final parsed = _parseResponse(resp);
    return parsed;
  }

    Future<Map<String, dynamic>> obtenerTop5Ranking({
    required String idUsuario,
    required String idCategoria,
  }) async {
    final url = Uri.parse(
      'https://nutri-api-1031993464059.us-west1.run.app/api/productos/ranking',
    );
    final body = jsonEncode({
      'id_usuario': idUsuario,
      'id_categoria': idCategoria,
    });

    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      throw HttpException('Error ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw Exception('Sin conexión (SocketException)');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (timeout)');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerPosicion({
    required String idUsuario,
    required String idProducto,
  }) async {
    final url = Uri.parse(
      'https://nutri-api-1031993464059.us-west1.run.app/api/productos/posicion',
    );
    final body = jsonEncode({
      'id_usuario': idUsuario,
      'id_producto': idProducto,
    });

    try {
      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      throw HttpException('Error ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw Exception('Sin conexión (SocketException)');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (timeout)');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

}


