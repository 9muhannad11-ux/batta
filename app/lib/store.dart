import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'main.dart' show MenuPanel;
import 'menus.dart';
import 'net.dart';
import 'sounds.dart';
import 'wallet.dart';

/// المتجر: كل غرض ينشرى بالغوازي أو بالدولار («قريباً» لين ينزل التطبيق على المتاجر)
class StorePage extends StatefulWidget {
  final VoidCallback onBack;
  final String? focus; // 'char:khalfan': المتجر يفتح عليه ويبرزه
  const StorePage({super.key, required this.onBack, this.focus});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final w = Wallet.instance;
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 300));
      });
    }
  }

  void _buy(ShopItem item) {
    if (w.buy(item)) {
      Sfx.tap();
      w.equip(item.kind, item.id);
      _toast('اشتريت ${item.name}');
    } else {
      _toast('غوازيك ما تكفي');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        duration: const Duration(seconds: 2),
      ));

  Widget _preview(String kind, String id) => switch (kind) {
        'char' => VoicePreview(charId: id, size: 62),
        'table' => _MiniTable(theme: tableThemes.firstWhere((t) => t.id == id)),
        _ => _MiniBg(theme: bgThemes.firstWhere((b) => b.id == id)),
      };

  Widget _button(String kind, String id, ShopItem? item) {
    final mine = w.owns(kind, id);
    final using = (kind == 'table' && w.table == id) || (kind == 'bg' && w.bg == id);
    ButtonStyle small(Color bg, Color fg) => FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(96, 34),
          textStyle: const TextStyle(fontFamily: 'ElMessiri', fontSize: 15, fontWeight: FontWeight.w700),
        );
    if (mine) {
      if (kind == 'char') return FilledButton(onPressed: null, style: small(Colors.white, Colors.black), child: const Text('عندك'));
      if (using) return FilledButton(onPressed: null, style: small(KoutColors.madmoon, Colors.white), child: const Text('مستخدم ✓'));
      return Pressable(child: FilledButton(onPressed: withTap(() => w.equip(kind, id)), style: small(Colors.white, Colors.black), child: const Text('استخدم')));
    }
    // مو عندك: خيارين، بالغوازي وبالدولار («قريباً» لين ينزل التطبيق على المتاجر)
    final enough = w.balance >= item!.price;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Pressable(child: FilledButton(
        onPressed: () => _buy(item),
        style: small(enough ? const Color(0xFFFFE08A) : const Color(0xFF9A9DA2), Colors.black),
        child: Row(mainAxisSize: MainAxisSize.min, children: [const GhawaziIcon(size: 18), const SizedBox(width: 5), Text('${item.price}')]),
      )),
      const SizedBox(height: 5),
      FilledButton(
        onPressed: null,
        style: small(Colors.white, Colors.black),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(item.usd, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          const Text('قريباً', style: TextStyle(fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _tile(String kind, String id, String name, ShopItem? item) {
    final locked = !w.owns(kind, id);
    final focused = widget.focus == '$kind:$id';
    return Container(
      key: focused ? _focusKey : null,
      width: 132,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? const Color(0xFFFFE08A) : (locked ? const Color(0xFF55585E) : Colors.white), width: focused ? 3.5 : 2),
        boxShadow: focused ? const [BoxShadow(color: Color(0xAAFFE08A), blurRadius: 14)] : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 80,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            _preview(kind, id),
            if (locked) const PositionedDirectional(top: 0, end: 0, child: Icon(Icons.lock, size: 20, color: Color(0xFFFFE08A), shadows: [Shadow(blurRadius: 4)])),
          ]),
        ),
        const SizedBox(height: 4),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _button(kind, id, item),
      ]),
    );
  }

  Widget _section(String title, List<Widget> tiles) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: KoutColors.ink)),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: tiles),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: w,
        builder: (context, _) {
          final items = {for (final i in shopItems(characterNames)) '${i.kind}:${i.id}': i};
          List<Widget> tilesOf(String kind, Iterable<(String, String)> all) => [
                for (final (id, name) in all) _tile(kind, id, name, items['$kind:$id']),
              ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    Expanded(child: BackRow(title: 'المتجر', onBack: widget.onBack)),
                    MenuChip(child: GhawaziAmount(w.balance, label: true)),
                  ]),
                ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                    _section('الشخصيات', tilesOf('char', [for (final id in lockedChars.keys) (id, characterNames[id] ?? id)])),
                    _section('لون الطاولة', tilesOf('table', [for (final t in tableThemes) (t.id, t.name)])),
                    _section('خلفية الطاولة', tilesOf('bg', [for (final b in bgThemes) (b.id, b.name)])),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// إطار أسود صغير بحافة بيضا (الرصيد)
