import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pedido_service.dart';

class _EstiloEstado {
  final String etiqueta;
  final Color color;
  final IconData icono;
  const _EstiloEstado(this.etiqueta, this.color, this.icono);
}

class _Accion {
  final String estado;
  final String etiqueta;
  final bool destructiva;
  const _Accion(this.estado, this.etiqueta, {this.destructiva = false});
}

const Map<String, _EstiloEstado> _estilos = {
  'pendiente': _EstiloEstado('Pendiente', Colors.orange, Icons.schedule),
  'aceptado': _EstiloEstado('Aceptado', Colors.blue, Icons.check_circle_outline),
  'en_camino': _EstiloEstado('En camino', Colors.purple, Icons.local_shipping),
  'entregado': _EstiloEstado('Entregado', Colors.green, Icons.done_all),
  'cancelado': _EstiloEstado('Cancelado', Colors.red, Icons.cancel_outlined),
};

// Acciones disponibles según el estado actual (mismo flujo que valida el backend)
const Map<String, List<_Accion>> _acciones = {
  'pendiente': [
    _Accion('cancelado', 'Rechazar', destructiva: true),
    _Accion('aceptado', 'Aceptar'),
  ],
  'aceptado': [
    _Accion('cancelado', 'Cancelar', destructiva: true),
    _Accion('en_camino', 'Salir a entregar'),
  ],
  'en_camino': [
    _Accion('entregado', 'Marcar entregado'),
  ],
};

const Map<String?, String> _filtros = {
  null: 'Todos',
  'pendiente': 'Pendientes',
  'aceptado': 'Aceptados',
  'en_camino': 'En camino',
  'entregado': 'Entregados',
  'cancelado': 'Cancelados',
};

class PanelDistribuidorScreen extends StatefulWidget {
  const PanelDistribuidorScreen({super.key});

  @override
  State<PanelDistribuidorScreen> createState() => _PanelDistribuidorScreenState();
}

class _PanelDistribuidorScreenState extends State<PanelDistribuidorScreen> {
  final _service = PedidoService();
  final _scroll = ScrollController();
  final List<dynamic> _pedidos = [];
  final Set<int> _actualizando = {};

  String? _filtro;
  int _pagina = 1;
  int _totalPaginas = 1;
  int _total = 0;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  String _nombreDistribuidora = '';

