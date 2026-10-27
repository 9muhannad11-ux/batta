import 'dart:math';

import 'package:flutter/material.dart';

/// ألوان الثيم: رمادي على أسود، مع ألوان الفريقين.
class KoutColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF141414);
  static const surfaceHigh = Color(0xFF1F1F1F);
  static const line = Color(0xFF3A3A3A);
  static const text = Color(0xFFD6D6D6);
  static const textDim = Color(0xFF8A8A8A);
  static const accent = Color(0xFF9E9E9E);
  static const cardFace = Color(0xFFFFFFFF); // وجه الورقة أبيض
  static const cardBorder = Color(0xFFBDBDBD);
  static const cardBack = Color(0xFF1A1A1A);
  static const redSuit = Color(0xFFD32F2F); // هاس وديمن: أحمر
  static const blackSuit = Color(0xFF111111); // سبيت وكلفس: أسود
  static const madmoon = Color(0xFF43A047); // كلمة مضمون: أخضر
  static const teamBlue = Color(0xFF3D8BFF); // الفريق الأول
  static const teamYellow = Color(0xFFF5C518); // الفريق الثاني
  static const gold = Color(0xFFD4AF37);
  static const win = Color(0xFF2E7D32);
  static const lose = Color(0xFFC62828);

  static Color team(int t) => t == 0 ? teamBlue : teamYellow;
  static String teamName(int t) => t == 0 ? 'الأزرق' : 'الأصفر';
}

const suitNames = {'S': 'سبيت', 'H': 'هاس', 'D': 'ديمن', 'C': 'كلفس'};
// نفس ترتيب الأوراق باليد: هاس، كلفس، ديمن، سبيت
const suitOrder = ['H', 'C', 'D', 'S'];

String rankLabel(int r) => switch (r) { 14 => 'A', 13 => 'K', 12 => 'Q', 11 => 'J', _ => '$r' };
String? rankName(int r) => switch (r) { 14 => 'خال', 13 => 'باشه', 12 => 'ميمه', 11 => 'غلام', _ => null };

bool isRedSuit(String s) => s == 'H' || s == 'D';
Color suitColor(String s) => isRedSuit(s) ? KoutColors.redSuit : KoutColors.blackSuit;

/// رسم ورقة واحدة: "S-14" أو "JB" (الجوكر الكبير) أو "JG" (الجوكر الصغير).
class PlayingCard extends StatelessWidget {
  final String card;
  final double width;
  final bool enabled;
  final bool highlight;
  final VoidCallback? onTap;

