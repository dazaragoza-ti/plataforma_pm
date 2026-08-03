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
                'Días tarde',
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
                        _taponNumero('${datos.diasTarde}', 'días\ntarde'),
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
    _ProyectoReporte p, {
    required bool esMovil,
    required VoidCallback alRefrescar,
  }) {
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
    // La etiqueta "Comité" puede existir ya en esta área (se crea sola al
    // abrirla como comité) sin que todavía nadie haya marcado ninguna
    // actividad con ella — un carril sin chips y sin ningún aviso se veía
    // como un espacio roto/a medio cargar en vez de "no hay nada aquí
    // todavía".
    final chips = p.tareas.isEmpty
        ? Text(
            'Sin actividades con la etiqueta "Comité" todavía.',
            style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in p.tareas) _chipTarea(t, p.color, alRefrescar),
            ],
          );

    // En móvil no cabe la franja lateral fija de 220 + divisor + chips uno
    // junto al otro — se apila el resumen arriba y los chips abajo, mismo
    // criterio que ya usa el módulo para Lista en pantallas angostas
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
            Padding(padding: const EdgeInsets.all(12), child: chips),
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
              child: Padding(padding: const EdgeInsets.all(12), child: chips),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipTarea(
    _TareaReporte t,
    Color colorProyecto,
    VoidCallback alRefrescar,
  ) {
    return _ChipTarea(
      tarea: t,
      colorProyecto: colorProyecto,
      alRefrescar: alRefrescar,
    );
  }
}

/// Chip de tarea del carril de proyecto — tocarlo abre la tarjeta completa
/// de la tarea de verdad (`TareaDetailDialog`, la misma del tablero), no
/// solo una vista con más texto: esto ya lee tareas reales del Kanban, así
/// que tiene sentido poder abrir/editar la de verdad desde aquí.
class _ChipTarea extends StatelessWidget {
  final _TareaReporte tarea;
  final Color colorProyecto;
  final VoidCallback alRefrescar;

  const _ChipTarea({
    required this.tarea,
    required this.colorProyecto,
    required this.alRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    final t = tarea;
    final esHecho = t.estado == _EstadoReporte.hecho;
    final esCurso = t.estado == _EstadoReporte.curso;
    final esFrena = t.estado == _EstadoReporte.frena;

    final Color fondo = esHecho
        ? colorProyecto
        : (esFrena ? KanbanColors.bg : KanbanColors.bg2);
    final Color borde = esCurso ? colorProyecto : KanbanColors.borde;
    final Color textoColor = esHecho
        ? Colors.white
        : (esFrena ? KanbanColors.tdim : KanbanColors.texto);
    final Color subColor = esHecho
        ? Colors.white.withValues(alpha: 0.75)
        : KanbanColors.tdim;

    final chip = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => TareaDetailDialog.show(
          context,
          repository: t.repo,
          tareaId: t.tareaIdReal,
          onRefresh: alRefrescar,
        ),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(6),
            // Detenida (`esFrena`) NO lleva este borde sólido — se le
            // dibuja uno punteado por fuera (`_BordePunteado`, más abajo)
            // para que se distinga a simple vista de "en curso"/"listo
            // para iniciar" sin depender solo del color.
            border: esFrena
                ? null
                : Border.all(color: borde, width: esCurso ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.dependeDe.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorProyecto,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'depende de ${t.dependeDe.join(', ')}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 1, right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: esHecho ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: esHecho ? Colors.white : colorProyecto,
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: esHecho
                        ? Icon(Icons.check, size: 10, color: colorProyecto)
                        : (esCurso
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE08A00),
                                  ),
                                )
                              : null),
                  ),
                  Expanded(
                    child: Text(
                      '${t.nombre} (${t.id})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textoColor,
                      ),
                    ),
                  ),
                  // Da la pista de que el chip es tocable — sin esto, "abre
                  // la tarjeta completa al tocar" no tiene ninguna señal
                  // visual antes del primer toque.
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 12,
                    color: subColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // `Expanded` (no `Spacer`): así es el nombre del
                  // responsable el que se trunca con "…" si no alcanza el
                  // espacio, y la etiqueta de fecha (el dato que importa:
                  // "espera T11 + T12 + T13" puede ser larga) nunca se
                  // corta ni desborda.
                  Expanded(
                    child: Text(
                      t.responsable,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: subColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // `Flexible` con más peso que el `Expanded` del
                  // responsable (flex 3 vs 1): protege contra desbordes en
                  // chips angostos sin sacrificar la etiqueta primero — es
                  // el dato de estado lo que importa más ver completo.
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esFrena
                            ? KanbanColors.dangerLight
                            : (esHecho
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : KanbanColors.bg3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        t.etiquetaFecha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: esFrena
                              ? KanbanColors.danger
                              : (esHecho ? Colors.white : KanbanColors.tdim),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return esFrena
        ? _BordePunteado(color: KanbanColors.borde, child: chip)
        : chip;
  }
}
