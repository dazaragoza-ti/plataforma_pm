part of '../proyectos_reporte_screen.dart';

/// Tarea del comité con más impacto en cadena: entre las tareas abiertas,
/// la que bloquea a más personas o áreas distintas (ver
/// `_cargarReporteProyectos`). `null` cuando ninguna tarea abierta bloquea
/// a otra tarea abierta con etiqueta "Comité".
class _TaponDatos {
  final String tareaId;
  final String titulo;
  final String responsable;
  final List<_RefTarea> impactadasTitulos;
  final int impactadas;

  /// Igual que en [_TareaReporte]/[_PendienteReporte]: permite abrir la
  /// tarjeta completa de la tarea señalada al tocar el aviso.
  final KanbanRepository repo;
  final int tareaIdReal;

  const _TaponDatos({
    required this.tareaId,
    required this.titulo,
    required this.responsable,
    required this.impactadasTitulos,
    required this.impactadas,
    required this.repo,
    required this.tareaIdReal,
  });
}

/// Resultado completo de cargar el reporte "Proyectos" con datos reales:
/// cada "proyecto" (cada carril "ÁREA NN") es UNA tarjeta con la etiqueta
/// "Comité" —en cualquier columna, de cualquier área de trabajo donde
/// pertenezca algún miembro del comité—, no un área de trabajo completa:
/// una misma área de trabajo con 3 tarjetas etiquetadas "Comité" produce 3
/// carriles "ÁREA NN" independientes, uno por tarjeta. Ver el doc comment
/// de [ProyectosReporteScreen].
class _ReporteProyectosDatos {
  final List<_ProyectoReporte> proyectos;
  final Map<String, List<_PendienteReporte>> pendientesPorResponsable;
  final int totalTareas;
  final int totalCerradas;
  final int diasTarde;
  final DateTime? cierrePlan;
  final DateTime? rangoInicio;
  final DateTime? rangoFin;
  final _TaponDatos? tapon;

  /// Tareas "listas para iniciar" (sin bloqueo, sin empezar) entre todas
  /// las áreas del comité — la "llamada a la acción" del tapón: activar
  /// estas hoy.
  final List<_RefTarea> listasParaActivar;

  const _ReporteProyectosDatos({
    required this.proyectos,
    required this.pendientesPorResponsable,
    required this.totalTareas,
    required this.totalCerradas,
    required this.diasTarde,
    required this.cierrePlan,
    required this.rangoInicio,
    required this.rangoFin,
    required this.tapon,
    required this.listasParaActivar,
  });

  int get porcentaje =>
      totalTareas == 0 ? 0 : (totalCerradas / totalTareas * 100).round();
}

String _rangoFechas(DateTime? inicio, DateTime? fin) {
  final ini = inicio == null ? 'Sin fecha' : kanbanFechaCompacta(inicio);
  final fi = fin == null ? 'Sin fecha' : kanbanFechaCompacta(fin);
  return '$ini → $fi';
}

/// Convierte el checklist real de una tarea (`Actividad`, a cualquier
/// profundidad) a [_ActividadReporte], resolviendo `miembroId` a un nombre
/// contra el catálogo del área — el reporte no tiene forma de resolver ese
/// id por su cuenta en el punto donde se dibuja.
List<_ActividadReporte> _actividadesReporte(
  List<Actividad> lista,
  Map<int, Miembro> miembrosPorId,
) {
  return [
    for (final a in lista)
      _ActividadReporte(
        id: a.id,
        descripcion: a.descripcion,
        terminada: a.terminada,
        responsable: a.miembroId != null
            ? miembrosPorId[a.miembroId]?.nombre
            : a.departamento,
        subActividades: _actividadesReporte(a.subActividades, miembrosPorId),
      ),
  ];
}

