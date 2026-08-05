import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/data/usuario_directorio.dart';
import 'package:plataforma_pm/features/kanban_pm/data/workspace_repository.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/actividad.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea.dart';
import 'package:plataforma_pm/features/kanban_pm/kanban_constants.dart';
import 'package:plataforma_pm/features/kanban_pm/presentation/screens/proyectos_reporte_screen.dart';

/// Nombre único (no choca con "Mi tablero", el área que
/// `InMemoryWorkspaceRepository` siempre siembra sola) para poder ubicar
/// esta área de trabajo por nombre en los asserts sin depender del orden
/// en que el reporte recorre las áreas del comité.
const _nombreArea = 'WS Comité Test';

/// Cada carril "ÁREA NN" es ahora UNA tarjeta (ver `_cargarReporteProyectos`),
/// así que las claves `pista_`/`barra_` del calendario simplificado se
/// arman con el título de la tarjeta, no con el nombre del área de trabajo.
const _tituloTareaTardia = 'Tarea abierta más tardía';

/// Arma un `WorkspaceRepository` con un área de trabajo real del comité
/// (Javier, `u6`, es el único `Usuario.perteneceComite` de la app) y tres
/// tareas con la etiqueta "Comité": una cerrada, una abierta sin bloqueo
/// (con la fecha de vencimiento más tardía del conjunto, para que su barra
/// del calendario deba llegar justo al borde derecho de su pista) y una
/// abierta bloqueada por la primera.
Future<WorkspaceRepository> _repoConDatosComite() async {
  final workspaceRepo = InMemoryWorkspaceRepository();
  final javier = UsuarioDirectorio.instancia.porId('u6');

  final workspace = await workspaceRepo.crearWorkspace(
    _nombreArea,
    Colors.indigo,
    creadorUsuarioId: javier.id,
  );
  final repo = workspaceRepo.kanbanRepositoryPara(workspace.id);
  final etiquetaComiteId = await repo.crearEtiqueta(
    kNombreEtiquetaComite,
    kColorEtiquetaComite,
  );
  final miembroId = await repo.crearMiembro(
    javier.nombre,
    javier.colorAvatar,
    usuarioId: javier.id,
  );
  final miembroId2 = await repo.crearMiembro('Otro Responsable', Colors.teal);

  final baseId = await repo.crearTarea(
    Tarea(
      id: 0,
      titulo: 'Tarea base',
      estatus: TareaEstatus.terminado,
      etiquetaIds: [etiquetaComiteId],
      miembroIds: [miembroId],
      fechaInicio: DateTime(2026, 1, 1),
      fechaVencimiento: DateTime(2026, 1, 5),
    ),
  );
  await repo.crearTarea(
    Tarea(
      id: 0,
      titulo: 'Tarea abierta más tardía',
      estatus: TareaEstatus.proceso,
      etiquetaIds: [etiquetaComiteId],
      miembroIds: [miembroId],
      fechaInicio: DateTime(2026, 1, 1),
      // La fecha más tardía del conjunto: su barra debe llegar exactamente
      // al 100% del rango del calendario.
      fechaVencimiento: DateTime(2026, 2, 1),
      // Checklist con 1 de 2 completada — regresión: el % del carril debe
      // salir de este conteo, no solo de si la tarjeta está cerrada (que
      // no lo está: sigue "en curso").
      actividades: [
        Actividad(id: 1, descripcion: 'Sub 1', terminada: true),
        Actividad(id: 2, descripcion: 'Sub 2', terminada: false),
      ],
    ),
  );
  await repo.crearTarea(
    Tarea(
      id: 0,
      titulo: 'Tarea bloqueada',
      estatus: TareaEstatus.tareas,
      etiquetaIds: [etiquetaComiteId],
      miembroIds: [miembroId],
      dependeDeIds: [baseId],
      fechaVencimiento: DateTime(2026, 1, 20),
    ),
  );
  // Asignación múltiple (`miembroIds` con 2 personas) — debe aparecer en
  // la lista de pendientes de AMBAS, no solo de la primera.
  await repo.crearTarea(
    Tarea(
      id: 0,
      titulo: 'Tarea co-asignada',
      estatus: TareaEstatus.tareas,
      etiquetaIds: [etiquetaComiteId],
      miembroIds: [miembroId, miembroId2],
      fechaVencimiento: DateTime(2026, 1, 25),
    ),
  );

  return workspaceRepo;
}

