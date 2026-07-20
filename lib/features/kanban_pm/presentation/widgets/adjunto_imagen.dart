import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';

/// Miniatura de una imagen adjunta a un comentario: en web `path` es una URL
/// `blob:` que solo `Image.network` sabe leer; fuera de web es una ruta de
/// archivo local que solo `Image.file` sabe leer. Un solo widget para no
/// repetir esta rama `kIsWeb` en cada lugar que muestra un adjunto.
class AdjuntoImagen extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AdjuntoImagen({
    super.key,
    required this.path,
    this.width = 96,
    this.height = 96,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// Reemplazo cuando la imagen no carga — en web, lo más común: los
  /// adjuntos usan URLs `blob:` que solo viven mientras dura la sesión del
  /// navegador, así que cualquier adjunto queda roto después de recargar
  /// la página. Sin esto, `Image.network`/`Image.file` no dejan nada
  /// visible (o el placeholder rojo de error en modo debug).
  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stack) {
    return Container(
      width: width,
      height: height,
      color: KanbanColors.bg3,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: (width < height ? width : height) * 0.4,
        color: KanbanColors.tdim,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = kIsWeb
        ? Image.network(
            path,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _errorBuilder,
          )
        : Image.file(
            File(path),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _errorBuilder,
          );
    if (borderRadius == null) return imagen;
    return ClipRRect(borderRadius: borderRadius!, child: imagen);
  }
}
