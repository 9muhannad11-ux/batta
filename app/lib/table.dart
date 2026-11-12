import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'fullscreen.dart';
import 'main.dart' show showErrors;
import 'menus.dart';
import 'net.dart';
import 'sounds.dart';

const _turnSeconds = 12.5;
const _trumpSeconds = 10.0;

/// أماكن اللاعبين بالطولي: يمين/يسار = حافة الشاشة، وفوق/تحت نسبة من نص طول الطاولة. أنا أول واحد.
/// اللعب عكس عقارب الساعة: اللي على يميني يلعب بعدي.
const _align6 = [Offset(0, 1), Offset(1, 0.36), Offset(1, -0.6), Offset(0, -1), Offset(-1, -0.6), Offset(-1, 0.36)];
const _align4 = [Offset(0, 1), Offset(1, -0.1), Offset(0, -1), Offset(-1, -0.1)];
// ميلان خفيف لكل ورقة منزولة
const _tilt6 = [3.0, -7.0, -5.0, -6.0, 7.0, 5.0];
const _tilt4 = [3.0, -6.0, -6.0, 6.0];

/// مقاسات الطاولة لهالشاشة: أماكن اللاعبين (قريبة من حواف الشاشة ومو مربوطة بالطاولة)، الطاولة، ومقاس الأوراق.
class _Board {
  final Size size;
  final bool landscape;
  final double handTop, handW, cardW, avatar;
  final double handLeft, handRight; // المساحة اللي تنفرد فيها اليد
  final Offset center;
  final Rect table;
  final List<Offset> seats; // حسب الترتيب بالنسبة لي (0 = أنا)
  final List<double> tilts;

  _Board._(this.size, this.landscape, this.handTop, this.handW, this.cardW, this.avatar, this.handLeft, this.handRight, this.table,
      this.seats, this.tilts)
      : center = table.center;

  factory _Board(Size size, int players) {
    final w = size.width, h = size.height;
    final landscape = w > h;
    final tilts = players == 4 ? _tilt4 : _tilt6;
    if (landscape) {
      // مثل الصورة النموذج: أنا تحت يسار، اثنين يمين واثنين يسار على حافة الشاشة، وواحد فوق بالنص
      final avatar = min(64.0, h * 0.17);
      final edge = avatar / 2 + 16;
      final handW = min(80.0, h * 0.21);
      final handTop = h - handW * cardRatio * 0.66; // الأوراق تطلع من تحت الشاشة (يبين ثلثينها)
      final topY = avatar * 0.78 - 6; // اللي فوق أعلى ما يمكن: راسه يوصل لحافة الشاشة
      // الطاولة بنص الشاشة بالضبط (نفس المسافة فوق وتحت ويمين ويسار)
      final ty = topY + avatar * 0.45;
      final table = Rect.fromLTRB(edge + avatar * 1.25, ty, w - edge - avatar * 1.25, h - ty);
      // شخصيتي تحت يسار: أوطى ما يمكن (اسمي بس تحتها)، وأبعد يمين ما يمكن قبل ما تلمس إطار الطاولة
      final myY = h - (avatar + 10) / 2 - 20;
      var myX = edge;
      // الإطار، والراس اللي يطلع فوقه (غطا الراس)
      bool fits(double x) =>
          _clearOfTable(Offset(x, myY), (avatar + 10) / 2 + 6, table) && _clearOfTable(Offset(x, myY - avatar * 0.62), avatar * 0.36 + 6, table);
      while (myX < w / 2 && fits(myX + 1)) {
        myX += 1;
      }
      final me = Offset(myX, myY);
      // الخصم على الجنبين أوطى شوي (بالـ6 اللي تحت يمين ويسار، وبالـ4 اللي يمين ويسار)
      final seats = players == 4
          ? [me, Offset(w - edge, h * 0.48), Offset(w / 2, topY), Offset(edge, h * 0.48)]
          : [me, Offset(w - edge, h * 0.62), Offset(w - edge, h * 0.24), Offset(w / 2, topY), Offset(edge, h * 0.24), Offset(edge, h * 0.62)];
      return _Board._(size, true, handTop, handW, min(64.0, h * 0.16), avatar, edge + avatar * 1.4, w - 225, table, seats, tilts);
    }
    final s = (w / 380).clamp(0.85, 1.3);
    final avatar = (60 * s).clamp(50.0, 74.0);
    final edge = avatar / 2 + 14;
    final handW = min(88.0, w / 4.6);
    final handTop = h - (handW * cardRatio + 40);
    final top = 138.0, myY = handTop - 104;
    final cy = (top + myY) / 2, ry = (myY - top) / 2;
    final seats = [
      for (final a in players == 4 ? _align4 : _align6)
        Offset(a.dx == 0 ? w / 2 : (a.dx > 0 ? w - edge : edge), cy + a.dy * ry),
    ];
    // الطاولة بين اللاعبين: ما تلمس شخصيات الجنب، وفوق وتحت تحت شخصية اللي فوق وفوقي
    final table = Rect.fromLTRB(avatar + 14, top + avatar * 0.55, w - avatar - 14, myY - avatar * 0.55);
    return _Board._(size, false, handTop, handW, (66 * s).clamp(44.0, 78.0), avatar, 34, w - 34, table, seats, tilts);
  }

  /// مكان الورقة المنزولة: بالطولي بنص المسافة بين وسط الطاولة وصاحبها.
  /// بالعرضي أماكن ثابتة حول الوسط (بمقاس الورقة) عشان ما تتداخل: ورقتي تحت بالنص،
  /// اللي فوق فوق بالنص، والجنبين فوق وتحت بمسافة ورقة كاملة بينهم
  Offset slot(int rel) {
    if (!landscape) return center + (seats[rel] - center) * 0.5;
    final x = cardW * 1.6, y = cardH;
    final spots = seats.length == 4
        ? [Offset(0, y * 0.62), Offset(x, 0), Offset(0, -y * 0.62), Offset(-x, 0)]
        : [Offset(0, y * 0.62), Offset(x, y * 0.44), Offset(x, -y * 0.62), Offset(0, -y * 0.55), Offset(-x, -y * 0.62), Offset(-x, y * 0.44)];
    return center + spots[rel];
  }
  double get cardH => cardW * cardRatio;

  /// دائرة (مركز ونص قطر) ما تلمس الطاولة: الطاولة شكلها كبسولة (طرفينها نص دائرة)
  static bool _clearOfTable(Offset c, double r, Rect t) {
    final rr = t.height / 2;
    final x = c.dx.clamp(t.left + rr, t.right - rr);
    return (c - Offset(x, t.center.dy)).distance >= rr + r;
  }

  /// اتجاه الطاولة من اللاعب (طوله 1)
  Offset toward(int rel) {
    final d = center - seats[rel];
    return d / d.distance;
  }
}

