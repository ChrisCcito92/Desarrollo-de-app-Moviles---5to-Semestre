import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pedido_service.dart';

class DetallePedidoScreen extends StatefulWidget {
  final int idPedido;
  const DetallePedidoScreen({super.key, required this.idPedido});

  @override
  State<DetallePedidoScreen> createState() => _DetallePedidoScreenState();
}

class _DetallePedidoScreenState extends State<DetallePedidoScreen> {
  final PedidoService _pedidoService = PedidoService();
  Map<String, dynamic>? _pedido;
  String? _fuente;
  bool _cargando = true;
  bool _procesando = false;
  String _error = '';
  int _estrellas = 0;

  String get _token => context.read<AuthProvider>().usuario?.accessToken ?? '';
  bool get _esCliente => context.read<AuthProvider>().usuario?.tipoUsuario == 'cliente';
  String get _estado => (_pedido?['estado_pedido'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final resultado = await _pedidoService.obtenerDetallePedido(_token, widget.idPedido);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (resultado['exito'] == true) {
        _pedido = Map<String, dynamic>.from(resultado['data']);
        _fuente = resultado['fuente'];
        _error = '';
      } else {
        _error = resultado['mensaje'] ?? 'Error al cargar el pedido.';
      }
    });
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    await _cargarDetalle();
  }

  void _mostrarMensaje(String? texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto ?? ''),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _cancelarPedido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text(
          '¿Seguro que quieres cancelar el pedido #${widget.idPedido}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _procesando = true);
    final r = await _pedidoService.actualizarEstadoPedido(
      _token,
      widget.idPedido,
      'cancelado',
    );
    if (!mounted) return;
    setState(() => _procesando = false);

    if (r['exito'] == true) {
      _mostrarMensaje('Pedido cancelado correctamente.');
      await _recargar();
    } else {
      _mostrarMensaje(r['mensaje'], error: true);
    }
  }

  Future<void> _enviarCalificacion() async {
    if (_estrellas == 0) return;

    setState(() => _procesando = true);
    final r = await _pedidoService.calificarPedido(_token, widget.idPedido, _estrellas);
    if (!mounted) return;
    setState(() => _procesando = false);

    if (r['exito'] == true) {
      _mostrarMensaje(r['mensaje'] ?? '¡Gracias por tu calificación!');
      await _recargar();
    } else {
      _mostrarMensaje(r['mensaje'], error: true);
    }
  }

  // ─── Utilidades de formato ─────────────────────────────────────────────

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'aceptado':
        return Colors.blue;
      case 'en_camino':
        return Colors.purple;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'aceptado':
        return Icons.check_circle_outline;
      case 'en_camino':
        return Icons.delivery_dining;
      case 'entregado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _dinero(dynamic valor) {
    final numero = double.tryParse('$valor') ?? 0;
    return '\$${numero.toStringAsFixed(2)}';
  }

  String _fecha(dynamic valor) {
    final f = DateTime.tryParse('$valor')?.toLocal();
    if (f == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }

  Widget _tarjeta({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  // ─── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Pedido #${widget.idPedido}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _procesando ? null : _recargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(_error, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _recargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pedido == null
                  ? const Center(child: Text('Pedido no encontrado'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _seccionEstado(),
                          _seccionSeguimiento(),
                          _seccionCalificacion(),
                          _seccionDetalle(),
                          _seccionDireccion(),
                          _seccionCliente(),
                          _seccionDistribuidor(),
                          _botonCancelar(),
                        ],
                      ),
                    ),
    );
  }

  Widget _seccionEstado() {
    final color = _colorEstado(_estado);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(_iconoEstado(_estado), color: color, size: 48),
            const SizedBox(height: 8),
            Text(
              _estado.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Realizado el ${_fecha(_pedido!['fecha_pedido'])}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_fuente != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _fuente == 'cache' ? Icons.bolt : Icons.storage,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _fuente == 'cache'
                        ? 'Cargado desde caché (Redis)'
                        : 'Cargado desde la base de datos',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seccionSeguimiento() {
    if (_estado == 'cancelado') {
      return _tarjeta(
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este pedido fue cancelado. Los bidones se devolvieron al stock del distribuidor.',
              ),
            ),
          ],
        ),
      );
    }

    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Seguimiento'),
          _buildPaso(
            'Pedido confirmado',
            'Tu pedido fue recibido',
            _estado == 'pendiente',
            ['aceptado', 'en_camino', 'entregado'].contains(_estado),
          ),
          _buildPaso(
            'Pedido aceptado',
            'El distribuidor aceptó tu pedido',
            _estado == 'aceptado',
            ['en_camino', 'entregado'].contains(_estado),
          ),
          _buildPaso(
            'En camino',
            'El repartidor está en camino',
            _estado == 'en_camino',
            _estado == 'entregado',
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _estado == 'entregado' ? Colors.green : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entregado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _estado == 'entregado' ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (_pedido!['fecha_entrega_real'] != null)
                    Text(
                      _fecha(_pedido!['fecha_entrega_real']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaso(String titulo, String descripcion, bool activo, bool completado) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: completado
                    ? Colors.green
                    : activo
                        ? Colors.blue
                        : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                completado ? Icons.check : Icons.circle,
                color: Colors.white,
                size: 16,
              ),
            ),
            Container(width: 2, height: 40, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: completado || activo ? Colors.black : Colors.grey,
                  ),
                ),
                Text(
                  descripcion,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seccionCalificacion() {
    if (!_esCliente || _estado != 'entregado') return const SizedBox.shrink();

    final calificacion = _pedido!['calificacion_pedido'] as int?;

    // Ya calificado: se muestran las estrellas en modo lectura
    if (calificacion != null) {
      return _tarjeta(
        child: Column(
          children: [
            _titulo('Tu calificación'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < calificacion ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calificaste este pedido con $calificacion de 5',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Pendiente de calificar
    return _tarjeta(
      child: Column(
        children: [
          _titulo('¿Cómo estuvo tu pedido?'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final valor = i + 1;
              return IconButton(
                iconSize: 36,
                onPressed: _procesando ? null : () => setState(() => _estrellas = valor),
                icon: Icon(
                  valor <= _estrellas ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _estrellas == 0 || _procesando ? null : _enviarCalificacion,
              child: _procesando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar calificación'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionDetalle() {
    final detalles = (_pedido!['detalles'] ?? []) as List;
    final observaciones = (_pedido!['observaciones'] ?? '').toString();

    return _tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Detalle del pedido'),
          ...detalles.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text('${d['cantidad']}x ${d['producto']?['tipo_bidon'] ?? 'Bidón'}'),
                    ],
                  ),
                  Text(
                    _dinero(d['subtotal']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _dinero(_pedido!['total_pagar']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payment, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _pedido!['metodo_pago'] == 'efectivo' ? 'Pago en efectivo' : 'Pago con tarjeta',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          if (observaciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(observaciones, style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionDireccion() {
    final direccion = _pedido!['direccion'];
    if (direccion == null) return const SizedBox.shrink();

    return _tarjeta(
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dirección de entrega',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '${direccion['alias'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${direccion['calle_referencia'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Solo el distribuidor necesita ver los datos de contacto del cliente
  Widget _seccionCliente() {
    final cliente = _pedido!['usuario'];
    if (_esCliente || cliente == null) return const SizedBox.shrink();

    return _tarjeta(
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cliente', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '${cliente['nombre'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${cliente['telefono'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionDistribuidor() {
    final distribuidor = _pedido!['distribuidor'];
    if (distribuidor == null) return const SizedBox.shrink();

    return _tarjeta(
      child: Row(
        children: [
          const Icon(Icons.store, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Distribuidor', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '${distribuidor['nombre_comercial'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${distribuidor['telefono_contacto'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonCancelar() {
    if (!_esCliente || _estado != 'pendiente') return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _procesando ? null : _cancelarPedido,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar pedido'),
      ),
    );
  }
}