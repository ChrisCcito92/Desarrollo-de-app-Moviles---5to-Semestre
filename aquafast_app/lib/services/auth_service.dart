import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';

class AuthService {
  final String baseUrl = 'http://10.0.2.2:3000';

  Future<Map<String, dynamic>> login(String correo, String contrasena) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo, 'contrasena': contrasena}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Obtener datos del usuario
        final perfilResponse = await http.get(
          Uri.parse('$baseUrl/api/auth/perfil'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${data['accessToken']}',
          },
        );

        Map<String, dynamic> usuarioData;
        if (perfilResponse.statusCode == 200) {
          usuarioData = jsonDecode(perfilResponse.body);
        } else {
          // Si no hay endpoint de perfil, usamos datos básicos del token
          usuarioData = {
            'id_usuario': 0,
            'nombre': correo.split('@')[0],
            'correo': correo,
            'tipo_usuario': 'cliente',
          };
        }

        final usuario = UsuarioModel.fromJson(
          usuarioData,
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

  Future<Map<String, dynamic>> registro(
    String nombre,
    String correo,
    String telefono,
    String contrasena,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'telefono': telefono,
          'contrasena': contrasena,
          'tipo_usuario': 'cliente',
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