class TableScreen extends StatefulWidget {
  final GameClient client;
  const TableScreen({super.key, required this.client});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with TickerProviderStateMixin {
  // لمّ اللمّة: آخر ورقة توصل، والفايزة تجمعهم وتبقى ظاهرة، وبعدها الكل ينسحب لصاحبها.
  // آخر لمّة بالجولة بنفس المدة، ونتيجة الجولة تطلع بعدها
  static const _collectMs = 2200;
  late final AnimationController _collect = AnimationController(vsync: this, duration: const Duration(milliseconds: _collectMs));
  bool _resultWaiting = false; // نتيجة الجولة تنتظر لين تخلص آخر لمّة
  late final AnimationController _deal = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600), value: 1);
  // كف الجوكر الكبير: ينزل 170ms ويضرب، وبعدها يرتفع ويختفي
  late final AnimationController _slap = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  Map<String, dynamic>? _collecting;
  _Board? _board; // آخر مقاسات الطاولة: منها مكان كل شخصية للصوت
  bool _collectSound = false, _liftSound = false;
  int? _slapRel;

  int _seenRound = 0;
  String? _lastPhase; // عشان نعرف إن مباراة جديدة بدأت بعد matchEnd
  int _trumpSaidRound = 0; // الجولة اللي انقال فيها صوت اختيار الحكم
  int _seenTrickNo = 0;
  int _seenTrickLen = 0;
  int _seenBids = 0;
  final Map<int, String> _talking = {}; // اللاعب → الصوت الشغّال له (فمه يتحرك معه)
  bool _goldOn = false;
  int _resultShownRound = 0;
  String? _effect; // win, lose, bawan
  Timer? _effectTimer;
  Timer? _ticker;
  final _seconds = ValueNotifier<int?>(null); // الثواني الباقية: يتغير مكان الرقم بس، مو الشاشة كلها
  DateTime? _tickedFor; // آخر عداد اشتغل له صوت آخر 5 ثواني
  bool _tickPlaying = false;

  // اليد: اختيار بلمسة، رمي بلمسة ثانية أو بالسحب
  String? _selected;
  String? _dragCard;
  Offset _dragPos = Offset.zero;
  bool _dragOver = false;
  String? _shakeCard;
  int _shakeId = 0;
  final Map<String, Offset> _releasedAt = {}; // الورقة اللي انسحبت ترمى من مكان ما تركها اللاعب
  final _boardKey = GlobalKey();

  GameClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _collect.addListener(() {
      // صوت الارتفاع لما الفايزة ترتفع (600)، وصوت اللمّ لما يجي الباقي عندها (940)
      final ms = _collect.value * _collect.duration!.inMilliseconds;
      if (!_liftSound && ms > 600) {
        _liftSound = true;
        Sfx.lift();
      }
      if (!_collectSound && ms > 940) {
        _collectSound = true;
        Sfx.collect();
      }
    });
    _collect.addStatusListener((s) {
      if (s != AnimationStatus.completed || !mounted) return;
      setState(() => _collecting = null);
      final v = c.view;
      if (_resultWaiting && v != null) {
        _resultWaiting = false;
        _showResult(v);
      }
    });
    // نافذة المزايدة تطلع أول ما يخلص التوزيع
    _deal.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    _slap.addListener(() {
      if (_slap.value >= 170 / 820 && !_shake.isAnimating && _shake.value == 0) _shake.forward(from: 0);
    });
    _slap.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _shake.value = 0;
        setState(() => _slapRel = null);
      }
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChange());
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _collect.dispose();
    _deal.dispose();
    _slap.dispose();
    _shake.dispose();
    _effectTimer?.cancel();
    _rippleTimer?.cancel();
    _ripple.dispose();
    _ticker?.cancel();
    _seconds.dispose();
    Sfx.stopGold();
    Sfx.stopTick();
    super.dispose();
  }

  bool get _myTurn {
    final v = c.view;
    if (v == null) return false;
    final phase = v['phase'];
    return ((phase == 'bidding' || phase == 'playing') && v['turn'] == c.mySeat) || (phase == 'trump' && v['buyer'] == c.mySeat);
  }

  // صوت العداد بآخر 5 ثواني بس، للي عليه الدور، ويوقف أول ما يتحرك
  void _tick() {
    if (!mounted) return;
    final left = c.secondsLeft;
    final deadline = c.deadline;
    _seconds.value = left?.ceil();
    if (_myTurn && left != null && left > 0 && left <= 5 && _tickedFor != deadline) {
      _tickedFor = deadline;
      _tickPlaying = true;
      Sfx.tick();
    } else if (_tickPlaying && (!_myTurn || deadline != _tickedFor)) {
      _tickPlaying = false;
      Sfx.stopTick();
    }
  }

  void _onChange() {
    final v = c.view;
    if (v == null || !mounted) return;
    _seconds.value = c.secondsLeft?.ceil();
    final round = v['round'] as int;
    final trickNo = v['trickNo'] as int;
    final trick = (v['trick'] as List).cast<Map<String, dynamic>>();
    final trickLen = trick.length;
    final n = v['players'] as int;

    // مباراة جديدة بعد نهاية المباراة: أرقام الجولات ترجع من 1، فنصفّر اللي شفناه
    // (وإلا لو خلصت المباراتين بنفس رقم الجولة ما تطلع أصوات النتيجة ولا المزايدة ولا التوزيع)
    final phase0 = v['phase'] as String?;
    if (_lastPhase == 'matchEnd' && phase0 != 'matchEnd') {
      _seenRound = 0;
      _resultShownRound = 0;
      _trumpSaidRound = 0;
    }
    _lastPhase = phase0;

    if (round != _seenRound) {
      final freshDeal = v['phase'] == 'bidding' && (v['bids'] as List).isEmpty;
      _seenRound = round;
      // لو رجعنا للعبة بنص الجولة، ما نعيد أنميشن التوزيع ولا أصوات اللي فات
      _seenTrickNo = freshDeal ? 0 : trickNo;
      _seenTrickLen = freshDeal ? 0 : trickLen;
      _seenBids = freshDeal ? 0 : (v['bids'] as List).length;
      _trumpSaidRound = v['trump'] != null ? round : 0;
      _resultShownRound = v['phase'] == 'roundEnd' || v['phase'] == 'matchEnd' ? round : _resultShownRound;
      _selected = null;
      _dragCard = null;
      _collecting = null;
      _releasedAt.clear();
      c.slapPending.clear();
      if (freshDeal) {
        _deal.forward(from: 0);
        Sfx.deal();
      }
    }

    // صوت الشخصية مع كل مزايدة: 6/7/8، طاف، 6 مجبور
    final bids = (v['bids'] as List).cast<Map<String, dynamic>>();
    for (var i = _seenBids; i < bids.length; i++) {
      final e = switch (bids[i]['bid']) { 6 => VoiceEvent.bid6, 7 => VoiceEvent.bid7, 8 => VoiceEvent.bid8, 'pass' => VoiceEvent.pass, 'majbur' => VoiceEvent.majbur, _ => null };
      if (e != null) _say(bids[i]['seat'] as int, e);
    }
    _seenBids = bids.length;

    // صوت الشاري لما يختار الحكم (مرة وحدة بالجولة)
    final trumpSuit = v['trump'] as String?;
    if (trumpSuit != null && _trumpSaidRound != round && v['buyer'] is int) {
      _trumpSaidRound = round;
      final e = switch (trumpSuit) { 'S' => VoiceEvent.trumpS, 'D' => VoiceEvent.trumpD, 'C' => VoiceEvent.trumpC, 'H' => VoiceEvent.trumpH, _ => null };
      if (e != null) _say(v['buyer'] as int, e);
    }

    // صوت الورقة اللي نزلت: جوكر، أو كف الجوكر الكبير، أو ورقة عادية.
    // before: أوراق اللمّة اللي نزلت قبلها (عشان نعرف إذا الكبير نزل فوق الصغير)
    void landed(Map<String, dynamic> t, List<Map<String, dynamic>> before) {
      final seat = t['seat'] as int;
      if (t['card'] == 'JB' && before.any((x) => x['card'] == 'JG')) _say(seat, VoiceEvent.blueOverGrey);
      // الجوكرين وآص الحكم: موجة برتقالية مثل قطرة ماي تطلع من مكان الورقة لما توصل الطاولة
      final trump = v['trump'];
      if (t['card'] == 'JB' || t['card'] == 'JG' || (trump is String && t['card'] == '$trump-14')) _dropRipple(_rel(seat, n));
      if (c.slapPending.remove(seat)) {
        _slapRel = _rel(seat, n);
        _slap.forward(from: 0);
        _shake.value = 0;
        // قمة الضربة بالصوت (90ms) توافق لحظة لمس الكف (170ms)
        Future.delayed(const Duration(milliseconds: 80), Sfx.signalBig);
      } else if (t['card'] == 'JB') {
        Sfx.jokerBig();
      } else if (t['card'] == 'JG') {
        Sfx.joker();
      } else {
        Sfx.play();
      }
    }

    if (trickNo > _seenTrickNo && v['lastTrick'] != null) {
      _seenTrickNo = trickNo;
      _collecting = v['lastTrick'] as Map<String, dynamic>;
      _collectSound = false;
      _liftSound = false;
      final done = (_collecting!['cards'] as List).cast<Map<String, dynamic>>();
      landed(done.last, done.sublist(0, done.length - 1));
      _collect.forward(from: 0);
    } else if (trickLen > _seenTrickLen) {
      landed(trick.last, trick.sublist(0, trickLen - 1));
    }
    _seenTrickLen = trickLen;

    // باون أو 9: الطاولة ذهبية ونبض قلب يتكرر لين تخلص الجولة
    final phase = v['phase'];
    final gold = _bawanActive(v) && phase != 'roundEnd' && phase != 'matchEnd';
    if (gold != _goldOn) {
      _goldOn = gold;
      gold ? Sfx.gold() : Sfx.stopGold();
      if (gold && v['buyer'] is int) _say(v['buyer'] as int, VoiceEvent.gold);
    }

    // نتيجة الجولة: أخضر إذا جابها الشاري، أحمر إذا ما جابها، وذهبي للباون
    if ((phase == 'roundEnd' || phase == 'matchEnd') && v['lastRound'] != null && round != _resultShownRound) {
      _resultShownRound = round;
      // إذا الجولة خلصت بلمّة، النتيجة تطلع بعد ما تخلص (الورقة الفايزة تبقى ظاهرة)
      if (_collecting != null) {
        _resultWaiting = true;
      } else {
        _showResult(v);
      }
    }

    final legal = (v['legalCards'] as List).cast<String>();
    if (_selected != null && !legal.contains(_selected)) _selected = null;
    setState(() {});
  }

  /// نتيجة الجولة: أصوات الشخصيات، وأخضر إذا جابها الشاري، أحمر إذا ما جابها، وذهبي للباون
  void _showResult(Map<String, dynamic> v) {
    final n = v['players'] as int;
    final last = v['lastRound'] as Map;
    final type = last['type'];
    final breaker = (v['lastTrick'] as Map?)?['winner'];
    final buyer = last['buyer'] as int;
    final matchWinner = v['winner'] as int?; // الفريق اللي فاز بالمباراة (إذا خلصت)
    void team(int t, int event) {
      for (var seat = 0; seat < n; seat++) {
        if (seat % 2 == t) _say(seat, event);
      }
    }
    if (type == 'bawanWin' || type == 'bawanFail') {
      // فوز بالباون أو انقلاب الباون: كل شخصيات الفريق الفايز صوت 6
      team(last['team'] as int, VoiceEvent.oppFailed);
    } else if (matchWinner != null) {
      // فوز بالمباراة: كل شخصيات الفريق الفايز صوت 5
      team(matchWinner, VoiceEvent.made);
    } else if (type == 'made') {
      _say(buyer, VoiceEvent.made);
    } else if (type == 'failed' && breaker is int) {
      _say(breaker, VoiceEvent.oppFailed);
    }
    final effect = switch (type) { 'made' => 'win', 'bawanWin' => 'bawan', 'bawanFail' => 'bawanFail', _ => 'lose' };
    switch (effect) {
      case 'win': Sfx.win();
      case 'bawan': Sfx.bawan();
      default: Sfx.lose();
    }
    _effectTimer?.cancel();
    setState(() => _effect = effect);
    _effectTimer = Timer(Duration(milliseconds: effect == 'bawan' ? 3500 : 2200), () {
      if (mounted) setState(() => _effect = null);
    });
  }

  /// صوت شخصية اللاعب لحدث (إذا لها صوت)، وفمها يتحرك لين يخلص
  void _say(int seat, int event) {
    final char = c.seatInfo(seat)?['char'] as String?;
    if (!Sfx.hasVoice(char, event)) return;
    final clip = '${char}_$event';
    Sfx.voice(seat, char!, event, pan: _panOf(seat), onStart: () {
      if (mounted) setState(() => _talking[seat] = clip);
    }).whenComplete(() {
      if (mounted && _talking[seat] == clip) setState(() => _talking.remove(seat));
    });
  }

  /// مكان الشخصية على الشاشة من -1 يسار لـ 1 يمين، وأطرافها 0.8 عشان الصوت ما يختفي من الأذن الثانية
  double _panOf(int seat) {
    final b = _board;
    if (b == null) return 0;
    final x = b.seats[_rel(seat, b.seats.length)].dx;
    return ((x / b.size.width) * 2 - 1).clamp(-1.0, 1.0) * 0.8;
  }

  // موجة قطرة الماي: تبدأ من مكان الورقة (rel) أول ما توصل الطاولة (طيرانها 220ms)
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  int? _rippleRel;
  Timer? _rippleTimer;
  void _dropRipple(int rel) {
    _rippleTimer?.cancel();
    _rippleTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _rippleRel = rel;
      _ripple.forward(from: 0);
    });
  }

  bool _bawanActive(Map v) => v['bawan'] == true || (v['currentBid'] == 9 && v['phase'] != 'bidding');

  /// لون الطاولة: لحظة النتيجة أخضر للوصول وأحمر للخسارة (مع تأثير الكلمة)، وإلا ذهبي للباون، وإلا رمادي (null)
  ({RadialGradient felt, Color glow})? _tableTone(Map v) {
    switch (_effect) {
      case 'win':
        return (felt: const RadialGradient(colors: [Color(0xFFB8F2C4), Color(0xFF3FAE5C), Color(0xFF1E6B33)], stops: [0, 0.6, 1], radius: 0.72, transform: _Ellipse()), glow: const Color(0xFF3FD067));
      case 'lose':
      case 'bawanFail':
        return (felt: const RadialGradient(colors: [Color(0xFFF7B4B4), Color(0xFFD23C3C), Color(0xFF7E1515)], stops: [0, 0.6, 1], radius: 0.72, transform: _Ellipse()), glow: const Color(0xFFFF3B3B));
    }
    if (_bawanActive(v)) {
      return (felt: const RadialGradient(colors: [Color(0xFFF3D98A), Color(0xFFC9A030)], radius: 0.72, transform: _Ellipse()), glow: KoutColors.gold);
    }
    return null;
  }

  int _rel(int seat, int n) => (seat - c.mySeat + n) % n;

  List<String> get _legal => (c.view!['legalCards'] as List).cast<String>();

  void _shakeIt(String card) => setState(() {
        _shakeCard = card;
        _shakeId++;
      });

  void _throw(String card, {Offset? from}) {
    if (from != null) _releasedAt[card] = from;
    c.play(card);
    setState(() => _selected = null);
  }

  // لمسة ترفع الورقة، ولمسة ثانية ترميها. الممنوعة تتهز
  void _tapCard(String card) {
    if (!_myTurn || c.view!['phase'] != 'playing') return;
    if (!_legal.contains(card)) return _shakeIt(card);
    if (_selected != card) {
      setState(() => _selected = card);
      return;
    }
    // بدون تحذير: اللاعب يرمي الجوكر وقت ما يبي، والقانون يطبّق نفسه
    _throw(card);
  }

  Offset _local(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    showErrors(context, c);
    final v = c.view;
    if (v == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: KoutColors.accent)));
    }
    final n = v['players'] as int;
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // الخلفية: حصير قديم (حليبي غامق قريب من لون المخدات) بدون زخرفة، شبه 3D
        RepaintBoundary(
          child: Stack(fit: StackFit.expand, children: [
            Image(image: matImage, repeat: ImageRepeat.repeat, alignment: Alignment.topLeft, fit: BoxFit.none, filterQuality: FilterQuality.low, gaplessPlayback: true),
            const CustomPaint(painter: _MatLight()),
          ]),
        ),
        SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final b = _Board(box.biggest, n);
            _board = b;
            return AnimatedBuilder(
              animation: _shake,
              builder: (_, child) {
                final t = _shake.value;
                final k = t == 0 || t == 1 ? 0.0 : sin(t * pi * 5) * (1 - t) * 5;
                return Transform.translate(offset: Offset(k, -k * 0.6), child: child);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _selected == null ? null : () => setState(() => _selected = null), // لمسة على مكان فاضي تنزّل الورقة
                child: Stack(key: _boardKey, fit: StackFit.expand, clipBehavior: Clip.none, children: [
                  // الطاولة: بيضاوية بحافة خشب، وسطها رمادي بتدرج أبيض بنفس شكلها، وتصير ذهبية في الباون
                  Positioned.fromRect(
                    rect: b.table.inflate(12),
                    child: RepaintBoundary(child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(b.size.longestSide),
                        gradient: const LinearGradient(
                          begin: Alignment(-1, -1),
                          end: Alignment(1, 1),
                          stops: [0, 0.18, 0.32, 0.5, 0.66, 0.82, 1],
                          colors: [Color(0xFFA56F3E), Color(0xFF7A4A22), Color(0xFF94602F), Color(0xFF6B3E1B), Color(0xFF8D5A2B), Color(0xFF6A3C19), Color(0xFF51300F)],
                        ),
                        border: Border.all(color: const Color(0xFF3A2209), width: 1.5),
                        boxShadow: [
                          const BoxShadow(color: Color(0x88000000), blurRadius: 22, offset: Offset(0, 10)),
                          if (_tableTone(v) != null) BoxShadow(color: _tableTone(v)!.glow.withValues(alpha: 0.6), blurRadius: 30),
                        ],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          gradient: _tableTone(v)?.felt ??
                              const RadialGradient(
                                  colors: [Color(0xFFF7F8F9), Color(0xFFB9BCC0), Color(0xFF7A7F85)], stops: [0, 0.55, 1], radius: 0.72, transform: _Ellipse()),
                          borderRadius: BorderRadius.circular(b.size.longestSide),
                          // لمعة على حافة الخشب من جوا
                          border: Border.all(color: const Color(0xFFC08A55), width: 1.5),
                        ),
                      ),
                    )),
                  ),
                  // موجة الجوكر وآص الحكم على الطاولة (تحت الأوراق)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ripple,
                        builder: (_, _) => !_ripple.isAnimating || _rippleRel == null
                            ? const SizedBox.shrink()
                            : CustomPaint(painter: _RipplePainter(table: b.table, center: b.slot(_rippleRel!), t: _ripple.value)),
                      ),
                    ),
                  ),
                  _centerInfo(v, b), // على الطاولة نفسها: الأوراق (المنزولة والمسحوبة) تغطي عليها
                  Positioned.fill(child: RepaintBoundary(child: Stack(clipBehavior: Clip.none, children: _trickLayer(v, b, n)))),
                  for (var seat = 0; seat < n; seat++)
                    _seatAt(b, _rel(seat, n), RepaintBoundary(child: _Seat(client: c, view: v, seat: seat, seconds: _seconds, me: seat == c.mySeat, size: b.avatar, nameLeft: _rel(seat, n) == n ~/ 2, voice: _talking[seat], toward: b.toward(_rel(seat, n)), showSeconds: !(b.landscape && seat == c.mySeat)))),
                  _dealLayer(v, b, n),
                  Positioned.fill(child: RepaintBoundary(child: Stack(clipBehavior: Clip.none, children: _handLayer(v, b)))),
                  _signalRow(v, b),
                  _slapLayer(b),
                  // النتيجة فوق يسار، وجنبها زر نشرة الجولات
                  Positioned(
                    top: b.landscape ? 1 : 6,
                    left: b.landscape ? b.size.width * 0.14 : 6,
                    child: Transform.scale(
                      scale: b.landscape ? 0.8 : 1,
                      alignment: Alignment.topLeft,
                      child: Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.ltr, children: [
                        _Scores(view: v),
                        const SizedBox(width: 4),
                        Pressable(child: GestureDetector(
                          onTap: withTap(() => _showRounds(context, c)),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: KoutColors.chrome(),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: KoutColors.chromeEdge, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                            ),
                            child: const Icon(Icons.receipt_long, size: 20, color: KoutColors.ink),
                          ),
                        )),
                      ]),
                    ),
                  ),
                  Positioned(top: 2, right: 2, child: _TopActions(client: c)),
                  // النوافذ بنص الطاولة بالضبط (نفس المسافة فوق وتحت مركزها). نتيجة المباراة النهائية تاخذ الشاشة كلها
                  Positioned.fromRect(
                    rect: v['phase'] == 'matchEnd'
                        ? Rect.fromLTWH(0, 0, b.size.width, b.size.height)
                        : Rect.fromCenter(center: Offset(b.size.width / 2, b.table.center.dy), width: b.size.width, height: 2 * min(b.table.center.dy, b.size.height - b.table.center.dy)),
                    child: _overlay(v),
                  ),
                ]),
              ),
            );
          }),
        ),
        if (_effect != null) Positioned.fill(child: IgnorePointer(child: _Effect(kind: _effect!))),
      ]),
    );
  }

  Widget _seatAt(_Board b, int rel, Widget child) {
    final p = b.seats[rel];
    // اللي فوق: الاسم يسار الشخصية، والشخصية بمكانها
    if (rel == b.seats.length ~/ 2) return Positioned(right: b.size.width - p.dx - (b.avatar + 10) / 2, top: p.dy - (b.avatar + 10) / 2, child: child);
    // اللي على حافة الشاشة: الاسم ما يطلع برا الشاشة
    final w = min(130.0, 2 * min(p.dx, b.size.width - p.dx) + 8.0);
    return Positioned(left: p.dx - w / 2, top: p.dy - (b.avatar + 10) / 2, width: w, child: child);
  }

  Widget _cardAt(Offset p, double w, Widget child) => Positioned(left: p.dx - w / 2, top: p.dy - w * cardRatio / 2, child: child);

  // معلومات الجولة بوسط الطاولة: الحكم وعدد المزايدة واسم المزايد
  Widget _centerInfo(Map<String, dynamic> v, _Board b) {
    final trump = v['trump'] as String?;
    final buyer = v['buyer'] as int?;
    if (trump == null || buyer == null) return const SizedBox.shrink();
    final bawan = _bawanActive(v);
    final suit = Stack(alignment: Alignment.center, children: [
      SuitIcon(trump, size: 34, color: Colors.black),
      SuitIcon(trump, size: 28, color: isRedSuit(trump) ? const Color(0xFFFF4D4D) : const Color(0xFF2B2B2B)),
    ]);
    final bid = OutlinedText(bawan ? 'باون' : '${v['currentBid']}', size: 30, color: bawan ? KoutColors.gold : Colors.white);
    final name = OutlinedText(c.seatName(buyer), size: b.landscape ? 15 : 12, color: KoutColors.team(buyer % 2));
    if (b.landscape) {
      // بالعرضي: يسار (الحكم والعدد) ويمين (الشاري)، جنب أوراق الجنبين بنفس المسافة من الوسط
      final d = b.cardW * 2.1 + 60; // طرف أوراق الجنب (1.6 + نص ورقة) + مسافة
      const box = 110.0;
      Widget at(double x, Widget child) => Positioned(
            left: b.center.dx + x - box / 2,
            width: box,
            top: b.center.dy - 60,
            height: 120,
            child: Center(child: child),
          );
      return Positioned.fill(
        child: IgnorePointer(
          child: Stack(children: [
            at(-d, Column(mainAxisSize: MainAxisSize.min, children: [suit, bid])),
            at(d, Column(mainAxisSize: MainAxisSize.min, children: [const OutlinedText('الشاري', size: 11, color: Color(0xFFEEEEEE)), name])),
          ]),
        ),
      );
    }
    // بالطولي بوسط الطاولة، أصغر شوي، وكل شي بحد أسود
    return Positioned(
      left: b.center.dx - 80,
      top: b.center.dy - 36,
      width: 160,
      child: IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [suit, const SizedBox(width: 6), bid]),
          name,
        ]),
      ),
    );
  }

  List<Widget> _trickLayer(Map<String, dynamic> v, _Board b, int n) {
    final w = b.cardW;
    final current = (v['trick'] as List).cast<Map<String, dynamic>>();
    final out = <Widget>[];

    // اللمّة اللي قاعدة تنلم: آخر ورقة توصل، والورقة الفايزة تجمع الباقي عندها، وبعدها كلها تروح للفائز
    final last = _collecting;
    if (last != null) {
      final cards = (last['cards'] as List).cast<Map<String, dynamic>>();
      final winner = last['winner'] as int;
      final winRel = _rel(winner, n);
      final winPos = b.seats[winRel];
      final winSlot = b.slot(winRel);
      final winTilt = b.tilts[winRel];
      out.add(Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _collect,
            builder: (_, _) {
              // بالملي ثانية: الوصول 260، الورق كله واقف على الطاولة لين 600، الفايزة ترتفع لحالها لين 900، الجمع عندها 940 لين 1300،
              // وبعدها الكومة تبقى ظاهرة لين آخر 400 تنسحب فيها للفائز
              final total = _collect.duration!.inMilliseconds;
              final ms = _collect.value * total;
              final arrive = Curves.easeOut.transform((ms / 260).clamp(0.0, 1.0));
              final lift = Curves.easeOutBack.transform(((ms - 600) / 300).clamp(0.0, 1.0));
              final gather = Curves.easeInOut.transform(((ms - 940) / 360).clamp(0.0, 1.0));
              final pull = Curves.easeIn.transform(((ms - (total - 400)) / 400).clamp(0.0, 1.0));
              final liftSlot = winSlot + Offset(0, -w * 0.12 * lift); // الفايزة ترتفع شوي فوق مكانها
              // من أول ما ترتفع الورقة الفايزة فوق الكل
              final order = lift > 0 ? [...cards.where((c) => c['seat'] != winner), ...cards.where((c) => c['seat'] == winner)] : cards;
              return Stack(clipBehavior: Clip.none, children: [
                for (final card in order)
                  Builder(builder: (_) {
                    final rel = _rel(card['seat'] as int, n);
                    final slot = b.slot(rel);
                    var pos = identical(card, cards.last) ? Offset.lerp(_fromFor(card['card'] as String, b, rel), slot, arrive)! : slot;
                    // الفايزة ترتفع لحالها، والباقي ينسحب لها وهي مرتفعة
                    pos = rel == winRel ? pos + (liftSlot - winSlot) : Offset.lerp(pos, liftSlot, gather)!;
                    pos = Offset.lerp(pos, winPos, pull)!;
                    final tilt = b.tilts[rel] + (winTilt - b.tilts[rel]) * gather;
                    // الفايزة تكبر وهي ترتفع، والباقي يكبر معها لما يوصل عندها عشان الكومة وحدة
                    final pop = rel == winRel ? 0.15 * lift : 0.15 * lift * gather;
                    return _cardAt(
                      pos,
                      w,
                      Transform.rotate(
                        angle: tilt * pi / 180 * (1 - pull),
                        child: Transform.scale(scale: 1 + pop - 0.45 * pull, child: PlayingCard(card['card'] as String, width: w, opacity: 1 - 0.7 * pull)),
                      ),
                    );
                  }),
              ]);
            },
          ),
        ),
      ));
    }

    // اللمّة الحالية: كل ورقة تطير من صاحبها لمكانها قدامه
    for (final t in current) {
      final rel = _rel(t['seat'] as int, n);
      final card = t['card'] as String;
      final from = _fromFor(card, b, rel);
      final to = b.slot(rel);
      out.add(TweenAnimationBuilder<double>(
        key: ValueKey('${v['round']}-$card'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (_, p, child) => _cardAt(
          Offset.lerp(from, to, p)!,
          w,
          Transform.rotate(angle: b.tilts[rel] * pi / 180 * p, child: Transform.scale(scale: (rel == 0 ? 1.25 : 0.8) + (rel == 0 ? -0.25 : 0.2) * p, child: child)),
        ),
        child: IgnorePointer(child: PlayingCard(card, width: w)),
      ));
    }
    return out;
  }

  Offset _fromFor(String card, _Board b, int rel) => (rel == 0 ? _releasedAt[card] : null) ?? b.seats[rel];

  // ترتيب اللي ياخذون ورق: يبدأ باللي على يمين الموزع (عكس عقارب الساعة، مثل اللعب).
  // ورق الموزع عنده أصلاً، إلا إذا الموزع أنا: ورقي ينزل لصف اليد
  List<int> _dealOrder(int dealer, int n) => [
        for (var i = 1; i <= n; i++)
          if ((dealer + i) % n != dealer || dealer == 0) (dealer + i) % n,
      ];

  // متى تطلع الورقة رقم k من دفعة اللاعب رقم turn (من 0 لـ 1 من وقت التوزيع)، وتاخذ 0.25 لين توصل
  double _dealStart(int turn, int k, int players) => (turn + k / 9 * 0.7) * (0.75 / players);

  // مكان الورقة بصف اليد: الأطراف تميل لبرا وتنزل شوي
  ({double left, double top, double angle}) _handSlot(_Board b, int i, int n) {
    final w = b.handW;
    // اليد تنفرد بين handLeft و handRight (بالعرضي فيه مكان لشخصيتي يسار والإشارات يمين)
    final avail = b.handRight - b.handLeft;
    // المسافة بين الأوراق ثابتة (محسوبة على يد كاملة 9 أوراق)، فلما تنقص ورقة يتقاربون للوسط ويبقى الشكل مرتب.
    // بالعرضي الأوراق أقرب لبعض
    final step = min(min(w + 4, (avail - w) / (max(n, 9) - 1)), b.landscape ? w * 0.3 : double.infinity);
    final total = w + step * (n - 1);
    // اليد من اليسار لليمين (هاس، كلفس، ديمن، سبيت، ثم الجوكرين)
    // بالعرضي اليد بنص الشاشة، وبالطولي بنص مساحتها
    final left = (b.landscape ? (b.size.width - total) / 2 : b.handLeft + (avail - total) / 2) + i * step;
    final t = n == 1 ? 0.0 : (i - (n - 1) / 2) / ((n - 1) / 2);
    // الوسط أعلى والأطراف بنفس مكان اليد القديم
    return (left: left, top: (t * t - 1) * w * 0.12 + b.handTop, angle: t * min(0.22, n * 0.026));
  }

  // أنميشن التوزيع: كل لاعب ياخذ 9 أوراق دفعة وحدة بالدور من الموزع.
  // ورق الخصوم يوقف قدام شخصياتهم، وورقي ينزل لصف اليد ورقة ورقة
  Widget _dealLayer(Map<String, dynamic> v, _Board b, int n) {
    final dealer = _rel(v['khabis'] as int, n);
    final order = _dealOrder(dealer, n);
    final inHand = (v['hand'] as List).length;
    final w = b.cardW * 0.6;
    // قدام الشخصية من جهة الطاولة، عشان الورق الدوّار ما يغطي عليها
    Offset front(int rel) => b.seats[rel] + b.toward(rel) * (b.avatar * 0.5 + w * 0.9 + 6);
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(child: AnimatedBuilder(
          animation: _deal,
          builder: (_, _) {
            if (!_deal.isAnimating) return const SizedBox.shrink();
            final t = _deal.value;
            return Stack(clipBehavior: Clip.none, children: [
              for (var i = 0; i < order.length; i++)
                for (var k = 0; k < 9; k++)
                  Builder(builder: (_) {
                    final p = ((t - _dealStart(i, k, order.length)) / 0.25).clamp(0.0, 1.0);
                    if (p <= 0 || p >= 1) return const SizedBox.shrink();
                    final e = Curves.easeOut.transform(p);
                    final rel = order[i];
                    if (rel == 0 && k < inHand) {
                      final slot = _handSlot(b, k, inHand);
                      final size = w + (b.handW - w) * e;
                      final to = Offset(slot.left + b.handW / 2, slot.top + _dealtDrop(b) + b.handW * cardRatio / 2);
                      return _cardAt(
                        Offset.lerp(front(dealer), to, e)!,
                        size,
                        Transform.rotate(angle: (2 * pi + slot.angle) * e, child: RepaintBoundary(child: CardBack(width: size))),
                      );
                    }
                    return _cardAt(
                      Offset.lerp(front(dealer), front(rel), e)!,
                      w,
                      Transform.rotate(angle: p * pi, child: RepaintBoundary(child: CardBack(width: w))),
                    );
                  }),
            ]);
          },
        )),
      ),
    );
  }

  // نزول ورق اليد وقت ما هو دوري
  double _dealtDrop(_Board b) => b.landscape ? 12 : 28;

  List<Widget> _handLayer(Map<String, dynamic> v, _Board b) {
    final hand = (v['hand'] as List).cast<String>();
    final legal = _legal.toSet();
    final myTurn = legal.isNotEmpty && _deal.isAnimating == false;
    final w = b.handW;
    final n = max(hand.length, 1);
    final players = v['players'] as int;
    final order = _dealOrder(_rel(v['khabis'] as int, players), players);
    final out = <Widget>[];
    final dealing = _deal.isAnimating;
    // الورق مقلوب لين يوصل دورك بالمزايدة (أو تختار الحكم)، ويرجع مقلوب لين يبدأ اللعب
    final phase = v['phase'];
    final hidden = dealing || (phase == 'bidding' && (v['legalBids'] as List).isEmpty) || (phase == 'trump' && v['buyer'] != c.mySeat);
    for (var i = 0; i < hand.length; i++) {
      final card = hand[i];
      final ok = legal.contains(card);
      final sel = card == _selected;
      final slot = _handSlot(b, i, n);
      final left = slot.left, angle = slot.angle;
      final top = slot.top + (b.landscape ? (sel ? -14 : (myTurn && ok ? 4 : _dealtDrop(b))) : (sel ? -8 : (myTurn && ok ? 18 : _dealtDrop(b))));
      // وقت التوزيع الورقة تبين بصف اليد لحظة وصولها
      final land = order.contains(0) ? _dealStart(order.indexOf(0), i, order.length) + 0.25 : 0.6;
      Widget face = _FlipCard(
        faceUp: !hidden,
        builder: (shown) => PlayingCard(
          shown ? card : 'back',
          width: w,
          highlight: sel,
          enabled: !myTurn || ok,
          opacity: _selected != null && !sel ? 0.6 : 1, // الباقي يخفت
          fade: dealing ? _deal.drive(CurveTween(curve: Interval(min(land, 0.98), min(land + 0.02, 1)))) : null,
          shadow: !dealing,
        ),
      );
      if (card == _shakeCard) {
        face = TweenAnimationBuilder<double>(
          key: ValueKey('shake$_shakeId'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 360),
          builder: (_, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * (1 - t) * 8, 0), child: child),
          child: face,
        );
      }
      out.add(AnimatedPositioned(
        key: ValueKey(card),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        left: left,
        top: top,
        // الميلان يتحرك بنعومة مع تحرك الورقة لمكانها الجديد.
        // لازم يكون برا الباقي: منطقة الضغط تميل مع الورقة، وإلا الجزء الظاهر من ورقة الطرف ما ينضغط
        child: AnimatedRotation(
          turns: angle / (2 * pi),
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            // الورقة اللي تنسحب تبقى بمكانها مخفية (عشان السحب ما ينقطع)، ونسخة منها تلحق الإصبع
            opacity: card == _dragCard ? 0 : 1,
            child: AnimatedScale(
              scale: sel ? 1.12 : 1,
              alignment: Alignment.bottomCenter,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(
                key: ValueKey('hand-$card'),
                onTap: () => _tapCard(card),
                // السحب: الورقة تكبر وتلحق الإصبع (بس إذا دورك)
                onPanStart: myTurn && v['phase'] == 'playing'
                    ? (d) => setState(() {
                          _dragCard = card;
                          _selected = null;
                          _dragPos = _local(d.globalPosition);
                          _dragOver = false;
                        })
                    : null,
                onPanUpdate: myTurn ? (d) => setState(() {
                      _dragPos = _local(d.globalPosition);
                      _dragOver = _dragPos.dy < b.handTop - 10;
                    }) : null,
                onPanEnd: myTurn ? (_) => _endDrag(card) : null,
                onPanCancel: myTurn ? () => setState(() => _dragCard = null) : null,
                child: face,
              ),
            ),
          ),
        ),
      ));
    }
    if (_dragCard != null) {
      out.add(_cardAt(_dragPos, w, IgnorePointer(child: Transform.scale(scale: 1.2, child: PlayingCard(_dragCard!, width: w, highlight: _dragOver)))));
    }
    return out;
  }

  // تركها فوق الحد = تنرمى. قبل الحد = ترجع لليد مرفوعة. الممنوعة تتهز وترجع
  void _endDrag(String card) {
    final over = _dragOver;
    final pos = _dragPos;
    setState(() {
      _dragCard = null;
      _dragOver = false;
    });
    if (!_legal.contains(card)) return _shakeIt(card);
    if (over) {
      _throw(card, from: pos);
    } else {
      setState(() => _selected = card);
    }
  }

  // الإشارات: بدون نافذة. بالطولي مربع فوق اليد، وبالعرضي صف يمين تحت جنب اليد
  Widget _signalRow(Map<String, dynamic> v, _Board b) {
    if (b.landscape) return Positioned(right: 10, bottom: 8, child: _SignalBar(client: c, view: v, row: true));
    // بالطولي المربع على يمين شخصيتي فوق اليد
    return Positioned(right: 14, bottom: b.size.height - b.handTop + 4, child: _SignalBar(client: c, view: v));
  }

  // كف الجوكر الكبير: ينزل من جهة صاحبه ويضرب ورقته على الطاولة
  Widget _slapLayer(_Board b) {
    final rel = _slapRel;
    if (rel == null) return const SizedBox.shrink();
    final seat = b.seats[rel];
    final target = b.slot(rel);
    final from = seat + (seat - b.center) * 0.25;
    final dir = b.center - seat;
    final rot = atan2(dir.dy, dir.dx) + pi / 2;
    final size = b.cardW * 1.6;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _slap,
          builder: (_, _) {
            final ms = _slap.value * 820;
            Offset pos;
            double scale, opacity;
            if (ms < 170) {
              final p = Curves.easeIn.transform(ms / 170);
              pos = Offset.lerp(from, target, p)!;
              scale = 1.6 - 0.6 * p;
              opacity = (p / 0.6).clamp(0.0, 1.0);
            } else {
              final q = (ms - 170) / 650;
              pos = target;
              scale = 1 + 0.1 * q;
              opacity = q < 0.7 ? 1 : (1 - q) / 0.3;
            }
            final ring = ms < 170 ? 0.0 : ((ms - 170) / 450).clamp(0.0, 1.0);
            return Stack(clipBehavior: Clip.none, children: [
              if (ring > 0 && ring < 1)
                Positioned(
                  left: target.dx - 10,
                  top: target.dy - 10,
                  child: Transform.scale(
                    scale: 1 + 6 * ring,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KoutColors.teamYellow.withValues(alpha: 0.9 * (1 - ring)), width: 3 / (1 + 6 * ring) * 2)),
                    ),
                  ),
                ),
              Positioned(
                left: pos.dx - size / 2,
                top: pos.dy - size / 2,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(angle: rot, child: Transform.scale(scale: scale, child: CustomPaint(size: Size.square(size), painter: _PalmPainter()))),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _overlay(Map<String, dynamic> v) {
    final phase = v['phase'] as String;
    final me = c.mySeat;
    final buyer = v['buyer'] as int?;
    if ((v['legalBids'] as List).isNotEmpty && !_deal.isAnimating) {
      return _ChromePanel(child: _BidPanel(client: c, view: v, seconds: _seconds));
    }
    if (phase == 'trump') {
      final left = c.secondsLeft;
      return _ChromePanel(
        child: buyer == me
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('حكمك؟', style: TextStyle(fontSize: 22, color: KoutColors.ink)),
                  if (left != null) _Countdown(seconds: _seconds),
                ]),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final s in suitOrder)
                      _ChromeButton(
                        onTap: () => c.chooseTrump(s),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SuitIcon(s, size: 30, color: isRedSuit(s) ? const Color(0xFFFF4D4D) : Colors.white),
                          Text(suitNames[s]!, style: TextStyle(fontSize: 14, color: isRedSuit(s) ? const Color(0xFFFF4D4D) : Colors.white)),
                        ]),
                      ),
                  ]),
                ),
                if (v['majbur'] == true)
                  const Padding(padding: EdgeInsets.only(top: 8), child: Text('6 مجبور', style: TextStyle(fontSize: 14, color: KoutColors.majbur))),
              ])
            : Text('${c.seatName(buyer!)} يختار الحكم...', style: const TextStyle(fontSize: 18, color: KoutColors.ink)),
      );
    }
    if (v['bawanOffer'] == true) {
      return _ChromePanel(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('مسؤول؟', style: TextStyle(fontSize: 24, color: KoutColors.ink)),
          const SizedBox(height: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _ChromeButton(onTap: () => c.answerBawan(true), gold: true, child: const Text('باون', style: TextStyle(fontSize: 20, color: Colors.black))),
            const SizedBox(width: 10),
            _ChromeButton(onTap: () => c.answerBawan(false), child: const Text('لا', style: TextStyle(fontSize: 20, color: Colors.white))),
          ]),
        ]),
      );
    }
    if (phase == 'bawanOffer') {
      return _ChromePanel(child: Text('${c.seatName(buyer!)} يفكر يعلن باون...', style: const TextStyle(fontSize: 18, color: KoutColors.ink)));
    }
    // النتيجة تطلع بعد ما تخلص آخر لمّة
    if ((phase == 'roundEnd' || phase == 'matchEnd') && _collecting == null) return _Panel(big: phase == 'matchEnd', child: _RoundResult(client: c, view: v));
    return const SizedBox.shrink();
  }
}

