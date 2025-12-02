import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart'; // Asegúrate que el path es correcto

class HistorialService {
  final String baseUrl;
  final Duration _timeout;

  // Usa apiBaseLocal por defecto si no se especifica baseUrl
  HistorialService({this.baseUrl = API_BASE_LOCAL, Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 10);

  Future<List<Map<String, dynamic>>> obtenerHistorialPorUsuario(
      String idUsuario) async {
    final url = Uri.parse('$baseUrl/api/historial/usuario/$idUsuario');

    try {
      final resp = await http.get(url).timeout(_timeout);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['ok'] == true && decoded['historial'] is List) {
          return List<Map<String, dynamic>>.from(decoded['historial']);
        }
        return [];
      } else {
        print('Error HTTP ${resp.statusCode}: ${resp.body}');
        return [];
      }
    } catch (e) {
      print('Error al obtener historial: $e');
      return [];
    }
  }
}
