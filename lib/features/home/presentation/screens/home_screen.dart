import 'package:flutter/material.dart';
import '../widgets/bubble_button.dart';
import '../../domain/entities/bubble_menu_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<BubbleMenuItem> menuItems = [
      BubbleMenuItem(
        title: 'Mi Perfil',
        icon: Icons.person_rounded,
        color: const Color(0xFF3182CE),
        onTap: () => debugPrint('Navegando a Perfil...'),
      ),
      BubbleMenuItem(
        title: 'Bitácora',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF319795),
        onTap: () => debugPrint('Navegando a Bitácora...'),
      ),
      BubbleMenuItem(
        title: 'Proyectos',
        icon: Icons.folder_special_rounded,
        color: const Color(0xFF805AD5),
        onTap: () => debugPrint('Navegando a Proyectos...'),
      ),
      BubbleMenuItem(
        title: 'Reportes',
        icon: Icons.analytics_rounded,
        color: const Color(0xFFDD6B20),
        onTap: () => debugPrint('Navegando a Reportes...'),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Plataforma PM', 
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A202C), fontSize: 20)
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login'); 
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFE53E3E)),
              label: const Text(
                'Salir', 
                style: TextStyle(color: Color(0xFFE53E3E), fontWeight: FontWeight.w700, fontSize: 13)
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFED7D7), width: 1.5),
                backgroundColor: const Color(0xFFFFF5F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              ),
            ),
          ),
        ],
      ),
      // Layout de Centrado Matemático Absoluto
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400), // Limita el ancho del contenedor en Web
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente
            crossAxisAlignment: CrossAxisAlignment.center, // Centra horizontalmente
            children: [
              const Text(
                'Bienvenido de vuelta,',
                style: TextStyle(fontSize: 15, color: Color(0xFF718096), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona un módulo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A202C), letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Fila 1 de Burbujas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: BubbleButton(title: menuItems[0].title, icon: menuItems[0].icon, color: menuItems[0].color, onTap: menuItems[0].onTap)),
                  const SizedBox(width: 32),
                  Expanded(child: BubbleButton(title: menuItems[1].title, icon: menuItems[1].icon, color: menuItems[1].color, onTap: menuItems[1].onTap)),
                ],
              ),
              const SizedBox(height: 32),
              
              // Fila 2 de Burbujas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: BubbleButton(title: menuItems[2].title, icon: menuItems[2].icon, color: menuItems[2].color, onTap: menuItems[2].onTap)),
                  const SizedBox(width: 32),
                  Expanded(child: BubbleButton(title: menuItems[3].title, icon: menuItems[3].icon, color: menuItems[3].color, onTap: menuItems[3].onTap)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}