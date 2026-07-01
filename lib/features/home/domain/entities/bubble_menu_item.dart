import 'package:flutter/material.dart';

class BubbleMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BubbleMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}