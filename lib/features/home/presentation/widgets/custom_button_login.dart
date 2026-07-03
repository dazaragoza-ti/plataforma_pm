import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final double borderRadius; // 1. Agregamos la propiedad para el redondeo
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.borderRadius = 12.0, // 2. Valor por defecto (puedes cambiarlo aquí)
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        // 3. Aplicamos el color de fondo que pasas desde el LoginScreen
        backgroundColor: color ?? Theme.of(context).primaryColor, 
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        // 4. Aquí es donde se hace la magia del redondeo
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}