class MenuChip extends StatelessWidget {
  final Widget child;
  const MenuChip({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: child,
      );
}

/// معاينة لون الطاولة: بيضاوية بحافة خشب
class _MiniTable extends StatelessWidget {
  final TableTheme theme;
  const _MiniTable({required this.theme});

  @override
  Widget build(BuildContext context) => Container(
        width: 110,
        height: 66,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(colors: [Color(0xFFA56F3E), Color(0xFF6B3E1B), Color(0xFF51300F)]),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: RadialGradient(colors: theme.felt, stops: const [0, 0.55, 1], radius: 0.8),
            border: Border.all(color: theme.edge, width: 1),
          ),
        ),
      );
}

/// معاينة الخلفية: مربع حصير بلونها
class _MiniBg extends StatelessWidget {
  final BgTheme theme;
  const _MiniBg({required this.theme});

  @override
  Widget build(BuildContext context) => Container(
        width: 110,
        height: 72,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))]),
        child: MatBackground(theme: theme),
      );
}

/// الحصير (بلون الخلفية المختارة)
class MatBackground extends StatelessWidget {
  final BgTheme theme;
  const MatBackground({super.key, required this.theme});

  static const image = ExactAssetImage('assets/images/mat.jpg', scale: 1.5);

  @override
  Widget build(BuildContext context) {
    final mat = Image(image: image, repeat: ImageRepeat.repeat, alignment: Alignment.topLeft, fit: BoxFit.none, filterQuality: FilterQuality.low, gaplessPlayback: true);
    final tint = theme.tint;
    return SizedBox.expand(child: tint == null ? mat : ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.multiply), child: mat));
  }
}

/// زر صغير على جنب القائمة الرئيسية (المتجر والتفضيلات)
class SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double phase;
  final bool dot; // نقطة حمرا: فيه شي ينتظرك (جايزة تحدي)
  const SideButton({super.key, required this.icon, required this.label, required this.onTap, this.phase = 0, this.dot = false});

  @override
  Widget build(BuildContext context) => Pressable(child: GestureDetector(
        onTap: withTap(onTap),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Bob(phase: phase, lift: 2.5, child: Icon(icon, color: Colors.white, size: 28)),
              if (dot)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: KoutColors.lose, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: KoutColors.ink, fontWeight: FontWeight.w700)),
        ]),
      ));
}

/// التفضيلات: تختار شخصيتك ولون الطاولة والخلفية من اللي عندك (المقفل يوديك للمتجر)
class PrefsPage extends StatelessWidget {
  final GameClient client;
  final VoidCallback onBack;
  final void Function(String item) onStore; // مقفل: يفتح المتجر على خيارات شرائه
  const PrefsPage({super.key, required this.client, required this.onBack, required this.onStore});