  const PlayingCard(this.card, {super.key, this.width = 54, this.enabled = true, this.highlight = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * 1.45;
    final isJoker = card == 'JB' || card == 'JG';
    final children = <Widget>[];

    if (isJoker) {
      final big = card == 'JB';
      final c = big ? const Color(0xFF7B1FA2) : const Color(0xFF555555);
      children.addAll([
        Positioned.fill(
          top: h * 0.2,
          bottom: h * 0.04,
          left: w * 0.06,
          right: w * 0.06,
          child: CustomPaint(painter: ClownPainter(colored: big)),
        ),
        Positioned(
          top: w * 0.04,
          left: w * 0.06,
          child: Text('★', style: TextStyle(color: c, fontSize: w * 0.22, height: 1, fontWeight: FontWeight.bold)),
        ),
        Positioned(
          top: w * 0.05,
          right: w * 0.06,
          child: Text(big ? 'الكبير' : 'الصغير',
              style: TextStyle(color: c, fontSize: w * 0.17, height: 1, fontWeight: FontWeight.bold)),
        ),
      ]);
    } else {
      final parts = card.split('-');
      final suit = parts[0];
      final rank = int.parse(parts[1]);
      final color = suitColor(suit);
      final name = rankName(rank);
      // الوسط: نقاط بعدد الرقم، أو صورة للباشه والميمه والغلام، أو رمز كبير للخال
      final inner = Rect.fromLTRB(w * 0.24, h * 0.17, w * 0.76, h * 0.92);
      if (rank >= 11 && rank <= 13) {
        children.add(Positioned.fromRect(
          rect: Rect.fromLTRB(w * 0.18, h * 0.2, w * 0.82, h * 0.95),
          child: CustomPaint(painter: CourtPainter(rank: rank, suit: suit)),
        ));
      } else if (rank == 14) {
        children.add(Positioned.fill(
          top: h * 0.18,
          child: Center(child: SuitIcon(suit, size: w * 0.62, color: color)),
        ));
      } else {
        final pip = w * 0.19;
        for (final p in pipLayout(rank)) {
          final cx = inner.left + p.dx * inner.width;
          final cy = inner.top + p.dy * inner.height;
          children.add(Positioned(
            left: cx - pip / 2,
            top: cy - pip / 2,
            child: Transform.rotate(angle: p.dy > 0.55 ? pi : 0, child: SuitIcon(suit, size: pip, color: color)),
          ));
        }
      }
      // فوق يسار: الحرف أو الرقم مع النوع
      children.add(Positioned(
        top: w * 0.04,
        left: w * 0.05,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(rankLabel(rank),
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: w * 0.27, height: 1)),
            const SizedBox(height: 1),
            SuitIcon(suit, size: w * 0.17, color: color),
          ]),
        ),
      ));
      // فوق يمين: اسم الورقة
      if (name != null) {
        children.add(Positioned(
          top: w * 0.05,
          right: w * 0.05,
          child: Text(name, style: TextStyle(color: color, fontSize: w * 0.17, height: 1, fontWeight: FontWeight.bold)),
        ));
      }
    }

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: KoutColors.cardFace,
        borderRadius: BorderRadius.circular(w * 0.1),
        border: Border.all(color: highlight ? KoutColors.gold : KoutColors.cardBorder, width: highlight ? 3 : 1),
        boxShadow: [
          BoxShadow(color: highlight ? KoutColors.gold.withValues(alpha: 0.6) : Colors.black, blurRadius: highlight ? 14 : 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(w * 0.1), child: Stack(children: children)),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(onTap: enabled ? onTap : null, child: face),
    );
  }
}

/// أماكن النقاط على الورقة (نسبة من المساحة الداخلية)، مثل الورق المعروف.
List<Offset> pipLayout(int n) {
  const l = 0.0, c = 0.5, r = 1.0;
  return switch (n) {
    2 => const [Offset(c, 0), Offset(c, 1)],
    3 => const [Offset(c, 0), Offset(c, 0.5), Offset(c, 1)],
    4 => const [Offset(l, 0), Offset(r, 0), Offset(l, 1), Offset(r, 1)],
    5 => const [Offset(l, 0), Offset(r, 0), Offset(c, 0.5), Offset(l, 1), Offset(r, 1)],
    6 => const [Offset(l, 0), Offset(r, 0), Offset(l, 0.5), Offset(r, 0.5), Offset(l, 1), Offset(r, 1)],
    7 => const [Offset(l, 0), Offset(r, 0), Offset(c, 0.25), Offset(l, 0.5), Offset(r, 0.5), Offset(l, 1), Offset(r, 1)],
    8 => const [Offset(l, 0), Offset(r, 0), Offset(c, 0.25), Offset(l, 0.5), Offset(r, 0.5), Offset(c, 0.75), Offset(l, 1), Offset(r, 1)],
    9 => const [Offset(l, 0), Offset(r, 0), Offset(l, 1 / 3), Offset(r, 1 / 3), Offset(c, 0.5), Offset(l, 2 / 3), Offset(r, 2 / 3), Offset(l, 1), Offset(r, 1)],
    10 => const [Offset(l, 0), Offset(r, 0), Offset(c, 1 / 6), Offset(l, 1 / 3), Offset(r, 1 / 3), Offset(l, 2 / 3), Offset(r, 2 / 3), Offset(c, 5 / 6), Offset(l, 1), Offset(r, 1)],
    _ => const [],
  };
}

