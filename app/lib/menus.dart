import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'cards.dart';
import 'main.dart' show ChromeBackground, showErrors;
import 'net.dart';
import 'sounds.dart';
import 'wallet.dart';

/// أي خيار ينضغط ينزل شوي ويصغر شوي، ويرجع لما ينشال الإصبع (عشان يبين إنه انضغط)
class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedSlide(
          offset: Offset(0, _down ? 0.05 : 0),
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          child: AnimatedScale(scale: _down ? 0.95 : 1, duration: const Duration(milliseconds: 70), curve: Curves.easeOut, child: widget.child),
        ),
      );
}

/// انتقال بسيط بين الصفحات: الجديدة تدخل بتلاشي وحركة خفيفة. id يتغير مع كل صفحة
class PageSwitcher extends StatelessWidget {
  final Object id;
  final Widget child;
  const PageSwitcher({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (page, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: page),
        ),
        layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(id), child: child),
      );
}

/// الإعدادات: من القائمة الرئيسية ومن داخل اللعبة
void showSettings(BuildContext context, GameClient client) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1B1C1F),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => _SettingsSheet(client: client),
  );
}

class _SettingsSheet extends StatefulWidget {
  final GameClient client;
  const _SettingsSheet({required this.client});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final _server = TextEditingController(text: widget.client.serverUrl);

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  void _voiceSample() {
    final c = widget.client;
    Sfx.voice(0, Sfx.hasVoice(c.char, VoiceEvent.pass) ? c.char! : 'fares', VoiceEvent.pass);
  }

  Widget _sound(String title, bool on, double level, ValueChanged<bool> setOn, ValueChanged<double> setLevel, VoidCallback sample) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700))),
          Switch(
            value: on,
            onChanged: (v) {
              setState(() => setOn(v));
              Sfx.saveSettings();
              if (v) sample();
            },
          ),
        ]),
        Row(children: [
          Icon(Icons.volume_down, size: 20, color: on ? Colors.white : const Color(0xFF777777)),
          Expanded(
            child: Slider(
              value: level,
              onChanged: on ? (v) => setState(() => setLevel(v)) : null,
              onChangeEnd: (_) {
                Sfx.saveSettings();
                sample();
              },
            ),
          ),
          Icon(Icons.volume_up, size: 20, color: on ? Colors.white : const Color(0xFF777777)),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('الإعدادات', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _sound('أصوات اللعبة', Sfx.sfxOn, Sfx.sfxVolume, (v) => Sfx.sfxOn = v, (v) => Sfx.sfxVolume = v, Sfx.tap),
                _sound('أصوات الشخصيات', Sfx.voiceOn, Sfx.voiceVolume, (v) => Sfx.voiceOn = v, (v) => Sfx.voiceVolume = v, _voiceSample),
                Row(children: [
                  const Expanded(child: Text('أنميشن الشعار عند فتح اللعبة', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700))),
                  Switch(value: c.intro, onChanged: (v) => setState(() => c.setIntro(v))),
                ]),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('إعدادات السيرفر', style: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB))),
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  children: [
                    TextField(
                      controller: _server,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'رابط السيرفر (ws://...)'),
                      onChanged: (v) => c.serverUrl = v.trim(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                const SizedBox(height: 6),
                Pressable(child: OutlinedButton.icon(
                  onPressed: withTap(() => Navigator.pop(context)),
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('رجوع'),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

const _green = Color(0xFF1B8A3A); // العبارات الصغيرة بالقوائم

/// خيار بالقوائم بشكل ورقة خال من نوع معيّن، مثل أوراق الشعار: رمز النوع بالزوايا.
/// بالوسط حلقة لاعبين (ring) أو رمز (icon). heading: عنوان واضح فوق الورقة
class MenuCard extends StatelessWidget {
  final double width;
  final String suit;
  final IconData? icon;
  final int? ring;
  final String? heading;
  final String title;
  final String? subtitle;
  final int? coins; // مبلغ غوازي بالوسط بدل الرمز
  final VoidCallback? onTap;
  const MenuCard({super.key, required this.width, required this.suit, required this.title, this.icon, this.ring, this.heading, this.subtitle, this.coins, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = suitColor(suit);
    final size = heading == null ? 84.0 : 62.0;
    final card = Container(
      width: 180,
      height: 180 * cardRatio,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF111111), width: 5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Stack(children: [
        PositionedDirectional(top: 7, end: 7, child: Shine(child: SuitIcon(suit, size: 22))),
        PositionedDirectional(bottom: 7, start: 7, child: Shine(child: Transform.rotate(angle: pi, child: SuitIcon(suit, size: 22)))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (heading != null) ...[
              FittedBox(fit: BoxFit.scaleDown, child: Text(heading!, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color))),
              const SizedBox(height: 10),
            ],
            if (coins != null)
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Bob(phase: coins! % 7 / 7, child: Shine(child: GhawaziIcon(size: size * 0.8))),
                const SizedBox(height: 4),
                Text('$coins', style: const TextStyle(fontSize: 34, height: 1, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
              ]))
            else
              Center(child: Bob(phase: (title.hashCode % 100) / 100, child: Shine(child: ring != null ? CustomPaint(size: Size.square(size), painter: _PlayersRing(ring!, color)) : Icon(icon, size: size, color: color)))),
            const SizedBox(height: 10),
            FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: TextStyle(fontSize: heading == null ? 25 : 20, fontWeight: FontWeight.w700, color: heading == null ? color : _green))),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _green, height: 1.25)),
            ],
          ]),
        ),
      ]),
    );
    return SizedBox(
      width: width,
      height: width * cardRatio,
      child: FittedBox(child: onTap == null ? card : Pressable(child: GestureDetector(onTap: withTap(onTap), child: card))),
    );
  }
}

