import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'cached_paint.dart';
import 'lipsync.dart';

/// شكل كل شخصية. كلهم بنفس التوجه الفني (مثل ود عمتيه): رسم أقرب للواقعي بتظليل خفيف وحدود سودا رفيعة.
class _Look {
  final Color skin;
  final String head; // kumma (كمّة السويق)، kummaWhite (كمّة بيضاء)، kummaBrown (بيضاء بتطريز بني)، turban (مصر)، pakol (طاقية باكستانية بلفة صوف)، bald (أقرع بشعر قصير على الجنبين)، qahfiya (قحفية مخرّمة بلون headColor)، hair (شعر قصير)
  final Color headColor; // لون المصر
  final String beard; // none, stubble, light, short, full, goatee, circle (سكسوكة موصولة بالشنب)
  final String mustache; // none, light, thick, trim (رفيع مرسوم)، bushy (كثيف وعريض وأطرافه نازلة)
  final String brows; // calm, sharp, angry, sad, thick, bushy (أكثف بشعيرات)، flat (مستقيم بارد)
  final String eyes; // calm, open, closed, smile (الخد يرفع الجفن التحتاني), cold (جفن ثقيل ونظرة بدون لمعة)
  final String mouth; // neutral, smile, frown, grin, gap, faint (ابتسامة خفيفة باردة)
  final bool thin;
  final bool wide; // وجه عريض
  final bool wideChin; // ذقن أعرض
  final bool long; // وجه أطول (الذقن أوطى)
  final double tilt; // ميلان غطا الراس
  final String nose; // normal, long
  final double eyeSize; // حجم العيون (1 = العادي)
  // فروق الملامح بين الشخصيات
  final double noseW; // عرض الخشم (1 = العادي)
  final bool noseHook; // خشم معقوف بحدبة على الجسر
  final double lips; // سماكة الشفايف (1 = العادي)
  final double eyeGap; // المسافة بين العيون (1 = العادي)
  final Color robe; // لون الدشداشة
  final bool scarf; // شماغ أحمر وأبيض مفصوخ على الكتف
  final bool shirt; // قميص بياقة مدببة وأزرار
  final bool pajama; // بيجامة نوم مخططة بياقة مقلوبة وأزرار
  final bool kameez; // ياقة واقفة وأزرار بدل فتحة الدشداشة (القميص الباكستاني والثوب السعودي)
  final double headScale; // حجم الراس (1 = العادي)، يصغر أو يكبر من عند الرقبة
  final bool openNeck; // جيب الدشداشة مفتوح من الجهة اللي ما فيها الفرفوشة بس
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
    this.wide = false,
    this.wideChin = false,
    this.long = false,
    this.tilt = 0,
    this.nose = 'normal',
    this.eyeSize = 1,
    this.noseW = 1,
    this.noseHook = false,
    this.lips = 1,
    this.eyeGap = 1,
    this.robe = const Color(0xFFF7F7F4),
    this.scarf = false,
    this.shirt = false,
    this.pajama = false,
    this.kameez = false,
    this.openNeck = false,
    this.headScale = 1,
    this.white = false,
    this.old = false,
  });
}

/// الشخصيات اللي يقدر اللاعب يختارها (نفس CHARACTERS بـ server/src/server.js)
const characterNames = <String, String>{
  'khalfan': 'خلفان التفق',
  'khusaib': 'خصيب',
  'marhoon': 'مرهون',
  'musabbah': 'سعيد',
  'bodhirs': 'بو شنب', // (المعرّف من أيام اسمه محمد بو ضرس، عشان المشتريات والاختيارات المحفوظة)
  'abdo': 'عبدو اليابس',
  'aslam': 'أسلم',
  'mundaghit': 'المنضغط',
  'wadamtih': 'ود عمتيه',
  'buhamdan': 'بو حمدان',
  'fares': 'فارس',
  'sulaiman': 'سليمان',
  'medhat': 'مدحت',
};

const _looks = <String, _Look>{
  // خلفان التفق: ملامح عمانية ومصر أحمر، شنب كثيف
  'khalfan': _Look(skin: Color(0xFFC68E5E), robe: Color(0xFFB7C7D6), head: 'turban', headColor: Color(0xFFC62828), mustache: 'thick', beard: 'stubble', mouth: 'smile', noseW: 1.25, lips: 1.3),
  // خصيب: ملامح حادة ومصر حليبي، لحية قصيرة
  'khusaib': _Look(skin: Color(0xFFB97A4F), robe: Color(0xFFEFE6CF), head: 'turban', headColor: Color(0xFFF3E9D2), brows: 'sharp', beard: 'short', mustache: 'light', noseHook: true, lips: 0.6, eyeGap: 0.94),
  // مرهون: شايب عمره 80، ملامح فقر ومصر بني فاتح، وجه نحيف بتجاعيد ولحية بيضاء
  'marhoon': _Look(skin: Color(0xFFBE8C64), robe: Color(0xFF8C6E52), head: 'turban', headColor: Color(0xFFC8A27A), brows: 'sad', eyes: 'calm', mouth: 'frown', beard: 'full', mustache: 'thick', thin: true, white: true, old: true, tilt: -0.12, noseW: 1.1, noseHook: true, lips: 0.7),
  // سعيد (المعرّف musabbah من أيام اسمه مصبّح، عشان اختيارات اللاعبين المحفوظة): وجه طويل ونحيف بملامح عمانية (بشرة سمرا، حواجب كثيفة، خشم طويل، شنب كثيف ولحية مرتبة)، وكمّة بيضاء بتطريز مفصّل
  'musabbah': _Look(skin: Color(0xFFB27A50), robe: Color(0xFFF7F7F4), head: 'kummaWhite', beard: 'short', mustache: 'thick', brows: 'thick', eyes: 'open', eyeSize: 0.92, nose: 'long', mouth: 'smile', thin: true, long: true, noseHook: true, lips: 0.9, eyeGap: 0.95),
  // بو شنب: كمّة عمانية بيضاء مطرزة بلون ترابي واحد (أوطى من العادية وبعرض راسه مع الشعر) وشعره الأسود الناعم يبين تحتها، شنب أسود كثيف وعريض، ذقن خفيف محلوق، حواجب كثيفة مقوّسة، دشداشة بنية غامقة جيبها مفتوح
  'bodhirs': _Look(skin: Color(0xFFB27B54), robe: Color(0xFF4A4038), head: 'smallKumma', openNeck: true, headScale: 0.92, mustache: 'bushy', beard: 'stubble', brows: 'bushy', eyes: 'open', eyeSize: 0.85, mouth: 'faint', long: true, noseW: 1.2, lips: 1.1, eyeGap: 1.02),
  // عبدو اليابس: قوة وصلابة ولحية مو كبيرة تغطي الوجه، وكمّة بيضاء بتطريز أخضر
  'abdo': _Look(skin: Color(0xFFB07A4F), robe: Color(0xFF5E6368), head: 'kummaGreen', brows: 'sharp', beard: 'full', mustache: 'thick', noseW: 1.2, eyeGap: 1.04),
  // أسلم: باكستاني بوجه عريض، پاکول صوف بني، لحية سودا كاملة وشنب، شلوار قميص زيتوني
  'aslam': _Look(skin: Color(0xFFA8714A), robe: Color(0xFF9AA58A), kameez: true, wide: true, head: 'pakol', headColor: Color(0xFF8B6B4A), beard: 'full', mustache: 'thick', brows: 'thick', mouth: 'smile', noseW: 1.35, lips: 1.25, eyeGap: 1.05),
  // المنضغط: ملامح غاضبة وسكسوكة
  'mundaghit': _Look(skin: Color(0xFFBF8A60), robe: Color(0xFF8A4545), brows: 'angry', mouth: 'frown', beard: 'goatee', mustache: 'light', noseW: 0.95, lips: 0.55, eyeGap: 0.95),
  // بو حمدان: كمّة بيضاء بتطريز بني، وجه حاد، عيون صغيرة، حواجب كثيفة، خشم طويل، شنب ولحية خفيفة على الذقن
  'buhamdan': _Look(skin: Color(0xFFC99470), robe: Color(0xFFCFE2EA), head: 'kummaBrown', brows: 'thick', eyes: 'open', eyeSize: 0.8, mustache: 'thick', beard: 'chin', nose: 'long', thin: true, noseHook: true, lips: 0.85, eyeGap: 0.92),
  // فارس: سعودي عمره 20، وجه نحيف بذقن أعرض شوي، ثوب أبيض وقحفية والشماغ الأحمر مفصوخ على الكتف، سكسوكة خفيفة موصولة بشنب رفيع
  'fares': _Look(skin: Color(0xFFC9966C), kameez: true, scarf: true, thin: true, wideChin: true, head: 'qahfiya', beard: 'circle', mustache: 'trim', eyeSize: 0.9, mouth: 'smile', noseW: 0.78, eyeGap: 1.02),
  // سليمان: بشرة فاتحة وملامح باردة، نظرة نص مغمضة، بابتسامة خفيفة، بقحفية زرقا وبيجامة نوم مخططة برقبة مفتوحة
  'sulaiman': _Look(skin: Color(0xFFE6CBB4), robe: Color(0xFFBCD2E6), pajama: true, head: 'qahfiya', headColor: Color(0xFF2563B8), brows: 'flat', eyes: 'cold', eyeSize: 0.9, mouth: 'faint', beard: 'stubble', nose: 'long', thin: true, wideChin: true, noseW: 0.72, lips: 0.6),
  // مدحت: مصري عمره 45، أقرع تقريباً بشعر قصير على الجنبين، وجه عريض ومليان، شنب كثيف وذقن خفيف، قميص أزرق بياقة
  'medhat': _Look(skin: Color(0xFFC48A62), robe: Color(0xFF8EB4DC), shirt: true, head: 'bald', wide: true, beard: 'stubble', mustache: 'thick', brows: 'thick', eyes: 'calm', mouth: 'smile', noseW: 1.5, lips: 1.45, eyeGap: 1.06),
  // ود عمتيه: من ولاية السويق، كمّة مطرزة مايلة شوي، لحية وشنب خفيفين
  'wadamtih': _Look(skin: Color(0xFFC4895C), robe: Color(0xFFD8C9A8), head: 'kumma', beard: 'light', mustache: 'light', eyes: 'calm', tilt: 0.12, lips: 1.05, eyeGap: 1.04),
};

