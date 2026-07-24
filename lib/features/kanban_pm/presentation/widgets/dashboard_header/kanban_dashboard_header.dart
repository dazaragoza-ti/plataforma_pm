import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../kanban_constants.dart';

/// Vista activa del tablero — compartida entre el header (selector de
/// pestaña) y la pantalla del dashboard (qué widget mostrar en el body).
enum KanbanVista { kanban, lista, graficas, gantt, ganttReal }

/// Por debajo de este ancho se considera "celular": el selector de vista
/// pasa del header a una barra de navegación inferior ([KanbanBottomNav]).
/// Deliberadamente más angosto que el umbral de "selector compacto" (900)
/// — una tablet angosta todavía tiene espacio de sobra para el header, es
/// solo el celular quien se beneficia de mover la navegación al pulgar.
const kUmbralMovilKanban = 600.0;

/// Header del tablero Kanban: título + selector de vista a la izquierda,
/// buscador/filtros/acciones a la derecha. Extraído de la pantalla del
/// dashboard porque es, con mucho, el bloque de UI más grande de ese
/// archivo y no depende de casi nada del estado del tablero en sí (solo
/// recibe lo que necesita pintar, vía parámetros y callbacks).
class KanbanDashboardHeader extends StatelessWidget {
  /// Nombre/color del área de trabajo actual — sin esto, el header decía
  /// siempre el mismo "Kanban PM" genérico sin importar cuál de las áreas
  /// de trabajo se tenía abierta, así que no había forma de saber en cuál
  /// se estaba una vez adentro (todas se veían idénticas).
  final String? workspaceNombre;
  final Color? workspaceColor;
  final List<KanbanColumna> columnas;
  final int tarjetasArchivadasCount;
  final KanbanVista vista;
  final ValueChanged<KanbanVista> onVistaChanged;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final bool filtrosActivos;
  final VoidCallback onAbrirFiltros;
  final int notificacionesCount;
  final VoidCallback onAbrirNotificaciones;
  final bool misTareas;
  final VoidCallback onToggleMisTareas;
  final VoidCallback onToggleModoOscuro;
  final VoidCallback onCambiarFondo;
  final VoidCallback onAbrirEtiquetas;
  final VoidCallback onAbrirPlantillas;
  final VoidCallback onAbrirNuevaLista;
  final VoidCallback onAbrirNuevaTarea;
  final VoidCallback onAbrirListasArchivadas;
  final VoidCallback onAbrirTarjetasArchivadas;

  const KanbanDashboardHeader({
    super.key,
    this.workspaceNombre,
    this.workspaceColor,
    required this.columnas,
    required this.tarjetasArchivadasCount,
    required this.vista,
    required this.onVistaChanged,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.filtrosActivos,
    required this.onAbrirFiltros,
    required this.notificacionesCount,
    required this.onAbrirNotificaciones,
    required this.misTareas,
    required this.onToggleMisTareas,
    required this.onToggleModoOscuro,
    required this.onCambiarFondo,
    required this.onAbrirEtiquetas,
    required this.onAbrirPlantillas,
    required this.onAbrirNuevaLista,
    required this.onAbrirNuevaTarea,
    required this.onAbrirListasArchivadas,
    required this.onAbrirTarjetasArchivadas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(bottom: BorderSide(color: KanbanColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      // Row de dos `Flexible` (no dos `Expanded` de ancho fijo): cada grupo
      // ocupa solo lo que necesita y el `Wrap` interno absorbe el resto —
      // en angostas ambos grupos pueden partirse en líneas propias sin que
      // el Row completo se desborde. `spaceBetween` es lo que realmente
      // empuja al grupo derecho hasta el borde derecho quesobra espacio:
      // sin esto, dos `Flexible` sueltos se quedan pegados el uno al otro
      // a la izquierda (el alineamiento por defecto del Row), dejando todo
      // el espacio libre sin usar del lado derecho.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: _grupoIzquierdo(context)),
          const SizedBox(width: 10),
          Flexible(child: _grupoDerecho(context)),
        ],
      ),
    );
  }

