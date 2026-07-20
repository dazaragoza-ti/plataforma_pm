import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/kanban_repository.dart';
import '../../../domain/entities/tarea.dart';
import '../../../kanban_constants.dart';
import '../csv_export/csv_utils.dart';
import '../csv_export/descargar_csv.dart';
import '../kanban_column.dart' show direccionAutoscroll;
import 'gantt_bar.dart';
import 'gantt_connectors_painter.dart';
import 'gantt_critical_path.dart';
import 'gantt_layout.dart';

const List<String> _kMeses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Vista "Gantt": cronograma con barras arrastrables/redimensionables y
/// líneas de dependencia entre tareas — sin paquetes externos, solo
/// widgets propios + `CustomPainter`.
class KanbanGanttView extends StatefulWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;
  final KanbanRepository repository;
  final Future<void> Function() onRefresh;
  final void Function(Tarea tarea) onAbrirTarea;

  /// Zoom con el que se monta esta vista y callback para recordarlo en el
  /// padre — sin esto, como cada cambio de pestaña desmonta y vuelve a
  /// montar el Gantt desde cero, siempre se resetaba a "Día" aunque el
  /// usuario hubiera elegido "Semana" o "Mes" antes de salir.
  final GanttZoom zoomInicial;
  final ValueChanged<GanttZoom>? onZoomCambiado;

  const KanbanGanttView({
    super.key,
    required this.tareas,
    required this.columnas,
    required this.repository,
    required this.onRefresh,
    required this.onAbrirTarea,
    this.zoomInicial = GanttZoom.dia,
    this.onZoomCambiado,
  });

  @override
  State<KanbanGanttView> createState() => _KanbanGanttViewState();
}

class _KanbanGanttViewState extends State<KanbanGanttView> {
  final _hCtrlHeader = ScrollController();
  final _hCtrlBody = ScrollController(); // bloque "Planeado"
  final _hCtrlBodyReal = ScrollController(); // bloque "Real"
  final _lienzoPlaneadoKey = GlobalKey();
  final _viewportPlaneadoKey = GlobalKey();
  bool _yaCentrado = false;
  late GanttZoom _zoom = widget.zoomInicial;

  /// Ancho real de un día en píxeles, recalculado en cada `build()` según
  /// el espacio disponible: si el cronograma natural (zoom elegido ×
  /// total de días) cabe en menos ancho del que hay en pantalla, este
  /// valor crece para llenarla en vez de dejar una franja vacía a la
  /// derecha — nunca baja de `_zoom.dayWidth` (el zoom sigue siendo la
  /// densidad mínima). Guardado como campo (no una variable local de
  /// `build()`) porque `_irAHoy` lo necesita también desde el botón
  /// "Hoy", que corre fuera del build que lo calculó.
  double _diaWidthEfectivo = kGanttDayWidth;

  /// Autoscroll horizontal al arrastrar una barra cerca del borde del
  /// viewport visible — mismo mecanismo que ya existe para arrastrar
  /// tarjetas en el tablero Kanban ([direccionAutoscroll]). Sin esto, no
  /// había forma de arrastrar una tarea a una fecha que quedara fuera de
  /// la parte visible del cronograma: el viewport nunca se movía solo.
  Timer? _autoscrollTimer;
  double? _autoscrollDireccion;

  /// Id de la tarea desde la que se está arrastrando un conector de
  /// dependencia (`null` si no hay ninguno en curso) y el punto actual del
  /// arrastre, en coordenadas locales del lienzo del bloque "Planeado".
  int? _origenConector;
  Offset? _puntoConector;

  /// Validez del destino actualmente sobrevolado mientras se arrastra un
  /// conector: `null` = no hay ninguna barra bajo el punto, `true`/`false`
  /// = la barra bajo el punto sí/no aceptaría la dependencia. Alimenta el
  /// color de la línea temporal para avisar en vivo, en vez de que el
  /// usuario solo se entere del error (ciclo, auto-referencia, ya existe)
  /// después de soltar.
  bool? _destinoConectorValido;

  @override
  void initState() {
    super.initState();
    // Solo el encabezado de fechas sigue al bloque "Planeado" (el
    // encabezado es de solo lectura, nunca dispara esto por su cuenta).
    // El bloque "Real" ya NO se sincroniza con "Planeado": cada uno se
    // desplaza de forma completamente independiente.
    _hCtrlBody.addListener(_seguirEncabezado);
  }

  void _seguirEncabezado() {
    if (!_hCtrlHeader.hasClients || !_hCtrlBody.hasClients) return;
    _hCtrlHeader.jumpTo(
      _hCtrlBody.offset.clamp(0.0, _hCtrlHeader.position.maxScrollExtent),
    );
  }

