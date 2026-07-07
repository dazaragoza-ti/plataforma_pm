import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';
import '../../domain/entities/bitacora.dart';
import 'bitacora_form_pieces.dart';

/// Tarjeta que resume una bitácora dentro del grid del dashboard.
/// Equivale a `_make_card` en `dashboard_view.py`.
class BitacoraCard extends StatelessWidget {
  final Bitacora bitacora;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BitacoraCard({
    super.key,
    required this.bitacora,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = bitacora.fecha;
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')} ${meses[fecha.month - 1]} ${fecha.year}';
    final elab = bitacora.elaboro.isEmpty ? 'Sin asignar' : bitacora.elaboro;
    final pintores = bitacora.pintores;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.13),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              // Encabezado con gradiente
              Container(
                height: 104,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [BitacoraColors.accentDark, BitacoraColors.accent],
                  ),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('# ${bitacora.id.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                                fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Ver / Editar',
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 19),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          tooltip: 'Eliminar bitácora',
                          icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 19),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(fechaStr, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              // Pie con datos de elaboró / piezas / pintores
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: BitacoraColors.bg2,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: BitacoraColors.accent, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            elab.isNotEmpty ? elab[0].toUpperCase() : '?',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Elaboró',
                                  style: TextStyle(fontSize: 9, color: BitacoraColors.tdim)),
                              Text(elab,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: BitacoraColors.texto,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const BitacoraDivider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: BitacoraColors.accentLight,
                                borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.inventory_2_outlined,
                                size: 15, color: BitacoraColors.accent),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Piezas',
                                  style: TextStyle(fontSize: 9, color: BitacoraColors.tdim)),
                              Text('${bitacora.numPiezas}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: BitacoraColors.texto,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ]),
                        const Spacer(),
                        Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: BitacoraColors.accentLight,
                                borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.people_outline_rounded,
                                size: 15, color: BitacoraColors.accent),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pintores',
                                  style: TextStyle(fontSize: 9, color: BitacoraColors.tdim)),
                              Text(
                                pintores.isEmpty
                                    ? '—'
                                    : pintores.take(2).join(', ') +
                                        (pintores.length > 2 ? '…' : ''),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: BitacoraColors.texto,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
