import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/tarea.dart';
import '../../../kanban_constants.dart'
    show KanbanColors, KanbanColumna, kanbanToast;
import 'kanban_alert_dialog.dart';

/// A diferencia de las listas archivadas (que siguen en la lista de
/// columnas de la pantalla y no necesitan una consulta aparte), las
/// tarjetas archivadas se filtran por completo de la lista de tareas
/// visible — así que antes no había ninguna forma de verlas ni
/// recuperarlas pasados los 5 segundos del aviso "Deshacer" al momento de
/// archivar. Este diálogo consulta el repositorio directo (no recibe la
/// lista por parámetro) porque las archivadas nunca viven en el estado
/// de la pantalla.
class TarjetasArchivadasDialog extends StatefulWidget {
  final KanbanRepository repository;
  final VoidCallback onDesarchivada;

  const TarjetasArchivadasDialog({
    super.key,
    required this.repository,
    required this.onDesarchivada,
  });

  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
    required VoidCallback onDesarchivada,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TarjetasArchivadasDialog(
        repository: repository,
        onDesarchivada: onDesarchivada,
      ),
    );
  }

  @override
  State<TarjetasArchivadasDialog> createState() =>
      _TarjetasArchivadasDialogState();
}

class _TarjetasArchivadasDialogState extends State<TarjetasArchivadasDialog> {
  List<Tarea> _archivadas = [];
  List<KanbanColumna> _columnas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final resultados = await Future.wait([
        widget.repository.listarTareas(),
        widget.repository.listarColumnas(),
      ]);
      if (!mounted) return;
      final todas = resultados[0] as List<Tarea>;
      final columnas = resultados[1] as List<KanbanColumna>;
      setState(() {
        _archivadas = todas.where((t) => t.archivada).toList();
        _columnas = columnas;
        _cargando = false;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() => _cargando = false);
      kanbanToast(context, 'Error al cargar: $ex', ok: false);
    }
  }

  Future<void> _desarchivar(Tarea t) async {
    try {
      await widget.repository.archivarTarea(t.id, false);
      // Se llama SIN condicionar a `mounted`: es la única forma en que el
      // tablero se entera de que esta tarjeta ya no está archivada. Si
      // este diálogo se cerró (tocar fuera, atrás) mientras
      // `archivarTarea` seguía en curso, la tarjeta queda genuinamente
      // desarchivada en el repositorio — saltarse este aviso la dejaría
      // invisible en el tablero hasta que algo no relacionado disparara
      // otro refresco, pareciendo que "Desarchivar" no hizo nada.
      widget.onDesarchivada();
      if (!mounted) return;
      setState(() => _archivadas.removeWhere((x) => x.id == t.id));
      // Desarchivar la tarjeta no basta si su columna TAMBIÉN sigue
      // archivada (es posible: se puede archivar una tarjeta individual
      // y, después, toda su columna): sin este aviso, la tarjeta
      // simplemente desaparecía de esta lista sin volver a aparecer en
      // ningún otro lado, y el usuario no tenía forma de saber por qué
      // "Desarchivar" parecía no haber hecho nada.
      final columnasDeLaTarea = _columnas.where(
        (c) => c.estatus == t.estatus,
      );
      if (columnasDeLaTarea.isNotEmpty && columnasDeLaTarea.first.archivada) {
        kanbanToast(
          context,
          'La lista "${columnasDeLaTarea.first.titulo}" también está '
          'archivada — desarchívala desde "Listas archivadas" para que '
          '"${t.titulo}" vuelva a aparecer.',
          ok: false,
        );
      }
    } catch (ex) {
      if (!mounted) return;
      kanbanToast(context, 'Error al desarchivar: $ex', ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return kanbanAlertDialog(
      titulo: 'Tarjetas archivadas',
      content: SizedBox(
        width: 340,
        child: _cargando
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _archivadas.isEmpty
            ? Text(
                'No hay tarjetas archivadas.',
                style: TextStyle(color: KanbanColors.tdim),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in _archivadas)
                    ListTile(
                      dense: true,
                      title: Text(
                        t.titulo,
                        style: TextStyle(color: KanbanColors.texto),
                      ),
                      subtitle: t.grupo.isEmpty
                          ? null
                          : Text(
                              t.grupo,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: KanbanColors.tdim,
                              ),
                            ),
                      trailing: TextButton(
                        onPressed: () => _desarchivar(t),
                        child: const Text('Desarchivar'),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
