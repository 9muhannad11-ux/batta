import 'dart:math';

import 'package:flutter/material.dart';

/// شكل كل شخصية (وجه كرتوني بسيط).
class _Look {
  final Color skin;
  final String hat; // turban, kumma, none
  final Color hatColor;
  final String brows; // calm, sharp, angry, sad
  final String mouth; // smile, flat, gap, frown, grin
  final String beard; // none, stubble, full, goatee, mustache
  final bool thin;
  const _Look({
    required this.skin,
    this.hat = 'none',
    this.hatColor = Colors.white,
    this.brows = 'calm',
    this.mouth = 'smile',
    this.beard = 'none',
    this.thin = false,
  });
}

const _looks = <String, _Look>{
  // خلفان التفق: ملامح عمانية وعمامة حمرا
  'khalfan': _Look(skin: Color(0xFFC68E5E), hat: 'turban', hatColor: Color(0xFFC62828), beard: 'mustache'),
  // خصيب: ملامح حادة وعمامة حليبية
  'khusaib': _Look(skin: Color(0xFFB97A4F), hat: 'turban', hatColor: Color(0xFFF3E9D2), brows: 'sharp', mouth: 'flat', beard: 'short'),
  // مرهون: ملامح فقر وعمامة بنية فاتحة
  'marhoon': _Look(skin: Color(0xFFC08A5B), hat: 'turban', hatColor: Color(0xFFC8A27A), brows: 'sad', mouth: 'frown', beard: 'stubble', thin: true),
  // مصبّح: ملامح هادئة وكمّة عمانية
  'musabbah': _Look(skin: Color(0xFFC9946A), hat: 'kumma', hatColor: Color(0xFFFFFFFF), beard: 'short'),
  // سلوم العرج: أسمر البشرة
  'salloum': _Look(skin: Color(0xFF6B4226), mouth: 'grin'),
  // محمد بو ضرس: مايل للسمار وناقصه سن قدام
  'bodhirs': _Look(skin: Color(0xFF9C6B43), mouth: 'gap', beard: 'mustache'),
  // عبدو اليابس: قوة وصلابة ولحية مو كبيرة تغطي الوجه
  'abdo': _Look(skin: Color(0xFFB07A4F), brows: 'sharp', mouth: 'flat', beard: 'full'),
  // صديق: من بنجلاديش
  'sadiq': _Look(skin: Color(0xFF8D5A3B), beard: 'mustache', thin: true),
  // المنضغط: ملامح غاضبة وسكسوكة
  'mundaghit': _Look(skin: Color(0xFFBF8A60), brows: 'angry', mouth: 'frown', beard: 'goatee'),
};

class CharacterAvatar extends StatelessWidget {
  final String? charId;
  final double size;
  final Color ring;
  const CharacterAvatar({super.key, required this.charId, this.size = 48, this.ring = Colors.transparent});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // خلفية سماوي فاتح (مثل جو المجلس)
          gradient: const RadialGradient(center: Alignment(-0.2, -0.3), radius: 0.7, colors: [Color(0xFFE6F6FF), Color(0xFFA9DCF5)]),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
          border: Border.all(color: ring, width: max(2, size * 0.06)),
        ),
        child: ClipOval(child: CustomPaint(painter: _FacePainter(_looks[charId] ?? _looks['musabbah']!))),
      );
}

class _FacePainter extends CustomPainter {
  final _Look look;
  _FacePainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final ink = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    final skin = Paint()..color = look.skin;
    final dark = Paint()..color = const Color(0xFF1A1A1A);
    final hairColor = Paint()..color = const Color(0xFF1B1B1B);

