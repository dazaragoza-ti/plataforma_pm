import 'package:flutter/material.dart';
// Usamos rutas absolutas basadas en el package para evitar fallos del linter
import 'package:plataforma_pm/core/theme/app_theme.dart';
import 'package:plataforma_pm/features/auth/presentation/screens/login_screen.dart';

void main() async {
  // Asegura que los bindings de Flutter estén listos antes de inicializar servicios
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Inicializar inyección de dependencias (GetIt), Firebase, etc.
  // await ServiceLocator.init();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Si usas un gestor de estados global (como BlocProvider o Provider), 
    // este es el lugar ideal para envolver tu MaterialApp.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plataforma PM',
      
      // Aplicamos el tema empresarial centralizado y corregido de Material 3
      theme: AppTheme.lightTheme,
      
      // Nuestra pantalla de login estructurada como la raíz
      home: const LoginScreen(),
      
      // TODO: Configurar el enrutador definitivo más adelante (ej. GoRouter)
      // routerConfig: AppRouter.config,
    );
  }
}