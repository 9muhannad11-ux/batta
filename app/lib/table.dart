import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'main.dart' show showErrors;
import 'net.dart';
import 'sounds.dart';

const _turnSeconds = 12.5;
const _trumpSeconds = 10.0;

/// أماكن اللاعبين بالطولي: نقاط على رسمة المجلس (380×700، tools/majlis-art/majlis.html)، أنا أول واحد.
/// اللعب عكس عقارب الساعة: اللي على يميني يلعب بعدي.
const _bgW = 380.0, _bgH = 700.0;
const _bgCenter = Offset(190, 460);
const _bgSeats6 = [Offset(190, 600), Offset(340, 520), Offset(334, 372), Offset(190, 300), Offset(46, 360), Offset(40, 520)];
const _bgSeats4 = [Offset(190, 600), Offset(345, 450), Offset(190, 300), Offset(35, 450)];
// بالعرضي: زوايا حول الطاولة (270 = فوق)، والجنبين متباعدين أكثر
const _angles6 = [90.0, 40.0, 318.0, 270.0, 222.0, 140.0];
const _angles4 = [90.0, 0.0, 270.0, 180.0];
// ميلان خفيف لكل ورقة منزولة
const _tilt6 = [3.0, -7.0, -5.0, -6.0, 7.0, 5.0];
const _tilt4 = [3.0, -6.0, -6.0, 6.0];

/// مقاسات الطاولة لهالشاشة: أماكن اللاعبين، والوسط، ومقاس الأوراق.
class _Board {
  final Size size;
  final bool landscape;
  final double handTop, handW, cardW, avatar;
  final Offset center;
  final List<Offset> seats; // حسب الترتيب بالنسبة لي (0 = أنا)
  final Rect? bgRect; // مكان رسمة المجلس بالطولي
  final List<double> tilts;

  _Board._(this.size, this.landscape, this.handTop, this.handW, this.cardW, this.avatar, this.center, this.seats, this.bgRect, this.tilts);

  factory _Board(Size size, int players) {
    final w = size.width, h = size.height;
    final landscape = w > h;
    final tilts = players == 4 ? _tilt4 : _tilt6;
    if (landscape) {
      final handW = min(88.0, min(h * 0.17, w / 10));
      final handTop = h - (handW * cardRatio + 14);
      final center = Offset(w / 2, handTop / 2 + 8);
      final rx = w / 2 - 78, ry = handTop / 2 - 44;
      final seats = [
        for (final a in players == 4 ? _angles4 : _angles6)
          center + Offset(cos(a * pi / 180) * rx, sin(a * pi / 180) * ry),
      ];
      return _Board._(size, true, handTop, handW, min(54.0, h * 0.13), min(48.0, h * 0.11), center, seats, null, tilts);
    }
    final handW = min(88.0, w / 4.6);
    final handTop = h - (handW * cardRatio + 40);
    // المجلس يتمدد لين يملأ المساحة فوق اليد، وتحته شوي يدخل ورا اليد
    final bottom = handTop + 40;
    final s = min(w / _bgW, bottom / _bgH);
    final bg = Rect.fromLTWH((w - _bgW * s) / 2, bottom - _bgH * s, _bgW * s, _bgH * s);
    Offset p(Offset o) => bg.topLeft + o * s;
    return _Board._(size, false, handTop, handW, (60 * s).clamp(40.0, 72.0), (46 * s).clamp(36.0, 60.0), p(_bgCenter),
        [for (final o in players == 4 ? _bgSeats4 : _bgSeats6) p(o)], bg, tilts);
  }

  /// مكان الورقة المنزولة: بنص المسافة بين وسط الطاولة وصاحبها
  Offset slot(int rel) => center + (seats[rel] - center) * 0.5;
  double get cardH => cardW * cardRatio;
}

