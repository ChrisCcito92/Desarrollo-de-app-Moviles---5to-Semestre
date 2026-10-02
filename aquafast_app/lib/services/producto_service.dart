import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductoService {
  final String baseUrl = 'http://192.168.100.11:3000';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _procesar(
    http.Response response,
    List<int> codigosExito,
    String mensajePorDefecto,
  ) {
    final data = jsonDecode(response.body);
    if (codigosExito.contains(response.statusCode)) {
      return {
        'exito': true,
        'data': data['data'],
        'resumen': data['resumen'],
        'mensaje': data['mensaje'],
      };
    }
    return {'exito': false, 'mensaje': data['error'] ?? mensajePorDefecto};
  }

  /// Productos de la distribuidora del usuario, con resumen de stock.
  Future<Map<String, dynamic>> obtenerMisProductos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/distribuidores/mis-productos'),
        headers: _headers(token),
      );
      return _procesar(response, [200], 'Error al cargar el inventario.');
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> crearProducto(
    String token, {
    required String tipoBidon,
    required double precio,
    required int stock,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/distribuidores/mis-productos'),
        headers: _headers(token),
        body: jsonEncode({
          'tipo_bidon': tipoBidon,
          'precio_unitario': precio,
          'stock_disponible': stock,
        }),
      );
      return _procesar(response, [201], 'No se pudo agregar el producto.');
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  /// [cambios] puede llevar: tipo_bidon, precio_unitario, stock_disponible,
  /// incremento (bidones que se suman al stock) o activo (true/false).
  Future<Map<String, dynamic>> actualizarProducto(
    String token,
    int idProducto,
    Map<String, dynamic> cambios,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/distribuidores/mis-productos/$idProducto'),
        headers: _headers(token),
        body: jsonEncode(cambios),
      );
      return _procesar(response, [200], 'No se pudo actualizar el producto.');
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> eliminarProducto(String token, int idProducto) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/distribuidores/mis-productos/$idProducto'),
        headers: _headers(token),
      );
      return _procesar(response, [200], 'No se pudo eliminar el producto.');
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }
}