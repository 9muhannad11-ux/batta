import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'main.dart' show showErrors;
import 'net.dart';
import 'sounds.dart';

/// مواقع المقاعد على الشاشة نسبةً لي (أنا تحت).
/// اللعب عكس عقارب الساعة: اللي على يميني يلعب بعدي، وهكذا.
const _align6 = [
  Alignment(0, 1), // أنا
  Alignment(0.97, 0.36), // على يميني
  Alignment(0.97, -0.6),
  Alignment(0, -1), // المقابل
  Alignment(-0.97, -0.6),
  Alignment(-0.97, 0.36), // على يساري
];
const _align4 = [
  Alignment(0, 1),
  Alignment(0.97, -0.1),
  Alignment(0, -1),
  Alignment(-0.97, -0.1),
];
List<Alignment> _aligns(int n) => n == 4 ? _align4 : _align6;

const _turnSeconds = 12.5;

class TableScreen extends StatefulWidget {
  final GameClient client;
  const TableScreen({super.key, required this.client});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with TickerProviderStateMixin {
  // لمّ اللمّة: آخر ورقة توصل، أعلى ورقة ترتفع، والباقي ينسحب لصاحبها
  late final AnimationController _collect = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _deal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  Map<String, dynamic>? _collecting;
  bool _collectSound = false;

  int _seenRound = 0;
  int _seenTrickNo = 0;
  int _seenTrickLen = 0;
  bool _goldShown = false;
  int _resultShownRound = 0;
  String? _effect; // win, lose, bawan
  Timer? _effectTimer;
  Timer? _ticker;
  int _lastTick = -1;
  String? _selected;

  GameClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _collect.addListener(() {
      if (!_collectSound && _collect.value > 0.5) {
        _collectSound = true;
        Sfx.collect();
      }
    });
    _collect.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _collecting = null);
    });
    // نافذة المزايدة تطلع أول ما يخلص التوزيع
    _deal.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChange());
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _collect.dispose();
    _deal.dispose();
    _effectTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  bool get _myTurn {
    final v = c.view;
    if (v == null) return false;
    return (v['phase'] == 'bidding' || v['phase'] == 'playing') && v['turn'] == c.mySeat;
  }

  // العداد التنازلي: تكة كل ثانية لما يكون الدور عليك
  void _tick() {
    if (!mounted) return;
    final left = c.secondsLeft;
    if (_myTurn && left != null) {
      final s = left.ceil();
      if (s != _lastTick && s > 0 && s <= _turnSeconds.ceil()) Sfx.tick();
      _lastTick = s;
    } else {
      _lastTick = -1;
    }
    if (left != null) setState(() {});
  }

  void _onChange() {
    final v = c.view;
    if (v == null || !mounted) return;
    final round = v['round'] as int;
    final trickNo = v['trickNo'] as int;
    final trickLen = (v['trick'] as List).length;

    if (round != _seenRound) {
      final freshDeal = v['phase'] == 'bidding' && (v['bids'] as List).isEmpty;
      _seenRound = round;
      // لو رجعنا للعبة بنص الجولة، ما نعيد أنميشن التوزيع ولا أصوات اللي فات
      _seenTrickNo = freshDeal ? 0 : trickNo;
      _seenTrickLen = freshDeal ? 0 : trickLen;
      _goldShown = !freshDeal && _bawanActive(v);
      _resultShownRound = v['phase'] == 'roundEnd' || v['phase'] == 'matchEnd' ? round : _resultShownRound;
      _selected = null;
      _collecting = null;
      if (freshDeal) {
        _deal.forward(from: 0);
        Sfx.deal();
      }
    }

    if (trickNo > _seenTrickNo && v['lastTrick'] != null) {
      _seenTrickNo = trickNo;
      _collecting = v['lastTrick'] as Map<String, dynamic>;
      _collectSound = false;
      Sfx.play();
      _collect.forward(from: 0);
    } else if (trickLen > _seenTrickLen) {
      Sfx.play();
    }
    _seenTrickLen = trickLen;

    // باون: الطاولة تصير ذهبية
    if (_bawanActive(v) && !_goldShown) {
      _goldShown = true;
      Sfx.gold();
    }

    // نتيجة الجولة: أخضر إذا جابها الشاري، أحمر إذا ما جابها، وذهبي للباون
    final phase = v['phase'];
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

  void _tapCard(String card) {
    final v = c.view!;
    final legal = (v['legalCards'] as List).cast<String>();
    if (!legal.contains(card)) return;
    if (_selected != card) {
      setState(() => _selected = card);
      return;
    }
    // بدون تحذير: اللاعب يرمي الجوكر وقت ما يبي، والقانون يطبّق نفسه
    c.play(card);
    setState(() => _selected = null);
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
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _TopBar(client: c, view: v),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final aligns = _aligns(n);
                return Stack(children: [
                  // الطاولة (تصير ذهبية في الباون)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 44),
                      decoration: BoxDecoration(
                        gradient: _bawanActive(v)
                            ? const RadialGradient(colors: [Color(0xFF6B5310), Color(0xFF2E2406)])
                            : const RadialGradient(colors: [Color(0xFF1E1E1E), Color(0xFF121212)]),
                        borderRadius: BorderRadius.circular(box.maxWidth),
                        border: Border.all(color: _bawanActive(v) ? KoutColors.gold : KoutColors.line, width: _bawanActive(v) ? 3 : 1),
                        boxShadow: _bawanActive(v) ? [BoxShadow(color: KoutColors.gold.withValues(alpha: 0.4), blurRadius: 30)] : null,
                      ),
                    ),
                  ),
                  _centerInfo(v),
                  ..._trickLayer(v, box, aligns, n),
                  for (var seat = 0; seat < n; seat++)
                    if (seat != c.mySeat)
                      Align(alignment: aligns[_rel(seat, n)], child: _Seat(client: c, view: v, seat: seat)),
                  Align(alignment: const Alignment(0, 1.02), child: _Seat(client: c, view: v, seat: c.mySeat, me: true)),
                  _dealLayer(aligns, n, box),
                  ..._overlays(v),
                ]);
              }),
            ),
            _SignalBar(client: c, view: v),
            AnimatedBuilder(
              animation: _deal,
              builder: (_, child) => Opacity(opacity: _deal.isAnimating ? ((_deal.value - 0.6) / 0.4).clamp(0.0, 1.0) : 1, child: child),
              child: _Hand(view: v, selected: _selected, onTap: _tapCard),
            ),
          ]),
          if (_effect != null) Positioned.fill(child: IgnorePointer(child: _Effect(kind: _effect!))),
        ]),
      ),
    );
  }

  // معلومات الجولة في وسط الطاولة: الحكم وعدد المزايدة واسم المزايد
  Widget _centerInfo(Map<String, dynamic> v) {
    final trump = v['trump'] as String?;
    final buyer = v['buyer'] as int?;
    if (trump == null || buyer == null) return const SizedBox.shrink();
    final bawan = _bawanActive(v);
    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.9,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SuitIcon(trump, size: 34),
          const SizedBox(height: 2),
          Text(bawan ? 'باون' : '${v['currentBid']}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: bawan ? KoutColors.gold : KoutColors.text, height: 1.1)),
          Text(c.seatName(buyer),
              style: TextStyle(fontSize: 14, color: KoutColors.team(buyer % 2), fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Alignment _slot(Alignment a, int n) => n == 4 ? Alignment(a.x * 0.36, a.y * 0.42) : Alignment(a.x * 0.44, a.y * 0.44);

  List<Widget> _trickLayer(Map<String, dynamic> v, BoxConstraints box, List<Alignment> aligns, int n) {
    final w = min(56.0, box.maxWidth / 7.2);
    final current = (v['trick'] as List).cast<Map<String, dynamic>>();
    final out = <Widget>[];

    // اللمّة اللي قاعدة تنلم
    final last = _collecting;
    if (last != null) {
      final cards = (last['cards'] as List).cast<Map<String, dynamic>>();
      final winner = last['winner'] as int;
      final winAlign = aligns[_rel(winner, n)];
      final ordered = [...cards.where((t) => t['seat'] != winner), ...cards.where((t) => t['seat'] == winner)];
      out.add(AnimatedBuilder(
        animation: _collect,
        builder: (_, _) {
          final t = _collect.value;
          final arrive = Curves.easeOut.transform((t / 0.18).clamp(0.0, 1.0));
          final rise = Curves.easeOut.transform(((t - 0.18) / 0.32).clamp(0.0, 1.0));
          final pull = Curves.easeIn.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));
          return Stack(children: [
            for (final card in ordered)
              Builder(builder: (_) {
                final seat = card['seat'] as int;
                final from = aligns[_rel(seat, n)];
                final slot = _slot(from, n);
                final isLastPlayed = identical(card, cards.last);
                final isWinner = seat == winner;
                var pos = isLastPlayed ? Alignment.lerp(from, slot, arrive)! : slot;
                pos = Alignment.lerp(pos, winAlign, pull)!;
                final scale = (isWinner ? 1 + 0.25 * rise : 1.0) * (1 - 0.45 * pull);
                return Align(
                  alignment: pos,
                  child: Opacity(
                    opacity: 1 - 0.7 * pull,
                    child: Transform.translate(
                      offset: Offset(0, isWinner ? -14 * rise : 0),
                      child: Transform.scale(
                        scale: scale,
                        child: PlayingCard(card['card'] as String, width: w, highlight: isWinner && rise > 0.05),
                      ),
                    ),
                  ),
                );
              }),
          ]);
        },
      ));
    }

    // اللمّة الحالية: كل ورقة تطير من صاحبها لمكانها
    for (final t in current) {
      final seat = t['seat'] as int;
      final from = aligns[_rel(seat, n)];
      out.add(TweenAnimationBuilder<double>(
        key: ValueKey('${v['round']}-${t['card']}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (_, p, child) => Align(
          alignment: Alignment.lerp(from, _slot(from, n), p)!,
          child: Transform.scale(scale: 0.75 + 0.25 * p, child: child),
        ),
        child: PlayingCard(t['card'] as String, width: w),
      ));
    }
    return out;
  }

  // أنميشن التوزيع: أوراق تطير من وسط الطاولة لكل لاعب
  Widget _dealLayer(List<Alignment> aligns, int n, BoxConstraints box) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _deal,
        builder: (_, _) {
          if (!_deal.isAnimating) return const SizedBox.shrink();
          final t = _deal.value;
          final w = min(34.0, box.maxWidth / 12);
          return Stack(children: [
            for (var k = 0; k < 3; k++)
              for (var i = 0; i < n; i++)
                Builder(builder: (_) {
                  final start = (k * n + i) * (0.75 / (3 * n));
                  final p = ((t - start) / 0.25).clamp(0.0, 1.0);
                  if (p <= 0 || p >= 1) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.lerp(Alignment.center, aligns[i], Curves.easeOut.transform(p))!,
                    child: Transform.rotate(angle: p * pi, child: CardBack(width: w)),
                  );
                }),
          ]);
        },
      ),
    );
  }

  List<Widget> _overlays(Map<String, dynamic> v) {
    final phase = v['phase'] as String;
    final me = c.mySeat;
    final buyer = v['buyer'] as int?;
    if ((v['legalBids'] as List).isNotEmpty && !_deal.isAnimating) {
      return [_Panel(child: _BidPanel(client: c, view: v))];
    }
    if (phase == 'trump') {
      return [
        _Panel(
          child: buyer == me
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('اخترت ${v['currentBid']}${v['majbur'] == true ? ' (مجبور)' : ''}، اختر الحكم',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final s in suitOrder)
                      OutlinedButton(
                        onPressed: () => c.chooseTrump(s),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                        child: Column(children: [SuitIcon(s, size: 32), Text(suitNames[s]!, style: const TextStyle(fontSize: 14))]),
                      ),
                  ]),
                ])
              : Text('${c.seatName(buyer!)} يختار الحكم...', style: const TextStyle(fontSize: 17)),
        ),
      ];
    }
    if (v['bawanOffer'] == true) {
      return [
        _Panel(
          gold: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أخذتوا كل اللمّات وباقي لك لمّة وحدة', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('تبي تعلن باون؟ إذا جبتوا كل اللمّات تفوزون بالمباراة، وإذا خسرتوا لمّة وحدة يفوز الخصم.',
                textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim, fontSize: 14)),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              FilledButton(
                onPressed: () => c.answerBawan(true),
                style: FilledButton.styleFrom(backgroundColor: KoutColors.gold),
                child: const Text('باون!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: () => c.answerBawan(false), child: const Text('لا، كمّل', style: TextStyle(fontSize: 16))),
            ]),
          ]),
        ),
      ];
    }
    if (phase == 'bawanOffer') {
      return [_Panel(child: Text('${c.seatName(buyer!)} يفكر يعلن باون...', style: const TextStyle(fontSize: 17)))];
    }
    if (phase == 'roundEnd' || phase == 'matchEnd') return [_Panel(child: _RoundResult(client: c, view: v))];
    return const [];
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final bool gold;
  const _Panel({required this.child, this.gold = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: KoutColors.surfaceHigh.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold ? KoutColors.gold : KoutColors.accent, width: gold ? 2 : 1),
            boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 24)],
          ),
          child: child,
        ),
      );
}