/// صورة الباشه والميمه والغلام: نص شخصية فوق ونفسها مقلوبة تحت، مثل الورق المعروف.
class CourtPainter extends CustomPainter {
  final int rank;
  final String suit;
  CourtPainter({required this.rank, required this.suit});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final main = suitColor(suit);
    final frame = Paint()
      ..color = main.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, frame);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _half(canvas, w, h / 2, main);
    canvas.translate(w, h);
    canvas.rotate(pi);
    _half(canvas, w, h / 2, main);
    canvas.restore();
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), frame);
  }

  void _half(Canvas canvas, double w, double h, Color main) {
    final gold = Paint()..color = const Color(0xFFE0A526);
    final skin = Paint()..color = const Color(0xFFF2C9A0);
    final ink = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.02);
    final robe = Paint()..color = main;
    final second = Paint()..color = isRedSuit(suit) ? const Color(0xFF1E3A8A) : const Color(0xFFB71C1C);

    // الكتوف والثوب
    final body = Path()
      ..moveTo(w * 0.08, h)
      ..lineTo(w * 0.18, h * 0.62)
      ..quadraticBezierTo(w * 0.5, h * 0.5, w * 0.82, h * 0.62)
      ..lineTo(w * 0.92, h)
      ..close();
    canvas.drawPath(body, robe);
    canvas.drawPath(Path()
      ..moveTo(w * 0.4, h * 0.58)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.6, h * 0.58)
      ..close(), second);
    canvas.drawPath(body, ink);
    // الياقة
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.6, w * 0.4, h * 0.06), gold);

    // الراس
    final head = Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.34, height: h * 0.34);
    canvas.drawOval(head, skin);
    canvas.drawOval(head, ink);
    // الملامح: حواجب وعيون وخشم وفم
    final eye = Paint()..color = Colors.black;
    final brow = Paint()
      ..color = rank == 13 ? const Color(0xFFE0E0E0) : const Color(0xFF3E2723)
      ..strokeWidth = max(1, w * 0.025)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.39, h * 0.365), Offset(w * 0.47, h * 0.37), brow);
    canvas.drawLine(Offset(w * 0.53, h * 0.37), Offset(w * 0.61, h * 0.365), brow);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.43, h * 0.41), width: w * 0.06, height: h * 0.035), Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.57, h * 0.41), width: w * 0.06, height: h * 0.035), Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.43, h * 0.41), w * 0.018, eye);
    canvas.drawCircle(Offset(w * 0.57, h * 0.41), w * 0.018, eye);
    canvas.drawPath(Path()
      ..moveTo(w * 0.5, h * 0.41)
      ..lineTo(w * 0.475, h * 0.47)
      ..lineTo(w * 0.52, h * 0.47), Paint()
      ..color = const Color(0xFFB9825A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.018));
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.1, height: h * 0.04), 0.2, pi - 0.4, false,
        Paint()
          ..color = const Color(0xFFB71C1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, w * 0.02));

    switch (rank) {
      case 13: // باشه: تاج ولحية بيضاء وشنب كثيف أبيض
        final white = Paint()..color = const Color(0xFFF5F5F5);
        final whiteInk = Paint()
          ..color = const Color(0xFF9E9E9E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, w * 0.012);
        final beard = Path()
          ..moveTo(w * 0.33, h * 0.44)
          ..quadraticBezierTo(w * 0.32, h * 0.62, w * 0.5, h * 0.7)
          ..quadraticBezierTo(w * 0.68, h * 0.62, w * 0.67, h * 0.44)
          ..quadraticBezierTo(w * 0.5, h * 0.54, w * 0.33, h * 0.44);
        canvas.drawPath(beard, white);
        canvas.drawPath(beard, whiteInk);
        // خطوط اللحية
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(Offset(w * (0.5 + i * 0.05), h * 0.56), Offset(w * (0.5 + i * 0.045), h * 0.66), whiteInk);
        }
        // شنب كثيف
        final mustache = Path()
          ..moveTo(w * 0.5, h * 0.475)
          ..quadraticBezierTo(w * 0.4, h * 0.45, w * 0.33, h * 0.5)
          ..quadraticBezierTo(w * 0.4, h * 0.52, w * 0.5, h * 0.495)
          ..quadraticBezierTo(w * 0.6, h * 0.52, w * 0.67, h * 0.5)
          ..quadraticBezierTo(w * 0.6, h * 0.45, w * 0.5, h * 0.475);
        canvas.drawPath(mustache, white);
        canvas.drawPath(mustache, whiteInk);
        final crown = Path()
          ..moveTo(w * 0.32, h * 0.29)
          ..lineTo(w * 0.32, h * 0.14)
          ..lineTo(w * 0.41, h * 0.22)
          ..lineTo(w * 0.5, h * 0.08)
          ..lineTo(w * 0.59, h * 0.22)
          ..lineTo(w * 0.68, h * 0.14)
          ..lineTo(w * 0.68, h * 0.29)
          ..close();
        canvas.drawPath(crown, gold);
        canvas.drawPath(crown, ink);
        // صولجان
        canvas.drawLine(Offset(w * 0.86, h * 0.95), Offset(w * 0.78, h * 0.35), ink..strokeWidth = w * 0.035);
        canvas.drawCircle(Offset(w * 0.78, h * 0.33), w * 0.05, gold);
      case 12: // ميمه: تاج صغير وشعر طويل ووردة
        final hair = Paint()..color = const Color(0xFF4E342E);
        canvas.drawPath(Path()
          ..moveTo(w * 0.32, h * 0.42)
          ..quadraticBezierTo(w * 0.3, h * 0.2, w * 0.5, h * 0.22)
          ..quadraticBezierTo(w * 0.7, h * 0.2, w * 0.68, h * 0.42)
          ..lineTo(w * 0.72, h * 0.62)
          ..lineTo(w * 0.62, h * 0.5)
          ..lineTo(w * 0.38, h * 0.5)
          ..lineTo(w * 0.28, h * 0.62)
          ..close(), hair);
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.43), width: w * 0.26, height: h * 0.26), skin);
        // ملامح الميمه: حواجب رفيعة، عيون برموش، خدود وشفايف حمرا
        final thin = Paint()
          ..color = const Color(0xFF3E2723)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, w * 0.012);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.45, h * 0.395), width: w * 0.07, height: h * 0.03), pi, pi, false, thin);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.55, h * 0.395), width: w * 0.07, height: h * 0.03), pi, pi, false, thin);
        for (final x in [0.45, 0.55]) {
          canvas.drawCircle(Offset(w * x, h * 0.42), w * 0.018, eye);
          for (var k = -1; k <= 1; k++) {
            canvas.drawLine(Offset(w * (x + k * 0.012), h * 0.408), Offset(w * (x + k * 0.02), h * 0.398), thin);
          }
        }
        final blush = Paint()..color = const Color(0x55E57373);
        canvas.drawCircle(Offset(w * 0.42, h * 0.46), w * 0.025, blush);
        canvas.drawCircle(Offset(w * 0.58, h * 0.46), w * 0.025, blush);
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.485), width: w * 0.07, height: h * 0.025), Paint()..color = const Color(0xFFC62828));
        final tiara = Path()
          ..moveTo(w * 0.38, h * 0.24)
          ..lineTo(w * 0.44, h * 0.15)
          ..lineTo(w * 0.5, h * 0.21)
          ..lineTo(w * 0.56, h * 0.15)
          ..lineTo(w * 0.62, h * 0.24)
          ..close();
        canvas.drawPath(tiara, gold);
        // وردة
        final flower = Paint()..color = second.color;
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * pi / 5;
          canvas.drawCircle(Offset(w * 0.2 + cos(a) * w * 0.045, h * 0.8 + sin(a) * w * 0.045), w * 0.04, flower);
        }
        canvas.drawCircle(Offset(w * 0.2, h * 0.8), w * 0.03, gold);
      case 11: // غلام: قبعة بريشة
        final hat = Path()
          ..moveTo(w * 0.28, h * 0.3)
          ..quadraticBezierTo(w * 0.5, h * 0.06, w * 0.72, h * 0.3)
          ..close();
        canvas.drawPath(hat, second);
        canvas.drawPath(hat, ink);
        canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.27, w * 0.44, h * 0.05), gold);
        canvas.drawPath(Path()
          ..moveTo(w * 0.66, h * 0.24)
          ..quadraticBezierTo(w * 0.95, h * 0.02, w * 0.86, h * 0.3)
          ..quadraticBezierTo(w * 0.8, h * 0.18, w * 0.66, h * 0.24), Paint()..color = const Color(0xFF2E7D32));
        // شنب أسود
        canvas.drawPath(Path()
          ..moveTo(w * 0.5, h * 0.478)
          ..quadraticBezierTo(w * 0.42, h * 0.46, w * 0.37, h * 0.495)
          ..quadraticBezierTo(w * 0.43, h * 0.5, w * 0.5, h * 0.492)
          ..quadraticBezierTo(w * 0.57, h * 0.5, w * 0.63, h * 0.495)
          ..quadraticBezierTo(w * 0.58, h * 0.46, w * 0.5, h * 0.478), Paint()..color = const Color(0xFF111111));
        // سيف
        canvas.drawLine(Offset(w * 0.14, h * 0.95), Offset(w * 0.22, h * 0.4), ink..strokeWidth = w * 0.03);
        canvas.drawLine(Offset(w * 0.1, h * 0.78), Offset(w * 0.26, h * 0.8), ink);
    }
  }

  @override
  bool shouldRepaint(CourtPainter old) => old.rank != rank || old.suit != suit;
}