class TableScreen extends StatefulWidget {
  final GameClient client;
  const TableScreen({super.key, required this.client});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with TickerProviderStateMixin {
  // لمّ اللمّة: آخر ورقة توصل، وبعدها الكل ينسحب لصاحبها
  late final AnimationController _collect = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _deal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  // كف الجوكر الكبير: ينزل 170ms ويضرب، وبعدها يرتفع ويختفي
  late final AnimationController _slap = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  Map<String, dynamic>? _collecting;
  bool _collectSound = false;
  int? _slapRel;

  int _seenRound = 0;
  int _seenTrickNo = 0;
  int _seenTrickLen = 0;
  bool _goldOn = false;
  int _resultShownRound = 0;
  String? _effect; // win, lose, bawan
  Timer? _effectTimer;
  Timer? _ticker;
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
      if (!_collectSound && _collect.value > 0.35) {
        _collectSound = true;
        Sfx.collect();
      }
    });
    _collect.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _collecting = null);
    });
    // اليد تبين بآخر التوزيع، ونافذة المزايدة تطلع أول ما يخلص
    _deal.addListener(() {
      if (mounted) setState(() {});
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
    _ticker?.cancel();
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
    if (_myTurn && left != null && left > 0 && left <= 5 && _tickedFor != deadline) {
      _tickedFor = deadline;
      _tickPlaying = true;
      Sfx.tick();
    } else if (_tickPlaying && (!_myTurn || deadline != _tickedFor)) {
      _tickPlaying = false;
      Sfx.stopTick();
    }
    if (left != null) setState(() {});
  }

  void _onChange() {
    final v = c.view;
    if (v == null || !mounted) return;
    final round = v['round'] as int;
    final trickNo = v['trickNo'] as int;
    final trick = (v['trick'] as List).cast<Map<String, dynamic>>();
    final trickLen = trick.length;
    final n = v['players'] as int;

    if (round != _seenRound) {
      final freshDeal = v['phase'] == 'bidding' && (v['bids'] as List).isEmpty;
      _seenRound = round;
      // لو رجعنا للعبة بنص الجولة، ما نعيد أنميشن التوزيع ولا أصوات اللي فات
      _seenTrickNo = freshDeal ? 0 : trickNo;
      _seenTrickLen = freshDeal ? 0 : trickLen;
      _resultShownRound = v['phase'] == 'roundEnd' || v['phase'] == 'matchEnd' ? round : _resultShownRound;
      _selected = null;
      _dragCard = null;
      _collecting = null;
      _releasedAt.clear();
      c.slapPending.clear();
      if (freshDeal) {
        if (round == 1) Sfx.start(); // بداية المباراة
        _deal.forward(from: 0);
        Sfx.deal();
      }
    }

    // صوت الورقة اللي نزلت: جوكر، أو كف الجوكر الكبير، أو ورقة عادية
    void landed(Map<String, dynamic> t) {
      final seat = t['seat'] as int;
      if (c.slapPending.remove(seat)) {
        _slapRel = _rel(seat, n);
        _slap.forward(from: 0);
        _shake.value = 0;
        // قمة الضربة بالصوت (90ms) توافق لحظة لمس الكف (170ms)
        Future.delayed(const Duration(milliseconds: 80), Sfx.signalBig);
      } else if (isJokerCard(t['card'] as String)) {
        Sfx.joker();
      } else {
        Sfx.play();
      }
    }

    if (trickNo > _seenTrickNo && v['lastTrick'] != null) {
      _seenTrickNo = trickNo;
      _collecting = v['lastTrick'] as Map<String, dynamic>;
      _collectSound = false;
      landed((_collecting!['cards'] as List).cast<Map<String, dynamic>>().last);
      _collect.forward(from: 0);
    } else if (trickLen > _seenTrickLen) {
      landed(trick.last);
    }
    _seenTrickLen = trickLen;

    // باون أو 9: الطاولة ذهبية ونبض قلب يتكرر لين تخلص الجولة
    final phase = v['phase'];
    final gold = _bawanActive(v) && phase != 'roundEnd' && phase != 'matchEnd';
    if (gold != _goldOn) {
      _goldOn = gold;
      gold ? Sfx.gold() : Sfx.stopGold();
    }

    // نتيجة الجولة: أخضر إذا جابها الشاري، أحمر إذا ما جابها، وذهبي للباون
    if ((phase == 'roundEnd' || phase == 'matchEnd') && v['lastRound'] != null && round != _resultShownRound) {
      _resultShownRound = round;
      final type = (v['lastRound'] as Map)['type'];
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

    final legal = (v['legalCards'] as List).cast<String>();
    if (_selected != null && !legal.contains(_selected)) _selected = null;
    setState(() {});
  }

  bool _bawanActive(Map v) => v['bawan'] == true || (v['currentBid'] == 9 && v['phase'] != 'bidding');

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
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // ورا كل شي: المجلس مكبّر وغامق يعبّي الأطراف
        Positioned.fill(
          child: Image.asset('assets/images/majlis.png',
              fit: BoxFit.cover, alignment: const Alignment(0, 0.3), color: Colors.black.withValues(alpha: 0.35), colorBlendMode: BlendMode.darken),
        ),
        SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final b = _Board(box.biggest, n);
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
                  if (b.bgRect != null)
                    Positioned.fromRect(rect: b.bgRect!, child: Image.asset('assets/images/majlis.png', fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
                  if (_bawanActive(v)) Positioned.fill(child: IgnorePointer(child: _GoldGlow(center: b.center, radius: b.size.shortestSide * 0.5))),
                  _centerInfo(v, b),
                  ..._trickLayer(v, b, n),
                  for (var seat = 0; seat < n; seat++) _seatAt(b, _rel(seat, n), _Seat(client: c, view: v, seat: seat, me: seat == c.mySeat, size: b.avatar)),
                  _dealLayer(b, n),
                  if (_dragOver) _dropTarget(b),
                  ..._handLayer(v, b),
                  _signalRow(v, b),
                  _slapLayer(b),
                  Positioned(top: 6, left: 8, child: _Scores(view: v)),
                  Positioned(top: 2, right: 2, child: _TopActions(client: c)),
                  Positioned.fromRect(rect: Rect.fromLTWH(0, 0, b.size.width, b.handTop), child: _overlay(v)),
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
    const w = 110.0;
    final p = b.seats[rel];
    return Positioned(left: p.dx - w / 2, top: p.dy - (b.avatar + 10) / 2, width: w, child: child);
  }

  Widget _cardAt(Offset p, double w, Widget child) => Positioned(left: p.dx - w / 2, top: p.dy - w * cardRatio / 2, child: child);

  // معلومات الجولة بوسط الطاولة: الحكم وعدد المزايدة واسم المزايد
  Widget _centerInfo(Map<String, dynamic> v, _Board b) {
    final trump = v['trump'] as String?;
    final buyer = v['buyer'] as int?;
    if (trump == null || buyer == null) return const SizedBox.shrink();
    final bawan = _bawanActive(v);
    return Positioned(
      left: b.center.dx - 60,
      top: b.center.dy - 26,
      width: 120,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                SuitIcon(trump, size: 24, color: isRedSuit(trump) ? const Color(0xFFFF4D4D) : Colors.white),
                const SizedBox(width: 6),
                Text(bawan ? 'باون' : '${v['currentBid']}',
                    style: TextStyle(fontSize: 22, color: bawan ? KoutColors.gold : Colors.white, height: 1.1)),
              ]),
              Text(c.seatName(buyer), style: TextStyle(fontSize: 12, color: KoutColors.team(buyer % 2), height: 1.1)),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _trickLayer(Map<String, dynamic> v, _Board b, int n) {
    final w = b.cardW;
    final current = (v['trick'] as List).cast<Map<String, dynamic>>();
    final out = <Widget>[];

    // اللمّة اللي قاعدة تنلم: آخر ورقة توصل، وبعدها كلها تروح للفائز
    final last = _collecting;
    if (last != null) {
      final cards = (last['cards'] as List).cast<Map<String, dynamic>>();
      final winner = last['winner'] as int;
      final winPos = b.seats[_rel(winner, n)];
      out.add(Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _collect,
            builder: (_, _) {
              final t = _collect.value;
              final arrive = Curves.easeOut.transform((t / 0.2).clamp(0.0, 1.0));
              final pull = Curves.easeIn.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));
              return Stack(clipBehavior: Clip.none, children: [
                for (final card in cards)
                  Builder(builder: (_) {
                    final rel = _rel(card['seat'] as int, n);
                    final slot = b.slot(rel);
                    var pos = identical(card, cards.last) ? Offset.lerp(_fromFor(card['card'] as String, b, rel), slot, arrive)! : slot;
                    pos = Offset.lerp(pos, winPos, pull)!;
                    return _cardAt(
                      pos,
                      w,
                      Opacity(
                        opacity: 1 - 0.7 * pull,
                        child: Transform.rotate(
                          angle: b.tilts[rel] * pi / 180 * (1 - pull),
                          child: Transform.scale(scale: 1 - 0.45 * pull, child: PlayingCard(card['card'] as String, width: w)),
                        ),
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

  // أنميشن التوزيع: أوراق تطير من وسط الطاولة لكل لاعب
  Widget _dealLayer(_Board b, int n) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _deal,
          builder: (_, _) {
            if (!_deal.isAnimating) return const SizedBox.shrink();
            final t = _deal.value;
            final w = b.cardW * 0.6;
            return Stack(clipBehavior: Clip.none, children: [
              for (var k = 0; k < 3; k++)
                for (var i = 0; i < n; i++)
                  Builder(builder: (_) {
                    final start = (k * n + i) * (0.75 / (3 * n));
                    final p = ((t - start) / 0.25).clamp(0.0, 1.0);
                    if (p <= 0 || p >= 1) return const SizedBox.shrink();
                    return _cardAt(
                      Offset.lerp(b.center, b.seats[i], Curves.easeOut.transform(p))!,
                      w,
                      Transform.rotate(angle: p * pi, child: CardBack(width: w)),
                    );
                  }),
            ]);
          },
        ),
      ),
    );
  }

  // مربع ذهبي منقّط بنص الطاولة: إذا تركت الورقة هنا تنرمى
  Widget _dropTarget(_Board b) {
    final w = b.cardW * 1.3;
    return Positioned(
      left: b.center.dx - w / 2,
      top: b.center.dy - w * cardRatio / 2,
      child: IgnorePointer(child: CustomPaint(size: Size(w, w * cardRatio), painter: _DashedBox())),
    );
  }

  List<Widget> _handLayer(Map<String, dynamic> v, _Board b) {
    final hand = (v['hand'] as List).cast<String>();
    final legal = _legal.toSet();
    final myTurn = legal.isNotEmpty && _deal.isAnimating == false;
    final w = b.handW;
    final W = b.size.width;
    final n = max(hand.length, 1);
    // بالعرضي نخلي مكان لعمود الإشارات على اليمين
    final step = n == 1 ? 0.0 : min(w + 4, (W - (b.landscape ? 110 : 16) - w) / (n - 1));
    final total = w + step * (n - 1);
    final out = <Widget>[];
    final dealFade = _deal.isAnimating ? ((_deal.value - 0.6) / 0.4).clamp(0.0, 1.0) : 1.0;
    for (var i = 0; i < hand.length; i++) {
      final card = hand[i];
      final ok = legal.contains(card);
      final sel = card == _selected;
      // اليد من اليسار لليمين (هاس، كلفس، ديمن، سبيت، ثم الجوكرين)
      final left = (W - total) / 2 + i * step;
      final top = b.handTop + (b.landscape ? (sel ? -14 : (myTurn && ok ? 4 : 12)) : (sel ? -8 : (myTurn && ok ? 18 : 28)));
      Widget face = PlayingCard(card, width: w, highlight: sel, enabled: !myTurn || ok);
      if (_selected != null && !sel) face = Opacity(opacity: 0.6, child: face); // الباقي يخفت
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
        child: Opacity(
          // الورقة اللي تنسحب تبقى بمكانها مخفية (عشان السحب ما ينقطع)، ونسخة منها تلحق الإصبع
          opacity: card == _dragCard ? 0 : dealFade,
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

  // الإشارات: بدون نافذة، صف رموز صغير فوق اليد (بالعرضي عمود يمين تحت جنب اليد)
  Widget _signalRow(Map<String, dynamic> v, _Board b) {
    if (b.landscape) return Positioned(right: 6, bottom: 6, child: _SignalBar(client: c, view: v, vertical: true));
    return Positioned(left: 0, right: 0, bottom: b.size.height - b.handTop + 2, child: Center(child: _SignalBar(client: c, view: v)));
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
      return _ChromePanel(child: _BidPanel(client: c, view: v));
    }
    if (phase == 'trump') {
      final left = c.secondsLeft;
      return _ChromePanel(
        child: buyer == me
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('حكمك؟', style: TextStyle(fontSize: 22, color: KoutColors.ink)),
                  if (left != null) _Countdown(left: left, total: _trumpSeconds),
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
    if (phase == 'roundEnd' || phase == 'matchEnd') return _Panel(child: _RoundResult(client: c, view: v));
    return const SizedBox.shrink();
  }
}

/// توهج ذهبي على الطاولة وقت الباون أو 9
class _GoldGlow extends StatelessWidget {
  final Offset center;
  final double radius;
  const _GoldGlow({required this.center, required this.radius});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, t, _) => CustomPaint(
          painter: _GlowPainter(center, radius, t),
        ),
      );
}

class _GlowPainter extends CustomPainter {
  final Offset center;
  final double radius, t;
  _GlowPainter(this.center, this.radius, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center,
      radius * 1.3,
      Paint()
        ..shader = RadialGradient(colors: [
          KoutColors.gold.withValues(alpha: 0.38 * t),
          KoutColors.gold.withValues(alpha: 0.12 * t),
          KoutColors.gold.withValues(alpha: 0),
        ], stops: const [0, 0.6, 1]).createShader(Rect.fromCircle(center: center, radius: radius * 1.3)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t || old.center != center;
}

class _DashedBox extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.08));
    canvas.drawRRect(r, Paint()..color = KoutColors.gold.withValues(alpha: 0.18));
    final paint = Paint()
      ..color = KoutColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, min(d + 6, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => false;
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

/// نافذة كروم شفافة شوي (~82%) بإطار رصاصي غامق وخط لمعة فوق: المزايدة والحكم والباون
class _ChromePanel extends StatelessWidget {
  final Widget child;
  const _ChromePanel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
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
      child: GestureDetector(
        onTap: onTap,
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
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final double left;
  final double total;
  const _Countdown({required this.left, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.access_time, size: 18, color: left <= 3 ? KoutColors.lose : KoutColors.ink),
          Text(' ${left.ceil()}', style: TextStyle(fontSize: 18, color: left <= 3 ? KoutColors.lose : KoutColors.ink)),
        ]),
      );
}

/// النتائج والكلام الثاني: لوحة غامقة
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
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

/// النتيجة فوق يسار، كل فريق بلونه.
class _Scores extends StatelessWidget {
  final Map<String, dynamic> view;
  const _Scores({required this.view});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final myTeam = v['team'] as int;
    final scores = (v['scores'] as List).cast<int>();
    final tricks = (v['tricksWon'] as List).cast<int>();
    final playing = v['trump'] != null;

    Widget pill(int t) {
      final color = KoutColors.team(t);
      final dark = t == 0 ? const Color(0xFF2F6FD6) : const Color(0xFF9C7700);
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: t == myTeam ? 2.5 : 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t == myTeam ? 'فريقك' : 'الخصم', style: TextStyle(fontSize: 10, color: dark, height: 1.2)),
          Text('${scores[t]}', style: TextStyle(fontSize: 22, color: dark, height: 1.1)),
          if (playing) Text('لمّات ${tricks[t]}', style: const TextStyle(fontSize: 10, color: Color(0xFF555555), height: 1.2)),
        ]),
      );
    }

    return Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: [pill(myTeam), pill(1 - myTeam)]));
  }
}

class _TopActions extends StatelessWidget {
  final GameClient client;
  const _TopActions({required this.client});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (!client.connected) const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.wifi_off, size: 20, color: KoutColors.lose)),
        IconButton(
          icon: const Icon(Icons.logout, size: 22, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
          tooltip: 'اطلع',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white, width: 2)),
                title: const Text('تطلع من اللعبة؟'),
                content: const Text('مقعدك يبقى محجوز وتقدر ترجع بنفس الكود.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('لا', style: TextStyle(color: Colors.white))),
                  TextButton(onPressed: () { Navigator.pop(context); client.leave(); }, child: const Text('اطلع', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ),
        ),
      ]);
}

