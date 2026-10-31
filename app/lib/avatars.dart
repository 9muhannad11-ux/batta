import 'dart:math';

import 'package:flutter/material.dart';

/// شكل كل شخصية. كلهم بنفس التوجه الفني (مثل ود عمتيه): رسم أقرب للواقعي بتظليل خفيف وحدود سودا رفيعة.
class _Look {
  final Color skin;
  final String head; // kumma (كمّة السويق)، kummaWhite (كمّة بيضاء)، kummaBrown (بيضاء بتطريز بني)، turban (مصر)، hair (شعر قصير)
  final Color headColor; // لون المصر
  final String beard; // none, stubble, light, short, full, goatee
  final String mustache; // none, light, thick
  final String brows; // calm, sharp, angry, sad, thick
  final String eyes; // calm, open, closed, smile (الخد يرفع الجفن التحتاني)
  final String mouth; // neutral, smile, frown, grin, gap
  final bool thin;
  final double tilt; // ميلان غطا الراس
  final String nose; // normal, long
  final double eyeSize; // حجم العيون (1 = العادي)
  final Color robe; // لون الدشداشة
  final bool white; // لحية وشنب وحواجب بيض
  final bool old; // كبير بالسن: تجاعيد
  const _Look({
    required this.skin,
    this.head = 'hair',
    this.headColor = Colors.white,
    this.beard = 'none',
    this.mustache = 'none',
    this.brows = 'calm',
    this.eyes = 'open',
    this.mouth = 'neutral',
    this.thin = false,
    this.tilt = 0,
    this.nose = 'normal',
    this.eyeSize = 1,
    this.robe = const Color(0xFFF7F7F4),
    this.white = false,
    this.old = false,
  });
}

const _looks = <String, _Look>{
  // خلفان التفق: ملامح عمانية ومصر أحمر، شنب كثيف
  'khalfan': _Look(skin: Color(0xFFC68E5E), robe: Color(0xFFB7C7D6), head: 'turban', headColor: Color(0xFFC62828), mustache: 'thick', beard: 'stubble', mouth: 'smile'),
  // خصيب: ملامح حادة ومصر حليبي، لحية قصيرة
  'khusaib': _Look(skin: Color(0xFFB97A4F), robe: Color(0xFFEFE6CF), head: 'turban', headColor: Color(0xFFF3E9D2), brows: 'sharp', beard: 'short', mustache: 'light'),
  // مرهون: شايب عمره 80، ملامح فقر ومصر بني فاتح، وجه نحيف بتجاعيد ولحية بيضاء
  'marhoon': _Look(skin: Color(0xFFBE8C64), robe: Color(0xFF8C6E52), head: 'turban', headColor: Color(0xFFC8A27A), brows: 'sad', eyes: 'calm', mouth: 'frown', beard: 'full', mustache: 'thick', thin: true, white: true, old: true),
  // مصبّح: ملامح هادئة وكمّة عمانية بيضاء، عيون مسكّرة مبتسمة
  'musabbah': _Look(skin: Color(0xFFC9946A), robe: Color(0xFFF7F7F4), head: 'kummaWhite', beard: 'short', mustache: 'light', eyes: 'closed', mouth: 'smile'),
  // محمد بو ضرس: مايل للسمار وناقصه سن قدام
  'bodhirs': _Look(skin: Color(0xFF9C6B43), robe: Color(0xFF9FC1E6), mouth: 'gap', mustache: 'thick'),
  // عبدو اليابس: قوة وصلابة ولحية مو كبيرة تغطي الوجه
  'abdo': _Look(skin: Color(0xFFB07A4F), robe: Color(0xFF5E6368), brows: 'sharp', beard: 'full', mustache: 'thick'),
  // صديق: من بنجلاديش، نحيف وشنب
  'sadiq': _Look(skin: Color(0xFF8D5A3B), robe: Color(0xFF9CC7A0), mustache: 'thick', thin: true, mouth: 'smile'),
  // المنضغط: ملامح غاضبة وسكسوكة
  'mundaghit': _Look(skin: Color(0xFFBF8A60), robe: Color(0xFF8A4545), brows: 'angry', mouth: 'frown', beard: 'goatee', mustache: 'light'),
  // بو حمدان: كمّة بيضاء بتطريز بني، وجه حاد، عيون صغيرة، حواجب كثيفة، خشم طويل، شنب ولحية خفيفة على الذقن
  'buhamdan': _Look(skin: Color(0xFFC99470), robe: Color(0xFFCFE2EA), head: 'kummaBrown', brows: 'thick', eyes: 'open', eyeSize: 0.8, mustache: 'thick', beard: 'chin', nose: 'long', thin: true),
  // ود عمتيه: من ولاية السويق، كمّة مطرزة مايلة شوي، لحية وشنب خفيفين
  'wadamtih': _Look(skin: Color(0xFFC4895C), robe: Color(0xFFD8C9A8), head: 'kumma', beard: 'light', mustache: 'light', eyes: 'calm', tilt: 0.12),
};

