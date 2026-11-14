import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet.dart';

/// تحدي: عدّاد لازم يوصل لهدف، وجايزته غوازي
class Challenge {
  final String id, title;
  final String stat; // العدّاد اللي يحسب (نفس مفاتيح الإحصائيات)
  final int goal, reward;
  final bool weekly;
  const Challenge(this.id, this.title, this.stat, this.goal, this.reward, {this.weekly = false});
}

/// التحديات تنحسب من المباريات أونلاين بس (لأن جايزتها غوازي)
const dailyChallenges = [
  Challenge('d_play3', 'العب 3 مباريات أونلاين', 'matches', 3, 100),
  Challenge('d_win1', 'فز بمباراة أونلاين', 'wins', 1, 150),
  Challenge('d_buy3', 'اشترِ 3 جولات ووصل فيها', 'boughtMade', 3, 150),
];
const weeklyChallenges = [
  Challenge('w_win10', 'فز بـ 10 مباريات أونلاين', 'wins', 10, 800, weekly: true),
  Challenge('w_bid8', 'وصل مزايدة 8 أو أكثر 3 مرات', 'bigBidMade', 3, 600, weekly: true),
  Challenge('w_bawan', 'جيب باون', 'bawanMade', 1, 1000, weekly: true),
];

/// سطر بصفحة «تاريخك»
class StatLine {
  final String key, title;
  const StatLine(this.key, this.title);
}

const historyStats = [
  StatLine('matches', 'مباريات لعبتها'),
  StatLine('wins', 'فزت'),
  StatLine('losses', 'خسرت'),
  StatLine('rounds', 'جولات لعبتها'),
  StatLine('bought', 'جولات شريتها'),
  StatLine('boughtMade', 'وصلت فيها'),
  StatLine('boughtFailed', 'خسرتها'),
  StatLine('bigBidMade', 'وصلت 8 أو أكثر'),
  StatLine('bawanMade', 'جبت باون'),
  StatLine('bawanFailed', 'خسرت باون'),
  StatLine('bawanBroken', 'قلبت باون'),
  StatLine('points', 'نقاط جابها فريقك'),
  StatLine('jokerPenalty', 'خيّست جوكر'),
  StatLine('ghawaziWon', 'غوازي كسبتها'),
];

/// إحصائيات اللاعب والتحديات: تنحفظ بالجهاز
class Progress extends ChangeNotifier {
  Progress._();
  static final instance = Progress._();

