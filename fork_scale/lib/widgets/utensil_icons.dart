import 'package:flutter/material.dart';

/// Hand-drawn utensil glyphs used as functional controls (utensil toggle,
/// camera guide, settings). Vectors rather than emoji so they render
/// identically across platforms and respect [color]/[size]. No fork-only
/// Unicode emoji exists, and 🔪/🥄 vary widely between fonts.

class ForkIcon extends StatelessWidget {
  final double size;
  final Color color;
  const ForkIcon({super.key, this.size = 14, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 0.55, size),
        painter: _ForkPainter(color),
      );
}

class KnifeIcon extends StatelessWidget {
  final double size;
  final Color color;
  const KnifeIcon({super.key, this.size = 14, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 0.55, size),
        painter: _KnifePainter(color),
      );
}

class SpoonIcon extends StatelessWidget {
  final double size;
  final Color color;
  const SpoonIcon({super.key, this.size = 14, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 0.55, size),
        painter: _SpoonPainter(color),
      );
}

class _ForkPainter extends CustomPainter {
  final Color color;
  const _ForkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sw = w * 0.20;
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Handle, shoulder, then 3 tines.
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, h * 0.52), paint);
    canvas.drawLine(Offset(sw / 2, h * 0.52), Offset(w - sw / 2, h * 0.52), paint);
    for (var i = 0; i < 3; i++) {
      final x = sw / 2 + (w - sw) * i / 2;
      canvas.drawLine(Offset(x, h * 0.52), Offset(x, h * 0.05), paint);
    }
  }

  @override
  bool shouldRepaint(_ForkPainter old) => old.color != color;
}

class _KnifePainter extends CustomPainter {
  final Color color;
  const _KnifePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Handle.
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, h * 0.5), stroke);
    // Blade: straight spine up to the tip, slanted cutting edge back down.
    final blade = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.82, h * 0.5)
      ..close();
    canvas.drawPath(blade, fill);
  }

  @override
  bool shouldRepaint(_KnifePainter old) => old.color != color;
}

class _SpoonPainter extends CustomPainter {
  final Color color;
  const _SpoonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Handle.
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, h * 0.42), stroke);
    // Bowl.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.24), width: w * 0.66, height: h * 0.42),
      fill,
    );
  }

  @override
  bool shouldRepaint(_SpoonPainter old) => old.color != color;
}
