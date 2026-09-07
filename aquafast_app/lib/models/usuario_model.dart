class UsuarioModel {
  final int idUsuario;
  final String nombre;
  final String correo;
  final String tipoUsuario;
  final String accessToken;
  final String refreshToken;

  UsuarioModel({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.tipoUsuario,
    required this.accessToken,
    required this.refreshToken,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json, String access, String refresh) {
    return UsuarioModel(
      idUsuario: json['id_usuario'],
      nombre: json['nombre'],
      correo: json['correo'],
      tipoUsuario: json['tipo_usuario'],
      accessToken: access,
      refreshToken: refresh,
    );
  }
}