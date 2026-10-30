import 'package:flutter/material.dart';

import 'avatars.dart';
import 'cards.dart';
import 'net.dart';
import 'table.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = GameClient();
  await client.loadPrefs();
  runApp(KoutApp(client: client));
}

/// خط المسيري الغامق لكل نصوص اللعبة
const appFont = 'ElMessiri';

class KoutApp extends StatelessWidget {
  final GameClient client;
  const KoutApp({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: KoutColors.accent,
      brightness: Brightness.dark,
      surface: KoutColors.surface,
    ).copyWith(primary: Colors.white, onPrimary: Colors.black, secondary: KoutColors.accent);
    final base = ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white, fontFamily: appFont);
    return MaterialApp(
      title: 'بتّه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        fontFamily: appFont,
        scaffoldBackgroundColor: KoutColors.bg,
        textTheme: base,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2C30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 2.5)),
          labelStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          counterStyle: const TextStyle(color: Color(0xFF999999)),
        ),
        // الزر الأساسي أبيض بكتابة سودا، والثانوي أسود بإطار أبيض
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFF9A9DA2),
            disabledForegroundColor: const Color(0xFF3A3A3A),
            textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w700, fontSize: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white, width: 2)),
            elevation: 3,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w700, fontSize: 17),
            side: const BorderSide(color: Colors.white, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      // كل الكلام أكبر شوي عشان يكون أوضح
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.15)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: ListenableBuilder(
        listenable: client,
        builder: (context, _) {
          if (client.room == null) return HomeScreen(client: client);
          if (!client.started) return LobbyScreen(client: client);
          return TableScreen(client: client);
        },
      ),
    );
  }
}

void showErrors(BuildContext context, GameClient client) {
  final err = client.error;
  if (err == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err, style: const TextStyle(color: Colors.black, fontFamily: appFont)),
      backgroundColor: Colors.white,
      duration: const Duration(seconds: 2),
    ));
    client.clearError();
  });
}

/// خلفية القوائم: كروم مثل الشعار، مع خط لمعة فوق
class ChromeBackground extends StatelessWidget {
  final Widget child;
  const ChromeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: KoutColors.chrome()),
        child: Stack(children: [
          Positioned(
            top: 4,
            left: 40,
            right: 40,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ]),
      );
}

/// لوحة سودا بإطار أبيض (القوائم)
class MenuPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const MenuPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// الشعار بزوايا دائرية وظل
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: size * 0.12, offset: Offset(0, size * 0.04))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
        ),
      );
}

const _dim = TextStyle(color: Color(0xFF2B2E33), fontSize: 14);

class HomeScreen extends StatefulWidget {
  final GameClient client;
  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _name = TextEditingController(text: widget.client.name);
  late final _server = TextEditingController(text: widget.client.serverUrl);
  final _code = TextEditingController();
  bool _showServer = false;

