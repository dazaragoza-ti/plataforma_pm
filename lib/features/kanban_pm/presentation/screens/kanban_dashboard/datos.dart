part of '../kanban_dashboard_screen.dart';

/// Carga de datos (tareas/columnas/etiquetas/miembros), la campana de
/// notificaciones, y el CRUD/movimiento de tarjetas — van en un solo mixin
/// porque están genuinamente entrelazados: casi todas las mutaciones
/// terminan en `_cargar`, y la campana de notificaciones abre el detalle
/// de una tarea (`_abrirDetalle`) igual que cualquier tarjeta del tablero.
/// Separarlos en mixins independientes habría exigido una dependencia
/// circular entre ellos (Carga necesita `_abrirDetalle` de Tareas, Tareas
/// necesita `_cargar` de Carga) — algo que la linearización de mixins de
/// Dart no permite expresar limpio.
mixin _KanbanDashboardDatosMixin on _KanbanDashboardCoreMixin {
  /// [_cargar] filtra columnas archivadas contra `_columnas` y calcula la
  /// campana de notificaciones contra `_miembros` (vía [_miIdDemo]) — ambos
  /// los llena [_cargarColumnasYEtiquetas]. Antes se disparaban en paralelo
  /// desde `initState`, y como esta última hace 3 llamadas y `_cargar` solo
  /// una, `_cargar` casi siempre terminaba primero con `_miembros` todavía
  /// vacío: `_miIdDemo` caía a `-1` y la campana quedaba en cero hasta que
  /// alguna otra acción disparara `_cargar` de nuevo. Aquí se espera a que
  /// el catálogo esté listo antes de cargar tareas.
  Future<void> _cargarInicial() async {
    await _cargarColumnasYEtiquetas();
    await _cargar();
  }

  Future<void> _cargarColumnasYEtiquetas() async {
    // Las 3 llamadas se disparan de una vez (sin `await` todavía) para que
    // corran concurrentes en vez de sumar su latencia una tras otra.
    final futuroColumnas = _repo.listarColumnas();
    final futuroEtiquetas = _repo.listarEtiquetas();
    final futuroMiembros = _repo.listarMiembros();
    final columnas = await futuroColumnas;
    final etiquetas = await futuroEtiquetas;
    final miembros = await futuroMiembros;
    if (!mounted) return;
    setState(() {
      // `List.of(...)` y no la lista tal cual: `listarColumnas()` devuelve
      // deliberadamente un `List.unmodifiable` (para que nadie más mute la
      // copia interna del repositorio), pero `_archivarColumna` y
      // `_renombrarColumna` escriben directo en `_columnas[idx]` — contra
      // la lista inmutable eso truena con "Unsupported operation" en
      // cuanto se intenta archivar o renombrar una lista.
      _columnas = List.of(columnas);
      _etiquetas = etiquetas;
      _miembros = miembros;
    });
  }

  Future<void> _cargar() async {
    final generacion = ++_generacionCarga;
    if (_primeraCarga) setState(() => _cargando = true);
    try {
      final busqueda = _searchCtrl.text;
      var tareas = await _repo.listarTareas(busqueda: busqueda);
      // Para notificaciones y el contador de archivadas hace falta el
      // universo completo de tareas, no solo las que coinciden con la
      // búsqueda actual: si se calculaban sobre `tareas` (ya angostada
      // por `busqueda`), escribir algo en el buscador "encogía"
      // `_actividadIdsVistos` a lo que quedaba visible, y una asignación
      // ya vista volvía a aparecer como "nueva" (con su aviso y todo) en
      // cuanto el texto de búsqueda cambiaba de nuevo.
      final todasSinBusqueda = busqueda.trim().isEmpty
          ? tareas
          : await _repo.listarTareas();
      final tarjetasArchivadasCount = todasSinBusqueda
          .where((t) => t.archivada)
          .length;
      final columnasArchivadas = _columnas
          .where((c) => c.archivada)
          .map((c) => c.estatus)
          .toSet();
      tareas = tareas
          .where((t) => !t.archivada && !columnasArchivadas.contains(t.estatus))
          .toList();
      // Antes de aplicar "Mis tareas"/"Solo pendientes"/fechas (que son
      // filtros de lo que se *muestra*): la campana de notificaciones debe
      // reflejar todas las subtareas asignadas a mí, no solo las que caben
      // en el filtro de vista actual (ni las que sobreviven la búsqueda).
      final baseParaNotificaciones = todasSinBusqueda
          .where((t) => !t.archivada && !columnasArchivadas.contains(t.estatus))
          .toList();
      if (_misTareas) {
        final miId = _miIdDemo;
        tareas = tareas
            .where(
              (t) =>
                  t.miembroIds.contains(miId) ||
                  _tengoSubtareaPendiente(t.actividades, miId),
            )
            .toList();
      }
      if (_soloPendientes) {
        tareas = tareas.where((t) => !t.cerrada).toList();
      }
      if (_fechaDesde != null) {
        tareas = tareas
            .where(
              (t) =>
                  t.fechaVencimiento == null ||
                  !t.fechaVencimiento!.isBefore(_fechaDesde!),
            )
            .toList();
      }
      if (_fechaHasta != null) {
        tareas = tareas
            .where(
              (t) =>
                  t.fechaVencimiento == null ||
                  !t.fechaVencimiento!.isAfter(_fechaHasta!),
            )
            .toList();
      }
      if (_miembroIdsFiltro.isNotEmpty) {
        tareas = tareas
            .where((t) => t.miembroIds.any(_miembroIdsFiltro.contains))
            .toList();
      }
      if (_departamentosFiltro.isNotEmpty) {
        tareas = tareas
            .where((t) => _departamentosFiltro.contains(t.grupo))
            .toList();
      }
      if (_etiquetaIdsFiltro.isNotEmpty) {
        tareas = tareas
            .where((t) => t.etiquetaIds.any(_etiquetaIdsFiltro.contains))
            .toList();
      }
      if (!mounted) return;
      // Descarta el resultado si ya no es la carga más reciente: sin esto,
      // una `_cargar()` más lenta (p. ej. con texto de búsqueda, que hace
      // el doble de llamadas al repositorio) podía resolver después de otra
      // más rápida disparada casi al mismo tiempo y pisar `_tareas` con
      // datos obsoletos, aunque en pantalla ya se viera el estado nuevo.
      if (generacion != _generacionCarga) return;
      final nuevasNotificaciones = _actualizarNotificaciones(
        baseParaNotificaciones,
      );
      setState(() {
        _tareas = tareas;
        _tareasCompletas = baseParaNotificaciones;
        _tareasAbsolutas = todasSinBusqueda;
        _tarjetasArchivadasCount = tarjetasArchivadasCount;
      });
      if (nuevasNotificaciones.isNotEmpty) {
        _avisarNuevasAsignaciones(nuevasNotificaciones);
      }
    } catch (ex) {
      if (mounted && generacion == _generacionCarga) {
        _toast('Error al cargar: $ex', ok: false);
      }
    } finally {
      if (mounted && generacion == _generacionCarga) {
        setState(() {
          _cargando = false;
          _primeraCarga = false;
        });
      }
    }
  }

  /// Recalcula qué subtareas siguen asignadas a mí y pendientes, a partir
  /// de [tareas] (ya filtradas de archivadas, pero antes de "Mis
  /// tareas"/"Solo pendientes"/fechas). Devuelve las que son nuevas desde
  /// la última carga (vacío en la primera carga, para no bombardear con
  /// toasts todo lo que ya estaba asignado desde el arranque).
  List<({Tarea tarea, Actividad actividad})> _actualizarNotificaciones(
    List<Tarea> tareas,
  ) {
    final miId = _miIdDemo;
    final actuales = miId == -1
        ? const <({Tarea tarea, Actividad actividad})>[]
        : _subtareasAsignadasA(tareas, miId);
    final nuevas = _notificacionesListas
        ? actuales
              .where((n) => !_actividadIdsVistos.contains(n.actividad.id))
              .toList()
        : const <({Tarea tarea, Actividad actividad})>[];
    _notificaciones = actuales;
    _actividadIdsVistos
      ..clear()
      ..addAll(actuales.map((n) => n.actividad.id));
    _notificacionesListas = true;
    return nuevas;
  }

  void _avisarNuevasAsignaciones(
    List<({Tarea tarea, Actividad actividad})> nuevas,
  ) {
    if (nuevas.length == 1) {
      final n = nuevas.first;
      _toastAccion(
        'Te asignaron la subtarea "${n.actividad.descripcion}" '
            'en "${n.tarea.titulo}"',
        'Ver',
        () => _abrirDetalle(n.tarea),
      );
    } else {
      _toastAccion(
        'Te asignaron ${nuevas.length} subtareas nuevas',
        'Ver',
        _abrirNotificaciones,
      );
    }
  }

  Future<void> _abrirNotificaciones() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Subtareas asignadas a mí',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: SizedBox(
          width: 360,
          child: _notificaciones.isEmpty
              ? Text(
                  'No tienes subtareas pendientes.',
                  style: TextStyle(color: KanbanColors.tdim),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final n in _notificaciones)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.assignment_ind_outlined,
                          size: 18,
                          color: KanbanColors.accent,
                        ),
                        title: Text(
                          n.actividad.descripcion,
                          style: TextStyle(
                            fontSize: 13,
                            color: KanbanColors.texto,
                          ),
                        ),
                        subtitle: Text(
                          'en "${n.tarea.titulo}"',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: KanbanColors.tdim,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _abrirDetalle(n.tarea);
                        },
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _cargar);
  }

  Future<void> _cambiarLimiteWip(TareaEstatus estatus, int? limite) async {
    setState(() {
      final idx = _columnas.indexWhere((c) => c.estatus == estatus);
      if (idx != -1) {
        _columnas[idx] = _columnas[idx].copyWith(
          limiteWip: limite,
          limpiarLimiteWip: limite == null,
        );
      }
    });
    await _repo.actualizarLimiteWipColumna(estatus, limite);
  }

  Future<void> _abrirNuevaTarea() async {
    final id = await NuevaTareaDialog.show(
      context,
      repository: _repo,
      columnas: _columnasVisibles,
      miembros: _miembros,
      etiquetas: _etiquetas,
    );
    if (id != null) {
      await _cargar();
      _toast('Tarea #$id creada');
    }
  }

  Future<void> _abrirPlantillas() async {
    final elegida = await PlantillasDialog.show(context, repository: _repo);
    if (elegida == null || !mounted) return;
    final id = await NuevaTareaDialog.show(
      context,
      repository: _repo,
      columnas: _columnasVisibles,
      miembros: _miembros,
      etiquetas: _etiquetas,
      plantilla: elegida,
    );
    if (id != null) {
      await _cargar();
      _toast('Tarea #$id creada');
    }
  }

  Future<void> _abrirDetalle(Tarea t) async {
    await TareaDetailDialog.show(
      context,
      repository: _repo,
      tareaId: t.id,
      onRefresh: _cargar,
    );
    await _cargar();
  }

  /// `null` si mover una tarjeta a [destino] respeta su límite de WIP; si
  /// lo excede, el mensaje a mostrar en vez de proceder. Antes el límite
  /// de WIP era puramente decorativo — solo pintaba la columna en rojo al
  /// pasarse, sin impedir nada — así que columnas como PROCESO (límite 1,
  /// solo una tarea a la vez) terminaban con varias tarjetas igual.
  /// [excluirId] es la tarjeta que se está moviendo, para no contarla dos
  /// veces si ya estaba en esa misma columna. [extra] permite pedir
  /// espacio para más de una tarjeta a la vez (mover en lote).
  String? _wipBloqueado(
    TareaEstatus destino, {
    required int excluirId,
    int extra = 1,
  }) {
    KanbanColumna? columna;
    for (final c in _columnas) {
      if (c.estatus == destino) {
        columna = c;
        break;
      }
    }
    final limite = columna?.limiteWip;
    if (limite == null) return null;
    // `_tareasCompletas` (no `_tareas`): el límite debe respetar el total
    // real de la columna, no solo lo que un filtro de vista activo (Mis
    // tareas, miembro, búsqueda…) deja visible en este momento — si no,
    // una tarjeta oculta por el filtro no cuenta para el límite y se
    // puede violar sin aviso.
    final ocupadas = _tareasCompletas
        .where((x) => x.id != excluirId && x.estatus == destino)
        .length;
    if (ocupadas + extra > limite) {
      return 'Ya hay ${ocupadas == 1 ? 'una tarjeta' : '$ocupadas tarjetas'} '
          'en "${columna!.titulo}" (límite $limite). Muévela antes de '
          'agregar otra.';
    }
    return null;
  }

  Future<void> _moverTarea(
    Tarea t,
    TareaEstatus nuevoEstatus, {
    int? antesDeId,
  }) async {
    final origen = t.estatus;
    if (origen != nuevoEstatus) {
      final bloqueo = _wipBloqueado(nuevoEstatus, excluirId: t.id);
      if (bloqueo != null) {
        _toast(bloqueo, ok: false);
        return;
      }
    }
    if (nuevoEstatus == TareaEstatus.pausa && origen != TareaEstatus.pausa) {
      final continuar = await PausarTareaDialog.show(
        context,
        repository: _repo,
        tarea: t,
      );
      if (!continuar || !mounted) return;
    }
    setState(() {
      final destinoActual =
          _tareas
              .where((x) => x.id != t.id && x.estatus == nuevoEstatus)
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden));
      final posVisible = antesDeId == null
          ? destinoActual.length
          : destinoActual.indexWhere((x) => x.id == antesDeId);
      final pos = (posVisible == -1 ? destinoActual.length : posVisible).clamp(
        0,
        destinoActual.length,
      );
      destinoActual.insert(pos, t.copyWith(estatus: nuevoEstatus));
      for (var i = 0; i < destinoActual.length; i++) {
        final idx = _tareas.indexWhere((x) => x.id == destinoActual[i].id);
        _tareas[idx] = _tareas[idx].copyWith(estatus: nuevoEstatus, orden: i);
      }
      if (origen != nuevoEstatus) {
        final origenActual = _tareas.where((x) => x.estatus == origen).toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));
        for (var i = 0; i < origenActual.length; i++) {
          final idx = _tareas.indexWhere((x) => x.id == origenActual[i].id);
          _tareas[idx] = _tareas[idx].copyWith(orden: i);
        }
      }
      _tareas.sort((a, b) => a.orden.compareTo(b.orden));
      // Mismo ajuste, también optimista, sobre `_tareasCompletas`: sin
      // esto, `_tareasCompletas` solo se refresca dentro del `_cargar()`
      // (async) de más abajo, y un segundo movimiento disparado antes de
      // que ese `_cargar()` resuelva leía `_wipBloqueado` contra datos
      // desactualizados — dos arrastres casi simultáneos a la misma
      // columna con límite de WIP podían saltárselo los dos, reabriendo
      // el bug que el propio límite existe para impedir.
      final idxCompleto = _tareasCompletas.indexWhere((x) => x.id == t.id);
      if (idxCompleto != -1) {
        _tareasCompletas[idxCompleto] = _tareasCompletas[idxCompleto]
            .copyWith(estatus: nuevoEstatus);
      }
    });
    // La posición que se manda al repositorio se resuelve contra
    // `_tareasCompletas` (el total real de la columna destino), no contra
    // `_tareas` (ya angostada por los filtros de vista activos): un
    // índice sobre la lista filtrada no corresponde al mismo lugar en la
    // columna completa si algún filtro oculta tarjetas de en medio.
    final destinoCompleto =
        _tareasCompletas
            .where((x) => x.id != t.id && x.estatus == nuevoEstatus)
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));
    final posicionReal = antesDeId == null
        ? destinoCompleto.length
        : destinoCompleto.indexWhere((x) => x.id == antesDeId);
    final posicion = posicionReal == -1
        ? destinoCompleto.length
        : posicionReal;
    try {
      final movida = await _repo.moverTarea(
        t.id,
        nuevoEstatus,
        posicion: posicion,
      );
      // El `setState` de arriba es optimista: reescribe `_tareas[idx]` a
      // partir de la `t` que llegó como argumento, así que cualquier otro
      // cambio hecho en el repositorio aparte del estatus/orden se
      // perdía — la tarjeta se movía bien, pero mostraba datos
      // desactualizados hasta la siguiente recarga completa.
      await _cargar();
      // `movida == false`: la columna destino se archivó justo antes de
      // que este movimiento llegara al repositorio. Sin este aviso, la
      // tarjeta simplemente "regresaba sola" a su columna original (por
      // el `_cargar()` de arriba) sin ninguna explicación de por qué.
      if (!movida && mounted) {
        _toast(
          'No se pudo mover: la columna de destino está archivada.',
          ok: false,
        );
      }
    } catch (ex) {
      if (mounted) _toast('Error al mover tarea: $ex', ok: false);
      await _cargar();
    }
  }

  Future<void> _archivarTarjeta(Tarea t) async {
    try {
      await _repo.archivarTarea(t.id, true);
      await _cargar();
      _toastAccion('Tarjeta archivada', 'Deshacer', () async {
        await _repo.archivarTarea(t.id, false);
        await _cargar();
      });
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _eliminarTarjeta(Tarea t) async {
    final ok = await confirmarEliminar(
      context,
      titulo: 'Eliminar tarjeta',
      // No "esta acción no se puede deshacer": si se dice eso y acto
      // seguido aparece un toast "Deshacer", el texto contradice lo que
      // realmente pasa. El mensaje es honesto sobre la limitación real de
      // ese "Deshacer" (recrea la tarjeta con un id nuevo, sin restaurar
      // los enlaces de dependencia que otras tareas tenían con ella).
      mensaje:
          '¿Eliminar "${t.titulo}"? Podrás deshacerlo enseguida, pero se '
          'perderán sus enlaces de dependencia con otras tarjetas.',
    );
    if (!ok) return;
    try {
      await _repo.eliminarTarea(t.id);
      await _cargar();
      _toastAccion('Tarjeta eliminada', 'Deshacer', () async {
        try {
          // Recreación ligera: nueva id, no restaura enlaces de otras
          // tareas que dependían de esta (el repositorio ya los limpió).
          // `historial: []`: sin esto, `t.copyWith()` conservaba el
          // historial completo de la tarjeta borrada Y `crearTarea` le
          // agregaba otro "Creó la tarjeta" encima, dejando dos entradas
          // de creación con fechas distintas en la tarjeta "recreada".
          await _repo.crearTarea(t.copyWith(historial: []));
          await _cargar();
        } catch (ex) {
          // Puede fallar si, mientras estaba el toast en pantalla, se
          // archivó la columna donde vivía esta tarjeta — sin este
          // try/catch, la excepción de `crearTarea` quedaba sin manejar
          // y el usuario no se enteraba de que el "Deshacer" no funcionó.
          _toast('No se pudo deshacer: $ex', ok: false);
        }
      });
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  /// Mueve, archiva o elimina varias tarjetas a la vez — usado por la
  /// barra de selección de la vista Lista. Recorre los ids uno por uno
  /// (el repositorio en memoria no tiene una operación de lote nativa) y
  /// recién al final refresca una sola vez, para no repintar el tablero
  /// entre cada tarjeta.
  Future<void> _moverTareasEnLote(
    List<int> ids,
    TareaEstatus nuevoEstatus,
  ) async {
    KanbanColumna? columna;
    for (final c in _columnas) {
      if (c.estatus == nuevoEstatus) {
        columna = c;
        break;
      }
    }
    final limite = columna?.limiteWip;
    if (limite != null) {
      // `_tareasCompletas` (no `_tareas`): mismo motivo que en
      // `_wipBloqueado` — el límite debe respetar el total real de la
      // columna, no solo lo que un filtro de vista activo deja visible.
      final ocupadas = _tareasCompletas
          .where((x) => !ids.contains(x.id) && x.estatus == nuevoEstatus)
          .length;
      if (ocupadas + ids.length > limite) {
        _toast(
          'Ya hay ${ocupadas == 1 ? 'una tarjeta' : '$ocupadas tarjetas'} '
          'en "${columna!.titulo}" (límite $limite). No caben '
          '${ids.length} más ahí.',
          ok: false,
        );
        return;
      }
    }
    // Ajuste optimista de `_tareasCompletas`, mismo motivo que en
    // `_moverTarea`: sin esto, un segundo movimiento (otro lote, o un
    // arrastre individual) disparado mientras este lote todavía está en
    // curso leía el límite de WIP contra datos desactualizados y podía
    // saltárselo.
    setState(() {
      for (final id in ids) {
        final idx = _tareasCompletas.indexWhere((x) => x.id == id);
        if (idx != -1) {
          _tareasCompletas[idx] = _tareasCompletas[idx].copyWith(
            estatus: nuevoEstatus,
          );
        }
      }
    });
    // Cada id se intenta por separado (no un solo try/catch para todo el
    // lote): antes, si una tarjeta a la mitad fallaba, la excepción cortaba
    // el for y `_cargar()` nunca corría — el repositorio ya había movido
    // las tarjetas anteriores pero la UI se quedaba mostrando el estado de
    // antes, desincronizada de lo que realmente pasó.
    final fallidos = <int>[];
    for (final id in ids) {
      try {
        // `moverTarea` devuelve `false` (sin lanzar) si la columna
        // destino se archivó mientras el lote seguía en curso — hay que
        // contarla como fallo explícitamente, o el toast final reportaría
        // "N tarjetas movidas" incluyendo tarjetas que en realidad se
        // quedaron donde estaban.
        final movida = await _repo.moverTarea(id, nuevoEstatus);
        if (!movida) fallidos.add(id);
      } catch (_) {
        fallidos.add(id);
      }
    }
    await _cargar();
    final exitosos = ids.length - fallidos.length;
    if (fallidos.isEmpty) {
      _toast(
        '$exitosos ${exitosos == 1 ? 'tarjeta movida' : 'tarjetas movidas'}',
      );
    } else if (exitosos == 0) {
      _toast('No se pudo mover ninguna tarjeta.', ok: false);
    } else {
      _toast(
        'Se movieron $exitosos de ${ids.length} tarjetas '
        '(${fallidos.length} ${fallidos.length == 1 ? 'falló' : 'fallaron'}).',
        ok: false,
      );
    }
  }

  Future<void> _archivarTareasEnLote(List<int> ids) async {
    // Mismo motivo que en `_moverTareasEnLote`: try/catch por tarjeta para
    // que una falla a la mitad no deje el resto del lote (ya archivado en
    // el repositorio) sin reflejarse en la UI.
    final exitosos = <int>[];
    for (final id in ids) {
      try {
        await _repo.archivarTarea(id, true);
        exitosos.add(id);
      } catch (_) {
        // se reporta el conteo de fallos al final, no aborta el resto.
      }
    }
    await _cargar();
    if (exitosos.isEmpty) {
      _toast('No se pudo archivar ninguna tarjeta.', ok: false);
      return;
    }
    final fallidos = ids.length - exitosos.length;
    final mensaje = fallidos == 0
        ? '${exitosos.length} ${exitosos.length == 1 ? 'tarjeta archivada' : 'tarjetas archivadas'}'
        : '${exitosos.length} de ${ids.length} tarjetas archivadas '
              '($fallidos ${fallidos == 1 ? 'falló' : 'fallaron'})';
    // El deshacer solo reabre las que sí se archivaron: no tiene sentido
    // intentar revertir una que nunca llegó a archivarse.
    _toastAccion(mensaje, 'Deshacer', () async {
      // Mismo motivo que el lote original: try/catch por tarjeta para que
      // una falla a la mitad del deshacer no deje sin `_cargar()` (y sin
      // avisar) el resto que sí se desarchivó.
      final fallidosDeshacer = <int>[];
      for (final id in exitosos) {
        try {
          await _repo.archivarTarea(id, false);
        } catch (_) {
          fallidosDeshacer.add(id);
        }
      }
      await _cargar();
      if (fallidosDeshacer.isNotEmpty) {
        _toast(
          fallidosDeshacer.length == exitosos.length
              ? 'No se pudo deshacer.'
              : 'Se deshizo ${exitosos.length - fallidosDeshacer.length} de '
                    '${exitosos.length} tarjetas.',
          ok: false,
        );
      }
    });
  }

  Future<void> _eliminarTareasEnLote(List<int> ids) async {
    final respaldo = _tareas.where((t) => ids.contains(t.id)).toList();
    // Mismo motivo que en `_moverTareasEnLote`/`_archivarTareasEnLote`.
    final exitosos = <int>[];
    for (final id in ids) {
      try {
        await _repo.eliminarTarea(id);
        exitosos.add(id);
      } catch (_) {
        // se reporta el conteo de fallos al final, no aborta el resto.
      }
    }
    await _cargar();
    if (exitosos.isEmpty) {
      _toast('No se pudo eliminar ninguna tarjeta.', ok: false);
      return;
    }
    final fallidos = ids.length - exitosos.length;
    final mensaje = fallidos == 0
        ? '${exitosos.length} ${exitosos.length == 1 ? 'tarjeta eliminada' : 'tarjetas eliminadas'}'
        : '${exitosos.length} de ${ids.length} tarjetas eliminadas '
              '($fallidos ${fallidos == 1 ? 'falló' : 'fallaron'})';
    _toastAccion(mensaje, 'Deshacer', () async {
      // Solo recrea las que sí se llegaron a eliminar. Mismo motivo que
      // el lote original: try/catch por tarjeta para que una falla a la
      // mitad del deshacer no deje sin `_cargar()` (y sin avisar) el
      // resto que sí se recreó.
      final aRecrear = respaldo.where((t) => exitosos.contains(t.id));
      var recreadas = 0;
      for (final t in aRecrear) {
        try {
          // `historial: []` — ver el comentario equivalente en
          // `_eliminarTarjeta`: evita la doble entrada de "Creó la
          // tarjeta" al recrear.
          await _repo.crearTarea(t.copyWith(historial: []));
          recreadas++;
        } catch (_) {
          // se reporta el conteo de fallos al final, no aborta el resto.
        }
      }
      await _cargar();
      if (recreadas < exitosos.length) {
        _toast(
          recreadas == 0
              ? 'No se pudo deshacer.'
              : 'Se deshizo $recreadas de ${exitosos.length} tarjetas.',
          ok: false,
        );
      }
    });
  }
}

/// `true` si alguna actividad del árbol (a cualquier profundidad) tiene a
/// [miembroId] como responsable y sigue sin marcarse terminada — usado
/// para que "Mis tareas" también muestre tarjetas que no son mías pero
/// donde tengo una subtarea delegada pendiente.
bool _tengoSubtareaPendiente(List<Actividad> actividades, int miembroId) {
  for (final a in actividades) {
    if (a.miembroId == miembroId && !a.terminada) return true;
    if (_tengoSubtareaPendiente(a.subActividades, miembroId)) return true;
  }
  return false;
}

/// Recolecta, con su tarea dueña, cada subtarea (a cualquier profundidad)
/// asignada a [miembroId] que siga sin marcarse terminada — la fuente de
/// datos de la campana de notificaciones del header.
List<({Tarea tarea, Actividad actividad})> _subtareasAsignadasA(
  List<Tarea> tareas,
  int miembroId,
) {
  final resultado = <({Tarea tarea, Actividad actividad})>[];
  void recorrer(Tarea t, List<Actividad> lista) {
    for (final a in lista) {
      if (a.miembroId == miembroId && !a.terminada) {
        resultado.add((tarea: t, actividad: a));
      }
      recorrer(t, a.subActividades);
    }
  }

  for (final t in tareas) {
    recorrer(t, t.actividades);
  }
  return resultado;
}
