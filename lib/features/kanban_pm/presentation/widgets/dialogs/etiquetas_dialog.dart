import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../data/kanban_repository.dart';
import '../../../data/usuario_directorio.dart';
import '../../../domain/entities/tarea_etiqueta.dart';
import '../common/color_wheel_picker.dart';
import 'confirmar_eliminar_dialog.dart';

/// Gestor de etiquetas del tablero: renombrar/recolorear o eliminar una
/// existente, o crear una nueva — todo desde un solo lugar en vez de solo
/// poder crearlas al vuelo desde el detalle de una tarjeta.
class EtiquetasDialog extends StatefulWidget {
  final KanbanRepository repository;

  const EtiquetasDialog({super.key, required this.repository});

  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
  }) {
    return showDialog(
      context: context,
      builder: (_) => EtiquetasDialog(repository: repository),
    );
  }

  @override
  State<EtiquetasDialog> createState() => _EtiquetasDialogState();
}

class _EtiquetasDialogState extends State<EtiquetasDialog> {
  List<TareaEtiqueta> _etiquetas = [];
  bool _cargando = true;

  /// Oculta la etiqueta del comité (ver `kNombreEtiquetaComite`) a quien no
  /// pertenece al comité — administrar ese catálogo (renombrar/recolorear/
  /// eliminar) queda reservado a quien sí pertenece, igual que aplicarla a
  /// una tarjeta desde el detalle.
  List<TareaEtiqueta> get _etiquetasVisibles => usuarioActual.value.perteneceComite
      ? _etiquetas
      : _etiquetas.where((e) => e.nombre != kNombreEtiquetaComite).toList();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _error(Object ex) {
    if (!mounted) return;
    kanbanToast(context, 'Error: $ex', ok: false);
  }

  Future<void> _cargar() async {
    try {
      final etiquetas = await widget.repository.listarEtiquetas();
      if (!mounted) return;
      setState(() {
        _etiquetas = etiquetas;
        _cargando = false;
      });
    } catch (ex) {
      if (mounted) setState(() => _cargando = false);
      _error(ex);
    }
  }

  Future<void> _crear() async {
    final resultado = await _EtiquetaFormDialog.show(context);
    if (resultado == null) return;
    try {
      await widget.repository.crearEtiqueta(resultado.$1, resultado.$2);
      await _cargar();
    } catch (ex) {
      _error(ex);
    }
  }

  Future<void> _editar(TareaEtiqueta existente) async {
    final resultado = await _EtiquetaFormDialog.show(
      context,
      nombreInicial: existente.nombre,
      colorInicial: existente.color,
    );
    if (resultado == null) return;
    try {
      await widget.repository.actualizarEtiqueta(
        existente.copyWith(nombre: resultado.$1, color: resultado.$2),
      );
      await _cargar();
    } catch (ex) {
      _error(ex);
    }
  }

  Future<void> _eliminar(TareaEtiqueta e) async {
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar etiqueta',
      mensaje:
          '¿Eliminar la etiqueta "${e.nombre}"? Se quitará de todas las '
          'tarjetas que la usen.',
    );
    if (!ok) return;
    try {
      await widget.repository.eliminarEtiqueta(e.id);
      await _cargar();
      if (!mounted) return;
      // Mismo patrón "Deshacer" que ya usan archivar/eliminar tarjeta —
      // antes eliminar una etiqueta era de las pocas acciones destructivas
      // del módulo sin ninguna forma de revertirla. Igual que esas, es una
      // recreación (id nuevo): no vuelve a aparecer sola en las tarjetas
      // que ya la habían perdido.
      kanbanToastAccion(context, 'Etiqueta eliminada', 'Deshacer', () async {
        await widget.repository.crearEtiqueta(e.nombre, e.color);
        await _cargar();
      });
    } catch (ex) {
      _error(ex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: KanbanColors.bg2,
                border: Border(bottom: BorderSide(color: KanbanColors.borde)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Etiquetas del tablero',
                      style: TextStyle(
                        fontSize: 15,
                        color: KanbanColors.texto,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: KanbanColors.tdim,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _cargando
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _etiquetasVisibles.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Aún no hay etiquetas. Crea una para clasificar '
                        'tarjetas por color.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: KanbanColors.tdim,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _etiquetasVisibles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _tile(_etiquetasVisibles[i]),
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: KanbanColors.borde)),
              ),
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _crear,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Nueva etiqueta'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: KanbanColors.borde),
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
    );
  }

  Widget _tile(TareaEtiqueta e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: KanbanColors.cardDecoration(radius: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: e.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              e.nombre,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Editar etiqueta',
            icon: Icon(Icons.edit_outlined, size: 18, color: KanbanColors.tdim),
            onPressed: () => _editar(e),
          ),
          IconButton(
            tooltip: 'Eliminar etiqueta',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: KanbanColors.tdim,
            ),
            onPressed: () => _eliminar(e),
          ),
        ],
      ),
    );
  }
}

/// Formulario mínimo (nombre + color) para crear/editar una etiqueta.
/// Devuelve `(nombre, color)` o `null` si se canceló.
class _EtiquetaFormDialog extends StatefulWidget {
  final String? nombreInicial;
  final Color? colorInicial;

  const _EtiquetaFormDialog({this.nombreInicial, this.colorInicial});

  static Future<(String, Color)?> show(
    BuildContext context, {
    String? nombreInicial,
    Color? colorInicial,
  }) {
    return showDialog<(String, Color)>(
      context: context,
      builder: (_) => _EtiquetaFormDialog(
        nombreInicial: nombreInicial,
        colorInicial: colorInicial,
      ),
    );
  }

  @override
  State<_EtiquetaFormDialog> createState() => _EtiquetaFormDialogState();
}

class _EtiquetaFormDialogState extends State<_EtiquetaFormDialog> {
  late final _nombreCtrl = TextEditingController(
    text: widget.nombreInicial ?? '',
  );
  late Color _color = widget.colorInicial ?? kColorPaletteEtiquetas.first;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    Navigator.of(context).pop((nombre, _color));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.nombreInicial == null
                    ? 'Nueva etiqueta'
                    : 'Editar etiqueta',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: KanbanColors.texto,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreCtrl,
                autofocus: true,
                onSubmitted: (_) => _guardar(),
                style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                decoration: kanbanInputDecoration(label: 'Nombre'),
              ),
              const SizedBox(height: 14),
              Text(
                'COLOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: KanbanColors.tdim,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: ColorWheelPicker(
                  initialColor: _color,
                  size: 170,
                  onColorChanged: (c) => setState(() => _color = c),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: KanbanColors.borde),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KanbanColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