/// النتيجة فوق بالنص، كل فريق بلونه.
class _TopBar extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  const _TopBar({required this.client, required this.view});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final myTeam = v['team'] as int;
    final scores = (v['scores'] as List).cast<int>();
    final tricks = (v['tricksWon'] as List).cast<int>();
    final playing = v['trump'] != null;

    Widget pill(int t) {
      final color = KoutColors.team(t);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: t == myTeam ? 2.5 : 1.2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t == myTeam ? 'فريقك' : 'الخصم', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          Text('${scores[t]}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color, height: 1.05)),
          if (playing) Text('لمّات ${tricks[t]}', style: const TextStyle(fontSize: 12, color: KoutColors.textDim)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.logout, size: 22, color: KoutColors.textDim),
          tooltip: 'اطلع',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: KoutColors.surfaceHigh,
                title: const Text('تطلع من اللعبة؟'),
                content: const Text('مقعدك يبقى محجوز وتقدر ترجع بنفس الكود.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('لا')),
                  TextButton(onPressed: () { Navigator.pop(context); client.leave(); }, child: const Text('اطلع')),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            pill(0),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('من', style: TextStyle(fontSize: 11, color: KoutColors.textDim)),
                Text('54', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: KoutColors.textDim)),
              ]),
            ),
            pill(1),
          ]),
        ),
        SizedBox(
          width: 48,
          child: client.connected ? null : const Icon(Icons.wifi_off, size: 20, color: KoutColors.lose),
        ),
      ]),
    );
  }
}

