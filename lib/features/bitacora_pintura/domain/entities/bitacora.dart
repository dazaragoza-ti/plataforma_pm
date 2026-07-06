import 'pieza.dart';

/// Registro general de una bitácora de pintura.
///
/// Equivale a la fila de `PM_Bitacora_Pintura1` del proyecto original,
/// más la lista de piezas asociadas (`PM_Bitacora_Piezas1`).
class Bitacora {
  final int id;
  final DateTime fecha;
  final String elaboro;
  final List<String> pintores;
  final List<Pieza> piezas;

  const Bitacora({
    required this.id,
    required this.fecha,
    this.elaboro = '',
    this.pintores = const [],
    this.piezas = const [],
  });

  int get numPiezas => piezas.length;

  Bitacora copyWith({
    int? id,
    DateTime? fecha,
    String? elaboro,
    List<String>? pintores,
    List<Pieza>? piezas,
  }) {
    return Bitacora(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      elaboro: elaboro ?? this.elaboro,
      pintores: pintores ?? this.pintores,
      piezas: piezas ?? this.piezas,
    );
  }
}