/// لمعة بيضا تمر على الشكل باستمرار
class Shine extends StatefulWidget {
  final Widget child;
  const Shine({super.key, required this.child});

  @override
  State<Shine> createState() => _ShineState();
}

class _ShineState extends State<Shine> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _sweep,
          child: widget.child,
          builder: (_, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0x00FFFFFF), Color(0xD9FFFFFF), Color(0x00FFFFFF)],
              stops: const [0.3, 0.5, 0.7],
              transform: _Sweep(-1.5 + 3 * _sweep.value),
            ).createShader(r),
            child: child,
          ),
        ),
      );
}

class _Sweep extends GradientTransform {
  final double at;
  const _Sweep(this.at);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * at, bounds.height * at, 0);
}

/// حلقة لاعبين: كل لاعب راس وأكتاف
class _PlayersRing extends CustomPainter {
  final int count;
  final Color color;
  const _PlayersRing(this.count, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width, center = size.center(Offset.zero);
    final paint = Paint()..color = color;
    final six = count == 6;
    // كل شخص واقف مستقيم بمكانه على الحلقة
    final radius = s * 0.36, f = s * (six ? 0.27 : 0.31);
    for (var i = 0; i < count; i++) {
      final a = -pi / 2 + 2 * pi * i / count;
      final p = center + Offset(cos(a), sin(a)) * radius;
      canvas.drawCircle(p + Offset(0, -f * 0.3), f * 0.27, paint);
      canvas.drawArc(Rect.fromCenter(center: p + Offset(0, f * 0.55), width: f * 0.95, height: f * 0.9), pi, pi, true, paint);
    }
  }

  @override
  bool shouldRepaint(_PlayersRing old) => old.count != count || old.color != color;
}

/// سطر الرجوع فوق الشاشات الفرعية
class BackRow extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const BackRow({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) => Row(children: [
        Pressable(child: OutlinedButton(
          onPressed: withTap(onBack),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(44, 44)),
          child: const Icon(Icons.arrow_back, size: 20),
        )),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 24, color: KoutColors.ink, fontWeight: FontWeight.w700))),
      ]);
}

/// أنميشن خلط ورق صغير: الأوراق تدور حول بعض يمين ويسار
class CardShuffle extends StatefulWidget {
  final double cardWidth;
  const CardShuffle({super.key, this.cardWidth = 64});

  @override
  State<CardShuffle> createState() => _CardShuffleState();
}

