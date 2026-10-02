import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/perfil_screen.dart';
import 'screens/home/ubicacion_screen.dart';
import 'screens/home/pedir_bidon_screen.dart';
import 'screens/home/mis_pedidos_screen.dart';
import 'screens/home/mis_direcciones_screen.dart';
import 'screens/home/detalle_pedido_screen.dart';
import 'screens/home/panel_distribuidor_screen.dart';
import 'screens/home/mis_productos_screen.dart';
import 'splash_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const AquaFastApp(),
    ),
  );
}

class AquaFastApp extends StatelessWidget {
  const AquaFastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaFast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegistroScreen(),
        '/home': (context) => const HomeScreen(),
        '/perfil': (context) => const PerfilScreen(),
        '/ubicacion': (context) => const UbicacionScreen(),
        '/pedido': (context) => const PedirBidonScreen(),
        '/mis-pedidos': (context) => const MisPedidosScreen(),
        '/mis-direcciones': (context) => const MisDireccionesScreen(),
        '/panel-distribuidor': (context) => const PanelDistribuidorScreen(),
        '/mis-productos': (context) => const MisProductosScreen(),
        '/agregar-producto': (context) => const MisProductosScreen(abrirFormulario: true),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detalle-pedido') {
          final idPedido = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => DetallePedidoScreen(idPedido: idPedido),
          );
        }
        return null;
      },
    );
  }
}