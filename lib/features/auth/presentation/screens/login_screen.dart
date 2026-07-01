import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../home/presentation/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    setState(() => _isSubmitting = true);
    
    // Simula una transición rápida de carga para mantener la respuesta visual premium
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      
      // Redirección directa al Home limpiando el historial de navegación
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Control para visualización en Web/Desktop
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Corporativo Temporal
                const FlutterLogo(size: 80), 
                const SizedBox(height: 32),
                
                Text(
                  'Plataforma PM',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Input de Usuario sin validación estricta
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Correo Electrónico o Usuario',
                  hintText: 'usuario@empresa.com',
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                
                // Input de Contraseña sin validación de caracteres
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Contraseña',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),

                // Botón de acceso directo
                CustomButton(
                  text: 'Iniciar Sesión',
                  isLoading: _isSubmitting,
                  onPressed: _onLoginPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}