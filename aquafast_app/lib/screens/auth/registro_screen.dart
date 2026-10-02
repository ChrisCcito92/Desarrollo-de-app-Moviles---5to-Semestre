import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();

  // Datos comunes
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarController = TextEditingController();

  // Datos de la distribuidora
  final _nombreComercialController = TextEditingController();
  final _radioController = TextEditingController(text: '5');

  String _rol = 'cliente';
  double? _latitud;
  double? _longitud;
  bool _obteniendoUbicacion = false;
  bool _verContrasena = false;
  bool _cargando = false;
  String _error = '';

  bool get _esDistribuidor => _rol == 'distribuidor';

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _contrasenaController.dispose();
    _confirmarController.dispose();
    _nombreComercialController.dispose();
    _radioController.dispose();
    super.dispose();
  }

  double? _leerDecimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _usarUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);
    final resultado = await _locationService.obtenerUbicacion();
    if (!mounted) return;
    setState(() => _obteniendoUbicacion = false);

    if (resultado['exito'] == true) {
      setState(() {
        _latitud = resultado['latitud'] as double;
        _longitud = resultado['longitud'] as double;
        if (_error.contains('ubicación')) _error = '';
      });
      return;
    }

    final tipo = resultado['tipo'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado['mensaje'] ?? 'No se pudo obtener la ubicación.'),
        backgroundColor: Colors.red,
        action: tipo == 'denegado_permanente'
            ? SnackBarAction(
                label: 'Ajustes',
                textColor: Colors.white,
                onPressed: _locationService.abrirAjustes,
              )
            : tipo == 'servicio_desactivado'
                ? SnackBarAction(
                    label: 'Activar',
                    textColor: Colors.white,
                    onPressed: _locationService.abrirAjustesUbicacion,
                  )
                : null,
      ),
    );
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_esDistribuidor && (_latitud == null || _longitud == null)) {
      setState(() => _error =
          'Registra la ubicación de tu distribuidora con el botón "Usar mi ubicación actual".');
      return;
    }

    setState(() {
      _cargando = true;
      _error = '';
    });

    final resultado = await AuthService().registro(
      _nombreController.text.trim(),
      _correoController.text.trim(),
      _telefonoController.text.trim(),
      _contrasenaController.text.trim(),
      tipoUsuario: _rol,
      distribuidor: _esDistribuidor
          ? {
              'nombre_comercial': _nombreComercialController.text.trim(),
              'radio_cobertura_km': _leerDecimal(_radioController.text),
              'latitud': _latitud,
              'longitud': _longitud,
            }
          : null,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (resultado['exito']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esDistribuidor
              ? 'Distribuidora registrada. Inicia sesión y agrega tus productos en "Mi inventario".'
              : 'Usuario registrado. Inicia sesión.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() => _error = resultado['mensaje']);
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono, {Widget? sufijo, String? ayuda}) {
    return InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      prefixIcon: Icon(icono),
      suffixIcon: sufijo,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Selector de rol ───────────────────────────────
                const Text(
                  '¿Cómo quieres usar AquaFast?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'cliente',
                        label: Text('Cliente'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: 'distribuidor',
                        label: Text('Distribuidor'),
                        icon: Icon(Icons.local_shipping),
                      ),
                    ],
                    selected: {_rol},
                    onSelectionChanged: (seleccion) => setState(() {
                      _rol = seleccion.first;
                      _error = '';
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _esDistribuidor
                      ? 'Registra tu distribuidora para recibir pedidos de tus clientes.'
                      : 'Pide bidones de agua a domicilio de forma rápida.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ─── Datos personales ──────────────────────────────
                TextFormField(
                  controller: _nombreController,
                  decoration: _decoracion(
                    _esDistribuidor ? 'Nombre del responsable' : 'Nombre completo',
                    Icons.person,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio.';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoracion('Correo electrónico', Icons.email),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El correo es obligatorio.';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Ingresa un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoracion('Teléfono', Icons.phone),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El teléfono es obligatorio.';
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                      return 'Ingresa un teléfono válido de 10 dígitos.';
                    }
                    return null;
                  },
                ),

                // ─── Datos de la distribuidora ─────────────────────
                if (_esDistribuidor) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Datos de la distribuidora',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tus productos y su stock los agregas después, desde "Mi inventario".',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombreComercialController,
                    decoration: _decoracion('Nombre comercial', Icons.store),
                    validator: (value) {
                      if (!_esDistribuidor) return null;
                      if (value == null || value.trim().length < 3) {
                        return 'El nombre comercial debe tener al menos 3 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _radioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoracion(
                      'Radio de cobertura (km)',
                      Icons.radar,
                      ayuda: 'Distancia máxima a la que entregas',
                    ),
                    validator: (value) {
                      if (!_esDistribuidor) return null;
                      final radio = _leerDecimal(value ?? '');
                      if (radio == null || radio <= 0 || radio > 100) {
                        return 'Ingresa un radio entre 0 y 100 km.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _latitud != null ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _latitud != null ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _latitud != null ? Icons.check_circle : Icons.location_off,
                              color: _latitud != null ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _latitud != null
                                    ? 'Ubicación de la base registrada\n'
                                        '${_latitud!.toStringAsFixed(5)}, ${_longitud!.toStringAsFixed(5)}'
                                    : 'Registra la ubicación de tu distribuidora.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _obteniendoUbicacion ? null : _usarUbicacionActual,
                            icon: _obteniendoUbicacion
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_latitud != null
                                ? 'Actualizar ubicación'
                                : 'Usar mi ubicación actual'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ─── Contraseña ────────────────────────────────────
                const SizedBox(height: 24),
                TextFormField(
                  controller: _contrasenaController,
                  obscureText: !_verContrasena,
                  decoration: _decoracion(
                    'Contraseña',
                    Icons.lock,
                    sufijo: IconButton(
                      icon: Icon(_verContrasena ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _verContrasena = !_verContrasena),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es obligatoria.';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarController,
                  obscureText: true,
                  decoration: _decoracion('Confirmar contraseña', Icons.lock_outline),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma tu contraseña.';
                    }
                    if (value != _contrasenaController.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                if (_error.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(_error, style: TextStyle(color: Colors.red[800])),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _registrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _esDistribuidor ? 'Registrar distribuidora' : 'Crear cuenta',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}