/// Smoke test: sin esto, un `Stack` con solo hijos `Positioned` (como el
/// marcador "HOY" del calendario simplificado) puede tirar una excepción
/// de layout en tiempo de ejecución que ningún test existente detectaba
/// (no hay ningún otro test para esta pantalla), y solo se notaba al
/// abrirla manualmente en la app.
void main() {
  Future<void> bombear(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // `runAsync`: los repositorios en memoria simulan latencia real con
    // `Future.delayed` — bajo `testWidgets`, el reloj es "falso" y solo
    // avanza cuando se llama `tester.pump()`. Armar el fixture con `await`
    // directo (sin ningún `pump` de por medio) se queda esperando para
    // siempre esos `Future.delayed`; `runAsync` corre este bloque en una
    // zona async de verdad, donde si avanzan solos.
    late final WorkspaceRepository workspaceRepo;
    await tester.runAsync(() async {
      workspaceRepo = await _repoConDatosComite();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProyectosReporteScreen(workspaceRepository: workspaceRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  }

  testWidgets('renderiza sin excepciones en escritorio', (tester) async {
    await bombear(tester, const Size(1400, 1000));
    expect(find.text('QUÉ DEBE CERRAR CADA QUIEN'), findsOneWidget);
    expect(find.text('CALENDARIO (SIMPLIFICADO)'), findsOneWidget);
  });

  testWidgets(
    'el % del carril refleja el checklist de actividades, no solo si la '
    'tarjeta está cerrada',
    (tester) async {
      // Regresión: al pasar cada carril a representar UNA tarjeta, el %
      // mostrado se calculaba como 0%/100% binario según `t.cerrada`
      // (siempre 0% mientras la tarjeta siguiera abierta) en vez de sacarlo
      // del checklist real — marcar actividades no movía la barra.
      // "Tarea abierta más tardía" está "en curso" (no cerrada) con 1 de 2
      // actividades completadas: debe mostrar 50%, no 0%.
      await bombear(tester, const Size(1400, 1000));
      expect(find.text('50%'), findsOneWidget);
    },
  );

  testWidgets(
    'la barra del calendario no se sale de su pista en escritorio',
    (tester) async {
      // Regresión: la barra/marcador "HOY" se calculaban con el ancho de
      // toda la fila (etiqueta+pista+fecha) en vez del ancho real de la
      // pista donde se dibujan — en escritorio quedaban corridas más allá
      // del borde derecho visible. Un `Positioned` desalineado no lanza
      // excepción (a diferencia de un overflow de `Row`/`Column`), así que
      // el smoke test de arriba no lo detecta; hay que medir posiciones.
      await bombear(tester, const Size(1400, 1000));

      // "Tarea abierta más tardía" tiene la fecha de vencimiento más
      // tardía del conjunto — su barra debe llegar justo hasta el borde
      // derecho de su pista, nunca más allá.
      final pista = tester.getTopRight(
        find.byKey(const ValueKey('pista_$_tituloTareaTardia')),
      );
      final barra = tester.getTopRight(
        find.byKey(const ValueKey('barra_$_tituloTareaTardia')),
      );
      expect(barra.dx, lessThanOrEqualTo(pista.dx + 0.5));
    },
  );

  testWidgets(
    'el encabezado ocupa el mismo ancho que el resto de las secciones',
    (tester) async {
      // Regresión: `_encabezado` envuelve un `Wrap` (se ajusta a su
      // contenido) en vez de un `Row` (se expande solo) — sin un `width`
      // explícito, la card quedaba angosta (del tamaño del título+KPIs)
      // mientras el resto de la pantalla sí ocupaba todo el ancho. Un
      // ancho de menos no lanza excepción, así que hay que comparar
      // tamaños directamente.
      await bombear(tester, const Size(1400, 1000));

      final anchoEncabezado = tester
          .getSize(find.byKey(const ValueKey('encabezado_proyectos')))
          .width;
      final anchoPista = tester
          .getSize(find.byKey(const ValueKey('pista_$_tituloTareaTardia')))
          .width;
      // La pista es más angosta que el ancho total de la sección (le
      // restan la etiqueta de 190 y la fecha de 70) — comparar contra un
      // ancho ya conocido de otra sección de ancho completo alcanza para
      // detectar que el encabezado NO se quedó angosto (bug original: se
      // quedaba del ancho del título+KPIs, ~90px menos en esta pantalla).
      expect(anchoEncabezado, greaterThan(anchoPista));
    },
  );

  testWidgets(
    'tocar el botón "abrir tarjeta completa" de un carril abre la tarjeta '
    'real (TareaDetailDialog)',
    (tester) async {
      await bombear(tester, const Size(1400, 1000));

      expect(find.byType(Dialog), findsNothing);

      // "Tarea base" es ahora el título del carril mismo (cada carril es
      // UNA tarjeta, ver `_cargarReporteProyectos`), no un chip — el botón
      // que abre la tarjeta real vive dentro del mismo carril (`Container`
      // con `cardDecoration`, único ancestro `Container` del título).
      final carril = find
          .ancestor(
            of: find.text('Tarea base'),
            matching: find.byType(Container),
          )
          .first;
      final boton = find.descendant(
        of: carril,
        matching: find.byTooltip('Abrir tarjeta completa'),
      );
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      // La tarjeta real de la tarea (no un simple texto expandido) — debe
      // mostrar el título completo dentro de un campo editable.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Tarea base'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'tocar una fila de "qué debe cerrar cada quien" también abre la '
    'tarjeta completa',
    (tester) async {
      await bombear(tester, const Size(1400, 1000));

      // "Tarea bloqueada" está abierta, así que aparece dos veces: en el
      // chip del carril y en su fila de "qué debe cerrar cada quien" — el
      // carril se dibuja primero en la pantalla, así que la fila de esa
      // sección es la segunda coincidencia.
      final fila = find
          .ancestor(
            of: find.textContaining('Tarea bloqueada'),
            matching: find.byType(InkWell),
          )
          .at(1);
      await tester.ensureVisible(fila);
      await tester.pumpAndSettle();
      await tester.tap(fila);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Tarea bloqueada'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'tocar la tarea señalada en el aviso de tapón abre su tarjeta completa',
    (tester) async {
      await bombear(tester, const Size(1400, 1000));

      // El `InMemoryWorkspaceRepository()` de este fixture también siembra
      // "Mi tablero"/"Precios"/"XLayout" (ver `_seed()`), así que siempre
      // hay un tapón real que mostrar — "Aprobar prototipo con dirección"
      // (XLayout) es el de mayor impacto (bloquea 3 áreas distintas).
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('TAPÓN'), findsOneWidget);

      // Como está abierta (proceso), "Aprobar prototipo con dirección"
      // también aparece en el chip de su carril y en su fila de "qué debe
      // cerrar cada quien" — el aviso de tapón se dibuja primero en la
      // pantalla (antes de "Los proyectos"), así que es la primera
      // coincidencia.
      final aviso = find
          .ancestor(
            of: find.textContaining('Aprobar prototipo con dirección'),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.ensureVisible(aviso);
      await tester.pumpAndSettle();
      await tester.tap(aviso);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Aprobar prototipo con dirección'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'tocar una mención individual de "impactadas" en el tapón también '
    'abre su tarjeta completa',
    (tester) async {
      await bombear(tester, const Size(1400, 1000));

      // "Aprobar prototipo con dirección" (XLayout) bloquea, entre otras,
      // "Actualizar catálogo comercial" — antes esa mención era solo texto
      // (los títulos unidos por "·"), ahora cada una es su propia mención
      // tocable dentro del párrafo "condiciona o influye en:".
      final mencion = find
          .ancestor(
            of: find.textContaining('Actualizar catálogo comercial'),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.ensureVisible(mencion);
      await tester.pumpAndSettle();
      await tester.tap(mencion);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Actualizar catálogo comercial'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'una tarea con varios responsables aparece en la lista de pendientes '
    'de cada uno',
    (tester) async {
      // Regresión: "Qué debe cerrar cada quien" solo miraba
      // `miembroIds.first` — una tarea asignada a 2 personas solo
      // aparecía en la lista de la primera, dejando a la segunda sin
      // enterarse de que también le toca cerrarla. El título aparece 5
      // veces en total: el encabezado de su propio carril "ÁREA NN" (cada
      // tarjeta "Comité" es ahora su propio carril, ver
      // `_cargarReporteProyectos`; esta tarea no tiene actividades propias
      // en este fixture, así que su carril no repite el título en ningún
      // otro lado), su fila "ÁREA NN · título" en el calendario
      // simplificado, la mención en "activar hoy" del tapón (es una tarea
      // libre, se lista una sola vez ahí sin importar cuántos
      // responsables tenga) y una fila por cada uno de sus 2 responsables
      // en "qué debe cerrar cada quien".
      await bombear(tester, const Size(1400, 1000));

      expect(find.textContaining('Tarea co-asignada'), findsNWidgets(5));
    },
  );

  testWidgets('renderiza sin excepciones en móvil', (tester) async {
    await bombear(tester, const Size(390, 1200));
    expect(find.text('QUÉ DEBE CERRAR CADA QUIEN'), findsOneWidget);
    expect(find.text('CALENDARIO (SIMPLIFICADO)'), findsOneWidget);
  });

  testWidgets(
    'un área de trabajo con la etiqueta "Comité" pero sin tarjetas '
    'etiquetadas no agrega ningún carril',
    (tester) async {
      // Regresión: cada carril "ÁREA NN" es ahora UNA tarjeta (no un área
      // de trabajo completa) — un área de trabajo cuya etiqueta "Comité"
      // ya existe (se crea sola al abrirla como comité) pero que todavía
      // no tiene ninguna tarjeta con esa etiqueta simplemente no debe
      // aportar ningún carril, ni tampoco el viejo aviso de "carril
      // vacío" (ese concepto ya no aplica: no hay carril que mostrar
      // vacío, solo cero tarjetas).
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late final WorkspaceRepository workspaceRepo;
      await tester.runAsync(() async {
        workspaceRepo = InMemoryWorkspaceRepository();
        final javier = UsuarioDirectorio.instancia.porId('u6');
        final workspace = await workspaceRepo.crearWorkspace(
          'WS Comité Vacía',
          Colors.teal,
          creadorUsuarioId: javier.id,
        );
        // La etiqueta ya existe (como si alguien del comité hubiera
        // abierto este tablero antes), pero ninguna tarea la tiene
        // asignada todavía.
        await workspaceRepo
            .kanbanRepositoryPara(workspace.id)
            .crearEtiqueta(kNombreEtiquetaComite, kColorEtiquetaComite);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ProyectosReporteScreen(workspaceRepository: workspaceRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('WS Comité Vacía'), findsNothing);
      expect(
        find.text('Sin actividades con la etiqueta "Comité" todavía.'),
        findsNothing,
      );
    },
  );
}