/// مهرج بملامح شريرة: ملوّن للجوكر الكبير، ورمادي للجوكر الصغير.
class ClownPainter extends CustomPainter {
  final bool colored;
  ClownPainter({required this.colored});

  Color _c(Color color) {
    if (colored) return color;
    final g = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    return Color.from(alpha: 1, red: g, green: g, blue: g);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = min(w, h * 0.8);
    final cx = w / 2, cy = h * 0.55;
    Paint p(Color c) => Paint()..color = _c(c);
    final ink = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, s * 0.025);

    // قبعة المهرج بثلاث رؤوس وأجراس
    final hatColors = [const Color(0xFFD32F2F), const Color(0xFF7B1FA2), const Color(0xFF2E7D32)];
    final tips = [Offset(cx - s * 0.48, cy - s * 0.42), Offset(cx, cy - s * 0.72), Offset(cx + s * 0.48, cy - s * 0.42)];
    for (var i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(cx - s * 0.32 + i * s * 0.2, cy - s * 0.22)
        ..quadraticBezierTo(tips[i].dx * 0.7 + cx * 0.3, tips[i].dy + s * 0.1, tips[i].dx, tips[i].dy)
        ..lineTo(cx - s * 0.12 + i * s * 0.2, cy - s * 0.24)
        ..close();
      canvas.drawPath(path, p(hatColors[i]));
      canvas.drawPath(path, ink);
      canvas.drawCircle(tips[i], s * 0.06, p(const Color(0xFFFFC107)));
      canvas.drawCircle(tips[i], s * 0.06, ink);
    }

