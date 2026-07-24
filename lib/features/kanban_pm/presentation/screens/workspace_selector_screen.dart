import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../data/workspace_repository.dart';
import '../../domain/entities/workspace.dart';
import '../../kanban_constants.dart';
import '../widgets/common/color_wheel_picker.dart';
import '../widgets/dialogs/nueva_workspace_dialog.dart';
import 'kanban_dashboard_screen.dart';

/// `true` solo en apps de escritorio nativas (Windows/macOS/Linux) — en web
/// ya existe el botón atrás del propio navegador y en móvil el gesto/botón
/// atrás del sistema, así que en ambos casos un botón propio sobra. Mismo
/// criterio que ya usa el header del tablero para su botón de regresar.
bool get _esEscritorioNativo =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Paso previo a entrar al tablero: elegir un área de trabajo existente o
/// crear una nueva. Cada área de trabajo es un tablero Kanban completo e
/// independiente (ver [WorkspaceRepository]) — entrar a una navega a
/// [KanbanDashboardScreen] con el [KanbanRepository] de esa área inyectado.
class WorkspaceSelectorScreen extends StatefulWidget {
  final WorkspaceRepository? repository;

  const WorkspaceSelectorScreen({super.key, this.repository});

  @override
  State<WorkspaceSelectorScreen> createState() =>
      _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends State<WorkspaceSelectorScreen> {
  late final WorkspaceRepository _repo =
      widget.repository ?? InMemoryWorkspaceRepository();

  List<Workspace> _workspaces = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final workspaces = await _repo.listarWorkspaces();
    if (!mounted) return;
    setState(() {
      _workspaces = workspaces;
      _cargando = false;
    });
  }

  Future<void> _crear() async {
    final creada = await NuevaWorkspaceDialog.show(context, repository: _repo);
    if (creada == null) return;
    await _cargar();
  }

