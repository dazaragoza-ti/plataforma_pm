import 'package:flutter/material.dart';

import '../../../domain/entities/actividad.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea.dart';
import '../../../kanban_constants.dart';

/// Miembro involucrado en una tarea (asignado directamente o responsable de
/// al menos una de sus subtareas) junto con las subtareas de esa tarea que
/// le tocan a él — ver [_personasEnTarea].
class _PersonaEnTarea {
  final Miembro miembro;
  final List<Actividad> actividades;

  const _PersonaEnTarea({required this.miembro, required this.actividades});

  int get terminadas => actividades.where((a) => a.terminada).length;
}

/// Vista "Gantt": a diferencia de "Calendario" (cronograma completo del
/// tablero, editable arrastrando barras), esta vista mira una sola tarea a
/// la vez a fondo —con sus subtareas y quién las resuelve, tiempo real
/// contra el estimado— y, debajo, quién participa en esa tarea y qué
/// subtareas le tocan a cada quien. Solo lectura: para mover fechas o
/// tarjetas se usa Kanban/Calendario.
class GanttRealView extends StatefulWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;
  final List<Miembro> miembros;
  final void Function(Tarea tarea) onAbrirTarea;

  const GanttRealView({
    super.key,
    required this.tareas,
    required this.columnas,
    required this.miembros,
    required this.onAbrirTarea,
  });

  @override
  State<GanttRealView> createState() => _GanttRealViewState();
}

class _GanttRealViewState extends State<GanttRealView> {
  int? _tareaSeleccionadaId;
  int? _personaFiltroId;

  Map<int, Miembro> get _miembrosPorId => {
    for (final m in widget.miembros) m.id: m,
  };

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Rango de fechas/hora planeadas para una subtarea delegada (ver
  /// [Actividad.fechaInicio]/[Actividad.fechaFin]) — mismo formato
  /// compacto que usa el diálogo que las pide al asignar el responsable.
  String _rangoFechasActividad(Actividad a) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final ini = a.fechaInicio;
    final fin = a.fechaFin;
    if (ini != null && fin != null) return '${fmt(ini)} – ${fmt(fin)}';
    if (ini != null) return 'Desde ${fmt(ini)}';
    return 'Hasta ${fmt(fin!)}';
  }

  KanbanColumna? _columnaDe(Tarea t) {
    for (final c in widget.columnas) {
      if (c.estatus == t.estatus) return c;
    }
    return null;
  }

