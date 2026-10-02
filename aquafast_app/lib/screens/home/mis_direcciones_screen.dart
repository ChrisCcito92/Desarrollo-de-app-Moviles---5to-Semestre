import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/direccion_service.dart';
import '../../services/location_service.dart';

class MisDireccionesScreen extends StatefulWidget {
  const MisDireccionesScreen({super.key});

  @override
  State<MisDireccionesScreen> createState() => _MisDireccionesScreenState();
}

class _MisDireccionesScreenState extends State<MisDireccionesScreen> {
  final DireccionService _direccionService = DireccionService();
  final LocationService _locationService = LocationService();
  List<dynamic> _direcciones = [];
  bool _cargando = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarDirecciones();
  }

  Future<void> _cargarDirecciones() async {
    final token = context.read<AuthProvider>().usuario?.accessToken ?? '';
    final resultado = await _direccionService.obtenerDirecciones(token);
    setState(() {
      _cargando = false;
      if (resultado['exito']) {
        _direcciones = resultado['data'];
      } else {
        _error = resultado['mensaje'];
      }
    });
  }

  Future<void> _eliminarDireccion(int id) async {
    final token = context.read<AuthProvider>().usuario?.accessToken ?? '';
    final resultado = await _direccionService.eliminarDireccion(token, id);
    if (resultado['exito']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección eliminada.'), backgroundColor: Colors.green),
      );
      _cargarDirecciones();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado['mensaje']), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarFormulario() {
    final aliasController = TextEditingController();
    final calleController = TextEditingController();
    double? latitud;
    double? longitud;
    bool predeterminada = false;
    bool obteniendo = false;
    String mensajeUbicacion = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva dirección',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: aliasController,
                decoration: InputDecoration(
                  labelText: 'Alias (ej: Casa, Oficina)',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calleController,
                decoration: InputDecoration(
                  labelText: 'Calle y referencia',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: obteniendo
                      ? null
                      : () async {
                          setModalState(() => obteniendo = true);
                          final resultado = await _locationService.obtenerUbicacion();
                          setModalState(() {
                            obteniendo = false;
                            if (resultado['exito']) {
                              latitud = resultado['latitud'];
                              longitud = resultado['longitud'];
                              mensajeUbicacion =
                                  '✅ Ubicación obtenida: ${latitud!.toStringAsFixed(4)}, ${longitud!.toStringAsFixed(4)}';
                            } else {
                              mensajeUbicacion = '❌ ${resultado['mensaje']}';
                            }
                          });
                        },
                  icon: obteniendo
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(obteniendo ? 'Obteniendo...' : 'Usar mi ubicación actual'),
                ),
              ),
              if (mensajeUbicacion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(mensajeUbicacion,
                    style: TextStyle(
                      fontSize: 12,
                      color: mensajeUbicacion.startsWith('✅') ? Colors.green : Colors.red,
                    )),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: predeterminada,
                    onChanged: (v) => setModalState(() => predeterminada = v ?? false),
                  ),
                  const Text('Establecer como predeterminada'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (aliasController.text.isEmpty || calleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Completa todos los campos.')),
                      );
                      return;
                    }
                    final token = context.read<AuthProvider>().usuario?.accessToken ?? '';
                    final resultado = await _direccionService.crearDireccion(
                      token: token,
                      alias: aliasController.text.trim(),
                      calleReferencia: calleController.text.trim(),
                      latitud: latitud ?? 0.0,
                      longitud: longitud ?? 0.0,
                      predeterminada: predeterminada,
                    );
                    if (resultado['exito']) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Dirección guardada.'),
                            backgroundColor: Colors.green),
                      );
                      _cargarDirecciones();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(resultado['mensaje']),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar dirección',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Mis direcciones', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _mostrarFormulario,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _direcciones.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off, color: Colors.grey, size: 80),
                          const SizedBox(height: 16),
                          const Text('No tienes direcciones guardadas',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _mostrarFormulario,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Agregar dirección',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _direcciones.length,
                      itemBuilder: (context, index) {
                        final d = _direcciones[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: d['predeterminada'] == true
                                  ? Colors.blue
                                  : Colors.grey[200]!,
                              width: d['predeterminada'] == true ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(d['alias'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (d['predeterminada'] == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('Principal',
                                                style: TextStyle(
                                                    color: Colors.white, fontSize: 10)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(d['calle_referencia'],
                                        style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar dirección'),
                                    content: Text(
                                        '¿Deseas eliminar la dirección "${d['alias']}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _eliminarDireccion(d['id_direccion']);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: const Text('Eliminar',
                                            style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      floatingActionButton: _direcciones.isNotEmpty
          ? FloatingActionButton(
              onPressed: _mostrarFormulario,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}