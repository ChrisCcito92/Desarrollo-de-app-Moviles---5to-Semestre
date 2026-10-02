import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';

class AuthService {
  final String baseUrl = 'http://192.168.100.11:3000';

  Future<Map<String, dynamic>> login(String correo, String contrasena) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo, 'contrasena': contrasena}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // El backend devuelve los tokens y los datos reales del usuario (incluido su rol)
        if (data['usuario'] == null) {
          return {
            'exito': false,
            'mensaje': 'El servidor no devolvió los datos del usuario.',
          };
        }

        final usuario = UsuarioModel.fromJson(
          data['usuario'],
          data['accessToken'],
          data['refreshToken'],
        );
        return {'exito': true, 'usuario': usuario};
      } else {
        return {'exito': false, 'mensaje': data['error'] ?? 'Credenciales inválidas.'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }

  /// [tipoUsuario] puede ser 'cliente' o 'distribuidor'.
  /// Si es distribuidor, [distribuidor] lleva nombre comercial, precio, stock,
  /// radio de cobertura y la ubicación de la base.
  Future<Map<String, dynamic>> registro(
    String nombre,
    String correo,
    String telefono,
    String contrasena, {
    String tipoUsuario = 'cliente',
    Map<String, dynamic>? distribuidor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'telefono': telefono,
          'contrasena': contrasena,
          'tipo_usuario': tipoUsuario,
          if (distribuidor != null) 'distribuidor': distribuidor,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'exito': true, 'mensaje': 'Usuario registrado exitosamente.'};
      } else {
        return {'exito': false, 'mensaje': data['error'] ?? 'Error al registrar.'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor.'};
    }
  }
}