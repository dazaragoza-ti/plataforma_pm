part of '../kanban_dashboard_screen.dart';

/// Campos de estado compartidos por toda la pantalla, más los dos helpers
/// de aviso (toasts) que usa el resto de los mixins — base de la que
/// cuelgan [_KanbanDashboardDatosMixin], [_KanbanDashboardColumnasMixin] y
/// [_KanbanDashboardFiltrosMixin].
///
/// Va como `mixin ... on State<KanbanDashboardScreen>` (no `extension`):
/// `setState` está marcado `@protected` en `State`, y ese chequeo solo
/// permite invocarlo desde miembros de instancia de una subclase real de
/// `State` — un método de `extension` no cuenta como tal aunque su `on`
/// sea la propia clase, así que con `extension` cada `setState()` de estos
/// archivos marcaba error. Un `mixin` sí se compone de verdad en la
/// jerarquía de la clase final (linearización), así que sus métodos sí
/// cuentan como miembros de instancia de esa subclase.
mixin _KanbanDashboardCoreMixin on State<KanbanDashboardScreen> {
  late final KanbanRepository _repo =
      widget.repository ?? InMemoryKanbanRepository();

  final _searchCtrl = TextEditingController();
  final _boardHCtrl = ScrollController();
  final _boardKey = GlobalKey();
  Timer? _debounce;
  Timer? _boardAutoscrollTimer;
  double? _boardAutoscrollDireccion;
  List<Tarea> _tareas = [];
  List<KanbanColumna> _columnas = [];
  List<TareaEtiqueta> _etiquetas = [];
  List<Miembro> _miembros = [];
  bool _cargando = true;

  /// Cuántas tarjetas están archivadas — a diferencia de las listas
  /// archivadas (que siguen viviendo en `_columnas`), las tarjetas
  /// archivadas se filtran por completo de `_tareas` en `_cargar`, así que
  /// sin este contador aparte no habría forma de saber si hay alguna sin
  /// volver a consultar el repositorio.
  int _tarjetasArchivadasCount = 0;

  /// Solo la carga inicial muestra el spinner de pantalla completa: los
  /// refrescos posteriores (mover una tarjeta, arrastrar una barra del
  /// Gantt, crear una tarea…) actualizan `_tareas` en el sitio sin
  /// desmontar la vista activa — desmontarla reseteaba el scroll/zoom del
  /// Gantt y se sentía como si la página completa se recargara.
  bool _primeraCarga = true;

  KanbanVista _vista = KanbanVista.kanban;
  bool _misTareas = false;
  // `false` por defecto: en el tablero Kanban el punto es ver el progreso
  // en todas las columnas, incluidas Terminado/Revisado — con esto en
  // `true` por defecto, mover una tarjeta ahí la hacía "desaparecer" sin
  // ningún aviso de que un filtro la estaba ocultando. Sigue disponible
  // como opción en "Filtros" para quien sí quiera ver solo lo pendiente.
  bool _soloPendientes = false;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  /// Filtros por persona/departamento/etiqueta — comparten el mismo
  /// `_tareas` que consumen las vistas (Kanban, Lista, Gráficas, Gantt),
  /// así que filtrar aquí una sola vez basta para que todas los respeten.
  /// Vacío significa "sin filtrar por ese campo"; con varios seleccionados
  /// basta con que coincida cualquiera de ellos.
  Set<int> _miembroIdsFiltro = {};
  Set<String> _departamentosFiltro = {};
  Set<int> _etiquetaIdsFiltro = {};

  int _fondoIdx = 0;

  /// Zoom del Gantt recordado aquí (no en `CalendarioView`): esa vista se
  /// desmonta por completo cada vez que se cambia de pestaña, así que sin
  /// esto siempre volvía a "Día" al regresar.
  GanttZoom _ganttZoom = GanttZoom.dia;

  /// Subtareas pendientes asignadas a mí (a cualquier profundidad, en
  /// cualquier tarea visible), para la campana de notificaciones del
  /// header — ver `_actualizarNotificaciones` en
  /// [_KanbanDashboardDatosMixin].
  List<({Tarea tarea, Actividad actividad})> _notificaciones = [];
  final Set<int> _actividadIdsVistos = {};

  /// `false` hasta la primera carga completa: evita que todo lo que ya
  /// estaba asignado desde el arranque se muestre como "nuevo" con un
  /// toast por cada tarjeta.
  bool _notificacionesListas = false;

  List<KanbanColumna> get _columnasVisibles =>
      _columnas.where((c) => !c.archivada).toList();

  Map<int, TareaEtiqueta> get _etiquetasPorId => {
    for (final e in _etiquetas) e.id: e,
  };

  Map<int, Miembro> get _miembrosPorId => {for (final m in _miembros) m.id: m};

  /// Id del miembro "yo" (usuario de la demo) resuelto una sola vez contra
  /// el catálogo, con `-1` de respaldo seguro si no hay match.
  int get _miIdDemo => _miembros
      .firstWhere(
        (m) => m.nombre == kUsuarioActualDemo,
        orElse: () =>
            const Miembro(id: -1, nombre: '', colorAvatar: Colors.transparent),
      )
      .id;

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? KanbanColors.ok : KanbanColors.danger,
      ),
    );
  }

  void _toastAccion(String msg, String etiquetaAccion, VoidCallback onAccion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: KanbanColors.ok,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: etiquetaAccion,
          textColor: Colors.white,
          onPressed: onAccion,
        ),
      ),
    );
  }
}