  /// Personas involucradas en [t]: asignadas directamente
  /// (`Tarea.miembroIds`) o responsables de alguna de sus subtareas (a
  /// cualquier profundidad del árbol de actividades) — con la lista de
  /// esas subtareas ya agrupada por persona.
  List<_PersonaEnTarea> _personasEnTarea(Tarea t) {
    final actividadesPorPersona = <int, List<Actividad>>{};
    void recorrer(List<Actividad> lista) {
      for (final a in lista) {
        if (a.miembroId != null) {
          actividadesPorPersona.putIfAbsent(a.miembroId!, () => []).add(a);
        }
        recorrer(a.subActividades);
      }
    }

    recorrer(t.actividades);

    final ids = {...t.miembroIds, ...actividadesPorPersona.keys};
    final resultado = [
      for (final id in ids)
        if (_miembrosPorId[id] != null)
          _PersonaEnTarea(
            miembro: _miembrosPorId[id]!,
            actividades: actividadesPorPersona[id] ?? const [],
          ),
    ]..sort((a, b) => a.miembro.nombre.compareTo(b.miembro.nombre));
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final todas = widget.tareas.where((t) => !t.archivada).toList()
      ..sort((a, b) => a.titulo.compareTo(b.titulo));
    final personaFiltro = _personaFiltroId == null
        ? null
        : _miembrosPorId[_personaFiltroId];
    final tareas = personaFiltro == null
        ? todas
        : todas.where((t) => t.miembroIds.contains(personaFiltro.id)).toList();
    final seleccionada = tareas.isEmpty
        ? null
        : tareas.firstWhere(
            (t) => t.id == _tareaSeleccionadaId,
            orElse: () => tareas.first,
          );

    final detalle = seleccionada == null
        ? _tarjeta('Tarea', _vacio(personaFiltro))
        : _tarjeta(null, _detalleTarea(seleccionada));

    return LayoutBuilder(
      builder: (context, constraints) {
        // A partir de aquí hay espacio de sobra para una lista de tareas
        // fija a la izquierda (estilo maestro-detalle) — en vez de un
        // selector angosto arriba, aprovecha el ancho completo de la
        // pantalla en vez de dejarlo vacío alrededor de una columna
        // centrada. En angosto (celular) no cabe una segunda columna, así
        // que el selector pasa a un botón compacto que abre la lista en
        // una hoja inferior.
        final maestroDetalle = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (personaFiltro != null) ...[
                _chipFiltroPersona(personaFiltro),
                const SizedBox(height: 12),
              ],
              if (maestroDetalle)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panelListaTareas(tareas, seleccionada),
                    const SizedBox(width: 16),
                    Expanded(child: detalle),
                  ],
                )
              else ...[
                _selectorCompacto(tareas, seleccionada),
                const SizedBox(height: 16),
                detalle,
              ],
              const SizedBox(height: 24),
              Text(
                'AVANCE POR PERSONA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: KanbanColors.tdim,
                ),
              ),
              const SizedBox(height: 10),
              _seccionAvancePorPersona(seleccionada),
            ],
          ),
        );
      },
    );
  }

  Widget _vacio(Miembro? personaFiltro) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          personaFiltro == null
              ? 'No hay tareas para mostrar.'
              : '${personaFiltro.nombre} no tiene tareas asignadas.',
          style: TextStyle(color: KanbanColors.tdim),
        ),
      ),
    );
  }

  Widget _chipFiltroPersona(Miembro m) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InputChip(
        avatar: CircleAvatar(
          radius: 9,
          backgroundColor: m.colorAvatar,
          child: Text(
            m.nombre.isEmpty ? '?' : m.nombre[0].toUpperCase(),
            style: const TextStyle(fontSize: 9, color: Colors.white),
          ),
        ),
        label: Text('Filtrando tareas de ${m.nombre}'),
        labelStyle: TextStyle(fontSize: 12, color: KanbanColors.accentDark),
        backgroundColor: KanbanColors.accentLight,
        side: BorderSide(color: KanbanColors.accent),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: () => setState(() => _personaFiltroId = null),
      ),
    );
  }

  /// Panel fijo de la lista de tareas (pantallas anchas): a diferencia de
  /// un buscador propio, no duplica el buscador global del header (que ya
  /// filtra `widget.tareas` antes de que lleguen aquí) — solo lista lo que
  /// ya quedó disponible después de ese filtro y del de persona.
  Widget _panelListaTareas(List<Tarea> tareas, Tarea? seleccionada) {
    return Container(
      width: 280,
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: KanbanColors.cardDecorationConFondo(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'TAREAS (${tareas.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: KanbanColors.tdim,
              ),
            ),
          ),
          Divider(height: 1, color: KanbanColors.borde),
          Expanded(child: _listaTareas(tareas, seleccionada)),
        ],
      ),
    );
  }

  /// Selector compacto (celular/tablet angosto): un botón con la tarea
  /// actual que abre la misma lista en una hoja inferior, en vez de
  /// reservar permanentemente una columna lateral que no cabe en la
  /// pantalla.
  Widget _selectorCompacto(List<Tarea> tareas, Tarea? seleccionada) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: tareas.isEmpty
          ? null
          : () => _abrirSelectorTareas(tareas, seleccionada),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: KanbanColors.bg3,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: KanbanColors.borde),
        ),
        child: Row(
          children: [
            Icon(
              Icons.view_timeline_rounded,
              size: 17,
              color: KanbanColors.tdim,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                seleccionada?.titulo ?? 'Selecciona una tarea…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: seleccionada == null
                      ? KanbanColors.tdim
                      : KanbanColors.texto,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: KanbanColors.tdim),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSelectorTareas(
    List<Tarea> tareas,
    Tarea? seleccionada,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: KanbanColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Selecciona una tarea',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KanbanColors.texto,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: KanbanColors.tdim),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: KanbanColors.borde),
            Expanded(
              child: _listaTareas(
                tareas,
                seleccionada,
                onSeleccionar: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaTareas(
    List<Tarea> tareas,
    Tarea? seleccionada, {
    VoidCallback? onSeleccionar,
  }) {
    if (tareas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No hay tareas para mostrar.',
          style: TextStyle(color: KanbanColors.tdim),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tareas.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: KanbanColors.borde),
      itemBuilder: (context, i) {
        final t = tareas[i];
        final activa = seleccionada?.id == t.id;
        final columna = _columnaDe(t);
        return InkWell(
          onTap: () {
            setState(() => _tareaSeleccionadaId = t.id);
            onSeleccionar?.call();
          },
          child: Container(
            color: activa ? KanbanColors.accentLight : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: columna?.color ?? KanbanColors.tdim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: activa
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: activa
                              ? KanbanColors.accentDark
                              : KanbanColors.texto,
                        ),
                      ),
                      if (columna != null)
                        Text(
                          columna.titulo,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: KanbanColors.tdim,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detalleTarea(Tarea t) {
    final columna = _columnaDe(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                t.titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: KanbanColors.texto,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (columna != null) _chipEstatus(columna),
            _chipPrioridad(t),
            OutlinedButton.icon(
              onPressed: () => widget.onAbrirTarea(t),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Abrir tarjeta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KanbanColors.accent,
                side: BorderSide(color: KanbanColors.accent),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            for (final id in t.miembroIds)
              if (_miembrosPorId[id] != null) _chipMiembro(_miembrosPorId[id]!),
          ],
        ),
        const SizedBox(height: 18),
        _barraTiempo(t),
        const SizedBox(height: 18),
        Text(
          'SUBTAREAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: KanbanColors.tdim,
          ),
        ),
        const SizedBox(height: 8),
        if (t.actividades.isEmpty)
          Text(
            'Esta tarea no tiene subtareas.',
            style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
          )
        else
          for (final a in t.actividades) _filaActividad(a),
      ],
    );
  }

  Widget _chipEstatus(KanbanColumna c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.icono, size: 12, color: c.color),
          const SizedBox(width: 5),
          Text(
            c.titulo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipPrioridad(Tarea t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.prioridad.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        t.prioridad.etiqueta,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: t.prioridad.color,
        ),
      ),
    );
  }

  Widget _chipMiembro(Miembro m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: m.colorAvatar.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: m.colorAvatar,
            child: Text(
              m.nombre.isEmpty ? '?' : m.nombre[0].toUpperCase(),
              style: const TextStyle(fontSize: 9, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            m.nombre,
            style: TextStyle(fontSize: 11.5, color: KanbanColors.texto),
          ),
        ],
      ),
    );
  }

  Widget _filaActividad(Actividad a, {int profundidad = 0}) {
    final responsable = a.miembroId != null
        ? _miembrosPorId[a.miembroId]?.nombre
        : a.departamento;
    final miembroResponsable = a.miembroId != null
        ? _miembrosPorId[a.miembroId]
        : null;
    return Padding(
      padding: EdgeInsets.only(left: profundidad * 18.0, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                a.terminada
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: a.terminada ? KanbanColors.ok : KanbanColors.tdim,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.descripcion,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: a.terminada ? KanbanColors.tdim : KanbanColors.texto,
                    decoration: a.terminada ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (miembroResponsable != null) ...[
                CircleAvatar(
                  radius: 8,
                  backgroundColor: miembroResponsable.colorAvatar,
                  child: Text(
                    miembroResponsable.nombre.isEmpty
                        ? '?'
                        : miembroResponsable.nombre[0].toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (responsable != null)
                Text(
                  responsable,
                  style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
                ),
            ],
          ),
          for (final hija in a.subActividades)
            _filaActividad(hija, profundidad: profundidad + 1),
        ],
      ),
    );
  }

  /// Compara la fecha planeada (`fechaInicio`/`fechaVencimiento`) contra la
  /// real (`fechaInicioReal`/`fechaFinReal`, la que el repositorio sella
  /// sola al mover la tarjeta) en dos barras a la misma escala, con una
  /// línea vertical marcando "hoy" cuando cae dentro del rango — sin
  /// arrastre ni edición, solo lectura: para mover fechas se usa Calendario.
  Widget _barraTiempo(Tarea t) {
    final ini = t.fechaInicio;
    final fin = t.fechaVencimiento;
    if (ini == null || fin == null) {
      return Text(
        'Esta tarea no tiene fechas planeadas.',
        style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
      );
    }
    final iniReal = t.fechaInicioReal;
    final finReal = t.fechaFinReal ?? (iniReal != null ? DateTime.now() : null);
    final hoy = DateTime.now();

    var minFecha = ini;
    var maxFecha = fin.isBefore(ini) ? ini : fin;
    if (iniReal != null && iniReal.isBefore(minFecha)) minFecha = iniReal;
    if (finReal != null && finReal.isAfter(maxFecha)) maxFecha = finReal;
    // El rango siempre incluye "hoy": sin esto, una tarea ya cerrada hace
    // tiempo no mostraba dónde está "hoy" respecto a sus fechas, porque
    // caía fuera del rango calculado solo con sus propias fechas.
    if (hoy.isBefore(minFecha)) minFecha = hoy;
    if (hoy.isAfter(maxFecha)) maxFecha = hoy;
    final totalDias = maxFecha.difference(minFecha).inDays + 1;
    final hoyDentroDeRango = !hoy.isBefore(minFecha) && !hoy.isAfter(maxFecha);

    // Ancho fijo de la etiqueta ("Planeado"/"Real") a la izquierda de cada
    // barra: se descuenta del ancho disponible antes de calcular `dayWidth`
    // para que la línea de "hoy" (que sí necesita esa escala) quede
    // alineada con las barras, no con el ancho completo de la tarjeta.
    const anchoEtiqueta = 62.0;

    Widget barra(
      String etiqueta,
      DateTime a,
      DateTime b,
      Color color,
      double dayWidth,
      double anchoDisponible,
    ) {
      final left = a.difference(minFecha).inDays * dayWidth;
      final width = (b.difference(a).inDays + 1) * dayWidth;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: anchoEtiqueta,
              child: Text(
                etiqueta,
                style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
              ),
            ),
            SizedBox(
              height: 22,
              width: anchoDisponible,
              child: Stack(
                children: [
                  Positioned(
                    left: left.clamp(0.0, anchoDisponible),
                    width: width.clamp(4.0, anchoDisponible),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_fecha(a)} – ${_fecha(b)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final diasRetraso = (finReal != null)
        ? finReal.difference(fin).inDays
        : (DateTime.now().isAfter(fin) ? DateTime.now().difference(fin).inDays : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final anchoDisponible = (constraints.maxWidth - anchoEtiqueta)
                .clamp(1.0, double.infinity);
            final dayWidth = anchoDisponible / totalDias;
            final hoyLeft =
                anchoEtiqueta + hoy.difference(minFecha).inDays * dayWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    barra(
                      'Planeado',
                      ini,
                      fin,
                      KanbanColors.accentLight,
                      dayWidth,
                      anchoDisponible,
                    ),
                    if (iniReal != null && finReal != null)
                      barra(
                        'Real',
                        iniReal,
                        finReal,
                        KanbanColors.accent,
                        dayWidth,
                        anchoDisponible,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: anchoEtiqueta),
                        child: Text(
                          iniReal == null ? 'Todavía no arranca.' : 'En curso…',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: KanbanColors.tdim,
                          ),
                        ),
                      ),
                  ],
                ),
                if (hoyDentroDeRango)
                  Positioned(
                    left: hoyLeft.clamp(0.0, constraints.maxWidth),
                    top: -16,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Column(
                        children: [
                          Text(
                            'HOY',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: KanbanColors.danger,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1,
                              color: KanbanColors.danger.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (diasRetraso > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 62),
            child: Text(
              '$diasRetraso ${diasRetraso == 1 ? "día" : "días"} de retraso',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: KanbanColors.danger,
              ),
            ),
          )
        else if (t.cerrada)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 62),
            child: Text(
              'Terminada a tiempo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: KanbanColors.ok,
              ),
            ),
          ),
      ],
    );
  }

  /// Debajo de la tarea seleccionada: quién participa en ella (asignados
  /// directos + responsables de subtareas) y qué subtareas de esta tarea
  /// le tocan a cada quien — reemplaza el resumen global de antes (retraso/
  /// tiempo muerto acumulado de todas las personas en todas sus tareas):
  /// con el nuevo diseño maestro-detalle, todo el panel de abajo sigue a la
  /// tarea que se está mirando arriba, no al tablero completo.
  Widget _seccionAvancePorPersona(Tarea? seleccionada) {
    if (seleccionada == null) {
      return _tarjeta(
        'Personas',
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Selecciona una tarea para ver quién participa.',
              style: TextStyle(color: KanbanColors.tdim),
            ),
          ),
        ),
      );
    }
    final personas = _personasEnTarea(seleccionada);
    if (personas.isEmpty) {
      return _tarjeta(
        'Personas',
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Esta tarea no tiene personas asignadas ni subtareas delegadas.',
              style: TextStyle(color: KanbanColors.tdim),
            ),
          ),
        ),
      );
    }
    return _filaTarjetasPersonas(personas);
  }

  Widget _filaTarjetasPersonas(List<_PersonaEnTarea> personas) {
    const espacio = 12.0;
    const anchoMinimo = 260.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = ((constraints.maxWidth + espacio) /
                (anchoMinimo + espacio))
            .floor()
            .clamp(1, personas.length);
        final filas = <Widget>[];
        for (var i = 0; i < personas.length; i += columnas) {
          final grupo = personas.skip(i).take(columnas).toList();
          filas.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < grupo.length; j++) ...[
                  if (j > 0) const SizedBox(width: espacio),
                  Expanded(child: _tarjetaPersona(grupo[j])),
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
      },
    );
  }

  Widget _tarjetaPersona(_PersonaEnTarea p) {
    final activa = _personaFiltroId == p.miembro.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _personaFiltroId = activa ? null : p.miembro.id;
        if (!activa) _tareaSeleccionadaId = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: KanbanColors.cardDecorationConFondo(radius: 12).copyWith(
          border: Border.all(
            color: activa ? KanbanColors.accent : KanbanColors.borde,
            width: activa ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: p.miembro.colorAvatar,
                  child: Text(
                    p.miembro.nombre.isEmpty
                        ? '?'
                        : p.miembro.nombre[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.miembro.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KanbanColors.texto,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activa)
                  Icon(
                    Icons.filter_alt_rounded,
                    size: 15,
                    color: KanbanColors.accent,
                  )
                else
                  Tooltip(
                    message: 'Ver todas las tareas de ${p.miembro.nombre}',
                    child: Icon(
                      Icons.filter_alt_outlined,
                      size: 15,
                      color: KanbanColors.tdim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (p.actividades.isEmpty)
              Text(
                'Asignado a la tarea, sin subtareas propias.',
                style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
              )
            else ...[
              Text(
                '${p.terminadas}/${p.actividades.length} subtareas completadas',
                style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
              ),
              const SizedBox(height: 8),
              for (final a in p.actividades)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        a.terminada
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: a.terminada
                            ? KanbanColors.ok
                            : KanbanColors.tdim,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.descripcion,
                              style: TextStyle(
                                fontSize: 12,
                                color: a.terminada
                                    ? KanbanColors.tdim
                                    : KanbanColors.texto,
                                decoration: a.terminada
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (a.fechaInicio != null || a.fechaFin != null)
                              Text(
                                _rangoFechasActividad(a),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: KanbanColors.tdim,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(String? titulo, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: KanbanColors.cardDecorationConFondo(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: KanbanColors.texto,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
