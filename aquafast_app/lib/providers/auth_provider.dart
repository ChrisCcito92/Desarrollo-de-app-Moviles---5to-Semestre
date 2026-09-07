import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario_model.dart';

class AuthProvider extends ChangeNotifier {
  UsuarioModel? _usuario;
  bool _cargando = false;

  UsuarioModel? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get estaAutenticado => _usuario != null;

  void setCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }

  Future<void> guardarSesion(UsuarioModel usuario) async {
    _usuario = usuario;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', usuario.accessToken);
    await prefs.setString('refreshToken', usuario.refreshToken);
    await prefs.setString('nombre', usuario.nombre);
    await prefs.setString('correo', usuario.correo);
    await prefs.setString('tipoUsuario', usuario.tipoUsuario);
    await prefs.setInt('idUsuario', usuario.idUsuario);
    notifyListeners();
  }

  Future<bool> cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) return false;

    _usuario = UsuarioModel(
      idUsuario: prefs.getInt('idUsuario') ?? 0,
      nombre: prefs.getString('nombre') ?? '',
      correo: prefs.getString('correo') ?? '',
      tipoUsuario: prefs.getString('tipoUsuario') ?? '',
      accessToken: token,
      refreshToken: prefs.getString('refreshToken') ?? '',
    );
    notifyListeners();
    return true;
  }

  Future<void> cerrarSesion() async {
    _usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}