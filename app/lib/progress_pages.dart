import 'package:flutter/material.dart';

import 'cards.dart';
import 'menus.dart';
import 'progress.dart';
import 'sounds.dart';
import 'store.dart' show MenuChip;
import 'wallet.dart';

String _left(Duration d) => d.inHours >= 24 ? 'يتجدد بعد ${d.inDays} يوم' : 'يتجدد بعد ${d.inHours} ساعة';

/// التحديات: يومية وأسبوعية، كل وحدة لها شريط تقدم وجايزة غوازي تنستلم
class ChallengesPage extends StatelessWidget {
  final VoidCallback onBack;
  const ChallengesPage({super.key, required this.onBack});

  Widget _card(BuildContext context, Challenge c) {
    final p = Progress.instance;
    final got = p.progress(c), done = p.done(c), claimed = p.isClaimed(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done && !claimed ? const Color(0xFFFFE08A) : Colors.white, width: done && !claimed ? 3 : 2),
      ),
      child: Row(children: [
        Bob(
          phase: c.id.hashCode % 10 / 10,
          lift: 2,
          child: Icon(claimed ? Icons.check_circle : (c.weekly ? Icons.emoji_events : Icons.flag), size: 30, color: claimed ? KoutColors.madmoon : const Color(0xFFFFE08A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: got / c.goal, minHeight: 9, backgroundColor: const Color(0xFF3A3C40), color: done ? KoutColors.madmoon : const Color(0xFFFFE08A)),
                ),
              ),
              const SizedBox(width: 8),
              Text('$got / ${c.goal}', style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: claimed
              ? const Text('استلمتها', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: KoutColors.madmoon, fontWeight: FontWeight.w700))
              : Pressable(child: FilledButton(
                  onPressed: done
                      ? () {
                          if (Progress.instance.claim(c)) Sfx.tap();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE08A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: const Size(88, 36),
                    textStyle: const TextStyle(fontFamily: 'ElMessiri', fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [const GhawaziIcon(size: 16), const SizedBox(width: 4), Text('${c.reward}')]),
                    if (done) const Text('استلم', style: TextStyle(fontSize: 11, height: 1.1)),
                  ]),
                )),
        ),
      ]),
    );
  }

  Widget _section(String title, String note, List<Widget> cards) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: KoutColors.ink)),
            const Spacer(),
            Text(note, style: const TextStyle(fontSize: 13, color: KoutColors.ink)),
          ]),
        ),
        ...cards,
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Progress.instance, Wallet.instance]),
        builder: (context, _) {
          final now = DateTime.now();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(child: BackRow(title: 'التحديات', onBack: onBack)),
                    MenuChip(child: GhawaziAmount(Wallet.instance.balance, label: true)),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('تنحسب من المباريات أونلاين', style: TextStyle(fontSize: 13, color: KoutColors.ink)),
                ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                    _section('تحديات اليوم', _left(Progress.untilTomorrow(now)), [for (final c in dailyChallenges) _card(context, c)]),
                    _section('تحديات الأسبوع', _left(Progress.untilNextWeek(now)), [for (final c in weeklyChallenges) _card(context, c)]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// «تاريخك»: إحصائيات اللاعب من كل مبارياته
class HistoryPage extends StatelessWidget {
  final VoidCallback onBack;
  const HistoryPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Progress.instance,
        builder: (context, _) {
          final p = Progress.instance;
          final matches = p.value('matches');
          final rate = matches == 0 ? 0 : (p.value('wins') * 100 / matches).round();
          Widget tile(String title, String value, {Color color = Colors.white}) => Container(
                width: 132,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(color: const Color(0xFF1B1C1F), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
                child: Column(children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w800, color: color))),
                  const SizedBox(height: 2),
                  Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
                ]),
              );
          Color colorOf(String key) => switch (key) {
                'wins' || 'boughtMade' || 'bawanMade' || 'bawanBroken' || 'bigBidMade' => const Color(0xFF6FD68A),
                'losses' || 'boughtFailed' || 'bawanFailed' || 'jokerPenalty' => const Color(0xFFFF7A7A),
                'ghawaziWon' => const Color(0xFFFFE08A),
                _ => Colors.white,
              };
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: 'تاريخك', onBack: onBack)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                      tile('نسبة الفوز', '$rate%', color: const Color(0xFF8EC5FF)),
                      for (final s in historyStats) tile(s.title, '${p.value(s.key)}', color: colorOf(s.key)),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}
