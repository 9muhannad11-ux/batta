import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// الأصوات على الجوال: كل قناة لها مشغّل، والملف يتحمّل مرة وحدة عشان يشتغل على طول.
class AudioEngine {
  // بدون audio focus: وإلا كل صوت جديد يوقف اللي قبله بأندرويد
  static final _context = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
  static final _players = <String, AudioPlayer>{};
  static final _sources = <String, String>{}; // القناة → الملف المحمّل فيها
  static final _tokens = <String, int>{}; // آخر طلب لكل قناة: أي طلب أقدم منه يتلغي
  static final _done = <String, Completer<void>>{};

  static Future<AudioPlayer> _player(String channel) async {
    final existing = _players[channel];
    if (existing != null) return existing;
    final p = AudioPlayer();
    _players[channel] = p;
    await p.setAudioContext(_context);
    p.onPlayerComplete.listen((_) => _finish(channel));
    return p;
  }

  static void _finish(String channel) {
    final d = _done.remove(channel);
    if (d != null && !d.isCompleted) d.complete();
  }

  /// يجهّز الأصوات القصيرة: اسم القناة نفسه اسم الملف
  static Future<void> preload(List<String> assets) async {
    await AudioCache.instance.loadAll(assets);
    for (final a in assets) {
      final p = await _player(a);
      if (_sources[a] == a) continue;
      await p.setSource(AssetSource(a));
      _sources[a] = a;
    }
  }

  static Future<void> play(String channel, String asset, {double volume = 1, bool loop = false, void Function()? onStart}) async {
    final token = (_tokens[channel] ?? 0) + 1;
    _tokens[channel] = token;
    bool stale() => _tokens[channel] != token;
    _finish(channel);
    final p = await _player(channel);
    await p.stop();
    if (stale()) return;
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await p.setVolume(volume);
    if (_sources[channel] != asset) {
      await p.setSource(AssetSource(asset));
      _sources[channel] = asset;
    }
    if (stale()) return;
    final done = Completer<void>();
    _done[channel] = done;
    await p.resume();
    onStart?.call();
    return done.future;
  }

  static void stop(String channel) {
    _tokens[channel] = (_tokens[channel] ?? 0) + 1;
    _finish(channel);
    _players[channel]?.stop().catchError((_) {});
  }

  static void setVolume(String channel, double volume) {
    _players[channel]?.setVolume(volume).catchError((_) {});
  }
}
