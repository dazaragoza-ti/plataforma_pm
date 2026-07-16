import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/tarea_etiqueta.dart';

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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final etiquetas = await widget.repository.listarEtiquetas();
    if (!mounted) return;
    setState(() {
      _etiquetas = etiquetas;
      _cargando = false;
    });
  }

  Future<void> _crear() async {
    final resultado = await _EtiquetaFormDialog.show(context);
    if (resultado == null) return;
    await widget.repository.crearEtiqueta(resultado.$1, resultado.$2);
    await _cargar();
  }

  Future<void> _editar(TareaEtiqueta existente) async {
    final resultado = await _EtiquetaFormDialog.show(
      context,
      nombreInicial: existente.nombre,
      colorInicial: existente.color,
    );
    if (resultado == null) return;
    await widget.repository.actualizarEtiqueta(
      existente.copyWith(nombre: resultado.$1, color: resultado.$2),
    );
    await _cargar();
  }

  Future<void> _eliminar(TareaEtiqueta e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Eliminar etiqueta',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: Text(
          '¿Eliminar la etiqueta "${e.nombre}"? Se quitará de todas las '
          'tarjetas que la usen.',
          style: TextStyle(color: KanbanColors.texto),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.eliminarEtiqueta(e.id);
    await _cargar();
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
                  : _etiquetas.isEmpty
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
                      itemCount: _etiquetas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _tile(_etiquetas[i]),
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
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                  isDense: true,
                  filled: true,
                  fillColor: KanbanColors.bg3,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: KanbanColors.borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: KanbanColors.borde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: KanbanColors.accent,
                      width: 2,
                    ),
                  ),
                ),
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in kColorPaletteEtiquetas)
                    InkWell(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _color == c
                              ? Border.all(color: KanbanColors.texto, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
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
