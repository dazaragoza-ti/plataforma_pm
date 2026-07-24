import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/bubble_button.dart';
import '../../domain/entities/bubble_menu_item.dart';
import '../../../bitacora_pintura/presentation/screens/bitacora_dashboard_screen.dart';
import '../../../kanban_pm/presentation/screens/workspace_selector_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _nombreCompleto = 'Ing. Alejandro Martínez';

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Actualiza la fecha/hora cada minuto
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = meses[dt.month - 1];
    int hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$day de $month de ${dt.year}, $hourStr:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final List<BubbleMenuItem> menuItems = [
      BubbleMenuItem(
        title: 'Mi perfil',
        icon: Icons.person_rounded,
        color: const Color(0xFF26A69A),
        onTap: () => Navigator.pushNamed(context, '/profile'),
      ),
      BubbleMenuItem(
        title: 'Vigilancia In/Out',
        icon: Icons.videocam_rounded,
        color: const Color(0xFF7E57C2),
        onTap: () => debugPrint('Navegando a Vigilancia In/Out...'),
      ),
      BubbleMenuItem(
        title: 'Kanban PM',
        icon: Icons.view_kanban_rounded,
        color: const Color(0xFFFFA726),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WorkspaceSelectorScreen()),
        ),
      ),
      BubbleMenuItem(
        title: 'IT Management',
        icon: Icons.devices_other_rounded,
        color: const Color(0xFF5C6BC0),
        onTap: () => debugPrint('Navegando a IT Management...'),
      ),
      BubbleMenuItem(
        title: 'Tickets de Soporte',
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFEF5350),
        onTap: () => debugPrint('Navegando a Tickets de Soporte...'),
      ),
      BubbleMenuItem(
        title: 'RH',
        icon: Icons.badge_rounded,
        color: const Color(0xFF29B6F6),
        onTap: () => debugPrint('Abriendo RH...'),
      ),
      BubbleMenuItem(
        title: 'Centro de Ayuda',
        icon: Icons.help_rounded,
        color: const Color(0xFF9C27B0),
        onTap: () => debugPrint('Abriendo Centro de Ayuda...'),
      ),
      BubbleMenuItem(
        title: 'Bitácora Pintura',
        icon: Icons.brush_rounded,
        color: const Color(0xFF0FE64C),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BitacoraDashboardScreen()),
        ),
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    double tituloSize = 47;
    double subtituloSize = 18;
    if (width < 700) {
      tituloSize = 32;
      subtituloSize = 14;
    } else if (width < 1000) {
      tituloSize = 36;
      subtituloSize = 16;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Encabezado superior: logo a la izquierda, acciones a la derecha.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: Colors.white),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Image(
                  image: AssetImage('assets/logo sin fondo.png'),
                  width: 200,
                  height: 60,
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFE53E3E),
                  ),
                  label: const Text(
                    'Salir',
                    style: TextStyle(
                      color: Color(0xFFE53E3E),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFED7D7), width: 2),
                    backgroundColor: const Color(0xFFFFF5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido central: bienvenida arriba, íconos al centro, fecha abajo.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 30,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'BIENVENIDO',
                            style: TextStyle(
                              fontSize: tituloSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nombreCompleto.toUpperCase(),
                            style: TextStyle(
                              fontSize: subtituloSize,
                              color: const Color(0xFF666666),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 28,
                                  runSpacing: 28,
                                  children: [
                                    for (final item in menuItems)
                                      BubbleButton(
                                        title: item.title,
                                        icon: item.icon,
                                        color: item.color,
                                        onTap: item.onTap,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 10),
                            child: Text(
                              _formatDateTime(_now),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
