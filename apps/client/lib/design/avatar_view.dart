import 'package:flutter/material.dart';

import '../domain/avatar_config.dart';
import 'court_theme.dart';
import '../l10n/app_strings.dart';

class AvatarView extends StatelessWidget {
  const AvatarView({
    required this.config,
    this.size = 96,
    this.label = 'Menschliche Spielfigur',
    super.key,
  });
  final AvatarConfig config;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final name = label == 'Menschliche Spielfigur'
        ? context.tr('humanCharacter')
        : label;
    return Semantics(
      label: config.isFallback
          ? context.tr('avatarFallback', {'name': name})
          : name,
      image: true,
      child: SizedBox(
        width: size,
        height: size * 1.125,
        child: CustomPaint(painter: AvatarPainter(config)),
      ),
    );
  }
}

/// Original vector geometry on a 160×180 canvas. Layer order matches manifest.
class AvatarPainter extends CustomPainter {
  AvatarPainter(this.config);
  final AvatarConfig config;
  static const skinColors = {
    'light': Color(0xFFF0C9A5),
    'medium': Color(0xFFD9A575),
    'brown': Color(0xFFAD7650),
    'dark': Color(0xFF754C38),
    'olive': Color(0xFFB6A474),
  };
  static const hairColors = {
    'brown': Color(0xFF63412D),
    'black': Color(0xFF302B29),
    'gold': Color(0xFFB48A3E),
    'gray': Color(0xFF92918C),
    'copper': Color(0xFFA95F3E),
  };
  static const topColors = {
    'blue': CourtTokens.blue,
    'red': CourtTokens.red,
    'green': CourtTokens.green,
    'brown': CourtTokens.wood,
    'plum': Color(0xFF654668),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 180);
    final skin = skinColors[config['skin']]!;
    final hair = hairColors[config['hairColor']]!;
    final line = Paint()
      ..color = CourtTokens.ink
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void oval(Rect rect, Color color) {
      canvas.drawOval(rect, Paint()..color = color);
      canvas.drawOval(rect, line);
    }

