import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/custom_button.dart';

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
    
    // Simulación de carga rápida para mantener la respuesta visual premium
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      
      // Reseteamos el estado de carga antes de movernos
      setState(() => _isSubmitting = false);

      // Usamos la ruta nombrada integrada con el historial del navegador Web
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Control para visualización en Web
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FlutterLogo(size: 80), 
                const SizedBox(height: 32),
                
                Text(
                  'Plataforma PM',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                CustomTextField(
                  controller: _emailController,
                  labelText: 'Correo Electrónico o Usuario',
                  hintText: 'usuario@empresa.com',
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Contraseña',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),

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