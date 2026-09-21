import 'package:flutter/material.dart';
import '../../services/location_service.dart';

class UbicacionScreen extends StatefulWidget {
  const UbicacionScreen({super.key});

  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  final LocationService _locationService = LocationService();
  bool _cargando = false;
  Map<String, dynamic>? _resultado;

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _cargando = true;
      _resultado = null;
    });

    final resultado = await _locationService.obtenerUbicacion();

    setState(() {
      _cargando = false;
      _resultado = resultado;
    });
  }

  Future<void> _abrirAjustes() async {
    await _locationService.abrirAjustes();
  }

  Future<void> _abrirAjustesUbicacion() async {
    await _locationService.abrirAjustesUbicacion();
  }

  Widget _buildResultado() {
    if (_resultado == null) return const SizedBox();

    final exito = _resultado!['exito'] as bool;
    final tipo = _resultado!['tipo'] as String;
    final mensaje = _resultado!['mensaje'] as String;

    Color color = exito ? Colors.green : Colors.red;
    IconData icono = exito ? Icons.check_circle : Icons.error;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Column(
            children: [
              Icon(icono, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 14),
              ),
              if (exito) ...[
                const SizedBox(height: 8),
                Text(
                  'Latitud: ${_resultado!['latitud']?.toStringAsFixed(6)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Longitud: ${_resultado!['longitud']?.toStringAsFixed(6)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Botones de degradación elegante
        if (!exito && tipo == 'denegado_permanente')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _abrirAjustes,
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text(
                'Abrir ajustes de la app',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (!exito && tipo == 'servicio_desactivado')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _abrirAjustesUbicacion,
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text(
                'Activar ubicación',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Mi ubicación',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Detectar mi ubicación',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AquaFast usa tu ubicación para asignarte el distribuidor de bidones más cercano y calcular el tiempo de entrega.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _cargando ? null : _obtenerUbicacion,
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      label: _cargando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Obtener ubicación',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
            const SizedBox(height: 24),
            _buildResultado(),
          ],
        ),
      ),
    );
  }
}