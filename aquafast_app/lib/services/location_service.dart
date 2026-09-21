import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Solicita el permiso y obtiene la ubicación actual.
  /// Gestiona los 4 estados: no solicitado, concedido, denegado, denegado permanente.
  Future<Map<String, dynamic>> obtenerUbicacion() async {
    // Verificar si el servicio de ubicación está activado
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      return {
        'exito': false,
        'tipo': 'servicio_desactivado',
        'mensaje': 'El servicio de ubicación está desactivado. Actívalo en los ajustes del dispositivo.',
      };
    }

    // Verificar estado del permiso
    LocationPermission permiso = await Geolocator.checkPermission();

    // Si nunca se ha solicitado o fue denegado una vez, solicitarlo
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        return {
          'exito': false,
          'tipo': 'denegado',
          'mensaje': 'Permiso de ubicación denegado. AquaFast necesita tu ubicación para asignarte el distribuidor más cercano.',
        };
      }
    }

    // Si fue denegado permanentemente
    if (permiso == LocationPermission.deniedForever) {
      return {
        'exito': false,
        'tipo': 'denegado_permanente',
        'mensaje': 'Permiso denegado permanentemente. Habilita la ubicación desde los ajustes de la aplicación.',
      };
    }

    // Permiso concedido — obtener ubicación
    try {
      Position posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return {
        'exito': true,
        'tipo': 'concedido',
        'latitud': posicion.latitude,
        'longitud': posicion.longitude,
        'mensaje': 'Ubicación obtenida correctamente.',
      };
    } catch (e) {
      return {
        'exito': false,
        'tipo': 'error',
        'mensaje': 'No se pudo obtener la ubicación: $e',
      };
    }
  }

  /// Abre los ajustes de la aplicación para que el usuario
  /// pueda habilitar el permiso denegado permanentemente.
  Future<void> abrirAjustes() async {
    await Geolocator.openAppSettings();
  }

  /// Abre los ajustes de ubicación del dispositivo.
  Future<void> abrirAjustesUbicacion() async {
    await Geolocator.openLocationSettings();
  }
}