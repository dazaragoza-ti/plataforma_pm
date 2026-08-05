part of '../proyectos_reporte_screen.dart';

/// Sección "Qué debe cerrar cada quien" (grilla de tarjetas por
/// responsable) y el calendario simplificado — la mitad "de abajo" de la
/// pantalla (ver `secciones.dart` para la de arriba).
mixin _ProyectosResponsablesCalendarioMixin {
  static const _paletaResponsables = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  Color _colorResponsable(String nombre) =>
      _paletaResponsables[nombre.hashCode.abs() % _paletaResponsables.length];

  /// Círculo con iniciales por responsable (color determinado por su
  /// nombre, no aleatorio, para que sea estable entre reconstrucciones).
  Widget _avatarResponsable(String nombre) {
    final color = _colorResponsable(nombre);
    final iniciales = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        iniciales,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _grillaResponsables(
    BuildContext context,
    Map<String, List<_PendienteReporte>> pendientesPorResponsable, {
    required VoidCallback alRefrescar,
  }) {
    if (pendientesPorResponsable.isEmpty) {
      return _mensajeVacio('Nadie tiene pendientes de comité abiertos.');
    }
    // Sin el `maxWidth` fijo que tenía la pantalla completa, este ancho ya
    // refleja la ventana real — con 2 columnas nada más, una pantalla
    // ancha de escritorio dejaba cada tarjeta enorme con mucho espacio
    // vacío adentro; a partir de escritorio ancho de verdad conviene una
    // tercera columna.
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho > 1300 ? 3 : (ancho > 760 ? 2 : 1);
    // Alto fijo por fila (en vez de `childAspectRatio`, que solo depende
    // del ancho): calculado a partir del responsable con más pendientes,
    // para que ninguna tarjeta recorte su lista ni sobre demasiado
    // espacio vacío al fondo.
    final maxFilas = pendientesPorResponsable.values.fold<int>(
      0,
      (m, l) => l.length > m ? l.length : m,
    );
    final alturaTarjeta = 56.0 + maxFilas * 56.0;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: alturaTarjeta,
      ),
      itemCount: pendientesPorResponsable.length,
      itemBuilder: (context, i) {
        final entry = pendientesPorResponsable.entries.elementAt(i);
        return _tarjetaResponsable(entry.key, entry.value, alRefrescar);
      },
    );
  }

  Widget _mensajeVacio(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: KanbanColors.cardDecoration(radius: 8),
      alignment: Alignment.center,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
      ),
    );
  }

  Widget _tarjetaResponsable(
    String nombre,
    List<_PendienteReporte> filas,
    VoidCallback alRefrescar,
  ) {
    final color = _colorResponsable(nombre);
    return Container(
      decoration: KanbanColors.cardDecoration(radius: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Franja superior del color del responsable — mismo lenguaje
          // visual que la barra izquierda de `_carrilProyecto`, para que
          // ambas secciones de tarjetas se sientan de la misma familia.
          Container(height: 3, color: color),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: KanbanColors.borde)),
            ),
            child: Row(
              children: [
                _avatarResponsable(nombre),
                const SizedBox(width: 8),
                // `Flexible` (no `Text` suelto): protege contra un nombre
                // de responsable largo en una tarjeta angosta (grilla de
                // 3 columnas), mismo criterio que ya se aplicó al resto
                // de filas de este módulo.
                Flexible(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: KanbanColors.texto,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${filas.length} abiertas',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: KanbanColors.tdim,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filas.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: KanbanColors.borde),
              itemBuilder: (context, i) {
                final f = filas[i];
                final esFrena = f.estado == _EstadoReporte.frena;
                // Tocable (igual que el chip del carril): misma tarea, no
                // hay razón para que solo una de las dos vistas permita
                // abrir su tarjeta completa.
                return InkWell(
                  onTap: () => TareaDetailDialog.show(
                    context,
                    repository: f.repo,
                    tareaId: f.tareaIdReal,
                    onRefresh: alRefrescar,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: f.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${f.nombre} (${f.tareaId})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KanbanColors.texto,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                f.proyecto,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: KanbanColors.tdim,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // `Flexible` (no `Text` suelto): en la columna
                        // angosta de la grilla en móvil, rangos largos como
                        // "Sin fecha → Sin fecha" desbordaban la fila junto
                        // con la etiqueta de estado — aquí se trunca
                        // primero él, dejando la etiqueta (el dato de
                        // estado) siempre visible completa.
                        Flexible(
                          child: Text(
                            f.rango,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: KanbanColors.tdim,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: esFrena
                                ? KanbanColors.dangerLight
                                : KanbanColors.bg3,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            f.etiqueta,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: esFrena
                                  ? KanbanColors.danger
                                  : KanbanColors.tdim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Franja horizontal por proyecto entre su primera y su última fecha
  /// conocida (aprox., a partir del texto del carril) — una versión muy
  /// simplificada del Gantt del documento original: transmite "cuándo
  /// arranca/cierra cada proyecto en relación con los demás", no el detalle
  /// de cada tarea día por día.
  Widget _calendarioSimplificado(
    List<_ProyectoReporte> proyectos, {
    required DateTime? rangoInicio,
    required DateTime? rangoFin,
    required bool esMovil,
  }) {
    if (rangoInicio == null || rangoFin == null || proyectos.isEmpty) {
      return _mensajeVacio(
        'Sin fechas capturadas todavía entre las actividades de comité.',
      );
    }
    // A diferencia del corte estático original (fechas fijas de un
    // documento), aquí el rango sale de las fechas reales de las
    // actividades de comité — `rangoInicio`/`rangoFin` ya vienen calculados
    // (mínima fecha de inicio, máxima fecha de vencimiento) por
    // `_cargarReporteProyectos`. Al menos 1 día para no dividir entre 0
    // cuando todo cae el mismo día.
    final totalDias = rangoFin.difference(rangoInicio).inDays.clamp(1, 1 << 30);
    // "HOY" es la fecha real del dispositivo (no una fecha de corte
    // congelada): esta vista sí es un tablero en vivo, no un snapshot.
    final diasHoy = DateTime.now().difference(rangoInicio).inDays.toDouble();

    Widget marcaHoy(BoxConstraints constraints) {
      final hoyLeft = constraints.maxWidth * diasHoy / totalDias;
      return Positioned(
        left: (hoyLeft - 12).clamp(0.0, constraints.maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: KanbanColors.danger,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'HOY',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    Widget barra(_ProyectoReporte p, BoxConstraints constraints, {Key? barKey}) {
      final ini = p.fechaInicio == null
          ? 0.0
          : p.fechaInicio!.difference(rangoInicio).inDays.toDouble();
      final fin = p.fechaFin == null
          ? totalDias.toDouble()
          : p.fechaFin!.difference(rangoInicio).inDays.toDouble();
      final left = constraints.maxWidth * ini / totalDias;
      final width = constraints.maxWidth * (fin - ini) / totalDias;
      final hoyLeft = constraints.maxWidth * diasHoy / totalDias;
      return Stack(
        children: [
          Container(height: 14, color: KanbanColors.bg3),
          Positioned(
            left: left.clamp(0.0, constraints.maxWidth),
            width: width.clamp(4.0, constraints.maxWidth),
            child: Container(
              key: barKey,
              height: 14,
              decoration: BoxDecoration(
                color: p.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: hoyLeft.clamp(0.0, constraints.maxWidth),
            width: 2,
            child: Container(
              height: 14,
              color: KanbanColors.danger.withValues(alpha: 0.65),
            ),
          ),
        ],
      );
    }

    // En móvil no cabe la franja fija de 190 (nombre) + 70 (fecha) junto a
    // la barra — el nombre/fecha pasan arriba en su propia línea y la
    // barra ocupa el ancho completo debajo.
    if (esMovil) {
      return Container(
        decoration: KanbanColors.cardDecoration(radius: 8),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                // Alto explícito: un `Stack` con solo hijos `Positioned`
                // (sin ninguno que le dé tamaño) intenta crecer "todo lo
                // posible" — dentro de una `Column`/`SingleChildScrollView`
                // sin altura acotada eso dispara una restricción infinita
                // y tira el layout de toda la tarjeta.
                child: SizedBox(
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [marcaHoy(constraints)],
                  ),
                ),
              ),
            ),
            for (final p in proyectos) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.numero} · ${p.nombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: KanbanColors.texto),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.resumenFecha,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: KanbanColors.tdim,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) => barra(p, constraints),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: KanbanColors.cardDecoration(radius: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                const SizedBox(width: 190),
                Expanded(
                  // `LayoutBuilder` aquí adentro (no envolviendo toda la
                  // fila): así `constraints.maxWidth` es el ancho real de
                  // esta franja (sin los 190+8+70 de etiqueta/fecha), no
                  // el de la fila completa — antes el marcador "HOY" y las
                  // barras de abajo se posicionaban con un ancho más
                  // grande del que en verdad tenían para dibujarse,
                  // quedando corridos/recortados en escritorio.
                  child: SizedBox(
                    height: 18,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        clipBehavior: Clip.none,
                        children: [marcaHoy(constraints)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 70),
              ],
            ),
          ),
          for (final p in proyectos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 190,
                    child: Text(
                      '${p.numero} · ${p.nombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: KanbanColors.texto),
                    ),
                  ),
                  Expanded(
                    // Clave por `nombre` (el título de la tarjeta, su
                    // identidad real), no por `numero` (un índice de
                    // posición que depende del orden en que se recorren
                    // las tarjetas "Comité" del comité).
                    key: ValueKey('pista_${p.nombre}'),
                    child: LayoutBuilder(
                      builder: (context, constraints) => barra(
                        p,
                        constraints,
                        barKey: ValueKey('barra_${p.nombre}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      p.resumenFecha,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: KanbanColors.tdim,
                        fontFamily: 'monospace',
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
}
