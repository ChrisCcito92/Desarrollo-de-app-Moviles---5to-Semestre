import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pedido_service.dart';
import '../../services/direccion_service.dart';

class PedirBidonScreen extends StatefulWidget {
  const PedirBidonScreen({super.key});

  @override
  State<PedirBidonScreen> createState() => _PedirBidonScreenState();
}

class _PedirBidonScreenState extends State<PedirBidonScreen> {
  final PedidoService _pedidoService = PedidoService();
  final DireccionService _direccionService = DireccionService();

  List<dynamic> _direcciones = [];
  List<dynamic> _distribuidores = [];
  List<dynamic> _productos = [];
  Map<int, int> _cantidades = {};
  int? _direccionSeleccionada;
  int? _distribuidorSeleccionado;
  String _metodoPago = 'efectivo';
  bool _cargandoDirecciones = true;
  bool _cargandoDistribuidores = true;
  bool _cargandoProductos = false;
  bool _enviandoPedido = false;
  String _error = '';

  String get _token => context.read<AuthProvider>().usuario?.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _cargarDirecciones();
    _cargarDistribuidores();
  }

  // ─── Carga de datos ────────────────────────────────────────────────────

  Future<void> _cargarDirecciones() async {
    final resultado = await _direccionService.obtenerDirecciones(_token);
    if (!mounted) return;
    setState(() {
      _cargandoDirecciones = false;
      if (resultado['exito'] == true) {
        _direcciones = (resultado['data'] ?? []) as List;

        // Se mantiene la selección si la dirección sigue existiendo;
        // si no, se elige la predeterminada o la primera.
        final ids = _direcciones.map((d) => d['id_direccion'] as int).toList();
        if (_direccionSeleccionada == null || !ids.contains(_direccionSeleccionada)) {
          final predeterminada = _direcciones.firstWhere(
            (d) => d['predeterminada'] == true,
            orElse: () => _direcciones.isNotEmpty ? _direcciones.first : null,
          );
          _direccionSeleccionada = predeterminada?['id_direccion'] as int?;
        }
      } else {
        _error = resultado['mensaje'] ?? 'Error al cargar tus direcciones.';
      }
    });
  }

  Future<void> _cargarDistribuidores() async {
    final resultado = await _pedidoService.obtenerDistribuidores(_token);
    if (!mounted) return;
    setState(() {
      _cargandoDistribuidores = false;
      if (resultado['exito']) {
        _distribuidores = resultado['data'];
      } else {
        _error = resultado['mensaje'];
      }
    });
  }

  Future<void> _cargarProductos(int idDistribuidor) async {
    setState(() {
      _cargandoProductos = true;
      _productos = [];
      _cantidades = {};
    });
    final resultado = await _pedidoService.obtenerProductos(_token, idDistribuidor);
    if (!mounted) return;
    setState(() {
      _cargandoProductos = false;
      if (resultado['exito']) {
        _productos = resultado['data'];
        for (var p in _productos) {
          _cantidades[p['id_producto']] = 0;
        }
      } else {
        _error = resultado['mensaje'];
      }
    });
  }

  Future<void> _irAMisDirecciones() async {
    await Navigator.pushNamed(context, '/mis-direcciones');
    if (!mounted) return;
    setState(() => _cargandoDirecciones = true);
    await _cargarDirecciones();
  }

  // ─── Lógica del pedido ─────────────────────────────────────────────────

  double _precio(dynamic producto) => double.tryParse('${producto['precio_unitario']}') ?? 0;

  double _calcularTotal() {
    double total = 0;
    for (var p in _productos) {
      total += (_cantidades[p['id_producto']] ?? 0) * _precio(p);
    }
    return total;
  }

  List<Map<String, dynamic>> _buildDetalles() {
    return _productos
        .where((p) => (_cantidades[p['id_producto']] ?? 0) > 0)
        .map((p) => {
              'id_producto': p['id_producto'],
              'cantidad': _cantidades[p['id_producto']],
            })
        .toList();
  }

  Map? get _direccionActual {
    for (final d in _direcciones) {
      if (d['id_direccion'] == _direccionSeleccionada) return d as Map;
    }
    return null;
  }

  Future<void> _confirmarPedido() async {
    if (_direccionSeleccionada == null) {
      setState(() => _error = 'Selecciona la dirección donde quieres recibir tu pedido.');
      return;
    }
    final detalles = _buildDetalles();
    if (detalles.isEmpty) {
      setState(() => _error = 'Selecciona al menos un bidón.');
      return;
    }

    setState(() {
      _enviandoPedido = true;
      _error = '';
    });

    final direccion = _direccionActual;
    final resultado = await _pedidoService.crearPedido(
      token: _token,
      idDireccion: _direccionSeleccionada!,
      idDistribuidor: _distribuidorSeleccionado!,
      metodoPago: _metodoPago,
      detalles: detalles,
    );

    if (!mounted) return;
    setState(() => _enviandoPedido = false);

    if (resultado['exito']) {
      final total = double.tryParse('${resultado['data']['total_pagar']}') ?? 0;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Pedido confirmado!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              Text(
                'Tu pedido #${resultado['data']['id_pedido']} fue registrado exitosamente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (direccion != null)
                Text(
                  'Se entregará en: ${direccion['alias']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 8),
              Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/mis-pedidos');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Ver mis pedidos', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      setState(() => _error = resultado['mensaje']);
    }
  }

  // ─── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cargandoInicial = _cargandoDirecciones && _cargandoDistribuidores;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Pedir bidón', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cargandoInicial
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(_error, style: TextStyle(color: Colors.red[800])),
                    ),

                  // 1. Dirección de entrega
                  _titulo('1. ¿Dónde entregamos tu pedido?'),
                  _seccionDireccion(),
                  const SizedBox(height: 24),

                  // 2. Distribuidor
                  _titulo('2. Selecciona el distribuidor'),
                  if (_cargandoDistribuidores)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._distribuidores.map(_tarjetaDistribuidor),

                  if (_cargandoProductos)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // 3. Productos, pago y confirmación
                  if (_productos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _titulo('3. Selecciona los bidones'),
                    ..._productos.map(_tarjetaProducto),
                    const SizedBox(height: 16),
                    _titulo('4. Método de pago'),
                    _selectorPago(),
                    const SizedBox(height: 24),
                    _resumenTotal(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _enviandoPedido ? null : _confirmarPedido,
                        icon: const Icon(Icons.shopping_cart, color: Colors.white),
                        label: _enviandoPedido
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirmar pedido',
                                style: TextStyle(color: Colors.white, fontSize: 16)),
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
                ],
              ),
            ),
    );
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _seccionDireccion() {
    if (_cargandoDirecciones) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_direcciones.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off, color: Colors.orange, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Aún no tienes direcciones registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Agrega una para que el distribuidor sepa dónde entregar tu pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _irAMisDirecciones,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Agregar dirección'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._direcciones.map((d) {
          final id = d['id_direccion'] as int;
          final seleccionada = id == _direccionSeleccionada;
          final predeterminada = d['predeterminada'] == true;

          return GestureDetector(
            onTap: () => setState(() {
              _direccionSeleccionada = id;
              _error = '';
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: seleccionada ? Colors.blue.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: seleccionada ? Colors.blue : Colors.grey[200]!,
                  width: seleccionada ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    predeterminada ? Icons.home : Icons.location_on,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${d['alias'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (predeterminada) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Predeterminada',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${d['calle_referencia'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    seleccionada ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: seleccionada ? Colors.blue : Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: _irAMisDirecciones,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Agregar otra dirección'),
        ),
      ],
    );
  }

  Widget _tarjetaDistribuidor(dynamic d) {
    final seleccionado = _distribuidorSeleccionado == d['id_distribuidor'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _distribuidorSeleccionado = d['id_distribuidor'];
          _error = '';
        });
        _cargarProductos(d['id_distribuidor']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? Colors.blue : Colors.grey[200]!,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.store, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['nombre_comercial'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('⭐ ${d['calificacion_promedio']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            if (seleccionado) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaProducto(dynamic p) {
    final id = p['id_producto'] as int;
    final cantidad = _cantidades[id] ?? 0;
    final stock = (p['stock_disponible'] ?? 0) as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['tipo_bidon'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${_precio(p).toStringAsFixed(2)} c/u',
                    style: const TextStyle(color: Colors.grey)),
                Text('Stock: $stock', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: cantidad > 0 ? () => setState(() => _cantidades[id] = cantidad - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.blue,
              ),
              Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                // No se permite pedir más unidades de las que hay en stock
                onPressed: cantidad < stock ? () => setState(() => _cantidades[id] = cantidad + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opcionPago(String valor, String etiqueta, IconData icono, Color color) {
    final seleccionado = _metodoPago == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPago = valor),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: seleccionado ? Colors.blue.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? Colors.blue : Colors.grey[200]!,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icono, color: color),
              const SizedBox(height: 4),
              Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorPago() {
    return Row(
      children: [
        _opcionPago('efectivo', 'Efectivo', Icons.money, Colors.green),
        const SizedBox(width: 12),
        _opcionPago('tarjeta', 'Tarjeta', Icons.credit_card, Colors.blue),
      ],
    );
  }

  Widget _resumenTotal() {
    final direccion = _direccionActual;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        children: [
          if (direccion != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Entrega en: ${direccion['alias']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a pagar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('\$${_calcularTotal().toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }
}