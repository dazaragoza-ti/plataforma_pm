part of '../proyectos_reporte_screen.dart';

/// Encabezado, KPIs, tapón, leyenda y el carril por proyecto — la mitad
/// "de arriba" de la pantalla, antes de las secciones de responsables y
/// calendario (ver `responsables_calendario.dart`).
mixin _ProyectosSeccionesMixin {
  /// Cabecera reutilizada por las 3 secciones grandes de la pantalla —
  /// ícono + título + subtítulo, siempre con el mismo tratamiento
  /// tipográfico para que la jerarquía visual sea obvia de un vistazo.
  Widget _seccionHeader(IconData icono, String titulo, String subtitulo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            color: KanbanColors.accentLight,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icono, size: 18, color: KanbanColors.accent),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo.toUpperCase(),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: KanbanColors.texto,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitulo,
                style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _encabezado(_ReporteProyectosDatos datos, {required bool esMovil}) {
    return Container(
      key: const ValueKey('encabezado_proyectos'),
      // Ancho completo explícito: adentro hay un `Wrap` (no un `Row`), y a
      // diferencia de `Row` (que se expande solo por su `mainAxisSize.max`
      // por defecto), `Wrap` se ajusta al tamaño de su contenido — sin
      // esto la card quedaba angosta (del ancho del título+KPIs) en vez de
      // ocupar todo el ancho como el resto de las secciones, y el
      // `WrapAlignment.spaceBetween` no tenía espacio real que repartir.
      width: double.infinity,
      decoration: BoxDecoration(
        color: KanbanColors.toolbarDark,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: KanbanColors.toolbarDark.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: esMovil ? 16 : 24,
        vertical: esMovil ? 18 : 22,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'GRUPO PM LA PIEDAD · COMITÉ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                datos.proyectos.length == 1
                    ? 'Plan estratégico · 1 proyecto'
                    : 'Plan estratégico · ${datos.proyectos.length} proyectos',
                style: TextStyle(
                  fontSize: esMovil ? 19 : 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${datos.totalCerradas} de ${datos.totalTareas} tareas '
                'cerradas'
                '${datos.cierrePlan == null ? '' : ' · cierre del plan ${kanbanFechaCompacta(datos.cierrePlan!)}'}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 30,
            runSpacing: 10,
            children: [
              _kpi(
                // `datos.diasTarde` cuenta tareas vencidas (`Tarea.vencida`
                // es un booleano, "¿está vencida?"), no días de retraso —
                // la etiqueta anterior ("Días tarde") prometía una unidad
                // que este número nunca representó.
                'Tareas vencidas',
                '${datos.diasTarde}',
                acento: datos.diasTarde > 0
                    ? const Color(0xFFFF6B60)
                    : Colors.white,
              ),
              _kpi('Cerrado', '${datos.porcentaje}%'),
              _kpi(
                'Cierre plan',
                datos.cierrePlan == null
                    ? 'Sin fecha'
                    : kanbanFechaCompacta(datos.cierrePlan!),
                pequeno: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    String label,
    String valor, {
    Color acento = Colors.white,
    bool pequeno = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          valor,
          style: TextStyle(
            fontSize: pequeno ? 15 : 24,
            fontWeight: FontWeight.w800,
            color: acento,
          ),
        ),
      ],
    );
  }

  /// `null` cuando ninguna tarea abierta del comité bloquea a otras — sin
  /// un "tapón" real que señalar, esta sección completa se omite (ver el
  /// llamado en `build()`).
  Widget? _tapon(
    BuildContext context,
    _ReporteProyectosDatos datos, {
    required bool esMovil,
    required VoidCallback alRefrescar,
  }) {
    final tapon = datos.tapon;
    if (tapon == null) return null;
    return Container(
      key: const ValueKey('tapon_proyectos'),
      decoration: BoxDecoration(
        color: KanbanColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KanbanColors.danger.withValues(alpha: 0.35)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: KanbanColors.danger),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: esMovil ? 14 : 18,
                  vertical: esMovil ? 14 : 16,
                ),
                child: Wrap(
                  spacing: 26,
                  runSpacing: 14,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 260),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: KanbanColors.danger,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ATENCIÓN PRIORITARIA · TAPÓN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: KanbanColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Tocable (igual que el chip del carril y la
                          // fila de "qué debe cerrar cada quien"): esta
                          // tarjeta es precisamente la que hay que abrir
                          // para actuar sobre el tapón.
                          InkWell(
                            onTap: () => TareaDetailDialog.show(
                              context,
                              repository: tapon.repo,
                              tareaId: tapon.tareaIdReal,
                              onRefresh: alRefrescar,
                            ),
                            child: Text(
                              '${tapon.titulo} (${tapon.tareaId}) · '
                              '${tapon.responsable}',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: KanbanColors.texto,
                                decoration: TextDecoration.underline,
                                decorationColor: KanbanColors.texto
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Es la actividad abierta con mayor impacto en '
                            'cadena. Su liberación condiciona o influye en:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KanbanColors.tdim,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Menciones tocables (no un solo `Text` con los
                          // títulos unidos por "·"): cada una abre su
                          // propia tarjeta completa, igual que el resto del
                          // módulo — antes esta lista era texto plano sin
                          // forma de saltar a ninguna de esas tareas.
                          _mencionesTareas(
                            context,
                            tapon.impactadasTitulos,
                            alRefrescar,
                            color: KanbanColors.texto,
                          ),
                          if (datos.listasParaActivar.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: KanbanColors.tdim,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Llamada a la acción: ',
                                    style: TextStyle(
                                      color: KanbanColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        'activar hoy; confirmar '
                                        'responsables, fecha de arranque '
                                        'y evidencia de inicio:',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            _mencionesTareas(
                              context,
                              datos.listasParaActivar,
                              alRefrescar,
                              color: KanbanColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _taponNumero(
                          '${tapon.impactadas}',
                          'tareas\nimpactadas',
                        ),
                        const SizedBox(width: 22),
                        _taponNumero('${datos.diasTarde}', 'tareas\nvencidas'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lista de menciones tocables ("Tarea X (T09)", "Tarea Y (T12)" …),
  /// cada una abriendo su propia tarjeta completa al tocarla — usado tanto
  /// para las tareas "impactadas" por el tapón como para su "llamada a la
  /// acción" (tareas listas para activar).
  Widget _mencionesTareas(
    BuildContext context,
    List<_RefTarea> refs,
    VoidCallback alRefrescar, {
    required Color color,
  }) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < refs.length; i++) ...[
          if (i > 0)
            Text(
              '·',
              style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
            ),
          InkWell(
            onTap: () => TareaDetailDialog.show(
              context,
              repository: refs[i].repo,
              tareaId: refs[i].tareaIdReal,
              onRefresh: alRefrescar,
            ),
            child: Text(
              refs[i].etiqueta,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _taponNumero(String numero, String etiqueta) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          numero,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: KanbanColors.danger,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: KanbanColors.tdim,
          ),
        ),
      ],
    );
  }

  Widget _leyenda() {
    Widget item(Color c, String texto, {bool punteado = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (punteado)
          _BordePunteado(
            color: c,
            radio: 6.5,
            child: const SizedBox(width: 13, height: 13),
          )
        else
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: c, width: 1.5),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: KanbanColors.tdim,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KanbanColors.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          item(const Color(0xFF4B5A6B), 'CERRADO'),
          item(const Color(0xFFE08A00), 'EN CURSO'),
          item(KanbanColors.tdim, 'LISTO PARA INICIAR'),
          item(KanbanColors.tdim, 'DETENIDO', punteado: true),
        ],
      ),
    );
  }

  Widget _carrilProyecto(
    BuildContext context,
    _ProyectoReporte p, {
    required bool esMovil,
    required VoidCallback alRefrescar,
  }) {
    // Cada `_ProyectoReporte` es UNA tarjeta "Comité" (ver
    // `_cargarReporteProyectos`): `p.tareas` siempre tiene exactamente un
    // elemento, nunca está vacía.
    final tarea = p.tareas.first;
    final resumen = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.numero,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: p.color,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p.nombre,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: KanbanColors.texto,
          ),
        ),
        const SizedBox(height: 4),
        // El responsable de la tarjeta principal de esta ÁREA (cada
        // `_ProyectoReporte` es UNA tarjeta "Comité", ver
        // `_cargarReporteProyectos`) — antes solo se veía adentro del
        // chip, sin nada que lo destacara en el resumen del carril.
        Row(
          children: [
            Icon(Icons.person_outline_rounded, size: 12, color: KanbanColors.tdim),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                tarea.responsable,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: KanbanColors.tdim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.progreso,
            minHeight: 6,
            backgroundColor: KanbanColors.bg3,
            valueColor: AlwaysStoppedAnimation(p.color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${(p.progreso * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: p.color,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${p.cerradas} de ${p.total} · ${p.resumenFecha}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: KanbanColors.tdim,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    // Cada actividad de nivel superior de la tarjeta es su propia card
    // (`_ChecklistTarea`/`_ListaActividadCard`), visible de entrada — evita
    // repetir el título de la tarjeta (ya está en `p.nombre` arriba).
    final tarjetaActividades = _ChecklistTarea(
      tarea: tarea,
      colorProyecto: p.color,
      alRefrescar: alRefrescar,
    );

    // En móvil no cabe la franja lateral fija de 220 + divisor + la card
    // una junto a la otra — se apila el resumen arriba y la card abajo,
    // mismo criterio que ya usa el módulo para Lista en pantallas angostas
    // (tarjetas apiladas en vez de una tabla/fila ancha).
    if (esMovil) {
      return Container(
        decoration: KanbanColors.cardDecoration(radius: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4, color: p.color),
            Padding(padding: const EdgeInsets.all(14), child: resumen),
            Divider(height: 1, color: KanbanColors.borde),
            Padding(
              padding: const EdgeInsets.all(12),
              child: tarjetaActividades,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: KanbanColors.cardDecoration(radius: 8),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: p.color),
            SizedBox(
              width: 220,
              child: Padding(padding: const EdgeInsets.all(16), child: resumen),
            ),
            VerticalDivider(width: 1, color: KanbanColors.borde),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: tarjetaActividades,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuenta cuántas [_ActividadReporte] hay en total (a cualquier
/// profundidad) — igual que `Tarea.actividadesTotales`, pero sobre el árbol
/// ya resuelto del reporte.
int _contarActividadesReporte(List<_ActividadReporte> lista) {
  var total = lista.length;
  for (final a in lista) {
    total += _contarActividadesReporte(a.subActividades);
  }
  return total;
}

int _contarTerminadasReporte(List<_ActividadReporte> lista) {
  var terminadas = 0;
  for (final a in lista) {
    if (a.terminada) terminadas++;
    terminadas += _contarTerminadasReporte(a.subActividades);
  }
  return terminadas;
}

Widget _filaActividadReporte(
  _ActividadReporte a,
  Color colorProyecto, {
  int profundidad = 0,
}) {
  return Padding(
    padding: EdgeInsets.only(left: profundidad * 16.0, bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 13,
              height: 13,
              margin: const EdgeInsets.only(top: 1.5, right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: a.terminada ? colorProyecto : Colors.transparent,
                border: Border.all(color: colorProyecto, width: 1.3),
              ),
              alignment: Alignment.center,
              child: a.terminada
                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Text(
                a.descripcion,
                style: TextStyle(
                  fontSize: 11.5,
                  // Una actividad con subtareas funciona como una "lista"
                  // (mismo criterio que `TareaDetailDialog`): se destaca
                  // en negrita para distinguirla de una hoja.
                  fontWeight: a.subActividades.isNotEmpty
                      ? FontWeight.w700
                      : FontWeight.normal,
                  color: a.terminada ? KanbanColors.tdim : KanbanColors.texto,
                  decoration: a.terminada ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (a.responsable != null) ...[
              const SizedBox(width: 6),
              Text(
                a.responsable!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: KanbanColors.tdim,
                ),
              ),
            ],
          ],
        ),
        for (final hija in a.subActividades)
          _filaActividadReporte(
            hija,
            colorProyecto,
            profundidad: profundidad + 1,
          ),
      ],
    ),
  );
}

/// Checklist de una tarjeta "Comité": cada actividad de nivel superior es
/// su propia card independiente (`_ListaActividadCard`), visible de
/// entrada — no hay una card "padre" que envuelva a todas y que haya que
/// abrir primero para verlas (eso mezclaba todas las listas de la tarjeta
/// en una sola secuencia bajo un único interruptor). El icono abre la
/// tarjeta completa de verdad (`TareaDetailDialog`), para quien quiera
/// editarla en vez de solo consultar el checklist.
class _ChecklistTarea extends StatelessWidget {
  final _TareaReporte tarea;
  final Color colorProyecto;
  final VoidCallback alRefrescar;

  const _ChecklistTarea({
    required this.tarea,
    required this.colorProyecto,
    required this.alRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    final t = tarea;
    final total = _contarActividadesReporte(t.actividades);
    final terminadas = _contarTerminadasReporte(t.actividades);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                total == 0 ? 'Sin actividades' : '$terminadas/$total completadas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: KanbanColors.texto,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Abrir tarjeta completa',
              icon: Icon(
                Icons.open_in_full_rounded,
                size: 15,
                color: KanbanColors.tdim,
              ),
              onPressed: () => TareaDetailDialog.show(
                context,
                repository: t.repo,
                tareaId: t.tareaIdReal,
                onRefresh: alRefrescar,
              ),
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 8),
          // Una card individual por actividad de nivel superior (p. ej.
          // "Recopilar normativa vigente" con sus 2 subtareas), en fila una
          // junto a otra — cada una se expande/colapsa por separado de las
          // demás. `Wrap` (no `Row`) para que quepan varias por fila en
          // pantallas anchas sin desbordar en las angostas (móvil): ahí
          // simplemente bajan a la siguiente fila.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in t.actividades)
                SizedBox(
                  key: ValueKey('lista_actividad_${a.id}'),
                  width: 220,
                  child: _ListaActividadCard(
                    actividad: a,
                    colorProyecto: colorProyecto,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Una "lista de tareas" del checklist: una actividad de nivel superior
/// junto con sus subtareas, en su propia card — se expande/colapsa por
/// separado del resto de las listas de la misma tarjeta (antes todas las
/// listas de nivel superior se mezclaban en una sola secuencia plana bajo
/// un único interruptor de la tarjeta completa).
class _ListaActividadCard extends StatefulWidget {
  final _ActividadReporte actividad;
  final Color colorProyecto;

  const _ListaActividadCard({
    required this.actividad,
    required this.colorProyecto,
  });

  @override
  State<_ListaActividadCard> createState() => _ListaActividadCardState();
}

class _ListaActividadCardState extends State<_ListaActividadCard> {
  // Expandida por defecto: a diferencia de la card de la tarjeta completa
  // (que sí conviene colapsada para no abrumar el carril), cada lista
  // individual es lo que el usuario vino a leer.
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final a = widget.actividad;
    final tieneSub = a.subActividades.isNotEmpty;
    final total = _contarActividadesReporte(a.subActividades);
    final terminadas = _contarTerminadasReporte(a.subActividades);
    return Container(
      decoration: BoxDecoration(
        color: KanbanColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KanbanColors.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tieneSub
              ? () => setState(() => _expandido = !_expandido)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      margin: const EdgeInsets.only(top: 1.5, right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.terminada
                            ? widget.colorProyecto
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.colorProyecto,
                          width: 1.3,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: a.terminada
                          ? const Icon(Icons.check, size: 9, color: Colors.white)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        a.descripcion,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: a.terminada
                              ? KanbanColors.tdim
                              : KanbanColors.texto,
                          decoration: a.terminada
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (a.responsable != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        a.responsable!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: KanbanColors.tdim,
                        ),
                      ),
                    ],
                    if (tieneSub) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$terminadas/$total',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: KanbanColors.tdim,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expandido
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: KanbanColors.tdim,
                      ),
                    ],
                  ],
                ),
                if (_expandido && tieneSub) ...[
                  const SizedBox(height: 6),
                  for (final hija in a.subActividades)
                    _filaActividadReporte(hija, widget.colorProyecto),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