  /// Grupo izquierdo del header: regresar (no-web), título y selector de
  /// vista. Envuelto en un [Wrap] (no un [Row] rígido) para que, si no
  /// alcanza el ancho, salte de línea en vez de desbordarse — el caso que
  /// importa en pantallas angostas (móvil, ventana redimensionada).
  Widget _grupoIzquierdo(BuildContext context) {
    final archivadas = columnas.where((c) => c.archivada).length;
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    // Por debajo de este ancho, el `SegmentedButton` con ícono+texto ya no
    // cabe: antes de este fix, en móvil se renderizaba deforme (una mancha
    // circular con el texto encimado) y en tablet el texto se cortaba a
    // media palabra ("Kanba"+"n"). Solo ícono evita ambos casos por
    // completo en vez de intentar que el texto quepa a la fuerza.
    final selectorCompacto = anchoPantalla < 900;
    // Por debajo de este otro umbral (celular, no solo tablet angosta), el
    // selector de vista se muestra como barra de navegación inferior (ver
    // [KanbanBottomNav]) — más alcanzable con el pulgar y no compite por
    // espacio con la búsqueda/filtros del header. Aquí simplemente se
    // omite para no duplicarlo.
    final esMovil = anchoPantalla < kUmbralMovilKanban;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // El botón de regresar solo tiene sentido en desktop/móvil: en web
        // el usuario navega con el propio historial del navegador, así que
        // aquí estorbaría más de lo que ayuda.
        if (!kIsWeb)
          IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Regresar al menú',
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: KanbanColors.accent,
              size: 16,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        Text(
          'Kanban PM',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: KanbanColors.texto,
          ),
        ),
        if (workspaceNombre != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (workspaceColor ?? KanbanColors.accent).withValues(
                alpha: 0.14,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: workspaceColor ?? KanbanColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  workspaceNombre!,
                  // No el color de la etiqueta para el texto (algunos
                  // colores de la paleta, como el amarillo, casi no se leen
                  // sobre el fondo claro que deja el tinte al 14%) — el
                  // punto de color ya identifica el área, el texto solo
                  // necesita ser legible siempre.
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KanbanColors.texto,
                  ),
                ),
              ],
            ),
          ),
        if (!esMovil)
          SegmentedButton<KanbanVista>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: KanbanVista.kanban,
                icon: const Icon(Icons.view_column_rounded, size: 15),
                label: selectorCompacto ? null : const Text('Kanban'),
              ),
              ButtonSegment(
                value: KanbanVista.lista,
                icon: const Icon(Icons.view_list_rounded, size: 15),
                label: selectorCompacto ? null : const Text('Lista'),
              ),
              ButtonSegment(
                value: KanbanVista.graficas,
                icon: const Icon(Icons.pie_chart_rounded, size: 15),
                label: selectorCompacto ? null : const Text('Gráficas'),
              ),
              ButtonSegment(
                value: KanbanVista.gantt,
                icon: const Icon(Icons.view_timeline_rounded, size: 15),
                label: selectorCompacto ? null : const Text('Calendario'),
              ),
              ButtonSegment(
                value: KanbanVista.ganttReal,
                icon: const Icon(Icons.insights_rounded, size: 15),
                label: selectorCompacto ? null : const Text('Gantt'),
              ),
            ],
            selected: {vista},
            onSelectionChanged: (s) => onVistaChanged(s.first),
            style: KanbanColors.segmentedButtonStyle().copyWith(
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
          ),
        if (archivadas > 0)
          TextButton.icon(
            onPressed: onAbrirListasArchivadas,
            icon: const Icon(Icons.archive_outlined, size: 14),
            label: Text(
              '$archivadas ${archivadas == 1 ? 'lista archivada' : 'listas archivadas'}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        if (tarjetasArchivadasCount > 0)
          TextButton.icon(
            onPressed: onAbrirTarjetasArchivadas,
            icon: const Icon(Icons.inventory_2_outlined, size: 14),
            label: Text(
              '$tarjetasArchivadasCount ${tarjetasArchivadasCount == 1 ? 'tarjeta archivada' : 'tarjetas archivadas'}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  /// Grupo derecho del header: buscador, filtros y acciones. También un
  /// [Wrap] (alineado a la derecha cuando hay espacio de sobra) por la
  /// misma razón que el grupo izquierdo.
  ///
  /// En móvil se colapsan las acciones secundarias (filtros, mis tareas,
  /// modo oscuro, paleta, etiquetas, plantillas) en un menú de "más
  /// opciones": mostrarlas todas como íconos sueltas ocupaba 4 líneas
  /// completas antes de llegar al tablero. "Nueva tarea" tampoco se
  /// muestra aquí en móvil — pasa a ser un FAB (en la pantalla del
  /// dashboard), más alcanzable con el pulgar.
  Widget _grupoDerecho(BuildContext context) {
    final esMovil = MediaQuery.sizeOf(context).width < kUmbralMovilKanban;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // En móvil el buscador se movió dentro del menú de "más opciones"
        // — aquí ya no hacía falta un buscador angosto compitiendo por
        // espacio con la campana y el menú.
        if (!esMovil) SizedBox(width: 240, child: _campoBusqueda()),
        if (esMovil) ...[
          _botonNotificaciones(),
          _menuMasOpciones(context),
        ] else ...[
          _iconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filtros',
            active: filtrosActivos,
            onTap: onAbrirFiltros,
          ),
          _botonNotificaciones(),
          _toggleChip(
            icon: Icons.person_rounded,
            label: 'Mis tareas',
            active: misTareas,
            onTap: onToggleMisTareas,
          ),
          _iconButton(
            icon: KanbanColors.oscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: KanbanColors.oscuro ? 'Modo claro' : 'Modo oscuro',
            active: KanbanColors.oscuro,
            onTap: onToggleModoOscuro,
          ),
          if (!KanbanColors.oscuro)
            _iconButton(
              icon: Icons.palette_outlined,
              tooltip: 'Cambiar fondo del tablero',
              onTap: onCambiarFondo,
            ),
          _iconButton(
            icon: Icons.label_outline_rounded,
            tooltip: 'Etiquetas del tablero',
            onTap: onAbrirEtiquetas,
          ),
          _iconButton(
            icon: Icons.dashboard_customize_outlined,
            tooltip: 'Plantillas de tarjeta',
            onTap: onAbrirPlantillas,
          ),
          _iconButton(
            icon: Icons.playlist_add_rounded,
            tooltip: 'Nueva lista',
            onTap: onAbrirNuevaLista,
          ),
          // Solo tiene sentido en el tablero Kanban: en Lista/Gráficas/
          // Calendario/Gantt ya existe "Nueva lista" y el resto de
          // acciones propias de cada vista — tenerlo siempre visible
          // sugería que hacía falta en todas, cuando en realidad solo se
          // usa desde el tablero.
          if (vista == KanbanVista.kanban)
            ElevatedButton.icon(
              onPressed: onAbrirNuevaTarea,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Nueva tarea', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Campo de búsqueda compartido entre el header (desktop) y el menú de
  /// "más opciones" (móvil) — mismo estilo en los dos sitios, solo cambia
  /// el ancho disponible.
  Widget _campoBusqueda() {
    return TextField(
      controller: searchCtrl,
      onChanged: onSearchChanged,
      style: TextStyle(fontSize: 13, color: KanbanColors.texto),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: KanbanColors.bg3,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 17,
          color: KanbanColors.tdim,
        ),
        hintText: 'Buscar…',
        hintStyle: TextStyle(color: KanbanColors.tdim, fontSize: 12.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: KanbanColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: KanbanColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: KanbanColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? KanbanColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? KanbanColors.accent : KanbanColors.borde,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: active ? KanbanColors.accentDark : KanbanColors.texto,
          ),
        ),
      ),
    );
  }

  Widget _botonNotificaciones() {
    final n = notificacionesCount;
    return Badge(
      label: Text('$n'),
      isLabelVisible: n > 0,
      backgroundColor: KanbanColors.danger,
      child: _iconButton(
        icon: Icons.notifications_outlined,
        tooltip: n == 0
            ? 'Sin subtareas pendientes asignadas a mí'
            : '$n ${n == 1 ? 'subtarea asignada a mí' : 'subtareas asignadas a mí'}',
        onTap: onAbrirNotificaciones,
      ),
    );
  }

  Widget _toggleChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? KanbanColors.accentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? KanbanColors.accent : KanbanColors.borde,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? KanbanColors.accentDark : KanbanColors.texto,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? KanbanColors.accentDark : KanbanColors.texto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menú de "más opciones" que agrupa, en móvil, las acciones secundarias
  /// que en desktop se muestran como íconos sueltos en el header.
  Widget _menuMasOpciones(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: Icon(Icons.more_vert_rounded, color: KanbanColors.texto),
      color: KanbanColors.bg2,
      onSelected: (valor) {
        switch (valor) {
          case 'filtros':
            onAbrirFiltros();
          case 'mis_tareas':
            onToggleMisTareas();
          case 'modo':
            onToggleModoOscuro();
          case 'paleta':
            onCambiarFondo();
          case 'etiquetas':
            onAbrirEtiquetas();
          case 'plantillas':
            onAbrirPlantillas();
          case 'nueva_lista':
            onAbrirNuevaLista();
        }
      },
      itemBuilder: (context) => [
        // `enabled: false` desactiva el tap-to-seleccionar del ítem (que
        // cerraría el menú con cualquier toque), sin desactivar el campo
        // de texto en sí — es el patrón estándar para meter un control
        // interactivo (buscador, switch, slider…) dentro de un menú.
        PopupMenuItem<String>(enabled: false, child: _campoBusqueda()),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'filtros',
          child: _itemMenu(
            Icons.tune_rounded,
            filtrosActivos ? 'Filtros (activos)' : 'Filtros',
          ),
        ),
        PopupMenuItem(
          value: 'mis_tareas',
          child: _itemMenu(
            Icons.person_rounded,
            misTareas ? 'Quitar "Mis tareas"' : 'Mis tareas',
          ),
        ),
        PopupMenuItem(
          value: 'modo',
          child: _itemMenu(
            KanbanColors.oscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            KanbanColors.oscuro ? 'Modo claro' : 'Modo oscuro',
          ),
        ),
        if (!KanbanColors.oscuro)
          PopupMenuItem(
            value: 'paleta',
            child: _itemMenu(
              Icons.palette_outlined,
              'Cambiar fondo del tablero',
            ),
          ),
        PopupMenuItem(
          value: 'etiquetas',
          child: _itemMenu(
            Icons.label_outline_rounded,
            'Etiquetas del tablero',
          ),
        ),
        PopupMenuItem(
          value: 'plantillas',
          child: _itemMenu(
            Icons.dashboard_customize_outlined,
            'Plantillas de tarjeta',
          ),
        ),
        PopupMenuItem(
          value: 'nueva_lista',
          child: _itemMenu(Icons.playlist_add_rounded, 'Nueva lista'),
        ),
      ],
    );
  }

  Widget _itemMenu(IconData icon, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: KanbanColors.texto),
        const SizedBox(width: 12),
        Text(texto, style: TextStyle(fontSize: 13, color: KanbanColors.texto)),
      ],
    );
  }
}

/// Barra de navegación inferior para celular — reemplaza al selector de
/// vista del header en pantallas angostas. Más alcanzable con el pulgar
/// que un control arriba de la pantalla, el patrón esperado en apps
/// móviles para cambiar de sección principal.
class KanbanBottomNav extends StatelessWidget {
  final KanbanVista vista;
  final ValueChanged<KanbanVista> onVistaChanged;

  const KanbanBottomNav({
    super.key,
    required this.vista,
    required this.onVistaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: KanbanVista.values.indexOf(vista),
      onDestinationSelected: (i) => onVistaChanged(KanbanVista.values[i]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.view_column_rounded),
          label: 'Kanban',
        ),
        NavigationDestination(
          icon: Icon(Icons.view_list_rounded),
          label: 'Lista',
        ),
        NavigationDestination(
          icon: Icon(Icons.pie_chart_rounded),
          label: 'Gráficas',
        ),
        NavigationDestination(
          icon: Icon(Icons.view_timeline_rounded),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_rounded),
          label: 'Gantt',
        ),
      ],
    );
  }
}
