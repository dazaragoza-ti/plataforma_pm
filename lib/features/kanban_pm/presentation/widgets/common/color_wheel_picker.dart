import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';

/// Selector de color por rueda HSV (matiz + saturación en el círculo,
/// brillo en el control debajo) en vez de una cuadrícula de colores fijos
/// — deja elegir cualquier tono, no solo los que vienen precargados.
class ColorWheelPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final double size;

  const ColorWheelPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.size = 200,
  });

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);

  void _actualizar(HSVColor nuevo) {
    setState(() => _hsv = nuevo);
    widget.onColorChanged(nuevo.toColor());
  }

  void _tocarRueda(Offset posicionLocal) {
    final centro = Offset(widget.size / 2, widget.size / 2);
    final radio = widget.size / 2;
    final delta = posicionLocal - centro;
    final distancia = delta.distance.clamp(0.0, radio);
    var angulo = math.atan2(delta.dy, delta.dx);
    if (angulo < 0) angulo += 2 * math.pi;
    _actualizar(
      _hsv.withHue(angulo * 180 / math.pi).withSaturation(distancia / radio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanDown: (d) => _tocarRueda(d.localPosition),
          onPanUpdate: (d) => _tocarRueda(d.localPosition),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RuedaColorPainter(hue: _hsv.hue),
              foregroundPainter: _SelectorPainter(
                hue: _hsv.hue,
                saturation: _hsv.saturation,
                size: widget.size,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              Icons.brightness_6_rounded,
              size: 16,
              color: KanbanColors.tdim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: HSVColor.fromAHSV(
                    1,
                    _hsv.hue,
                    _hsv.saturation,
                    1,
                  ).toColor(),
                  thumbColor: color,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _hsv.value,
                  onChanged: (v) => _actualizar(_hsv.withValue(v)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: KanbanColors.borde),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: KanbanColors.tdim,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pinta el disco: matiz en ángulo (`SweepGradient`, arranca y termina en
/// rojo para cerrar el círculo sin costura) y saturación en radio (blanco
/// opaco al centro que se desvanece hacia el borde, superpuesto encima).
class _RuedaColorPainter extends CustomPainter {
  final double hue;

  _RuedaColorPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final matiz = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(rect);
    canvas.drawCircle(centro, radio, matiz);

    final saturacion = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect);
    canvas.drawCircle(centro, radio, saturacion);
  }

  @override
  bool shouldRepaint(covariant _RuedaColorPainter oldDelegate) => false;
}

/// Aro que marca dónde está el color elegido dentro del disco.
class _SelectorPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double size;

  _SelectorPainter({
    required this.hue,
    required this.saturation,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final centro = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radio = canvasSize.width / 2;
    final anguloRad = hue * math.pi / 180;
    final distancia = saturation * radio;
    final punto = centro + Offset(math.cos(anguloRad), math.sin(anguloRad)) * distancia;

    canvas.drawCircle(
      punto,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      punto,
      8,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectorPainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.saturation != saturation;
}

/// Botón compacto (swatch + flechita) que muestra el color actual y abre
/// [showColorWheelDialog] al tocarlo — para los lugares donde antes había
/// una cuadrícula de colores fijos embebida en un formulario ya abierto.
class ColorWheelTriggerButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  final String titulo;

  const ColorWheelTriggerButton({
    super.key,
    required this.color,
    required this.onChanged,
    this.titulo = 'Elige un color',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final elegido = await showColorWheelDialog(
          context,
          initial: color,
          titulo: titulo,
        );
        if (elegido != null) onChanged(elegido);
      },
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: KanbanColors.borde),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 16, color: KanbanColors.tdim),
        ],
      ),
    );
  }
}

/// Diálogo compacto con la rueda para los lugares donde el color se elegía
/// antes en su propio `AlertDialog` separado (no embebido en un formulario
/// más grande).
Future<Color?> showColorWheelDialog(
  BuildContext context, {
  required Color initial,
  String titulo = 'Elige un color',
}) {
  var elegido = initial;
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      title: Text(titulo, style: TextStyle(color: KanbanColors.texto)),
      content: ColorWheelPicker(
        initialColor: initial,
        onColorChanged: (c) => elegido = c,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(elegido),
          style: ElevatedButton.styleFrom(
            backgroundColor: KanbanColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Elegir'),
        ),
      ],
    ),
  );
}