class _Seat extends StatelessWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  final int seat;
  final bool me;
  const _Seat({required this.client, required this.view, required this.seat, this.me = false});

  @override
  Widget build(BuildContext context) {
    final v = view;
    final phase = v['phase'] as String;
    final isTurn = (phase == 'bidding' || phase == 'playing') && v['turn'] == seat;
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
    final avatarSize = me ? 52.0 : 58.0;

    final avatar = Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (left != null)
        SizedBox(
          width: avatarSize + 10,
          height: avatarSize + 10,
          child: CircularProgressIndicator(
            value: (left / _turnSeconds).clamp(0.0, 1.0),
            strokeWidth: 4,
            color: left <= 3 ? KoutColors.lose : KoutColors.text,
            backgroundColor: KoutColors.line,
          ),
        ),
      Container(
        decoration: isTurn
            ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: teamColor.withValues(alpha: 0.7), blurRadius: 14)])
            : null,
        child: CharacterAvatar(charId: info?['char'] as String?, size: avatarSize, ring: teamColor),
      ),
      if (isBot)
        Positioned(
          bottom: -2,
          left: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: KoutColors.surfaceHigh, shape: BoxShape.circle, border: Border.all(color: KoutColors.line)),
            child: const Icon(Icons.smart_toy, size: 14, color: KoutColors.text),
          ),
        ),
      if (isBuyer)
        const Positioned(
          top: -12,
          right: -10,
          child: Icon(Icons.star, size: 30, color: KoutColors.gold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
        ),
      if (offline) const Positioned(top: -4, left: -4, child: Icon(Icons.wifi_off, size: 14, color: KoutColors.lose)),
      // الإشارات: تظهر كلها مع بعض فوق اللاعب
      if (sig != null)
        Positioned(
          top: me ? -44 : -40,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(sig.at),
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: teamColor, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final s in sig.suits)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: s == 'J' ? const JokerSignalIcon(size: 24) : SuitIcon(s, size: 22, color: suitColor(s)),
                  ),
              ]),
            ),
          ),
        ),
    ]);

    final tags = <Widget>[
      if (isBuyer && v['madmoon'] == true)
        const Text('مضمون', style: TextStyle(fontSize: 13, color: KoutColors.madmoon, fontWeight: FontWeight.w900)),
      if (isBuyer && v['majbur'] == true)
        const Text('مجبور', style: TextStyle(fontSize: 13, color: KoutColors.majbur, fontWeight: FontWeight.w900)),
      if (phase == 'bidding' && bidLabel != null)
        Text(bidLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: bidLabel == 'طاف' ? KoutColors.textDim : KoutColors.text)),
      if (isKhabis && phase == 'bidding') const Text('خابص', style: TextStyle(fontSize: 11, color: KoutColors.textDim)),
      if (left != null)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.access_time, size: 13, color: left <= 3 ? KoutColors.lose : KoutColors.text),
          const SizedBox(width: 2),
          Text('${left.ceil()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: left <= 3 ? KoutColors.lose : KoutColors.text)),
        ]),
    ];

    return SizedBox(
      width: 104,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        avatar,
        const SizedBox(height: 3),
        Text(me ? 'أنت' : client.seatName(seat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isTurn ? Colors.white : KoutColors.text)),
        Wrap(spacing: 6, alignment: WrapAlignment.center, children: tags),
      ]),
    );
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
    final current = view['currentBid'] as int;
    final left = client.secondsLeft;
    String label(Object b) => switch (b) { 6 => '6 باب', 9 => '9 باون', _ => bidName(b) };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(current == 0 ? 'دورك تزايد' : 'أعلى مزايدة: $current (${client.seatName(view['buyer'] as int)})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (left != null) ...[
          const SizedBox(width: 10),
          const Icon(Icons.access_time, size: 18),
          Text(' ${left.ceil()}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: left <= 3 ? KoutColors.lose : KoutColors.text)),
        ],
      ]),
      if (legal.contains('majbur'))
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('محد زايد: «6 مجبور» إذا خسرت ياخذ الخصم 6 بس، وبدون باون',
              style: TextStyle(fontSize: 13, color: KoutColors.textDim)),
        ),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final b in legal)
          b == 'pass'
              ? OutlinedButton(onPressed: () => client.bid(b), child: Text(label(b), style: const TextStyle(fontSize: 17)))
              : FilledButton(
                  onPressed: () => client.bid(b),
                  style: b == 9
                      ? FilledButton.styleFrom(backgroundColor: KoutColors.gold)
                      : b == 'majbur'
                          ? FilledButton.styleFrom(backgroundColor: KoutColors.majbur)
                          : null,
                  child: Text(label(b), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
      ]),
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
      final reasonColor = v['winReason'] == 'bawanFail' ? KoutColors.lose : KoutColors.text;
      final color = KoutColors.team(winner);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('فاز الفريق ${KoutColors.teamName(winner)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        Text(winner == myTeam ? 'مبروك! فريقك فاز' : 'هاردلك، فريقك خسر', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${scores[0]}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: KoutColors.teamBlue)),
          const Text('  –  ', style: TextStyle(fontSize: 26)),
          Text('${scores[1]}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: KoutColors.teamYellow)),
        ]),
        const SizedBox(height: 8),
        const Text('سبب الفوز', style: TextStyle(fontSize: 13, color: KoutColors.textDim)),
        Text(reason, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: reasonColor)),
        const SizedBox(height: 14),
        if (client.isHost)
          FilledButton(onPressed: client.rematch, child: const Text('مباراة جديدة', style: TextStyle(fontSize: 17)))
        else
          const Text('بانتظار المضيف...', style: TextStyle(color: KoutColors.textDim)),
      ]);
    }

    final good = r['type'] == 'made';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(good ? Icons.check_circle : Icons.cancel, size: 40, color: good ? KoutColors.win : KoutColors.lose),
      const SizedBox(height: 6),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (pts != null)
        Text('+$pts للفريق ${KoutColors.teamName(team)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: KoutColors.team(team))),
      const SizedBox(height: 8),
      const Text('الجولة الجاية تبدأ بعد شوي...', style: TextStyle(color: KoutColors.textDim, fontSize: 13)),
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
                    fontWeight: FontWeight.w900,
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

/// نافذة الإشارات: الضغط على النوع (أو الجوكر إذا عندك) يرسله على طول، ويظهر للكل فوراً.
class _SignalBar extends StatefulWidget {
  final GameClient client;
  final Map<String, dynamic> view;
  const _SignalBar({required this.client, required this.view});

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
        opacity: enabled || on ? 1 : 0.3,
        child: GestureDetector(
          onTap: enabled
              ? () {
                  widget.client.signal([s]);
                  setState(() => _sent.add(s));
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: on ? Colors.white : KoutColors.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: on ? KoutColors.gold : KoutColors.line, width: on ? 2 : 1),
            ),
            child: s == 'J' ? const JokerSignalIcon(size: 22) : SuitIcon(s, size: 20, color: on ? suitColor(s) : null),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: KoutColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: KoutColors.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('إشارة', style: TextStyle(fontSize: 14, color: KoutColors.textDim, fontWeight: FontWeight.bold)),
        ),
        for (final s in options) chip(s),
      ]),
    );
  }
}

