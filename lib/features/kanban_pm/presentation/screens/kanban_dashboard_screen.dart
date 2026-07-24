import 'dart:async';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/actividad.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';
import '../widgets/dashboard_header/kanban_dashboard_header.dart';
import '../widgets/dialogs/etiquetas_dialog.dart';
import '../widgets/dialogs/filtros_dialog.dart';
import '../widgets/dialogs/listas_archivadas_dialog.dart';
import '../widgets/dialogs/tarjetas_archivadas_dialog.dart';
import '../widgets/kanban_board/kanban_column.dart';
import '../widgets/calendario/gantt_layout.dart';
import '../widgets/calendario/calendario_view.dart';
import '../widgets/gantt_real/gantt_real_view.dart';
import '../widgets/kanban_graficas/kanban_graficas_view.dart';
import '../widgets/kanban_lista/kanban_lista_view.dart';
import '../widgets/dialogs/nueva_lista_dialog.dart';
import '../widgets/dialogs/nueva_tarea_dialog.dart';
import '../widgets/dialogs/pausar_tarea_dialog.dart';
import '../widgets/dialogs/plantillas_dialog.dart';
import '../widgets/dialogs/tarea_detail_dialog.dart';

part 'kanban_dashboard/core.dart';
part 'kanban_dashboard/datos.dart';
part 'kanban_dashboard/columnas.dart';
part 'kanban_dashboard/filtros.dart';

/// Tablero Kanban: barra de herramientas (buscador, vistas, filtros) y
/// columnas TAREAS / PROCESO / PAUSA / TERMINADO / REVISADO, replicando el
/// diseño del tablero de referencia, con look estilo Trello (etiquetas,
/// portadas, listas renombrables/archivables) y una vista Gantt.
///
/// Por defecto usa [InMemoryKanbanRepository]; cuando exista un backend
/// real basta con inyectar aquí una implementación de [KanbanRepository]
/// que hable con la API.
///
/// El estado de esta pantalla está dividido en varios archivos (ver la
/// carpeta `kanban_dashboard/`, unidos con `part`/`part of`) agrupados por
/// responsabilidad, cada uno un `mixin` encadenado con `on`:
/// [_KanbanDashboardCoreMixin] (campos + toasts) → [_KanbanDashboardDatosMixin]
/// (carga, notificaciones, CRUD/movimiento de tarjetas) →
/// [_KanbanDashboardColumnasMixin] / [_KanbanDashboardFiltrosMixin] (ambos
/// sobre Datos). Van como `mixin` y no `extension`: `setState` está marcado
/// `@protected` en `State`, y ese chequeo solo acepta invocarlo desde
/// miembros de instancia de una subclase real de `State` — un método de
/// `extension` no cuenta como tal aunque su `on` sea la propia clase,
/// mientras que un `mixin` sí se compone de verdad en la jerarquía final
/// (linearización).
class KanbanDashboardScreen extends StatefulWidget {
  final KanbanRepository? repository;

  /// Nombre/color del área de trabajo actual, solo para mostrarlos en el
  /// header (ver [KanbanDashboardHeader]) — `null` cuando se abre este
  /// tablero fuera del flujo de áreas de trabajo.
  final String? workspaceNombre;
  final Color? workspaceColor;

  const KanbanDashboardScreen({
    super.key,
    this.repository,
    this.workspaceNombre,
    this.workspaceColor,
  });

  @override
  State<KanbanDashboardScreen> createState() => _KanbanDashboardScreenState();
}

