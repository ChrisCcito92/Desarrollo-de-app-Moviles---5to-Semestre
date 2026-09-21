import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/camera_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final CameraService _cameraService = CameraService();
  File? _fotoPerfil;
  String _mensajeCamara = '';
  bool _errorCamara = false;

  Future<void> _tomarFoto() async {
    setState(() {
      _mensajeCamara = '';
      _errorCamara = false;
    });

    final resultado = await _cameraService.tomarFoto();

    setState(() {
      if (resultado['exito']) {
        _fotoPerfil = resultado['archivo'] as File;
        _mensajeCamara = 'Foto de perfil actualizada.';
        _errorCamara = false;
      } else {
        _mensajeCamara = resultado['mensaje'];
        _errorCamara = true;
      }
    });

    // Si el permiso fue denegado permanentemente, ofrecer ir a ajustes
    if (!resultado['exito'] && resultado['tipo'] == 'denegado_permanente') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso de cámara'),
            content: const Text(
              'El acceso a la cámara fue denegado permanentemente. '
              '¿Deseas abrir los ajustes para habilitarlo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Abrir ajustes del sistema
                },
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    final resultado = await _cameraService.seleccionarDeGaleria();
    setState(() {
      if (resultado['exito']) {
        _fotoPerfil = resultado['archivo'] as File;
        _mensajeCamara = 'Foto seleccionada correctamente.';
        _errorCamara = false;
      } else {
        _mensajeCamara = resultado['mensaje'];
        _errorCamara = true;
      }
    });
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Foto de perfil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'AquaFast usa tu foto para personalizar tu perfil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _tomarFoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Seleccionar de galería'),
              onTap: () {
                Navigator.pop(ctx);
                _seleccionarDeGaleria();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Mi perfil',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _mostrarOpciones,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue,
                    backgroundImage:
                        _fotoPerfil != null ? FileImage(_fotoPerfil!) : null,
                    child: _fotoPerfil == null
                        ? Text(
                            usuario?.nombre
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca para cambiar foto',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_mensajeCamara.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _errorCamara
                      ? Colors.red[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _errorCamara ? Colors.red : Colors.green,
                  ),
                ),
                child: Text(
                  _mensajeCamara,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _errorCamara
                        ? Colors.red[800]
                        : Colors.green[800],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              usuario?.nombre ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                usuario?.tipoUsuario ?? '',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 32),
            _InfoTile(
              icono: Icons.email,
              titulo: 'Correo',
              valor: usuario?.correo ?? '',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              icono: Icons.badge,
              titulo: 'Rol',
              valor: usuario?.tipoUsuario ?? '',
            ),
            const SizedBox(height: 12),
            _InfoTile(
              icono: Icons.tag,
              titulo: 'ID de usuario',
              valor: usuario?.idUsuario.toString() ?? '',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Provider.of<AuthProvider>(context, listen: false)
                      .cerrarSesion();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _InfoTile({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.blue),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}