  Future<void> _renombrar(Workspace w) async {
    final ctrl = TextEditingController(text: w.nombre);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Renombrar área de trabajo',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: KanbanColors.texto),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: KanbanColors.bg3,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: KanbanColors.borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: KanbanColors.accent, width: 1.5),
              ),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevoNombre == null || nuevoNombre.trim().isEmpty) return;
    await _repo.renombrarWorkspace(w.id, nuevoNombre);
    await _cargar();
  }

  Future<void> _cambiarColor(Workspace w) async {
    var color = w.color;
    final elegido = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: KanbanColors.bg2,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Color del área de trabajo',
            style: TextStyle(color: KanbanColors.texto),
          ),
          content: SizedBox(
            width: 260,
            child: Center(
              child: ColorWheelPicker(
                initialColor: color,
                size: 180,
                onColorChanged: (c) => setDialogState(() => color = c),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(color),
              style: ElevatedButton.styleFrom(
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (elegido == null) return;
    await _repo.cambiarColorWorkspace(w.id, elegido);
    await _cargar();
  }

  Future<void> _eliminar(Workspace w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Eliminar área de trabajo',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: Text(
          '¿Eliminar "${w.nombre}"? Se pierden todas sus tareas, columnas y '
          'catálogos. Esta acción no se puede deshacer.',
          style: TextStyle(color: KanbanColors.texto),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.eliminarWorkspace(w.id);
    await _cargar();
  }

  Future<void> _entrar(Workspace w) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KanbanDashboardScreen(
          repository: _repo.kanbanRepositoryPara(w.id),
          workspaceNombre: w.nombre,
          workspaceColor: w.color,
        ),
      ),
    );
    // `KanbanColors.oscuro` es global al módulo: si adentro del tablero se
    // cambió a modo oscuro, sin este `setState` al volver, este selector se
    // quedaba pintado con los colores claros con los que se montó la
    // primera vez — inconsistente hasta la próxima recarga completa.
    if (mounted) setState(() {});
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KanbanColors.bg,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _encabezado(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      // Primera vez (sin áreas creadas todavía): un mensaje de
                      // bienvenida con una sola llamada a la acción es más
                      // claro que una cuadrícula con nada más que la tarjeta
                      // de "crear" perdida y sin contexto de qué hacer.
                      child: _workspaces.isEmpty
                          ? _estadoVacio()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return _cuadricula(constraints.maxWidth);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _encabezado(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(bottom: BorderSide(color: KanbanColors.borde)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solo en escritorio nativo — ver [_esEscritorioNativo].
          if (_esEscritorioNativo) ...[
            IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Regresar al menú',
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: KanbanColors.accent,
                size: 16,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KanbanColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.view_kanban_rounded,
              color: KanbanColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Áreas de trabajo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: KanbanColors.texto,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cada una es un tablero Kanban independiente. Elige uno '
                  'para continuar o crea uno nuevo.',
                  style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
                ),
                // Resumen a simple vista de cuánto hay: sin esto, saber si
                // "vale la pena" abrir el selector (¿tengo pendientes?)
                // exigía entrar a cada tarjeta a mirar una por una.
                if (_workspaces.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _estadistica(
                        Icons.dashboard_customize_rounded,
                        _workspaces.length == 1
                            ? '1 área de trabajo'
                            : '${_workspaces.length} áreas de trabajo',
                      ),
                      _estadistica(
                        Icons.task_alt_rounded,
                        () {
                          final total = _workspaces.fold<int>(
                            0,
                            (s, w) => s + w.tareasCount,
                          );
                          return total == 1
                              ? '1 tarea activa'
                              : '$total tareas activas';
                        }(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadistica(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KanbanColors.bg3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KanbanColors.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: KanbanColors.tdim),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: KanbanColors.tdim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KanbanColors.accentLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.dashboard_customize_rounded,
                size: 32,
                color: KanbanColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Aún no tienes áreas de trabajo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: KanbanColors.texto,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 320,
              child: Text(
                'Crea la primera para empezar a organizar tus tareas en un '
                'tablero Kanban propio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Crear área de trabajo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuadricula(double anchoDisponible) {
    const espacio = 16.0;
    const anchoTarjeta = 232.0;
    final columnas = ((anchoDisponible + espacio) / (anchoTarjeta + espacio))
        .floor()
        .clamp(1, 6);
    final tarjetas = [
      for (final w in _workspaces) _tarjetaWorkspace(w),
      _tarjetaCrear(),
    ];
    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += columnas) {
      final grupo = tarjetas.skip(i).take(columnas).toList();
      filas.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < grupo.length; j++) ...[
              if (j > 0) const SizedBox(width: espacio),
              Expanded(child: grupo[j]),
            ],
            // Última fila incompleta: rellena el resto del ancho con
            // espacio vacío en vez de estirar las tarjetas que sí hay —
            // sin esto, con 1 tablero + "crear" en una fila de 4 columnas
            // las dos tarjetas terminaban gigantes ocupando todo el ancho.
            if (grupo.length < columnas)
              for (var k = grupo.length; k < columnas; k++) ...[
                const SizedBox(width: espacio),
                const Expanded(child: SizedBox()),
              ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const SizedBox(height: espacio),
          filas[i],
        ],
      ],
    );
  }

  Widget _tarjetaWorkspace(Workspace w) {
    return _TarjetaBase(
      onTap: () => _entrar(w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloque de color a todo lo ancho (estilo "tablero" de
          // Trello/Linear) en vez de una simple franja delgada — el color
          // que el usuario eligió se nota de inmediato, no hay que buscarlo.
          Container(
            height: 60,
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [w.color, Color.lerp(w.color, Colors.black, 0.18)!],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar con iniciales en vez de un ícono genérico repetido
                // en todas las tarjetas — ayuda a reconocer un área de un
                // vistazo por su nombre, no solo por su color.
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _iniciales(w.nombre),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: w.color,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  color: KanbanColors.bg2,
                  onSelected: (v) {
                    if (v == 'renombrar') _renombrar(w);
                    if (v == 'color') _cambiarColor(w);
                    if (v == 'eliminar') _eliminar(w);
                  },
                  // Ícono + texto (no solo texto): con 3 opciones muy
                  // parecidas a simple vista ("Renombrar" / "Cambiar
                  // color"), el ícono ayuda a escanear el menú de un
                  // vistazo en vez de tener que leer cada palabra.
                  itemBuilder: (context) => [
                    _itemMenu('renombrar', Icons.edit_outlined, 'Renombrar'),
                    _itemMenu(
                      'color',
                      Icons.palette_outlined,
                      'Cambiar color',
                    ),
                    _itemMenu(
                      'eliminar',
                      Icons.delete_outline_rounded,
                      'Eliminar',
                      destructivo: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: KanbanColors.texto,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      w.tareasCount == 0
                          ? Icons.circle_outlined
                          : Icons.task_alt_rounded,
                      size: 12,
                      color: KanbanColors.tdim,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        // El conteo de tarjetas dice más de un vistazo que
                        // la fecha de creación sola — antes era lo único
                        // que distinguía una tarjeta vacía de una con
                        // trabajo real sin tener que entrar a cada una.
                        w.tareasCount == 0
                            ? 'Vacía · Creada el ${_fecha(w.fechaCreacion)}'
                            : '${w.tareasCount} ${w.tareasCount == 1 ? 'tarea' : 'tareas'} · '
                                  '${_fecha(w.fechaCreacion)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: KanbanColors.tdim,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2 letras: iniciales de las dos primeras palabras del nombre, o las
  /// primeras 2 letras si es una sola palabra ("Ventas" → "VE").
  String _iniciales(String nombre) {
    final palabras = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (palabras.isEmpty) return '?';
    if (palabras.length == 1) {
      final p = palabras.first;
      return p.substring(0, p.length < 2 ? p.length : 2).toUpperCase();
    }
    return (palabras[0][0] + palabras[1][0]).toUpperCase();
  }

  PopupMenuItem<String> _itemMenu(
    String valor,
    IconData icono,
    String texto, {
    bool destructivo = false,
  }) {
    final color = destructivo ? KanbanColors.danger : KanbanColors.texto;
    return PopupMenuItem(
      value: valor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 10),
          Text(texto, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }

  Widget _tarjetaCrear() {
    return _TarjetaBase(
      onTap: _crear,
      punteada: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KanbanColors.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add_rounded, color: KanbanColors.accent),
            ),
            const SizedBox(height: 12),
            Text(
              'Nueva área de trabajo',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: KanbanColors.accentDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Empieza un tablero en blanco',
              style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con elevación/realce al pasar el mouse (desktop/web) y un borde
/// que brilla siguiendo al cursor — inspirado en el componente React
/// "BorderGlow": el matiz gira con el ángulo del puntero respecto al centro
/// de la tarjeta y la intensidad crece mientras el puntero se acerca al
/// borde. Recreado con `CustomPainter`/`BoxShadow` porque Flutter no tiene
/// motor CSS (nada de mask-image ni conic-gradient con transición vía CSS);
/// en vez de un `Shader` con degradado cónico (que en Flutter ignora el
/// alpha del `Paint` cuando hay `shader`), el color se interpola a mano
/// entre los 3 tonos según el ángulo — más simple y evita ese conflicto.
class _TarjetaBase extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool punteada;

  const _TarjetaBase({
    required this.child,
    required this.onTap,
    this.punteada = false,
  });

  @override
  State<_TarjetaBase> createState() => _TarjetaBaseState();
}

class _TarjetaBaseState extends State<_TarjetaBase> {
  static const _colores = [
    Color(0xFFC084FC), // morado
    Color(0xFFF472B6), // rosa
    Color(0xFF38BDF8), // celeste
  ];

  bool _hover = false;
  Offset? _puntero;

  /// `0` en el centro de la tarjeta, `1` en el borde o más allá — el eje
  /// (x o y) que esté proporcionalmente más cerca de su límite manda.
  double _proximidadBorde(Size tamano) {
    final p = _puntero;
    if (p == null || tamano.width == 0 || tamano.height == 0) return 0;
    final dx = (p.dx - tamano.width / 2).abs() / (tamano.width / 2);
    final dy = (p.dy - tamano.height / 2).abs() / (tamano.height / 2);
    return math.max(dx, dy).clamp(0.0, 1.0);
  }

  double _anguloPuntero(Size tamano) {
    final p = _puntero;
    if (p == null) return 0;
    return math.atan2(p.dy - tamano.height / 2, p.dx - tamano.width / 2);
  }

  Color _colorEnAngulo(double angulo) {
    final normalizado = (angulo + math.pi) / (2 * math.pi); // 0..1
    final escalado = (normalizado * _colores.length) % _colores.length;
    final i = escalado.floor() % _colores.length;
    final j = (i + 1) % _colores.length;
    return Color.lerp(_colores[i], _colores[j], escalado - escalado.floor())!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamano = Size(constraints.maxWidth, 152);
        final proximidad = _proximidadBorde(tamano);
        final colorGlow = _puntero == null
            ? null
            : _colorEnAngulo(_anguloPuntero(tamano));

        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() {
            _hover = false;
            _puntero = null;
          }),
          onHover: (e) => setState(() => _puntero = e.localPosition),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 152,
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: KanbanColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hover ? KanbanColors.accent : KanbanColors.borde,
                width: widget.punteada ? 1.5 : 1,
              ),
              boxShadow: [
                // Sombra suave siempre presente (no solo al pasar el mouse):
                // da sensación de tarjeta "flotando" sobre el fondo en vez
                // de un rectángulo plano con borde — más acorde a un diseño
                // moderno tipo Notion/Linear. Se intensifica en hover.
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.05),
                  blurRadius: _hover ? 16 : 8,
                  offset: Offset(0, _hover ? 6 : 2),
                ),
                // Aura de color que se asoma más allá del borde de la
                // tarjeta — a diferencia del `CustomPaint` de abajo (que
                // solo pinta dentro), un `BoxShadow` sí se dibuja fuera de
                // los límites del contenedor sin necesitar overflow manual.
                if (colorGlow != null && proximidad > 0.05)
                  BoxShadow(
                    color: colorGlow.withValues(alpha: 0.35 * proximidad),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: widget.onTap, child: widget.child),
                  ),
                  if (colorGlow != null && proximidad > 0.05)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BordeBrillantePainter(
                            color: colorGlow,
                            opacidad: proximidad,
                            radioBorde: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Anillo nítido pegado al borde interior de la tarjeta, con un pase
/// adicional difuminado por debajo para dar sensación de brillo — ambos en
/// el mismo color interpolado según el ángulo del cursor.
class _BordeBrillantePainter extends CustomPainter {
  final Color color;
  final double opacidad;
  final double radioBorde;

  _BordeBrillantePainter({
    required this.color,
    required this.opacidad,
    required this.radioBorde,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radioBorde),
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withValues(alpha: 0.5 * opacidad)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect.deflate(1), glow);

    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: opacidad);
    canvas.drawRRect(rrect.deflate(0.8), linea);
  }

  @override
  bool shouldRepaint(covariant _BordeBrillantePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacidad != opacidad;
  }
}