  String get _token => context.read<AuthProvider>().usuario?.accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alHacerScroll);
    _cargar(reiniciar: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _cargar();
    }
  }

  /// Carga la primera página (reiniciar) o la siguiente (scroll infinito).
  Future<void> _cargar({bool reiniciar = false}) async {
    if (reiniciar) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    } else {
      if (_cargando || _cargandoMas || _pagina >= _totalPaginas) return;
      setState(() => _cargandoMas = true);
    }

    final paginaAPedir = reiniciar ? 1 : _pagina + 1;
    final r = await _service.obtenerPedidosDistribuidor(
      _token,
      pagina: paginaAPedir,
      estado: _filtro,
    );

    if (!mounted) return;

    if (r['exito'] == true) {
      final paginacion = (r['paginacion'] ?? {}) as Map;
      setState(() {
        if (reiniciar) _pedidos.clear();
        _pedidos.addAll((r['data'] ?? []) as List);
        _pagina = paginaAPedir;
        _totalPaginas = (paginacion['total_paginas'] ?? 1) as int;
        _total = (paginacion['total'] ?? _pedidos.length) as int;
        _nombreDistribuidora = (r['distribuidor'] ?? '') as String;
        _cargando = false;
        _cargandoMas = false;
      });
    } else {
      setState(() {
        if (reiniciar) _error = r['mensaje'];
        _cargando = false;
        _cargandoMas = false;
      });
      if (!reiniciar) _mostrarMensaje(r['mensaje'], error: true);
    }
  }

  Future<void> _cambiarEstado(Map pedido, _Accion accion) async {
    final id = pedido['id_pedido'] as int;
    final nuevo = _estilos[accion.estado]!.etiqueta;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accion.etiqueta),
        content: Text('¿Confirmas cambiar el pedido #$id a "$nuevo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _actualizando.add(id));
    final r = await _service.actualizarEstadoPedido(_token, id, accion.estado);
    if (!mounted) return;
    setState(() => _actualizando.remove(id));

    if (r['exito'] == true) {
      _mostrarMensaje('Pedido #$id actualizado a "$nuevo".');
      // Se recarga desde el backend para mostrar el dato real guardado en la base
      await _cargar(reiniciar: true);
    } else {
      _mostrarMensaje(r['mensaje'], error: true);
    }
  }

  void _mostrarMensaje(String? texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto ?? ''),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatearFecha(dynamic valor) {
    final fecha = DateTime.tryParse('$valor')?.toLocal();
    if (fecha == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  String _formatearDinero(dynamic valor) {
    final numero = double.tryParse('$valor') ?? 0;
    return '\$${numero.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pedidos recibidos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_nombreDistribuidora.isNotEmpty)
              Text(
                _nombreDistribuidora,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _barraFiltros(),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _barraFiltros() {
    return Container(
      color: Colors.white,
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _filtros.entries.map((entrada) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entrada.value),
              selected: _filtro == entrada.key,
              onSelected: (_) {
                if (_filtro == entrada.key) return;
                setState(() => _filtro = entrada.key);
                _cargar(reiniciar: true);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando && _pedidos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _cargar(reiniciar: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(reiniciar: true),
      child: _pedidos.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'No hay pedidos en esta categoría.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _pedidos.length + 1,
              itemBuilder: (context, i) {
                if (i == _pedidos.length) return _pieLista();
                return _tarjetaPedido(_pedidos[i] as Map);
              },
            ),
    );
  }

  Widget _pieLista() {
    if (_cargandoMas) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          'Mostrando ${_pedidos.length} de $_total pedido(s)',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _tarjetaPedido(Map pedido) {
    final id = pedido['id_pedido'] as int;
    final estado = (pedido['estado_pedido'] ?? 'pendiente') as String;
    final estilo = _estilos[estado] ?? _estilos['pendiente']!;
    final cliente = (pedido['usuario'] ?? {}) as Map;
    final direccion = (pedido['direccion'] ?? {}) as Map;
    final detalles = (pedido['detalles'] ?? []) as List;
    final acciones = _acciones[estado] ?? const [];
    final ocupado = _actualizando.contains(id);
    final observaciones = (pedido['observaciones'] ?? '').toString();

    final productos = detalles
        .map((d) => '${d['cantidad']} × ${d['producto']?['tipo_bidon'] ?? 'Bidón'}')
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.pushNamed(context, '/detalle-pedido', arguments: id);
          if (mounted) _cargar(reiniciar: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pedido #$id',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  _chipEstado(estilo),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatearFecha(pedido['fecha_pedido']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Divider(height: 20),
              _fila(Icons.person, '${cliente['nombre'] ?? ''} · ${cliente['telefono'] ?? ''}'),
              _fila(
                Icons.location_on,
                '${direccion['alias'] ?? ''}: ${direccion['calle_referencia'] ?? ''}',
              ),
              _fila(Icons.water_drop, productos),
              _fila(
                Icons.payments,
                'Total: ${_formatearDinero(pedido['total_pagar'])} · ${pedido['metodo_pago'] ?? ''}',
              ),
              if (observaciones.isNotEmpty) _fila(Icons.notes, observaciones),
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                ocupado
                    ? const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < acciones.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _botonAccion(pedido, acciones[i])),
                          ],
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonAccion(Map pedido, _Accion accion) {
    if (accion.destructiva) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
        onPressed: () => _cambiarEstado(pedido, accion),
        child: Text(accion.etiqueta),
      );
    }
    return FilledButton(
      onPressed: () => _cambiarEstado(pedido, accion),
      child: Text(accion.etiqueta),
    );
  }

  Widget _chipEstado(_EstiloEstado estilo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estilo.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estilo.icono, size: 14, color: estilo.color),
          const SizedBox(width: 4),
          Text(
            estilo.etiqueta,
            style: TextStyle(
              color: estilo.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}