/// Carga el reporte completo: usuarios del comité → sus áreas de trabajo →
/// tareas con etiqueta "Comité" en cada una (sin importar su columna). Cada
/// una de esas tarjetas se convierte en su propio carril "ÁREA NN" — no se
/// agrupan por área de trabajo.
Future<_ReporteProyectosDatos> _cargarReporteProyectos(
  WorkspaceRepository workspaceRepo,
) async {
  final comiteUsuarios = UsuarioDirectorio.instancia
      .listar()
      .where((u) => u.perteneceComite);

  // `Map` en vez de acumular una `List` con posibles duplicados: dos
  // miembros del comité pueden compartir la misma área de trabajo, y ahí
  // debe aparecer una sola vez.
  final workspacesPorId = <String, Workspace>{};
  for (final u in comiteUsuarios) {
    for (final w in await workspaceRepo.listarWorkspacesDe(u.id)) {
      workspacesPorId[w.id] = w;
    }
  }

  final proyectos = <_ProyectoReporte>[];
  final pendientesPorResponsable = <String, List<_PendienteReporte>>{};
  var totalTareas = 0;
  var totalCerradas = 0;
  var diasTarde = 0;
  DateTime? cierrePlan;
  DateTime? rangoInicio;
  DateTime? rangoFin;
  _TaponDatos? mejorTapon;
  var mejorImpacto = 0;
  var mejorImpactadas = 0;
  final listasParaActivar = <_RefTarea>[];

  // Orden estable por nombre (no el de inserción del `Map`, que depende
  // del orden en que `UsuarioDirectorio.instancia.listar()` y
  // `listarWorkspacesDe` devuelven sus resultados — sin garantía de ser
  // el mismo entre una carga y otra): sin esto, la misma área podía
  // aparecer como "ÁREA 01" una vez y "ÁREA 03" la siguiente, confundiendo
  // cualquier referencia previa a "el área tal número".
  final workspacesOrdenados = workspacesPorId.values.toList()
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  // A diferencia de `workspacesOrdenados` (una entrada por área de
  // trabajo): este cuenta tarjetas, así que se incrementa una vez por
  // cada tarjeta "Comité" que se convierte en su propio carril "ÁREA NN"
  // (ver más abajo), no una vez por área de trabajo.
  var indice = 0;
  for (final w in workspacesOrdenados) {
    final repo = workspaceRepo.kanbanRepositoryPara(w.id);
    final etiquetas = await repo.listarEtiquetas();
    TareaEtiqueta? etiquetaComite;
    for (final e in etiquetas) {
      if (e.nombre.toLowerCase() == kNombreEtiquetaComite.toLowerCase()) {
        etiquetaComite = e;
        break;
      }
    }

    // La etiqueta "Comité" se crea sola la primera vez que alguien del
    // comité abre ESE tablero (ver `_cargarColumnasYEtiquetas` en
    // `kanban_dashboard/datos.dart`) — si todavía nadie lo abrió, esta área
    // simplemente no tiene actividades de comité que mostrar aún.
    final todasLasTareas = etiquetaComite == null
        ? <Tarea>[]
        : (await repo.listarTareas()).where((t) => !t.archivada).toList();
    // Orden estable por título (mismo criterio que `workspacesOrdenados`):
    // de esto depende directamente qué número "ÁREA NN" le toca a cada
    // tarjeta, así que no puede depender del orden en que el repositorio
    // devuelva `listarTareas()`.
    final tareasComite =
        todasLasTareas
            .where((t) => t.etiquetaIds.contains(etiquetaComite!.id))
            .toList()
          ..sort(
            (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
          );

    final miembros = await repo.listarMiembros();
    final miembrosPorId = {for (final m in miembros) m.id: m};
    // Del universo COMPLETO de tareas del área (no solo las etiquetadas
    // "Comité"): una tarea de comité puede depender de una tarea normal
    // sin esa etiqueta, y sigue estando realmente bloqueada por ella
    // mientras esa predecesora no cierre. Si este mapa solo tuviera las
    // tareas de comité, esas dependencias eran invisibles: `bloqueada()`
    // devolvía `false` (predecesora no encontrada) y la tarea aparecía
    // como "libre"/lista para activar cuando en realidad seguía frenada.
    final tareasPorId = {for (final t in todasLasTareas) t.id: t};

    String responsableDe(Tarea t) {
      if (t.miembroIds.isEmpty) return 'SIN ASIGNAR';
      final nombre = miembrosPorId[t.miembroIds.first]?.nombre;
      return (nombre == null || nombre.isEmpty)
          ? 'SIN ASIGNAR'
          : nombre.toUpperCase();
    }

    // A diferencia de `responsableDe` (solo el primer asignado, para el
    // renglón compacto del chip): esta devuelve a TODOS los asignados —
    // sin esto, una tarea con 2+ responsables (asignación múltiple, ver
    // `Tarea.miembroIds`) solo aparecía en la lista de pendientes de la
    // primera persona, y el resto no se enteraba de que también les toca
    // cerrarla; lo mismo para contar cuántas personas distintas bloquea
    // el tapón.
    List<String> responsablesDe(Tarea t) {
      if (t.miembroIds.isEmpty) return const ['SIN ASIGNAR'];
      final nombres = t.miembroIds
          .map((id) => miembrosPorId[id]?.nombre)
          .where((n) => n != null && n.isNotEmpty)
          .map((n) => n!.toUpperCase())
          .toSet()
          .toList();
      return nombres.isEmpty ? const ['SIN ASIGNAR'] : nombres;
    }

    bool bloqueada(Tarea t) =>
        !t.cerrada &&
        t.dependeDeIds.any((id) {
          final predecesora = tareasPorId[id];
          return predecesora != null && !predecesora.cerrada;
        });

    for (final t in tareasComite) {
      totalTareas++;
      if (t.cerrada) totalCerradas++;
      if (t.vencida) diasTarde++;

      final inicioTarea = t.fechaInicio ?? t.fechaInicioReal;
      if (t.fechaVencimiento != null) {
        if (cierrePlan == null || t.fechaVencimiento!.isAfter(cierrePlan)) {
          cierrePlan = t.fechaVencimiento;
        }
      }
      // `finTarea`: fecha de cierre a usar para el rango REAL de esta
      // tarjeta (`fechaFin`/`rangoFin`). Simétrico al `t.fechaInicio ??
      // t.fechaInicioReal` de arriba: si la tarea ya cerró de verdad,
      // `fechaFinReal` es más fiel que la fecha planeada (pudo cerrar
      // antes o después de lo previsto). Solo aplica cuando `t.cerrada`
      // — `fechaFinReal` no significa nada mientras la tarea siga abierta.
      // A propósito NO se usa para `cierrePlan`: ese campo representa el
      // plan original tal cual, no el avance real.
      final finTarea = t.cerrada
          ? (t.fechaFinReal ?? t.fechaVencimiento)
          : t.fechaVencimiento;
      // `rangoInicio`/`rangoFin` (el rango GLOBAL que usa el calendario
      // simplificado) se calculan sobre el mismo conjunto de fechas —
      // inicio Y fin de cada tarjeta — en vez de "mínimo de los inicios"
      // por un lado y "máximo de los fines" por otro: con fondos
      // independientes, una tarjeta que solo tiene fecha de inicio (tardía)
      // y otra que solo tiene fecha de fin (temprana) podían invertir el
      // rango (`rangoFin` < `rangoInicio`), rompiendo las proporciones de
      // toda la franja del calendario. Tomar el mínimo/máximo sobre la
      // unión de ambas fechas por tarjeta garantiza `rangoInicio <=
      // rangoFin` sin importar qué combinación de fechas falte.
      for (final fecha in [inicioTarea, finTarea]) {
        if (fecha == null) continue;
        if (rangoInicio == null || fecha.isBefore(rangoInicio)) {
          rangoInicio = fecha;
        }
        if (rangoFin == null || fecha.isAfter(rangoFin)) {
          rangoFin = fecha;
        }
      }

      final estaBloqueada = bloqueada(t);
      final estado = t.cerrada
          ? _EstadoReporte.hecho
          : estaBloqueada
          ? _EstadoReporte.frena
          : t.estatus == TareaEstatus.proceso
          ? _EstadoReporte.curso
          : _EstadoReporte.libre;

      final responsable = responsableDe(t);

      if (estado == _EstadoReporte.libre) {
        listasParaActivar.add(
          _RefTarea(
            etiqueta: '${t.titulo} (T${t.id})',
            repo: repo,
            tareaIdReal: t.id,
          ),
        );
      }

      final etiquetaFecha = switch (estado) {
        _EstadoReporte.hecho => 'listo',
        _EstadoReporte.curso => 'en curso',
        _EstadoReporte.libre => 'listo',
        _EstadoReporte.frena =>
          'espera '
              '${t.dependeDeIds.where((id) {
                final p = tareasPorId[id];
                return p != null && !p.cerrada;
              }).map((id) => 'T$id').join(' + ')}',
      };

      final tareaReporte = _TareaReporte(
        id: 'T${t.id}',
        nombre: t.titulo,
        responsable: responsable,
        estado: estado,
        etiquetaFecha: etiquetaFecha,
        dependeDe: t.dependeDeIds.map((id) => 'T$id').toList(),
        repo: repo,
        tareaIdReal: t.id,
        actividades: _actividadesReporte(t.actividades, miembrosPorId),
      );

      // Cada tarjeta "Comité" es su propio carril "ÁREA NN" — ver el doc
      // comment de `_cargarReporteProyectos`. La barra de progreso del
      // carril refleja el checklist real (mismo conteo que las cards de
      // `_ChecklistTarea`/`_ListaActividadCard`), no solo si la tarjeta
      // está cerrada — si no, marcar actividades del checklist no movía el
      // % mostrado arriba. Sin actividades, cae de vuelta al estatus
      // binario de la tarjeta (no hay checklist del que sacar un %).
      final actividadesTotales = t.actividadesTotales;
      indice++;
      proyectos.add(
        _ProyectoReporte(
          numero: 'ÁREA ${indice.toString().padLeft(2, '0')}',
          nombre: t.titulo,
          color: w.color,
          cerradas: actividadesTotales == 0
              ? (t.cerrada ? 1 : 0)
              : t.actividadesTerminadas,
          total: actividadesTotales == 0 ? 1 : actividadesTotales,
          resumenFecha: finTarea == null
              ? 'sin fecha'
              : 'cierra ${kanbanFechaCompacta(finTarea)}',
          tareas: [tareaReporte],
          fechaInicio: inicioTarea,
          fechaFin: finTarea,
        ),
      );

      if (!t.cerrada) {
        // Una fila por CADA responsable asignado (no solo el primero) —
        // ver el comentario de `responsablesDe`.
        for (final nombreResponsable in responsablesDe(t)) {
          (pendientesPorResponsable[nombreResponsable] ??= []).add(
            _PendienteReporte(
              tareaId: 'T${t.id}',
              nombre: t.titulo,
              proyecto: w.nombre,
              color: w.color,
              // `t.fechaInicio ?? t.fechaInicioReal` (no solo
              // `fechaInicio`): mismo fallback que ya usa el cálculo del
              // rango global arriba — sin esto, una tarea sin fecha
              // planeada pero que ya se movió de columna de verdad (con
              // `fechaInicioReal` real) mostraba "Sin fecha" aunque el
              // sistema sí sepa cuándo arrancó.
              rango: _rangoFechas(
                t.fechaInicio ?? t.fechaInicioReal,
                t.fechaVencimiento,
              ),
              estado: estado,
              etiqueta: etiquetaFecha,
              repo: repo,
              tareaIdReal: t.id,
            ),
          );
        }

        // Tapón: entre las tareas que ESTA tarea (no cerrada) bloquea,
        // ¿a cuántas personas o áreas distintas afecta?
        final impactadas = tareasComite
            .where((otra) => !otra.cerrada && otra.dependeDeIds.contains(t.id))
            .toList();
        if (impactadas.isNotEmpty) {
          final personas = <String>{};
          final areas = <String>{};
          final titulos = <_RefTarea>[];
          for (final imp in impactadas) {
            // Excluye el placeholder "SIN ASIGNAR": no es una persona real,
            // y contarlo como una más inflaba artificialmente el "impacto"
            // de un tapón cuyas tareas impactadas en realidad no tienen
            // nadie asignado (o solo una persona real + el placeholder).
            personas.addAll(
              responsablesDe(imp).where((p) => p != 'SIN ASIGNAR'),
            );
            if (imp.grupo.isNotEmpty) areas.add(imp.grupo);
            titulos.add(
              _RefTarea(
                etiqueta: '${imp.titulo} (T${imp.id})',
                repo: repo,
                tareaIdReal: imp.id,
              ),
            );
          }
          final impacto = personas.length > areas.length
              ? personas.length
              : areas.length;
          final esMejor =
              impacto > mejorImpacto ||
              (impacto == mejorImpacto && impactadas.length > mejorImpactadas);
          if (impacto > 1 && esMejor) {
            mejorImpacto = impacto;
            mejorImpactadas = impactadas.length;
            mejorTapon = _TaponDatos(
              tareaId: 'T${t.id}',
              titulo: t.titulo,
              responsable: responsable,
              impactadasTitulos: titulos,
              impactadas: impactadas.length,
              repo: repo,
              tareaIdReal: t.id,
            );
          }
        }
      }
    }
  }

  return _ReporteProyectosDatos(
    proyectos: proyectos,
    pendientesPorResponsable: pendientesPorResponsable,
    totalTareas: totalTareas,
    totalCerradas: totalCerradas,
    diasTarde: diasTarde,
    cierrePlan: cierrePlan,
    rangoInicio: rangoInicio,
    rangoFin: rangoFin,
    tapon: mejorTapon,
    listasParaActivar: listasParaActivar,
  );
}
