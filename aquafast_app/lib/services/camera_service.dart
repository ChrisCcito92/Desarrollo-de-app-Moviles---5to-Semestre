import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  /// Toma una foto con la cámara del dispositivo.
  /// Gestiona los 4 estados del permiso.
  Future<Map<String, dynamic>> tomarFoto() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (foto == null) {
        return {
          'exito': false,
          'tipo': 'cancelado',
          'mensaje': 'El usuario canceló la captura de la foto.',
        };
      }

      return {
        'exito': true,
        'tipo': 'concedido',
        'archivo': File(foto.path),
        'ruta': foto.path,
        'mensaje': 'Foto tomada correctamente.',
      };
    } catch (e) {
      String mensaje = e.toString();

      if (mensaje.contains('camera_access_denied') ||
          mensaje.contains('Permission')) {
        return {
          'exito': false,
          'tipo': 'denegado_permanente',
          'mensaje':
              'Permiso de cámara denegado. Habilítalo desde los ajustes de la aplicación.',
        };
      }

      return {
        'exito': false,
        'tipo': 'error',
        'mensaje': 'Error al acceder a la cámara: $e',
      };
    }
  }

  /// Selecciona una imagen desde la galería.
  Future<Map<String, dynamic>> seleccionarDeGaleria() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (imagen == null) {
        return {
          'exito': false,
          'tipo': 'cancelado',
          'mensaje': 'El usuario canceló la selección.',
        };
      }

      return {
        'exito': true,
        'tipo': 'concedido',
        'archivo': File(imagen.path),
        'ruta': imagen.path,
        'mensaje': 'Imagen seleccionada correctamente.',
      };
    } catch (e) {
      return {
        'exito': false,
        'tipo': 'error',
        'mensaje': 'Error al acceder a la galería: $e',
      };
    }
  }
}