class CharacterAvatar extends StatelessWidget {
  final String? charId;
  final double size;
  final Color ring;
  final Color? background; // لون الفريق (وإلا سماوي فاتح)
  final bool talking; // الفم يتحرك (وقت ما يشتغل صوت الشخصية)
  final double? mouth; // فتحة فم ثابتة (للمعاينة)
  const CharacterAvatar({
    super.key,
    required this.charId,
    this.size = 48,
    this.ring = Colors.transparent,
    this.background,
    this.talking = false,
    this.mouth,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background;
    const pop = 0.28; // قد إيش يطلع الراس فوق الإطار (نسبة من المقاس)
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topLeft, children: [
        // الإطار والخلفية
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.3),
              radius: 0.75,
              colors: bg == null ? const [Color(0xFFE6F6FF), Color(0xFFA9DCF5)] : [Color.lerp(bg, Colors.white, 0.45)!, bg],
            ),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
            border: Border.all(color: ring, width: max(2.5, size * 0.075)),
          ),
        ),
        // الشخصية أكبر: تحت محصورة بالدائرة، وفوق الراس يطلع برا الإطار شوي
        Positioned(
          left: 0,
          top: -size * pop,
          width: size,
          height: size * (1 + pop),
          child: ClipPath(
            clipper: _PopOutClipper(pop),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topLeft, children: [
              Positioned(
                left: 0,
                top: size * pop,
                width: size,
                height: size,
                child: Transform.scale(
                  scale: 1.3,
                  alignment: const Alignment(0, 0.62),
                  child: _Face(charId: charId, talking: talking, mouth: mouth),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// الدائرة من تحت (داخل الإطار)، ومن نصها لفوق مفتوح عشان الراس يطلع برا الإطار
class _PopOutClipper extends CustomClipper<Path> {
  final double pop;
  const _PopOutClipper(this.pop);

  @override
  Path getClip(Size box) {
    final s = box.width;
    final top = s * pop;
    final inner = s * 0.5 - max(2.5, s * 0.075) * 0.5; // داخل الحلقة
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(s / 2, top + s / 2), radius: inner))
      ..addRect(Rect.fromLTRB(s * 0.08, 0, s * 0.92, top + s * 0.42));
  }

  @override
  bool shouldReclip(_PopOutClipper old) => old.pop != pop;
}

/// الوجه، والفم يفتح ويسكّر مثل الكلام طول ما talking
class _Face extends StatefulWidget {
  final String? charId;
  final bool talking;
  final double? mouth;
  const _Face({required this.charId, required this.talking, this.mouth});

  @override
  State<_Face> createState() => _FaceState();
}

class _FaceState extends State<_Face> with SingleTickerProviderStateMixin {
  late final AnimationController _talk = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (widget.talking) _talk.repeat();
  }

  @override
  void didUpdateWidget(_Face old) {
    super.didUpdateWidget(old);
    if (widget.talking && !_talk.isAnimating) _talk.repeat();
    if (!widget.talking && _talk.isAnimating) _talk.stop();
  }

  @override
  void dispose() {
    _talk.dispose();
    super.dispose();
  }

  // مقاطع كلام: فتحات سريعة بأحجام مختلفة
  double _mouthAt(double t) {
    final syll = (0.5 + 0.5 * sin(t * 2 * pi * 14)).toDouble();
    final phrase = (0.55 + 0.45 * sin(t * 2 * pi * 3.1 + 1)).toDouble();
    return syll * phrase;
  }

  CustomPainter _painter(double m) => _FacePainter(_looks[widget.charId] ?? _looks['musabbah']!, mouth: m);

  @override
  Widget build(BuildContext context) {
    if (widget.mouth != null || !widget.talking) return CustomPaint(painter: _painter(widget.mouth ?? 0));
    return AnimatedBuilder(animation: _talk, builder: (_, _) => CustomPaint(painter: _painter(_mouthAt(_talk.value))));
  }
}

/// رسم الشخصية: دشداشة، رقبة، أذون، وجه بتظليل، لحية/شنب، حواجب، عيون، خشم، فم، وغطا راس.
class _FacePainter extends CustomPainter {
  final _Look look;
  final double mouth; // فتحة الفم وقت الكلام (0 مسكّر، 1 مفتوح)
  _FacePainter(this.look, {this.mouth = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final line = Paint()
      ..color = const Color(0xFF2A2420)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, s * 0.011)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, s * w)
      ..strokeCap = StrokeCap.round;
    final skinMid = look.skin;
    final skinLight = Color.lerp(look.skin, Colors.white, 0.22)!;
    final skinDark = Color.lerp(look.skin, Colors.black, 0.22)!;
    final hw = look.thin ? s * 0.18 : s * 0.2; // نص عرض الوجه

    // بنفس حجم الإطار
    canvas.translate(cx, s * 0.66);
    canvas.scale(1.1);
    canvas.translate(-cx, -s * 0.66);

    // الدشداشة: بيضاء بظل خفيف
    final robe = Path()
      ..moveTo(s * 0.06, s * 1.02)
      ..quadraticBezierTo(s * 0.12, s * 0.8, cx - s * 0.12, s * 0.76)
      ..lineTo(cx + s * 0.12, s * 0.76)
      ..quadraticBezierTo(s * 0.88, s * 0.8, s * 0.94, s * 1.02)
      ..close();
    canvas.drawPath(
        robe,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(look.robe, Colors.white, 0.35)!, look.robe, Color.lerp(look.robe, Colors.black, 0.12)!])
              .createShader(Rect.fromLTWH(0, s * 0.74, s, s * 0.3)));
    canvas.drawPath(robe, line);
    // الرقبة
    final neck = Path()
      ..moveTo(cx - s * 0.085, s * 0.66)
      ..lineTo(cx - s * 0.095, s * 0.79)
      ..quadraticBezierTo(cx, s * 0.84, cx + s * 0.095, s * 0.79)
      ..lineTo(cx + s * 0.085, s * 0.66)
      ..close();
    canvas.drawPath(neck, fill(skinMid));
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.085, s * 0.68)
          ..quadraticBezierTo(cx, s * 0.74, cx + s * 0.085, s * 0.68)
          ..lineTo(cx + s * 0.085, s * 0.66)
          ..lineTo(cx - s * 0.085, s * 0.66),
        fill(skinDark.withValues(alpha: 0.6)));
    canvas.drawPath(neck, line);
    // فتحة الدشداشة والفراخة (الشرابة)
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.1, s * 0.79)
          ..quadraticBezierTo(cx, s * 0.86, cx + s * 0.1, s * 0.79),
        line);
    canvas.drawLine(Offset(cx, s * 0.84), Offset(cx, s * 0.97), line);
    final tassel = Color.lerp(look.robe, Colors.black, 0.2)!;
    canvas.drawLine(Offset(cx, s * 0.86), Offset(cx + s * 0.012, s * 0.98), Paint()..color = tassel..strokeWidth = s * 0.012);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.005, s * 0.99), width: s * 0.03, height: s * 0.05), fill(Color.lerp(tassel, Colors.white, 0.3)!));

    // الأذون
    for (final side in [-1.0, 1.0]) {
      final ear = Rect.fromCenter(center: Offset(cx + side * (hw + s * 0.015), s * 0.47), width: s * 0.07, height: s * 0.12);
      canvas.drawOval(ear, fill(skinMid));
      canvas.drawOval(ear, line);
      canvas.drawArc(ear.deflate(s * 0.015), side < 0 ? pi * 0.6 : -pi * 0.4, pi * 0.8, false, stroke(const Color(0xFF2A2420), 0.008));
    }

    // الوجه: بيضاوي بفك واضح، وتظليل من اليمين
    final face = Path()
      ..moveTo(cx - hw, s * 0.36)
      ..quadraticBezierTo(cx - hw * 1.075, s * 0.56, cx - hw * 0.7, s * 0.65)
      ..quadraticBezierTo(cx - hw * 0.3, s * 0.73, cx, s * 0.73)
      ..quadraticBezierTo(cx + hw * 0.3, s * 0.73, cx + hw * 0.7, s * 0.65)
      ..quadraticBezierTo(cx + hw * 1.075, s * 0.56, cx + hw, s * 0.36)
      ..quadraticBezierTo(cx, s * 0.2, cx - hw, s * 0.36)
      ..close();
    canvas.drawPath(
        face,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-0.25, -0.2), radius: 0.85, colors: [skinLight, skinMid, skinDark], stops: const [0, 0.6, 1])
              .createShader(Rect.fromLTWH(cx - hw * 1.1, s * 0.2, hw * 2.2, s * 0.55)));
    if (look.thin) {
      // خدود غايرة شوي
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + side * hw * 0.62, s * 0.57), width: hw * 0.35, height: s * 0.08), fill(skinDark.withValues(alpha: 0.25)));
      }
    }

    // اللحية (داخل الوجه بس)
    canvas.save();
    canvas.clipPath(face);
    _beard(canvas, s, cx, hw);
    canvas.restore();
    canvas.drawPath(face, line);

    // الحواجب
    final (yi, yo) = switch (look.brows) {
      'sharp' => (0.418, 0.388),
      'angry' => (0.432, 0.384),
      'sad' => (0.386, 0.42),
      _ => (0.408, 0.398),
    };
    final browW = switch (look.brows) { 'angry' => 0.017, 'thick' => 0.02, _ => 0.013 };
    for (final side in [-1.0, 1.0]) {
      final xi = cx + side * s * 0.035, xo = cx + side * s * 0.165, xm = cx + side * s * 0.1;
      final ym = min(yi, yo) - 0.022;
      canvas.drawPath(
          Path()
            ..moveTo(xi, s * yi)
            ..quadraticBezierTo(xm, s * ym, xo, s * yo)
            ..quadraticBezierTo(xm, s * (ym + browW + 0.004), xi, s * (yi + browW))
            ..close(),
          fill(look.white ? const Color(0xFFE2DED6) : const Color(0xFF241812)));
    }

    // تجاعيد الكبر
    if (look.old) _wrinkles(canvas, s, cx, hw);

    // العيون (أوسع: أعرض وأطول شوي)
    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * s * 0.097, ey = s * 0.462;
      canvas.save();
      canvas.translate(ex, ey);
      canvas.scale(1.22 * look.eyeSize, 1.35 * look.eyeSize);
      canvas.translate(-ex, -ey);
      _eye(canvas, s, ex, ey, side, fill, stroke);
      canvas.restore();
    }

    if (look.nose == 'long') _longNose(canvas, s, cx, fill);
    if (look.mouth == 'grin') _smileLines(canvas, s, cx);
    // الخشم: جنب وظل، وفتحتين
    canvas.drawPath(
        Path()
          ..moveTo(cx + s * 0.012, s * 0.45)
          ..quadraticBezierTo(cx + s * 0.03, s * 0.53, cx + s * 0.036, s * 0.555),
        stroke(const Color(0x2E402818), 0.008));
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.04, s * 0.555)
          ..quadraticBezierTo(cx - s * 0.02, s * 0.575, cx, s * 0.568)
          ..quadraticBezierTo(cx + s * 0.02, s * 0.575, cx + s * 0.04, s * 0.555),
        line);
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + side * s * 0.018, s * 0.562), width: s * 0.016, height: s * 0.008), fill(const Color(0xFF5A3420)));
    }

    // الفم
    _mouth(canvas, s, cx, fill, line);

    // الشنب
    _mustache(canvas, s, cx, fill);

    // غطا الراس
    switch (look.head) {
      case 'kumma':
      case 'kummaWhite':
      case 'kummaBrown':
        _temples(canvas, s, cx, hw, fill);
        _kumma(canvas, s, cx, hw, line, fill, style: look.head);
      case 'turban':
        _turban(canvas, s, cx, hw, line, fill);
      default:
        _hair(canvas, s, cx, hw, line, fill);
    }
  }

  /// تجاعيد: أكياس تحت العيون، خطوط عند طرف العين، وخطوط من الخشم للفم وعلى الخدود
  void _wrinkles(Canvas canvas, double s, double cx, double hw) {
    final p = Paint()
      ..color = const Color(0x5A3A2214)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, s * 0.006)
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * s * 0.095;
      // أكياس تحت العين (خطين)
      for (final dy in [0.022, 0.034]) {
        canvas.drawPath(
            Path()
              ..moveTo(ex - s * 0.035, s * (0.462 + dy))
              ..quadraticBezierTo(ex, s * (0.462 + dy + 0.014), ex + s * 0.035, s * (0.462 + dy - 0.002)),
            p);
      }
      // خطوط طرف العين
      for (var k = -1; k <= 1; k++) {
        final x0 = ex + side * s * 0.05, y0 = s * 0.462 + k * s * 0.012;
        canvas.drawLine(Offset(x0, y0), Offset(x0 + side * s * 0.025, y0 + k * s * 0.008), p);
      }
      // من جنب الخشم لزاوية الفم
      canvas.drawPath(
          Path()
            ..moveTo(cx + side * s * 0.045, s * 0.55)
            ..quadraticBezierTo(cx + side * s * 0.085, s * 0.585, cx + side * s * 0.075, s * 0.64),
          p..strokeWidth = max(0.7, s * 0.008));
      p.strokeWidth = max(0.6, s * 0.006);
      // خط على الخد
      canvas.drawPath(
          Path()
            ..moveTo(cx + side * hw * 0.62, s * 0.5)
            ..quadraticBezierTo(cx + side * hw * 0.72, s * 0.55, cx + side * hw * 0.66, s * 0.59),
          p);
    }
    // بين الحواجب
    canvas.drawLine(Offset(cx - s * 0.008, s * 0.4), Offset(cx - s * 0.006, s * 0.43), p);
    canvas.drawLine(Offset(cx + s * 0.008, s * 0.4), Offset(cx + s * 0.006, s * 0.43), p);
  }

  /// خشم أطول: جسر الخشم بظل على الجنبين، ورأس أعرض شوي
  void _longNose(Canvas canvas, double s, double cx, Paint Function(Color) fill) {
    final shade = Paint()
      ..color = const Color(0x40402818)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, s * 0.009)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.016, s * 0.44)
          ..quadraticBezierTo(cx - s * 0.022, s * 0.51, cx - s * 0.032, s * 0.55),
        shade);
    canvas.drawPath(
        Path()
          ..moveTo(cx + s * 0.016, s * 0.44)
          ..quadraticBezierTo(cx + s * 0.024, s * 0.51, cx + s * 0.036, s * 0.548),
        shade);
    // لمعة على جسر الخشم
    canvas.drawLine(Offset(cx - s * 0.002, s * 0.47), Offset(cx - s * 0.004, s * 0.535), Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = max(0.6, s * 0.008)
      ..strokeCap = StrokeCap.round);
    // أجنحة الخشم
    for (final side in [-1.0, 1.0]) {
      canvas.drawArc(Rect.fromCenter(center: Offset(cx + side * s * 0.036, s * 0.556), width: s * 0.03, height: s * 0.026), side < 0 ? pi * 0.5 : -pi * 0.3, pi * 0.8, false, shade);
    }
  }

  /// خطوط الضحكة: من جنب الخشم لزاوية الفم
  void _smileLines(Canvas canvas, double s, double cx) {
    final p = Paint()
      ..color = const Color(0x5A3A2214)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, s * 0.009)
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(cx + side * s * 0.05, s * 0.56)
            ..quadraticBezierTo(cx + side * s * 0.1, s * 0.6, cx + side * s * 0.092, s * 0.655),
          p);
    }
  }

  void _beard(Canvas canvas, double s, double cx, double hw) {
    if (look.beard == 'none') return;
    final rnd = Random(11);
    void strands(Path area, int n, Color c, double len) {
      canvas.save();
      canvas.clipPath(area);
      final p = Paint()
        ..color = c
        ..strokeWidth = max(0.5, s * 0.0045)
        ..strokeCap = StrokeCap.round;
      final b = area.getBounds();
      for (var i = 0; i < n; i++) {
        final x = b.left + rnd.nextDouble() * b.width;
        final y = b.top + rnd.nextDouble() * b.height;
        final a = pi / 2 + (x - cx) / hw * 0.5 + (rnd.nextDouble() - 0.5) * 0.5;
        canvas.drawLine(Offset(x, y), Offset(x + cos(a) * s * len, y + sin(a) * s * len), p);
      }
      canvas.restore();
    }

    // منطقة الفك والذقن (تحت الخدود وحول الفم)
    Path jaw(double top) => Path()
      ..moveTo(cx - hw * 1.05, s * top)
      ..lineTo(cx - hw * 1.05, s * 0.76)
      ..lineTo(cx + hw * 1.05, s * 0.76)
      ..lineTo(cx + hw * 1.05, s * top)
      ..quadraticBezierTo(cx + hw * 0.8, s * (top + 0.08), cx + hw * 0.45, s * 0.62)
      ..quadraticBezierTo(cx, s * 0.66, cx - hw * 0.45, s * 0.62)
      ..quadraticBezierTo(cx - hw * 0.8, s * (top + 0.08), cx - hw * 1.05, s * top)
      ..close();
    switch (look.beard) {
      case 'stubble':
        final area = jaw(0.53);
        canvas.drawPath(area, Paint()..color = const Color(0x262A1A12));
        strands(area, 200, const Color(0x401C120C), 0.008);
      case 'chin':
        final area = jaw(0.55);
        canvas.drawPath(area, Paint()..color = const Color(0x262A1A12));
        strands(area, 160, const Color(0x401C120C), 0.008);
        final patch = Path()
          ..moveTo(cx - hw * 0.25, s * 0.675)
          ..quadraticBezierTo(cx, s * 0.665, cx + hw * 0.25, s * 0.675)
          ..quadraticBezierTo(cx + hw * 0.2, s * 0.73, cx, s * 0.738)
          ..quadraticBezierTo(cx - hw * 0.2, s * 0.73, cx - hw * 0.25, s * 0.675)
          ..close();
        canvas.drawPath(patch, Paint()..color = const Color(0x592A1A12));
        strands(patch, 90, const Color(0x801C120C), 0.01);
      case 'light':
        final area = jaw(0.52);
        canvas.drawPath(area, Paint()..color = const Color(0x402A1A12));
        strands(area, 320, const Color(0x661C120C), 0.011);
      case 'short':
        final area = jaw(0.5);
        canvas.drawPath(area, Paint()..color = const Color(0x8C1E1510));
        strands(area, 420, const Color(0x991C120C), 0.012);
      case 'full':
        // لحية كاملة من السوالف لين تحت الذقن
        final area = Path()
          ..moveTo(cx - hw * 1.05, s * 0.42)
          ..lineTo(cx - hw * 1.05, s * 0.78)
          ..lineTo(cx + hw * 1.05, s * 0.78)
          ..lineTo(cx + hw * 1.05, s * 0.42)
          ..quadraticBezierTo(cx + hw * 0.85, s * 0.56, cx + hw * 0.45, s * 0.6)
          ..quadraticBezierTo(cx, s * 0.645, cx - hw * 0.45, s * 0.6)
          ..quadraticBezierTo(cx - hw * 0.85, s * 0.56, cx - hw * 1.05, s * 0.42)
          ..close();
        canvas.drawPath(area, Paint()..color = look.white ? const Color(0xF5ECEAE5) : const Color(0xE61C140F));
        strands(area, 380, look.white ? const Color(0x8C9A958C) : const Color(0x664A3A30), 0.014);
      case 'goatee':
        final area = Path()
          ..moveTo(cx - hw * 0.32, s * 0.64)
          ..quadraticBezierTo(cx, s * 0.665, cx + hw * 0.32, s * 0.64)
          ..quadraticBezierTo(cx + hw * 0.3, s * 0.72, cx, s * 0.745)
          ..quadraticBezierTo(cx - hw * 0.3, s * 0.72, cx - hw * 0.32, s * 0.64)
          ..close();
        canvas.drawPath(area, Paint()..color = const Color(0xD91C140F));
        strands(area, 120, const Color(0x664A3A30), 0.01);
    }
  }

  void _eye(Canvas canvas, double s, double ex, double ey, double side, Paint Function(Color) fill, Paint Function(Color, double) stroke) {
    if (look.eyes == 'closed') {
      // عيون مسكّرة مبتسمة (نظرة هادية)
      canvas.drawPath(
          Path()
            ..moveTo(ex - s * 0.04, ey - s * 0.002)
            ..quadraticBezierTo(ex, ey + s * 0.02, ex + s * 0.04, ey - s * 0.002),
          stroke(const Color(0xFF1A110C), 0.014));
      canvas.drawPath(
          Path()
            ..moveTo(ex - s * 0.03, ey - s * 0.016)
            ..quadraticBezierTo(ex, ey - s * 0.024, ex + s * 0.034, ey - s * 0.014),
          stroke(const Color(0x40402818), 0.007));
      return;
    }
    final calm = look.eyes == 'calm';
    final smiling = look.eyes == 'smile';
    final sad = look.brows == 'sad';
    final topY = calm ? -0.024 : (smiling ? -0.028 : -0.032);
    final lowY = smiling ? 0.008 : 0.022; // قاع العين
    final droop = sad ? side * -0.004 : 0.0; // الحزين: طرف العين الخارجي نازل
    final eye = Path()
      ..moveTo(ex - s * 0.043, ey + s * (0.002 - droop))
      ..quadraticBezierTo(ex - s * 0.008, ey + s * topY, ex + s * 0.043, ey + s * (-0.002 + droop))
      ..quadraticBezierTo(ex + s * 0.005, ey + s * lowY, ex - s * 0.043, ey + s * (0.002 - droop))
      ..close();
    canvas.drawPath(eye, fill(const Color(0xFFF2EBE2)));
    canvas.save();
    canvas.clipPath(eye);
    final iris = Offset(ex - side * s * 0.003, ey + s * 0.001);
    canvas.drawCircle(iris, s * 0.019, fill(const Color(0xFF4A2E1A)));
    canvas.drawCircle(iris, s * 0.009, fill(const Color(0xFF0E0806)));
    if (calm) canvas.drawRect(Rect.fromLTWH(ex - s * 0.05, ey - s * 0.03, s * 0.1, s * 0.016), fill(const Color(0x40301C10)));
    canvas.restore();
    canvas.drawCircle(iris + Offset(-s * 0.006, -s * 0.004), s * 0.0045, fill(const Color(0xDDFFFFFF)));
    // الرموش فوق
    canvas.drawPath(
        Path()
          ..moveTo(ex - s * 0.046, ey + s * (0.003 - droop))
          ..quadraticBezierTo(ex - s * 0.008, ey + s * (topY - 0.003), ex + s * 0.046, ey + s * (-0.003 + droop)),
        stroke(const Color(0xFF1A110C), calm ? 0.016 : 0.012));
    // طية الجفن والجفن التحتاني
    canvas.drawPath(
        Path()
          ..moveTo(ex - s * 0.036, ey + s * (topY + 0.01))
          ..quadraticBezierTo(ex - s * 0.005, ey + s * (topY - 0.012), ex + s * 0.04, ey + s * (topY + 0.006)),
        stroke(const Color(0x55402818), 0.007));
    canvas.drawPath(
        Path()
          ..moveTo(ex - s * 0.036, ey + s * 0.008)
          ..quadraticBezierTo(ex, ey + s * (lowY + 0.002), ex + s * 0.036, ey + s * 0.006),
        stroke(const Color(0x40402818), 0.006));
    if (smiling) {
      // الخد المرفوع تحت العين (طيّتين)
      canvas.drawPath(
          Path()
            ..moveTo(ex - s * 0.03, ey + s * 0.018)
            ..quadraticBezierTo(ex, ey + s * 0.03, ex + s * 0.034, ey + s * 0.016),
          stroke(const Color(0x2E3A2214), 0.006));
    }
  }

  void _mouth(Canvas canvas, double s, double cx, Paint Function(Color) fill, Paint line) {
    final lipY = s * 0.632;
    final talk = mouth.clamp(0.0, 1.0);
    final grin = look.mouth == 'grin' || look.mouth == 'gap';
    // فتحة الفم: وقت الكلام، أو الضحكة العريضة
    final open = max(talk * s * 0.065, grin ? s * 0.042 : 0.0);
    // زوايا الفم: فوق للابتسامة وتحت للعبسة
    final corner = switch (look.mouth) {
      'smile' || 'grin' || 'gap' => -s * 0.01,
      'frown' => s * 0.012,
      _ => 0.0,
    };
    final w = grin ? s * 0.078 : s * 0.055;
    if (open > 0.5) {
      final hole = grin && talk < 0.05
          ? (Path()
            ..moveTo(cx - w, lipY + corner)
            ..quadraticBezierTo(cx, lipY - s * 0.002, cx + w, lipY + corner)
            ..cubicTo(cx + w * 0.8, lipY + open * 1.5, cx - w * 0.8, lipY + open * 1.5, cx - w, lipY + corner)
            ..close())
          : (Path()
            ..moveTo(cx - w * 0.9, lipY + corner)
            ..quadraticBezierTo(cx, lipY - s * 0.006, cx + w * 0.9, lipY + corner)
            ..quadraticBezierTo(cx, lipY + open * 1.4, cx - w * 0.9, lipY + corner)
            ..close());
      canvas.drawPath(hole, fill(const Color(0xFF3A1414)));
      canvas.save();
      canvas.clipPath(hole);
      final teeth = Rect.fromLTWH(cx - w * 0.8, lipY - s * 0.004, w * 1.6, min(open * (grin ? 0.75 : 0.5), s * 0.03));
      canvas.drawRect(teeth, fill(const Color(0xFFF1EDE6)));
      if (look.mouth == 'gap') canvas.drawRect(Rect.fromLTWH(cx + s * 0.004, teeth.top, s * 0.014, teeth.height), fill(const Color(0xFF3A1414))); // سن ناقص
      canvas.restore();
    }
    // الشفة الفوقانية
    canvas.drawPath(
        Path()
          ..moveTo(cx - w, lipY + corner)
          ..quadraticBezierTo(cx - s * 0.02, lipY - s * 0.013, cx, lipY - s * 0.007)
          ..quadraticBezierTo(cx + s * 0.02, lipY - s * 0.013, cx + w, lipY + corner)
          ..quadraticBezierTo(cx, lipY + s * 0.003, cx - w, lipY + corner)
          ..close(),
        fill(Color.lerp(look.skin, const Color(0xFF7A3A30), 0.55)!));
    // الشفة التحتانية تنزل مع الفتح
    final ly = lipY + open;
    canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.9, ly + corner * 0.6)
          ..quadraticBezierTo(cx, ly + s * 0.024, cx + w * 0.9, ly + corner * 0.6)
          ..quadraticBezierTo(cx, ly + s * 0.004, cx - w * 0.9, ly + corner * 0.6)
          ..close(),
        fill(Color.lerp(look.skin, const Color(0xFF8A4A3C), 0.5)!));
    if (open <= 0.5) {
      canvas.drawPath(
          Path()
            ..moveTo(cx - w * 0.95, lipY + corner)
            ..quadraticBezierTo(cx, lipY + (corner < 0 ? s * 0.008 : (corner > 0 ? -s * 0.006 : 0)), cx + w * 0.95, lipY + corner),
          Paint()
            ..color = line.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.7, s * 0.009)
            ..strokeCap = StrokeCap.round);
    }
  }

  void _mustache(Canvas canvas, double s, double cx, Paint Function(Color) fill) {
    if (look.mustache == 'none') return;
    final thick = look.mustache == 'thick';
    final lipY = s * 0.632;
    final w = thick ? s * 0.095 : s * 0.085;
    final h = thick ? s * 0.05 : s * 0.045;
    final mus = Path()
      ..moveTo(cx - w, lipY - s * (thick ? 0.004 : 0.012))
      ..quadraticBezierTo(cx - w * 0.5, lipY - h, cx, lipY - h * 0.8)
      ..quadraticBezierTo(cx + w * 0.5, lipY - h, cx + w, lipY - s * (thick ? 0.004 : 0.012))
      ..quadraticBezierTo(cx + w * 0.5, lipY - s * (thick ? 0.014 : 0.022), cx, lipY - s * (thick ? 0.014 : 0.02))
      ..quadraticBezierTo(cx - w * 0.5, lipY - s * (thick ? 0.014 : 0.022), cx - w, lipY - s * (thick ? 0.004 : 0.012))
      ..close();
    canvas.drawPath(mus, fill(look.white ? const Color(0xF5F1EFEA) : (thick ? const Color(0xE6140C08) : const Color(0x8C1C120C))));
    canvas.save();
    canvas.clipPath(mus);
    final rnd = Random(5);
    final p = Paint()
      ..color = look.white ? const Color(0x99948E84) : (thick ? const Color(0x55604a3a) : const Color(0xAA140C08))
      ..strokeWidth = max(0.5, s * 0.004)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 80; i++) {
      final x = cx + (rnd.nextDouble() * 2 - 1) * w;
      final y = lipY - s * 0.012 - rnd.nextDouble() * h;
      final dir = x < cx ? -1 : 1;
      canvas.drawLine(Offset(x, y), Offset(x + dir * s * 0.006, y + s * 0.01), p);
    }
    canvas.restore();
  }

  // شعر قصير أسود يبين تحت الكمّة عند الصدغ
  void _temples(Canvas canvas, double s, double cx, double hw, Paint Function(Color) fill) {
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(cx + side * hw, s * 0.37)
            ..quadraticBezierTo(cx + side * hw * 1.025, s * 0.43, cx + side * hw * 0.95, s * 0.46)
            ..lineTo(cx + side * hw * 0.875, s * 0.37)
            ..close(),
          fill(const Color(0xFF1A1310)));
    }
  }

  /// الكمّة العمانية. white=false: كمّة السويق (بيج، خطوط بيضاء بارزة، معيّنات زرقاء وشيفرون بني وردي).
  /// kummaWhite: كمّة بيضاء بتطريز ناعم ملوّن. kummaBrown: بيضاء بتطريز بني (ورق فوق، أشرطة، ووردات).
  void _kumma(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill, {required String style}) {
    final white = style != 'kumma';
    canvas.save();
    canvas.translate(cx, s * 0.3);
    canvas.rotate(look.tilt);
    canvas.translate(-cx, -s * 0.3);
    final top = s * 0.165, bottom = s * 0.38, half = hw * 1.035; // على قد الراس
    final cap = Path()
      ..moveTo(cx - half, bottom)
      ..lineTo(cx - half * 0.93, s * 0.205)
      ..quadraticBezierTo(cx - half * 0.9, top + s * 0.012, cx - half * 0.45, top + s * 0.004)
      ..quadraticBezierTo(cx, top - s * 0.006, cx + half * 0.45, top + s * 0.004)
      ..quadraticBezierTo(cx + half * 0.9, top + s * 0.012, cx + half * 0.93, s * 0.205)
      ..lineTo(cx + half, bottom)
      ..quadraticBezierTo(cx, bottom - s * 0.012, cx - half, bottom)
      ..close();
    const blue = Color(0xFF5B5FC9), mauve = Color(0xFF9C7268), whiteC = Color(0xFFF7F5EE);
    canvas.drawPath(cap, fill(white ? const Color(0xFFFAF9F5) : const Color(0xFFCBC3A3)));
    canvas.save();
    canvas.clipPath(cap);
    final rib = Paint()
      ..color = white ? const Color(0xFFDCD8CC) : whiteC
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, s * 0.007)
      ..strokeJoin = StrokeJoin.round;
    Path diamond(double x, double y, double w, double h) => Path()
      ..moveTo(x, y - h)
      ..lineTo(x + w, y)
      ..lineTo(x, y + h)
      ..lineTo(x - w, y)
      ..close();
    Path chevron(double x, double y, double w, double h, {bool up = false}) {
      final d = up ? -1.0 : 1.0;
      return Path()
        ..moveTo(x - w, y - d * h * 0.5)
        ..lineTo(x, y + d * h * 0.1)
        ..lineTo(x + w, y - d * h * 0.5)
        ..lineTo(x + w, y + d * h * 0.1)
        ..lineTo(x, y + d * h * 0.7)
        ..lineTo(x - w, y + d * h * 0.1)
        ..close();
    }

    void motif(Path p, Color c) {
      canvas.drawPath(p, fill(c));
      canvas.drawPath(p, rib);
    }

    if (style == 'kummaBrown') {
      _brownEmbroidery(canvas, s, cx, half, fill);
    } else if (white) {
      // الكمّة البيضاء: صفوف نقاط ومعيّنات صغيرة بألوان (بنفسجي، أزرق، أحمر)
      const emb = [Color(0xFF8E24AA), Color(0xFF1E88E5), Color(0xFFE53935)];
      for (var r = 0; r < 4; r++) {
        final y = s * (0.2 + r * 0.045);
        for (var i = -5; i <= 5; i++) {
          final x = cx + (i + (r.isOdd ? 0.5 : 0)) * s * 0.04;
          if (r.isEven) {
            canvas.drawPath(diamond(x, y, s * 0.008, s * 0.01), fill(emb[(i + r).abs() % 3]));
          } else {
            canvas.drawCircle(Offset(x, y), s * 0.006, fill(emb[(i + r + 1).abs() % 3]));
          }
        }
      }
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.365, half * 2.2, s * 0.008), fill(const Color(0xFF8E24AA)));
    } else {
      // الحزام الكبير: معيّن أزرق بين شيفرونين بنيين، وخطوط بيضاء مايلة بينهم
      const cell = 0.066;
      final midY = s * 0.268;
      for (var i = -4; i <= 4; i++) {
        final x = cx + i * s * cell;
        canvas.drawLine(Offset(x - s * cell / 2, s * 0.215), Offset(x + s * cell / 2, s * 0.322), rib);
        canvas.drawLine(Offset(x + s * cell / 2, s * 0.215), Offset(x - s * cell / 2, s * 0.322), rib);
        motif(diamond(x, midY, s * 0.016, s * 0.02), blue);
        motif(chevron(x, midY - s * 0.034, s * 0.014, s * 0.02), mauve);
        motif(chevron(x, midY + s * 0.034, s * 0.014, s * 0.02, up: true), mauve);
        motif(diamond(x + s * cell / 2, midY, s * 0.008, s * 0.012), blue);
      }
      // الشريط البني بين خطين أبيض
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.322, half * 2.2, s * 0.012), fill(mauve));
      canvas.drawLine(Offset(cx - half * 1.1, s * 0.321), Offset(cx + half * 1.1, s * 0.321), rib);
      canvas.drawLine(Offset(cx - half * 1.1, s * 0.335), Offset(cx + half * 1.1, s * 0.335), rib);
      // الحزام التحتاني
      for (var i = -5; i <= 5; i++) {
        final x = cx + i * s * 0.044;
        if (i.isEven) {
          motif(chevron(x, s * 0.354, s * 0.012, s * 0.018, up: true), mauve);
        } else {
          motif(diamond(x, s * 0.356, s * 0.009, s * 0.012), blue);
        }
      }
      // القبة فوق
      for (var r = 0; r < 2; r++) {
        final y = s * (0.175 + r * 0.02);
        for (var i = -4; i <= 4; i++) {
          final x = cx + (i + (r.isOdd ? 0.5 : 0)) * s * 0.052;
          if ((i + r).isEven) {
            final o = Rect.fromCenter(center: Offset(x, y), width: s * 0.022, height: s * 0.016);
            canvas.drawOval(o, fill(blue));
            canvas.drawOval(o, rib);
          } else {
            motif(chevron(x, y, s * 0.011, s * 0.016), mauve);
          }
        }
      }
      canvas.drawLine(Offset(cx - half * 1.1, s * 0.205), Offset(cx + half * 1.1, s * 0.205), rib);
    }
    // الحافة البيضاء
    canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.372, half * 2.2, s * 0.02), fill(whiteC));
    // حجم: إضاءة من فوق يسار وظل على اليمين
    canvas.drawPath(
        cap,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x00000000), Color(0x33000000)], stops: [0, 0.5, 1])
              .createShader(Rect.fromLTWH(cx - half, top, half * 2, bottom - top)));
    canvas.restore();
    canvas.drawPath(cap, line);
    canvas.restore();
  }

  /// تطريز بني على كمّة بيضاء (مثل كمّة بو حمدان): ورق سرخس على القبة، شريطين، صف وردات، وأسهم تحت
  void _brownEmbroidery(Canvas canvas, double s, double cx, double half, Paint Function(Color) fill) {
    const brown = Color(0xFF6E4234);
    final thin = Paint()
      ..color = brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, s * 0.006)
      ..strokeCap = StrokeCap.round;
    // ورق على القبة: ساق وأوراق مايلة
    for (var i = -4; i <= 4; i++) {
      final x = cx + i * s * 0.05;
      canvas.drawLine(Offset(x, s * 0.172), Offset(x, s * 0.212), thin);
      for (var k = 0; k < 3; k++) {
        final y = s * (0.178 + k * 0.012);
        canvas.drawLine(Offset(x, y + s * 0.006), Offset(x - s * 0.012, y), thin);
        canvas.drawLine(Offset(x, y + s * 0.006), Offset(x + s * 0.012, y), thin);
      }
    }
    // شريطين بنيين
    for (final y in [0.218, 0.302]) {
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * y, half * 2.2, s * 0.007), fill(brown));
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * (y + 0.011), half * 2.2, s * 0.004), fill(brown));
    }
    // صف الوردات: أربع بتلات حول نقطة، وبينها معيّنات صغيرة
    for (var i = -4; i <= 4; i++) {
      final x = cx + i * s * 0.056, y = s * 0.262;
      for (final (dx, dy) in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x + dx * s * 0.012, y + dy * s * 0.014), width: s * 0.013, height: s * 0.013), fill(brown));
      }
      canvas.drawCircle(Offset(x, y), s * 0.005, fill(brown));
      final mx = x + s * 0.028;
      canvas.drawPath(
          Path()
            ..moveTo(mx, y - s * 0.012)
            ..lineTo(mx + s * 0.007, y)
            ..lineTo(mx, y + s * 0.012)
            ..lineTo(mx - s * 0.007, y)
            ..close(),
          fill(brown));
    }
    // صف أسهم تحت
    for (var i = -6; i <= 6; i++) {
      final x = cx + i * s * 0.036, y = s * 0.342;
      canvas.drawPath(
          Path()
            ..moveTo(x - s * 0.01, y + s * 0.008)
            ..lineTo(x, y - s * 0.01)
            ..lineTo(x + s * 0.01, y + s * 0.008),
          thin);
      canvas.drawLine(Offset(x, y - s * 0.01), Offset(x, y + s * 0.014), thin);
    }
    canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.362, half * 2.2, s * 0.006), fill(brown));
  }

  /// المصر العماني: قماش ملفوف حول الراس بلفات مايلة، خطوط نقشة، وطرف طالع على اليمين
  void _turban(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill) {
    final c = look.headColor;
    final dark = Color.lerp(c, Colors.black, 0.28)!;
    final light = Color.lerp(c, Colors.white, 0.3)!;
    // عريض ومدوّر (لفات قماش)، وما يطلع فوق حدود الإطار
    final half = hw * 1.22;
    final top = s * 0.165, bottom = s * 0.4;
    final shape = Path()
      ..moveTo(cx - half * 0.98, bottom)
      ..cubicTo(cx - half * 1.22, s * 0.33, cx - half * 1.1, top + s * 0.03, cx - half * 0.55, top + s * 0.008)
      ..quadraticBezierTo(cx, top - s * 0.012, cx + half * 0.55, top + s * 0.008)
      ..cubicTo(cx + half * 1.1, top + s * 0.03, cx + half * 1.22, s * 0.33, cx + half * 0.98, bottom)
      ..quadraticBezierTo(cx, bottom - s * 0.04, cx - half * 0.98, bottom)
      ..close();
    canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, c, dark], stops: const [0, 0.5, 1])
              .createShader(shape.getBounds()));
    canvas.save();
    canvas.clipPath(shape);
    // اللفات: أشرطة مايلة متداخلة بظل تحت كل لفة
    for (var i = 0; i < 5; i++) {
      final y = bottom - s * (0.03 + i * 0.05);
      final fold = Path()
        ..moveTo(cx - half * 1.2, y + s * 0.035)
        ..quadraticBezierTo(cx - half * 0.2, y - s * 0.03 - i * s * 0.004, cx + half * 1.2, y - s * 0.01);
      canvas.drawPath(
          fold,
          Paint()
            ..color = dark.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.012);
      canvas.drawPath(
          fold.shift(Offset(0, -s * 0.009)),
          Paint()
            ..color = light.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.005);
    }
    // نقشة المصر: خطوط رفيعة ومربعات صغيرة
    final pat = Paint()
      ..color = Color.lerp(c, Colors.black, 0.45)!.withValues(alpha: 0.55)
      ..strokeWidth = max(0.5, s * 0.004);
    for (var i = -8; i <= 8; i++) {
      final x = cx + i * s * 0.03;
      canvas.drawLine(Offset(x, top), Offset(x + s * 0.06, bottom), pat);
    }
    canvas.restore();
    canvas.drawPath(shape, line);
    // الطرف (الذيل) طالع على اليمين
    final tail = Path()
      ..moveTo(cx + half * 0.6, top + s * 0.05)
      ..quadraticBezierTo(cx + half * 0.98, top + s * 0.005, cx + half * 1.14, top + s * 0.045)
      ..quadraticBezierTo(cx + half * 1.0, top + s * 0.075, cx + half * 0.84, top + s * 0.1)
      ..close();
    canvas.drawPath(tail, fill(c));
    canvas.drawPath(
        tail,
        Paint()
          ..color = dark.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.006);
    canvas.drawPath(tail, line);
    // أهداب الطرف
    for (var i = 0; i < 4; i++) {
      final x = cx + half * (1.0 + i * 0.03);
      canvas.drawLine(Offset(x, top + s * (0.035 + i * 0.008)), Offset(x + s * 0.012, top + s * (0.05 + i * 0.008)),
          Paint()
            ..color = dark
            ..strokeWidth = max(0.5, s * 0.005)
            ..strokeCap = StrokeCap.round);
    }
  }

  /// شعر قصير أسود بخط شعر طبيعي وسوالف
  void _hair(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill) {
    final hair = Path()
      ..moveTo(cx - hw * 1.02, s * 0.45)
      ..quadraticBezierTo(cx - hw * 1.15, s * 0.22, cx - hw * 0.4, s * 0.19)
      ..quadraticBezierTo(cx, s * 0.17, cx + hw * 0.5, s * 0.195)
      ..quadraticBezierTo(cx + hw * 1.15, s * 0.23, cx + hw * 1.02, s * 0.45)
      ..lineTo(cx + hw * 0.9, s * 0.45)
      ..quadraticBezierTo(cx + hw * 0.92, s * 0.36, cx + hw * 0.75, s * 0.33)
      ..quadraticBezierTo(cx + hw * 0.2, s * 0.29, cx - hw * 0.1, s * 0.31)
      ..quadraticBezierTo(cx - hw * 0.7, s * 0.32, cx - hw * 0.88, s * 0.37)
      ..lineTo(cx - hw * 0.9, s * 0.45)
      ..close();
    canvas.drawPath(
        hair,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2C24), Color(0xFF15100D)])
              .createShader(hair.getBounds()));
    canvas.save();
    canvas.clipPath(hair);
    final rnd = Random(7);
    final p = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = max(0.5, s * 0.004)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 70; i++) {
      final x = cx + (rnd.nextDouble() * 2 - 1) * hw;
      final y = s * (0.2 + rnd.nextDouble() * 0.12);
      canvas.drawLine(Offset(x, y), Offset(x + s * 0.012, y + s * 0.004), p);
    }
    canvas.restore();
    canvas.drawPath(hair, line);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.look != look || old.mouth != mouth;
}
