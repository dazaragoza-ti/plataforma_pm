import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';
import '../../data/bitacora_repository.dart';
import 'bitacora_form_pieces.dart';

/// Diálogo para crear el registro general de una nueva bitácora.
/// Equivale a `_open_nueva_dlg` en `dashboard_view.py`.
class NuevaBitacoraDialog extends StatefulWidget {
  final BitacoraRepository repository;

  const NuevaBitacoraDialog({super.key, required this.repository});

  /// Devuelve el id de la bitácora creada, o null si se canceló.
  static Future<int?> show(BuildContext context, {required BitacoraRepository repository}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NuevaBitacoraDialog(repository: repository),
    );
  }

  @override
  State<NuevaBitacoraDialog> createState() => _NuevaBitacoraDialogState();
}

class _NuevaBitacoraDialogState extends State<NuevaBitacoraDialog> {
  final _elaboroCtrl = TextEditingController();
  final Map<String, bool> _pintoresSel = {for (final p in kPintores) p: false};
  bool _guardando = false;

  @override
  void dispose() {
    _elaboroCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() => _guardando = true);
    try {
      final pintores =
          _pintoresSel.entries.where((e) => e.value).map((e) => e.key).toList();
      final id = await widget.repository.crearBitacoraGeneral(_elaboroCtrl.text, pintores);
      if (mounted) Navigator.of(context).pop(id);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [BitacoraColors.accentDark, BitacoraColors.accent]),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Nueva bitácora',
                        style: TextStyle(
                            fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BitacoraField(label: 'Elaboró', controller: _elaboroCtrl, upperCase: true),
                  const SizedBox(height: 10),
                  const Text('Pintores',
                      style: TextStyle(
                          fontSize: 11, color: BitacoraColors.tdim, fontWeight: FontWeight.w600)),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _crear,
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('✚  Crear bitácora'),
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
}
