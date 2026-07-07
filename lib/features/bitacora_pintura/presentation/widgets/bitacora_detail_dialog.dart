import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';
import '../../data/bitacora_repository.dart';
import '../../domain/entities/bitacora.dart';
import '../../domain/entities/pieza.dart';
import 'bitacora_form_pieces.dart';
import 'pieza_form_dialog.dart';

/// Diálogo con el detalle completo de una bitácora: datos generales
/// (elaboró + pintores) y la lista de piezas capturadas, con alta/edición/
/// borrado de cada una. Equivale a `bitacora_dlg.py` (BitacoraDlg).
class BitacoraDetailDialog extends StatefulWidget {
  final BitacoraRepository repository;
  final int bitacoraId;
  final VoidCallback? onRefresh;

  const BitacoraDetailDialog({
    super.key,
    required this.repository,
    required this.bitacoraId,
    this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required BitacoraRepository repository,
    required int bitacoraId,
    VoidCallback? onRefresh,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BitacoraDetailDialog(
        repository: repository,
        bitacoraId: bitacoraId,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<BitacoraDetailDialog> createState() => _BitacoraDetailDialogState();
}

class _BitacoraDetailDialogState extends State<BitacoraDetailDialog> {
  Bitacora? _bitacora;
  bool _cargando = true;
  bool _guardandoGeneral = false;

  final _elaboroCtrl = TextEditingController();
  final Map<String, bool> _pintoresSel = {for (final p in kPintores) p: false};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _elaboroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final b = await widget.repository.obtenerBitacora(widget.bitacoraId);
    if (!mounted) return;
    setState(() {
      _bitacora = b;
      _cargando = false;
      _elaboroCtrl.text = b?.elaboro ?? '';
      for (final p in kPintores) {
        _pintoresSel[p] = b?.pintores.contains(p) ?? false;
      }
    });
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? BitacoraColors.ok : BitacoraColors.danger,
    ));
  }

  Future<void> _guardarGeneral() async {
    setState(() => _guardandoGeneral = true);
    try {
      final pintores =
          _pintoresSel.entries.where((e) => e.value).map((e) => e.key).toList();
      await widget.repository.actualizarBitacoraGeneral(
          widget.bitacoraId, _elaboroCtrl.text, pintores);
      _toast('✓  Datos generales actualizados');
      widget.onRefresh?.call();
      await _cargar();
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    } finally {
      if (mounted) setState(() => _guardandoGeneral = false);
    }
  }

  Future<void> _abrirPiezaDlg({Pieza? pieza}) async {
    final guardado = await PiezaFormDialog.show(
      context,
      repository: widget.repository,
      bitacoraId: widget.bitacoraId,
      pieza: pieza,
    );
    if (guardado == true) {
      _toast(pieza == null ? '✓  Pieza agregada' : '✓  Pieza actualizada');
      widget.onRefresh?.call();
      await _cargar();
    }
  }

