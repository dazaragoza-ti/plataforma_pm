import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';
import '../../data/bitacora_repository.dart';
import '../../domain/entities/bitacora.dart';
import '../widgets/bitacora_card.dart';
import '../widgets/bitacora_detail_dialog.dart';
import '../widgets/nueva_bitacora_dialog.dart';

/// Pantalla principal del módulo de Bitácora de Pintura: listado paginado
/// con búsqueda, alta de nuevas bitácoras y acceso al detalle de cada una.
///
/// Equivale a `BitacoraDashboardView` (`dashboard_view.py`) del proyecto
/// original. Por defecto usa [InMemoryBitacoraRepository]; cuando exista un
/// backend real basta con inyectar aquí una implementación de
/// [BitacoraRepository] que hable con la API.
class BitacoraDashboardScreen extends StatefulWidget {
  final BitacoraRepository? repository;

  const BitacoraDashboardScreen({super.key, this.repository});

  @override
  State<BitacoraDashboardScreen> createState() => _BitacoraDashboardScreenState();
}

class _BitacoraDashboardScreenState extends State<BitacoraDashboardScreen> {
  late final BitacoraRepository _repo = widget.repository ?? InMemoryBitacoraRepository();

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _pageIdx = 0;
  int _total = 0;
  List<Bitacora> _rows = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final (rows, total) = await _repo.listarBitacoras(
        _searchCtrl.text,
        _pageIdx * kPerPage,
        kPerPage,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _total = total;
      });
    } catch (ex) {
      if (mounted) _toast('Error al cargar: $ex', ok: false);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _pageIdx = 0;
      _cargar();
    });
  }

  Future<void> _paginar(int delta) async {
    final pages = math.max(1, (_total / kPerPage).ceil());
    final nuevo = _pageIdx + delta;
    if (nuevo >= 0 && nuevo < pages) {
      setState(() => _pageIdx = nuevo);
      await _cargar();
    }
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? BitacoraColors.ok : BitacoraColors.danger,
    ));
  }

  Future<void> _abrirNuevaBitacora() async {
    final id = await NuevaBitacoraDialog.show(context, repository: _repo);
    if (id != null) {
      await _cargar();
      if (mounted) {
        await BitacoraDetailDialog.show(
          context,
          repository: _repo,
          bitacoraId: id,
          onRefresh: _cargar,
        );
      }
    }
  }

  Future<void> _abrirDetalle(int id) async {
    await BitacoraDetailDialog.show(
      context,
      repository: _repo,
      bitacoraId: id,
      onRefresh: _cargar,
    );
  }

  Future<void> _confirmarEliminar(Bitacora b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: BitacoraColors.dangerLight, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.delete_rounded, color: BitacoraColors.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Eliminar bitácora',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Folio #${b.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(fontSize: 11, color: BitacoraColors.tdim)),
              ],
            ),
          ),
        ]),
        content: const Text(
          'Se eliminará la bitácora y todas sus piezas y mediciones.\n\n'
          'Esta acción no se puede deshacer.',
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
        await _repo.eliminarBitacora(b.id);
        _toast('Bitácora #${b.id} eliminada');
        await _cargar();
      } catch (ex) {
        _toast('Error: $ex', ok: false);
      }
    }
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: BitacoraColors.bg2,
        border: const Border(bottom: BorderSide(color: BitacoraColors.borde)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: BitacoraColors.accentLight, shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Regresar al menú',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: BitacoraColors.accent, size: 16),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.brush_rounded, color: BitacoraColors.accent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Bitácora de Pintura',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: BitacoraColors.texto),
                    overflow: TextOverflow.ellipsis),
              ),
              ElevatedButton.icon(
                onPressed: _abrirNuevaBitacora,
                icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                label: const Text('Nueva',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BitacoraColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13, color: BitacoraColors.texto),
            decoration: InputDecoration(
              hintText: 'Buscar por folio o elaboró…',
              hintStyle: const TextStyle(color: BitacoraColors.tdim, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: BitacoraColors.tdim),
              filled: true,
              fillColor: BitacoraColors.bg2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: BitacoraColors.borde),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: BitacoraColors.borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: BitacoraColors.accent, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    final pages = math.max(1, (_total / kPerPage).ceil());
    return Row(
      children: [
        Text('$_total bitácora${_total != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: BitacoraColors.tdim)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: _pageIdx > 0 ? BitacoraColors.accent : BitacoraColors.borde),
          onPressed: _pageIdx > 0 ? () => _paginar(-1) : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: BitacoraColors.bg3, borderRadius: BorderRadius.circular(8)),
          child: Text('${_pageIdx + 1} / $pages',
              style: const TextStyle(
                  fontSize: 12, color: BitacoraColors.tdim, fontWeight: FontWeight.w500)),
        ),
        IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: _pageIdx < pages - 1 ? BitacoraColors.accent : BitacoraColors.borde),
          onPressed: _pageIdx < pages - 1 ? () => _paginar(1) : null,
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: BitacoraColors.accentLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.inbox_outlined, size: 38, color: BitacoraColors.accent),
          ),
          const SizedBox(height: 12),
          const Text('Sin bitácoras',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: BitacoraColors.texto)),
          const SizedBox(height: 4),
          const Text('Crea la primera con el botón +',
              style: TextStyle(fontSize: 13, color: BitacoraColors.tdim)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BitacoraColors.bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pagination(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : _rows.isEmpty
                            ? _emptyState()
                            : GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 420,
                                  childAspectRatio: 1.55,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _rows.length,
                                itemBuilder: (context, i) {
                                  final b = _rows[i];
                                  return BitacoraCard(
                                    bitacora: b,
                                    onEdit: () => _abrirDetalle(b.id),
                                    onDelete: () => _confirmarEliminar(b),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
