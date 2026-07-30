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

  /// Universo completo de tareas ACTIVAS (sin archivadas, sin las de
  /// columnas archivadas) SIN los filtros de vista (búsqueda, "Mis
  /// tareas", "Solo pendientes", fechas, miembro, departamento, etiqueta)
  /// — a diferencia de `_tareas`. La necesita el límite de WIP al mover
  /// una tarjeta (ver `_wipBloqueado`): una tarjeta archivada no debe
  /// contar como ocupando espacio en su columna.
  List<Tarea> _tareasCompletas = [];

  /// Como `_tareasCompletas`, pero SIN excluir archivadas ni las de
  /// columnas archivadas — el universo absoluto tal como vive en el
  /// repositorio. La necesita el guard anti-ciclo de dependencias y la
  /// ruta crítica del Gantt: `dependeDeIds` no se limpia al archivar una
  /// tarea (solo al eliminarla), así que un ciclo real puede cerrarse a
  /// través de una tarea archivada — si el guard no la ve, no lo detecta.
  List<Tarea> _tareasAbsolutas = [];
  List<KanbanColumna> _columnas = [];
  List<TareaEtiqueta> _etiquetasInterno = [];
  List<Miembro> _miembrosInterno = [];
  Map<int, TareaEtiqueta>? _etiquetasPorIdCache;
  Map<int, Miembro>? _miembrosPorIdCache;
  bool _cargando = true;

  /// Se incrementa al empezar cada `_cargar()` — quien la llama guarda su
  /// propio valor y, antes de aplicar el resultado con `setState`, compara
  /// contra el valor actual: si ya no coinciden, alguien más empezó (y
  /// probablemente ya terminó) una carga más nueva mientras esta corría, así
  /// que se descarta en vez de pisar datos frescos con una respuesta vieja
  /// que tardó más (p. ej. la búsqueda con texto hace el doble de llamadas
  /// al repositorio que sin texto, así que puede resolver después de una
  /// recarga sin texto disparada casi al mismo tiempo).
  int _generacionCarga = 0;

  /// `_etiquetasPorId`/`_miembrosPorId` se pasan a cada `KanbanColumnView`
  /// del tablero y antes reconstruían un `Map` nuevo cada vez que se los
  /// leía — cualquier rebuild del dashboard (p. ej. escribir en el
  /// buscador) los recalculaba aunque el catálogo de etiquetas/miembros no
  /// hubiera cambiado. El setter invalida el cache solo cuando la lista
  /// realmente se reasigna (la única vez es en `_cargarColumnasYEtiquetas`).
  List<TareaEtiqueta> get _etiquetas => _etiquetasInterno;
  set _etiquetas(List<TareaEtiqueta> valor) {
    _etiquetasInterno = valor;
    _etiquetasPorIdCache = null;
  }

  List<Miembro> get _miembros => _miembrosInterno;
  set _miembros(List<Miembro> valor) {
    _miembrosInterno = valor;
    _miembrosPorIdCache = null;
  }

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

  Map<int, TareaEtiqueta> get _etiquetasPorId =>
      _etiquetasPorIdCache ??= {for (final e in _etiquetas) e.id: e};

  Map<int, Miembro> get _miembrosPorId =>
      _miembrosPorIdCache ??= {for (final m in _miembros) m.id: m};

  /// Id del miembro "yo" dentro de ESTE tablero, resuelto contra la
  /// identidad simulada activa (`usuarioActual`, la que se elige en el
  /// selector de áreas de trabajo) — antes comparaba por nombre contra
  /// `kUsuarioActualDemo` (una constante fija), así que cambiar de persona
  /// en el selector no cambiaba qué veía "Mis tareas" ni la campana de
  /// notificaciones dentro de un tablero ya abierto. Primero intenta por
  /// `Miembro.usuarioId` (el enlace real con el directorio); si el miembro
  /// se creó antes de existir ese enlace, cae a comparar por nombre como
  /// respaldo. `-1` si la persona activa no es miembro de este tablero.
  int get _miIdDemo {
    const sinMatch = Miembro(
      id: -1,
      nombre: '',
      colorAvatar: Colors.transparent,
    );
    final activo = usuarioActual.value;
    final porDirectorio = _miembros.firstWhere(
      (m) => m.usuarioId == activo.id,
      orElse: () => sinMatch,
    );
    if (porDirectorio.id != -1) return porDirectorio.id;
    return _miembros
        .firstWhere((m) => m.nombre == activo.nombre, orElse: () => sinMatch)
        .id;
  }

  void _toast(String msg, {bool ok = true}) => kanbanToast(context, msg, ok: ok);

  void _toastAccion(String msg, String etiquetaAccion, VoidCallback onAccion) =>
      kanbanToastAccion(context, msg, etiquetaAccion, onAccion);
}
