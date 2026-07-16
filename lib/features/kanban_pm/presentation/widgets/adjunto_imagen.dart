import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final imagen = kIsWeb
        ? Image.network(path, width: width, height: height, fit: fit)
        : Image.file(File(path), width: width, height: height, fit: fit);
    if (borderRadius == null) return imagen;
    return ClipRRect(borderRadius: borderRadius!, child: imagen);
  }
}
