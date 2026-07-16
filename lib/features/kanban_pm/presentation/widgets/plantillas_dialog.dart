import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/tarea_plantilla.dart';

/// Diálogo de plantillas: lista las existentes (crear tarjeta / editar /
/// eliminar) y permite crear nuevas. Al elegir "Usar" se cierra devolviendo
/// la plantilla elegida, para que quien lo abrió arranque `NuevaTareaDialog`
/// precargado con ella.
class PlantillasDialog extends StatefulWidget {
  final KanbanRepository repository;

  const PlantillasDialog({super.key, required this.repository});

  static Future<TareaPlantilla?> show(
    BuildContext context, {
    required KanbanRepository repository,
  }) {
    return showDialog<TareaPlantilla>(
      context: context,
      builder: (_) => PlantillasDialog(repository: repository),
    );
  }

  @override
  State<PlantillasDialog> createState() => _PlantillasDialogState();
}

class _PlantillasDialogState extends State<PlantillasDialog> {
  List<TareaPlantilla> _plantillas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final plantillas = await widget.repository.listarPlantillas();
    if (!mounted) return;
    setState(() {
      _plantillas = plantillas;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({TareaPlantilla? existente}) async {
    final resultado = await _PlantillaFormDialog.show(
      context,
      existente: existente,
    );
    if (resultado == null) return;
    if (existente == null) {
      await widget.repository.crearPlantilla(resultado);
    } else {
      await widget.repository.actualizarPlantilla(resultado);
    }
    await _cargar();
  }

  Future<void> _eliminar(TareaPlantilla p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Eliminar la plantilla "${p.nombre}"?'),
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
    await widget.repository.eliminarPlantilla(p.id);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
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
                      'Plantillas de tarjeta',
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
                  : _plantillas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Aún no hay plantillas. Crea una para reutilizar título, '
                        'prioridad, área y checklist al dar de alta tarjetas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _plantillas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _tile(_plantillas[i]),
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
                  onPressed: () => _crearOEditar(),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Nueva plantilla'),
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

  Widget _tile(TareaPlantilla p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: KanbanColors.cardDecoration(radius: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: KanbanColors.texto,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (p.grupo.isNotEmpty) p.grupo,
                    p.prioridad.etiqueta,
                    if (p.actividades.isNotEmpty)
                      '${p.actividades.length} pendientes en checklist',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar plantilla',
            icon: Icon(Icons.edit_outlined, size: 18, color: KanbanColors.tdim),
            onPressed: () => _crearOEditar(existente: p),
          ),
          IconButton(
            tooltip: 'Eliminar plantilla',
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: KanbanColors.tdim),
            onPressed: () => _eliminar(p),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(p),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: KanbanColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Usar', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Formulario para crear/editar una plantilla. Devuelve la [TareaPlantilla]
/// resultante (con `id: 0` si es nueva; el repositorio le asigna el real).
class _PlantillaFormDialog extends StatefulWidget {
  final TareaPlantilla? existente;

  const _PlantillaFormDialog({this.existente});

  static Future<TareaPlantilla?> show(
    BuildContext context, {
    TareaPlantilla? existente,
  }) {
    return showDialog<TareaPlantilla>(
      context: context,
      builder: (_) => _PlantillaFormDialog(existente: existente),
    );
  }

  @override
  State<_PlantillaFormDialog> createState() => _PlantillaFormDialogState();
}

class _PlantillaFormDialogState extends State<_PlantillaFormDialog> {
  late final _nombreCtrl = TextEditingController(
    text: widget.existente?.nombre ?? '',
  );
  late final _tituloCtrl = TextEditingController(
    text: widget.existente?.tituloSugerido ?? '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.existente?.descripcion ?? '',
  );
  late final _actividadesCtrl = TextEditingController(
    text: (widget.existente?.actividades ?? const []).join('\n'),
  );
  String? _grupo;
  late TareaPrioridad _prioridad =
      widget.existente?.prioridad ?? TareaPrioridad.media;

  @override
  void initState() {
    super.initState();
    final grupoExistente = widget.existente?.grupo;
    _grupo = (grupoExistente != null && grupoExistente.isNotEmpty)
        ? grupoExistente
        : null;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _actividadesCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    final actividades = _actividadesCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      TareaPlantilla(
        id: widget.existente?.id ?? 0,
        nombre: nombre,
        tituloSugerido: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        prioridad: _prioridad,
        grupo: _grupo ?? '',
        actividades: actividades,
      ),
    );
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: BorderSide(color: KanbanColors.accent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existente == null ? 'Nueva plantilla' : 'Editar plantilla',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: KanbanColors.texto,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreCtrl,
                  style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                  decoration: _decoracion('Nombre de la plantilla'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tituloCtrl,
                  style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                  decoration: _decoracion('Título sugerido'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descripcionCtrl,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                  decoration: _decoracion('Descripción sugerida'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _grupo,
                        decoration: _decoracion('Área'),
                        items: [
                          for (final g in kGruposDemo)
                            DropdownMenuItem(
                              value: g,
                              child: Text(g, style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (v) => setState(() => _grupo = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<TareaPrioridad>(
                        initialValue: _prioridad,
                        decoration: _decoracion('Prioridad'),
                        items: [
                          for (final p in TareaPrioridad.values)
                            DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.etiqueta,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _prioridad = v ?? TareaPrioridad.media),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _actividadesCtrl,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                  decoration: _decoracion('Checklist (un punto por línea)'),
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
      ),
    );
  }
}
