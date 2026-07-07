import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';
import '../../data/bitacora_repository.dart';
import '../../domain/entities/pieza.dart';
import 'bitacora_form_pieces.dart';

/// Diálogo para crear o editar una [Pieza] dentro de una bitácora.
///
/// Replica el formulario de `agregar_pieza.py` (PiezaForm): datos de
/// identificación con autocompletado de código/descripción, condiciones de
/// horno, y mediciones opcionales por superficie (paneles expandibles con
/// una matriz de kFilas x kCols).
class PiezaFormDialog extends StatefulWidget {
  final BitacoraRepository repository;
  final Pieza? pieza; // null => nueva pieza
  final int bitacoraId;

  const PiezaFormDialog({
    super.key,
    required this.repository,
    required this.bitacoraId,
    this.pieza,
  });

  @override
  State<PiezaFormDialog> createState() => _PiezaFormDialogState();

  /// Abre el diálogo y devuelve `true` si se guardó algo.
  static Future<bool?> show(
    BuildContext context, {
    required BitacoraRepository repository,
    required int bitacoraId,
    Pieza? pieza,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PiezaFormDialog(
        repository: repository,
        bitacoraId: bitacoraId,
        pieza: pieza,
      ),
    );
  }
}

class _PiezaFormDialogState extends State<PiezaFormDialog> {
  late final bool _esEdicion = widget.pieza != null;
  bool _guardando = false;

  final _jobCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _codCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late final Map<String, TextEditingController> _horno = {
    'temp': TextEditingController(),
    'vel': TextEditingController(),
    'hrn': TextEditingController(),
    'dur': TextEditingController(),
    'bri': TextEditingController(),
    'cuad': TextEditingController(),
    'cur': TextEditingController(),
    'col': TextEditingController(),
    'cab': TextEditingController(),
    'ps_pin': TextEditingController(),
    'pc_pin': TextEditingController(),
    'pza_ok': TextEditingController(),
  };

  // superficie -> (fila, col) -> controller
  final Map<String, Map<int, Map<int, TextEditingController>>> _sup = {};
  final Set<String> _supExpandida = {};

  List<String> _sugerencias = [];

  @override
  void initState() {
    super.initState();
    final p = widget.pieza;
    if (p != null) {
      _jobCtrl.text = p.job;
      _loteCtrl.text = p.nLote;
      _codCtrl.text = p.codigo;
      _descCtrl.text = p.descripcion;
      _horno['temp']!.text = p.temp;
      _horno['vel']!.text = p.vel;
      _horno['hrn']!.text = p.hrn;
      _horno['dur']!.text = p.dur;
      _horno['bri']!.text = p.bri;
      _horno['cuad']!.text = p.cuad;
      _horno['cur']!.text = p.cur;
      _horno['col']!.text = p.col;
      _horno['cab']!.text = p.cab;
      _horno['ps_pin']!.text = p.psPin;
      _horno['pc_pin']!.text = p.pcPin;
      _horno['pza_ok']!.text = p.pzaOk;
    }

    for (final sup in kSuperficies) {
      final existente = p?.superficies[sup];
      if (existente != null) _supExpandida.add(sup);
      final filas = <int, Map<int, TextEditingController>>{};
      for (var f = 0; f < kFilas; f++) {
        final cols = <int, TextEditingController>{};
        for (var c = 0; c < kCols; c++) {
          String val = '';
          if (existente != null && f < existente.length && c < existente[f].length) {
            val = existente[f][c];
          }
          cols[c] = TextEditingController(text: val);
        }
        filas[f] = cols;
      }
      _sup[sup] = filas;
    }
  }

