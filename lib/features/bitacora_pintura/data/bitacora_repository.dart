import '../domain/entities/bitacora.dart';
import '../domain/entities/pieza.dart';

/// Contrato de acceso a datos del módulo de Bitácora de Pintura.
///
/// En el proyecto original (Python/Flet) estas operaciones vivían en
/// `queries.py` y hablaban directo con SQL Server vía `pyodbc`/`pymssql`.
/// Una app Flutter (sobre todo si corre en móvil o web) no debe conectarse
/// directo a una base de datos SQL Server ni cargar sus credenciales: lo
/// correcto es exponer estas mismas operaciones a través de un backend/API
/// (REST o similar) y que este repositorio las consuma por HTTP.
///
/// Por eso esta clase queda como interfaz: define exactamente las mismas
/// operaciones que `queries.py`, y [InMemoryBitacoraRepository] es una
/// implementación de prueba que permite usar la pantalla ya mismo, sin
/// backend. El día que exista una API, basta con crear un
/// `ApiBitacoraRepository implements BitacoraRepository` que llame a los
/// endpoints correspondientes, sin tocar nada de la capa de presentación.
abstract class BitacoraRepository {
  /// Lista bitácoras filtradas por folio o "elaboró", paginadas.
  /// Devuelve (filas, total).
  Future<(List<Bitacora>, int)> listarBitacoras(
    String busqueda,
    int offset,
    int limit,
  );

  /// Crea sólo el registro general y devuelve el id generado.
  Future<int> crearBitacoraGeneral(String elaboro, List<String> pintores);

  Future<void> actualizarBitacoraGeneral(
    int id,
    String elaboro,
    List<String> pintores,
  );

  Future<void> eliminarBitacora(int id);

  /// Devuelve la bitácora completa (datos generales + piezas + superficies).
  Future<Bitacora?> obtenerBitacora(int id);

  Future<int> agregarPieza(int idBitacora, Pieza pieza);

  Future<void> actualizarPieza(int piezaId, Pieza pieza);

  Future<void> eliminarPieza(int piezaId);

  /// Autocompletado de código / part number a partir de lo tecleado.
  Future<List<String>> buscarCodigos(String codigo, String job);

  /// Descripción asociada a un job + código, si existe.
  Future<String> buscarDescripcion(String job, String codigo);
}

/// Implementación en memoria, útil para desarrollar y probar la UI sin
/// backend. Simula un pequeño catálogo de "Job / Part Number / Descripción"
/// equivalente a la tabla `Job` que consultaba `buscar_codigos` /
/// `buscar_descripcion` en el proyecto original.
class InMemoryBitacoraRepository implements BitacoraRepository {
  final List<Bitacora> _bitacoras = [];
  int _nextBitacoraId = 1;
  int _nextPiezaId = 1;

  // Catálogo simulado: cada entrada es (job, partNumber, descripcion).
  final List<(String, String, String)> _catalogoJobs = const [
    ('J-1001', 'PN-2200-A', 'Gabinete metálico serie 2200'),
    ('J-1001', 'PN-2200-B', 'Tapa gabinete serie 2200'),
    ('J-1042', 'PN-3310-C', 'Charola de control 3310'),
    ('J-1077', 'PN-4405-A', 'Base soporte 4405'),
  ];

  Future<void> _latencia() => Future.delayed(const Duration(milliseconds: 200));

  @override
  Future<(List<Bitacora>, int)> listarBitacoras(
    String busqueda,
    int offset,
    int limit,
  ) async {
    await _latencia();
    final like = busqueda.trim().toLowerCase();
    final filtradas = _bitacoras.where((b) {
      if (like.isEmpty) return true;
      return b.id.toString().contains(like) ||
          b.elaboro.toLowerCase().contains(like);
    }).toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    final total = filtradas.length;
    final pagina = filtradas.skip(offset).take(limit).toList();
    return (pagina, total);
  }

  @override
  Future<int> crearBitacoraGeneral(
      String elaboro, List<String> pintores) async {
    await _latencia();
    final id = _nextBitacoraId++;
    _bitacoras.add(Bitacora(
      id: id,
      fecha: DateTime.now(),
      elaboro: elaboro,
      pintores: pintores,
      piezas: const [],
    ));
    return id;
  }

  @override
  Future<void> actualizarBitacoraGeneral(
      int id, String elaboro, List<String> pintores) async {
    await _latencia();
    final idx = _bitacoras.indexWhere((b) => b.id == id);
    if (idx == -1) throw Exception('Bitácora #$id no encontrada');
    _bitacoras[idx] =
        _bitacoras[idx].copyWith(elaboro: elaboro, pintores: pintores);
  }

  @override
  Future<void> eliminarBitacora(int id) async {
    await _latencia();
    _bitacoras.removeWhere((b) => b.id == id);
  }

  @override
  Future<Bitacora?> obtenerBitacora(int id) async {
    await _latencia();
    final idx = _bitacoras.indexWhere((b) => b.id == id);
    return idx == -1 ? null : _bitacoras[idx];
  }

  @override
  Future<int> agregarPieza(int idBitacora, Pieza pieza) async {
    await _latencia();
    final idx = _bitacoras.indexWhere((b) => b.id == idBitacora);
    if (idx == -1) throw Exception('Bitácora #$idBitacora no encontrada');
    final pid = _nextPiezaId++;
    final nueva = pieza.copyWith(id: pid);
    final piezas = [..._bitacoras[idx].piezas, nueva];
    _bitacoras[idx] = _bitacoras[idx].copyWith(piezas: piezas);
    return pid;
  }

  @override
  Future<void> actualizarPieza(int piezaId, Pieza pieza) async {
    await _latencia();
    for (var i = 0; i < _bitacoras.length; i++) {
      final piezas = _bitacoras[i].piezas;
      final pIdx = piezas.indexWhere((p) => p.id == piezaId);
      if (pIdx != -1) {
        final nuevasPiezas = [...piezas];
        nuevasPiezas[pIdx] = pieza.copyWith(id: piezaId);
        _bitacoras[i] = _bitacoras[i].copyWith(piezas: nuevasPiezas);
        return;
      }
    }
    throw Exception('Pieza #$piezaId no encontrada');
  }

  @override
  Future<void> eliminarPieza(int piezaId) async {
    await _latencia();
    for (var i = 0; i < _bitacoras.length; i++) {
      final piezas = _bitacoras[i].piezas;
      if (piezas.any((p) => p.id == piezaId)) {
        _bitacoras[i] = _bitacoras[i].copyWith(
          piezas: piezas.where((p) => p.id != piezaId).toList(),
        );
        return;
      }
    }
  }

  @override
  Future<List<String>> buscarCodigos(String codigo, String job) async {
    if (codigo.length < 2 && job.length < 2) return [];
    await _latencia();
    final codLow = codigo.toLowerCase();
    final jobLow = job.toLowerCase();
    return _catalogoJobs
        .where((e) =>
            e.$2.toLowerCase().startsWith(codLow) ||
            e.$1.toLowerCase().startsWith(jobLow))
        .map((e) => e.$2)
        .toSet()
        .take(10)
        .toList();
  }

  @override
  Future<String> buscarDescripcion(String job, String codigo) async {
    if (job.trim().isEmpty || codigo.trim().isEmpty) return '';
    await _latencia();
    final match = _catalogoJobs.firstWhere(
      (e) =>
          e.$1.toLowerCase() == job.trim().toLowerCase() &&
          e.$2.toLowerCase() == codigo.trim().toLowerCase(),
      orElse: () => ('', '', ''),
    );
    return match.$3;
  }
}