class CharacterAvatar extends StatelessWidget {
  final String? charId;
  final double size;
  final Color ring;
  final Color? background; // لون الفريق (وإلا سماوي فاتح)
  final bool talking; // الفم يتحرك (وقت ما يشتغل صوت الشخصية)
  final String? voice; // الصوت الشغّال (مثل wadamtih_3): الفم يتبع علوه
  final double? mouth; // فتحة فم ثابتة (للمعاينة)
  const CharacterAvatar({
    super.key,
    required this.charId,
    this.size = 48,
    this.ring = Colors.transparent,
    this.background,
    this.talking = false,
    this.voice,
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
                  child: _Face(charId: charId, talking: talking, voice: voice, mouth: mouth),
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

/// الوجه. وقت صوت الشخصية الفم يتبع علو الصوت (lipsync.dart)،
/// وإذا talking بدون صوت معروف يفتح ويسكّر مثل مقاطع الكلام.
class _Face extends StatefulWidget {
  final String? charId;
  final bool talking;
  final String? voice;
  final double? mouth;
  const _Face({required this.charId, required this.talking, this.voice, this.mouth});

  @override
  State<_Face> createState() => _FaceState();
}

class _FaceState extends State<_Face> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((t) => setState(() => _t = t));
  Duration _t = Duration.zero; // من بداية الصوت

  bool get _moving => widget.mouth == null && (widget.talking || widget.voice != null);

  @override
  void initState() {
    super.initState();
    if (_moving) _ticker.start();
  }

  @override
  void didUpdateWidget(_Face old) {
    super.didUpdateWidget(old);
    if (_moving && (widget.voice != old.voice || !_ticker.isActive)) {
      _ticker.stop();
      _t = Duration.zero;
      _ticker.start();
    }
    if (!_moving && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // من علو الصوت: بين كل خانتين نمشي بخط مستقيم
  double? _mouthFromVoice(double ms) {
    final env = lipSync[widget.voice];
    if (env == null) return null;
    final x = ms / lipSyncStepMs;
    final i = x.floor();
    if (i >= env.length - 1) return 0;
    final f = x - i;
    return (env[i] * (1 - f) + env[i + 1] * f) / 100;
  }

  // مقاطع كلام: فتحات سريعة بأحجام مختلفة
  double _mouthAt(double t) {
    final syll = (0.5 + 0.5 * sin(t * 2 * pi * 14)).toDouble();
    final phrase = (0.55 + 0.45 * sin(t * 2 * pi * 3.1 + 1)).toDouble();
    return syll * phrase;
  }

  double _open(double ms) => !_moving ? 0.0 : _mouthFromVoice(ms) ?? _mouthAt((ms / 2000) % 1);

  @override
  Widget build(BuildContext context) {
    final ms = _t.inMicroseconds / 1000;
    final m = widget.mouth ?? _open(ms);
    final look = _looks[widget.charId] ?? _looks['musabbah']!;
    if (_moving) {
      // تفاعل مع الكلام: علو الصوت الناعم (متوسط 300 ملي) يرفع الحواجب ويحرك الراس،
      // والراس يميل يمين ويسار ببطء ويهز مع المقاطع القوية
      var energy = 0.0;
      for (var k = -3; k <= 3; k++) {
        energy += _open(max(0, ms + k * 50));
      }
      energy = (energy / 7).clamp(0.0, 1.0);
      // الجسم ثابت: الحواجب ترتفع، والعيون تنفتح شوي مع الكلام وترمش رمشة خفيفة،
      // والراس بس يميل ميلة بسيطة ويهز هزة خفيفة مع المقاطع
      final fadeIn = (ms / 250).clamp(0.0, 1.0);
      final blinkT = (ms - 700) % 1900; // رمشة بعد 0.7 ثانية وبعدها كل 1.9
      final blink = ms > 700 && blinkT < 140 ? 1 - sin(blinkT / 140 * pi) * 0.85 : 1.0;
      final eye = (1 + energy * 0.12 * fadeIn) * blink;
      final tilt = sin(ms / 1000 * 2 * pi * 0.7) * 0.03 * fadeIn;
      final nod = ((m - energy) * 0.012 + energy * 0.006) * fadeIn;
      return CustomPaint(painter: _FacePainter(look, mouth: m, brow: (energy * 1.6).clamp(0.0, 1.0) * fadeIn, eye: eye, headTilt: tilt, headNod: nod));
    }
    final painter = _FacePainter(look, mouth: m);
    if (m != 0) return CustomPaint(painter: painter);
    // وجه ساكت: صورة جاهزة (الوجه فيه مئات الأشكال). الرسم يطلع برا حدوده، والصورة مكبّرة 1.3
    return CachedPaint(cacheKey: look, painter: painter, bleed: 0.5, scale: 1.3);
  }
}

/// رسم الشخصية: دشداشة، رقبة، أذون، وجه بتظليل، لحية/شنب، حواجب، عيون، خشم، فم، وغطا راس.
class _FacePainter extends CustomPainter {
  final _Look look;
  final double mouth; // فتحة الفم وقت الكلام (0 مسكّر، 1 مفتوح)
  final double brow; // ارتفاع الحواجب وقت الكلام (0 عادي، 1 مرفوع)
  final double eye; // فتحة العين وقت الكلام (1 عادي، أكبر منفتحة، قريب من 0 رمشة)
  final double headTilt; // ميلان الراس بالراديان (الجسم ثابت)
  final double headNod; // رفعة الراس (نسبة من المقاس)
  _FacePainter(this.look, {this.mouth = 0, this.brow = 0, this.eye = 1, this.headTilt = 0, this.headNod = 0});

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
    final chin = look.wideChin ? 0.5 : 0.3; // عرض الذقن من نص عرض الوجه
    final hw = look.wide ? s * 0.235 : look.wideChin ? s * 0.19 : look.thin ? s * 0.18 : s * 0.2; // نص عرض الوجه

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
    if (look.pajama) {
      // خطوط البيجامة
      canvas.save();
      canvas.clipPath(robe);
      final stripe = Paint()
        ..color = const Color(0xFF2F4C72)
        ..strokeWidth = max(0.8, s * 0.011);
      for (var i = -9; i <= 9; i++) {
        final x = cx + i * s * 0.05;
        canvas.drawLine(Offset(x, s * 0.72), Offset(x + i * s * 0.012, s * 1.04), stripe);
      }
      canvas.restore();
    }
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
    if (look.openNeck) {
      canvas.drawLine(Offset(cx - s * 0.085, s * 0.66), Offset(cx - s * 0.095, s * 0.79), line);
      canvas.drawLine(Offset(cx + s * 0.085, s * 0.66), Offset(cx + s * 0.095, s * 0.79), line);
    } else {
      canvas.drawPath(neck, line);
    }
    // فتحة الدشداشة والفراخة (الشرابة)، أو ياقة القميص الباكستاني وأزراره
    if (look.shirt) {
      _shirtCollar(canvas, s, cx, line, fill);
    } else if (look.pajama) {
      _pajamaCollar(canvas, s, cx, line, fill);
    } else if (look.kameez) {
      _kameezCollar(canvas, s, cx, line, fill);
    } else {
    // الجيب المفتوح ينرسم قبل الفرفوشة (الفرفوشة تتعلق على طرفه المنثني)، وبدون خط الياقة على الرقبة
    if (look.openNeck) {
      _openNeck(canvas, s, cx, line);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(cx - s * 0.1, s * 0.79)
            ..quadraticBezierTo(cx, s * 0.86, cx + s * 0.1, s * 0.79),
          line);
    }
    canvas.drawLine(Offset(cx, s * (look.openNeck ? 0.835 : 0.82)), Offset(cx, s * 0.97), line); // خياطة الوسط من الرقبة
    // الفرفوشة: تتعلق من طرف الفتحة، جزء مبروم منفوخ، وخصر ضيق، وشرابة تنفتح تحته
    // (تحت 0.9 يغطيها إطار الشخصية)
    final fx = cx - s * (look.openNeck ? 0.05 : 0.07);
    final tassel = Color.lerp(look.robe, Colors.black, 0.42)!;
    canvas.save();
    if (look.openNeck) {
      // الطرف منثني لبرا، فالفرفوشة تميل معه شوي
      canvas.translate(0, s * 0.02);
      canvas.translate(fx, s * 0.8);
      canvas.rotate(0.3);
      canvas.translate(-fx, -s * 0.8);
    }
    final strands = Paint()
      ..color = Color.lerp(tassel, Colors.white, 0.3)!
      ..strokeWidth = max(0.5, s * 0.005);
    final twist = Path()
      ..moveTo(fx, s * 0.8)
      ..quadraticBezierTo(fx - s * 0.024, s * 0.82, fx - s * 0.005, s * 0.84)
      ..lineTo(fx + s * 0.005, s * 0.84)
      ..quadraticBezierTo(fx + s * 0.024, s * 0.82, fx, s * 0.8)
      ..close();
    canvas.drawPath(twist, fill(tassel));
    final fringe = Path()
      ..moveTo(fx - s * 0.005, s * 0.84)
      ..quadraticBezierTo(fx - s * 0.012, s * 0.87, fx - s * 0.034, s * 0.897)
      ..lineTo(fx + s * 0.034, s * 0.897)
      ..quadraticBezierTo(fx + s * 0.012, s * 0.87, fx + s * 0.005, s * 0.84)
      ..close();
    canvas.drawPath(fringe, fill(tassel));
    for (final x in [-0.024, -0.008, 0.008, 0.024]) {
      canvas.drawLine(Offset(fx + s * x * 0.2, s * 0.848), Offset(fx + s * x, s * 0.895), strands);
    }
    canvas.drawLine(Offset(fx - s * 0.006, s * 0.84), Offset(fx + s * 0.006, s * 0.84), Paint()..color = Color.lerp(tassel, Colors.black, 0.3)!..strokeWidth = max(0.8, s * 0.01));
    canvas.restore();
    }

    if (look.scarf) _shoulderShemagh(canvas, s, cx, line, fill);

    // من هني وتحت الراس: يميل ويهز شوي وقت الكلام والجسم ثابت (المحور فوق الرقبة)
    if (headTilt != 0 || headNod != 0) {
      canvas.translate(cx, s * 0.68);
      canvas.rotate(headTilt);
      canvas.translate(-cx, -s * 0.68 - headNod * s);
    }
    if (look.headScale != 1) {
      canvas.translate(cx, s * 0.67);
      canvas.scale(look.headScale);
      canvas.translate(-cx, -s * 0.67);
    }

    // الأذون
    for (final side in [-1.0, 1.0]) {
      final ear = Rect.fromCenter(center: Offset(cx + side * (hw + s * 0.015), s * 0.47), width: s * 0.07, height: s * 0.12);
      canvas.drawOval(ear, fill(skinMid));
      canvas.drawOval(ear, line);
      canvas.drawArc(ear.deflate(s * 0.015), side < 0 ? pi * 0.6 : -pi * 0.4, pi * 0.8, false, stroke(const Color(0xFF2A2420), 0.008));
    }

    // الوجه: بيضاوي بفك واضح، وتظليل من اليمين
    final jawY = look.long ? 0.68 : 0.65, chinY = look.long ? 0.765 : 0.73;
    var face = Path()
      ..moveTo(cx - hw, s * 0.36)
      ..quadraticBezierTo(cx - hw * 1.075, s * 0.56, cx - hw * 0.7, s * jawY)
      ..quadraticBezierTo(cx - hw * chin, s * chinY, cx, s * chinY)
      ..quadraticBezierTo(cx + hw * chin, s * chinY, cx + hw * 0.7, s * jawY)
      ..quadraticBezierTo(cx + hw * 1.075, s * 0.56, cx + hw, s * 0.36)
      ..quadraticBezierTo(cx, s * 0.2, cx - hw, s * 0.36)
      ..close();
    // الأقرع: قبة الراس جزء من الوجه نفسه (نفس اللون والتظليل وحد واحد)
    if (look.head == 'bald') {
      face = Path.combine(
          PathOperation.union,
          face,
          Path()
            ..moveTo(cx - hw, s * 0.42)
            ..cubicTo(cx - hw * 1.06, s * 0.21, cx - hw * 0.6, s * 0.15, cx, s * 0.15)
            ..cubicTo(cx + hw * 0.6, s * 0.15, cx + hw * 1.06, s * 0.21, cx + hw, s * 0.42)
            ..close());
    }
    canvas.drawPath(
        face,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-0.25, -0.2), radius: 0.85, colors: [skinLight, skinMid, skinDark], stops: const [0, 0.6, 1])
              .createShader(Rect.fromLTWH(cx - hw * 1.1, look.head == 'bald' ? s * 0.15 : s * 0.2, hw * 2.2, look.head == 'bald' ? s * 0.6 : s * 0.55)));
    if (look.thin && !look.wideChin) {
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
      'flat' => (0.424, 0.416),
      _ => (0.408, 0.398),
    };
    final browW = switch (look.brows) { 'angry' => 0.017, 'thick' => 0.02, 'bushy' => 0.026, _ => 0.013 };
    final eyeX = s * 0.097 * look.eyeGap; // بعد العين عن النص
    final gapShift = eyeX - s * 0.097;
    for (final side in [-1.0, 1.0]) {
      final xi = cx + side * (s * 0.035 + gapShift), xo = cx + side * (s * 0.165 + gapShift), xm = cx + side * (s * 0.1 + gapShift);
      final ym = min(yi, yo) - (look.brows == 'flat' ? 0.004 : 0.022);
      // وقت الكلام الحاجب يرتفع، وطرفه الداخلي أكثر (تعبير)
      final lift = brow * 0.018, liftIn = brow * 0.024;
      canvas.drawPath(
          Path()
            ..moveTo(xi, s * (yi - liftIn))
            ..quadraticBezierTo(xm, s * (ym - lift), xo, s * (yo - lift * 0.7))
            ..quadraticBezierTo(xm, s * (ym - lift + browW + 0.004), xi, s * (yi - liftIn + browW))
            ..close(),
          fill(look.white ? const Color(0xFFE2DED6) : const Color(0xFF241812)));
      // كثيف: شعيرات طالعة من الحواف عشان يبين أكثف
      if (look.brows == 'bushy') {
        final hairP = Paint()
          ..color = const Color(0xFF241812)
          ..strokeWidth = max(0.6, s * 0.0045)
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k <= 8; k++) {
          final t = k / 8;
          final x = xi + (xo - xi) * t;
          final yTop = s * ((1 - t) * (1 - t) * (yi - liftIn) + 2 * t * (1 - t) * (ym - lift) + t * t * (yo - lift * 0.7));
          // الجزء اللي يطلع برا الحاجب صغير (15% من الطول الأول)
          canvas.drawLine(Offset(x, yTop + s * 0.004), Offset(x + side * s * 0.008 * 0.15, yTop - s * 0.006 * 0.15), hairP);
        }
      }
    }

