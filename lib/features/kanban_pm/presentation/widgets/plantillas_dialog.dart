import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea_etiqueta.dart';
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
  List<TareaEtiqueta> _etiquetas = [];
  List<Miembro> _miembros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final resultados = await Future.wait([
      widget.repository.listarPlantillas(),
      widget.repository.listarEtiquetas(),
      widget.repository.listarMiembros(),
    ]);
    if (!mounted) return;
    setState(() {
      _plantillas = resultados[0] as List<TareaPlantilla>;
      _etiquetas = resultados[1] as List<TareaEtiqueta>;
      _miembros = resultados[2] as List<Miembro>;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({TareaPlantilla? existente}) async {
    final resultado = await _PlantillaFormDialog.show(
      context,
      existente: existente,
      etiquetas: _etiquetas,
      miembros: _miembros,
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
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Eliminar plantilla',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: Text(
          '¿Eliminar la plantilla "${p.nombre}"?',
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
    await widget.repository.eliminarPlantilla(p.id);
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
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
                        'prioridad, área, etiquetas, miembros y checklist al dar '
                        'de alta tarjetas.',
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
    final etiquetasPlantilla = p.etiquetaIds
        .map((id) => _etiquetas.where((e) => e.id == id))
        .where((it) => it.isNotEmpty)
        .map((it) => it.first)
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: KanbanColors.cardDecoration(radius: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.portada != null)
            Container(
              width: 6,
              height: 40,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: p.portada,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
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
                    if (p.miembroIds.isNotEmpty)
                      '${p.miembroIds.length} ${p.miembroIds.length == 1 ? 'miembro' : 'miembros'}',
                    if (p.actividades.isNotEmpty)
                      '${p.actividades.length} pendientes en checklist',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
                ),
                if (etiquetasPlantilla.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final et in etiquetasPlantilla)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: et.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            et.nombre,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: KanbanColors.tdim,
            ),
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
  final List<TareaEtiqueta> etiquetas;
  final List<Miembro> miembros;

  const _PlantillaFormDialog({
    this.existente,
    required this.etiquetas,
    required this.miembros,
  });

  static Future<TareaPlantilla?> show(
    BuildContext context, {
    TareaPlantilla? existente,
    required List<TareaEtiqueta> etiquetas,
    required List<Miembro> miembros,
  }) {
    return showDialog<TareaPlantilla>(
      context: context,
      builder: (_) => _PlantillaFormDialog(
        existente: existente,
        etiquetas: etiquetas,
        miembros: miembros,
      ),
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
  late final Set<int> _etiquetaIdsSeleccionadas = {
    ...?widget.existente?.etiquetaIds,
  };
  late final Set<int> _miembroIdsSeleccionados = {
    ...?widget.existente?.miembroIds,
  };
  Color? _portada;

  @override
  void initState() {
    super.initState();
    final grupoExistente = widget.existente?.grupo;
    _grupo = (grupoExistente != null && grupoExistente.isNotEmpty)
        ? grupoExistente
        : null;
    _portada = widget.existente?.portada;
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
        etiquetaIds: _etiquetaIdsSeleccionadas.toList(),
        miembroIds: _miembroIdsSeleccionados.toList(),
        portada: _portada,
      ),
    );
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      isDense: true,
      filled: true,
      fillColor: KanbanColors.bg3,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existente == null
                      ? 'Nueva plantilla'
                      : 'Editar plantilla',
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
                              child: Text(
                                g,
                                style: const TextStyle(fontSize: 13),
                              ),
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
                        onChanged: (v) => setState(
                          () => _prioridad = v ?? TareaPrioridad.media,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _seccionLabel('Etiquetas sugeridas'),
                if (widget.etiquetas.isEmpty)
                  Text(
                    'Aún no hay etiquetas en el tablero.',
                    style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final et in widget.etiquetas)
                        FilterChip(
                          label: Text(
                            et.nombre,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: KanbanColors.texto,
                            ),
                          ),
                          selected: _etiquetaIdsSeleccionadas.contains(et.id),
                          backgroundColor: KanbanColors.bg3,
                          selectedColor: et.color.withValues(alpha: 0.3),
                          side: BorderSide(color: et.color),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _etiquetaIdsSeleccionadas.add(et.id);
                            } else {
                              _etiquetaIdsSeleccionadas.remove(et.id);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                _seccionLabel('Miembros sugeridos'),
                if (widget.miembros.isEmpty)
                  Text(
                    'Aún no hay integrantes en el tablero.',
                    style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in widget.miembros)
                        FilterChip(
                          avatar: CircleAvatar(
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
                          label: Text(
                            m.nombre,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: KanbanColors.texto,
                            ),
                          ),
                          selected: _miembroIdsSeleccionados.contains(m.id),
                          backgroundColor: KanbanColors.bg3,
                          selectedColor: m.colorAvatar.withValues(alpha: 0.3),
                          side: BorderSide(color: KanbanColors.borde),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _miembroIdsSeleccionados.add(m.id);
                            } else {
                              _miembroIdsSeleccionados.remove(m.id);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                _seccionLabel('Color de portada'),
                Wrap(
                  spacing: 6,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _portada = null),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: KanbanColors.bg3,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _portada == null
                                ? KanbanColors.texto
                                : KanbanColors.borde,
                            width: _portada == null ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: KanbanColors.tdim,
                        ),
                      ),
                    ),
                    for (final c in kColorPaletteEtiquetas)
                      InkWell(
                        onTap: () => setState(() => _portada = c),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: _portada == c
                                ? Border.all(
                                    color: KanbanColors.texto,
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _seccionLabel('Checklist'),
                TextField(
                  controller: _actividadesCtrl,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                  decoration: _decoracion('Un punto por línea'),
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