    void path(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, line);
    }

    // background: mugshot measuring lines, without identity/number data.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 152, 172),
        const Radius.circular(12),
      ),
      Paint()..color = CourtTokens.paper,
    );
    for (final y in [32.0, 58.0, 84.0, 110.0, 136.0, 162.0]) {
      canvas.drawLine(
        Offset(10, y),
        Offset(150, y),
        Paint()
          ..color = CourtTokens.border.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }
    // torso
    path(
      Path()
        ..moveTo(32, 174)
        ..lineTo(38, 140)
        ..quadraticBezierTo(45, 119, 80, 121)
        ..quadraticBezierTo(119, 119, 126, 141)
        ..lineTo(132, 174)
        ..close(),
      topColors[config['topColor']]!,
    );
    if (config['top'] == 'jacket') {
      path(
        Path()
          ..moveTo(64, 123)
          ..lineTo(80, 151)
          ..lineTo(96, 123)
          ..lineTo(88, 169)
          ..lineTo(73, 169)
          ..close(),
        CourtTokens.file,
      );
    }
    if (config['top'] == 'waistcoat') {
      path(
        Path()
          ..moveTo(60, 123)
          ..lineTo(80, 147)
          ..lineTo(100, 123)
          ..lineTo(91, 169)
          ..lineTo(80, 163)
          ..lineTo(69, 169)
          ..close(),
        CourtTokens.file,
      );
      for (final y in [145.0, 155.0, 165.0]) {
        canvas.drawCircle(Offset(80, y), 2, Paint()..color = CourtTokens.ink);
      }
      canvas.drawLine(const Offset(102, 149), const Offset(116, 147), line);
    }
    // hairBack
    if (config['hair'] == 'ponytail') {
      path(
        Path()
          ..moveTo(100, 45)
          ..quadraticBezierTo(146, 43, 140, 83)
          ..quadraticBezierTo(151, 108, 128, 126)
          ..quadraticBezierTo(138, 90, 113, 79)
          ..close(),
        hair,
      );
      canvas.drawLine(
        const Offset(118, 67),
        const Offset(134, 72),
        Paint()
          ..color = CourtTokens.red
          ..strokeWidth = 5,
      );
    }
    if (config['hair'] == 'long') {
      path(
        Path()
          ..moveTo(41, 64)
          ..quadraticBezierTo(39, 12, 80, 18)
          ..quadraticBezierTo(127, 15, 121, 80)
          ..lineTo(129, 128)
          ..quadraticBezierTo(79, 144, 31, 127)
          ..close(),
        hair,
      );
    }
    // ears and face
    oval(const Rect.fromLTWH(39, 63, 18, 25), skin);
    oval(const Rect.fromLTWH(104, 63, 18, 25), skin);
    final face = config['face'];
    final rect = face == 'long'
        ? const Rect.fromLTWH(49, 30, 62, 94)
        : const Rect.fromLTWH(45, 34, 70, 86);
    if (face == 'heart') {
      path(
        Path()
          ..moveTo(80, 39)
          ..cubicTo(47, 20, 35, 58, 49, 87)
          ..quadraticBezierTo(59, 113, 80, 124)
          ..quadraticBezierTo(102, 114, 112, 86)
          ..cubicTo(128, 54, 110, 20, 80, 39)
          ..close(),
        skin,
      );
    } else if (face == 'round') {
      oval(rect, skin);
    } else {
      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(face == 'square' ? 15 : 28),
      );
      canvas.drawRRect(rounded, Paint()..color = skin);
      canvas.drawRRect(rounded, line);
    }
    // eyes
    for (final x in [65.0, 96.0]) {
      if (config['eyes'] == 'sleepy' || config['eyes'] == 'wink' && x == 96) {
        canvas.drawLine(Offset(x - 5, 69), Offset(x + 5, 70), line);
      } else {
        oval(
          Rect.fromCenter(center: Offset(x, 70), width: 12, height: 15),
          CourtTokens.file,
        );
        canvas.drawCircle(
          Offset(x + 1, 71),
          2.7,
          Paint()..color = CourtTokens.ink,
        );
      }
    }
    // brows
    if (config['brows'] == 'stern') {
      canvas.drawLine(const Offset(58, 52), const Offset(72, 59), line);
      canvas.drawLine(const Offset(90, 59), const Offset(104, 52), line);
    } else {
      final browY = config['brows'] == 'raised' ? 51.0 : 57.0;
      canvas.drawLine(Offset(58, browY + 2), Offset(71, browY), line);
      canvas.drawLine(Offset(90, browY), Offset(103, browY + 2), line);
    }
    // nose
    if (config['nose'] == 'long') {
      path(
        Path()
          ..moveTo(79, 72)
          ..lineTo(73, 92)
          ..quadraticBezierTo(83, 98, 89, 89),
        skin,
      );
    } else if (config['nose'] == 'button') {
      oval(const Rect.fromLTWH(77, 82, 10, 8), skin);
    } else {
      oval(const Rect.fromLTWH(73, 79, 17, 12), skin);
    }
    // mouth
    if (config['mouth'] == 'surprised') {
      oval(const Rect.fromLTWH(75, 99, 11, 15), CourtTokens.ink);
    } else if (config['mouth'] == 'smile') {
      canvas.drawPath(
        Path()
          ..moveTo(68, 101)
          ..quadraticBezierTo(82, 117, 96, 100),
        line,
      );
    } else if (config['mouth'] == 'smirk') {
      canvas.drawPath(
        Path()
          ..moveTo(70, 104)
          ..quadraticBezierTo(88, 109, 96, 97),
        line,
      );
      canvas.drawLine(const Offset(94, 96), const Offset(99, 98), line);
    } else {
      canvas.drawLine(const Offset(71, 104), const Offset(91, 104), line);
    }
    // beard
    if (config['beard'] == 'full') {
      path(
        Path()
          ..moveTo(53, 94)
          ..quadraticBezierTo(80, 117, 108, 94)
          ..quadraticBezierTo(108, 129, 80, 131)
          ..quadraticBezierTo(54, 126, 53, 94),
        hair,
      );
    }
    if (config['beard'] == 'stubble') {
      for (final x in [62.0, 70.0, 80.0, 90.0, 99.0]) {
        canvas.drawLine(Offset(x, 113), Offset(x + 2, 117), line);
      }
    }
    if (config['beard'] == 'moustache') {
      path(
        Path()
          ..moveTo(80, 95)
          ..quadraticBezierTo(71, 89, 61, 99)
          ..quadraticBezierTo(68, 108, 80, 101)
          ..quadraticBezierTo(93, 108, 101, 98)
          ..quadraticBezierTo(90, 90, 80, 95)
          ..close(),
        hair,
      );
    }
    // hairFront
    if (['short', 'long', 'ponytail'].contains(config['hair'])) {
      path(
        Path()
          ..moveTo(45, 57)
          ..lineTo(43, 32)
          ..lineTo(62, 21)
          ..lineTo(101, 24)
          ..lineTo(117, 39)
          ..lineTo(112, 61)
          ..lineTo(99, 42)
          ..lineTo(70, 48)
          ..lineTo(60, 39)
          ..close(),
        hair,
      );
    }
    if (config['hair'] == 'curly') {
      for (final point in [
        const Offset(46, 42),
        const Offset(58, 28),
        const Offset(77, 25),
        const Offset(96, 27),
        const Offset(114, 40),
      ]) {
        oval(Rect.fromCircle(center: point, radius: 13), hair);
      }
    }
    // glasses
    if (config['glasses'] == 'round') {
      canvas.drawCircle(const Offset(64, 71), 13, line);
      canvas.drawCircle(const Offset(96, 71), 13, line);
      canvas.drawLine(const Offset(77, 70), const Offset(83, 70), line);
    }
    if (config['glasses'] == 'rectangular') {
      for (final x in [50.0, 83.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 59, 27, 23),
            const Radius.circular(4),
          ),
          line,
        );
      }
      canvas.drawLine(const Offset(77, 70), const Offset(83, 70), line);
    }
    // hat
    if (config['hat'] == 'cap') {
      path(
        Path()
          ..moveTo(40, 37)
          ..quadraticBezierTo(45, 6, 82, 8)
          ..quadraticBezierTo(113, 9, 119, 37)
          ..lineTo(132, 43)
          ..lineTo(40, 43)
          ..close(),
        CourtTokens.blue,
      );
    }
    if (config['hat'] == 'tricorn') {
      path(
        Path()
          ..moveTo(34, 18)
          ..lineTo(58, 23)
          ..quadraticBezierTo(80, 1, 104, 23)
          ..lineTo(128, 16)
          ..lineTo(118, 44)
          ..quadraticBezierTo(80, 36, 43, 44)
          ..close(),
        CourtTokens.wood,
      );
      canvas.drawPath(
        Path()
          ..moveTo(43, 34)
          ..quadraticBezierTo(81, 28, 117, 33),
        Paint()
          ..color = hairColors['gold']!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    // extra
    if (config['extra'] == 'bowtie') {
      path(
        Path()
          ..moveTo(65, 132)
          ..lineTo(80, 139)
          ..lineTo(96, 132)
          ..lineTo(96, 148)
          ..lineTo(80, 141)
          ..lineTo(65, 148)
          ..close(),
        CourtTokens.red,
      );
    }
    if (config['extra'] == 'badge') {
      oval(const Rect.fromLTWH(101, 132, 20, 24), hairColors['gold']!);
      canvas.drawLine(const Offset(106, 143), const Offset(116, 143), line);
      canvas.drawLine(const Offset(111, 138), const Offset(111, 148), line);
    }
    if (config.isFallback) {
      canvas.drawCircle(
        const Offset(141, 158),
        12,
        Paint()..color = CourtTokens.red,
      );
      canvas.drawLine(
        const Offset(141, 151),
        const Offset(141, 159),
        Paint()
          ..color = CourtTokens.file
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        const Offset(141, 164),
        1.5,
        Paint()..color = CourtTokens.file,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) =>
      oldDelegate.config != config;
}