    // ظل بارد تحت العيون
    if (look.eyes == 'cold') {
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + side * eyeX, s * 0.5), width: s * 0.09, height: s * 0.02), fill(const Color(0x143A3F52)));
      }
    }

    // تجاعيد الكبر
    if (look.old) _wrinkles(canvas, s, cx, hw);

    // العيون (أوسع: أعرض وأطول شوي)
    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeX, ey = s * 0.462;
      canvas.save();
      canvas.translate(ex, ey);
      canvas.scale(1.22 * look.eyeSize, 1.35 * look.eyeSize * eye);
      canvas.translate(-ex, -ey);
      _eye(canvas, s, ex, ey, side, fill, stroke);
      canvas.restore();
    }

    if (look.mouth == 'grin') _smileLines(canvas, s, cx);
    // الخشم بعرضه الخاص لكل شخصية (من نص الوجه، وطوله نفسه)
    canvas.save();
    canvas.translate(cx, 0);
    canvas.scale(look.noseW, 1);
    canvas.translate(-cx, 0);
    if (look.nose == 'long') _longNose(canvas, s, cx, fill);
    _nose(canvas, s, cx, fill, stroke, line);
    canvas.restore();

    // الفم
    _mouth(canvas, s, cx, fill, line);

    // الشنب
    _mustache(canvas, s, cx, fill);

    // غطا الراس
    switch (look.head) {
      case 'kumma':
      case 'kummaWhite':
      case 'kummaBrown':
      case 'kummaGreen':
        _temples(canvas, s, cx, hw, fill);
        _kumma(canvas, s, cx, hw, line, fill, style: look.head);
      case 'turban':
      case 'turbanEmb':
        _turban(canvas, s, cx, hw, line, fill);
      case 'pakol':
        _temples(canvas, s, cx, hw, fill);
        _pakol(canvas, s, cx, hw, line, fill);
      case 'bald':
        _bald(canvas, s, cx, hw, fill);
      case 'qahfiya':
        _temples(canvas, s, cx, hw, fill);
        _qahfiya(canvas, s, cx, hw, line, fill);
      case 'softHair':
        _softHair(canvas, s, cx, hw, line);
      case 'smallKumma':
        // الشعر يبين تحت الكمّة بس (ما يطلع فوقها)
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, s * 0.2, s, s));
        _softHair(canvas, s, cx, hw, line);
        canvas.restore();
        // الكمّة العمانية البيضاء المطرزة (نفس رسمة كمّة سعيد)، متصغّرة بالطول ومكبّرة بالعرض على قد راسه مع الشعر
        canvas.save();
        canvas.translate(cx, s * 0.15);
        canvas.scale(1.09 / 1.035, (0.335 - 0.15) / (0.38 - 0.165));
        canvas.translate(-cx, -s * 0.165);
        _kumma(canvas, s, cx, hw, line, fill, style: 'kummaWhite', one: const Color(0xFFBDAE8D)); // التطريز كله ترابي
        canvas.restore();
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

  /// الخشم لكل الشخصيات: ظل الجسر من جهة، كرة الخشم بظل تحتها ولمعة فوقها،
  /// أجنحة واضحة، وفتحتين مايلات بدل النقط
  void _nose(Canvas canvas, double s, double cx, Paint Function(Color) fill, Paint Function(Color, double) stroke, Paint line) {
    final shade = Color.lerp(look.skin, const Color(0xFF3A2010), 0.45)!;
    // ظل جسر الخشم (جهة اليمين، الضو جاي من اليسار)
    canvas.drawPath(
        Path()
          ..moveTo(cx + s * 0.012, s * 0.45)
          ..quadraticBezierTo(cx + s * 0.03, s * 0.53, cx + s * 0.036, s * 0.555),
        stroke(const Color(0x2E402818), 0.008));
    canvas.drawPath(
        Path()
          ..moveTo(cx + s * 0.006, s * 0.46)
          ..quadraticBezierTo(cx + s * 0.02, s * 0.52, cx + s * 0.024, s * 0.545)
          ..lineTo(cx + s * 0.034, s * 0.548)
          ..quadraticBezierTo(cx + s * 0.026, s * 0.5, cx + s * 0.012, s * 0.45)
          ..close(),
        fill(shade.withValues(alpha: 0.16)));
    if (look.noseHook) {
      // حدبة على الجسر: خط معقوف بنص الخشم ولمعة فوق الحدبة، والرأس نازل شوي
      canvas.drawPath(
          Path()
            ..moveTo(cx + s * 0.004, s * 0.462)
            ..quadraticBezierTo(cx + s * 0.03, s * 0.488, cx + s * 0.018, s * 0.515)
            ..quadraticBezierTo(cx + s * 0.012, s * 0.53, cx + s * 0.022, s * 0.548),
          stroke(shade.withValues(alpha: 0.55), 0.008));
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.006, s * 0.49), width: s * 0.014, height: s * 0.022), fill(const Color(0x2EFFFFFF)));
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.002, s * 0.566), width: s * 0.03, height: s * 0.014), fill(shade.withValues(alpha: 0.3)));
    }
    // كرة الخشم: ظل ناعم تحتها، ولمعة فوقها
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.002, s * 0.561), width: s * 0.06, height: s * 0.018), fill(shade.withValues(alpha: 0.22)));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - s * 0.005, s * 0.541), width: s * 0.022, height: s * 0.014), fill(const Color(0x30FFFFFF)));
    canvas.drawCircle(Offset(cx - s * 0.007, s * 0.538), s * 0.0045, fill(const Color(0x55FFFFFF)));
    // الأجنحة (الطويل عنده أجنحته)
    if (look.nose != 'long') {
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(Rect.fromCenter(center: Offset(cx + side * s * 0.031, s * 0.553), width: s * 0.026, height: s * 0.024),
            side < 0 ? pi * 0.55 : -pi * 0.35, pi * 0.8, false, stroke(shade.withValues(alpha: 0.75), 0.008));
      }
    }
    // قاعدة الخشم
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.04, s * 0.555)
          ..quadraticBezierTo(cx - s * 0.02, s * 0.575, cx, s * 0.568)
          ..quadraticBezierTo(cx + s * 0.02, s * 0.575, cx + s * 0.04, s * 0.555),
        line);
    // الفتحتين: مايلات للداخل
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx + side * s * 0.019, s * 0.563);
      canvas.rotate(side * -0.35);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.019, height: s * 0.0095), fill(const Color(0xFF4A2818)));
      canvas.restore();
    }
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
      case 'circle':
        // سكسوكة سعودية مرسومة: خط رفيع ينزل من طرف الشنب ويدور حول الفم، ويتجمع بذقن مدبب
        final area = Path()
          ..moveTo(cx - s * 0.082, s * 0.628)
          ..quadraticBezierTo(cx - s * 0.09, s * 0.69, cx - s * 0.03, s * 0.735)
          ..quadraticBezierTo(cx, s * 0.758, cx + s * 0.03, s * 0.735)
          ..quadraticBezierTo(cx + s * 0.09, s * 0.69, cx + s * 0.082, s * 0.628)
          ..lineTo(cx + s * 0.068, s * 0.63)
          ..quadraticBezierTo(cx + s * 0.07, s * 0.668, cx + s * 0.026, s * 0.678)
          ..quadraticBezierTo(cx, s * 0.668, cx - s * 0.026, s * 0.678)
          ..quadraticBezierTo(cx - s * 0.07, s * 0.668, cx - s * 0.068, s * 0.63)
          ..close();
        canvas.drawPath(area, Paint()..color = const Color(0xA61C140F));
        strands(area, 140, const Color(0x664A3A30), 0.01);
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
    final cold = look.eyes == 'cold';
    final calm = look.eyes == 'calm' || cold;
    final smiling = look.eyes == 'smile';
    final sad = look.brows == 'sad';
    final topY = cold ? -0.013 : calm ? -0.024 : (smiling ? -0.028 : -0.032);
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
    if (!cold) canvas.drawCircle(iris + Offset(-s * 0.006, -s * 0.004), s * 0.0045, fill(const Color(0xDDFFFFFF)));
    // الرموش فوق
    canvas.drawPath(
        Path()
          ..moveTo(ex - s * 0.046, ey + s * (0.003 - droop))
          ..quadraticBezierTo(ex - s * 0.008, ey + s * (topY - 0.003), ex + s * 0.046, ey + s * (-0.003 + droop)),
        stroke(const Color(0xFF1A110C), cold ? 0.02 : calm ? 0.016 : 0.012));
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
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, s * w)
      ..strokeCap = StrokeCap.round;
    final lipY = s * 0.632;
    final talk = mouth.clamp(0.0, 1.0);
    final grin = look.mouth == 'grin' || look.mouth == 'gap';
    // فتحة الفم: وقت الكلام، أو الضحكة العريضة
    final open = max(talk * s * 0.065, grin ? s * 0.042 : 0.0);
    // زوايا الفم: فوق للابتسامة وتحت للعبسة
    final corner = switch (look.mouth) {
      'smile' || 'grin' || 'gap' => -s * 0.01,
      'frown' => s * 0.012,
      'faint' => -s * 0.006,
      _ => 0.0,
    };
    final w = (grin ? s * 0.078 : look.mouth == 'faint' ? s * 0.05 : s * 0.055) * (0.88 + 0.12 * look.lips);
    final lipK = look.lips; // سماكة الشفايف
    final shade = Color.lerp(look.skin, const Color(0xFF3A2010), 0.45)!;
    // النقرة بين الخشم والشفة (خطين خفيفين وظل بينهم)
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.008, s * 0.576)
          ..lineTo(cx - s * 0.011, lipY - s * 0.011 * lipK)
          ..lineTo(cx + s * 0.011, lipY - s * 0.011 * lipK)
          ..lineTo(cx + s * 0.008, s * 0.576)
          ..close(),
        fill(shade.withValues(alpha: 0.1)));
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(Offset(cx + side * s * 0.008, s * 0.578), Offset(cx + side * s * 0.012, lipY - s * 0.012 * lipK), stroke(shade.withValues(alpha: 0.32), 0.005));
    }
    // ظل تحت الشفة التحتانية (فوق الذقن)
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, lipY + open + s * (0.03 + 0.008 * lipK)), width: w * 1.1, height: s * 0.016), fill(shade.withValues(alpha: 0.2)));
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
            ..quadraticBezierTo(cx, lipY + open * 2.1, cx - w * 0.9, lipY + corner)
            ..close());
      // داخل الفم أحمر مثل فم الإنسان: أفتح بالنص وأغمق عند الأطراف والحلق
      canvas.drawPath(
          hole,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(0, 0.2),
              radius: 0.75,
              colors: [Color(0xFFA8302E), Color(0xFF7E2022), Color(0xFF501214)],
              stops: [0, 0.55, 1],
            ).createShader(hole.getBounds()));
      canvas.save();
      canvas.clipPath(hole);
      final teeth = Rect.fromLTWH(cx - w * 0.8, lipY - s * 0.004, w * 1.6, grin ? min(open * 0.75, s * 0.03) : min(open * 0.3, s * 0.018));
      // اللسان وردي تحت بلمعة خفيفة، والأسنان التحتانية لما الفم ينفتح زيادة
      final tongue = Rect.fromCenter(center: Offset(cx, lipY + open * 0.95), width: w * 1.3, height: open * 0.7);
      canvas.drawOval(tongue, fill(const Color(0xFFD86A62)));
      canvas.drawOval(Rect.fromCenter(center: tongue.center.translate(-w * 0.15, -open * 0.12), width: w * 0.4, height: open * 0.18), fill(const Color(0x40FFFFFF)));
      canvas.drawRect(teeth, fill(const Color(0xFFF1EDE6)));
      canvas.drawLine(Offset(cx, teeth.top), Offset(cx, teeth.bottom), stroke(const Color(0x33000000), 0.004)); // بين السنين القدام
      if (open > s * 0.03) {
        canvas.drawRect(Rect.fromLTWH(cx - w * 0.55, lipY + open * 0.92, w * 1.1, s * 0.007), fill(const Color(0xFFE4DED4)));
      }
      if (look.mouth == 'gap') canvas.drawRect(Rect.fromLTWH(cx + s * 0.004, teeth.top, s * 0.014, teeth.height), fill(const Color(0xFF3A1414))); // سن ناقص
      canvas.restore();
    }
    // الشفة الفوقانية: قوس كيوبيد وحدّ أغمق فوقه
    final upper = Path()
      ..moveTo(cx - w, lipY + corner)
      ..quadraticBezierTo(cx - s * 0.02, lipY - s * 0.013 * lipK, cx, lipY - s * 0.007 * lipK)
      ..quadraticBezierTo(cx + s * 0.02, lipY - s * 0.013 * lipK, cx + w, lipY + corner)
      ..quadraticBezierTo(cx, lipY + s * 0.003, cx - w, lipY + corner)
      ..close();
    canvas.drawPath(upper, fill(Color.lerp(look.skin, const Color(0xFF7A3A30), 0.55)!));
    canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.8, lipY + corner * 0.8 - s * 0.004 * lipK)
          ..quadraticBezierTo(cx - s * 0.02, lipY - s * 0.013 * lipK, cx, lipY - s * 0.007 * lipK)
          ..quadraticBezierTo(cx + s * 0.02, lipY - s * 0.013 * lipK, cx + w * 0.8, lipY + corner * 0.8 - s * 0.004 * lipK),
        stroke(Color.lerp(look.skin, const Color(0xFF4A2018), 0.55)!.withValues(alpha: 0.6), 0.005));
    // الشفة التحتانية تنزل مع الفتح، بلمعة صغيرة
    final ly = lipY + open;
    final lowerCol = Color.lerp(look.skin, const Color(0xFF8A4A3C), 0.5)!;
    canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.9, ly + corner * 0.6)
          ..quadraticBezierTo(cx, ly + s * 0.024 * lipK, cx + w * 0.9, ly + corner * 0.6)
          ..quadraticBezierTo(cx, ly + s * 0.004, cx - w * 0.9, ly + corner * 0.6)
          ..close(),
        fill(lowerCol));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.15, ly + s * 0.011 * lipK), width: w * 0.5, height: s * 0.006 * lipK), fill(const Color(0x40FFFFFF)));
    // زوايا الفم: نقطة غامقة وطية صغيرة
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * w;
      canvas.drawCircle(Offset(x, lipY + corner), s * 0.0045, fill(shade.withValues(alpha: 0.5)));
      canvas.drawPath(
          Path()
            ..moveTo(x + side * s * 0.004, lipY + corner - s * 0.008)
            ..quadraticBezierTo(x + side * s * 0.012, lipY + corner, x + side * s * 0.006, lipY + corner + s * 0.01),
          stroke(shade.withValues(alpha: 0.28), 0.005));
    }
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
    if (look.mustache == 'bushy') return _bushyMustache(canvas, s, cx, fill);
    final trim = look.mustache == 'trim';
    final thick = look.mustache == 'thick' || trim;
    final lipY = s * 0.632;
    final w = trim ? s * 0.086 : thick ? s * 0.095 : s * 0.085;
    final h = trim ? s * 0.034 : thick ? s * 0.05 : s * 0.045;
    final mus = Path()
      ..moveTo(cx - w, lipY - s * (thick ? 0.004 : 0.012))
      ..quadraticBezierTo(cx - w * 0.5, lipY - h, cx, lipY - h * 0.8)
      ..quadraticBezierTo(cx + w * 0.5, lipY - h, cx + w, lipY - s * (thick ? 0.004 : 0.012))
      ..quadraticBezierTo(cx + w * 0.5, lipY - s * (thick ? 0.014 : 0.022), cx, lipY - s * (thick ? 0.014 : 0.02))
      ..quadraticBezierTo(cx - w * 0.5, lipY - s * (thick ? 0.014 : 0.022), cx - w, lipY - s * (thick ? 0.004 : 0.012))
      ..close();
    canvas.drawPath(mus, fill(look.white ? const Color(0xF5F1EFEA) : (trim ? const Color(0xA6140C08) : thick ? const Color(0xE6140C08) : const Color(0x8C1C120C))));
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

  /// شنب كثيف وعريض: يغطي فوق الشفة كلها، وأطرافه نازلة شوي عند زوايا الفم
  void _bushyMustache(Canvas canvas, double s, double cx, Paint Function(Color) fill) {
    final lipY = s * 0.632;
    final w = s * 0.118, h = s * 0.066;
    final mus = Path()
      ..moveTo(cx - w, lipY + s * 0.016)
      ..quadraticBezierTo(cx - w * 1.02, lipY - h * 0.55, cx - w * 0.55, lipY - h)
      ..quadraticBezierTo(cx - w * 0.15, lipY - h * 1.12, cx, lipY - h * 0.88)
      ..quadraticBezierTo(cx + w * 0.15, lipY - h * 1.12, cx + w * 0.55, lipY - h)
      ..quadraticBezierTo(cx + w * 1.02, lipY - h * 0.55, cx + w, lipY + s * 0.016)
      ..quadraticBezierTo(cx + w * 0.8, lipY - s * 0.004, cx + w * 0.5, lipY - s * 0.008)
      ..quadraticBezierTo(cx, lipY - s * 0.016, cx - w * 0.5, lipY - s * 0.008)
      ..quadraticBezierTo(cx - w * 0.8, lipY - s * 0.004, cx - w, lipY + s * 0.016)
      ..close();
    canvas.drawPath(mus, fill(const Color(0xF2120A06)));
    canvas.save();
    canvas.clipPath(mus);
    final rnd = Random(7);
    final p = Paint()
      ..color = const Color(0x4D6E5646)
      ..strokeWidth = max(0.5, s * 0.004)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 110; i++) {
      final x = cx + (rnd.nextDouble() * 2 - 1) * w;
      final y = lipY + s * 0.01 - rnd.nextDouble() * (h + s * 0.01);
      final dir = x < cx ? -1 : 1;
      canvas.drawLine(Offset(x, y), Offset(x + dir * s * 0.007, y + s * 0.012), p);
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
  void _kumma(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill, {required String style, Color? one}) {
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

    if (style == 'kummaBrown' || style == 'kummaGreen') {
      _brownEmbroidery(canvas, s, cx, half, fill, color: style == 'kummaGreen' ? const Color(0xFF1F5E3A) : const Color(0xFF6E4234));
    } else if (white) {
      // كمّة سعيد البيضاء بتطريز ملوّن مفصّل: وردات فوق، حزام متعرّج بمعيّنات، شريطين، وصف معيّنات وأسهم تحت
      // one: كل التطريز بلون واحد (كمّة بو شنب الترابية)
      final purple = one ?? const Color(0xFF7B1FA2), blueE = one ?? const Color(0xFF1E6FD9), red = one ?? const Color(0xFFD32F2F);
      final yellow = one ?? const Color(0xFFFFD54F);
      final thin = Paint()
        ..color = red
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, s * 0.0065)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      // القبة: وردات بأربع بتلات، وبينها نقاط حمرا
      for (var r = 0; r < 2; r++) {
        final y = s * (0.18 + r * 0.022);
        for (var i = -5; i <= 5; i++) {
          final x = cx + (i + (r.isOdd ? 0.5 : 0)) * s * 0.046;
          final c = (i + r).isEven ? purple : blueE;
          for (final (dx, dy) in const [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]) {
            canvas.drawCircle(Offset(x + dx * s * 0.0065, y + dy * s * 0.0065), s * 0.0048, fill(c));
          }
          canvas.drawCircle(Offset(x, y), s * 0.003, fill(yellow));
          canvas.drawCircle(Offset(x + s * 0.023, y), s * 0.003, fill(red));
        }
      }
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.207, half * 2.2, s * 0.005), fill(purple));
      // الحزام الكبير: خطين متعرّجين أحمر، ومعيّن أزرق داخل كل مثلث، ونقطة بنفسجية بالمثلثات المقلوبة
      const cell = 0.05;
      final yTop = s * 0.222, yBot = s * 0.312;
      for (final yy in [yTop, yBot]) {
        final zig = Path()..moveTo(cx - half * 1.1, yy);
        var up = true;
        for (var x = cx - half * 1.1; x <= cx + half * 1.1; x += s * cell / 2) {
          zig.lineTo(x, up ? yy : (yy + (yy == yTop ? 1 : -1) * s * 0.03));
          up = !up;
        }
        canvas.drawPath(zig, thin);
      }
      for (var i = -5; i <= 5; i++) {
        final x = cx + i * s * cell;
        motif(diamond(x, s * 0.267, s * 0.014, s * 0.022), blueE);
        canvas.drawPath(diamond(x, s * 0.267, s * 0.005, s * 0.008), fill(one == null ? yellow : Colors.white));
        canvas.drawCircle(Offset(x + s * cell / 2, s * 0.267), s * 0.0055, fill(purple));
        motif(chevron(x + s * cell / 2, s * 0.243, s * 0.008, s * 0.012), red);
        motif(chevron(x + s * cell / 2, s * 0.291, s * 0.008, s * 0.012, up: true), red);
      }
      // شريطين بنفسجي بينهم خط أحمر
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.321, half * 2.2, s * 0.006), fill(purple));
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.33, half * 2.2, s * 0.003), fill(red));
      canvas.drawRect(Rect.fromLTWH(cx - half * 1.1, s * 0.336, half * 2.2, s * 0.006), fill(purple));
      // صف تحت: معيّنات حمرا وأسهم زرقا
      for (var i = -6; i <= 6; i++) {
        final x = cx + i * s * 0.036;
        if (i.isEven) {
          motif(diamond(x, s * 0.356, s * 0.008, s * 0.011), red);
        } else {
          canvas.drawPath(
              Path()
                ..moveTo(x - s * 0.009, s * 0.364)
                ..lineTo(x, s * 0.348)
                ..lineTo(x + s * 0.009, s * 0.364)
                ..close(),
              fill(blueE));
        }
      }
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
  void _brownEmbroidery(Canvas canvas, double s, double cx, double half, Paint Function(Color) fill, {required Color color}) {
    final brown = color;
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
    canvas.save();
    canvas.translate(cx, s * 0.3);
    canvas.rotate(look.tilt);
    canvas.translate(-cx, -s * 0.3);
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
    // الطرف طالع على اليمين: جزء من نفس القماش، فينرسم مع المصر بحد واحد
    final tail = Path()
      ..moveTo(cx + half * 0.6, top + s * 0.05)
      ..quadraticBezierTo(cx + half * 0.98, top + s * 0.005, cx + half * 1.14, top + s * 0.045)
      ..quadraticBezierTo(cx + half * 1.0, top + s * 0.075, cx + half * 0.84, top + s * 0.1)
      ..close();
    final whole = Path.combine(PathOperation.union, shape, tail);
    canvas.drawPath(
        whole,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, c, dark], stops: const [0, 0.5, 1])
              .createShader(shape.getBounds()));
    canvas.save();
    canvas.clipPath(whole);
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
    if (look.head == 'turbanEmb') _embroidery(canvas, s, cx, half, top, bottom);
    canvas.restore();
    canvas.drawPath(whole, line);
    // ثنية خفيفة عند مدخل الطرف باللون نفسه
    canvas.drawPath(
        Path()
          ..moveTo(cx + half * 0.6, top + s * 0.05)
          ..quadraticBezierTo(cx + half * 0.7, top + s * 0.085, cx + half * 0.84, top + s * 0.1),
        Paint()
          ..color = dark.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.006
          ..strokeCap = StrokeCap.round);
    // أهداب الطرف
    for (var i = 0; i < 4; i++) {
      final x = cx + half * (1.0 + i * 0.03);
      canvas.drawLine(Offset(x, top + s * (0.035 + i * 0.008)), Offset(x + s * 0.012, top + s * (0.05 + i * 0.008)),
          Paint()
            ..color = dark
            ..strokeWidth = max(0.5, s * 0.005)
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();
  }

  /// تطريز المصر (مثل مصر بو شنب): شريط عريض مايل فوق بلون عنابي وعليه نقشة حمرا وذهبية،
  /// ونقاط ذهبية وحمرا على حواف اللفات تحت
  void _embroidery(Canvas canvas, double s, double cx, double half, double top, double bottom) {
    const maroon = Color(0xFF7A2E26), red = Color(0xFFC8432F), gold = Color(0xFFD9A441), cream = Color(0xFFE8C98A);
    final dot = Paint();
    // الشريط المايل من يسار تحت لفوق يمين
    final band = Path()
      ..moveTo(cx - half * 1.1, top + s * 0.11)
      ..quadraticBezierTo(cx - half * 0.2, top + s * 0.0, cx + half * 0.75, top - s * 0.01)
      ..lineTo(cx + half * 1.05, top + s * 0.11)
      ..quadraticBezierTo(cx - half * 0.1, top + s * 0.13, cx - half * 1.1, top + s * 0.235)
      ..close();
    canvas.drawPath(band, Paint()..color = maroon.withValues(alpha: 0.92));
    canvas.save();
    canvas.clipPath(band);
    // نقشة: معينات ذهبية بنصها نقطة حمرا، بصفين
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i < 9; i++) {
        final t = i / 8;
        final x = cx - half * 1.05 + t * half * 2.0 + row * s * 0.02;
        final y = top + s * (0.15 - t * 0.12 + row * 0.04) - s * 0.01;
        final d = s * 0.018;
        canvas.drawPath(
            Path()
              ..moveTo(x, y - d)
              ..lineTo(x + d, y)
              ..lineTo(x, y + d)
              ..lineTo(x - d, y)
              ..close(),
            dot..color = gold.withValues(alpha: 0.9));
        canvas.drawCircle(Offset(x, y), d * 0.45, dot..color = red);
      }
    }
    canvas.restore();
    // حواف الشريط: خيط كريمي
    final edge = Paint()
      ..color = cream.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, s * 0.004);
    canvas.drawPath(band, edge);
    // اللفات تحت: نقاط تطريز حمرا وذهبية بالتناوب
    for (var i = 0; i < 3; i++) {
      final y = bottom - s * (0.03 + i * 0.05);
      for (var k = 0; k <= 14; k++) {
        final t = k / 14;
        final x = cx - half * 1.0 + t * half * 2.0;
        // نفس ميلان اللفة تقريباً
        final yy = y + s * 0.03 - t * s * 0.045 - sin(t * pi) * s * 0.02;
        canvas.drawCircle(Offset(x, yy), s * 0.007, dot..color = (k + i).isEven ? gold : red);
      }
    }
  }

  /// القحفية: طاقية مخرّمة مدوّرة، والشعر يبين تحتها
  void _qahfiya(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill) {
    canvas.drawPath(
        Path()
          ..moveTo(cx - hw * 1.03, s * 0.31)
          ..lineTo(cx + hw * 1.03, s * 0.31)
          ..lineTo(cx + hw * 1.0, s * 0.4)
          ..quadraticBezierTo(cx + hw * 0.92, s * 0.355, cx + hw * 0.5, s * 0.345)
          ..quadraticBezierTo(cx, s * 0.335, cx - hw * 0.5, s * 0.345)
          ..quadraticBezierTo(cx - hw * 0.92, s * 0.355, cx - hw * 1.0, s * 0.4)
          ..close(),
        fill(const Color(0xFF1A1310)));
    final top = s * 0.185, bottom = s * 0.335, half = hw * 1.05;
    final rim = Path()
      ..moveTo(cx - half, bottom)
      ..quadraticBezierTo(cx, bottom - s * 0.034, cx + half, bottom);
    final cap = Path()
      ..moveTo(cx - half, bottom)
      ..cubicTo(cx - half * 1.03, s * 0.25, cx - half * 0.72, top, cx, top)
      ..cubicTo(cx + half * 0.72, top, cx + half * 1.03, s * 0.25, cx + half, bottom)
      ..quadraticBezierTo(cx, bottom - s * 0.034, cx - half, bottom)
      ..close();
    final dark = look.headColor.computeLuminance() < 0.2;
    canvas.drawPath(cap, fill(dark ? look.headColor : const Color(0xFFFBFAF6)));
    canvas.save();
    canvas.clipPath(cap);
    // التخريم: صفوف نقاط صغيرة
    final hole = fill(dark ? const Color(0x59FFFFFF) : const Color(0x40483F36));
    for (var r = 0; r < 6; r++) {
      for (var i = -10; i <= 10; i++) {
        canvas.drawCircle(Offset(cx + (i + (r.isOdd ? 0.5 : 0)) * s * 0.024, s * (0.2 + r * 0.021)), s * 0.0042, hole);
      }
    }
    canvas.drawPath(
        rim,
        Paint()
          ..color = dark ? Color.lerp(look.headColor, Colors.white, 0.14)! : const Color(0xFFEFEBE2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.034);
    canvas.drawPath(
        rim.shift(Offset(0, -s * 0.017)),
        Paint()
          ..color = dark ? const Color(0x40FFFFFF) : const Color(0x40483F36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.6, s * 0.005));
    canvas.drawPath(
        cap,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x00000000), Color(0x00000000), Color(0x30000000)], stops: [0, 0.5, 1])
              .createShader(cap.getBounds()));
    canvas.restore();
    canvas.drawPath(cap, line);
  }

  /// الشماغ الأحمر والأبيض مفصوخ ومرمي على الكتف
  void _shoulderShemagh(Canvas canvas, double s, double cx, Paint line, Paint Function(Color) fill) {
    // ينتفخ فوق الكتف وينزل عريض على الصدر
    final cloth = Path()
      ..moveTo(cx - s * 0.1, s * 0.75)
      ..quadraticBezierTo(cx - s * 0.22, s * 0.695, cx - s * 0.34, s * 0.775)
      ..lineTo(cx - s * 0.42, s * 1.04)
      ..lineTo(cx - s * 0.03, s * 1.04)
      ..quadraticBezierTo(cx - s * 0.125, s * 0.87, cx - s * 0.1, s * 0.75)
      ..close();
    canvas.drawPath(cloth.shift(Offset(s * 0.012, s * 0.008)), fill(const Color(0x2E000000))); // ظله على الثوب
    canvas.drawPath(cloth, fill(const Color(0xFFFBFAF6)));
    canvas.save();
    canvas.clipPath(cloth);
    // المربعات تميل مع نزول القماش
    canvas.save();
    canvas.translate(cx - s * 0.2, s * 0.86);
    canvas.rotate(0.2);
    final cell = s * 0.024;
    for (var i = -14; i <= 14; i++) {
      for (var j = -12; j <= 12; j++) {
        if ((i + j).isOdd) continue;
        canvas.drawRect(Rect.fromLTWH(i * cell, j * cell, cell * 0.74, cell * 0.74), fill(const Color(0xFFC8202B)));
      }
    }
    canvas.restore();
    final fold = Paint()
      ..color = const Color(0x73483F36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, s * 0.011)
      ..strokeCap = StrokeCap.round;
    for (final (x0, x1) in const [(0.13, 0.09), (0.17, 0.15), (0.22, 0.22), (0.27, 0.3), (0.32, 0.37)]) {
      canvas.drawPath(
          Path()
            ..moveTo(cx - s * x0, s * 0.74)
            ..quadraticBezierTo(cx - s * (x1 + 0.05), s * 0.86, cx - s * x1, s * 1.03),
          fold);
    }
    canvas.drawPath(
        cloth,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x26000000), Color(0x00000000), Color(0x1F000000)], stops: [0, 0.55, 1])
              .createShader(cloth.getBounds()));
    canvas.restore();
    canvas.drawPath(cloth, line);
  }

  /// رقبة البيجامة مفتوحة على شكل V: الصدر يبين، بحافتين فاتحتين، وصف أزرار تحتها
  void _pajamaCollar(Canvas canvas, double s, double cx, Paint line, Paint Function(Color) fill) {
    canvas.drawLine(Offset(cx, s * 0.93), Offset(cx, s * 1.02), line);
    canvas.drawCircle(Offset(cx + s * 0.018, s * 0.975), s * 0.011, fill(const Color(0xFFF4F1E8)));
    canvas.drawCircle(Offset(cx + s * 0.018, s * 0.975), s * 0.011, line);
    final chest = Path()
      ..moveTo(cx - s * 0.095, s * 0.76)
      ..lineTo(cx, s * 0.915)
      ..lineTo(cx + s * 0.095, s * 0.76)
      ..close();
    canvas.drawPath(chest, fill(Color.lerp(look.skin, Colors.black, 0.06)!));
    for (final side in [-1.0, 1.0]) {
      final edge = Path()
        ..moveTo(cx + side * s * 0.095, s * 0.755)
        ..lineTo(cx + side * s * 0.13, s * 0.765)
        ..lineTo(cx + side * s * 0.003, s * 0.955)
        ..lineTo(cx, s * 0.915)
        ..close();
      canvas.drawPath(edge, fill(Color.lerp(look.robe, Colors.white, 0.5)!));
      canvas.drawPath(edge, line);
    }
  }

  /// ياقة القميص: جناحين مدببين ينزلون للصدر، وصف أزرار بالنص
  void _shirtCollar(Canvas canvas, double s, double cx, Paint line, Paint Function(Color) fill) {
    canvas.drawLine(Offset(cx, s * 0.84), Offset(cx, s * 1.02), line);
    for (final y in [0.895, 0.955]) {
      final c = Offset(cx + s * 0.016, s * y);
      canvas.drawCircle(c, s * 0.009, fill(Color.lerp(look.robe, Colors.white, 0.7)!));
      canvas.drawCircle(c, s * 0.009, line);
    }
    for (final side in [-1.0, 1.0]) {
      final flap = Path()
        ..moveTo(cx + side * s * 0.112, s * 0.758)
        ..lineTo(cx + side * s * 0.035, s * 0.885)
        ..lineTo(cx + side * s * 0.004, s * 0.82)
        ..quadraticBezierTo(cx + side * s * 0.05, s * 0.79, cx + side * s * 0.075, s * 0.752)
        ..close();
      canvas.drawPath(flap, fill(Color.lerp(look.robe, Colors.white, 0.25)!));
      canvas.drawPath(flap, line);
    }
  }

  /// الراس الأقرع (القبة من شكل الوجه): شعر قصير رمادي غامق على الجنبين فوق الأذون، ولمعة خفيفة
  void _bald(Canvas canvas, double s, double cx, double hw, Paint Function(Color) fill) {
    // شعر قصير على الجنبين
    final rnd = Random(3);
    final dot = Paint()..color = const Color(0x8C2A2420);
    for (final side in [-1.0, 1.0]) {
      final patch = Path()
        ..moveTo(cx + side * hw * 1.0, s * 0.43)
        ..quadraticBezierTo(cx + side * hw * 1.04, s * 0.33, cx + side * hw * 0.93, s * 0.27)
        ..lineTo(cx + side * hw * 0.84, s * 0.3)
        ..quadraticBezierTo(cx + side * hw * 0.92, s * 0.36, cx + side * hw * 0.9, s * 0.43)
        ..close();
      canvas.drawPath(patch, fill(const Color(0x7A2E2824)));
      canvas.save();
      canvas.clipPath(patch);
      final b = patch.getBounds();
      for (var i = 0; i < 60; i++) {
        canvas.drawCircle(Offset(b.left + rnd.nextDouble() * b.width, b.top + rnd.nextDouble() * b.height), s * 0.0028, dot);
      }
      canvas.restore();
    }
    // لمعة
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - hw * 0.35, s * 0.2), width: hw * 0.55, height: s * 0.035), fill(const Color(0x40FFFFFF)));
  }

  /// ياقة القميص الباكستاني: ياقة واقفة حول الرقبة، وشق قدام بثلاث أزرار
  void _kameezCollar(Canvas canvas, double s, double cx, Paint line, Paint Function(Color) fill) {
    final dark = Color.lerp(look.robe, Colors.black, 0.18)!;
    for (final side in [-1.0, 1.0]) {
      final band = Path()
        ..moveTo(cx + side * s * 0.1, s * 0.765)
        ..quadraticBezierTo(cx + side * s * 0.1, s * 0.82, cx + side * s * 0.012, s * 0.835)
        ..lineTo(cx + side * s * 0.012, s * 0.805)
        ..quadraticBezierTo(cx + side * s * 0.08, s * 0.795, cx + side * s * 0.085, s * 0.745)
        ..close();
      canvas.drawPath(band, fill(Color.lerp(look.robe, Colors.white, 0.2)!));
      canvas.drawPath(band, line);
    }
    final placket = Rect.fromLTRB(cx - s * 0.022, s * 0.835, cx + s * 0.022, s * 0.99);
    canvas.drawRect(placket, fill(Color.lerp(look.robe, Colors.white, 0.12)!));
    canvas.drawLine(placket.topLeft, placket.bottomLeft, line);
    canvas.drawLine(placket.topRight, placket.bottomRight, line);
    for (final y in [0.865, 0.915, 0.965]) {
      final c = Offset(cx, s * y);
      canvas.drawCircle(c, s * 0.009, fill(dark));
      canvas.drawCircle(c, s * 0.009, line);
    }
  }

  /// پاکول: طاقية صوف بلفة عريضة مدوّرة تحت، وفوقها سطح مسطّح شوي أعرض من اللفة
  void _pakol(Canvas canvas, double s, double cx, double hw, Paint line, Paint Function(Color) fill) {
    final c = look.headColor;
    final half = hw * 1.08;
    canvas.save();
    canvas.translate(cx, s * 0.3);
    canvas.rotate(look.tilt);
    canvas.translate(-cx, -s * 0.3);
    // السطح: بيضاوي مسطّح يطلع من ورا اللفة
    final top = Rect.fromLTRB(cx - half * 1.06, s * 0.17, cx + half * 1.06, s * 0.27);
    canvas.drawOval(top, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(c, Colors.white, 0.25)!, c]).createShader(top));
    canvas.drawOval(top, line);
    // اللفة: أنبوب صوف ملفوف (فاتح بالنص وغامق فوق وتحت)
    final roll = RRect.fromLTRBR(cx - half, s * 0.235, cx + half, s * 0.355, Radius.circular(s * 0.06));
    canvas.drawRRect(
        roll,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            Color.lerp(c, Colors.black, 0.25)!,
            Color.lerp(c, Colors.white, 0.18)!,
            c,
            Color.lerp(c, Colors.black, 0.35)!,
          ], stops: const [0, 0.35, 0.65, 1]).createShader(roll.outerRect));
    // نسيج الصوف: نقاط ناعمة
    canvas.save();
    canvas.clipRRect(roll);
    final rnd = Random(11);
    final dot = Paint()..color = const Color(0x22000000);
    for (var i = 0; i < 160; i++) {
      canvas.drawCircle(Offset(cx + (rnd.nextDouble() * 2 - 1) * half, s * (0.235 + rnd.nextDouble() * 0.12)), s * 0.0035, dot);
    }
    canvas.restore();
    // خط اللفة (مكان ما تنطوي)
    canvas.drawPath(
        Path()
          ..moveTo(cx - half * 0.96, s * 0.3)
          ..quadraticBezierTo(cx, s * 0.312, cx + half * 0.96, s * 0.3),
        Paint()
          ..color = Color.lerp(c, Colors.black, 0.45)!.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.6, s * 0.005));
    canvas.drawRRect(roll, line);
    canvas.restore();
  }

  /// جيب الدشداشة: الياقة مرخية (أوطى من الرقبة) والصدر يبين داخلها، وشق صغير مفتوح من جهة الفرفوشة
  void _openNeck(Canvas canvas, double s, double cx, Paint line) {
    // يبدأ بنفس لون الرقبة بالضبط (بدون حد بينهم)، ويغمق شوي بس تحت
    final skinTop = look.skin, skinLow = Color.lerp(look.skin, Colors.black, 0.12)!;
    // الياقة: قوس أوطى من الرقبة، يكمّل الجلد من الرقبة للصدر بدون قماش بينهم
    final u = Path()
      ..moveTo(cx - s * 0.112, s * 0.775)
      ..quadraticBezierTo(cx, s * 0.9, cx + s * 0.112, s * 0.775)
      ..lineTo(cx + s * 0.09, s * 0.76)
      ..lineTo(cx - s * 0.09, s * 0.76)
      ..close();
    // الشق: من الياقة جهة الفرفوشة ينزل لين خياطة الوسط
    final slit = Path()
      ..moveTo(cx - s * 0.05, s * 0.82)
      ..quadraticBezierTo(cx - s * 0.028, s * 0.875, cx, s * 0.915)
      ..lineTo(cx, s * 0.835)
      ..close();
    final chest = Path.combine(PathOperation.union, u, slit);
    canvas.drawPath(
        chest,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skinTop, skinLow]).createShader(chest.getBounds()));
    // حافة الياقة والشق (على القماش)
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.112, s * 0.775)
          ..quadraticBezierTo(cx - s * 0.085, s * 0.808, cx - s * 0.05, s * 0.82)
          ..quadraticBezierTo(cx - s * 0.028, s * 0.875, cx, s * 0.915),
        line);
    canvas.drawPath(
        Path()
          ..moveTo(cx, s * 0.835)
          ..quadraticBezierTo(cx + s * 0.06, s * 0.826, cx + s * 0.112, s * 0.775),
        line);
    // ثنية خفيفة على طرف الشق (القماش منثني لبرا شوي)
    canvas.drawPath(
        Path()
          ..moveTo(cx - s * 0.06, s * 0.83)
          ..quadraticBezierTo(cx - s * 0.04, s * 0.88, cx - s * 0.012, s * 0.915),
        Paint()
          ..color = Color.lerp(look.robe, Colors.black, 0.25)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.6, s * 0.005)
          ..strokeCap = StrokeCap.round);
  }

  /// شعر أسود ناعم طويل شوي: حجم فوق، غرّة مسحوبة على الجنب فوق الجبهة، ويغطي فوق الأذن
  void _softHair(Canvas canvas, double s, double cx, double hw, Paint line) {
    final hair = Path()
      ..moveTo(cx - hw * 1.06, s * 0.5)
      ..quadraticBezierTo(cx - hw * 1.2, s * 0.3, cx - hw * 0.85, s * 0.2)
      ..quadraticBezierTo(cx - hw * 0.3, s * 0.12, cx + hw * 0.35, s * 0.14)
      ..quadraticBezierTo(cx + hw * 1.12, s * 0.17, cx + hw * 1.12, s * 0.38)
      ..quadraticBezierTo(cx + hw * 1.12, s * 0.46, cx + hw * 1.04, s * 0.5)
      ..lineTo(cx + hw * 0.93, s * 0.48)
      ..quadraticBezierTo(cx + hw * 0.95, s * 0.38, cx + hw * 0.82, s * 0.33)
      // الغرّة: تنزل من اليمين وتنسحب لليسار فوق الجبهة بطرف مدبب
      ..quadraticBezierTo(cx + hw * 0.4, s * 0.31, cx - hw * 0.05, s * 0.335)
      ..quadraticBezierTo(cx - hw * 0.45, s * 0.355, cx - hw * 0.72, s * 0.34)
      ..quadraticBezierTo(cx - hw * 0.5, s * 0.315, cx - hw * 0.62, s * 0.3)
      ..quadraticBezierTo(cx - hw * 0.85, s * 0.33, cx - hw * 0.92, s * 0.4)
      ..lineTo(cx - hw * 0.94, s * 0.48)
      ..close();
    final bounds = hair.getBounds();
    canvas.drawPath(
        hair,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2E2420), Color(0xFF0E0A08)])
              .createShader(bounds));
    canvas.save();
    canvas.clipPath(hair);
    // خصل ناعمة: خطوط منحنية طويلة من فوق للغرّة، ولمعة عريضة خفيفة
    final strand = Paint()
      ..color = const Color(0x2EFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, s * 0.004)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final t = i / 13;
      final x0 = cx + hw * (0.9 - t * 1.6);
      canvas.drawPath(
          Path()
            ..moveTo(x0, s * 0.15)
            ..quadraticBezierTo(x0 - hw * 0.15, s * 0.24, x0 - hw * 0.45, s * 0.32),
          strand);
    }
    canvas.drawPath(
        Path()
          ..moveTo(cx - hw * 0.55, s * 0.19)
          ..quadraticBezierTo(cx, s * 0.155, cx + hw * 0.5, s * 0.18),
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..strokeCap = StrokeCap.round);
    canvas.restore();
    canvas.drawPath(hair, line);
  }

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
  bool shouldRepaint(_FacePainter old) => old.look != look || old.mouth != mouth || old.brow != brow || old.eye != eye || old.headTilt != headTilt || old.headNod != headNod;
}
