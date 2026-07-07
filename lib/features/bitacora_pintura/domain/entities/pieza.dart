/// Representa una pieza registrada dentro de una bitácora de pintura,
/// junto con las condiciones de horno y las mediciones por superficie.
///
/// Equivale a la fila de `PM_Bitacora_Piezas1` + sus filas asociadas en
/// `PM_Bitacora_Superficies1` del proyecto original en Python/Flet.
class Pieza {
  final int? id;
  final DateTime fecha;
  final String codigo;
  final String descripcion;
  final String job;
  final String nLote;

  // Condiciones del horno
  final String temp;
  final String vel;
  final String hrn;
  final String dur;
  final String bri;
  final String cuad;
  final String cur;
  final String col;
  final String cab;
  final String psPin;
  final String pcPin;
  final String pzaOk;

  /// Mediciones por superficie: nombre de superficie -> matriz FILAS x COLS.
  final Map<String, List<List<String>>> superficies;

  const Pieza({
    this.id,
    required this.fecha,
    this.codigo = '',
    this.descripcion = '',
    this.job = '',
    this.nLote = '',
    this.temp = '',
    this.vel = '',
    this.hrn = '',
    this.dur = '',
    this.bri = '',
    this.cuad = '',
    this.cur = '',
    this.col = '',
    this.cab = '',
    this.psPin = '',
    this.pcPin = '',
    this.pzaOk = '',
    this.superficies = const {},
  });

  /// Número de superficies con al menos un valor capturado.
  int get numSuperficiesConDatos => superficies.entries
      .where((e) => e.value.any((fila) => fila.any((v) => v.trim().isNotEmpty)))
      .length;

  Pieza copyWith({
    int? id,
    DateTime? fecha,
    String? codigo,
    String? descripcion,
    String? job,
    String? nLote,
    String? temp,
    String? vel,
    String? hrn,
    String? dur,
    String? bri,
    String? cuad,
    String? cur,
    String? col,
    String? cab,
    String? psPin,
    String? pcPin,
    String? pzaOk,
    Map<String, List<List<String>>>? superficies,
  }) {
    return Pieza(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      job: job ?? this.job,
      nLote: nLote ?? this.nLote,
      temp: temp ?? this.temp,
      vel: vel ?? this.vel,
      hrn: hrn ?? this.hrn,
      dur: dur ?? this.dur,
      bri: bri ?? this.bri,
      cuad: cuad ?? this.cuad,
      cur: cur ?? this.cur,
      col: col ?? this.col,
      cab: cab ?? this.cab,
      psPin: psPin ?? this.psPin,
      pcPin: pcPin ?? this.pcPin,
      pzaOk: pzaOk ?? this.pzaOk,
      superficies: superficies ?? this.superficies,
    );
  }
}