  @override
  void dispose() {
    _jobCtrl.dispose();
    _loteCtrl.dispose();
    _codCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _horno.values) {
      c.dispose();
    }
    for (final filas in _sup.values) {
      for (final cols in filas.values) {
        for (final c in cols.values) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  Future<void> _onInputChange() async {
    final cod = _codCtrl.text;
    final job = _jobCtrl.text;
    if (cod.length >= 2 || job.length >= 2) {
      final sugs = await widget.repository.buscarCodigos(cod, job);
      if (mounted) setState(() => _sugerencias = sugs);
    } else if (_sugerencias.isNotEmpty) {
      setState(() => _sugerencias = []);
    }
    await _fillDescripcion();
  }

  Future<void> _fillDescripcion() async {
    final job = _jobCtrl.text;
    final cod = _codCtrl.text;
    if (job.trim().isNotEmpty && cod.trim().isNotEmpty) {
      final desc = await widget.repository.buscarDescripcion(job, cod);
      if (mounted) {
        setState(() => _descCtrl.text = desc.isEmpty ? 'Sin descripción' : desc);
      }
    } else if (mounted) {
      setState(() => _descCtrl.text = '');
    }
  }

  void _pickSugerencia(String val) {
    _codCtrl.text = val;
    setState(() => _sugerencias = []);
    _fillDescripcion();
  }

  Map<String, List<List<String>>> _extraerSuperficies() {
    final result = <String, List<List<String>>>{};
    for (final sup in kSuperficies) {
      final filas = _sup[sup]!;
      final matriz = List.generate(
        kFilas,
        (f) => List.generate(kCols, (c) => filas[f]![c]!.text),
      );
      final tieneDatos = matriz.any((fila) => fila.any((v) => v.trim().isNotEmpty));
      if (tieneDatos) result[sup] = matriz;
    }
    return result;
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final pieza = Pieza(
        id: widget.pieza?.id,
        fecha: DateTime.now(),
        codigo: _codCtrl.text,
        descripcion: _descCtrl.text,
        job: _jobCtrl.text,
        nLote: _loteCtrl.text,
        temp: _horno['temp']!.text,
        vel: _horno['vel']!.text,
        hrn: _horno['hrn']!.text,
        dur: _horno['dur']!.text,
        bri: _horno['bri']!.text,
        cuad: _horno['cuad']!.text,
        cur: _horno['cur']!.text,
        col: _horno['col']!.text,
        cab: _horno['cab']!.text,
        psPin: _horno['ps_pin']!.text,
        pcPin: _horno['pc_pin']!.text,
        pzaOk: _horno['pza_ok']!.text,
        superficies: _extraerSuperficies(),
      );

      if (_esEdicion) {
        await widget.repository.actualizarPieza(widget.pieza!.id!, pieza);
      } else {
        await widget.repository.agregarPieza(widget.bitacoraId, pieza);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $ex'), backgroundColor: BitacoraColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _hornoRow(List<String> keys, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: BitacoraField(
                label: labels[i],
                controller: _horno[keys[i]]!,
                upperCase: keys[i] != 'temp' && keys[i] != 'vel' && keys[i] != 'bri' && keys[i] != 'pza_ok',
                keyboardType: (keys[i] == 'temp' || keys[i] == 'vel' || keys[i] == 'bri' || keys[i] == 'pza_ok')
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _superficieTile(String sup) {
    final filas = _sup[sup]!;
    final expandida = _supExpandida.contains(sup);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: BitacoraColors.borde),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expandida,
          iconColor: BitacoraColors.accent,
          collapsedIconColor: BitacoraColors.tdim,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sup, style: const TextStyle(fontSize: 12, color: BitacoraColors.texto)),
              if (expandida) ...[
                const SizedBox(width: 6),
                const BitacoraBadge(text: '✓', color: BitacoraColors.ok),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (var f = 0; f < kFilas; f++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          for (var c = 0; c < kCols; c++) ...[
                            if (c > 0) const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: filas[f]![c]!,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: BitacoraColors.bg3,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide:
                                        const BorderSide(color: BitacoraColors.borde),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width < 600 ? width * 0.94 : 520.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: BitacoraColors.accentLight,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(_esEdicion ? Icons.edit_rounded : Icons.add_box_rounded,
                      color: BitacoraColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _esEdicion
                          ? 'Editar pieza #${widget.pieza!.id}'
                          : 'Nueva pieza — Bitácora #${widget.bitacoraId.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: BitacoraColors.accent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: BitacoraColors.tdim, size: 18),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: BitacoraField(label: 'Job', controller: _jobCtrl, upperCase: true, onChanged: (_) => _onInputChange())),
                      const SizedBox(width: 8),
                      Expanded(child: BitacoraField(label: 'N° Lote', controller: _loteCtrl, upperCase: true)),
                    ]),
                    const SizedBox(height: 8),
                    BitacoraField(
                        label: 'Código / Part Number',
                        controller: _codCtrl,
                        upperCase: true,
                        onChanged: (_) => _onInputChange()),
                    if (_sugerencias.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: BitacoraColors.bg2,
                          border: Border.all(
                              color: BitacoraColors.accent.withValues(alpha: 0.33)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final s in _sugerencias)
                              ListTile(
                                dense: true,
                                title: Text(s, style: const TextStyle(fontSize: 13)),
                                onTap: () => _pickSugerencia(s),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    BitacoraField(label: 'Descripción', controller: _descCtrl, readOnly: true),
                    const SizedBox(height: 12),
                    const BitacoraSectionLabel(text: 'Condiciones del horno', icon: '🌡️'),
                    const SizedBox(height: 8),
                    _hornoRow(['temp', 'vel', 'hrn'], ['Temp', 'Vel', 'Hrn']),
                    _hornoRow(['dur', 'bri', 'cuad'], ['Dur', 'Bri', 'Cuad']),
                    _hornoRow(['cur', 'col', 'cab'], ['Cur', 'Col', 'Cab']),
                    _hornoRow(['ps_pin', 'pc_pin', 'pza_ok'], ['P S/Pin', 'P C/Pin', 'Pza OK']),
                    const SizedBox(height: 8),
                    const BitacoraSectionLabel(text: 'Superficies (opcional)', icon: '📐'),
                    const SizedBox(height: 8),
                    for (final sup in kSuperficies) _superficieTile(sup),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BitacoraColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_esEdicion ? '💾  Guardar cambios' : '💾  Agregar pieza'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
