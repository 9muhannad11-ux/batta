import 'dart:math';

import 'package:flutter/material.dart';

import 'menus.dart' show Bob;
import 'sounds.dart';
import 'wallet.dart';

/// عملات غوازي تطير من مكان لمكان (من الهدية للرصيد، أو من الرصيد للجيم) مع صوت العملات.
/// onLand: أول ما توصل أول عملة (نحدّث الرصيد وقتها عشان الرقم يعدّ مع وصولها)
void flyCoins(BuildContext context, {required GlobalKey from, required GlobalKey to, int count = 9, VoidCallback? onLand, VoidCallback? onDone}) {
  final overlay = Overlay.maybeOf(context);
  final box = overlay?.context.findRenderObject() as RenderBox?;
  Rect? rectOf(GlobalKey k) {
    final b = k.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || box == null || !b.hasSize) return null;
    return b.localToGlobal(Offset.zero, ancestor: box) & b.size;
  }

  final a = rectOf(from), b = rectOf(to);
  if (overlay == null || a == null || b == null) {
    onLand?.call();
    onDone?.call();
    return;
  }
  Sfx.coins();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CoinFlight(
      from: a.center,
      to: b.center,
      count: count,
      onLand: onLand,
      onDone: () {
        entry.remove();
        onDone?.call();
      },
    ),
  );
  overlay.insert(entry);
}

class _CoinFlight extends StatefulWidget {
  final Offset from, to;
  final int count;
  final VoidCallback? onLand;
  final VoidCallback onDone;
  const _CoinFlight({required this.from, required this.to, required this.count, required this.onLand, required this.onDone});

  @override
  State<_CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<_CoinFlight> with SingleTickerProviderStateMixin {
  static const _ms = 900, _fly = 0.55, _gap = 0.05; // كل عملة تطير 55% من الوقت، وورا بعض بفرق 5%
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: _ms));
  final _rnd = Random(3);
  late final List<Offset> _spread = [for (var i = 0; i < widget.count; i++) Offset(_rnd.nextDouble() * 36 - 18, _rnd.nextDouble() * 20 - 10)];
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      if (!_landed && _t.value >= _fly) {
        _landed = true;
        widget.onLand?.call();
      }
    });
    _t.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, _) {
            final d = widget.to - widget.from;
            // قوس لفوق بين النقطتين
            // (ما يطلع برا الشاشة من فوق)
            final lift = -min(min(140.0, 60 + d.distance * 0.25), max(0.0, min(widget.from.dy, widget.to.dy) - 14));
            return Stack(children: [
              for (var i = 0; i < widget.count; i++)
                Builder(builder: (_) {
                  final p = ((_t.value - i * _gap) / _fly).clamp(0.0, 1.0);
                  if (p <= 0 || p >= 1) return const SizedBox.shrink();
                  final e = Curves.easeInOut.transform(p);
                  // تنتشر شوي أول ما تطلع، وتتجمع لما توصل
                  final spread = _spread[i] * sin(p * pi);
                  final pos = widget.from + d * e + Offset(0, lift * 4 * e * (1 - e)) + spread;
                  final size = 26.0 * (1 - 0.25 * e);
                  return Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Transform.rotate(angle: p * pi * 2 * (i.isEven ? 1 : -1), child: GhawaziIcon(size: size)),
                  );
                }),
            ]);
          },
        ),
      );
}

/// خانة هدية اليوم تحت الرصيد: تلمع وتنط لين يضغطها اللاعب، وبعدها تقول متى الجاية
class GiftBox extends StatelessWidget {
  final VoidCallback onTap;
  const GiftBox({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Wallet.instance,
        builder: (_, _) {
          final ready = Wallet.instance.giftReady;
          final left = Wallet.untilNextGift(DateTime.now());
          final when = left.inHours >= 1 ? 'بعد ${left.inHours} ساعة' : 'بعد ${max(1, left.inMinutes)} دقيقة';
          return GestureDetector(
            onTap: ready ? onTap : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
              decoration: BoxDecoration(
                color: ready ? const Color(0xFF2A1F05) : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ready ? const Color(0xFFFFD65A) : const Color(0xFF8A8D92), width: 2),
                boxShadow: ready ? const [BoxShadow(color: Color(0x99FFD65A), blurRadius: 12)] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Bob(phase: 0.1, lift: ready ? 3 : 0, child: Icon(Icons.card_giftcard, size: 22, color: ready ? const Color(0xFFFFD65A) : const Color(0xFF8A8D92))),
                const SizedBox(width: 6),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ready ? 'هدية اليوم' : 'هدية بكرة', style: TextStyle(fontFamily: 'ElMessiri', fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, color: ready ? Colors.white : const Color(0xFFAAAAAA))),
                  ready
                      ? const Row(mainAxisSize: MainAxisSize.min, children: [
                          GhawaziIcon(size: 13),
                          SizedBox(width: 3),
                          Text('+${Wallet.dailyGift} استلمها', style: TextStyle(fontFamily: 'ElMessiri', fontSize: 12, height: 1.2, color: Color(0xFFFFD65A))),
                        ])
                      : Text(when, style: const TextStyle(fontFamily: 'ElMessiri', fontSize: 12, height: 1.2, color: Color(0xFFAAAAAA))),
                ]),
              ]),
            ),
          );
        },
      );
}
