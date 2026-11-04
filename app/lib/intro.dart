import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'main.dart' show appFont;
import 'sounds.dart';

/// أنميشن الشعار عند فتح اللعبة: الأوراق تنزل كومة، تنفتح مروحة والجوكر آخرها، «بتّه» تطلع تحتها،
/// ولمعة على الجوكر. نفس توقيت tools/logo-art/logo.html?anim. لمسة تتخطاه.
class LogoIntro extends StatefulWidget {
  final VoidCallback onDone;
  const LogoIntro({super.key, required this.onDone});

  @override
  State<LogoIntro> createState() => _LogoIntroState();
}

class _LogoIntroState extends State<LogoIntro> with TickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(milliseconds: 2700));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  List<ui.Image>? _cards;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _time.addStatusListener((s) {
      if (s == AnimationStatus.completed) _leave();
    });
    _start();
  }

  Future<void> _start() async {
    final images = await Future.wait(['H', 'C', 'D', 'S', 'J'].map(_load));
    await Sfx.preloadIntro().timeout(const Duration(milliseconds: 800), onTimeout: () {});
    if (!mounted) return;
    setState(() => _cards = images);
    _time.forward();
    Sfx.intro();
  }

  Future<ui.Image> _load(String id) {
    final done = Completer<ui.Image>();
    final stream = AssetImage('assets/images/intro_$id.png').resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((info, _) {
      if (!done.isCompleted) done.complete(info.image);
    }));
    return done.future;
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _fade.reverse().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _time.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _leave,
      child: FadeTransition(
        opacity: _fade,
        child: SizedBox.expand(child: CustomPaint(painter: _IntroPainter(_time, cards))),
      ),
    );
  }
}

class _IntroPainter extends CustomPainter {
  final Animation<double> time;
  final List<ui.Image>? cards;
  _IntroPainter(this.time, this.cards) : super(repaint: time);

  // إحداثيات رسمة الشعار (tools/logo-art/logo.html)
  static const _rots = [-36.0, -18.0, 0.0, 18.0, 36.0];
  static const _pivot = Offset(512, 640);
  static const _card = Rect.fromLTWH(394, 260, 236, 350);

  static double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  static double _out(double p) => 1 - pow(1 - p, 3).toDouble();
  static double _back(double p) {
    const c = 1.9;
    return 1 + (c + 1) * pow(p - 1, 3) + c * pow(p - 1, 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawRect(
        all,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.18, 0.5, 0.52, 0.8, 1],
            colors: [Color(0xFFF2F3F5), Color(0xFFC9CCD1), Color(0xFF8E939A), Color(0xFF7B8087), Color(0xFFA9ADB3), Color(0xFFD9DBDF)],
          ).createShader(all));
    final images = cards;
    if (images == null) return;
    final t = time.value * 2.7;
    final s = min(size.width, size.height);
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 1024);

    // المروحة
    final drop = _out(_span(t, 0.1, 0.5));
    final alpha = _span(t, 0.1, 0.3);
    final scale = 1.1 * (1.35 - 0.35 * drop);
    canvas.save();
    canvas.translate(512, 440 - 90 * (1 - drop));
    canvas.scale(scale);
    canvas.translate(-512, -560);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..filterQuality = FilterQuality.medium;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final rrect = RRect.fromRectAndRadius(_card, const Radius.circular(24));
    for (var i = 0; i < images.length; i++) {
      final open = _back(_span(t, 0.55 + i * 0.09, 1.05 + i * 0.09));
      canvas.save();
      canvas.translate(_pivot.dx, _pivot.dy);
      canvas.rotate(_rots[i] * open * pi / 180);
      canvas.translate(-_pivot.dx, -_pivot.dy);
      canvas.drawRRect(rrect.shift(const Offset(0, 12)), shadow);
      final image = images[i];
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), _card.inflate(6), paint);
      if (i == images.length - 1) {
        // اللمعة على الجوكر
        final p = _span(t, 1.65, 2.2);
        if (p > 0 && p < 1) {
          final band = Rect.fromLTWH(_card.left - 130 + (_card.width + 260) * p, _card.top - 80, 110, _card.height + 160);
          canvas.save();
          canvas.clipRRect(rrect);
          canvas.drawRect(
              band,
              Paint()
                ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xE6FFFFFF), Color(0x00FFFFFF)]).createShader(band));
          canvas.restore();
        }
      }
      canvas.restore();
    }
    canvas.restore();

    // «بتّه»
    final w = _back(_span(t, 1.35, 1.85));
    final wordAlpha = _span(t, 1.35, 1.6);
    if (wordAlpha > 0) {
      final word = TextPainter(
        text: TextSpan(
          text: 'بتّه',
          style: TextStyle(
            fontFamily: appFont,
            fontWeight: FontWeight.w700,
            fontSize: 240,
            height: 1.2,
            color: const Color(0xFF1D1F22).withValues(alpha: wordAlpha),
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35 * wordAlpha), blurRadius: 12, offset: const Offset(0, 6))],
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final baseline = word.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      canvas.save();
      canvas.translate(512, 760);
      canvas.scale(0.7 + 0.3 * w);
      canvas.translate(-512, -760 + 40 * (1 - w));
      word.paint(canvas, Offset(512 - word.width / 2, 845 - baseline));
      canvas.restore();
      word.dispose();
    }
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.cards != cards;
}
