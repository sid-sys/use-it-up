import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Flat vector fruit bowl, drawn in code. No image file needed.
class FruitBowl extends StatelessWidget {
  final double width;
  const FruitBowl({super.key, this.width = 230});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.72,
      child: CustomPaint(painter: _BowlPainter()),
    );
  }
}

class _BowlPainter extends CustomPainter {
  static const _w = 230.0, _h = 166.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);

    Paint fill(int c) => Paint()..color = Color(c);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Light green leafy stalks (back)
    for (final (x, y, a) in [(70.0, 52.0, -0.28), (92.0, 44.0, 0.05)]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, 0, 20, 70), const Radius.circular(10)), fill(0xFF7CC242));
      canvas.restore();
    }

    // Banana, with a brown tip
    final banana = Path()
      ..moveTo(98, 70)
      ..quadraticBezierTo(140, 8, 190, 40);
    canvas.drawPath(banana, stroke..color = const Color(0xFFFFC21F)..strokeWidth = 24);
    canvas.drawPath(banana, stroke..color = const Color(0xFFFFD84D)..strokeWidth = 7);
    canvas.save();
    canvas.translate(190, 40);
    canvas.rotate(0.62);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -9, 14, 18), const Radius.circular(4)), fill(0xFFB5651D));
    canvas.restore();

    // Cherries (left)
    final stemP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = const Color(0xFF3B6B25);
    canvas.drawPath(Path()..moveTo(34, 86)..quadraticBezierTo(34, 62, 50, 52), stemP);
    canvas.drawPath(Path()..moveTo(56, 92)..quadraticBezierTo(52, 66, 50, 52), stemP);
    canvas.drawOval(Rect.fromCircle(center: const Offset(52, 52), radius: 0.1), fill(0xFF3B6B25));
    canvas.drawCircle(const Offset(34, 92), 13, fill(0xFFD91E43));
    canvas.drawCircle(const Offset(58, 98), 13, fill(0xFFC2123A));
    canvas.drawCircle(const Offset(30, 88), 3, Paint()..color = Colors.white.withValues(alpha: 0.5));

    // Orange with a leaf (right)
    canvas.drawCircle(const Offset(168, 98), 27, fill(0xFFF57A1F));
    canvas.drawCircle(const Offset(160, 90), 6, Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.save();
    canvas.translate(172, 72);
    canvas.rotate(-0.6);
    canvas.drawOval(const Rect.fromLTWH(-4, -9, 24, 12), fill(0xFF6BBF3A));
    canvas.restore();

    // Broccoli (front, dark green)
    final dark = fill(0xFF0B5B1A);
    for (final (x, y, r) in [(88.0, 108.0, 23.0), (116.0, 94.0, 28.0), (142.0, 110.0, 21.0), (104.0, 122.0, 20.0), (128.0, 124.0, 18.0)]) {
      canvas.drawCircle(Offset(x, y), r, dark);
    }
    canvas.drawCircle(const Offset(108, 86), 9, fill(0xFF1B7A2A));

    // Bowl (front)
    final bowl = Path()
      ..moveTo(26, 112)
      ..quadraticBezierTo(115, 126, 204, 112)
      ..quadraticBezierTo(196, 164, 115, 164)
      ..quadraticBezierTo(34, 164, 26, 112)
      ..close();
    canvas.drawPath(bowl, fill(0xFFEFE5CC));
    canvas.drawPath(
      Path()
        ..moveTo(40, 140)
        ..quadraticBezierTo(115, 160, 190, 140),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFD9CCAE),
    );

    // Strawberry (front right)
    final berry = Path()
      ..moveTo(150, 118)
      ..cubicTo(168, 112, 190, 118, 188, 134)
      ..cubicTo(186, 150, 168, 160, 160, 160)
      ..cubicTo(150, 156, 138, 140, 142, 128)
      ..cubicTo(143, 122, 146, 119, 150, 118)
      ..close();
    canvas.drawPath(berry, fill(0xFFE5232F));
    final seed = Paint()..color = const Color(0xFFFFE9A8);
    for (final (x, y) in [(154.0, 132.0), (168.0, 128.0), (162.0, 142.0), (176.0, 138.0), (152.0, 146.0), (168.0, 152.0)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 3.2, height: 4.6), seed);
    }
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(166, 117);
      canvas.rotate(-math.pi / 2 + (i - 1.5) * 0.7);
      canvas.drawOval(const Rect.fromLTWH(0, -3.5, 14, 7), fill(0xFF2E8B3A));
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BowlPainter old) => false;
}
