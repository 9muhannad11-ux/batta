import 'dart:math';

import 'package:flutter/material.dart';

/// ألوان الثيم: رمادي على أسود، مع ألوان الفريقين، وكروم الشعار للقوائم والنوافذ.
class KoutColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF141414);
  static const surfaceHigh = Color(0xFF1F1F1F);
  static const line = Color(0xFF3A3A3A);
  static const text = Color(0xFFD6D6D6);
  static const textDim = Color(0xFF8A8A8A);
  static const accent = Color(0xFF9E9E9E);
  static const cardBack = Color(0xFF1A1A1A);
  static const redSuit = Color(0xFFD11F1F); // هاس وديمن: أحمر
  static const blackSuit = Color(0xFF111111); // سبيت وكلفس: أسود
  static const madmoon = Color(0xFF43A047); // كلمة مضمون: أخضر
  static const majbur = Color(0xFFFF8F00); // كلمة مجبور: برتقالي
  static const teamBlue = Color(0xFF5AA9FF); // الفريق الأول (أزرق فاتح)
  static const teamYellow = Color(0xFFDDA600); // الفريق الثاني (أصفر غامق شوي)
  static const gold = Color(0xFFD4AF37);
  static const win = Color(0xFF2E7D32);
  static const lose = Color(0xFFC62828);
  static const ink = Color(0xFF1D1F22); // الكتابة الغامقة على الكروم
  static const chromeEdge = Color(0xFF5A5F66);
  static const chromeButton = Color(0xFF4A4F56);

  static Color team(int t) => t == 0 ? teamBlue : teamYellow;
  static String teamName(int t) => t == 0 ? 'الأزرق' : 'الأصفر';

  /// تدرّج الكروم (نفس خلفية الشعار): فاتح فوق، يغمق بالنص، يفتح تحت
  static LinearGradient chrome([double alpha = 1]) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.18, 0.5, 0.52, 0.8, 1],
        colors: [
          const Color(0xFFF2F3F5),
          const Color(0xFFC9CCD1),
          const Color(0xFF8E939A),
          const Color(0xFF7B8087),
          const Color(0xFFA9ADB3),
          const Color(0xFFD9DBDF),
        ].map((c) => c.withValues(alpha: alpha)).toList(),
      );
}

const suitNames = {'S': 'سبيت', 'H': 'هاس', 'D': 'ديمن', 'C': 'كلفس'};
// نفس ترتيب الأوراق باليد: هاس، كلفس، ديمن، سبيت
const suitOrder = ['H', 'C', 'D', 'S'];

String rankLabel(int r) => switch (r) { 14 => 'A', 13 => 'K', 12 => 'Q', 11 => 'J', _ => '$r' };

bool isRedSuit(String s) => s == 'H' || s == 'D';
Color suitColor(String s) => isRedSuit(s) ? KoutColors.redSuit : KoutColors.blackSuit;
bool isJokerCard(String c) => c == 'JB' || c == 'JG';

/// نسبة طول الورقة لعرضها (200×290)
const cardRatio = 1.45;

/// رسم ورقة واحدة: "S-14" أو "JB" (الجوكر الكبير) أو "JG" (الجوكر الصغير).
/// الرسمة من assets/cards (مصدرها tools/card-art/deck.html والجوكرين من tools/joker-art).
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
    final radius = BorderRadius.circular(w * 0.07);
    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: w,
      height: w * cardRatio,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: highlight ? KoutColors.gold.withValues(alpha: 0.7) : Colors.black54,
            blurRadius: highlight ? 14 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      foregroundDecoration: highlight
          ? BoxDecoration(borderRadius: radius, border: Border.all(color: KoutColors.gold, width: max(2, w * 0.04)))
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset('assets/cards/$card.png', fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(onTap: enabled ? onTap : null, child: face),
    );
  }
}

