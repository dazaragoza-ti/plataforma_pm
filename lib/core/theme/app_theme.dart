import 'package:flutter/material.dart';

class AppTheme {
  // Privado para evitar instanciación accidental
  AppTheme._();

  // Paleta de Colores Corporativos (Ajusta los hexadecimales según tu marca)
  static const Color primaryColor = Color(0xFF0052CC);     // Azul Empresarial
  static const Color secondaryColor = Color(0xFF0747A6);   // Azul Oscuro
  static const Color backgroundColor = Color(0xFFFAFBFC);  // Fondo claro/grisáceo
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFDE350B);       // Rojo de error estándar

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),

      // Estilo global de los Inputs (Campos de texto)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        // Estado por defecto
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        // Estado habilitado pero no seleccionado
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        // Estado cuando el usuario hace clic en el input
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        // Estado de error
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: errorColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: errorColor, width: 2.0),
        ),
      ),

      // Estilo global de los Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}