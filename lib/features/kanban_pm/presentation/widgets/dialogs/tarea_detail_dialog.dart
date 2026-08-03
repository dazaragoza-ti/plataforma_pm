import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/actividad.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea.dart';
import '../../../data/usuario_directorio.dart';
import '../../../domain/entities/tarea_etiqueta.dart';
import '../../../domain/entities/usuario.dart';
import '../common/color_wheel_picker.dart';
import 'actividad_fechas_dialog.dart';
import 'confirmar_eliminar_dialog.dart';
import 'kanban_alert_dialog.dart';
import 'pausar_tarea_dialog.dart';

/// Diálogo de detalle/edición de una tarea: datos generales, las 3
/// clasificaciones (Generales/Nivel/Importancia) y checklist de
/// actividades — replica el diseño del panel de detalle de referencia.
class TareaDetailDialog extends StatefulWidget {
  final KanbanRepository repository;
  final int tareaId;
  final VoidCallback onRefresh;

  const TareaDetailDialog({
    super.key,
    required this.repository,
    required this.tareaId,
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
    required int tareaId,
    required VoidCallback onRefresh,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TareaDetailDialog(
        repository: repository,
        tareaId: tareaId,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<TareaDetailDialog> createState() => _TareaDetailDialogState();
}

class _TareaDetailDialogState extends State<TareaDetailDialog> {
  Tarea? _tarea;
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _nuevaActividadCtrl = TextEditingController();
  final _nuevaEtiquetaCtrl = TextEditingController();
  final _nuevoMiembroCtrl = TextEditingController();

  String? _area;
  int _generalesIdx = 0;
  int _nivelIdx = 0;
  int _importanciaIdx = 0;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _ocultarCompletados = false;
  bool _creandoActividad = false;
  bool _guardando = false;

  List<TareaEtiqueta> _catalogoEtiquetas = [];
  Set<int> _etiquetaIdsSeleccionadas = {};
  List<Miembro> _catalogoMiembros = [];
  Set<int> _miembroIdsSeleccionados = {};
  Color? _portada;
  Set<int> _dependeDeSeleccionadas = {};
  bool _creandoEtiqueta = false;
  Color _colorNuevaEtiqueta = kColorPaletteEtiquetas.first;
  bool _creandoMiembro = false;
  Color _colorNuevoMiembro = kColorPaletteEtiquetas.first;

  /// Guards contra doble-tap/Enter-y-clic-rápido: sin ellos, un segundo
  /// disparo antes de que el primer `await` resuelva (~150ms de latencia
  /// simulada) creaba dos `Miembro`/`TareaEtiqueta` duplicados — el
  /// repositorio no deduplica por nombre ni por `usuarioId`. Mismo
  /// patrón que `WorkspaceMiembrosDialog._agregando`.
  bool _guardandoEtiquetaNueva = false;
  bool _guardandoMiembroNuevo = false;
  final Set<String> _agregandoDeDirectorio = {};

  /// Id de la actividad bajo la que se está agregando una subtarea (`null`
  /// si ninguna, o si el composer visible es el de nivel raíz).
  int? _padreSubActividad;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _nuevaActividadCtrl.dispose();
    _nuevaEtiquetaCtrl.dispose();
    _nuevoMiembroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final results = await Future.wait([
      widget.repository.obtenerTarea(widget.tareaId),
      widget.repository.listarEtiquetas(),
      widget.repository.listarMiembros(),
    ]);
    if (!mounted) return;
    final t = results[0] as Tarea?;
    final etiquetas = results[1] as List<TareaEtiqueta>;
    final miembros = results[2] as List<Miembro>;
    if (t == null) return;
    setState(() {
      _tarea = t;
      _catalogoEtiquetas = etiquetas;
      _catalogoMiembros = miembros;
      _tituloCtrl.text = t.titulo;
      _descripcionCtrl.text = t.descripcion;
      _area = t.grupo.isEmpty ? null : t.grupo;
      _fechaInicio = t.fechaInicio;
      _fechaFin = t.fechaVencimiento;
      _portada = t.portada;
      _etiquetaIdsSeleccionadas = t.etiquetaIds.toSet();
      _miembroIdsSeleccionados = t.miembroIds.toSet();
      _dependeDeSeleccionadas = t.dependeDeIds.toSet();
      _generalesIdx = t.generales == null
          ? 0
          : kGeneralesDemo
                .indexWhere((c) => c.$1 == t.generales!.$1)
                .clamp(0, kGeneralesDemo.length - 1);
      _nivelIdx = t.nivel == null
          ? 0
          : kNivelDemo
                .indexWhere((c) => c.$1 == t.nivel!.$1)
                .clamp(0, kNivelDemo.length - 1);
      _importanciaIdx = t.importancia == null
          ? 0
          : kImportanciaDemo
                .indexWhere((c) => c.$1 == t.importancia!.$1)
                .clamp(0, kImportanciaDemo.length - 1);
    });
  }

  void _toggleEtiqueta(int id) {
    setState(() {
      if (!_etiquetaIdsSeleccionadas.add(id)) {
        _etiquetaIdsSeleccionadas.remove(id);
      }
    });
  }

  Future<void> _crearEtiqueta() async {
    final nombre = _nuevaEtiquetaCtrl.text.trim();
    if (nombre.isEmpty || _guardandoEtiquetaNueva) return;
    _guardandoEtiquetaNueva = true;
    try {
      final id = await widget.repository.crearEtiqueta(
        nombre,
        _colorNuevaEtiqueta,
      );
      // El chequeo de `mounted` va ANTES de tocar el controller: si el
      // diálogo se cerró durante el `await` de arriba, `dispose()` ya corrió
      // y `_nuevaEtiquetaCtrl` quedó liberado — llamar `.clear()` sobre un
      // `TextEditingController` ya disposed lanza una excepción.
      if (!mounted) return;
      _nuevaEtiquetaCtrl.clear();
      // Mismo motivo que en `_crearMiembro`: agregar al catálogo local en vez
      // de `_cargar()` para no perder ediciones sin guardar del resto del
      // formulario.
      setState(() {
        _creandoEtiqueta = false;
        _catalogoEtiquetas = [
          ..._catalogoEtiquetas,
          TareaEtiqueta(id: id, nombre: nombre, color: _colorNuevaEtiqueta),
        ];
        _etiquetaIdsSeleccionadas.add(id);
      });
    } finally {
      _guardandoEtiquetaNueva = false;
    }
  }

  void _toggleMiembro(int id) {
    setState(() {
      if (!_miembroIdsSeleccionados.add(id)) {
        _miembroIdsSeleccionados.remove(id);
      }
    });
  }

  Future<void> _crearMiembro() async {
    final nombre = _nuevoMiembroCtrl.text.trim();
    if (nombre.isEmpty || _guardandoMiembroNuevo) return;
    _guardandoMiembroNuevo = true;
    try {
      final id = await widget.repository.crearMiembro(
        nombre,
        _colorNuevoMiembro,
      );
      // Ver el comentario equivalente en `_crearEtiqueta`: el chequeo de
      // `mounted` va antes de tocar el controller, no después.
      if (!mounted) return;
      _nuevoMiembroCtrl.clear();
      // Agrega el miembro nuevo al catálogo local en vez de recargar con
      // `_cargar()`: esa llamada re-lee la tarea del repositorio y pisa por
      // completo el estado del formulario (título, fechas, la propia
      // selección de miembros que se acaba de tocar…) con lo último guardado
      // — como este diálogo no autoguarda campo por campo, eso borraba
      // cualquier cambio sin persistir todavía con solo crear un miembro
      // nuevo.
      setState(() {
        _creandoMiembro = false;
        _catalogoMiembros = [
          ..._catalogoMiembros,
          Miembro(id: id, nombre: nombre, colorAvatar: _colorNuevoMiembro),
        ];
        _miembroIdsSeleccionados.add(id);
      });
    } finally {
      _guardandoMiembroNuevo = false;
    }
  }

  /// Agrega a [usuario] (alguien del directorio global, típicamente de
  /// otra área de trabajo) al catálogo de miembros de ESTA tarea — a
  /// diferencia de [_crearMiembro], liga el registro nuevo a su
  /// [Usuario.id] (ver [Miembro.usuarioId]), así que esta área le
  /// aparece en su selector aunque no sea "de su departamento".
  Future<void> _agregarDeDirectorio(Usuario usuario) async {
    if (_agregandoDeDirectorio.contains(usuario.id)) return;
    _agregandoDeDirectorio.add(usuario.id);
    try {
      final id = await widget.repository.crearMiembro(
        usuario.nombre,
        usuario.colorAvatar,
        usuarioId: usuario.id,
      );
      if (!mounted) return;
      setState(() {
        _catalogoMiembros = [
          ..._catalogoMiembros,
          Miembro(
            id: id,
            nombre: usuario.nombre,
            colorAvatar: usuario.colorAvatar,
            usuarioId: usuario.id,
          ),
        ];
        _miembroIdsSeleccionados.add(id);
      });
    } finally {
      _agregandoDeDirectorio.remove(usuario.id);
    }
  }

  /// Lista desplegable con el catálogo completo del tablero para marcar/
  /// desmarcar miembros de la tarea, en vez de una fila de chips siempre
  /// visible — el cambio queda en `_miembroIdsSeleccionados` (estado local
  /// del formulario) y se persiste hasta que se presiona GUARDAR, igual
  /// que el resto de los campos de este diálogo.
  void _mostrarSelectorMiembros(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => kanbanAlertDialog(
          titulo: 'Miembros',
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_catalogoMiembros.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final m in _catalogoMiembros)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: KanbanColors.accent,
                              value: _miembroIdsSeleccionados.contains(m.id),
                              secondary: CircleAvatar(
                                radius: 12,
                                backgroundColor: m.colorAvatar,
                                child: Text(
                                  m.nombre.isNotEmpty
                                      ? m.nombre[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(
                                m.nombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: KanbanColors.texto,
                                ),
                              ),
                              onChanged: (_) {
                                _toggleMiembro(m.id);
                                setDialogState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    // Gente del directorio global que ya existe (en otra
                    // área) pero todavía no en el catálogo de esta —
                    // agregarla de aquí es lo que la hace "invitada" de
                    // esta área: su Miembro nuevo queda ligado al mismo
                    // Usuario, así que le aparece en su selector.
                    final disponibles = UsuarioDirectorio.instancia
                        .listar()
                        .where(
                          (u) => !_catalogoMiembros.any(
                            (m) => m.usuarioId == u.id,
                          ),
                        )
                        .toList();
                    if (disponibles.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AGREGAR DE OTRA ÁREA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: KanbanColors.tdim,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final u in disponibles)
                                ActionChip(
                                  avatar: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: u.colorAvatar,
                                    child: Text(
                                      u.nombre.isNotEmpty
                                          ? u.nombre[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  label: Text(
                                    u.nombre,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                  backgroundColor: KanbanColors.bg3,
                                  side: BorderSide(color: KanbanColors.borde),
                                  onPressed: () async {
                                    await _agregarDeDirectorio(u);
                                    // `ctx.mounted` (no solo el `mounted`
                                    // del diálogo grande, que sigue vivo
                                    // aunque este selector anidado ya se
                                    // haya cerrado): sin este chequeo,
                                    // cerrar "Miembros" mientras el
                                    // `await` de arriba sigue en curso
                                    // deja `setDialogState` apuntando a
                                    // un `StatefulBuilder` ya desmontado
                                    // — lanza incluso en release, no solo
                                    // en un `assert` de debug.
                                    if (ctx.mounted) setDialogState(() {});
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_creandoMiembro) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nuevoMiembroCtrl,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: KanbanColors.texto,
                          ),
                          decoration: _decoracion().copyWith(
                            hintText: 'Nombre de la persona…',
                          ),
                          onSubmitted: (_) async {
                            await _crearMiembro();
                            // Ver el comentario equivalente de
                            // `_agregarDeDirectorio` más arriba.
                            if (ctx.mounted) setDialogState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.check_circle_rounded,
                          color: KanbanColors.ok,
                        ),
                        onPressed: () async {
                          await _crearMiembro();
                          if (ctx.mounted) setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _botonColorRueda(
                    color: _colorNuevoMiembro,
                    onTap: () async {
                      final elegido = await showColorWheelDialog(
                        ctx,
                        initial: _colorNuevoMiembro,
                        titulo: 'Color del miembro',
                      );
                      if (elegido == null || !mounted) return;
                      setState(() => _colorNuevoMiembro = elegido);
                      // Ver el comentario de `_agregarDeDirectorio` más
                      // arriba: `mounted` (del diálogo grande) no basta,
                      // hace falta `ctx.mounted` (de este selector
                      // anidado) antes de tocar `setDialogState`.
                      if (ctx.mounted) setDialogState(() {});
                    },
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () =>
                        setDialogState(() => _creandoMiembro = true),
                    icon: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: KanbanColors.accent,
                    ),
                    label: Text(
                      'Nuevo miembro',
                      style: TextStyle(color: KanbanColors.accent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Se ejecuta sin importar cómo se cerró el selector (botón
      // "Cerrar", tocar fuera, Esc, atrás del sistema) — antes solo el
      // botón "Cerrar" reseteaba `_creandoMiembro`/limpiaba el texto sin
      // confirmar; cualquier otra forma de cerrar dejaba el composer de
      // "nuevo miembro" abierto (con lo que se hubiera escrito) para la
      // próxima vez que se abriera "Miembros".
      if (!mounted) return;
      setState(() => _creandoMiembro = false);
      _nuevoMiembroCtrl.clear();
    });
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _fechaInicio : _fechaFin) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha == null || !mounted) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = fecha;
        // Si el nuevo inicio queda después del fin ya elegido, el fin se
        // recorre junto con él — mismo comportamiento que arrastrar el
        // borde izquierdo de una barra en el Gantt (ver
        // `GanttBar._confirmarIzquierda`), en vez de dejar guardar un
        // rango de fechas invertido.
        if (_fechaFin != null && fecha.isAfter(_fechaFin!)) {
          _fechaFin = fecha;
        }
      } else {
        _fechaFin = fecha;
        if (_fechaInicio != null && fecha.isBefore(_fechaInicio!)) {
          _fechaInicio = fecha;
        }
      }
    });
  }

  Future<void> _elegirHora() async {
    final actual = _fechaInicio ?? DateTime.now();
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null || !mounted) return;
    setState(() {
      final base = _fechaInicio ?? DateTime.now();
      _fechaInicio = DateTime(
        base.year,
        base.month,
        base.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  Future<void> _iniciar() async {
    // Reusa `_guardando` (no un flag nuevo): bloquea el mismo botón contra
    // doble-tap Y el cierre del diálogo mientras esta operación async
    // sigue en curso — sin esto, un doble-tap rápido con la tarjeta en
    // "Proceso" disparaba dos veces `PausarTareaDialog.show(...)`
    // apilados, registrando dos entradas de historial "Pausó: ..." para
    // una sola acción.
    setState(() => _guardando = true);
    try {
      await _iniciarInterno();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _iniciarInterno() async {
    final t = _tarea!;
    final TareaEstatus nuevo;
    switch (t.estatus) {
      case TareaEstatus.tareas:
      case TareaEstatus.pausa:
        nuevo = TareaEstatus.proceso;
      case TareaEstatus.proceso:
        nuevo = TareaEstatus.pausa;
      case TareaEstatus.terminado:
      case TareaEstatus.revisado:
        nuevo = TareaEstatus.proceso;
      default:
        // Columna personalizada (ver `KanbanRepository.crearColumna`): no
        // participa del flujo tareas→proceso→pausa→terminado/revisado, así
        // que este botón simplemente la trae de vuelta a Proceso.
        nuevo = TareaEstatus.proceso;
    }
    if (nuevo != t.estatus) {
      final columnas = await widget.repository.listarColumnas();
      KanbanColumna? columna;
      for (final c in columnas) {
        if (c.estatus == nuevo) {
          columna = c;
          break;
        }
      }
      // A diferencia de arrastrar una tarjeta (que solo ofrece columnas
      // visibles como destino), este botón calcula `nuevo` con un
      // `switch` fijo y no tenía ningún chequeo — si esa columna estaba
      // archivada, la tarjeta se movía igual y desaparecía del tablero
      // sin ningún aviso, sin quedar tampoco en "Tarjetas archivadas".
      if (columna?.archivada == true) {
        if (mounted) {
          kanbanToast(
            context,
            'La lista "${columna!.titulo}" está archivada. Desarchívala '
            'antes de mover una tarjeta ahí.',
            ok: false,
          );
        }
        return;
      }
      final limite = columna?.limiteWip;
      if (limite != null) {
        final todas = await widget.repository.listarTareas();
        final ocupadas = todas
            .where((x) => x.id != t.id && x.estatus == nuevo)
            .length;
        if (ocupadas >= limite) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ya hay ${ocupadas == 1 ? 'una tarjeta' : '$ocupadas tarjetas'} '
                  'en "${columna!.titulo}" (límite $limite). Muévela antes '
                  'de agregar otra.',
                ),
                backgroundColor: KanbanColors.danger,
              ),
            );
          }
          return;
        }
      }
    }
    if (!mounted) return;
    if (nuevo == TareaEstatus.pausa) {
      final continuar = await PausarTareaDialog.show(
        context,
        repository: widget.repository,
        tarea: t,
      );
      if (!continuar || !mounted) return;
    }
    final movida = await widget.repository.moverTarea(t.id, nuevo);
    widget.onRefresh();
    await _cargar();
    // `movida == false`: la columna destino se archivó en la ventana
    // entre el chequeo de más arriba y esta llamada (o durante el
    // `PausarTareaDialog`/chequeo de límite de WIP, que también esperan).
    // Sin este aviso, el botón "no hacía nada" sin ninguna explicación.
    if (!movida && mounted) {
      kanbanToast(
        context,
        'No se pudo mover: la columna de destino está archivada.',
        ok: false,
      );
    }
  }

  String _labelBoton(TareaEstatus estatus) {
    switch (estatus) {
      case TareaEstatus.tareas:
        return 'Iniciar';
      case TareaEstatus.pausa:
        return 'Reanudar';
      case TareaEstatus.proceso:
        return 'Pausar';
      case TareaEstatus.terminado:
      case TareaEstatus.revisado:
        return 'Reabrir';
      default:
        return 'Mover a Proceso';
    }
  }

  Future<void> _guardar() async {
    // Sin esta validación (que `NuevaTareaDialog._crear()` sí hace), se
    // podía guardar el título en blanco con solo borrar el campo y tocar
    // GUARDAR, dejando una tarjeta sin título visible en el tablero.
    if (_tituloCtrl.text.trim().isEmpty) {
      kanbanToast(context, 'El título no puede quedar vacío.', ok: false);
      return;
    }
    setState(() => _guardando = true);
    try {
      final movidas = await widget.repository.actualizarTarea(
        _tarea!.copyWith(
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          grupo: _area ?? '',
          fechaInicio: _fechaInicio,
          fechaVencimiento: _fechaFin,
          generales: kGeneralesDemo[_generalesIdx],
          nivel: kNivelDemo[_nivelIdx],
          importancia: kImportanciaDemo[_importanciaIdx],
          etiquetaIds: _etiquetaIdsSeleccionadas.toList(),
          miembroIds: _miembroIdsSeleccionados.toList(),
          portada: _portada,
          limpiarPortada: _portada == null,
          dependeDeIds: _dependeDeSeleccionadas.toList(),
        ),
      );
      widget.onRefresh();
      // Aviso antes de cerrar: si el cambio de fechas/dependencias empujó
      // a otras tarjetas en cascada, quien edita debería enterarse aquí
      // mismo, no tener que abrir cada sucesora después para notarlo.
      if (movidas > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              movidas == 1
                  ? 'Se recorrió 1 tarjeta sucesora para respetar la '
                        'dependencia'
                  : 'Se recorrieron $movidas tarjetas sucesoras para '
                        'respetar la dependencia',
            ),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (ex) {
      // El detalle técnico va a la consola, no a la cara del usuario: útil
      // para depurar, pero un mensaje como "Exception: ..." no le dice
      // nada a quien está editando una tarea.
      debugPrint('Error al guardar tarea: $ex');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudieron guardar los cambios. Intenta de nuevo.',
            ),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarActividad({int? padreId}) async {
    final desc = _nuevaActividadCtrl.text.trim();
    if (desc.isEmpty) return;
    _nuevaActividadCtrl.clear();
    await widget.repository.agregarActividad(
      widget.tareaId,
      desc,
      padreId: padreId,
    );
    // Sin condicionar a `mounted`: es la única forma en que el tablero
    // (`KanbanDashboardScreen`) se entera de que esta tarjeta tiene una
    // actividad nueva. Mismo motivo que `_eliminarActividad`/
    // `_eliminarTarea`/`_toggleActividad` en este mismo archivo, que ya
    // llaman `widget.onRefresh()` sin ese chequeo — si este diálogo se
    // cerró (tocar fuera, atrás) mientras el `await` de arriba seguía en
    // curso, la actividad queda genuinamente creada en el repositorio,
    // pero saltarse este aviso dejaría el conteo de checklist de la
    // tarjeta desactualizado en el tablero hasta un refresco no
    // relacionado.
    widget.onRefresh();
    // El chequeo de `mounted` sí aplica a partir de aquí: `setState`
    // sobre este diálogo (que puede ya estar `dispose()`ado) y `_cargar`
    // (que solo tiene sentido si el diálogo sigue abierto para mostrar
    // el resultado).
    if (!mounted) return;
    setState(() {
      _creandoActividad = false;
      _padreSubActividad = null;
    });
    await _cargar();
  }

  Future<void> _toggleActividad(int actividadId) async {
    await widget.repository.toggleActividad(widget.tareaId, actividadId);
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _eliminarActividad(int actividadId) async {
    // Antes era la única acción destructiva del módulo sin confirmación
    // NI deshacer — la más fácil de disparar sin querer (un solo tap en
    // el ícono de basura de la fila) y la menos protegida.
    final actividad = _buscarActividad(_tarea?.actividades ?? [], actividadId);
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar subtarea',
      mensaje: actividad == null
          ? '¿Eliminar esta subtarea?'
          : '¿Eliminar "${actividad.descripcion}"?',
    );
    if (!ok) return;
    // Igual que `_eliminarTarea`: bloquea el botón (vía `_guardando`,
    // compartido por todo el diálogo) recién después de confirmar, para
    // que un doble-tap posterior no apile un segundo `confirmarEliminar`
    // sobre una subtarea que la primera confirmación ya va a borrar.
    if (!mounted) return;
    setState(() => _guardando = true);
    try {
      await widget.repository.eliminarActividad(widget.tareaId, actividadId);
      widget.onRefresh();
      await _cargar();
      if (mounted) setState(() => _guardando = false);
    } catch (ex) {
      // Mismo criterio que `_guardar()`: el detalle técnico a la consola,
      // un aviso genérico a quien usa la app — sin este catch, un
      // doble-tap que dispara dos `confirmarEliminar` apilados sobre la
      // misma subtarea dejaba la segunda excepción (id ya eliminado) sin
      // capturar y sin ningún aviso.
      debugPrint('Error al eliminar subtarea: $ex');
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo eliminar la subtarea. Intenta de nuevo.',
            ),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _asignarResponsable(
    int actividadId, {
    int? miembroId,
    String? departamento,
  }) async {
    // Solo se piden fechas cuando de verdad se está asignando a alguien —
    // quitar el responsable (ambos `null`) no necesita preguntar nada.
    DateTime? fechaInicio;
    DateTime? fechaFin;
    if (miembroId != null || departamento != null) {
      final actual = _buscarActividad(_tarea?.actividades ?? [], actividadId);
      final fechas = await ActividadFechasDialog.show(
        context,
        inicioInicial: actual?.fechaInicio,
        finInicial: actual?.fechaFin,
      );
      if (fechas == null || !mounted) return;
      fechaInicio = fechas.inicio;
      fechaFin = fechas.fin;
    }
    await widget.repository.asignarResponsableActividad(
      widget.tareaId,
      actividadId,
      miembroId: miembroId,
      departamento: departamento,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
    );
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _eliminarTarea() async {
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar tarea',
      mensaje:
          '¿Eliminar "${_tarea!.titulo}"? Esta acción no se puede deshacer.',
    );
    if (!ok) return;
    // Recién aquí (no antes de `confirmarEliminar`): así el botón sigue
    // tocable mientras el diálogo de confirmación está abierto (para
    // poder cancelarlo), pero un doble-tap DESPUÉS de confirmar —que
    // apilaría un segundo `confirmarEliminar` sobre una tarea que la
    // primera confirmación ya va a borrar— queda bloqueado.
    if (!mounted) return;
    setState(() => _guardando = true);
    try {
      await widget.repository.eliminarTarea(widget.tareaId);
      widget.onRefresh();
      if (mounted) Navigator.of(context).pop();
    } catch (ex) {
      // Un doble-tap en el ícono de basura puede apilar dos
      // `confirmarEliminar`; al confirmar el segundo, la tarea ya no
      // existe y `eliminarTarea` puede lanzar — sin este catch, esa
      // excepción quedaba sin capturar y sin ningún aviso (a diferencia
      // de `_guardar()`, que sí atrapa sus errores).
      debugPrint('Error al eliminar tarea: $ex');
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo eliminar la tarea. Intenta de nuevo.',
            ),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
    }
  }

  String _hora(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final periodo = d.hour < 12 ? 'a. m.' : 'p. m.';
    return '${h12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $periodo';
  }

  /// Botón compacto que muestra el color actual y abre la rueda cromática
  /// para cambiarlo — reemplaza las cuadrículas de colores fijos en
  /// etiquetas/miembros/portada, que solo dejaban elegir entre lo
  /// precargado.
  Widget _botonColorRueda({required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: KanbanColors.borde),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 16, color: KanbanColors.tdim),
        ],
      ),
    );
  }

  Widget _campoBox({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: KanbanColors.borde),
          borderRadius: BorderRadius.circular(9),
        ),
        child: child,
      ),
    );
  }

