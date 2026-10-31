import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// أصوات اللعبة. كل صوت له مشغّل خاص عشان تقدر تشتغل مع بعض.
class Sfx {
  static final Map<String, AudioPlayer> _players = {};
  static bool muted = false;

  static Future<void> _play(String name, {double volume = 1, bool loop = false}) async {
    if (muted) return;
    try {
      final p = _players.putIfAbsent(name, () => AudioPlayer());
      await p.stop();
      await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$name.wav'));
    } catch (e) {
      // المتصفح أحياناً يمنع الصوت قبل أول ضغطة، نتجاهلها
      debugPrint('sound $name failed: $e');
    }
  }

  static Future<void> _stop(String name) async {
    try {
      await _players[name]?.stop();
    } catch (_) {}
  }

  static void play() => _play('play');
  static void joker() => _play('joker'); // بدل صوت الورقة لما ينرمى جوكر
  static void signalBig() => _play('signal_big'); // كف الجوكر الكبير
  static void deal() => _play('deal', volume: 0.8);
  static void start() => _play('start'); // بداية المباراة
  static void collect() => _play('collect');
  // تكتكة آخر 5 ثواني (الملف 5 ثواني)، وتوقف أول ما يتحرك اللاعب
  static void tick() => _play('tick');
  static void stopTick() => _stop('tick');
  static void win() => _play('win');
  static void lose() => _play('lose');
  // نبض القلب يتكرر طول ما الطاولة ذهبية
  static void gold() => _play('gold', loop: true);
  static void stopGold() => _stop('gold');
  static void bawan() => _play('bawan');

  /// أصوات الشخصيات الموجودة: `assets/voices/{id}_{رقم}.wav` (الأحداث من 1 لـ 9، شوف VoiceEvent)
  static const voices = <String, Set<int>>{
    'wadamtih': {1, 2, 3, 4, 5, 6, 7, 8, 9},
  };

  static bool hasVoice(String? char, int event) => voices[char]?.contains(event) ?? false;

  /// يشغّل صوت الشخصية، ويخلص لما يخلص الصوت (عشان الفم يوقف معه). كل لاعب له مشغّل.
  static final voiceLog = <String>[]; // آخر الأصوات المطلوبة (للاختبارات)

  static Future<void> voice(int seat, String char, int event) async {
    if (!hasVoice(char, event)) return;
    voiceLog.add('${char}_$event');
    if (muted) return;
    try {
      final p = _players.putIfAbsent('voice$seat', () => AudioPlayer());
      await p.stop();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1);
      final done = p.onPlayerComplete.first;
      await p.play(AssetSource('voices/${char}_$event.wav'));
      await done.timeout(const Duration(seconds: 4), onTimeout: () {});
    } catch (e) {
      debugPrint('voice $char $event failed: $e');
    }
  }
}

/// أحداث أصوات الشخصيات (نفس ترقيم pending-changes.md)
class VoiceEvent {
  static const bid6 = 1, bid7 = 2, bid8 = 3, gold = 4, made = 5, oppFailed = 6, pass = 7, majbur = 8, blueOverGrey = 9;
}
