import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// أصوات اللعبة. كل صوت له مشغّل خاص عشان تقدر تشتغل مع بعض.
class Sfx {
  static final Map<String, AudioPlayer> _players = {};
  static bool muted = false;

  static Future<void> _play(String name, {double volume = 1}) async {
    if (muted) return;
    try {
      final p = _players.putIfAbsent(name, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$name.wav'));
    } catch (e) {
      // المتصفح أحياناً يمنع الصوت قبل أول ضغطة، نتجاهلها
      debugPrint('sound $name failed: $e');
    }
  }

  static void play() => _play('play');
  static void deal() => _play('deal', volume: 0.8);
  static void collect() => _play('collect');
  static void tick() => _play('tick', volume: 0.6);
  static void win() => _play('win');
  static void lose() => _play('lose');
  static void gold() => _play('gold');
  static void bawan() => _play('bawan');
}