  final Map<String, int> stats = {}; // كل الألعاب (أونلاين وتدريب)
  final Map<String, int> _daily = {}, _weekly = {}; // أونلاين بس
  final Set<String> claimed = {};
  String _day = '', _week = '';
  final Set<String> _seen = {}; // جولات انحسبت (عشان ما تنحسب مرتين)

  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// الأسبوع يبدأ يوم الأحد
  static String weekKey(DateTime d) {
    final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday % 7));
    return dayKey(start);
  }

  int value(String stat) => stats[stat] ?? 0;
  int progress(Challenge c) => ((c.weekly ? _weekly : _daily)[c.stat] ?? 0).clamp(0, c.goal);
  bool done(Challenge c) => progress(c) >= c.goal;
  bool isClaimed(Challenge c) => claimed.contains(c.id);
  bool get anyToClaim => [...dailyChallenges, ...weeklyChallenges].any((c) => done(c) && !isClaimed(c));

  /// كم باقي لين يتجدد (للعرض)
  static Duration untilTomorrow(DateTime now) => DateTime(now.year, now.month, now.day + 1).difference(now);
  static Duration untilNextWeek(DateTime now) => DateTime(now.year, now.month, now.day + 7 - now.weekday % 7).difference(now);

  Future<void> load({DateTime? now}) async {
    final p = await SharedPreferences.getInstance();
    Map<String, int> read(String k) => (jsonDecode(p.getString(k) ?? '{}') as Map).map((k, v) => MapEntry(k as String, v as int));
    stats
      ..clear()
      ..addAll(read('stats'));
    _daily
      ..clear()
      ..addAll(read('daily'));
    _weekly
      ..clear()
      ..addAll(read('weekly'));
    claimed
      ..clear()
      ..addAll(p.getStringList('claimed') ?? const []);
    _day = p.getString('dailyDay') ?? '';
    _week = p.getString('weeklyWeek') ?? '';
    _roll(now ?? DateTime.now());
    await _save(p);
  }

  /// يوم جديد أو أسبوع جديد: التحديات تبدأ من الصفر
  void _roll(DateTime now) {
    final d = dayKey(now), w = weekKey(now);
    if (_day != d) {
      _day = d;
      _daily.clear();
      claimed.removeWhere((id) => id.startsWith('d_'));
    }
    if (_week != w) {
      _week = w;
      _weekly.clear();
      claimed.removeWhere((id) => id.startsWith('w_'));
    }
  }

  Future<void> _save([SharedPreferences? p]) async {
    p ??= await SharedPreferences.getInstance();
    await p.setString('stats', jsonEncode(stats));
    await p.setString('daily', jsonEncode(_daily));
    await p.setString('weekly', jsonEncode(_weekly));
    await p.setStringList('claimed', claimed.toList());
    await p.setString('dailyDay', _day);
    await p.setString('weeklyWeek', _week);
  }

  void _add(String stat, bool online, [int by = 1]) {
    if (by == 0) return;
    stats[stat] = (stats[stat] ?? 0) + by;
    if (online) {
      _daily[stat] = (_daily[stat] ?? 0) + by;
      _weekly[stat] = (_weekly[stat] ?? 0) + by;
    }
  }

  /// من حالة اللعبة: نهاية كل جولة ونهاية المباراة. online = مباراة بحث أونلاين (بغوازي)
  void onState({required String? code, required Map view, required int mySeat, required bool online, DateTime? now}) {
    final phase = view['phase'];
    if (phase != 'roundEnd' && phase != 'matchEnd') return;
    final last = view['lastRound'] as Map?;
    if (last == null) return;
    _roll(now ?? DateTime.now());
    final scores = (view['scores'] as List?)?.join(',') ?? '';
    final key = '$code|${view['round']}|$scores|${last['type']}';
    if (!_seen.add(key)) return;
    final me = mySeat % 2;
    final type = last['type'] as String?;
    final team = last['team'] as int?;
    final buyer = last['buyer'] as int?;
    final bid = last['bid'] as int? ?? 0;
    _add('rounds', online);
    if (team == me) _add('points', online, last['points'] as int? ?? 0);
    if (buyer == mySeat) {
      _add('bought', online);
      if (type == 'made' || type == 'bawanWin') {
        _add('boughtMade', online);
        if (bid >= 8) _add('bigBidMade', online);
      }
      if (type == 'failed' || type == 'bawanFail') _add('boughtFailed', online);
      if (type == 'bawanWin') _add('bawanMade', online);
      if (type == 'bawanFail') _add('bawanFailed', online);
    }
    if (type == 'bawanFail' && last['breaker'] == mySeat) _add('bawanBroken', online);
    if (last['offender'] == mySeat) _add('jokerPenalty', online);
    if (phase == 'matchEnd' && view['winner'] != null) {
      _add('matches', online);
      _add(view['winner'] == me ? 'wins' : 'losses', online);
    }
    notifyListeners();
    _save();
  }

  /// الغوازي اللي رجعت من الفوز (للإحصائيات)
  void addWinnings(int amount) {
    stats['ghawaziWon'] = (stats['ghawaziWon'] ?? 0) + amount;
    _save();
  }

  /// استلام جايزة تحدي خلص
  bool claim(Challenge c) {
    if (!done(c) || isClaimed(c)) return false;
    claimed.add(c.id);
    Wallet.instance.addGhawazi(c.reward);
    notifyListeners();
    _save();
    return true;
  }
}
