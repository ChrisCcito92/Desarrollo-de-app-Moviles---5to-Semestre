import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/producto_service.dart';

class MisProductosScreen extends StatefulWidget {
  /// Si es true, la pantalla abre directamente el formulario de nuevo producto.
  final bool abrirFormulario;
  const MisProductosScreen({super.key, this.abrirFormulario = false});

  @override
  State<MisProductosScreen> createState() => _MisProductosScreenState();
}

class _MisProductosScreenState extends State<MisProductosScreen> {
  final _service = ProductoService();
  List<dynamic> _productos = [];
  Map<String, dynamic> _resumen = {};
  final Set<int> _procesando = {};
  bool _cargando = true;
  String _error = '';

  String get _token => context.read<AuthProvider>().usuario?.accessToken ?? '';
  int get _umbral => (_resumen['umbral_stock_bajo'] ?? 10) as int;

  @override
  void initState() {
    super.initState();
    _cargar();
    if (widget.abrirFormulario) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirFormulario());
    }
  }

  Future<void> _cargar() async {
    final r = await _service.obtenerMisProductos(_token);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (r['exito'] == true) {
        _productos = (r['data'] ?? []) as List;
        _resumen = Map<String, dynamic>.from(r['resumen'] ?? {});
        _error = '';
      } else {
        _error = r['mensaje'] ?? 'Error al cargar el inventario.';
      }
    });
  }

  Future<void> _recargar() async {
    setState(() => _cargando = true);
    await _cargar();
  }

  void _mostrarMensaje(String? texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto ?? ''),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _ejecutar(int? idProducto, Future<Map<String, dynamic>> Function() accion) async {
    if (idProducto != null) setState(() => _procesando.add(idProducto));
    final r = await accion();
    if (!mounted) return;
    if (idProducto != null) setState(() => _procesando.remove(idProducto));
    _mostrarMensaje(r['mensaje'], error: r['exito'] != true);
    if (r['exito'] == true) await _cargar();
  }

  // ─── Acciones ──────────────────────────────────────────────────────────

  Future<void> _abrirFormulario({Map? producto}) async {
    final valores = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormularioProducto(producto: producto),
    );
    if (valores == null || !mounted) return;

    if (producto == null) {
      await _ejecutar(
        null,
        () => _service.crearProducto(
          _token,
          tipoBidon: valores['tipo_bidon'],
          precio: valores['precio_unitario'],
          stock: valores['stock_disponible'],
        ),
      );
    } else {
      final id = producto['id_producto'] as int;
      await _ejecutar(id, () => _service.actualizarProducto(_token, id, valores));
    }
  }

  Future<void> _agregarStock(Map producto) async {
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoAgregarStock(nombre: producto['tipo_bidon'] ?? ''),
    );
    if (cantidad == null || !mounted) return;
    final id = producto['id_producto'] as int;
    await _ejecutar(id, () => _service.actualizarProducto(_token, id, {'incremento': cantidad}));
  }

  Future<void> _cambiarActivo(Map producto) async {
    final id = producto['id_producto'] as int;
    final activo = producto['activo'] == true;
    await _ejecutar(id, () => _service.actualizarProducto(_token, id, {'activo': !activo}));
  }

  Future<void> _eliminar(Map producto) async {
    final id = producto['id_producto'] as int;
    final usadoEnPedidos = ((producto['_count'] ?? {})['detalles'] ?? 0) as int;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          usadoEnPedidos > 0
              ? '"${producto['tipo_bidon']}" aparece en $usadoEnPedidos pedido(s). '
                  'Para no perder el historial, se desactivará en lugar de eliminarse.'
              : '¿Seguro que quieres eliminar "${producto['tipo_bidon']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(usadoEnPedidos > 0 ? 'Desactivar' : 'Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _ejecutar(id, () => _service.eliminarProducto(_token, id));
  }

  // ─── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mi inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar producto'),
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
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _tarjetaResumen(),
                      const SizedBox(height: 16),
                      if (_productos.isEmpty)
                        _estadoVacio()
                      else
                        ..._productos.map((p) => _tarjetaProducto(p as Map)),
                    ],
                  ),
                ),
    );
  }

  Widget _tarjetaResumen() {
    final stockBajo = (_resumen['productos_stock_bajo'] ?? 0) as int;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _dato('Productos activos', '${_resumen['productos_activos'] ?? 0}', Icons.inventory_2),
          _dato('Stock total', '${_resumen['stock_total'] ?? 0}', Icons.water_drop),
          _dato(
            'Stock bajo',
            '$stockBajo',
            stockBajo > 0 ? Icons.warning_amber : Icons.check_circle,
          ),
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor, IconData icono) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Aún no tienes productos',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Agrega tu primer producto para empezar a recibir pedidos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaProducto(Map producto) {
    final id = producto['id_producto'] as int;
    final activo = producto['activo'] == true;
    final stock = (producto['stock_disponible'] ?? 0) as int;
    final precio = double.tryParse('${producto['precio_unitario']}') ?? 0;
    final ocupado = _procesando.contains(id);

    Color colorStock;
    String estadoStock;
    if (!activo) {
      colorStock = Colors.grey;
      estadoStock = 'Inactivo';
    } else if (stock == 0) {
      colorStock = Colors.red;
      estadoStock = 'Agotado';
    } else if (stock < _umbral) {
      colorStock = Colors.orange;
      estadoStock = 'Stock bajo';
    } else {
      colorStock = Colors.green;
      estadoStock = 'Disponible';
    }

    return Opacity(
      opacity: activo ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${producto['tipo_bidon'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '\$${precio.toStringAsFixed(2)} por unidad',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !ocupado,
                  onSelected: (opcion) {
                    switch (opcion) {
                      case 'editar':
                        _abrirFormulario(producto: producto);
                        break;
                      case 'activo':
                        _cambiarActivo(producto);
                        break;
                      case 'eliminar':
                        _eliminar(producto);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'activo',
                      child: ListTile(
                        leading: Icon(activo ? Icons.visibility_off : Icons.visibility),
                        title: Text(activo ? 'Desactivar' : 'Activar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock disponible', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$stock',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorStock,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 5),
                          child: Text('unidades', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorStock.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estadoStock,
                        style: TextStyle(
                          color: colorStock,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ocupado
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: activo ? () => _agregarStock(producto) : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar stock'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulario para crear o editar un producto ──────────────────────────

class _FormularioProducto extends StatefulWidget {
  final Map? producto;
  const _FormularioProducto({this.producto});

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tipoController;
  late final TextEditingController _precioController;
  late final TextEditingController _stockController;

  static const _sugerencias = ['Bidón 20 litros', 'Bidón 10 litros', 'Botellón 6 litros'];

  bool get _editando => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _tipoController = TextEditingController(text: p?['tipo_bidon']?.toString() ?? '');
    _precioController = TextEditingController(
      text: p != null ? (double.tryParse('${p['precio_unitario']}') ?? 0).toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(text: p?['stock_disponible']?.toString() ?? '');
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  double? _leerDecimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'tipo_bidon': _tipoController.text.trim(),
      'precio_unitario': _leerDecimal(_precioController.text),
      'stock_disponible': int.parse(_stockController.text.trim()),
    });
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) {
    return InputDecoration(
      labelText: etiqueta,
      prefixIcon: Icon(icono),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editando ? 'Editar producto' : 'Nuevo producto',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tipoController,
              decoration: _decoracion('Nombre del producto', Icons.water_drop),
              validator: (value) {
                final texto = (value ?? '').trim();
                if (texto.length < 3 || texto.length > 40) {
                  return 'Debe tener entre 3 y 40 caracteres.';
                }
                return null;
              },
            ),
            if (!_editando) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _sugerencias
                    .map((s) => ActionChip(
                          label: Text(s),
                          onPressed: () => setState(() => _tipoController.text = s),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoracion('Precio (\$)', Icons.attach_money),
                    validator: (value) {
                      final precio = _leerDecimal(value ?? '');
                      if (precio == null || precio <= 0) return 'Precio inválido.';
                      if (precio > 100) return 'Máximo \$100.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: _decoracion('Stock', Icons.inventory_2),
                    validator: (value) {
                      final stock = int.tryParse((value ?? '').trim());
                      if (stock == null || stock < 0) return 'Stock inválido.';
                      if (stock > 100000) return 'Máximo 100000.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardar,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_editando ? 'Guardar cambios' : 'Agregar producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo para reponer stock ──────────────────────────────────────────

class _DialogoAgregarStock extends StatefulWidget {
  final String nombre;
  const _DialogoAgregarStock({required this.nombre});

  @override
  State<_DialogoAgregarStock> createState() => _DialogoAgregarStockState();
}

class _DialogoAgregarStockState extends State<_DialogoAgregarStock> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final cantidad = int.tryParse(_controller.text.trim());
    if (cantidad == null || cantidad < 1 || cantidad > 10000) {
      setState(() => _error = 'Ingresa un número entre 1 y 10000.');
      return;
    }
    Navigator.pop(context, cantidad);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cuántas unidades de "${widget.nombre}" ingresan?'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _confirmar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}