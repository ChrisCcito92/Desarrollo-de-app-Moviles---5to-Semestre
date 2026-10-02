import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pedido_service.dart';

class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  final PedidoService _pedidoService = PedidoService();
  List<dynamic> _pedidos = [];
  bool _cargando = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    final token = context.read<AuthProvider>().usuario?.accessToken ?? '';
    final resultado = await _pedidoService.obtenerMisPedidos(token);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (resultado['exito']) {
        _pedidos = resultado['data'];
        _error = '';
      } else {
        _error = resultado['mensaje'];
      }
    });
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    await _cargarPedidos();
  }

  // Abre el detalle y, al volver, recarga la lista por si el pedido cambió
  Future<void> _abrirDetalle(int idPedido) async {
    await Navigator.pushNamed(context, '/detalle-pedido', arguments: idPedido);
    if (mounted) _recargar();
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente': return Colors.orange;
      case 'aceptado': return Colors.blue;
      case 'en_camino': return Colors.purple;
      case 'entregado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'pendiente': return Icons.hourglass_empty;
      case 'aceptado': return Icons.check_circle_outline;
      case 'en_camino': return Icons.delivery_dining;
      case 'entregado': return Icons.check_circle;
      case 'cancelado': return Icons.cancel;
      default: return Icons.info;
    }
  }

  String _dinero(dynamic valor) {
    final numero = double.tryParse('$valor') ?? 0;
    return '\$${numero.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Mis pedidos', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _recargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(_error, textAlign: TextAlign.center),
                    ],
                  ),
                )
              : _pedidos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined,
                              color: Colors.grey, size: 80),
                          const SizedBox(height: 16),
                          const Text('No tienes pedidos aún',
                              style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/pedido'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text('Hacer mi primer pedido',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarPedidos,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _pedidos.length,
                        itemBuilder: (context, index) {
                          final pedido = _pedidos[index];
                          final estado = pedido['estado_pedido'] as String;
                          final color = _colorEstado(estado);
                          final icono = _iconoEstado(estado);
                          final detalles = pedido['detalles'] as List;
                          final distribuidor = pedido['distribuidor'];
                          final calificacion = pedido['calificacion_pedido'] as int?;

                          return GestureDetector(
                            onTap: () => _abrirDetalle(pedido['id_pedido'] as int),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Pedido #${pedido['id_pedido']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: color),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(icono, color: color, size: 14),
                                              const SizedBox(width: 4),
                                              Text(estado.replaceAll('_', ' '),
                                                  style: TextStyle(
                                                      color: color,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (distribuidor != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.store, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(distribuidor['nombre_comercial'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    ...detalles.map((d) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.water_drop,
                                                  size: 14, color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${d['cantidad']}x ${d['producto']?['tipo_bidon'] ?? 'Bidón'}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        )),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          pedido['metodo_pago'] == 'efectivo'
                                              ? '💵 Efectivo'
                                              : '💳 Tarjeta',
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 13),
                                        ),
                                        Text(_dinero(pedido['total_pagar']),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.blue)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (calificacion != null) ...[
                                          ...List.generate(
                                            5,
                                            (i) => Icon(
                                              i < calificacion ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        ] else if (estado == 'entregado')
                                          const Text('Pendiente de calificar',
                                              style: TextStyle(
                                                  color: Colors.orange, fontSize: 12)),
                                        const Spacer(),
                                        const Text('Ver detalle',
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.blue, size: 18),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}