/// أوراقك: اضغط مرة تختار الورقة (ترتفع)، واضغط مرة ثانية ترميها.
class _Hand extends StatelessWidget {
  final Map<String, dynamic> view;
  final String? selected;
  final void Function(String) onTap;
  const _Hand({required this.view, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hand = (view['hand'] as List).cast<String>();
    final legal = (view['legalCards'] as List).cast<String>().toSet();
    final myTurn = legal.isNotEmpty;
    return LayoutBuilder(builder: (context, box) {
      final n = max(hand.length, 1);
      final w = min(76.0, box.maxWidth / 5.2);
      final step = n == 1 ? 0.0 : min(w + 4, (box.maxWidth - 16 - w) / (n - 1));
      final total = w + step * (n - 1);
      // الورقة المختارة ترتفع وتكبر داخل مساحة اليد، عشان ما تغطي نافذة الإشارات
      return SizedBox(
        height: w * 1.45 + 44,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            for (var i = 0; i < hand.length; i++)
              AnimatedPositioned(
                key: ValueKey(hand[i]),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: (box.maxWidth - total) / 2 + i * step,
                top: hand[i] == selected ? 10 : (myTurn && legal.contains(hand[i]) ? 24 : 36),
                child: AnimatedScale(
                  scale: hand[i] == selected ? 1.08 : 1,
                  alignment: Alignment.bottomCenter,
                  duration: const Duration(milliseconds: 180),
                  child: PlayingCard(
                    hand[i],
                    width: w,
                    highlight: hand[i] == selected,
                    enabled: !myTurn || legal.contains(hand[i]),
                    onTap: myTurn ? () => onTap(hand[i]) : null,
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}