/// كتابة بحد أسود عريض (حد مرسوم تحت الكتابة)
class OutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const OutlinedText(this.text, {super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, height: 1.15);
    return Stack(alignment: Alignment.center, children: [
      Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = max(3, size * 0.16)
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = Colors.black)),
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: color)),
    ]);
  }
}

/// يخلي التدرج الدائري بيضاوي بنفس شكل الطاولة
/// موجة مثل قطرة ماي: موجة برتقالية وحدة تتوسع من مكان الورقة وتخف، محصورة داخل الطاولة
class _RipplePainter extends CustomPainter {
  final Rect table;
  final Offset center;
  final double t; // 0..1
  _RipplePainter({required this.table, required this.center, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(table, Radius.circular(table.shortestSide / 2)));
    final far = [table.topLeft, table.topRight, table.bottomLeft, table.bottomRight].map((p) => (p - center).distance).reduce(max);
    final r = Curves.easeOutCubic.transform(t) * far;
    final fade = 1 - t * t; // يخف ببطء بالأول وبسرعة بالآخر
    const orange = Color(0xFFF08A24);
    if (r > 1) {
      // الماي المتحرك: لون خفيف داخل الدايرة وأقوى عند حافة الموجة
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [orange.withValues(alpha: 0.12 * fade), orange.withValues(alpha: 0.38 * fade), orange.withValues(alpha: 0.8 * fade), orange.withValues(alpha: 0)],
              stops: const [0, 0.7, 0.94, 1],
            ).createShader(Rect.fromCircle(center: center, radius: r)));
    }
    // حلقة الموجة: وحدة بس عند الحافة
    for (final (k, a) in const [(1.0, 1.0)]) {
      final rr = r * k;
      if (rr < 2) continue;
      canvas.drawCircle(
          center,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + 6 * fade
            ..color = const Color(0xFFFF9A2E).withValues(alpha: a * fade));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t || old.center != center;
}