  /// Etiqueta de sección flat/minimal (mayúsculas, tenue, sin negrita)
  /// compartida por los campos simples del formulario — evita repetir el
  /// mismo `Text` con estilo distinto en cada sección.
  String _formatoRelativo(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  Widget _seccionLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: KanbanColors.tdim,
        ),
      ),
    );
  }

  InputDecoration _decoracion() => kanbanInputDecoration();

  Widget _dropdownClasificacion(
    List<(String, Color)> opciones,
    int seleccionado,
    void Function(int) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: seleccionado,
            isExpanded: true,
            decoration: _decoracion().copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
            ),
            items: [
              for (var i = 0; i < opciones.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    opciones[i].$1,
                    style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => onChanged(v ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: opciones[seleccionado].$2,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _fila(
    String label,
    String valor, {
    IconData icon = Icons.person_rounded,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: KanbanColors.tdim),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: KanbanColors.texto,
            ),
          ),
          Expanded(
            child: Text(
              valor.toUpperCase(),
              style: TextStyle(fontSize: 12, color: KanbanColors.texto),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Miembro? _buscarMiembro(int id) {
    for (final m in _catalogoMiembros) {
      if (m.id == id) return m;
    }
    return null;
  }

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

  Actividad? _buscarActividad(List<Actividad> lista, int id) {
    for (final a in lista) {
      if (a.id == id) return a;
      final enHijas = _buscarActividad(a.subActividades, id);
      if (enHijas != null) return enHijas;
    }
    return null;
  }

  /// Pill que muestra el responsable actual de [a] (persona, departamento o
  /// "Asignar" si no tiene) y, al tocarla, abre el menú para elegir uno
  /// nuevo o quitarlo.
  Widget _chipResponsable(Actividad a) {
    late final String texto;
    late final Color color;
    late final IconData icono;
    if (a.miembroId != null) {
      final m = _buscarMiembro(a.miembroId!);
      texto = m?.nombre ?? 'Persona';
      color = m?.colorAvatar ?? KanbanColors.tdim;
      icono = Icons.person_rounded;
    } else if (a.departamento != null) {
      texto = a.departamento!;
      color = KanbanColors.accent;
      icono = Icons.groups_rounded;
    } else {
      texto = 'Asignar';
      color = KanbanColors.tdim;
      icono = Icons.person_add_alt_rounded;
    }
    return PopupMenuButton<String>(
      tooltip: 'Responsable de esta subtarea',
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == '_quitar') {
          _asignarResponsable(a.id);
        } else if (v == '_editar_fechas') {
          // Reasignar al mismo responsable ya activo, para que
          // `_asignarResponsable` vuelva a pedir fechas (precargadas con
          // las actuales) sin tocar quién es el responsable.
          _asignarResponsable(
            a.id,
            miembroId: a.miembroId,
            departamento: a.departamento,
          );
        } else if (v.startsWith('m:')) {
          _asignarResponsable(a.id, miembroId: int.parse(v.substring(2)));
        } else if (v.startsWith('d:')) {
          _asignarResponsable(a.id, departamento: v.substring(2));
        }
      },
      itemBuilder: (context) => [
        if (a.tieneResponsable) ...[
          const PopupMenuItem(
            value: '_editar_fechas',
            child: Text('Editar fechas', style: TextStyle(fontSize: 12.5)),
          ),
          const PopupMenuItem(
            value: '_quitar',
            child: Text('Quitar responsable', style: TextStyle(fontSize: 12.5)),
          ),
        ],
        PopupMenuItem(
          enabled: false,
          height: 28,
          child: Text(
            'PERSONA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: KanbanColors.tdim,
            ),
          ),
        ),
        for (final m in _catalogoMiembros)
          PopupMenuItem(
            value: 'm:${m.id}',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: m.colorAvatar,
                  child: Text(
                    m.nombre.isNotEmpty ? m.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(m.nombre, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          height: 28,
          child: Text(
            'DEPARTAMENTO',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: KanbanColors.tdim,
            ),
          ),
        ),
        for (final g in kGruposDemo)
          PopupMenuItem(
            value: 'd:$g',
            child: Text(g, style: const TextStyle(fontSize: 12.5)),
          ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Composer inline para agregar una actividad: en la raíz si [padreId] es
  /// `null`, o como subtarea de esa actividad si no.
  Widget _composerActividad({int? padreId}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nuevaActividadCtrl,
              autofocus: true,
              onSubmitted: (_) => _agregarActividad(padreId: padreId),
              style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
              decoration: _decoracion().copyWith(
                hintText: padreId == null
                    ? 'Descripción de la actividad…'
                    : 'Descripción de la subtarea…',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.check_circle_rounded, color: KanbanColors.ok),
            onPressed: () => _agregarActividad(padreId: padreId),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: KanbanColors.tdim, size: 18),
            onPressed: () => setState(() {
              _padreSubActividad = null;
              _creandoActividad = false;
              _nuevaActividadCtrl.clear();
            }),
          ),
        ],
      ),
    );
  }

  /// Una fila del árbol de actividades: checkbox, descripción, pill de
  /// responsable, botón para delegar una subtarea y para eliminarla —
  /// dibujada recursivamente para cualquier profundidad de delegación.
  Widget _filaActividad(Actividad a, {int profundidad = 0}) {
    final hijasVisibles = a.subActividades.where(
      (h) => !_ocultarCompletados || !h.terminada,
    );
    // Una actividad con subtareas funciona como una "lista": su estatus se
    // deriva solo de ellas (ver `_conTerminadaDerivada` en el repositorio,
    // que la recalcula en automático), así que aquí no se puede marcar a
    // mano — solo las hojas (las "tareas" reales) tienen checkbox activo.
    final esLista = a.subActividades.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(left: profundidad * 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: a.terminada,
                activeColor: KanbanColors.toolbarTeal,
                onChanged: esLista ? null : (_) => _toggleActividad(a.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.descripcion,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: esLista
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: a.terminada
                                  ? KanbanColors.tdim
                                  : KanbanColors.texto,
                              decoration: a.terminada
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (esLista) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${a.subActividades.where((h) => h.terminada).length}/${a.subActividades.length}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: KanbanColors.tdim,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (a.fechaInicio != null || a.fechaFin != null)
                      Text(
                        _rangoFechasActividad(a),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: KanbanColors.tdim,
                        ),
                      ),
                  ],
                ),
              ),
              _chipResponsable(a),
              IconButton(
                tooltip: 'Delegar subtarea',
                icon: Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: _padreSubActividad == a.id
                      ? KanbanColors.accent
                      : KanbanColors.tdim,
                ),
                onPressed: () => setState(() {
                  _creandoActividad = false;
                  _padreSubActividad = _padreSubActividad == a.id ? null : a.id;
                  _nuevaActividadCtrl.clear();
                }),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: KanbanColors.tdim,
                ),
                onPressed: _guardando ? null : () => _eliminarActividad(a.id),
              ),
            ],
          ),
          if (_padreSubActividad == a.id) _composerActividad(padreId: a.id),
          for (final hija in hijasVisibles)
            _filaActividad(hija, profundidad: profundidad + 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tarea;
    // `canPop: !_guardando` bloquea CUALQUIER forma de cerrar (la "X",
    // tocar fuera del diálogo, el botón atrás) mientras `_guardar()`
    // sigue en curso — sin esto, cerrar a la mitad del `await
    // actualizarTarea(...)` no cancelaba nada: si la escritura fallaba
    // (p. ej. la tarea se eliminó desde otra pestaña/acción mientras se
    // editaba), el `catch` mostraba el error solo `if (mounted)`, que ya
    // era `false` — el usuario se iba creyendo que guardó (o canceló)
    // cuando en realidad sus cambios se perdieron en silencio.
    return PopScope(
      canPop: !_guardando,
      child: Dialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: t == null
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: KanbanColors.bg2,
                      border: Border(
                        bottom: BorderSide(color: KanbanColors.borde),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KanbanColors.bg3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${t.id}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.tdim,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          // Editable directamente en el encabezado — antes
                          // el título aparecía dos veces (aquí de solo
                          // lectura y otra vez más abajo en un campo
                          // editable), confuso porque parecían dos datos
                          // distintos cuando eran el mismo.
                          child: TextField(
                            controller: _tituloCtrl,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Título de la tarea',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar tarea',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: KanbanColors.tdim,
                            size: 19,
                          ),
                          onPressed: _guardando ? null : _eliminarTarea,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: KanbanColors.tdim,
                            size: 20,
                          ),
                          // Deshabilitado mientras se guarda — ver el
                          // `PopScope` de más arriba: sin esto, el ícono
                          // seguía viéndose clicable aunque `canPop`
                          // bloqueara el cierre real, sin ninguna pista
                          // visual de por qué "no hacía nada".
                          onPressed: _guardando
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _guardando ? null : _iniciar,
                            icon: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 16,
                              color: KanbanColors.toolbarTeal,
                            ),
                            label: Text(
                              _labelBoton(t.estatus),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: KanbanColors.toolbarTeal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: KanbanColors.toolbarTeal),
                            ),
                          ),
                          // `fechaFinReal` no se borra al reabrir una tarea
                          // (el repositorio conserva el primer sello como
                          // historial), así que hace falta comprobar
                          // también `t.cerrada` — si no, "Reabrir" dejaba
                          // el aviso de "Terminado el…" pegado aunque la
                          // tarjeta ya hubiera vuelto a Proceso/Pausa.
                          if (t.fechaFinReal != null && t.cerrada) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: KanbanColors.ok,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Terminado el ${kanbanFecha(t.fechaFinReal)} '
                                  'a las ${_hora(t.fechaFinReal!)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: KanbanColors.ok,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _campoBox(
                                  onTap: _elegirHora,
                                  child: Text(
                                    _fechaInicio == null
                                        ? 'Hora'
                                        : _hora(_fechaInicio!),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _campoBox(
                                  onTap: () => _elegirFecha(esInicio: true),
                                  child: Text(
                                    _fechaInicio == null
                                        ? 'Fecha inicio'
                                        : kanbanFecha(_fechaInicio),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _campoBox(
                                  onTap: () => _elegirFecha(esInicio: false),
                                  child: Text(
                                    _fechaFin == null
                                        ? 'Fecha fin'
                                        : kanbanFecha(_fechaFin),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _seccionLabel('Etiquetas'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // La etiqueta del comité (`kNombreEtiquetaComite`)
                              // solo se ofrece para agregar/quitar a quien
                              // pertenece al comité — si esta tarjeta ya la
                              // tiene puesta, sigue mostrándose (de solo
                              // lectura) para cualquiera, en vez de
                              // desaparecer del todo.
                              for (final et in _catalogoEtiquetas.where(
                                (et) =>
                                    et.nombre != kNombreEtiquetaComite ||
                                    usuarioActual.value.perteneceComite ||
                                    _etiquetaIdsSeleccionadas.contains(et.id),
                              ))
                                FilterChip(
                                  label: Text(
                                    et.nombre,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                  selected: _etiquetaIdsSeleccionadas.contains(
                                    et.id,
                                  ),
                                  selectedColor: et.color.withValues(
                                    alpha: 0.3,
                                  ),
                                  backgroundColor: et.color.withValues(
                                    alpha: 0.12,
                                  ),
                                  checkmarkColor: et.color,
                                  side: BorderSide(color: et.color),
                                  onSelected:
                                      (et.nombre == kNombreEtiquetaComite &&
                                          !usuarioActual.value.perteneceComite)
                                      ? null
                                      : (_) => _toggleEtiqueta(et.id),
                                ),
                              ActionChip(
                                avatar: Icon(
                                  Icons.add_rounded,
                                  size: 15,
                                  color: KanbanColors.texto,
                                ),
                                label: Text(
                                  'Nueva',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: KanbanColors.texto,
                                  ),
                                ),
                                backgroundColor: KanbanColors.bg3,
                                side: BorderSide(color: KanbanColors.borde),
                                onPressed: () => setState(() {
                                  _creandoEtiqueta = !_creandoEtiqueta;
                                  // Al cerrar el composer sin confirmar
                                  // (este chip es un toggle, no un botón
                                  // "Cancelar" aparte), limpia el texto a
                                  // medio escribir — sin esto, la próxima
                                  // vez que se abriera "Nueva" aparecía
                                  // con el borrador anterior todavía ahí.
                                  if (!_creandoEtiqueta) {
                                    _nuevaEtiquetaCtrl.clear();
                                  }
                                }),
                              ),
                            ],
                          ),
                          if (_creandoEtiqueta) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nuevaEtiquetaCtrl,
                                    autofocus: true,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: KanbanColors.texto,
                                    ),
                                    decoration: _decoracion().copyWith(
                                      hintText: 'Nombre de la etiqueta…',
                                    ),
                                    onSubmitted: (_) => _crearEtiqueta(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: KanbanColors.ok,
                                  ),
                                  onPressed: _crearEtiqueta,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _botonColorRueda(
                              color: _colorNuevaEtiqueta,
                              onTap: () async {
                                final elegido = await showColorWheelDialog(
                                  context,
                                  initial: _colorNuevaEtiqueta,
                                  titulo: 'Color de la etiqueta',
                                );
                                if (elegido != null && mounted) {
                                  setState(() => _colorNuevaEtiqueta = elegido);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          _seccionLabel('Portada'),
                          _botonColorRueda(
                            color: _portada ?? KanbanColors.bg3,
                            onTap: () async {
                              final elegido = await showColorWheelDialog(
                                context,
                                initial: _portada ?? KanbanColors.accent,
                                titulo: 'Color de portada',
                                onQuitarColor: _portada == null
                                    ? null
                                    : () => setState(() => _portada = null),
                              );
                              if (elegido != null && mounted) {
                                setState(() => _portada = elegido);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _seccionLabel('Área'),
                          DropdownButtonFormField<String>(
                            initialValue: _area,
                            isExpanded: true,
                            decoration: _decoracion().copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                            ),
                            items: [
                              for (final g in kGruposDemo)
                                DropdownMenuItem(
                                  value: g,
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _area = v),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Generales'),
                          _dropdownClasificacion(
                            kGeneralesDemo,
                            _generalesIdx,
                            (i) => setState(() => _generalesIdx = i),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Nivel'),
                          _dropdownClasificacion(
                            kNivelDemo,
                            _nivelIdx,
                            (i) => setState(() => _nivelIdx = i),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Importancia'),
                          _dropdownClasificacion(
                            kImportanciaDemo,
                            _importanciaIdx,
                            (i) => setState(() => _importanciaIdx = i),
                          ),
                          const SizedBox(height: 16),
                          _seccionLabel('Descripción'),
                          TextField(
                            controller: _descripcionCtrl,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KanbanColors.texto,
                            ),
                            decoration: _decoracion().copyWith(
                              contentPadding: const EdgeInsets.all(10),
                              filled: true,
                              fillColor: KanbanColors.bg3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _fila(
                            'Asignado por:',
                            t.asignadoPor.isEmpty
                                ? 'Sin definir'
                                : t.asignadoPor,
                            icon: Icons.account_tree_rounded,
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Miembros'),
                          // Botón compacto en vez de chips siempre visibles
                          // para todo el catálogo: con varios miembros en el
                          // tablero, la fila de chips se volvía larga y
                          // ocupaba espacio aunque casi nunca se tocara.
                          _campoBox(
                            onTap: () => _mostrarSelectorMiembros(context),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _miembroIdsSeleccionados.isEmpty
                                        ? 'Sin miembros asignados'
                                        : _catalogoMiembros
                                              .where(
                                                (m) => _miembroIdsSeleccionados
                                                    .contains(m.id),
                                              )
                                              .map((m) => m.nombre)
                                              .join(', '),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _miembroIdsSeleccionados.isEmpty
                                          ? KanbanColors.tdim
                                          : KanbanColors.texto,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 18,
                                  color: KanbanColors.tdim,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(color: KanbanColors.borde),
                          const SizedBox(height: 4),
                          if (t.actividades.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 16,
                                    color: KanbanColors.bg3,
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: t.progreso,
                                    child: Container(
                                      height: 16,
                                      color: KanbanColors.toolbarTeal,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        '${(t.progreso * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: KanbanColors.texto,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ACTIVIDADES (${t.actividadesTerminadas}/${t.actividadesTotales})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: KanbanColors.texto,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(
                                  () => _ocultarCompletados =
                                      !_ocultarCompletados,
                                ),
                                child: Text(
                                  _ocultarCompletados
                                      ? 'Mostrar completados'
                                      : 'Ocultar completados',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: KanbanColors.texto,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          for (final a in t.actividades.where(
                            (a) => !_ocultarCompletados || !a.terminada,
                          ))
                            _filaActividad(a),
                          const SizedBox(height: 6),
                          if (_creandoActividad)
                            _composerActividad()
                          else
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _creandoActividad = true;
                                // Si había un composer de SUBTAREA abierto
                                // (`_padreSubActividad` apuntando a otra
                                // actividad), este botón lo cierra
                                // implícitamente al abrir el de nivel
                                // raíz — sin limpiar el controller aquí,
                                // el texto que se hubiera escrito para
                                // esa subtarea seguía ahí y podía
                                // terminar creado como actividad de nivel
                                // raíz sin que el usuario lo notara.
                                _padreSubActividad = null;
                                _nuevaActividadCtrl.clear();
                              }),
                              icon: Icon(
                                Icons.add_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              label: Text(
                                'Crear actividad',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KanbanColors.texto,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Divider(color: KanbanColors.borde),
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              iconColor: KanbanColors.tdim,
                              collapsedIconColor: KanbanColors.tdim,
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 15,
                                    color: KanbanColors.texto,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'HISTORIAL (${t.historial.length})',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: KanbanColors.texto,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                if (t.historial.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'Todavía no hay actividad registrada.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: KanbanColors.tdim,
                                      ),
                                    ),
                                  )
                                else
                                  for (final ev in t.historial.reversed)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 3,
                                            ),
                                            child: Icon(
                                              Icons.circle,
                                              size: 5,
                                              color: KanbanColors.tdim,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ev.mensaje,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: KanbanColors.texto,
                                                  ),
                                                ),
                                                Text(
                                                  '${ev.autor} · ${_formatoRelativo(ev.fecha)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: KanbanColors.borde),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'GUARDAR',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: KanbanColors.toolbarGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}