    // الدشداشة والرقبة
    canvas.drawPath(Path()
      ..moveTo(s * 0.1, s)
      ..quadraticBezierTo(cx, s * 0.68, s * 0.9, s)
      ..close(), Paint()..color = const Color(0xFFF5F5F5));
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, s * 0.76), width: s * 0.18, height: s * 0.14), skin);

    // الراس
    final fw = look.thin ? s * 0.42 : s * 0.48;
    final face = Rect.fromCenter(center: Offset(cx, s * 0.5), width: fw, height: s * 0.54);
    // الأذون
    canvas.drawCircle(Offset(cx - fw / 2, s * 0.52), s * 0.06, skin);
    canvas.drawCircle(Offset(cx + fw / 2, s * 0.52), s * 0.06, skin);
    canvas.drawOval(face, skin);

    // اللحية (قبل الملامح عشان تبين الفم فوقها)
    switch (look.beard) {
      case 'full':
        canvas.drawPath(Path()
          ..moveTo(cx - fw / 2, s * 0.5)
          ..quadraticBezierTo(cx - fw / 2, s * 0.84, cx, s * 0.84)
          ..quadraticBezierTo(cx + fw / 2, s * 0.84, cx + fw / 2, s * 0.5)
          ..lineTo(cx + fw * 0.35, s * 0.58)
          ..quadraticBezierTo(cx, s * 0.62, cx - fw * 0.35, s * 0.58)
          ..close(), hairColor);
      case 'short':
        canvas.drawPath(Path()
          ..moveTo(cx - fw * 0.45, s * 0.58)
          ..quadraticBezierTo(cx, s * 0.86, cx + fw * 0.45, s * 0.58)
          ..quadraticBezierTo(cx, s * 0.7, cx - fw * 0.45, s * 0.58), Paint()..color = const Color(0xFF2B2B2B));
      case 'stubble':
        final dots = Paint()..color = const Color(0x66000000);
        final rnd = Random(3);
        for (var i = 0; i < 40; i++) {
          final a = pi * (0.15 + rnd.nextDouble() * 0.7);
          final r = fw * (0.32 + rnd.nextDouble() * 0.16);
          canvas.drawCircle(Offset(cx + cos(a) * r * 0.9, s * 0.56 + sin(a) * r * 0.75), s * 0.008, dots);
        }
      case 'goatee':
        canvas.drawPath(Path()
          ..moveTo(cx - s * 0.06, s * 0.7)
          ..lineTo(cx + s * 0.06, s * 0.7)
          ..lineTo(cx, s * 0.82)
          ..close(), hairColor);
    }

    // الحواجب
    final browPaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final x1 = cx + side * s * 0.05, x2 = cx + side * s * 0.16;
      final (y1, y2) = switch (look.brows) {
        'angry' => (s * 0.43, s * 0.37),
        'sharp' => (s * 0.41, s * 0.38),
        'sad' => (s * 0.37, s * 0.42),
        _ => (s * 0.39, s * 0.39),
      };
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), browPaint);
    }

    // العيون
    final eyeY = look.brows == 'calm' ? s * 0.465 : s * 0.47;
    for (final side in [-1.0, 1.0]) {
      if (look.hat == 'kumma' && look.brows == 'calm') {
        // نظرة هادئة: عيون شبه مسكرة
        canvas.drawArc(Rect.fromCenter(center: Offset(cx + side * s * 0.1, eyeY), width: s * 0.08, height: s * 0.05), 0, pi, false, ink);
      } else {
        canvas.drawCircle(Offset(cx + side * s * 0.1, eyeY), s * 0.027, dark);
      }
    }

    // الخشم
    canvas.drawPath(Path()
      ..moveTo(cx, s * 0.49)
      ..lineTo(cx - s * 0.03, s * 0.57)
      ..lineTo(cx + s * 0.02, s * 0.575), ink..strokeWidth = s * 0.022);

    // الشارب
    if (look.beard == 'mustache' || look.beard == 'goatee' || look.beard == 'full' || look.beard == 'short') {
      canvas.drawPath(Path()
        ..moveTo(cx - s * 0.1, s * 0.62)
        ..quadraticBezierTo(cx, s * 0.58, cx + s * 0.1, s * 0.62)
        ..quadraticBezierTo(cx, s * 0.61, cx - s * 0.1, s * 0.62), Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035);
    }

    // الفم
    final my = s * 0.67;
    final mouthInk = Paint()
      ..color = const Color(0xFF3E1F1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round;
    switch (look.mouth) {
      case 'smile':
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, my - s * 0.02), width: s * 0.14, height: s * 0.07), 0.2, pi - 0.4, false, mouthInk);
      case 'flat':
        canvas.drawLine(Offset(cx - s * 0.06, my), Offset(cx + s * 0.06, my), mouthInk);
      case 'frown':
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, my + s * 0.03), width: s * 0.14, height: s * 0.07), pi + 0.3, pi - 0.6, false, mouthInk);
      case 'grin':
      case 'gap':
        final r = Rect.fromCenter(center: Offset(cx, my), width: s * 0.18, height: s * 0.08);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.04)), Paint()..color = const Color(0xFF5D1F1F));
        canvas.drawRect(Rect.fromLTWH(r.left + s * 0.01, r.top, r.width - s * 0.02, r.height * 0.45), Paint()..color = Colors.white);
        if (look.mouth == 'gap') {
          // سن قدام ناقص
          canvas.drawRect(Rect.fromLTWH(cx - s * 0.005, r.top, s * 0.03, r.height * 0.45), Paint()..color = const Color(0xFF5D1F1F));
        }
    }

    // غطا الراس
    switch (look.hat) {
      case 'turban':
        // المصر العماني: لفات فوق الراس
        final t = Paint()..color = look.hatColor;
        final shade = Paint()..color = Color.lerp(look.hatColor, Colors.black, 0.25)!;
        canvas.drawPath(Path()
          ..moveTo(cx - fw * 0.62, s * 0.4)
          ..quadraticBezierTo(cx - fw * 0.7, s * 0.08, cx, s * 0.08)
          ..quadraticBezierTo(cx + fw * 0.7, s * 0.08, cx + fw * 0.62, s * 0.4)
          ..quadraticBezierTo(cx, s * 0.32, cx - fw * 0.62, s * 0.4), t);
        for (var i = 0; i < 3; i++) {
          final y = s * (0.18 + i * 0.07);
          canvas.drawPath(Path()
            ..moveTo(cx - fw * 0.55, y + s * 0.06)
            ..quadraticBezierTo(cx, y - s * 0.03, cx + fw * 0.55, y + s * 0.06), Paint()
            ..color = shade.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.018);
        }
        // طرف المصر
        canvas.drawPath(Path()
          ..moveTo(cx + fw * 0.5, s * 0.22)
          ..lineTo(cx + fw * 0.72, s * 0.14)
          ..lineTo(cx + fw * 0.62, s * 0.3)
          ..close(), shade);
      case 'kumma':
        // الكمّة العمانية: طاقية مطرزة
        final cap = Rect.fromLTRB(cx - fw * 0.55, s * 0.14, cx + fw * 0.55, s * 0.36);
        canvas.drawPath(Path()
          ..moveTo(cap.left, cap.bottom)
          ..quadraticBezierTo(cap.left, cap.top, cx, cap.top)
          ..quadraticBezierTo(cap.right, cap.top, cap.right, cap.bottom)
          ..close(), Paint()..color = look.hatColor);
        final emb = [const Color(0xFF8E24AA), const Color(0xFF1E88E5), const Color(0xFFE53935)];
        for (var i = 0; i < 7; i++) {
          final x = cap.left + (i + 0.5) * cap.width / 7;
          canvas.drawCircle(Offset(x, s * 0.3), s * 0.018, Paint()..color = emb[i % 3]);
          canvas.drawCircle(Offset(x, s * 0.23), s * 0.012, Paint()..color = emb[(i + 1) % 3]);
        }
      default:
        // شعر قصير
        canvas.drawPath(Path()
          ..moveTo(cx - fw * 0.5, s * 0.44)
          ..quadraticBezierTo(cx - fw * 0.55, s * 0.2, cx, s * 0.21)
          ..quadraticBezierTo(cx + fw * 0.55, s * 0.2, cx + fw * 0.5, s * 0.44)
          ..quadraticBezierTo(cx + fw * 0.3, s * 0.3, cx, s * 0.31)
          ..quadraticBezierTo(cx - fw * 0.3, s * 0.3, cx - fw * 0.5, s * 0.44), hairColor);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.look != look;
}