class _Ellipse extends GradientTransform {
  const _Ellipse();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final s = bounds.shortestSide;
    return Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
      ..scaleByDouble(bounds.width / s, bounds.height / s, 1, 1)
      ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
  }
}

/// الحصير صورة جاهزة (tools/mat-art/mat.html)، لأن رسم خيوطه آلاف الأشكال بكل إطار.
/// مقياسها 1.5 عشان خيوطها بنفس الحجم على كل الشاشات.
const matImage = ExactAssetImage('assets/images/mat.jpg', scale: 1.5);

/// ضوء من فوق يسار، والأطراف أغمق (عمق)
class _MatLight extends CustomPainter {
  const _MatLight();

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = const Color(0x38000000)); // الحصير أغمق شوي
    canvas.drawRect(
        all,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.3,
            colors: [Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x66000000)],
            stops: [0, 0.5, 1],
          ).createShader(all));
  }

  @override
  bool shouldRepaint(_MatLight old) => false;
}

/// الكف (بدون رسغ ولا كم): حدود سودا، أظافر ومفاصل وخطوط كف وظل. نفس tools/sound-candidates/hand-slap.html
class _PalmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 110);
    canvas.drawOval(Rect.fromCenter(center: const Offset(4, 6), width: 80, height: 88), Paint()..color = Colors.black.withValues(alpha: 0.28));
    final ink = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final fing = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFD79F78), Color(0xFFEFC29C), Color(0xFFD1976F)], stops: [0, 0.45, 1])
          .createShader(const Rect.fromLTWH(-50, -55, 100, 70));
    void shape(Path p, Paint fill) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, ink);
    }

    shape(
        Path()
          ..moveTo(-24, 6)
          ..quadraticBezierTo(-38, 0, -45, -12)
          ..quadraticBezierTo(-49, -20, -43, -23)
          ..quadraticBezierTo(-37, -25, -32, -17)
          ..quadraticBezierTo(-26, -8, -21, -4)
          ..close(),
        fing);
    Path finger(double l, double r, double top) {
      final mid = (l + r) / 2;
      return Path()
        ..moveTo(l, -3)
        ..lineTo(l, top + 7)
        ..quadraticBezierTo(l, top, mid, top)
        ..quadraticBezierTo(r, top, r, top + 7)
        ..lineTo(r, -3)
        ..close();
    }

    shape(finger(-25, -14, -43), fing);
    shape(finger(-12.5, -0.5, -51), fing);
    shape(finger(1, 13, -49), fing);
    shape(finger(14.5, 24.5, -37), fing);
    shape(
        Path()
          ..moveTo(-26, -8)
          ..quadraticBezierTo(-28, 18, -16, 32)
          ..quadraticBezierTo(2, 42, 22, 32)
          ..quadraticBezierTo(30, 20, 27, -6)
          ..quadraticBezierTo(12, -12, -2, -11)
          ..quadraticBezierTo(-16, -11, -26, -8)
          ..close(),
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFFF0C39D), Color(0xFFE2AB83), Color(0xFFC98E66)], stops: [0, 0.65, 1])
              .createShader(Rect.fromCircle(center: const Offset(0, 10), radius: 40)));
    // الأظافر
    final nail = Paint()..color = const Color(0xFFF7DDD0);
    final thin = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (x, y, w) in [(-22.5, -40.0, 6.0), (-9.5, -48.0, 6.0), (4.0, -46.0, 6.0), (17.0, -34.0, 5.0)]) {
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + w / 2, y - 4, x + w, y)
        ..lineTo(x + w, y + 5)
        ..quadraticBezierTo(x + w / 2, y + 6.5, x, y + 5)
        ..close();
      canvas.drawPath(p, nail);
      canvas.drawPath(p, thin);
    }
    final thumbNail = Path()
      ..moveTo(-44, -20)
      ..quadraticBezierTo(-41, -24, -37.5, -21)
      ..lineTo(-36, -17)
      ..quadraticBezierTo(-39, -15, -42, -16.5)
      ..close();
    canvas.drawPath(thumbNail, nail);
    canvas.drawPath(thumbNail, thin);
    // مفاصل الأصابع
    final joint = Paint()
      ..color = const Color(0xCC111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (x, y, w) in [(-23.0, -26.0, 7.0), (-23.0, -16.0, 7.0), (-10.5, -33.0, 8.0), (-10.5, -20.0, 8.0), (3.0, -31.0, 8.0), (3.0, -18.0, 8.0), (16.5, -23.0, 6.0), (16.5, -13.0, 6.0), (-39.0, -13.0, 6.0)]) {
      canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(x + w / 2, y + 1.5, x + w, y),
          joint);
    }
    // خطوط الكف
    final line = Paint()
      ..color = const Color(0xFF9B6544)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(-20, 2)
          ..quadraticBezierTo(-4, 8, 18, 0),
        line);
    canvas.drawPath(
        Path()
          ..moveTo(-22, 10)
          ..quadraticBezierTo(-6, 14, 8, 22)
          ..quadraticBezierTo(14, 26, 16, 30),
        line);
    canvas.drawPath(
        Path()
          ..moveTo(-14, -2)
          ..quadraticBezierTo(-18, 12, -12, 26),
        line);
  }

  @override
  bool shouldRepaint(_PalmPainter old) => false;
}

