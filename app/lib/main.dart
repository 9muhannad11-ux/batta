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

class KoutApp extends StatelessWidget {
  final GameClient client;
  const KoutApp({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: KoutColors.accent,
      brightness: Brightness.dark,
      surface: KoutColors.surface,
    ).copyWith(primary: KoutColors.text, onPrimary: KoutColors.bg, secondary: KoutColors.accent);
    return MaterialApp(
      title: 'بتّه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: KoutColors.bg,
        appBarTheme: const AppBarTheme(backgroundColor: KoutColors.bg, foregroundColor: KoutColors.text),
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: KoutColors.text, displayColor: KoutColors.text),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: KoutColors.line)),
          labelStyle: TextStyle(color: KoutColors.textDim),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: KoutColors.text, foregroundColor: KoutColors.bg),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: KoutColors.text, side: const BorderSide(color: KoutColors.line)),
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
      content: Text(err, style: const TextStyle(color: KoutColors.bg)),
      backgroundColor: KoutColors.text,
      duration: const Duration(seconds: 2),
    ));
    client.clearError();
  });
}

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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SuitIcon('S', size: 34), SizedBox(width: 6), SuitIcon('H', size: 34),
                  SizedBox(width: 6), SuitIcon('D', size: 34), SizedBox(width: 6), SuitIcon('C', size: 34),
                ]),
                const SizedBox(height: 12),
                const Text('بتّه', textAlign: TextAlign.center, style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                const Text('6 أو 4 لاعبين · فريقين', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim)),
                const SizedBox(height: 32),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسمك'), maxLength: 20),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () { if (_apply()) c.createRoom(); },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('سوّ غرفة جديدة', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'كود الغرفة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () { if (_apply() && _code.text.trim().isNotEmpty) c.joinRoom(_code.text.trim()); },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20)),
                    child: const Text('ادخل'),
                  ),
                ]),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() => _showServer = !_showServer),
                  child: const Text('إعدادات السيرفر', style: TextStyle(color: KoutColors.textDim)),
                ),
                if (_showServer)
                  TextField(
                    controller: _server,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'رابط السيرفر (ws://...)'),
                  ),
              ]),
            ),
          ),
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
            Text('الفريق ${KoutColors.teamName(t)}',
                style: TextStyle(color: KoutColors.team(t), fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var seat = t; seat < c.mode; seat += 2) _SeatTile(client: c, seat: seat),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('الغرفة'),
        actions: [IconButton(onPressed: c.leave, icon: const Icon(Icons.logout), tooltip: 'اطلع')],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text('كود الغرفة', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim)),
              SelectableText(c.code ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 8)),
              const Text('أرسل الكود لأصحابك عشان يدخلون', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim)),
              const SizedBox(height: 16),
              // عدد اللاعبين: المضيف يختار
              Center(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 6, label: Text('6 لاعبين', style: TextStyle(fontSize: 16))),
                    ButtonSegment(value: 4, label: Text('4 لاعبين', style: TextStyle(fontSize: 16))),
                  ],
                  selected: {c.mode},
                  onSelectionChanged: c.isHost ? (s) => c.setMode(s.first) : null,
                  showSelectedIcon: false,
                ),
              ),
              if (c.mode == 4)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('36 ورقة: بدون 2-6 كلفس وهاس، وبدون 2-5 سبيت وديمن',
                      textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim, fontSize: 13)),
                ),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [team(0), const SizedBox(width: 12), team(1)]),
              const SizedBox(height: 8),
              const Text('اضغط على مقعد فاضي عشان تنتقل له', textAlign: TextAlign.center, style: TextStyle(color: KoutColors.textDim, fontSize: 12)),
              const SizedBox(height: 20),
              if (c.isHost) ...[
                if (!full)
                  OutlinedButton.icon(
                    onPressed: c.addBots,
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('عبّي المقاعد الفاضية', style: TextStyle(fontSize: 16)),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: full ? c.start : null,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(full ? 'ابدأ اللعب' : 'بانتظار ${c.seats.where((s) => s == null).length} لاعبين'),
                ),
              ] else
                const Text('بانتظار المضيف يبدأ اللعبة...', textAlign: TextAlign.center),
              if (!c.connected) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('انقطع الاتصال، جاري إعادة الاتصال...', textAlign: TextAlign.center),
              ),
            ]),
          ),
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
        color: me ? KoutColors.surfaceHigh : KoutColors.surface,
        border: Border.all(color: me ? teamColor : KoutColors.line, width: me ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: canMove && !me ? () => client.sit(seat) : null,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            const SizedBox(width: 8),
            if (s == null)
              const Icon(Icons.event_seat_outlined, color: KoutColors.textDim, size: 26)
            else
              CharacterAvatar(charId: s['char'] as String?, size: 48, ring: teamColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s == null ? 'فاضي' : '${s['name']}${me ? ' (أنت)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: s == null ? KoutColors.textDim : KoutColors.text)),
            ),
            if (s != null && s['bot'] == true) const Icon(Icons.smart_toy, size: 18, color: KoutColors.textDim),
            if (client.isHost && s != null && !me)
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => client.kick(seat), tooltip: 'طرد'),
          ]),
        ),
      ),
    );
  }
}
