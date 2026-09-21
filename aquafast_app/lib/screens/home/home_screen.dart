import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'AquaFast',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false)
                  .cerrarSesion();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.water_drop, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    '¡Hola, ${usuario?.nombre ?? 'Usuario'}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¿Qué necesitas hoy?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Acciones rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Opciones
            GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  crossAxisSpacing: 16,
  mainAxisSpacing: 16,
  children: [
    _OpcionCard(
      icono: Icons.shopping_cart,
      titulo: 'Pedir bidón',
      color: Colors.blue,
      onTap: () => Navigator.pushNamed(context, '/pedido'),
    ),
    _OpcionCard(
      icono: Icons.list_alt,
      titulo: 'Mis pedidos',
      color: Colors.teal,
      onTap: () => Navigator.pushNamed(context, '/mis-pedidos'),
    ),
    _OpcionCard(
      icono: Icons.location_on,
      titulo: 'Mi ubicación',
      color: Colors.orange,
      onTap: () => Navigator.pushNamed(context, '/ubicacion'),
    ),
    _OpcionCard(
      icono: Icons.person,
      titulo: 'Mi perfil',
      color: Colors.purple,
      onTap: () => Navigator.pushNamed(context, '/perfil'),
    ),
  ],
),
            const SizedBox(height: 24),
            // Info del usuario
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sesión activa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        usuario?.correo ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Rol: ${usuario?.tipoUsuario ?? ''}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Color color;
  final VoidCallback onTap;

  const _OpcionCard({
    required this.icono,
    required this.titulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}