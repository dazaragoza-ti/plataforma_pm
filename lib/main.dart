import 'package:flutter/material.dart';
import 'package:plataforma_pm/core/theme/app_theme.dart';
import 'package:plataforma_pm/features/auth/presentation/screens/login_screen.dart';
import 'package:plataforma_pm/features/home/presentation/screens/home_screen.dart';
import 'package:plataforma_pm/features/profile/presentation/screens/profile_screen.dart';
import 'package:plataforma_pm/features/bitacora_pintura/presentation/screens/bitacora_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plataforma PM',
      theme: AppTheme.lightTheme,
      
      // Definimos la ruta inicial explícita
      initialRoute: '/login',
      
      // Mapa de rutas de la aplicación para soporte Web nativo
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/bitacora': (context) => const BitacoraDashboardScreen(),
      },
    );
  }
}