import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An offline HSV picker: hue wheel + saturation/brightness square.
/// Changes are previewed immediately in the surrounding editor.
class AvatarColorPicker extends StatefulWidget {
  const AvatarColorPicker({
    required this.initialHex,
    required this.english,
    required this.onChanged,
    super.key,
  });

  final String initialHex;
  final bool english;
  final ValueChanged<String> onChanged;

  @override
  State<AvatarColorPicker> createState() => _AvatarColorPickerState();
}

class _AvatarColorPickerState extends State<AvatarColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(_fromHex(widget.initialHex));
  }

  @override
  void didUpdateWidget(AvatarColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHex.toUpperCase() != _toHex(_hsv.toColor())) {
      _hsv = HSVColor.fromColor(_fromHex(widget.initialHex));
    }
  }

  static Color _fromHex(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));

  static String _toHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255).toInt();
    final g = (color.g * 255).round().clamp(0, 255).toInt();
    final b = (color.b * 255).round().clamp(0, 255).toInt();
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  void _update(HSVColor value) {
    setState(() {
      _hsv = value;
    });
    widget.onChanged(_toHex(_hsv.toColor()));
  }

  void _tapWheel(Offset point, double size) {
    final c = Offset(size / 2, size / 2);
    final dx = point.dx - c.dx;
    final dy = point.dy - c.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final squareSide = size * .48;
    final squareLeft = (size - squareSide) / 2;
    if (radius > size * .36 && radius < size * .55) {
      final degrees = (math.atan2(dy, dx) * 180 / math.pi + 90 + 360) % 360;
      _update(_hsv.withHue(degrees));
    } else if (point.dx >= squareLeft &&
        point.dx <= squareLeft + squareSide &&
        point.dy >= squareLeft &&
        point.dy <= squareLeft + squareSide) {
      final saturation = ((point.dx - squareLeft) / squareSide)
          .clamp(0.0, 1.0)
          .toDouble();
      final value = (1 - (point.dy - squareLeft) / squareSide)
          .clamp(0.0, 1.0)
          .toDouble();
      _update(_hsv.withSaturation(saturation).withValue(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final wheelSize = math.min(
          236.0,
          math.max(
            120.0,
            math.min(bounds.maxWidth - 32, bounds.maxHeight - 60),
          ),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: GestureDetector(
                    key: const ValueKey('avatar-color-wheel'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (event) =>
                        _tapWheel(event.localPosition, wheelSize),
                    onPanStart: (event) =>
                        _tapWheel(event.localPosition, wheelSize),
                    onPanUpdate: (event) =>
                        _tapWheel(event.localPosition, wheelSize),
                    child: Semantics(
                      label: widget.english ? 'Colour wheel' : 'Farbkreis',
                      child: CustomPaint(painter: _HuePickerPainter(_hsv)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hsv.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE9BC73)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HuePickerPainter extends CustomPainter {
  const _HuePickerPainter(this.color);
  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .43;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final wheel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .12
      ..shader = const SweepGradient(
        colors: [
          Colors.red,
          Colors.yellow,
          Colors.green,
          Colors.cyan,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(bounds);
    canvas.drawCircle(center, radius, wheel);

    final side = size.width * .48;
    final square = Rect.fromCenter(center: center, width: side, height: side);
    final hueColor = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor();
    canvas.drawRect(
      square,
      Paint()
        ..shader = LinearGradient(colors: [Colors.white, hueColor])
            .createShader(square),
    );
    canvas.drawRect(
      square,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(square),
    );
    canvas.drawRect(
      square,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final radians = (color.hue - 90) * math.pi / 180;
    final hueHandle =
        center + Offset(math.cos(radians), math.sin(radians)) * radius;
    _handle(canvas, hueHandle);
    final marker = Offset(
      square.left + side * color.saturation,
      square.top + side * (1 - color.value),
    );
    _handle(canvas, marker);
  }

  void _handle(Canvas canvas, Offset point) {
    canvas.drawCircle(
      point,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      point,
      8.5,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HuePickerPainter oldDelegate) =>
      oldDelegate.color != color;
}