/// كتابة فاتحة بحد غامق (تبين على السجادة)
const _outline = [
  Shadow(color: Color(0xFF2A2A2A), offset: Offset(1.2, 1.2)),
  Shadow(color: Color(0xFF2A2A2A), offset: Offset(-1.2, 1.2)),
  Shadow(color: Color(0xFF2A2A2A), offset: Offset(1.2, -1.2)),
  Shadow(color: Color(0xFF2A2A2A), offset: Offset(-1.2, -1.2)),
];

class _Seat extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  final int seat;
  final bool me;
  final double size;
  const _Seat({required this.client, required this.view, required this.seat, required this.size, this.me = false});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final phase = v['phase'] as String;
    final isTurn = ((phase == 'bidding' || phase == 'playing') && v['turn'] == seat) || (phase == 'trump' && v['buyer'] == seat);
    final isBuyer = v['buyer'] == seat && phase != 'bidding';
    final isKhabis = v['khabis'] == seat;
    final teamColor = KoutColors.team(seat % 2);
    final bids = (v['bids'] as List).where((b) => b['seat'] == seat).toList();
    final bidLabel = bids.isEmpty ? null : bidName(bids.last['bid'] as Object);
    final sig = client.signals[seat];
    final info = client.seatInfo(seat);
    final isBot = info?['bot'] == true;
    final offline = info != null && info['connected'] != true;
    final left = isTurn ? client.secondsLeft : null;
    final total = phase == 'trump' ? _trumpSeconds : _turnSeconds;

    final avatar = SizedBox.square(dimension: size + 10, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (left != null)
        SizedBox(
          width: size + 10,
          height: size + 10,
          child: CircularProgressIndicator(
            value: (left / total).clamp(0.0, 1.0),
            strokeWidth: 4,
            color: left <= 3 ? KoutColors.lose : Colors.white,
            backgroundColor: Colors.black38,
          ),
        ),
      Container(
        decoration: isTurn ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: teamColor.withValues(alpha: 0.8), blurRadius: 14)]) : null,
        child: CharacterAvatar(charId: info?['char'] as String?, size: size, ring: teamColor),
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
        const Positioned(
          top: -12,
          right: -10,
          child: Icon(Icons.star, size: 28, color: KoutColors.gold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
        ),
      if (offline) const Positioned(top: -4, left: -4, child: Icon(Icons.wifi_off, size: 14, color: KoutColors.lose)),
      // الإشارات: تظهر كلها مع بعض فوق اللاعب
      if (sig != null)
        Positioned(
          top: -size * 0.5 - 22,
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
    ]));

    TextStyle tag(Color color, [double size = 12]) => TextStyle(fontSize: size, color: color, shadows: _outline, height: 1.2);
    final tags = <Widget>[
      if (isBuyer && v['madmoon'] == true) Text('مضمون', style: tag(KoutColors.madmoon, 13)),
      if (isBuyer && v['majbur'] == true) Text('مجبور', style: tag(KoutColors.majbur, 13)),
      if (phase == 'bidding' && bidLabel != null) Text(bidLabel, style: tag(bidLabel == 'طاف' ? const Color(0xFFCCCCCC) : Colors.white, 13)),
      if (isKhabis && phase == 'bidding') Text('خابص', style: tag(const Color(0xFFDDDDDD), 11)),
      if (left != null) Text('${left.ceil()}', style: tag(left <= 3 ? const Color(0xFFFF5A5A) : Colors.white, 13)),
    ];

    return Column(mainAxisSize: MainAxisSize.min, children: [
      avatar,
      const SizedBox(height: 2),
      Text(me ? 'أنت' : client.seatName(seat),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFFF2EFE8), shadows: _outline, height: 1.2)),
      Wrap(spacing: 6, alignment: WrapAlignment.center, children: tags),
    ]);
  }
}

