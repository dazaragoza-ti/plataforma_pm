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
/// "proyectos" son las áreas de trabajo donde pertenece algún miembro del
/// comité, "actividades" son las tareas —en cualquier columna— con la
/// etiqueta "Comité" dentro de esas áreas. Ver el doc comment de
/// [ProyectosReporteScreen].
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

/// Carga el reporte completo: usuarios del comité → sus áreas de trabajo →
/// tareas con etiqueta "Comité" en cada una (sin importar su columna).
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

  var indice = 0;
  for (final w in workspacesOrdenados) {
    indice++;
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
    final tareasComite = todasLasTareas
        .where((t) => t.etiquetaIds.contains(etiquetaComite!.id))
        .toList();

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

    final tareasReporte = <_TareaReporte>[];
    var cerradasProyecto = 0;
    DateTime? inicioProyecto;
    DateTime? finProyecto;

    for (final t in tareasComite) {
      totalTareas++;
      if (t.cerrada) {
        totalCerradas++;
        cerradasProyecto++;
      }
      if (t.vencida) diasTarde++;

      final inicioTarea = t.fechaInicio ?? t.fechaInicioReal;
      if (inicioTarea != null) {
        if (inicioProyecto == null || inicioTarea.isBefore(inicioProyecto)) {
          inicioProyecto = inicioTarea;
        }
        if (rangoInicio == null || inicioTarea.isBefore(rangoInicio)) {
          rangoInicio = inicioTarea;
        }
      }
      if (t.fechaVencimiento != null) {
        if (cierrePlan == null || t.fechaVencimiento!.isAfter(cierrePlan)) {
          cierrePlan = t.fechaVencimiento;
        }
      }
      // `finTarea`: fecha de cierre a usar para el rango REAL del proyecto
      // (`finProyecto`/`rangoFin`). Simétrico al `t.fechaInicio ??
      // t.fechaInicioReal` de arriba: si la tarea ya cerró de verdad,
      // `fechaFinReal` es más fiel que la fecha planeada (pudo cerrar
      // antes o después de lo previsto). Solo aplica cuando `t.cerrada`
      // — `fechaFinReal` no significa nada mientras la tarea siga abierta.
      // A propósito NO se usa para `cierrePlan`: ese campo representa el
      // plan original tal cual, no el avance real.
      final finTarea = t.cerrada
          ? (t.fechaFinReal ?? t.fechaVencimiento)
          : t.fechaVencimiento;
      if (finTarea != null) {
        if (finProyecto == null || finTarea.isAfter(finProyecto)) {
          finProyecto = finTarea;
        }
        if (rangoFin == null || finTarea.isAfter(rangoFin)) {
          rangoFin = finTarea;
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

      tareasReporte.add(
        _TareaReporte(
          id: 'T${t.id}',
          nombre: t.titulo,
          responsable: responsable,
          estado: estado,
          etiquetaFecha: etiquetaFecha,
          dependeDe: t.dependeDeIds.map((id) => 'T$id').toList(),
          repo: repo,
          tareaIdReal: t.id,
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

    proyectos.add(
      _ProyectoReporte(
        numero: 'ÁREA ${indice.toString().padLeft(2, '0')}',
        nombre: w.nombre,
        color: w.color,
        cerradas: cerradasProyecto,
        total: tareasComite.length,
        resumenFecha: finProyecto == null
            ? 'sin fecha'
            : 'cierra ${kanbanFechaCompacta(finProyecto)}',
        tareas: tareasReporte,
        fechaInicio: inicioProyecto,
        fechaFin: finProyecto,
      ),
    );
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