/// ورقة تنقلب بين وجهها وظهرها
class _FlipCard extends StatelessWidget {
  final bool faceUp;
  final Widget Function(bool shown) builder;
  const _FlipCard({required this.faceUp, required this.builder});

  @override
  Widget build(BuildContext context) {
    final end = faceUp ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: end, end: end),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (_, t, _) {
        final shown = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(pi * (shown ? t - 1 : t)),
          child: builder(shown),
        );
      },
    );
  }
}

/// يكبّر النافذة، ويصغّرها بس إذا ما وسعتها المساحة
class _Grow extends StatelessWidget {
  final double scale;
  final double? portraitScale; // تكبير ثاني للشاشة الطولية (إذا انعطى)
  final Widget child;
  const _Grow({required this.child, this.scale = 1.35, this.portraitScale});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        // التكبير الزايد (النتيجة النهائية) بس إذا العرض يكفي، عشان الكلام ما ينكسر بالشاشة الطولية
        final portrait = box.maxHeight > box.maxWidth;
        final scale = portrait && portraitScale != null
            ? portraitScale!
            : (this.scale <= 1.35 ? this.scale : max(1.35, min(this.scale, box.maxWidth / 350)));
        final w = box.maxWidth / scale, h = box.maxHeight / scale;
        return Center(
          child: Transform.scale(
            scale: scale,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w, maxHeight: h),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(constraints: BoxConstraints(maxWidth: w), child: child),
              ),
            ),
          ),
        );
      });
}