    // الشعر المنفوش على الجنب
    final hair = p(const Color(0xFFFF5722));
    for (final side in [-1, 1]) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(cx + side * s * (0.36 + i * 0.03), cy - s * 0.05 + i * s * 0.1), s * 0.1, hair);
      }
    }

    // الوجه
    final face = Rect.fromCenter(center: Offset(cx, cy), width: s * 0.66, height: s * 0.72);
    canvas.drawOval(face, Paint()..color = const Color(0xFFF5F5F5));
    canvas.drawOval(face, ink);

    // حواجب شريرة
    final brow = Paint()
      ..color = Colors.black
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - s * 0.24, cy - s * 0.2), Offset(cx - s * 0.06, cy - s * 0.12), brow);
    canvas.drawLine(Offset(cx + s * 0.24, cy - s * 0.2), Offset(cx + s * 0.06, cy - s * 0.12), brow);

    // نقوش العيون (معيّن) والعيون
    for (final side in [-1, 1]) {
      final ex = cx + side * s * 0.14;
      final diamond = Path()
        ..moveTo(ex, cy - s * 0.17)
        ..lineTo(ex + s * 0.07, cy - s * 0.06)
        ..lineTo(ex, cy + s * 0.08)
        ..lineTo(ex - s * 0.07, cy - s * 0.06)
        ..close();
      canvas.drawPath(diamond, p(const Color(0xFF1565C0)));
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, cy - s * 0.06), width: s * 0.09, height: s * 0.06), Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: colored ? 1 : 0.9));
      canvas.drawCircle(Offset(ex + side * -s * 0.01, cy - s * 0.06), s * 0.022, Paint()..color = Colors.black);
    }

    // الخشم الأحمر
    canvas.drawCircle(Offset(cx, cy + s * 0.04), s * 0.075, p(const Color(0xFFE53935)));
    canvas.drawCircle(Offset(cx - s * 0.02, cy + s * 0.02), s * 0.02, Paint()..color = Colors.white70);

    // ابتسامة شريرة عريضة بأسنان
    final mouth = Path()
      ..moveTo(cx - s * 0.26, cy + s * 0.1)
      ..quadraticBezierTo(cx, cy + s * 0.42, cx + s * 0.26, cy + s * 0.1)
      ..quadraticBezierTo(cx, cy + s * 0.24, cx - s * 0.26, cy + s * 0.1)
      ..close();
    canvas.drawPath(mouth, p(const Color(0xFFB71C1C)));
    final teeth = Paint()..color = Colors.white;
    for (var i = -3; i <= 3; i++) {
      final tx = cx + i * s * 0.055;
      canvas.drawPath(Path()
        ..moveTo(tx - s * 0.022, cy + s * 0.19 - (i.abs() * s * 0.012))
        ..lineTo(tx + s * 0.022, cy + s * 0.19 - (i.abs() * s * 0.012))
        ..lineTo(tx, cy + s * 0.25 - (i.abs() * s * 0.015))
        ..close(), teeth);
    }
    canvas.drawPath(mouth, ink);
  }

  @override
  bool shouldRepaint(ClownPainter old) => old.colored != colored;
}