class _CardShuffleState extends State<CardShuffle> with SingleTickerProviderStateMixin {
  static const _count = 6;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cardWidth;
    return RepaintBoundary(
      child: SizedBox(
        width: w * 3.1,
        height: w * cardRatio * 1.3,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (_, _) {
            // الأمامي يترسم آخر
            final cards = List.generate(_count, (i) {
              final a = 2 * pi * (_spin.value + i / _count);
              return (x: sin(a), depth: cos(a));
            })
              ..sort((a, b) => a.depth.compareTo(b.depth));
            return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              for (final c in cards)
                Transform.translate(
                  offset: Offset(c.x * w * 0.95, -c.depth * w * 0.1),
                  child: Transform.rotate(angle: c.x * 0.28, child: Transform.scale(scale: 0.9 + 0.1 * c.depth, child: CardBack(width: w))),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

const _waitTop = 'استغفر ربك وصل على النبي';
const _waitLine = 'قاعدين ندورلك ربع';

/// فوق شاشة انتظار الغرفة المخصصة
class WaitBanner extends StatelessWidget {
  const WaitBanner({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(_waitTop, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: KoutColors.ink))),
          SizedBox(height: 4),
          CardShuffle(cardWidth: 34),
          SizedBox(height: 2),
          Text(_waitLine, style: TextStyle(fontSize: 16, color: KoutColors.ink)),
        ]),
      );
}

/// البحث عن لاعبين: أقصى شي دقيقة ونص، وبعدها البوتات تكمّل
class SearchScreen extends StatefulWidget {
  final GameClient client;
  const SearchScreen({super.key, required this.client});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Timer _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _clock;
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    showErrors(context, c);
    final found = c.seats.where((s) => s != null).length;
    final ends = c.searchEnds;
    final left = ends == null ? 0 : max(0, ends.difference(DateTime.now()).inSeconds);
    final time = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    final score = c.room?['winScore'];
    return Scaffold(
      body: ChromeBackground(
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(_waitTop, textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: KoutColors.ink)),
                  const SizedBox(height: 26),
                  const CardShuffle(),
                  const SizedBox(height: 18),
                  const Text(_waitLine, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: KoutColors.ink)),
                  const SizedBox(height: 6),
                  Text('$found من ${c.mode} لاعبين · من $score نقطة', style: const TextStyle(fontSize: 17, color: KoutColors.ink)),
                  Text(time, style: const TextStyle(fontSize: 17, color: KoutColors.ink)),
                  const SizedBox(height: 16),
                  Pressable(child: OutlinedButton.icon(
                    onPressed: withTap(c.leave),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 28)),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('رجوع'),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حركة خفيفة للأيقونات بالقوائم: تطفو فوق وتحت وتميل شوي. phase يفرّق بين الأيقونات عشان ما تتحرك سوا
class Bob extends StatefulWidget {
  final Widget child;
  final double phase; // من 0 لـ 1
  final double lift; // كم بكسل تطلع
  const Bob({super.key, required this.child, this.phase = 0, this.lift = 3});

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (_, child) {
          final a = 2 * pi * (_t.value + widget.phase);
          return Transform.translate(
            offset: Offset(0, -widget.lift * sin(a)),
            child: Transform.rotate(angle: 0.04 * sin(a * 0.5 + 1), child: child),
          );
        },
      );
}

/// خلفية القائمة الرئيسية: رموز الورق باهتة تطلع لفوق ببطء وتدور، عشان القائمة ما تكون جامدة
class MenuBackdrop extends StatefulWidget {
  const MenuBackdrop({super.key});

  @override
  State<MenuBackdrop> createState() => _MenuBackdropState();
}

class _MenuBackdropState extends State<MenuBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, _) => Stack(fit: StackFit.expand, children: [
              LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                const suits = ['S', 'H', 'C', 'D'];
                return Stack(children: [
                  for (var i = 0; i < 16; i++)
                    () {
                      // كل رمز له مكان وسرعة ثابتة (من رقمه)
                      final x = ((i * 0.6180339) % 1) * w;
                      final speed = 1 + (i % 3);
                      final p = (_t.value * speed + i / 16) % 1;
                      final y = h + 40 - p * (h + 80);
                      final size = 22.0 + (i * 7) % 26;
                      return Positioned(
                        left: x - size / 2 + 14 * sin(2 * pi * (p * 2 + i / 5)),
                        top: y - size / 2,
                        child: Opacity(
                          // يظهر ويختفي بهدوء عند الأطراف
                          opacity: 0.10 * sin(pi * p),
                          child: Transform.rotate(angle: 2 * pi * p * (i.isEven ? 1 : -1), child: SuitIcon(suits[i % 4], size: size)),
                        ),
                      );
                    }(),
                ]);
              }),
            ]),
          ),
        ),
      );
}
