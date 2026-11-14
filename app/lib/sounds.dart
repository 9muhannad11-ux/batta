import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_engine.dart';

/// يضيف صوت الضغطة لأي زر قائمة (والمعطّل يبقى معطّل)
VoidCallback? withTap(VoidCallback? action) => action == null
    ? null
    : () {
        Sfx.tap();
        action();
      };

/// أصوات اللعبة. كل صوت له قناة خاصة عشان تقدر تشتغل مع بعض.
/// وقت ما تتكلم شخصية، باقي الأصوات تنخفض (ducking) عشان الكلام يكون أوضح، وترجع بعده.
class Sfx {
  static final Map<String, double> _volumes = {}; // القوة الأصلية لكل صوت (قبل الخفض)
  static final Map<int, Object> _speaking = {}; // اللاعبين اللي صوت شخصيتهم شغّال
  static const duck = 0.35; // قوة باقي الأصوات وقت الكلام
  static bool muted = false; // للاختبارات

  // إعدادات اللاعب
  static bool sfxOn = true, voiceOn = true;
  static double sfxVolume = 1, voiceVolume = 1;

  static double get _sfx => sfxOn ? sfxVolume : 0;

  static Future<void> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    sfxOn = p.getBool('sfxOn') ?? true;
    voiceOn = p.getBool('voiceOn') ?? true;
    sfxVolume = p.getDouble('sfxVolume') ?? 1;
    voiceVolume = p.getDouble('voiceVolume') ?? 1;
  }

  /// يطبّق الإعدادات على الأصوات الشغّالة ويحفظها
  static Future<void> saveSettings() async {
    _applyDuck();
    final p = await SharedPreferences.getInstance();
    await p.setBool('sfxOn', sfxOn);
    await p.setBool('voiceOn', voiceOn);
    await p.setDouble('sfxVolume', sfxVolume);
    await p.setDouble('voiceVolume', voiceVolume);
  }

  static const _names = ['play', 'joker', 'joker_big', 'signal_big', 'deal', 'collect', 'tick', 'win', 'lose', 'gold', 'bawan', 'tap', 'lift', 'coins', 'trump_ace'];

  static double get _duckFactor => _speaking.isEmpty ? 1 : duck;
  // دقات قلب الباون ما تنخفض مع كلام الشخصيات (لازم تبقى عالية)
  static double _duckOf(String asset) => asset == 'sounds/gold.wav' ? 1 : _duckFactor;

  static void _applyDuck() {
    for (final e in _volumes.entries) {
      AudioEngine.setVolume(e.key, e.value * _sfx * _duckOf(e.key));
    }
  }

  /// يجهّز كل الأصوات قبل اللعب، عشان تشتغل على طول بدون تأخير
  static Future<void> preload() async {
    if (muted) return;
    try {
      await AudioEngine.preload([for (final n in _names) 'sounds/$n.wav']);
    } catch (e) {
      debugPrint('sound preload failed: $e');
    }
  }

  static Future<void> preloadIntro() async {
    if (muted) return;
    try {
      await AudioEngine.preload(['sounds/logo_intro.wav']);
    } catch (e) {
      debugPrint('intro sound failed: $e');
    }
  }

  static Future<void> _play(String name, {double volume = 1, bool loop = false}) async {
    if (muted || (_sfx == 0 && !loop)) return; // الصوت المتكرر يشتغل بدون علو، عشان يرجع لما تفتح الصوت
    final asset = 'sounds/$name.wav';
    _volumes[asset] = volume;
    try {
      await AudioEngine.play(asset, asset, volume: volume * _sfx * _duckOf(asset), loop: loop);
    } catch (e) {
      // المتصفح أحياناً يمنع الصوت قبل أول ضغطة، نتجاهلها
      debugPrint('sound $name failed: $e');
    }
  }

  static void _stop(String name) {
    final asset = 'sounds/$name.wav';
    _volumes.remove(asset);
    try {
      AudioEngine.stop(asset);
    } catch (_) {}
  }

  static void intro() => _play('logo_intro'); // أنميشن الشعار عند فتح اللعبة
  static void tap() => _play('tap', volume: 0.6); // أي ضغطة على القوائم
  static void coins() => _play('coins', volume: 0.7); // غوازي تطير (هدية اليوم، دخول جيم)
  static void play() => _play('play');
  static void joker() => _play('joker'); // بدل صوت الورقة لما ينرمى الجوكر الصغير
  static void jokerBig() => _play('joker_big', volume: 0.55); // الجوكر الكبير (أوطى من الصغير)
  static void trumpAce() => _play('trump_ace', volume: 0.8); // خال الحكم (آص الحكم) لما ينزل
  static void signalBig() => _play('signal_big'); // كف الجوكر الكبير
  // صوت واحد طول طلعات الورق (tools/sound-candidates/make-deal.js)
  static void deal() => _play('deal', volume: 0.4);
  static void collect() => _play('collect');
  // نقرة خشب خفيفة لما الورقة الفايزة باللمّة ترتفع (tools/sound-candidates/make-lift2.js، lift_d)
  static void lift() => _play('lift', volume: 0.7);
  // تكتكة آخر 5 ثواني (الملف 5 ثواني)، وتوقف أول ما يتحرك اللاعب
  static void tick() => _play('tick');
  static void stopTick() => _stop('tick');
  // الفوز والخسارة أوطى عشان أصوات الشخصيات تطغى عليهم (نص القوة، -6 dB)
  static void win() => _play('win', volume: 0.5);
  static void lose() => _play('lose', volume: 0.5);
  // نبض القلب يتكرر طول ما الطاولة ذهبية
  static void gold() => _play('gold', loop: true);
  static void stopGold() => _stop('gold');
  static void bawan() => _play('bawan');

  /// أصوات الشخصيات الموجودة: `assets/voices/{id}_{رقم}.wav` (الأحداث من 1 لـ 13، شوف VoiceEvent)
  static final voices = <String, Set<int>>{ // final (مو const) عشان الاختبارات تقدر تضيف
    'wadamtih': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'aslam': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'fares': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'sulaiman': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'musabbah': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'medhat': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'khusaib': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13},
    'bodhirs': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}, // بو شنب
  };

  static bool hasVoice(String? char, int event) => voices[char]?.contains(event) ?? false;

  /// يشغّل صوت الشخصية، ويخلص لما يخلص الصوت (عشان الفم يوقف معه). كل لاعب له مشغّل.
  static final voiceLog = <String>[]; // آخر الأصوات المطلوبة (للاختبارات)

  /// قوة كل أصوات الشخصيات قبل إعداد اللاعب، أوطى 30٪ من باقي الأصوات
  static const voiceLevel = 0.7;

  /// pan: مكان الشخصية من -1 يسار لـ 1 يمين، عشان الصوت يطلع من ناحيتها
  static Future<void> voice(int seat, String char, int event, {double pan = 0, void Function()? onStart}) async {
    if (!hasVoice(char, event)) return;
    voiceLog.add('${char}_$event');
    if (muted || !voiceOn || voiceVolume == 0) return;
    final me = Object();
    try {
      await AudioEngine.play('voice$seat', 'voices/${char}_$event.wav', volume: voiceVolume * voiceLevel, pan: pan, onStart: () {
        _speaking[seat] = me;
        _applyDuck();
        onStart?.call(); // الفم يبدأ مع الصوت بالضبط
      }).timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (e) {
      debugPrint('voice $char $event failed: $e');
    } finally {
      // نرجّع باقي الأصوات (إلا إذا نفس اللاعب بدأ صوت ثاني بعده)
      if (_speaking[seat] == me) {
        _speaking.remove(seat);
        _applyDuck();
      }
    }
  }
}

/// أحداث أصوات الشخصيات (نفس ترقيم pending-changes.md)
class VoiceEvent {
  static const bid6 = 1, bid7 = 2, bid8 = 3, gold = 4, made = 5, oppFailed = 6, pass = 7, majbur = 8, blueOverGrey = 9;
  // الشاري يختار الحكم
  static const trumpS = 10, trumpD = 11, trumpC = 12, trumpH = 13;
}