/// ظهر الورقة.
class CardBack extends StatelessWidget {
  final double width;
  const CardBack({super.key, this.width = 22});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: width * cardRatio,
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

/// رمز النوع مرسوم (مو خط) بنفس أشكال الأوراق المعتمدة.
class SuitIcon extends StatelessWidget {
  final String suit;
  final double size;
  final Color? color;
  const SuitIcon(this.suit, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _SuitPainter(suit, color ?? suitColor(suit)),
      );
}

class _SuitPainter extends CustomPainter {
  final String suit;
  final Color color;
  _SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // الأشكال بإحداثيات من -1 لـ 1 (نفس tools/card-art/deck.html)
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 2.2);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    switch (suit) {
      case 'H':
        canvas.drawPath(
            Path()
              ..moveTo(0, 1.02)
              ..lineTo(-0.8, 0.08)
              ..cubicTo(-1.06, -0.2, -1.03, -0.64, -0.76, -0.87)
              ..cubicTo(-0.48, -1.08, -0.12, -0.99, 0, -0.64)
              ..cubicTo(0.12, -0.99, 0.48, -1.08, 0.76, -0.87)
              ..cubicTo(1.03, -0.64, 1.06, -0.2, 0.8, 0.08)
              ..close(),
            paint);
      case 'D':
        canvas.drawPath(
            Path()
              ..moveTo(0, -1.08)
              ..lineTo(0.86, 0)
              ..lineTo(0, 1.08)
              ..lineTo(-0.86, 0)
              ..close(),
            paint);
      case 'S':
        canvas.drawPath(
            Path()
              ..moveTo(0, -1)
              ..cubicTo(0.35, -0.6, 1, -0.25, 1, 0.25)
              ..cubicTo(1, 0.62, 0.62, 0.78, 0.3, 0.62)
              ..cubicTo(0.2, 0.58, 0.1, 0.5, 0.06, 0.42)
              ..cubicTo(0.1, 0.7, 0.2, 0.88, 0.38, 1)
              ..lineTo(-0.38, 1)
              ..cubicTo(-0.2, 0.88, -0.1, 0.7, -0.06, 0.42)
              ..cubicTo(-0.1, 0.5, -0.2, 0.58, -0.3, 0.62)
              ..cubicTo(-0.62, 0.78, -1, 0.62, -1, 0.25)
              ..cubicTo(-1, -0.25, -0.35, -0.6, 0, -1)
              ..close(),
            paint);
      case 'C':
        canvas.drawCircle(const Offset(0, -0.52), 0.47, paint);
        canvas.drawCircle(const Offset(-0.53, 0.12), 0.47, paint);
        canvas.drawCircle(const Offset(0.53, 0.12), 0.47, paint);
        canvas.drawCircle(const Offset(0, 0.06), 0.24, paint);
        canvas.drawPath(
            Path()
              ..moveTo(-0.08, 0.2)
              ..cubicTo(-0.11, 0.6, -0.22, 0.86, -0.42, 1.02)
              ..lineTo(0.42, 1.02)
              ..cubicTo(0.22, 0.86, 0.11, 0.6, 0.08, 0.2)
              ..close(),
            paint);
    }
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}

/// حرف J الذهبي اللماع (إشارة الجوكر): خط كلاسيكي عريض، تدرّج ذهبي وحد بني رفيع.
class GoldJ extends StatelessWidget {
  final double size;
  const GoldJ({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'serif', fontFamilyFallback: const ['Times New Roman', 'Georgia'], fontSize: size, fontWeight: FontWeight.w900, height: 1);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Stack(children: [
          Text('J',
              style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = max(1.5, size * 0.09)
                    ..color = const Color(0xFF5A3A0A))),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, 0.35, 0.5, 0.65, 1],
              colors: [Color(0xFFFFF4C2), Color(0xFFF5C84A), Color(0xFFFFFBE6), Color(0xFFD9A21E), Color(0xFF8C5E0C)],
            ).createShader(r),
            child: Text('J', style: style.copyWith(color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}
