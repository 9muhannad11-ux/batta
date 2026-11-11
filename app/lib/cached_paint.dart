import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// يرسم CustomPainter مرة وحدة بصورة، وبعدها كل إطار يرسم الصورة بس.
/// للرسومات الثقيلة اللي ما تتغير (الحصير والوجوه): بدونه تنعاد آلاف الأشكال كل إطار طول الأنميشن.
/// لين تجهز الصورة يرسم مباشرة.
class CachedPaint extends StatefulWidget {
  final Object cacheKey; // نفس المفتاح = نفس الرسمة
  final CustomPainter painter;
  final double bleed; // كم يطلع الرسم برا حدوده (نسبة من العرض)
  final double scale; // إذا الودجت مكبّر بـ Transform، عشان تبقى الصورة حادة
  const CachedPaint({super.key, required this.cacheKey, required this.painter, this.bleed = 0, this.scale = 1});

  @override
  State<CachedPaint> createState() => _CachedPaintState();
}

class _CachedPaintState extends State<CachedPaint> {
  static const _maxPixels = 16000000; // حوالي 64MB
  static final _cache = <Object, ui.Image>{};
  static final _pending = <Object>{};

  Object? _shownKey;
  ui.Image? _shown;
  double? _measured; // التكبير الحقيقي على الشاشة (إطار الجوال بالكمبيوتر، تصغير الطاولة، Transform...)

  // نقيس كم الرسمة متكبّرة فعلاً على الشاشة، وإذا يختلف نعيد الصورة بنفس الدقة عشان ما تطلع مبكسلة
  void _measure(double fallback) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final m = box.getTransformTo(null);
    final screen = (Offset(m.entry(0, 0), m.entry(1, 0)).distance) * MediaQuery.devicePixelRatioOf(context);
    // نقرّب لربع، عشان ما تنعاد الصورة مع كل فرق بسيط
    final r = ((screen <= 0 ? fallback : screen) * 4).ceil() / 4;
    if (_measured == null || (r - _measured!).abs() > 0.2) setState(() => _measured = r);
  }

  static void _put(Object key, ui.Image image) {
    _cache[key] = image;
    var pixels = 0;
    for (final i in _cache.values) {
      pixels += i.width * i.height;
    }
    while (pixels > _maxPixels && _cache.length > 1) {
      final oldest = _cache.keys.first;
      final i = _cache.remove(oldest)!;
      pixels -= i.width * i.height;
    }
  }

  Future<void> _render(Object key, Size size, double ratio) async {
    if (!_pending.add(key)) return;
    try {
      final pad = size.width * widget.bleed;
      final painter = widget.painter;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(ratio);
      canvas.translate(pad, pad);
      painter.paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(((size.width + pad * 2) * ratio).ceil(), ((size.height + pad * 2) * ratio).ceil());
      picture.dispose();
      _put(key, image);
      if (mounted) setState(() {});
    } finally {
      _pending.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = MediaQuery.devicePixelRatioOf(context) * widget.scale;
    final ratio = _measured ?? fallback;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(fallback));
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final key = (widget.cacheKey, size, ratio);
      final image = _cache[key] ?? (_shownKey == key ? _shown : null);
      if (image == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _render(key, size, ratio));
        return CustomPaint(painter: widget.painter, size: size);
      }
      _shownKey = key;
      _shown = image;
      return CustomPaint(painter: _ImagePainter(image, size.width * widget.bleed), size: size);
    });
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final double pad;
  const _ImagePainter(this.image, this.pad);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-pad, -pad, size.width + pad * 2, size.height + pad * 2),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image || old.pad != pad;
}