  Widget _tile({required String item, required Widget preview, required String name, required bool chosen, required bool locked, required VoidCallback onChoose}) => Pressable(child: GestureDetector(
        onTap: withTap(locked ? () => onStore(item) : onChoose),
        child: Container(
          width: 112,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: chosen ? KoutColors.madmoon : (locked ? const Color(0xFF55585E) : Colors.white), width: chosen ? 3 : 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 76,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Opacity(opacity: locked ? 0.55 : 1, child: preview),
                if (locked) const Icon(Icons.lock, size: 26, color: Color(0xFFFFE08A), shadows: [Shadow(blurRadius: 6)]),
                if (chosen) const PositionedDirectional(top: 0, end: 0, child: Icon(Icons.check_circle, size: 22, color: KoutColors.madmoon)),
              ]),
            ),
            const SizedBox(height: 4),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: locked ? const Color(0xFF999999) : Colors.white, fontWeight: FontWeight.w700)),
            if (locked) const Text('من المتجر', style: TextStyle(fontSize: 11, color: Color(0xFFFFE08A))),
          ]),
        ),
      ));

  Widget _section(String title, List<Widget> tiles) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: KoutColors.ink)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: tiles),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Wallet.instance, client]),
        builder: (context, _) {
          final w = Wallet.instance;
          // المفتوح أول، والمقفل آخر
          final chars = [...characterNames.keys.where((id) => w.owns('char', id)), ...characterNames.keys.where((id) => !w.owns('char', id))];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: 'التفضيلات', onBack: onBack)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                    _section('اسمك', [_NameEdit(client: client)]),
                    _section('شخصيتك', [
                      for (final id in chars)
                        _tile(
                          item: 'char:$id',
                          preview: VoicePreview(charId: id, size: 58),
                          name: characterNames[id]!,
                          chosen: client.char == id,
                          locked: !w.owns('char', id),
                          onChoose: () => client.chooseChar(id),
                        ),
                    ]),
                    _section('لون الطاولة', [
                      for (final t in tableThemes)
                        _tile(item: 'table:${t.id}', preview: _MiniTable(theme: t), name: t.name, chosen: w.table == t.id, locked: !w.owns('table', t.id), onChoose: () => w.equip('table', t.id)),
                    ]),
                    _section('خلفية الطاولة', [
                      for (final b in bgThemes)
                        _tile(item: 'bg:${b.id}', preview: _MiniBg(theme: b), name: b.name, chosen: w.bg == b.id, locked: !w.owns('bg', b.id), onChoose: () => w.equip('bg', b.id)),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// صورة الشخصية مع زر سماعة يشغّل صوتها (والفم يتحرك معه). كل ضغطة عبارة ثانية
class VoicePreview extends StatefulWidget {
  final String charId;
  final double size;
  const VoicePreview({super.key, required this.charId, required this.size});

  @override
  State<VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends State<VoicePreview> {
  static const _lines = [VoiceEvent.pass, VoiceEvent.made, VoiceEvent.bid6, VoiceEvent.gold, VoiceEvent.trumpS, VoiceEvent.oppFailed];
  static int _next = 0;
  String? _talking;

  Future<void> _play() async {
    final event = _lines[_next++ % _lines.length];
    final id = '${widget.charId}_$event';
    await Sfx.voice(9, widget.charId, event, onStart: () {
      if (mounted) setState(() => _talking = id);
    });
    if (mounted && _talking == id) setState(() => _talking = null);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CharacterAvatar(charId: widget.charId, size: widget.size, ring: KoutColors.team(0), background: KoutColors.team(0), voice: _talking);
    if (!Sfx.voices.containsKey(widget.charId)) return avatar;
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      PositionedDirectional(
        bottom: -2,
        start: -6,
        child: Pressable(child: GestureDetector(
          onTap: _play,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _talking != null ? KoutColors.madmoon : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF111111), width: 2),
            ),
            child: Icon(_talking != null ? Icons.graphic_eq : Icons.volume_up, size: 17, color: _talking != null ? Colors.white : Colors.black),
          ),
        )),
      ),
    ]);
  }
}

/// تغيير الاسم من التفضيلات (ينحفظ مع كل حرف)
class _NameEdit extends StatefulWidget {
  final GameClient client;
  const _NameEdit({required this.client});

  @override
  State<_NameEdit> createState() => _NameEditState();
}

class _NameEditState extends State<_NameEdit> {
  late final _c = TextEditingController(text: widget.client.name);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: MenuPanel(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: TextField(
            controller: _c,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(labelText: 'اسمك', counterText: '', isDense: true),
            maxLength: 20,
            onChanged: (v) {
              if (v.trim().isNotEmpty) widget.client.saveName(v);
            },
          ),
        ),
      );
}