  Future<void> _confirmarEliminarPieza(Pieza pieza) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: BitacoraColors.dangerLight,
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Icon(Icons.delete_rounded, color: BitacoraColors.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Eliminar pieza',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('ID #${pieza.id}',
                    style: const TextStyle(fontSize: 11, color: BitacoraColors.tdim)),
              ],
            ),
          ),
        ]),
        content: const Text(
          'Se eliminará esta pieza y sus mediciones.\nEsta acción no se puede deshacer.',
          style: TextStyle(color: BitacoraColors.tdim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: BitacoraColors.tdim)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: BitacoraColors.danger, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.repository.eliminarPieza(pieza.id!);
        _toast('Pieza #${pieza.id} eliminada');
        widget.onRefresh?.call();
        await _cargar();
      } catch (ex) {
        _toast('Error: $ex', ok: false);
      }
    }
  }

  Widget _panelGeneral() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BitacoraField(label: 'Elaboró', controller: _elaboroCtrl, upperCase: true),
        const SizedBox(height: 10),
        const Text('Pintores',
            style: TextStyle(fontSize: 11, color: BitacoraColors.tdim, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final p in kPintores)
              FilterChip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                selected: _pintoresSel[p] ?? false,
                selectedColor: BitacoraColors.accentLight,
                checkmarkColor: BitacoraColors.accent,
                onSelected: (v) => setState(() => _pintoresSel[p] = v),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _guardandoGeneral ? null : _guardarGeneral,
            style: ElevatedButton.styleFrom(
              backgroundColor: BitacoraColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _guardandoGeneral
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar General'),
          ),
        ),
      ],
    );
  }

  Widget _panelPiezas() {
    final piezas = _bitacora?.piezas ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BitacoraSectionLabel(text: 'Piezas', icon: '🔧'),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _abrirPiezaDlg(),
              icon: const Icon(Icons.add_rounded, size: 15, color: BitacoraColors.accent),
              label: const Text('Agregar pieza',
                  style: TextStyle(fontSize: 12, color: BitacoraColors.accent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: BitacoraColors.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (piezas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Sin piezas capturadas todavía.',
                style: TextStyle(color: BitacoraColors.tdim, fontSize: 13)),
          )
        else
          for (final pieza in piezas) _piezaTile(pieza),
      ],
    );
  }

  Widget _piezaTile(Pieza pieza) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BitacoraColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BitacoraColors.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: BitacoraColors.accentLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${pieza.id}',
                style: const TextStyle(
                    fontSize: 11, color: BitacoraColors.accent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pieza.codigo.isEmpty ? 'Sin código' : pieza.codigo,
                    style: const TextStyle(
                        fontSize: 13, color: BitacoraColors.texto, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (pieza.descripcion.isNotEmpty)
                  Text(pieza.descripcion,
                      style: const TextStyle(
                          fontSize: 10, color: BitacoraColors.tdim, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    Text('Job: ${pieza.job}', style: const TextStyle(fontSize: 11, color: BitacoraColors.tdim)),
                    const Text('·', style: TextStyle(color: BitacoraColors.borde)),
                    Text('Col: ${pieza.col}', style: const TextStyle(fontSize: 11, color: BitacoraColors.tdim)),
                    const Text('·', style: TextStyle(color: BitacoraColors.borde)),
                    Text('Pzas OK: ${pieza.pzaOk}', style: const TextStyle(fontSize: 11, color: BitacoraColors.tdim)),
                    const Text('·', style: TextStyle(color: BitacoraColors.borde)),
                    Text('Sups: ${pieza.numSuperficiesConDatos}',
                        style: const TextStyle(
                            fontSize: 11, color: BitacoraColors.accent, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar pieza',
            icon: const Icon(Icons.edit_rounded, color: BitacoraColors.accent, size: 18),
            onPressed: () => _abrirPiezaDlg(pieza: pieza),
          ),
          IconButton(
            tooltip: 'Eliminar pieza',
            icon: const Icon(Icons.delete_rounded, color: BitacoraColors.danger, size: 18),
            onPressed: () => _confirmarEliminarPieza(pieza),
          ),
        ],
      ),
    );
  }

  Widget _titulo() {
    final fecha = _bitacora?.fecha;
    final fechaStr = fecha == null
        ? ''
        : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [BitacoraColors.accentDark, BitacoraColors.accent]),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bitácora #${widget.bitacoraId.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${_bitacora?.elaboro.isNotEmpty == true ? _bitacora!.elaboro : '—'}  ·  $fechaStr',
                    style: const TextStyle(fontSize: 13, color: Colors.white)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= kDesktopBreakpoint;
    final dialogWidth = isDesktop ? 800.0 : (width < 560 ? width * 0.95 : 480.0);
    final dialogHeight = isDesktop ? 560.0 : 600.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _titulo(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: SingleChildScrollView(child: _panelGeneral()),
                                ),
                                const SizedBox(width: 16),
                                const VerticalDivider(width: 1, color: BitacoraColors.borde),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SingleChildScrollView(child: _panelPiezas()),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _panelGeneral(),
                                  const SizedBox(height: 12),
                                  const BitacoraDivider(),
                                  const SizedBox(height: 12),
                                  _panelPiezas(),
                                ],
                              ),
                            ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar', style: TextStyle(color: BitacoraColors.tdim)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