/// نافذة كروم شفافة شوي (~82%) بإطار رصاصي غامق وخط لمعة فوق: المزايدة والحكم والباون
class _ChromePanel extends StatelessWidget {
  final Widget child;
  const _ChromePanel({required this.child});

  @override
  Widget build(BuildContext context) => _Grow(
        child: Container(
          margin: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            gradient: KoutColors.chrome(0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KoutColors.chromeEdge, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 6))],
          ),
          child: Stack(children: [
            Positioned(
              top: 3,
              left: 24,
              right: 24,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)]),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: child),
          ]),
        ),
      );
}

class _ChromeButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool gold;
  final Color? color;
  final EdgeInsets padding;
  const _ChromeButton({required this.onTap, required this.child, this.gold = false, this.color, this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 9)});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.35, // الأرقام اللي ما تجوز باهتة
      child: Pressable(child: GestureDetector(
        onTap: withTap(onTap),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gold
                ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6DA7A), Color(0xFFC9971E)])
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [(color ?? const Color(0xFF5D636B)).withValues(alpha: 0.92), (color ?? KoutColors.chromeButton).withValues(alpha: 0.95)]),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: gold ? const Color(0xFF8C6410) : const Color(0xFF2E3237), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: child,
        ),
      )),
    );
  }
}

class _Countdown extends StatelessWidget {
  final ValueNotifier<int?> seconds;
  const _Countdown({required this.seconds});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 10),
        child: ValueListenableBuilder(
          valueListenable: seconds,
          builder: (_, left, _) {
            final s = left ?? 0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 18, color: s <= 3 ? KoutColors.lose : KoutColors.ink),
              Text(' $s', style: TextStyle(fontSize: 18, color: s <= 3 ? KoutColors.lose : KoutColors.ink)),
            ]);
          },
        ),
      );
}

/// حلقة وقت الدور: تنقص بنعومة لحالها، بدون ما تعيد رسم غيرها
class _TurnRing extends StatefulWidget {
  final GameClient client;
  final double total;
  const _TurnRing({required this.client, required this.total});

  @override
  State<_TurnRing> createState() => _TurnRingState();
}

class _TurnRingState extends State<_TurnRing> {
  // 20 مرة بالثانية تكفي: الحلقة تتحرك أقل من بكسل كل مرة، و60 تعيد تركيب الشاشة كلها
  late final Timer _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.client.secondsLeft ?? 0;
    return RepaintBoundary(
      child: CircularProgressIndicator(
        value: (left / widget.total).clamp(0.0, 1.0),
        strokeWidth: 4,
        color: left <= 3 ? KoutColors.lose : Colors.white,
        backgroundColor: Colors.black38,
      ),
    );
  }
}

/// النتائج والكلام الثاني: لوحة غامقة
class _Panel extends StatelessWidget {
  final Widget child;
  final bool big; // نتيجة المباراة النهائية: أكبر
  const _Panel({required this.child, this.big = false});

  @override
  Widget build(BuildContext context) => _Grow(
        scale: big ? 1.7 : 1.35,
        portraitScale: big ? 1.35 * 0.6 : null, // النتيجة النهائية بالطولي أصغر 40٪
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: const Color(0xF2111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 24)],
          ),
          child: child,
        ),
      );
}

/// لون الفريق على خلفية الكروم (ألوان الفريقين العادية فاتحة عليها)
Color _teamInk(int t) => t == 0 ? const Color(0xFF0F4FA8) : const Color(0xFFFFD21F);

/// الأصفر فاتح، فيحتاج ظل غامق عشان يبين على الكروم
const _numShadow = [Shadow(color: Color(0xE6000000), blurRadius: 2.5, offset: Offset(0, 1))];
List<Shadow>? _teamShadow(int t) => t == 0 ? null : _numShadow;

/// جملة نتيجة الجولة
/// report: سطر نشرة الجولات («محمد وصل 6» / «محمد خسر 12» بالنقاط اللي راحت)
String _roundLine(GameClient client, Map r, {bool report = false}) {
  final buyerName = r['buyer'] is int ? client.seatName(r['buyer'] as int) : '';
  final offender = r['offender'] is int ? client.seatName(r['offender'] as int) : '';
  final majbur = r['majbur'] == true ? ' (مجبور)' : '';
  return switch (r['type']) {
    'made' when report => '$buyerName وصل ${r['points']}$majbur',
    'failed' when report => '$buyerName خسر ${r['points']}$majbur',
    'made' => '$buyerName جاب ${r['bid']}$majbur',
    'failed' => '$buyerName ما جاب ${r['bid']}$majbur',
    'greyPenalty' => '$offender خيّس الجوكر الصغير',
    'bawanWin' => '$buyerName جاب باون: كل اللمّات!',
    'bawanFail' => 'انقلب الباون',
    'blueEarly' => '$offender رمى الجوكر الكبير قبل الصغير',
    'blueStuck' => '$offender خيّس الجوكر الكبير',
    _ => '',
  };
}

/// نشرة الجولات: نتيجة كل جولة خلصت، الأحدث فوق
void _showRounds(BuildContext context, GameClient c) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        final v = c.view;
        final rounds = ((v?['history'] as List?) ?? const []).cast<Map>().reversed.toList();
        final myTeam = (v?['team'] as int?) ?? 0;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          decoration: BoxDecoration(
            gradient: KoutColors.chrome(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: KoutColors.chromeEdge, width: 2),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('نشرة الجولات', style: TextStyle(fontSize: 20, color: KoutColors.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (rounds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('ما خلصت أي جولة بعد', style: TextStyle(fontSize: 15, color: KoutColors.ink)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rounds.length,
                      separatorBuilder: (_, _) => const Divider(height: 14, color: KoutColors.chromeEdge),
                      itemBuilder: (_, i) {
                        final r = rounds[i];
                        final team = r['team'] as int;
                        final scores = (r['scores'] as List).cast<int>();
                        return Row(children: [
                          SizedBox(width: 62, child: Text('الجولة ${r['round']}', style: const TextStyle(fontSize: 12, color: KoutColors.ink))),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_roundLine(c, r, report: true), style: const TextStyle(fontSize: 15, color: KoutColors.ink)),
                              Text('فريقك ${scores[myTeam]} · الخصم ${scores[1 - myTeam]}', style: const TextStyle(fontSize: 12, color: KoutColors.ink)),
                            ]),
                          ),
                          Text(r['points'] == null ? 'فوز' : '+${r['points']}', style: TextStyle(fontSize: 18, color: _teamInk(team), fontWeight: FontWeight.w700, shadows: _teamShadow(team))),
                        ]);
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Pressable(child: OutlinedButton.icon(
                  onPressed: withTap(() => Navigator.pop(ctx)),
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('رجوع'),
                )),
              ]),
            ),
          ),
        );
      },
    ),
  );
}

/// النتيجة: الأزرق يسار والأصفر يمين، وبالنص عداد اللمّات المشترك:
/// 9 نقاط، الأزرق يعبّي من اليسار والأصفر من اليمين، والنقطة البيضاء هدف الفريقين بهالجولة
/// (مثلاً الشاري الأزرق بـ 6: الأزرق يحتاج 6 نقاط والأصفر 4 من الجهة الثانية، ويلتقون عندها).
class _Scores extends StatelessWidget {
  final Map<String, dynamic> view;
  const _Scores({required this.view});

