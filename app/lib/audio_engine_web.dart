import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

class _Playing {
  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  final Completer<void> done;
  _Playing(this.source, this.gain, this.done);
}

/// الأصوات بالمتصفح عبر Web Audio: تشتغل فوراً وفوق بعض، وتتحكم بقوتها حتى على الآيفون،
/// وأول لمسة تفتح الصوت لكل الأصوات (عناصر audio العادية كل وحدة تحتاج لمسة بالجوال).
class AudioEngine {
  static web.AudioContext? _ctx;
  static final _buffers = <String, Future<web.AudioBuffer>>{};
  static final _channels = <String, _Playing>{};
  static final _tokens = <String, int>{}; // آخر طلب لكل قناة: أي طلب أقدم منه يتلغي

  static web.AudioContext get _context {
    final existing = _ctx;
    if (existing != null) return existing;
    // الآيفون: زر الصامت يكتم أصوات الصفحات، إلا إذا الصفحة قالت إنها «تشغيل وسائط» (Safari 17 وفوق)
    try {
      final session = (globalContext['navigator'] as JSObject?)?['audioSession'] as JSObject?;
      session?['type'] = 'playback'.toJS;
    } catch (_) {}
    final ctx = web.AudioContext(web.AudioContextOptions(latencyHint: 'interactive'.toJS));
    _ctx = ctx;
    // الآيفون يوقف الصوت لما تطلع من الصفحة أو تجي مكالمة، فنخلي المستمعين دايماً
    final unlock = ((web.Event _) => _unlock()).toJS;
    for (final type in ['pointerdown', 'pointerup', 'touchend', 'click', 'keydown']) {
      web.window.addEventListener(type, unlock, true.toJS);
    }
    web.document.addEventListener(
        'visibilitychange',
        ((web.Event _) {
          if (web.document.hidden) {
            ctx.suspend();
          } else {
            ctx.resume();
          }
        }).toJS);
    return ctx;
  }

  static void _unlock() {
    final ctx = _context;
    if (ctx.state == 'running') return;
    ctx.resume();
    // صوت فاضي داخل اللمسة نفسها: الآيفون يفتح الصوت بهالطريقة
    final silent = ctx.createBufferSource();
    silent.buffer = ctx.createBuffer(1, 1, 22050);
    silent.connect(ctx.destination);
    silent.start();
  }

  static Future<web.AudioBuffer> _load(String asset) => _buffers.putIfAbsent(asset, () async {
        try {
          final data = await rootBundle.load('assets/$asset');
          final bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
          return await _context.decodeAudioData(bytes.buffer.toJS).toDart;
        } catch (_) {
          _buffers.remove(asset); // نحاول مرة ثانية وقت ما يتطلب
          rethrow;
        }
      });

  static Future<void> preload(List<String> assets) async {
    _context;
    for (final a in assets) {
      await _load(a);
    }
  }

  static Future<void> play(String channel, String asset, {double volume = 1, bool loop = false, double pan = 0, void Function()? onStart}) async {
    final token = (_tokens[channel] ?? 0) + 1;
    _tokens[channel] = token;
    bool stale() => _tokens[channel] != token;
    _halt(channel);
    final ctx = _context;
    final buffer = await _load(asset);
    if (stale()) return;
    if (ctx.state != 'running') {
      if (web.document.hidden) return;
      // بدون لمسة المتصفح ما يفتح الصوت: نتجاوز هالصوت بدل ما تتراكم الأصوات وتشتغل كلها مع أول لمسة
      await ctx.resume().toDart.timeout(const Duration(milliseconds: 200), onTimeout: () => null);
      if (ctx.state != 'running' || stale()) return;
    }
    final gain = ctx.createGain();
    gain.gain.value = volume;
    // الآيفونات القديمة ما فيها StereoPanner: بدونه الصوت يطلع من الوسط بدل ما ينكتم كله
    web.StereoPannerNode? panner;
    try {
      panner = ctx.createStereoPanner();
      panner.pan.value = pan;
      gain.connect(panner);
      panner.connect(ctx.destination);
    } catch (_) {
      panner = null;
      gain.connect(ctx.destination);
    }
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = loop;
    source.connect(gain);
    final done = Completer<void>();
    final playing = _Playing(source, gain, done);
    source.onended = ((web.Event _) {
      if (_channels[channel] == playing) _channels.remove(channel);
      gain.disconnect();
      panner?.disconnect();
      if (!done.isCompleted) done.complete();
    }).toJS;
    _channels[channel] = playing;
    source.start();
    onStart?.call();
    return done.future;
  }

  // يوقف الصوت الشغّال بسرعة بدون طقّة
  static void _halt(String channel) {
    final p = _channels.remove(channel);
    if (p == null) return;
    final now = _context.currentTime;
    p.gain.gain.setTargetAtTime(0, now, 0.008);
    p.source.stop(now + 0.04);
    if (!p.done.isCompleted) p.done.complete();
  }

  static void stop(String channel) {
    _tokens[channel] = (_tokens[channel] ?? 0) + 1;
    _halt(channel);
  }

  static void setVolume(String channel, double volume) {
    _channels[channel]?.gain.gain.setTargetAtTime(volume, _context.currentTime, 0.02);
  }
}
