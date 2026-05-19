import 'dart:math';
import 'package:flutter/material.dart';

class Chip {
  final int value;
  final Color color;
  final Color stripeColor;

  const Chip({required this.value, required this.color, this.stripeColor = Colors.white});
}

class ChipWidget extends StatelessWidget {
  final Chip chip;
  final double diameter;

  const ChipWidget({super.key, required this.chip, this.diameter = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _ChipPainter(chip: chip),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  final Chip chip;

  _ChipPainter({required this.chip});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base chip color
    final paint = Paint()..color = chip.color;
    canvas.drawCircle(center, radius, paint);

    // Rim shading for 3D effect
    final rimPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1;
    canvas.drawCircle(center, radius, rimPaint);

    // Inner white circle
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.85, innerPaint);

    // Stripes
    final stripePaint = Paint()
      ..color = chip.stripeColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90.0) * (pi / 180.0);
      final rect = Rect.fromCenter(center: center, width: radius * 1.7, height: radius * 0.25);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRect(rect, stripePaint);
      canvas.restore();
    }

    // Center circle on top of stripes to create the final look
    canvas.drawCircle(center, radius * 0.5, innerPaint);
    final centerPaint = Paint()..color = chip.color;
    canvas.drawCircle(center, radius * 0.45, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}