  @override
  void dispose() {
    _autoscrollTimer?.cancel();
    _hCtrlHeader.dispose();
    _hCtrlBody.dispose();
    _hCtrlBodyReal.dispose();
    super.dispose();
  }

  void _manejarAutoscrollGantt(Offset globalPos) {
    final box =
        _viewportPlaneadoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final area = box.localToGlobal(Offset.zero) & box.size;
    final direccion = direccionAutoscroll(
      posEnEje: globalPos.dx,
      inicioArea: area.left,
      finArea: area.right,
    );
    if (direccion == _autoscrollDireccion) return;
    _autoscrollDireccion = direccion;
    _autoscrollTimer?.cancel();
    if (direccion == null) return;
    _autoscrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_hCtrlBody.hasClients) return;
      final destino = (_hCtrlBody.offset + direccion * 14).clamp(
        0.0,
        _hCtrlBody.position.maxScrollExtent,
      );
      _hCtrlBody.jumpTo(destino);
    });
  }

  void _detenerAutoscrollGantt() {
    _autoscrollTimer?.cancel();
    _autoscrollTimer = null;
    _autoscrollDireccion = null;
  }

  void _centrarEnHoy(GanttLayout layout) {
    if (_yaCentrado || !_hCtrlBody.hasClients) return;
    _yaCentrado = true;
    _irAHoy(layout);
  }

  /// Ctrl+rueda del mouse cambia de zoom (Día ↔ Semana ↔ Mes), el mismo
  /// atajo que Google/Microsoft Project — un atajo más rápido que ir hasta
  /// el selector de arriba cuando ya estás con las manos en el mouse sobre
  /// el cronograma. Sin Ctrl, la rueda hace scroll normal (no cambia esto).
  void _manejarZoomRueda(PointerScrollEvent evento) {
    if (!HardwareKeyboard.instance.isControlPressed) return;
    final niveles = GanttZoom.values;
    final idxActual = niveles.indexOf(_zoom);
    // Rueda hacia arriba (deltaY negativo) = acercar zoom = ir hacia "Día".
    final direccion = evento.scrollDelta.dy < 0 ? -1 : 1;
    final nuevoIdx = (idxActual + direccion).clamp(0, niveles.length - 1);
    if (nuevoIdx == idxActual) return;
    setState(() {
      _zoom = niveles[nuevoIdx];
      _yaCentrado = false;
      widget.onZoomCambiado?.call(_zoom);
    });
  }

  /// Re-centra el cronograma en la fecha de hoy — a diferencia de
  /// [_centrarEnHoy] (que solo corre una vez al montar la vista), esta se
  /// puede llamar en cualquier momento desde el botón "Hoy". Mueve los dos
  /// bloques (Planeado y Real): aunque ya se desplazan de forma
  /// independiente, "Hoy" sigue siendo una acción global para todo el
  /// cronograma.
  void _irAHoy(GanttLayout layout) {
    final hoy = DateTime.now();
    final dias = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).difference(layout.inicio).inDays;
    final offsetDeseado = dias * _diaWidthEfectivo - 120;
    for (final ctrl in [_hCtrlBody, _hCtrlBodyReal]) {
      if (!ctrl.hasClients) continue;
      ctrl.jumpTo(offsetDeseado.clamp(0.0, ctrl.position.maxScrollExtent));
    }
  }

  Future<void> _actualizarFechas(
    Tarea tarea,
    DateTime inicio,
    DateTime fin,
  ) async {
    final movidas = await widget.repository.actualizarTarea(
      tarea.copyWith(fechaInicio: inicio, fechaVencimiento: fin),
    );
    await widget.onRefresh();
    _avisarCascada(movidas);
  }

  /// Avisa en el momento cuando mover una tarjeta empujó a otras en
  /// cascada — sin esto, las tareas sucesoras se mueven en silencio y solo
  /// se nota después, abriendo cada una para ver su historial.
  void _avisarCascada(int movidas) {
    if (movidas == 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          movidas == 1
              ? 'Se recorrió 1 tarjeta sucesora para respetar la dependencia'
              : 'Se recorrieron $movidas tarjetas sucesoras para respetar '
                    'la dependencia',
        ),
      ),
    );
  }

  /// Convierte una posición global (de puntero) a coordenadas locales del
  /// lienzo del bloque "Planeado" — el mismo espacio en el que viven
  /// `layout.barras`, así el punto de arrastre se puede comparar
  /// directamente contra esos rects para el hit-test al soltar.
  Offset _aLocal(Offset global) {
    final caja =
        _lienzoPlaneadoKey.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null) return global;
    return caja.globalToLocal(global);
  }

  void _iniciarConector(int origenId, Offset global) {
    setState(() {
      _origenConector = origenId;
      _puntoConector = _aLocal(global);
      _destinoConectorValido = null;
    });
  }

  /// Id de la barra bajo [punto] (con el mismo margen de tolerancia de
  /// siempre), o `null` si no hay ninguna ahí.
  int? _idDestinoBajoPunto(GanttLayout layout, Offset punto) {
    for (final entrada in layout.barras.entries) {
      if (entrada.value.inflate(4).contains(punto)) return entrada.key;
    }
    return null;
  }

  /// `true` si soltar el conector de [origenId] sobre [destinoId] crearía
  /// una dependencia válida — usado solo para el color de la línea
  /// temporal; [_confirmarConector] repite estos mismos criterios paso a
  /// paso porque, a diferencia de aquí, necesita distinguir el caso de
  /// ciclo (que sí avisa con un mensaje específico) del resto (que
  /// simplemente no hacen nada al soltar).
  bool _esDestinoValido(int origenId, int destinoId) {
    if (destinoId == origenId) return false;
    final idx = widget.tareas.indexWhere((t) => t.id == destinoId);
    if (idx == -1) return false;
    if (widget.tareas[idx].dependeDeIds.contains(origenId)) return false;
    return !creariaCicloDependencia(
      widget.tareas,
      dependienteId: destinoId,
      predecesoraId: origenId,
    );
  }

  void _actualizarConector(Offset global) {
    final punto = _aLocal(global);
    final layout = _ultimoLayout;
    final origenId = _origenConector;
    final destinoId = (layout == null || origenId == null)
        ? null
        : _idDestinoBajoPunto(layout, punto);
    setState(() {
      _puntoConector = punto;
      _destinoConectorValido = destinoId == null
          ? null
          : _esDestinoValido(origenId!, destinoId);
    });
  }

  Future<void> _confirmarConector(GanttLayout layout) async {
    final origenId = _origenConector;
    final punto = _puntoConector;
    setState(() {
      _origenConector = null;
      _puntoConector = null;
      _destinoConectorValido = null;
    });
    if (origenId == null || punto == null) return;

    final destinoId = _idDestinoBajoPunto(layout, punto);
    if (destinoId == null || destinoId == origenId) return;

    final idx = widget.tareas.indexWhere((t) => t.id == destinoId);
    if (idx == -1) return;
    final destino = widget.tareas[idx];
    if (destino.dependeDeIds.contains(origenId)) return;

    if (creariaCicloDependencia(
      widget.tareas,
      dependienteId: destinoId,
      predecesoraId: origenId,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Esa dependencia crearía un ciclo — no se puede crear.',
            ),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
      return;
    }

    final movidas = await widget.repository.actualizarTarea(
      destino.copyWith(dependeDeIds: [...destino.dependeDeIds, origenId]),
    );
    await widget.onRefresh();
    _avisarCascada(movidas);
  }

  /// Toca cerca de la flecha de un conector para borrar esa dependencia —
  /// simétrico a crearla arrastrando desde [_asaConector]. Con "Deshacer"
  /// porque es una acción de un solo tap, fácil de disparar sin querer.
  Future<void> _tocarConector(GanttLayout layout, Offset punto) async {
    final conectores = calcularConectores(
      layout.filas.map((f) => f.tarea).toList(),
      layout.barras,
    );
    final c = conectorBajoPunto(conectores, punto);
    if (c == null) return;
    final idx = widget.tareas.indexWhere((t) => t.id == c.destinoId);
    if (idx == -1) return;
    final destino = widget.tareas[idx];
    await widget.repository.actualizarTarea(
      destino.copyWith(
        dependeDeIds: destino.dependeDeIds
            .where((id) => id != c.origenId)
            .toList(),
      ),
    );
    await widget.onRefresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Dependencia eliminada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await widget.repository.actualizarTarea(destino);
            await widget.onRefresh();
          },
        ),
      ),
    );
  }

  /// Asa circular en el borde derecho de la barra planeada de [fila]: al
  /// arrastrarla hasta soltar sobre otra barra, esa otra tarea pasa a
  /// depender de [fila] (flecha de conector en el próximo refresco).
  Widget _asaConector(GanttFila fila, Rect rect) {
    final activo = _origenConector == fila.tarea.id;
    return Positioned(
      left: rect.right - 5,
      top: rect.top + rect.height / 2 - 5,
      width: 10,
      height: 10,
      child: Semantics(
        label: 'Crear dependencia desde "${fila.tarea.titulo}"',
        button: true,
        child: Tooltip(
          message: 'Arrastra para crear una dependencia',
          waitDuration: const Duration(milliseconds: 400),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) =>
                  _iniciarConector(fila.tarea.id, d.globalPosition),
              onPanUpdate: (d) => _actualizarConector(d.globalPosition),
              onPanEnd: (_) => _confirmarConector(_ultimoLayout!),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activo ? KanbanColors.accent : fila.columna.color,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Última [GanttLayout] calculada por `build()` — el arrastre de un
  /// conector la necesita en `onPanEnd`, que corre fuera del `build` que la
  /// originó.
  GanttLayout? _ultimoLayout;

  Widget _encabezadoDias(GanttLayout layout) {
    final limite = layout.inicio.add(Duration(days: layout.totalDias));
    switch (_zoom) {
      case GanttZoom.dia:
        return Row(
          children: [
            for (var i = 0; i < layout.totalDias; i++)
              _diaHeader(layout.inicio.add(Duration(days: i))),
          ],
        );
      case GanttZoom.semana:
        final celdas = <Widget>[];
        var cursor = layout.inicio;
        while (cursor.isBefore(limite)) {
          final fin = cursor.add(const Duration(days: 7));
          final real = fin.isBefore(limite) ? fin : limite;
          celdas.add(
            _celdaAgrupada(
              ancho: real.difference(cursor).inDays * _diaWidthEfectivo,
              texto: '${cursor.day} ${_kMeses[cursor.month - 1]}',
              destacada: _contieneHoy(cursor, real),
            ),
          );
          cursor = real;
        }
        return Row(children: celdas);
      case GanttZoom.mes:
        final celdas = <Widget>[];
        var cursor = layout.inicio;
        while (cursor.isBefore(limite)) {
          final finMes = DateTime(cursor.year, cursor.month + 1, 1);
          final real = finMes.isBefore(limite) ? finMes : limite;
          celdas.add(
            _celdaAgrupada(
              ancho: real.difference(cursor).inDays * _diaWidthEfectivo,
              texto: '${_kMeses[cursor.month - 1]} ${cursor.year}',
              destacada: _contieneHoy(cursor, real),
            ),
          );
          cursor = real;
        }
        return Row(children: celdas);
    }
  }

  bool _contieneHoy(DateTime desde, DateTime hasta) {
    final hoy = soloFecha(DateTime.now());
    return !hoy.isBefore(desde) && hoy.isBefore(hasta);
  }

  Widget _celdaAgrupada({
    required double ancho,
    required String texto,
    required bool destacada,
  }) {
    return Container(
      width: ancho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: destacada ? KanbanColors.accentLight : null,
        border: Border(
          right: BorderSide(color: KanbanColors.borde, width: 0.5),
        ),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: destacada ? FontWeight.bold : FontWeight.normal,
          color: destacada ? KanbanColors.accentDark : KanbanColors.texto,
        ),
      ),
    );
  }

  Widget _diaHeader(DateTime dia) {
    final hoy = DateTime.now();
    final esHoy =
        dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;
    return Container(
      width: _diaWidthEfectivo,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esHoy ? KanbanColors.accentLight : null,
        border: Border(
          right: BorderSide(color: KanbanColors.borde, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _kMeses[dia.month - 1],
            style: TextStyle(fontSize: 9.5, color: KanbanColors.tdim),
          ),
          Text(
            '${dia.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              color: esHoy ? KanbanColors.accentDark : KanbanColors.texto,
            ),
          ),
        ],
      ),
    );
  }

  /// Una fila de la columna de títulos (nombre de tarea + punto de color),
  /// compartida por los dos bloques del Gantt (Planeado / Real) — ambos
  /// muestran las mismas tareas en el mismo orden, así que basta con una
  /// sola implementación.
  Widget _filaTitulo(int index, GanttFila fila) {
    return Container(
      height: kGanttRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: index.isOdd ? KanbanColors.bg3.withValues(alpha: 0.4) : null,
        border: Border(
          bottom: BorderSide(color: KanbanColors.borde),
          right: BorderSide(color: KanbanColors.borde),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: fila.columna.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: InkWell(
              onTap: () => widget.onAbrirTarea(fila.tarea),
              child: Text(
                fila.tarea.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: KanbanColors.texto,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fila vacía (sin tarea) con el mismo rayado/bordes que [_filaTitulo] —
  /// usada para las filas "fantasma" que rellenan hacia abajo cuando hay
  /// menos tareas que espacio vertical disponible, igual que el ancho de
  /// día se estira cuando hay menos días que ancho disponible.
  Widget _filaTituloFantasma(int index) {
    return Container(
      height: kGanttRowHeight,
      decoration: BoxDecoration(
        color: index.isOdd ? KanbanColors.bg3.withValues(alpha: 0.4) : null,
        border: Border(
          bottom: BorderSide(color: KanbanColors.borde),
          right: BorderSide(color: KanbanColors.borde),
        ),
      ),
    );
  }

  Widget _columnaTitulos(List<GanttFila> filas, {int? filasTotal}) {
    final total = filasTotal ?? filas.length;
    return SizedBox(
      width: kGanttTitleColumnWidth,
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) _filaTitulo(i, filas[i]),
          for (var i = filas.length; i < total; i++) _filaTituloFantasma(i),
        ],
      ),
    );
  }

  /// Franjas alternadas de fondo por fila, compartidas por los dos
  /// bloques del Gantt.
  List<Widget> _fondoFilas(int cantidad) {
    return [
      for (var i = 0; i < cantidad; i++)
        Positioned(
          left: 0,
          right: 0,
          top: i * kGanttRowHeight,
          height: kGanttRowHeight,
          child: Container(
            decoration: BoxDecoration(
              color: i.isOdd ? KanbanColors.bg3.withValues(alpha: 0.4) : null,
              border: Border(bottom: BorderSide(color: KanbanColors.borde)),
            ),
          ),
        ),
    ];
  }

  /// Un bloque completo del Gantt (columna de títulos + línea de tiempo
  /// propia), usado dos veces: una para "Planeado" y otra para "Real" —
  /// dos cronogramas separados en vez de una barra apilada bajo otra.
  Widget _bloqueGantt({
    required List<GanttFila> filas,
    required Widget timeline,
    int? filasTotal,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _columnaTitulos(filas, filasTotal: filasTotal),
        Expanded(child: timeline),
      ],
    );
  }

  /// Barra "real" (tiempo real transcurrido): del mismo alto que la barra
  /// planeada pero claramente separada de ella (fila propia, con espacio de
  /// por medio) y con un tratamiento visual distinto — relleno tenue del
  /// color de la columna y borde sólido — para que planeado y real se lean
  /// como dos cronogramas independientes y no como una sola barra con un
  /// hilito debajo. De solo lectura: sin arrastre/resize. Si la tarea sigue
  /// en curso (sin `fechaFinReal`), el borde derecho se pinta punteado en
  /// vez de cerrado, para marcar que la fecha de fin todavía no existe.
  Widget _barraReal({
    required Rect rect,
    required Color color,
    required bool enCurso,
    required String titulo,
  }) {
    final bordeColor = color.withValues(alpha: 0.85);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Tooltip(
        message: titulo,
        waitDuration: const Duration(milliseconds: 300),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(color: bordeColor, width: 1.4),
                  top: BorderSide(color: bordeColor, width: 1.4),
                  bottom: BorderSide(color: bordeColor, width: 1.4),
                  right: enCurso
                      ? BorderSide.none
                      : BorderSide(color: bordeColor, width: 1.4),
                ),
              ),
            ),
            if (enCurso)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: CustomPaint(
                  painter: _BordePunteadoVerticalPainter(color: bordeColor),
                ),
              ),
            if (rect.width >= 30)
              Positioned.fill(
                child: Center(
                  child: Text(
                    'Real',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelSinFechas(List<Tarea> sinFechas) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(top: BorderSide(color: KanbanColors.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sinFechas.length} ${sinFechas.length == 1 ? 'tarjeta sin fecha' : 'tarjetas sin fecha'} — agrégales fecha de inicio y vencimiento para verlas en el cronograma',
            style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in sinFechas)
                ActionChip(
                  label: Text(t.titulo, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => widget.onAbrirTarea(t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyendaPlaneado() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(
            color: KanbanColors.tdim,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Planeado',
          style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
        ),
      ],
    );
  }

  Widget _leyendaReal() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(
            color: KanbanColors.tdim.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: KanbanColors.tdim.withValues(alpha: 0.85),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Real',
          style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
        ),
      ],
    );
  }

  String _fecha(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Exporta el cronograma (planeado vs. real, ruta crítica) a CSV — la
  /// vista Lista ya tenía su propio export, pero acá había que abrir cada
  /// tarjeta o mirar las barras a ojo para sacar fechas planeadas vs.
  /// reales en limpio.
  void _exportarCsvGantt(GanttLayout layout) {
    final rutaCritica = calcularRutaCritica(widget.tareas);
    final encabezado = const [
      'Tarea',
      'Columna',
      'Inicio planeado',
      'Fin planeado',
      'Inicio real',
      'Fin real',
      'Ruta crítica',
      'Progreso',
    ].map(campoCsv).join(',');
    final lineas = [encabezado];
    for (final fila in layout.filas) {
      final t = fila.tarea;
      lineas.add(
        [
          t.titulo,
          fila.columna.titulo,
          _fecha(t.fechaInicio),
          _fecha(t.fechaVencimiento),
          _fecha(t.fechaInicioReal),
          _fecha(t.fechaFinReal),
          rutaCritica.contains(t.id) ? 'Sí' : 'No',
          '${(t.progreso * 100).round()}%',
        ].map(campoCsv).join(','),
      );
    }
    try {
      descargarCsv('gantt_kanban.csv', lineas.join('\r\n'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Exportar a CSV solo está disponible en la versión web.',
          ),
          backgroundColor: KanbanColors.danger,
        ),
      );
    }
  }

  Widget _selectorZoom({GanttLayout? layout}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: KanbanColors.cardDecoration(radius: 10),
      // Un solo `Wrap` para toda la barra (no un `Row` con solo la leyenda
      // envuelta): un `Row` no reparte a sus hijos rígidos en líneas
      // nuevas, así que en pantallas angostas "Hoy"/"Exportar"/el selector
      // de zoom se salían de la pantalla en vez de bajar a su propia línea.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [_leyendaPlaneado(), _leyendaReal()],
          ),
          const SizedBox(width: 12),
          if (layout != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _irAHoy(layout),
                icon: Icon(
                  Icons.today_rounded,
                  size: 15,
                  color: KanbanColors.texto,
                ),
                label: Text(
                  'Hoy',
                  style: TextStyle(fontSize: 12, color: KanbanColors.texto),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: KanbanColors.borde),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _exportarCsvGantt(layout),
                icon: Icon(
                  Icons.download_rounded,
                  size: 15,
                  color: KanbanColors.texto,
                ),
                label: Text(
                  'Exportar',
                  style: TextStyle(fontSize: 12, color: KanbanColors.texto),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: KanbanColors.borde),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          SegmentedButton<GanttZoom>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: GanttZoom.dia, label: Text('Día')),
              ButtonSegment(value: GanttZoom.semana, label: Text('Semana')),
              ButtonSegment(value: GanttZoom.mes, label: Text('Mes')),
            ],
            selected: {_zoom},
            onSelectionChanged: (s) => setState(() {
              _zoom = s.first;
              _yaCentrado = false;
              widget.onZoomCambiado?.call(_zoom);
            }),
            style: KanbanColors.segmentedButtonStyle(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layoutNominal = calcularGanttLayout(
      tareas: widget.tareas,
      columnas: widget.columnas,
      dayWidth: _zoom.dayWidth,
    );
    final rutaCritica = calcularRutaCritica(widget.tareas);

    if (layoutNominal.filas.isEmpty) {
      _ultimoLayout = layoutNominal;
      return Column(
        children: [
          _selectorZoom(),
          Expanded(
            child: Center(
              child: Text(
                layoutNominal.sinFechas.isEmpty
                    ? 'No hay tareas para mostrar en el Gantt.'
                    : 'Ninguna tarjeta tiene fecha de inicio y vencimiento aún.',
                style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
              ),
            ),
          ),
          if (layoutNominal.sinFechas.isNotEmpty)
            _panelSinFechas(layoutNominal.sinFechas),
        ],
      );
    }

    return Column(
      children: [
        _selectorZoom(layout: layoutNominal),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Si el cronograma natural (zoom elegido × total de días)
              // cabe en menos ancho del que hay disponible, estira los
              // días para llenar la pantalla en vez de dejar una franja
              // vacía a la derecha — nunca se encoge por debajo del zoom
              // elegido, solo crece cuando sobra espacio.
              final anchoDisponible =
                  (constraints.maxWidth - kGanttTitleColumnWidth).clamp(
                    0.0,
                    double.infinity,
                  );
              _diaWidthEfectivo = layoutNominal.totalDias > 0
                  ? (anchoDisponible / layoutNominal.totalDias).clamp(
                      _zoom.dayWidth,
                      double.infinity,
                    )
                  : _zoom.dayWidth;
              final layout = _diaWidthEfectivo == _zoom.dayWidth
                  ? layoutNominal
                  : calcularGanttLayout(
                      tareas: widget.tareas,
                      columnas: widget.columnas,
                      dayWidth: _diaWidthEfectivo,
                    );
              _ultimoLayout = layout;

              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _centrarEnHoy(layout),
              );

              final anchoTotal = layout.totalDias * _diaWidthEfectivo;

              // Igual que el ancho de día: si hay menos tareas que espacio
              // vertical disponible, agrega filas "fantasma" (mismo rayado,
              // sin datos) a cada bloque para que el rayado llegue hasta
              // abajo en vez de dejar un vacío — nunca menos que las filas
              // reales, solo de más cuando sobra espacio. El estimado de
              // "chrome" son las leyendas, el divisor grueso y los paddings
              // fijos entre los dos bloques (Planeado/Real) que no dependen
              // de cuántas tareas haya.
              const alturaChromeEntreBloques = 150.0;
              final alturaDisponibleFilas =
                  (constraints.maxHeight -
                          kGanttHeaderHeight -
                          1 -
                          alturaChromeEntreBloques)
                      .clamp(0.0, double.infinity) /
                  2;
              final filasConFantasmas = [
                layout.filas.length,
                (alturaDisponibleFilas / kGanttRowHeight).ceil(),
              ].reduce((a, b) => a > b ? a : b);
              final altoTotal = layout.filas.length * kGanttRowHeight;
              final altoTotalConFantasmas = filasConFantasmas * kGanttRowHeight;

              return Listener(
                onPointerSignal: (evento) {
                  if (evento is PointerScrollEvent) {
                    _manejarZoomRueda(evento);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: kGanttHeaderHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(width: kGanttTitleColumnWidth),
                          Expanded(
                            child: ClipRect(
                              child: SingleChildScrollView(
                                controller: _hCtrlHeader,
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                child: SizedBox(
                                  width: anchoTotal,
                                  child: _encabezadoDias(layout),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: KanbanColors.borde),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _leyendaPlaneado(),
                              ),
                              _bloqueGantt(
                                filas: layout.filas,
                                filasTotal: filasConFantasmas,
                                // `Scrollbar` visible: sin ella, nada indicaba que
                                // el cronograma se puede desplazar horizontalmente
                                // más allá de lo que cabe en pantalla.
                                timeline: Scrollbar(
                                  controller: _hCtrlBody,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    key: _viewportPlaneadoKey,
                                    controller: _hCtrlBody,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: anchoTotal,
                                      height: altoTotalConFantasmas,
                                      child: Stack(
                                        key: _lienzoPlaneadoKey,
                                        clipBehavior: Clip.none,
                                        children: [
                                          ..._fondoFilas(filasConFantasmas),
                                          // Toca cerca de una flecha para borrar esa
                                          // dependencia — antes solo se podían
                                          // *crear* arrastrando un conector, no
                                          // quitar sin abrir el detalle de la
                                          // tarea. `behavior: opaque` para que
                                          // funcione también sobre el área vacía
                                          // del lienzo, no solo donde hay trazo.
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapUp: (details) =>
                                                _tocarConector(
                                                  layout,
                                                  details.localPosition,
                                                ),
                                            child: CustomPaint(
                                              size: Size(anchoTotal, altoTotal),
                                              painter: GanttConnectorsPainter(
                                                tareas: layout.filas
                                                    .map((f) => f.tarea)
                                                    .toList(),
                                                barras: layout.barras,
                                              ),
                                            ),
                                          ),
                                          // Nota: no envolver esto en
                                          // `RepaintBoundary` — `GanttBar` devuelve
                                          // un `Positioned` en su propio `build()`,
                                          // y `Positioned` necesita colgar
                                          // directamente del `Stack` (sin otro
                                          // widget de render en medio) para que su
                                          // `rect` se aplique. Con un
                                          // `RepaintBoundary` de por medio, el
                                          // posicionamiento se rompe y la barra se
                                          // dibuja con tamaño/posición por defecto,
                                          // tapando todo lo demás — ver la barra
                                          // gigante que causó esto (probado en la
                                          // app real).
                                          for (final fila in layout.filas)
                                            GanttBar(
                                              tarea: fila.tarea,
                                              rect:
                                                  layout.barras[fila.tarea.id]!,
                                              color: fila.columna.color,
                                              dayWidth: _diaWidthEfectivo,
                                              esCritica: rutaCritica.contains(
                                                fila.tarea.id,
                                              ),
                                              onTap: () => widget.onAbrirTarea(
                                                fila.tarea,
                                              ),
                                              onFechasCambiadas: (ini, fin) =>
                                                  _actualizarFechas(
                                                    fila.tarea,
                                                    ini,
                                                    fin,
                                                  ),
                                              onArrastreCuerpoEnCurso:
                                                  _manejarAutoscrollGantt,
                                              onArrastreCuerpoTerminado:
                                                  _detenerAutoscrollGantt,
                                            ),
                                          for (final fila in layout.filas)
                                            _asaConector(
                                              fila,
                                              layout.barras[fila.tarea.id]!,
                                            ),
                                          // `layout.barras[_origenConector]` puede
                                          // faltar si, mientras se arrastraba el
                                          // conector, la tarea origen salió del
                                          // layout (un filtro la ocultó, se archivó,
                                          // etc.) — sin este chequeo, el `!` de abajo
                                          // tronaba con un null-check exception.
                                          if (_origenConector != null &&
                                              _puntoConector != null &&
                                              layout.barras[_origenConector] !=
                                                  null)
                                            CustomPaint(
                                              size: Size(anchoTotal, altoTotal),
                                              painter: _ConectorTemporalPainter(
                                                origen: layout
                                                    .barras[_origenConector]!,
                                                destino: _puntoConector!,
                                                // Verde: el destino bajo el punto
                                                // aceptaría la dependencia. Rojo: lo
                                                // rechazaría (ciclo, ya existe,
                                                // auto-referencia). Acento: no hay
                                                // ninguna barra bajo el punto
                                                // todavía.
                                                color:
                                                    switch (_destinoConectorValido) {
                                                      true => const Color(
                                                        0xFF16A34A,
                                                      ),
                                                      false =>
                                                        KanbanColors.danger,
                                                      null =>
                                                        KanbanColors.accent,
                                                    },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: kGanttSeccionEspacio),
                              // Divisor grueso (no un `Divider` delgado): marca
                              // con más fuerza que "Planeado" y "Real" son dos
                              // secciones independientes, cada una con su propio
                              // scroll — no un solo cronograma partido a la mitad.
                              Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: KanbanColors.borde,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _leyendaReal(),
                              ),
                              _bloqueGantt(
                                filas: layout.filas,
                                filasTotal: filasConFantasmas,
                                timeline: Scrollbar(
                                  controller: _hCtrlBodyReal,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _hCtrlBodyReal,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: anchoTotal,
                                      height: altoTotalConFantasmas,
                                      child: Stack(
                                        children: [
                                          ..._fondoFilas(filasConFantasmas),
                                          for (final fila in layout.filas)
                                            if (layout.barrasReales[fila
                                                    .tarea
                                                    .id]
                                                case final rectReal?)
                                              _barraReal(
                                                rect: rectReal,
                                                color: fila.columna.color,
                                                titulo: fila.tarea.titulo,
                                                enCurso: layout.realesEnCurso
                                                    .contains(fila.tarea.id),
                                              )
                                            else
                                              Positioned(
                                                left: layout
                                                    .barras[fila.tarea.id]!
                                                    .left,
                                                top:
                                                    layout
                                                        .barras[fila.tarea.id]!
                                                        .top +
                                                    (kGanttBarHeight - 14) / 2,
                                                child: Text(
                                                  'Sin iniciar',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: KanbanColors.tdim,
                                                  ),
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (layoutNominal.sinFechas.isNotEmpty)
          _panelSinFechas(layoutNominal.sinFechas),
      ],
    );
  }
}

/// Borde derecho punteado para la barra "real" de una tarea aún en curso
/// (sin `fechaFinReal`): distingue de un vistazo "todavía no cierra" de "ya
/// cerró" sin necesitar otro color — el resto del borde (izq/arriba/abajo)
/// se pinta sólido como de costumbre.
class _BordePunteadoVerticalPainter extends CustomPainter {
  final Color color;

  const _BordePunteadoVerticalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    const largoGuion = 4.0;
    const espacio = 3.0;
    final x = size.width / 2;
    var y = 0.0;
    while (y < size.height) {
      final fin = (y + largoGuion).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, fin), paint);
      y += largoGuion + espacio;
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteadoVerticalPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Línea "codo" que sigue al puntero mientras se arrastra un conector de
/// dependencia desde el borde derecho de una barra planeada — el mismo
/// estilo de codo+flecha que [GanttConnectorsPainter], pero terminando en
/// el punto de arrastre en vez de en otra barra.
class _ConectorTemporalPainter extends CustomPainter {
  final Rect origen;
  final Offset destino;
  final Color color;

  const _ConectorTemporalPainter({
    required this.origen,
    required this.destino,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linea = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final inicio = Offset(origen.right, origen.center.dy);
    final midX = (inicio.dx + destino.dx) / 2;
    final path = Path()
      ..moveTo(inicio.dx, inicio.dy)
      ..lineTo(midX, inicio.dy)
      ..lineTo(midX, destino.dy)
      ..lineTo(destino.dx, destino.dy);
    canvas.drawPath(path, linea);
    canvas.drawCircle(destino, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ConectorTemporalPainter oldDelegate) =>
      oldDelegate.origen != origen ||
      oldDelegate.destino != destino ||
      oldDelegate.color != color;
}
