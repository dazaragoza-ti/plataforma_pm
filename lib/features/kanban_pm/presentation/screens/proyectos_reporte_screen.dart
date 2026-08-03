import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/kanban_repository.dart';
import '../../data/usuario_directorio.dart';
import '../../data/workspace_repository.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';
import '../../domain/entities/workspace.dart';
import '../../kanban_constants.dart';
import '../widgets/dialogs/tarea_detail_dialog.dart';

part 'proyectos_reporte/modelo.dart';
part 'proyectos_reporte/datos.dart';
part 'proyectos_reporte/secciones.dart';
part 'proyectos_reporte/responsables_calendario.dart';

/// Pantalla "Proyectos": reconstrucción nativa (con los widgets y colores
/// propios del módulo Kanban) del reporte que el comité usa para ver su
/// trabajo cruzando varias áreas de trabajo — ver `Usuario.perteneceComite`.
/// A diferencia de la primera versión (un snapshot fijo de un documento),
/// esta lee datos reales: "proyectos" son las áreas de trabajo donde
/// pertenece algún miembro del comité, y "actividades" son las tareas —en
/// cualquier columna— con la etiqueta "Comité" dentro de esas áreas (ver
/// `_cargarReporteProyectos` en `proyectos_reporte/datos.dart`).
///
/// El contenido está dividido en varios archivos (carpeta
/// `proyectos_reporte/`, unidos con `part`/`part of`), igual que
/// `kanban_dashboard_screen.dart` divide su tablero: [_ProyectosSeccionesMixin]
/// (encabezado/KPIs/tapón/leyenda/carril de proyectos) y
/// [_ProyectosResponsablesCalendarioMixin] (grilla de responsables +
/// calendario simplificado) son `mixin` en vez de `extension` para poder
/// llamarse entre sí libremente (un método de un mixin puede invocar un
/// método del otro una vez combinados en la misma clase).
class ProyectosReporteScreen extends StatefulWidget {
  final WorkspaceRepository workspaceRepository;

  const ProyectosReporteScreen({super.key, required this.workspaceRepository});

  @override
  State<ProyectosReporteScreen> createState() =>
      _ProyectosReporteScreenState();
}

class _ProyectosReporteScreenState extends State<ProyectosReporteScreen>
    with _ProyectosSeccionesMixin, _ProyectosResponsablesCalendarioMixin {
  _ReporteProyectosDatos? _datos;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _cargarReporteProyectos(widget.workspaceRepository);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _error = '$ex';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.sizeOf(context).width < kUmbralMovilKanban;
    final paddingHorizontal = esMovil ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: KanbanColors.bg,
      // Sin `AppBar`: aunque quedara sin título y del mismo color que el
      // fondo, seguía reservando su alto por defecto (56) como una franja
      // vacía arriba — un "header invisible" ocupando espacio de verdad.
      // La flecha de regreso (solo hace falta fuera de web, ver
      // `kanban_dashboard_header.dart`) ahora es un control más dentro
      // del contenido, sin barra propia.
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _estadoError(_error!)
            : _contenido(context, _datos!, esMovil, paddingHorizontal),
      ),
    );
  }

  Widget _estadoError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: KanbanColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el reporte de proyectos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: KanbanColors.texto,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    _ReporteProyectosDatos datos,
    bool esMovil,
    double paddingHorizontal,
  ) {
    final tapon = _tapon(
      context,
      datos,
      esMovil: esMovil,
      alRefrescar: _cargar,
    );
    return Column(
      children: [
        // La card oscura (y la flecha de regreso) quedan fijas arriba,
        // fuera del `SingleChildScrollView` de abajo — así hacen las veces
        // de "header" de la pantalla (como el `AppBar` de antes), en vez de
        // desplazarse junto con el resto del reporte.
        Padding(
          padding: EdgeInsets.fromLTRB(
            paddingHorizontal,
            paddingHorizontal,
            paddingHorizontal,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Regresar',
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: KanbanColors.accent,
                      size: 16,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              _encabezado(datos, esMovil: esMovil),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              paddingHorizontal,
              esMovil ? 16 : 22,
              paddingHorizontal,
              paddingHorizontal,
            ),
            // Ancho completo de la ventana (no un `maxWidth` fijo): con un
            // ancho tope chico, en una pantalla de escritorio ancha el
            // reporte quedaba pegado a la izquierda con una franja enorme
            // de espacio vacío en vez de aprovechar la pantalla.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tapon != null) ...[
                    tapon,
                    SizedBox(height: esMovil ? 22 : 30),
                  ],
                  _seccionHeader(
                    Icons.view_kanban_outlined,
                    datos.proyectos.length == 1
                        ? 'El proyecto'
                        : 'Los ${datos.proyectos.length} proyectos',
                    'Cada carril es un área de trabajo del comité.',
                  ),
                  const SizedBox(height: 14),
                  _leyenda(),
                  const SizedBox(height: 14),
                  if (datos.proyectos.isEmpty)
                    _mensajeVacio(
                      'Ningún miembro del comité pertenece a un área de '
                      'trabajo todavía.',
                    )
                  else
                    for (final p in datos.proyectos) ...[
                      _carrilProyecto(
                        p,
                        esMovil: esMovil,
                        alRefrescar: _cargar,
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 18),
                  _seccionHeader(
                    Icons.assignment_ind_outlined,
                    'Qué debe cerrar cada quien',
                    'Ordenado por fecha fin. Solo tareas abiertas.',
                  ),
                  const SizedBox(height: 14),
                  _grillaResponsables(
                    context,
                    datos.pendientesPorResponsable,
                    alRefrescar: _cargar,
                  ),
                  const SizedBox(height: 18),
                  _seccionHeader(
                    Icons.calendar_month_outlined,
                    'Calendario (simplificado)',
                    'Barra proporcional entre el inicio y el cierre de '
                        'cada proyecto — el mismo dato del carril, en '
                        'línea de tiempo.',
                  ),
                  const SizedBox(height: 14),
                  _calendarioSimplificado(
                    datos.proyectos,
                    rangoInicio: datos.rangoInicio,
                    rangoFin: datos.rangoFin,
                    esMovil: esMovil,
                  ),
                  const SizedBox(height: 26),
                  Divider(color: KanbanColors.borde),
                  const SizedBox(height: 10),
                  Text(
                    'Reporte en vivo · actividades con la etiqueta '
                    '"Comité" en las áreas de trabajo del comité.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: KanbanColors.tdim,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
