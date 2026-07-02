import 'package:flutter/material.dart';

class BubbleButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BubbleButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<BubbleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // MouseRegion detecta de manera precisa la posición del cursor en Web/Desktop
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: _isHovered ? 1.12 : 1.0, // Efecto de acercamiento (zoom)
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                splashColor: widget.color.withValues(alpha: 0.12),
                highlightColor: widget.color.withValues(alpha: 0.06),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withValues(alpha: _isHovered ? 0.25 : 0.18), // Brilla más en hover
                        widget.color.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: widget.color.withValues(alpha: _isHovered ? 0.70 : 0.45),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: _isHovered ? 0.14 : 0.06), // Sombra más profunda en hover
                        blurRadius: _isHovered ? 24 : 20,
                        offset: _isHovered ? const Offset(0, 12) : const Offset(0, 10),
                        spreadRadius: _isHovered ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 38,
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}