class _KanbanDashboardScreenState extends State<KanbanDashboardScreen>
    with
        _KanbanDashboardCoreMixin,
        _KanbanDashboardDatosMixin,
        _KanbanDashboardColumnasMixin,
        _KanbanDashboardFiltrosMixin {
  @override
  void initState() {
    super.initState();
    _cargarInicial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _boardAutoscrollTimer?.cancel();
    _searchCtrl.dispose();
    _boardHCtrl.dispose();
    super.dispose();
  }

  Widget _tablero(BuildContext context) {
    final visibles = _columnasVisibles;
    final esMovil = MediaQuery.sizeOf(context).width < kUmbralMovilKanban;
    return Listener(
      onPointerUp: (_) => _detenerAutoscrollHorizontal(),
      child: Padding(
        key: _boardKey,
        padding: const EdgeInsets.all(16),
        // `LayoutBuilder` en vez de `MediaQuery.size.height - <número mágico>`:
        // ese número mágico asumía una altura de header fija, que dejó de
        // ser cierta en cuanto el header pasó a envolver en varias líneas
        // en pantallas angostas. Aquí se toma el alto real ya disponible.
        child: LayoutBuilder(
          builder: (context, constraints) {
            // En móvil cada columna ocupa casi todo el ancho disponible,
            // dejando un "peek" de la siguiente — se siente como deslizar
            // entre pantallas (estilo Trello) en vez de mostrar varias
            // columnas angostas apretadas. 0.80 en vez de un valor más
            // cercano a 1: con menos peek apenas se notaba un hilo de
            // color de la siguiente columna, sin espacio para su título,
            // así que no comunicaba "hay más columnas aquí".
            final anchoColumna = esMovil ? constraints.maxWidth * 0.80 : 280.0;
            return SingleChildScrollView(
              controller: _boardHCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < visibles.length; i++) ...[
                    _columnaGap(i),
                    SizedBox(
                      height: constraints.maxHeight,
                      // Aísla el repintado de cada columna: sin esto,
                      // Skia/CanvasKit repinta el tablero completo cada vez
                      // que una sola columna cambia (mover una tarjeta,
                      // hover de un drag, etc.).
                      child: RepaintBoundary(
                        child: KanbanColumnView(
                          columna: visibles[i],
                          ancho: anchoColumna,
                          tareas: _tareas
                              .where((t) => t.estatus == visibles[i].estatus)
                              .toList(),
                          etiquetasPorId: _etiquetasPorId,
                          miembrosPorId: _miembrosPorId,
                          onTapTarea: _abrirDetalle,
                          onReordenar: _moverTarea,
                          onRenombrar: (nuevo) =>
                              _renombrarColumna(visibles[i].estatus, nuevo),
                          onArchivarColumna: () =>
                              _archivarColumna(visibles[i].estatus, true),
                          onMoverIzquierda: i > 0
                              ? () => _moverColumna(visibles[i].estatus, -1)
                              : null,
                          onMoverDerecha: i < visibles.length - 1
                              ? () => _moverColumna(visibles[i].estatus, 1)
                              : null,
                          onArchivarTarjeta: _archivarTarjeta,
                          onEliminarTarjeta: _eliminarTarjeta,
                          onArrastreGlobalHorizontal:
                              _manejarAutoscrollHorizontal,
                          onCambiarLimiteWip: (limite) =>
                              _cambiarLimiteWip(visibles[i].estatus, limite),
                        ),
                      ),
                    ),
                  ],
                  _columnaGap(visibles.length),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// El tema global de la app (`AppTheme`, fuera de este módulo) usa azul
  /// como color primario — bien para el resto de la app, pero choca con
  /// el acento naranja propio de este módulo (`KanbanColors.accent`) en
  /// cualquier widget de Material que no se haya restyleado a mano
  /// (`Checkbox`, `Radio`, el indicador de selección del `NavigationBar`
  /// inferior…). Sobreescrito solo aquí, con un `Theme` que envuelve el
  /// `Scaffold` de esta pantalla — no afecta al resto de la app.
  ThemeData _temaConAcento(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: KanbanColors.accent,
        secondary: KanbanColors.accent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KanbanColors.accent
              : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KanbanColors.accent
              : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KanbanColors.accent
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? KanbanColors.accentLight
              : null,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: KanbanColors.accentLight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? KanbanColors.accentDark
                : KanbanColors.tdim,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
            color: states.contains(WidgetState.selected)
                ? KanbanColors.accentDark
                : KanbanColors.tdim,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.sizeOf(context).width < kUmbralMovilKanban;
    return Theme(
      data: _temaConAcento(context),
      child: Scaffold(
        backgroundColor: KanbanColors.oscuro
            ? KanbanColors.bg
            : kFondosTablero[_fondoIdx],
        bottomNavigationBar: esMovil
            ? KanbanBottomNav(
                vista: _vista,
                onVistaChanged: (v) => setState(() => _vista = v),
              )
            : null,
        // En desktop "Nueva tarea" vive en el header; en móvil ese botón
        // queda muy lejos del pulgar arriba de la pantalla, así que se
        // sustituye por un FAB cerca de la barra de navegación inferior.
        // Solo en Kanban, igual que el botón de desktop: en
        // Lista/Gráficas/Calendario/Gantt no aporta nada que ya no tengan
        // sus propias acciones.
        floatingActionButton: (esMovil && _vista == KanbanVista.kanban)
            ? FloatingActionButton(
                onPressed: _abrirNuevaTarea,
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
                tooltip: 'Nueva tarea',
                child: const Icon(Icons.add_rounded),
              )
            : null,
        body: Column(
          children: [
            KanbanDashboardHeader(
              workspaceNombre: widget.workspaceNombre,
              workspaceColor: widget.workspaceColor,
              columnas: _columnas,
              tarjetasArchivadasCount: _tarjetasArchivadasCount,
              vista: _vista,
              onVistaChanged: (v) => setState(() => _vista = v),
              searchCtrl: _searchCtrl,
              onSearchChanged: _onSearchChanged,
              filtrosActivos: _filtrosActivos,
              onAbrirFiltros: _abrirFiltros,
              notificacionesCount: _notificaciones.length,
              onAbrirNotificaciones: _abrirNotificaciones,
              misTareas: _misTareas,
              onToggleMisTareas: () {
                setState(() => _misTareas = !_misTareas);
                _cargar();
              },
              onToggleModoOscuro: () => setState(
                () => KanbanColors.establecerOscuro(!KanbanColors.oscuro),
              ),
              onCambiarFondo: _cambiarFondo,
              onAbrirEtiquetas: _abrirEtiquetas,
              onAbrirPlantillas: _abrirPlantillas,
              onAbrirNuevaLista: _abrirNuevaLista,
              onAbrirNuevaTarea: _abrirNuevaTarea,
              onAbrirListasArchivadas: _abrirListasArchivadas,
              onAbrirTarjetasArchivadas: _abrirTarjetasArchivadas,
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  // `AnimatedSwitcher` en vez de un `switch` desnudo: sin él,
                  // cambiar de vista desmontaba y montaba el widget completo
                  // en el mismo frame (corte seco); con él, la vista saliente
                  // se desvanece mientras entra la nueva.
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey(_vista),
                        child: switch (_vista) {
                          KanbanVista.lista => KanbanListaView(
                            tareas: _tareas,
                            columnas: _columnasVisibles,
                            miembrosPorId: _miembrosPorId,
                            etiquetasPorId: _etiquetasPorId,
                            onAbrirTarea: _abrirDetalle,
                            onMoverSeleccion: _moverTareasEnLote,
                            onArchivarSeleccion: _archivarTareasEnLote,
                            onEliminarSeleccion: _eliminarTareasEnLote,
                          ),
                          KanbanVista.graficas => KanbanGraficasView(
                            tareas: _tareas,
                            columnas: _columnasVisibles,
                            miembros: _miembros,
                          ),
                          KanbanVista.gantt => CalendarioView(
                            tareas: _tareas,
                            columnas: _columnasVisibles,
                            repository: _repo,
                            onRefresh: _cargar,
                            onAbrirTarea: _abrirDetalle,
                            zoomInicial: _ganttZoom,
                            onZoomCambiado: (z) => _ganttZoom = z,
                          ),
                          KanbanVista.ganttReal => GanttRealView(
                            tareas: _tareas,
                            columnas: _columnasVisibles,
                            miembros: _miembros,
                            onAbrirTarea: _abrirDetalle,
                          ),
                          KanbanVista.kanban => _tablero(context),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