/// اسم المزايدة اللي يشوفه اللاعب
String bidName(Object b) => switch (b) { 'pass' => 'طاف', 'majbur' => '6 مجبور', _ => '$b' };

class _BidPanel extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  const _BidPanel({required this.client, required this.view});

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
        if (left != null) _Countdown(left: left, total: _turnSeconds),
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
    final majbur = r['majbur'] == true ? ' (مجبور)' : '';
    final text = switch (r['type']) {
      'made' => '$buyerName جاب ${r['bid']}$majbur',
      'failed' => '$buyerName ما جاب ${r['bid']}$majbur',
      'greyPenalty' => '$offender خيّس الجوكر الصغير',
      'bawanWin' => '$buyerName جاب باون: كل اللمّات!',
      'bawanFail' => 'انقلب الباون',
      'blueEarly' => '$offender رمى الجوكر الكبير قبل الصغير',
      _ => '',
    };
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
        _ => '',
      };
      final reasonColor = v['winReason'] == 'bawanFail' ? KoutColors.lose : Colors.white;
      final color = KoutColors.team(winner);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('فاز الفريق ${KoutColors.teamName(winner)}', style: TextStyle(fontSize: 26, color: color)),
        Text(winner == myTeam ? 'مبروك! فريقك فاز' : 'هاردلك، فريقك خسر', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${scores[0]}', style: const TextStyle(fontSize: 34, color: KoutColors.teamBlue)),
          const Text('  –  ', style: TextStyle(fontSize: 26)),
          Text('${scores[1]}', style: const TextStyle(fontSize: 34, color: KoutColors.teamYellow)),
        ]),
        const SizedBox(height: 8),
        const Text('سبب الفوز', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
        Text(reason, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: reasonColor)),
        const SizedBox(height: 14),
        if (client.isHost)
          FilledButton(onPressed: client.rematch, child: const Text('مباراة جديدة', style: TextStyle(fontSize: 17)))
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
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [color.withValues(alpha: 0.05), color.withValues(alpha: kind == 'bawan' ? 0.7 : 0.45)], radius: 0.9),
            ),
            alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              if (kind == 'bawan')
                for (var i = 0; i < 24; i++)
                  Align(
                    alignment: Alignment(sin(i * 1.7) * t * 1.2, -1 + ((i * 0.37 + t * 1.6) % 2.2)),
                    child: Icon(Icons.star, color: KoutColors.gold.withValues(alpha: 0.9), size: 14 + (i % 4) * 6.0),
                  ),
              Transform.scale(
                scale: 0.3 + 0.7 * pop,
                child: Text(
                  word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: kind == 'bawan' ? 120 : 64,
                    color: switch (kind) { 'bawan' => KoutColors.gold, 'bawanFail' => KoutColors.lose, _ => Colors.white },
                    shadows: [Shadow(color: color, blurRadius: 30), const Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ]),
          ),
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
  final bool vertical;
  const _SignalBar({required this.client, required this.view, this.vertical = false});

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
      return Opacity(
        opacity: enabled || on ? 1 : 0.4,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  widget.client.signal([s]);
                  setState(() => _sent.add(s));
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: widget.vertical ? const EdgeInsets.symmetric(vertical: 3) : const EdgeInsets.symmetric(horizontal: 3),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: KoutColors.chrome(0.85),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? KoutColors.gold : KoutColors.chromeEdge, width: on ? 2 : 1),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: s == 'J' ? const GoldJ(size: 20) : SuitIcon(s, size: 18),
          ),
        ),
      );
    }

    final chips = [for (final s in options) chip(s)];
    if (widget.vertical) return Column(mainAxisSize: MainAxisSize.min, children: chips);
    return Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: chips));
  }
}