/// ظهر الورقة.
class CardBack extends StatelessWidget {
  final double width;
  const CardBack({super.key, this.width = 22});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: width * 1.45,
        decoration: BoxDecoration(
          color: const Color(0xFF263238),
          borderRadius: BorderRadius.circular(width * 0.1),
          border: Border.all(color: const Color(0xFFB0BEC5), width: max(1, width * 0.04)),
        ),
        child: Center(
          child: Container(
            width: width * 0.6,
            height: width * 1.0,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF90A4AE), width: 1),
              borderRadius: BorderRadius.circular(width * 0.06),
            ),
          ),
        ),
      );
}

/// رمز النوع مرسوم (مو خط) عشان يطلع بنفس الشكل على كل الأجهزة.
class SuitIcon extends StatelessWidget {
  final String suit;
  final double size;
  final Color? color;
  const SuitIcon(this.suit, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        // خارج الورق الخلفية سوداء، فالسبيت والكلفس يطلعون فاتحين
        painter: _SuitPainter(suit, color ?? (isRedSuit(suit) ? KoutColors.redSuit : KoutColors.text)),
      );
}

class _SuitPainter extends CustomPainter {
  final String suit;
  final Color color;
  _SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    Offset p(double x, double y) => Offset(x * s, y * s);
    void circle(double x, double y, double r) => canvas.drawCircle(p(x, y), r * s, paint);
    void poly(List<List<double>> pts) {
      final path = Path()..moveTo(pts[0][0] * s, pts[0][1] * s);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt[0] * s, pt[1] * s);
      }
      canvas.drawPath(path..close(), paint);
    }

    switch (suit) {
      case 'H':
        circle(0.29, 0.35, 0.22);
        circle(0.71, 0.35, 0.22);
        poly([[0.08, 0.42], [0.92, 0.42], [0.5, 0.92]]);
      case 'D':
        poly([[0.5, 0.04], [0.86, 0.5], [0.5, 0.96], [0.14, 0.5]]);
      case 'S':
        circle(0.29, 0.58, 0.2);
        circle(0.71, 0.58, 0.2);
        poly([[0.1, 0.52], [0.9, 0.52], [0.5, 0.04]]);
        poly([[0.5, 0.6], [0.68, 0.96], [0.32, 0.96]]);
      case 'C':
        circle(0.5, 0.27, 0.2);
        circle(0.27, 0.57, 0.2);
        circle(0.73, 0.57, 0.2);
        poly([[0.5, 0.45], [0.66, 0.96], [0.34, 0.96]]);
    }
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}

/// أيقونة إشارة الجوكر (وجه المهرج الصغير).
class JokerSignalIcon extends StatelessWidget {
  final double size;
  const JokerSignalIcon({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: ClownPainter(colored: true)),
      );
}