  bool _apply() {
    final c = widget.client;
    c.name = _name.text.trim();
    c.serverUrl = _server.text.trim();
    if (c.name.isEmpty) {
      c.error = 'اكتب اسمك';
      setState(() {});
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    showErrors(context, c);
    final header = Column(mainAxisSize: MainAxisSize.min, children: const [
      Center(child: AppLogo(size: 190)),
      SizedBox(height: 8),
      Text('6 أو 4 لاعبين · فريقين', textAlign: TextAlign.center, style: _dim),
    ]);
    final form = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MenuPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _name,
            style: const TextStyle(fontSize: 18, color: Colors.white),
            decoration: const InputDecoration(labelText: 'اسمك'),
            maxLength: 20,
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () { if (_apply()) c.createRoom(); },
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('سوّ غرفة جديدة', style: TextStyle(fontSize: 19)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      MenuPanel(
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white, letterSpacing: 4),
              decoration: const InputDecoration(labelText: 'كود الغرفة'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () { if (_apply() && _code.text.trim().isNotEmpty) c.joinRoom(_code.text.trim()); },
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22)),
            child: const Text('ادخل'),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final s in suitOrder) Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: SuitIcon(s, size: 20)),
      ]),
      TextButton(
        onPressed: () => setState(() => _showServer = !_showServer),
        child: const Text('إعدادات السيرفر', style: TextStyle(color: Color(0xFF2B2E33), decoration: TextDecoration.underline)),
      ),
      if (_showServer)
        MenuPanel(
          child: TextField(
            controller: _server,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'رابط السيرفر (ws://...)'),
          ),
        ),
    ]);
    return Scaffold(
      body: ChromeBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            // عرضي: عمودين (الشعار يمين، والخانات يسار)
            final wide = box.maxWidth > box.maxHeight && box.maxWidth > 560;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: wide
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(child: header),
                          const SizedBox(width: 24),
                          Expanded(child: form),
                        ]),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 16), form]),
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class LobbyScreen extends StatelessWidget {
  final GameClient client;
  const LobbyScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;
    showErrors(context, c);
    final full = c.seats.every((s) => s != null);
    Widget team(int t) => Expanded(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: KoutColors.team(t), borderRadius: BorderRadius.circular(8)),
              child: Text('الفريق ${KoutColors.teamName(t)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t == 0 ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            for (var seat = t; seat < c.mode; seat += 2) _SeatTile(client: c, seat: seat),
          ]),
        );

    final bar = Row(children: [
      const AppLogo(size: 44),
      const SizedBox(width: 10),
      const Expanded(child: Text('الغرفة', style: TextStyle(fontSize: 24, color: KoutColors.ink))),
      OutlinedButton(
        onPressed: c.leave,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(44, 44)),
        child: const Icon(Icons.logout, size: 20),
      ),
    ]);
    final codePanel = MenuPanel(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Column(children: [
        const Text('كود الغرفة', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
        SelectableText(c.code ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: 10, color: Colors.white)),
        const Text('أرسل الكود لأصحابك عشان يدخلون', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
      ]),
    );
    // عدد اللاعبين: المضيف يختار (المحدد أبيض)
    Widget modeButton(int m) {
      final on = c.mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: c.isHost && !on ? () => c.setMode(m) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: on ? Colors.white : const Color(0xFF111111),
            child: Text('$m لاعبين', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: on ? Colors.black : Colors.white)),
          ),
        ),
      );
    }

    final mode = Column(children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2)),
        child: Row(children: [modeButton(6), modeButton(4)]),
      ),
      if (c.mode == 4)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('36 ورقة: بدون 2-6 كلفس وهاس، وبدون 2-5 سبيت وديمن', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 13)),
        ),
    ]);
    final seats = Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [team(0), const SizedBox(width: 10), team(1)]),
      const Text('اضغط على مقعد فاضي عشان تنتقل له', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 12)),
    ]);
    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.isHost) ...[
        if (!full)
          OutlinedButton.icon(
            onPressed: c.addBots,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.smart_toy),
            label: const Text('عبّي المقاعد الفاضية', style: TextStyle(fontSize: 16)),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: full ? c.start : null,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(full ? 'ابدأ اللعب' : 'بانتظار ${c.seats.where((s) => s == null).length} لاعبين'),
        ),
      ] else
        const Text('بانتظار المضيف يبدأ اللعبة...', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.ink, fontSize: 16)),
      if (!c.connected)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('انقطع الاتصال، جاري إعادة الاتصال...', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.lose)),
        ),
    ]);

    return Scaffold(
      body: ChromeBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight && box.maxWidth > 560;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 900 : 520),
                child: wide
                    // عرضي: عمودين (الكود والاختيار يمين، المقاعد يسار)
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(children: [bar, const SizedBox(height: 12), codePanel, const SizedBox(height: 12), mode, const SizedBox(height: 12), actions]),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: SingleChildScrollView(child: seats)),
                        ]),
                      )
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        bar,
                        const SizedBox(height: 12),
                        codePanel,
                        const SizedBox(height: 12),
                        mode,
                        const SizedBox(height: 12),
                        seats,
                        const SizedBox(height: 14),
                        actions,
                      ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final GameClient client;
  final int seat;
  const _SeatTile({required this.client, required this.seat});

  @override
  Widget build(BuildContext context) {
    final s = client.seats[seat];
    final me = seat == client.mySeat;
    final canMove = s == null || s['bot'] == true;
    final teamColor = KoutColors.team(seat % 2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        // مقعدك بإطار لون فريقك
        border: Border.all(color: me ? teamColor : Colors.white, width: me ? 3 : 2),
        borderRadius: BorderRadius.circular(11),
        boxShadow: me ? [BoxShadow(color: teamColor.withValues(alpha: 0.5), blurRadius: 8)] : null,
      ),
      child: InkWell(
        onTap: canMove && !me ? () => client.sit(seat) : null,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            const SizedBox(width: 7),
            if (s == null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFBFE6F7), border: Border.all(color: teamColor, width: 2)),
                child: const Icon(Icons.event_seat_outlined, color: Color(0xFF5A6A72), size: 22),
              )
            else
              CharacterAvatar(charId: s['char'] as String?, size: 44, ring: teamColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(s == null ? 'فاضي' : '${s['name']}${me ? ' (أنت)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: s == null ? const Color(0xFF999999) : Colors.white)),
            ),
            if (s != null && s['bot'] == true) const Icon(Icons.smart_toy, size: 17, color: Color(0xFFBBBBBB)),
            if (client.isHost && s != null && !me)
              IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white), onPressed: () => client.kick(seat), tooltip: 'طرد'),
          ]),
        ),
      ),
    );
  }
}