  static const _tricks = 9;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final myTeam = v['team'] as int;
    final scores = (v['scores'] as List).cast<int>();
    final won = (v['tricksWon'] as List).cast<int>();
    final buyer = v['buyer'] as int?;
    final bid = v['currentBid'] as int;
    final playing = v['trump'] != null && buyer != null;
    final bawan = v['bawan'] == true;
    // هدف كل فريق: الشاري يحتاج عدد المزايدة (أو كلها بالباون)، والخصم يحتاج الباقي + 1 عشان يكسره
    final need = playing ? (bawan ? _tricks : bid) : 0;
    final goal = playing ? (buyer % 2 == 0 ? [need, _tricks - need + 1] : [_tricks - need + 1, need]) : [0, 0];

    Widget score(int t) => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t == myTeam ? 'فريقك' : 'الخصم', style: TextStyle(fontSize: 9, color: _teamInk(t), height: 1.1, shadows: _teamShadow(t))),
          Text('${scores[t]}', style: TextStyle(fontSize: 19, color: _teamInk(t), height: 1.05, shadows: _numShadow)),
        ]);
    Widget count(int t) => Text(playing ? '${won[t]}/${goal[t]}' : '', style: TextStyle(fontSize: 11, color: _teamInk(t), shadows: _numShadow));

    Widget dot(int i) {
      // i من اليسار
      final blue = i < won[0], yellow = i >= _tricks - won[1];
      final marker = playing && i == goal[0] - 1;
      final fill = blue ? _teamInk(0) : (yellow ? _teamInk(1) : const Color(0xFF5A5F66));
      return Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marker && !blue && !yellow ? Colors.white : fill,
          border: marker ? Border.all(color: Colors.white, width: 2) : null,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 5),
      decoration: BoxDecoration(
        gradient: KoutColors.chrome(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoutColors.chromeEdge, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            score(0),
            const SizedBox(width: 30),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('من', style: TextStyle(fontSize: 9, color: KoutColors.ink, height: 1.1)),
              Text('${v['winScore'] ?? 54}', style: const TextStyle(fontSize: 13, color: KoutColors.ink, height: 1.1, shadows: _numShadow)),
            ]),
            const SizedBox(width: 30),
            score(1),
          ]),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 26, child: count(0)),
            for (var i = 0; i < _tricks; i++) dot(i),
            SizedBox(width: 26, child: Align(alignment: Alignment.centerRight, child: count(1))),
          ]),
        ]),
      ),
    );
  }
}

class _TopActions extends StatelessWidget {
  final GameClient client;
  const _TopActions({required this.client});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (!client.connected) const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.wifi_off, size: 20, color: KoutColors.lose)),
        if (Fullscreen.supported)
          ValueListenableBuilder<bool>(
            valueListenable: Fullscreen.on,
            builder: (context, full, _) => Pressable(child: IconButton(
              icon: Icon(full ? Icons.fullscreen_exit : Icons.fullscreen, size: 26, color: Colors.white, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
              tooltip: full ? 'خروج من ملء الشاشة' : 'ملء الشاشة',
              onPressed: withTap(Fullscreen.toggle),
            )),
          ),
        Pressable(child: IconButton(
          icon: const Icon(Icons.settings, size: 24, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
          tooltip: 'الإعدادات',
          onPressed: withTap(() => showSettings(context, client)),
        )),
        Pressable(child: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
          tooltip: 'رجوع',
          onPressed: withTap(() => showDialog(
            context: context,
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white, width: 2)),
                title: const Text('تطلع من اللعبة؟', style: TextStyle(fontSize: 30)),
                content: const Text('مقعدك يبقى محجوز وتقدر ترجع بنفس الكود.', style: TextStyle(fontSize: 21)),
                actions: [
                  Pressable(child: TextButton(onPressed: withTap(() => Navigator.pop(context)), child: const Text('لا', style: TextStyle(color: Colors.white, fontSize: 22)))),
                  Pressable(child: TextButton(onPressed: withTap(() { Navigator.pop(context); client.leave(); }), child: const Text('اطلع', style: TextStyle(color: Colors.white, fontSize: 22)))),
                ],
              ),
  )          ),
          )),
        ),
      ]);
}

class _Seat extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  final int seat;
  final ValueNotifier<int?> seconds;
  final bool me;
  final double size;
  final bool nameLeft;
  final String? voice; // الصوت الشغّال للشخصية
  final Offset toward; // اتجاه الطاولة (لعلامة طاف والإشارات)
  final bool showSeconds; // الرقم تحت الشخصية (الحلقة تبقى دايماً)
  const _Seat({required this.client, required this.view, required this.seat, required this.seconds, required this.size, this.me = false, this.nameLeft = false, this.voice, this.toward = Offset.zero, this.showSeconds = true});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final phase = v['phase'] as String;
    final isTurn = ((phase == 'bidding' || phase == 'playing') && v['turn'] == seat) || (phase == 'trump' && v['buyer'] == seat);
    final isBuyer = v['buyer'] == seat && phase != 'bidding';
    final isKhabis = v['khabis'] == seat;
    final teamColor = KoutColors.team(seat % 2);
    final bids = (v['bids'] as List).where((b) => b['seat'] == seat).toList();
    final passed = phase == 'bidding' && bids.isNotEmpty && bids.last['bid'] == 'pass';
    final sig = client.signals[seat];
    final info = client.seatInfo(seat);
    final isBot = info?['bot'] == true;
    final offline = info != null && info['connected'] != true;
    final left = isTurn ? client.secondsLeft : null;
    final total = phase == 'trump' ? _trumpSeconds : _turnSeconds;

    final avatar = SizedBox.square(dimension: size + 10, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (left != null)
        SizedBox(width: size + 10, height: size + 10, child: _TurnRing(client: client, total: total)),
      Container(
        decoration: isTurn ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: teamColor.withValues(alpha: 0.8), blurRadius: 14)]) : null,
        child: CharacterAvatar(charId: info?['char'] as String?, size: size, ring: teamColor, background: teamColor, voice: voice),
      ),
      if (isBot)
        Positioned(
          bottom: -2,
          left: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: const Color(0xFF111111), shape: BoxShape.circle, border: Border.all(color: Colors.white)),
            child: const Icon(Icons.smart_toy, size: 13, color: Colors.white),
          ),
        ),
      if (isBuyer)
        Positioned(
          // اللي فوق لاصق بحافة الشاشة: النجمة تحت يمين
          top: nameLeft ? null : -12,
          bottom: nameLeft ? -6 : null,
          right: -10,
          child: const Icon(Icons.star, size: 28, color: KoutColors.gold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
        ),
      if (offline) const Positioned(top: -4, left: -4, child: Icon(Icons.wifi_off, size: 14, color: KoutColors.lose)),
      // طاف: علامة كف رمادية جنب الشخصية من جهة الطاولة
      if (passed) Transform.translate(offset: toward * (size * 0.5 + 14), child: _PassSign(size: size * 0.46)),
      // المزايدة: رقمها بدائرة بنفس مكان وطريقة كف «طاف»
      if (phase == 'bidding' && bids.isNotEmpty && !passed)
        Transform.translate(offset: toward * (size * 0.5 + 14), child: _BidSign(key: ValueKey('bid-${bids.last['bid']}'), bid: bids.last['bid'] as Object, size: size * 0.46)),
      // الإشارات: تظهر كلها مع بعض جنب الشخصية من جهة وسط الطاولة
      if (sig != null)
        Transform.translate(
          // البعد على قد عرض الإشارة، عشان ما تغطي الشخصية
          offset: toward * (size * 0.5 + 10 + (16 + sig.suits.length * 25) / 2 * toward.dx.abs() + 17 * toward.dy.abs()),
          child: OverflowBox(
            maxWidth: 200,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(sig.at),
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 180),
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: teamColor, width: 2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in sig.suits)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: s == 'J' ? const GoldJ(size: 22) : SuitIcon(s, size: 20)),
                ]),
              ),
            ),
          ),
        ),
    ]));

    // كل الكتابة تحت الشخصية بحد أسود متصل
    final tags = <Widget>[
      if (isBuyer && v['madmoon'] == true) const OutlinedText('مضمون', size: 13, color: KoutColors.madmoon),
      if (isBuyer && v['majbur'] == true) const OutlinedText('مجبور', size: 13, color: KoutColors.majbur),
      if (isKhabis && phase == 'bidding') const OutlinedText('الموزع', size: 11, color: Color(0xFFDDDDDD)),
      if (left != null && showSeconds)
        ValueListenableBuilder(
          valueListenable: seconds,
          builder: (_, s, _) {
            final n = s ?? left.ceil();
            return OutlinedText('$n', size: 13, color: n <= 3 ? const Color(0xFFFF5A5A) : Colors.white);
          },
        ),
    ];

    // الاسم بلون فريقه
    final name = OutlinedText(me ? 'أنت' : client.seatName(seat), size: 14, color: teamColor);
    if (nameLeft) {
      // اللي فوق: الاسم على يسار الشخصية
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              name,
              Wrap(spacing: 6, children: tags),
            ]),
          ),
          const SizedBox(width: 4),
          avatar,
        ]),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      avatar,
      const SizedBox(height: 2),
      name,
      Wrap(spacing: 6, alignment: WrapAlignment.center, children: tags),
    ]);
  }
}

/// علامة المزايدة: دائرة فيها رقم المزايدة (6 مجبور برتقالي، و9 ذهبي)، تطلع مثل علامة طاف
class _BidSign extends StatelessWidget {
  final Object bid;
  final double size;
  const _BidSign({super.key, required this.bid, required this.size});

  @override
  Widget build(BuildContext context) {
    final majbur = bid == 'majbur';
    final nine = bid == 9;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 180),
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: majbur ? const Color(0xFFB86400) : (nine ? KoutColors.gold : const Color(0xFF111111)),
          border: Border.all(color: Colors.white, width: max(1.5, size * 0.07)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(majbur ? '6' : '$bid', textScaler: TextScaler.noScaling, style: TextStyle(fontSize: size * 0.62, height: 1, fontWeight: FontWeight.w700, color: nine ? Colors.black : Colors.white)),
      ),
    );
  }
}

/// علامة طاف: دائرة رمادية بكف أبيض (مثل اللي يلوّح بيده: ما أبي)
class _PassSign extends StatelessWidget {
  final double size;
  const _PassSign({required this.size});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 180),
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF5E636B),
            border: Border.all(color: Colors.white, width: max(1.5, size * 0.07)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(Icons.front_hand, size: size * 0.6, color: Colors.white),
        ),
      );
}

/// اسم المزايدة اللي يشوفه اللاعب
String bidName(Object b) => switch (b) { 'pass' => 'طاف', 'majbur' => '6 مجبور', _ => '$b' };

