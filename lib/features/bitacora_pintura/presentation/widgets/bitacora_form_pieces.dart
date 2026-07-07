import 'package:flutter/material.dart';
import '../../bitacora_constants.dart';

/// Campo de texto con el estilo coherente del módulo (equivalente a
/// `field()` en `card.py`). `upperCase: true` fuerza mayúsculas en las
/// letras a medida que se escribe, igual que en el original.
class BitacoraField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool upperCase;
  final ValueChanged<String>? onChanged;

  const BitacoraField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.upperCase = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 13, color: BitacoraColors.texto),
      textCapitalization:
          upperCase ? TextCapitalization.characters : TextCapitalization.none,
      onChanged: (v) {
        if (upperCase) {
          final upped = v.toUpperCase();
          if (upped != v) {
            controller.value = TextEditingValue(
              text: upped,
              selection: TextSelection.collapsed(offset: upped.length),
            );
          }
        }
        onChanged?.call(controller.text);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: BitacoraColors.tdim),
        filled: true,
        fillColor: BitacoraColors.bg3,
        isDense: true,
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline, size: 16, color: BitacoraColors.tdim)
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BitacoraColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BitacoraColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BitacoraColors.accent, width: 2),
        ),
      ),
    );
  }
}

/// Chip pequeño de texto con borde (equivalente a `badge()`).
class BitacoraBadge extends StatelessWidget {
  final String text;
  final Color color;

  const BitacoraBadge({super.key, required this.text, this.color = BitacoraColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

/// Encabezado de sección con fondo azul claro (equivalente a `section_label()`).
class BitacoraSectionLabel extends StatelessWidget {
  final String text;
  final String? icon;

  const BitacoraSectionLabel({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BitacoraColors.accentLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: const TextStyle(
                  fontSize: 14,
                  color: BitacoraColors.accent,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Divisor delgado (equivalente a `divider()`).
class BitacoraDivider extends StatelessWidget {
  const BitacoraDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: BitacoraColors.borde);
  }
}
