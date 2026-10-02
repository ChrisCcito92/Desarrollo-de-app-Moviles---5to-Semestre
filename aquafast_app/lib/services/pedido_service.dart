import 'dart:convert';
import 'package:http/http.dart' as http;

class PedidoService {
  final String baseUrl = 'http://192.168.100.11:3000';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> obtenerDistribuidores(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/distribuidores'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar distribuidores.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> obtenerProductos(String token, int idDistribuidor) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/distribuidores/$idDistribuidor/productos'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar productos.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> crearPedido({
    required String token,
    required int idDireccion,
    required int idDistribuidor,
    required String metodoPago,
    required List<Map<String, dynamic>> detalles,
    String? observaciones,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/pedidos'),
        headers: _headers(token),
        body: jsonEncode({
          'id_direccion': idDireccion,
          'id_distribuidor': idDistribuidor,
          'metodo_pago': metodoPago,
          'detalles': detalles,
          'observaciones': observaciones,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'exito': true, 'data': data['data'], 'mensaje': data['mensaje']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al crear el pedido.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> obtenerMisPedidos(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/mis-pedidos'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data'], 'paginacion': data['paginacion']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar pedidos.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  Future<Map<String, dynamic>> obtenerDetallePedido(String token, int idPedido) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/pedidos/$idPedido'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data'], 'fuente': data['fuente']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar el pedido.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  // ─── Panel del distribuidor ───────────────────────────────────────────

  /// Lista paginada de los pedidos de la distribuidora del usuario autenticado.
  /// [estado] es opcional: pendiente, aceptado, en_camino, entregado o cancelado.
  Future<Map<String, dynamic>> obtenerPedidosDistribuidor(
    String token, {
    int pagina = 1,
    int limite = 10,
    String? estado,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pedidos/distribuidor').replace(
        queryParameters: {
          'pagina': '$pagina',
          'limite': '$limite',
          if (estado != null) 'estado': estado,
        },
      );
      final response = await http.get(uri, headers: _headers(token));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'exito': true,
          'data': data['data'],
          'paginacion': data['paginacion'],
          'distribuidor': data['distribuidor'],
        };
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'Error al cargar los pedidos.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  /// Cambia el estado de un pedido. El distribuidor lo avanza;
  /// el cliente solo puede enviar "cancelado" mientras esté pendiente.
  Future<Map<String, dynamic>> actualizarEstadoPedido(
    String token,
    int idPedido,
    String nuevoEstado,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/pedidos/$idPedido/estado'),
        headers: _headers(token),
        body: jsonEncode({'estado_pedido': nuevoEstado}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data'], 'mensaje': data['mensaje']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'No se pudo actualizar el estado.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  /// El cliente califica un pedido entregado con un valor de 1 a 5.
  Future<Map<String, dynamic>> calificarPedido(
    String token,
    int idPedido,
    int calificacion,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/pedidos/$idPedido/calificacion'),
        headers: _headers(token),
        body: jsonEncode({'calificacion': calificacion}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'exito': true, 'data': data['data'], 'mensaje': data['mensaje']};
      }
      return {'exito': false, 'mensaje': data['error'] ?? 'No se pudo enviar la calificación.'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }
}