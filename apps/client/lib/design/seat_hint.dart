import 'package:flutter/material.dart';

/// A stationary seat cue: one baseline and two short end marks, without a box.
class SeatHint extends StatelessWidget {
  const SeatHint({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: 18,
        child: CustomPaint(painter: _SeatHintPainter()),
      ),
    ),
  );
}

class _SeatHintPainter extends CustomPainter {
  const _SeatHintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 12 || size.height < 2) return;
    final bottom = size.height - 2;
    canvas.drawPath(
      Path()
        ..moveTo(6, bottom - 12)
        ..lineTo(6, bottom)
        ..lineTo(size.width - 6, bottom)
        ..lineTo(size.width - 6, bottom - 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x8CE7C98B),
    );
  }

  @override
  bool shouldRepaint(_SeatHintPainter oldDelegate) => false;
}
