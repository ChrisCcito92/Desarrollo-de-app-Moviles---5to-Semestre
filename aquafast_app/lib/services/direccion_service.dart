import 'dart:convert';
import 'package:http/http.dart' as http;

class DireccionService {
  final String baseUrl = 'http://192.168.100.11:3000';

  Future<Map<String, dynamic>> obtenerDirecciones(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/direcciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar direcciones.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> crearDireccion({
    required String token,
    required String alias,
    required String calleReferencia,
    required double latitud,
    required double longitud,
    bool predeterminada = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/direcciones'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'alias': alias,
          'calle_referencia': calleReferencia,
          'latitud': latitud,
          'longitud': longitud,
          'predeterminada': predeterminada,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'exito': true, 'data': data['data'], 'mensaje': data['mensaje']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al crear dirección.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> eliminarDireccion(String token, int idDireccion) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/direcciones/$idDireccion'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'mensaje': data['mensaje']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al eliminar dirección.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }
}