class _BidPanel extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  final ValueNotifier<int?> seconds;
  const _BidPanel({required this.client, required this.view, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final legal = view['legalBids'] as List;
    final left = client.secondsLeft;
    final pass = legal.contains('majbur') ? 'majbur' : 'pass';
    Widget button(Object b) {
      final ok = legal.contains(b);
      return _ChromeButton(
        onTap: ok ? () => client.bid(b) : null,
        color: b == 'majbur' ? const Color(0xFFB86400) : null,
        padding: EdgeInsets.symmetric(horizontal: b is int ? 16 : 12, vertical: 9),
        child: Text(bidName(b), style: TextStyle(fontSize: 20, color: b == 9 ? const Color(0xFFFFD65A) : Colors.white)),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('كم تروح؟', style: TextStyle(fontSize: 22, color: KoutColors.ink)),
        if (left != null) _Countdown(seconds: seconds),
      ]),
      if (legal.contains('majbur'))
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('محد زايد: «6 مجبور» إذا خسرت ياخذ الخصم 6 بس، وبدون باون',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF2B2E33))),
        ),
      const SizedBox(height: 12),
      // من اليسار: 9، 8، 7، 6، طاف (بسطر واحد، يصغر إذا الشاشة ضيقة)
      FittedBox(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final b in [9, 8, 7, 6, pass]) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: button(b)),
          ]),
        ),
      ),
    ]);
  }
}

/// حديدة الدور: بالباون هو اللي جاب الباون أو اللي قلبه (أخذ لمّة من فريق الباون)،
/// وإلا أكثر لاعب جاب نقاط وهو شاري (التعادل: اللي وصل أكثر جولات، وبعدها اللي آخر وحدة له أحدث)
({int seat, int points, String? bawan})? _bestPlayer(List<Map> history) {
  final points = <int, int>{}, made = <int, int>{}, last = <int, int>{};
  int? bawan, breaker;
  for (var i = 0; i < history.length; i++) {
    final r = history[i];
    final buyer = r['buyer'];
    if (buyer is! int) continue;
    if (r['type'] == 'bawanWin') bawan = buyer;
    if (r['type'] == 'bawanFail' && r['breaker'] is int) breaker = r['breaker'] as int;
    if (r['type'] == 'made') {
      points[buyer] = (points[buyer] ?? 0) + ((r['points'] as num?)?.toInt() ?? 0);
      made[buyer] = (made[buyer] ?? 0) + 1;
      last[buyer] = i;
    }
  }
  if (bawan != null) return (seat: bawan, points: points[bawan] ?? 0, bawan: 'جاب باون');
  if (breaker != null) return (seat: breaker, points: points[breaker] ?? 0, bawan: 'قلب الباون');
  if (points.isEmpty) return null;
  final seat = points.keys.reduce((a, b) {
    final c = points[a]!.compareTo(points[b]!);
    if (c != 0) return c > 0 ? a : b;
    final m = made[a]!.compareTo(made[b]!);
    if (m != 0) return m > 0 ? a : b;
    return last[a]! > last[b]! ? a : b;
  });
  return (seat: seat, points: points[seat]!, bawan: null);
}

class _RoundResult extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  const _RoundResult({required this.client, required this.view});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final r = v['lastRound'] as Map<String, dynamic>;
    final myTeam = v['team'] as int;
    final buyerName = client.seatName(r['buyer'] as int);
    final offender = r['offender'] is int ? client.seatName(r['offender'] as int) : '';
    final text = _roundLine(client, r);
    final pts = r['points'];
    final team = r['team'] as int;
    final ended = v['phase'] == 'matchEnd';
    final scores = (v['scores'] as List).cast<int>();
    final winner = v['winner'] as int?;

    if (ended && winner != null) {
      final reason = switch (v['winReason']) {
        'score' => 'وصل ${scores[winner]} نقطة',
        'bawanWin' => 'باون: $buyerName جاب كل اللمّات',
        'bawanFail' => 'انقلب الباون',
        'blueEarly' => '$offender رمى الجوكر الكبير قبل الصغير',
        'blueStuck' => '$offender خيّس الجوكر الكبير',
        _ => '',
      };
      final reasonColor = v['winReason'] == 'bawanFail' ? KoutColors.lose : Colors.white;
      final color = KoutColors.team(winner);
      final history = ((v['history'] as List?) ?? const []).cast<Map>();
      final best = _bestPlayer(history);
      final bestInfo = best == null ? null : client.seatInfo(best.seat);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        // حديدة الدور: أفضل لاعب بالمباراة (اللي جاب باون، وإلا أكثر واحد جاب نقاط وهو شاري)
        if (best != null) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            CharacterAvatar(charId: bestInfo?['char'] as String?, size: 46, ring: KoutColors.gold, background: KoutColors.team(best.seat % 2)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('حديدة الدور', style: TextStyle(fontSize: 14, color: KoutColors.gold)),
              Text(client.seatName(best.seat), style: const TextStyle(fontSize: 20)),
              Text(best.bawan ?? 'جاب ${best.points} نقطة', style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
            ]),
          ]),
          const SizedBox(height: 10),
        ],
        Text('فاز الفريق ${KoutColors.teamName(winner)}', style: TextStyle(fontSize: 26, color: color)),
        Text(winner == myTeam ? 'مبروك! فريقك فاز' : 'هاردلك، فريقك خسر', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        FittedBox(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${scores[0]}', style: const TextStyle(fontSize: 34, color: KoutColors.teamBlue)),
            const Text('  –  ', style: TextStyle(fontSize: 26)),
            Text('${scores[1]}', style: const TextStyle(fontSize: 34, color: KoutColors.teamYellow)),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('سبب الفوز', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
        Text(reason, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: reasonColor)),
        // نشرة الجولات مختصرة: سطر لكل جولة
        if (history.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150, maxWidth: 300),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final r in history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(children: [
                      SizedBox(width: 24, child: Text('${r['round']}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))),
                      Expanded(child: Text(_roundLine(client, r, report: true), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      if (r['points'] is int && r['team'] is int)
                        Text('+${r['points']}', style: TextStyle(fontSize: 13, color: KoutColors.team(r['team'] as int))),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (client.isHost)
          Pressable(child: FilledButton(onPressed: withTap(client.rematch), child: const Text('مباراة جديدة', style: TextStyle(fontSize: 17))))
        else
          const Text('بانتظار المضيف...', style: TextStyle(color: Color(0xFFAAAAAA))),
      ]);
    }

    final good = r['type'] == 'made';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(good ? Icons.check_circle : Icons.cancel, size: 40, color: good ? KoutColors.win : KoutColors.lose),
      const SizedBox(height: 6),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      if (pts != null) Text('+$pts للفريق ${KoutColors.teamName(team)}', style: TextStyle(fontSize: 20, color: KoutColors.team(team))),
      const SizedBox(height: 8),
      const Text('الجولة الجاية تبدأ بعد شوي...', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
    ]);
  }
}

/// تأثير يغطي الشاشة: أخضر (جابها)، أحمر (ما جابها)، ذهبي مع كلمة باون.
class _Effect extends StatelessWidget {
  final String kind;
  const _Effect({required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) { 'win' => KoutColors.win, 'bawan' => KoutColors.gold, _ => KoutColors.lose };
    final word = switch (kind) { 'win' => 'وصول', 'bawan' => 'باون', 'bawanFail' => 'انقلب الباون', _ => 'خسارة' };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: kind == 'bawan' ? 3400 : 2100),
      builder: (_, t, _) {
        final fade = t < 0.15 ? t / 0.15 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
        final pop = Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
        final a = fade.clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [color.withValues(alpha: 0.05 * a), color.withValues(alpha: (kind == 'bawan' ? 0.7 : 0.45) * a)], radius: 0.9),
          ),
          alignment: Alignment.center,
          child: Stack(alignment: Alignment.center, children: [
            if (kind == 'bawan')
              for (var i = 0; i < 24; i++)
                Align(
                  alignment: Alignment(sin(i * 1.7) * t * 1.2, -1 + ((i * 0.37 + t * 1.6) % 2.2)),
                  child: Icon(Icons.star, color: KoutColors.gold.withValues(alpha: 0.9 * a), size: 14 + (i % 4) * 6.0),
                ),
            // وصول أخضر وخسارة أحمر، أكبر، وبحد أسود
            Opacity(
              opacity: a,
              child: Transform.scale(
                scale: 0.3 + 0.7 * pop,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: OutlinedText(
                      word,
                      size: switch (kind) { 'bawan' => 120, 'bawanFail' => 72, _ => 100 },
                      color: switch (kind) { 'bawan' => KoutColors.gold, 'win' => const Color(0xFF3FD067), _ => const Color(0xFFFF3B3B) },
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// الإشارات: الضغط على النوع (أو الجوكر إذا عندك) يرسله على طول، ويظهر للكل فوراً.
/// بدون نافذة: كل رمز بمربع كروم صغير شفاف شوي.
class _SignalBar extends StatefulWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  final bool row; // بالعرضي صف، وبالطولي مربع
  const _SignalBar({required this.client, required this.view, this.row = false});

  @override
  State<_SignalBar> createState() => _SignalBarState();
}

class _SignalBarState extends State<_SignalBar> {
  final Set<String> _sent = {}; // اللي انرسل بهالدور

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final can = v['canSignal'] == true;
    final jokerOk = v['canSignalJoker'] == true;
    if (!can && _sent.isNotEmpty) _sent.clear();
    final options = [...suitOrder, if (v['hasJoker'] == true) 'J'];

    Widget chip(String s) {
      final on = _sent.contains(s);
      final enabled = can && !on && (s != 'J' || jokerOk);
      final a = enabled || on ? 1.0 : 0.4;
      return Pressable(child: GestureDetector(
        onTap: enabled
            ? () {
                Sfx.tap();
                widget.client.signal([s]);
                setState(() => _sent.add(s));
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(3),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: KoutColors.chrome(0.85 * a),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: (on ? KoutColors.gold : KoutColors.chromeEdge).withValues(alpha: a), width: on ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.38 * a), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: s == 'J' ? GoldJ(size: 30, opacity: a) : SuitIcon(s, size: 28, color: suitColor(s).withValues(alpha: a)),
        ),
      ));
    }

    // بالعرضي: الأنواع صف، والجوكر فوقهم بالنص
    if (widget.row) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (options.contains('J')) chip('J'),
          Row(mainAxisSize: MainAxisSize.min, children: [for (final s in suitOrder) chip(s)]),
        ]),
      );
    }
    // بالطولي مربع: فوق هاس وسبيت، تحت كلفس وديمن (الألوان متقابلة)، والجوكر فوقهم بالنص
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (options.contains('J')) chip('J'),
        Row(mainAxisSize: MainAxisSize.min, children: [chip('H'), chip('S')]),
        Row(mainAxisSize: MainAxisSize.min, children: [chip('C'), chip('D')]),
      ]),
    );
  }
}
