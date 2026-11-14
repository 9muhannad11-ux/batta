import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'avatars.dart';
import 'menus.dart';
import 'sounds.dart';
import 'store.dart' show MenuChip;

/// صديق محفوظ بالجهاز: كوده واسمه وشخصيته (آخر ما عرفناه)
class Friend {
  final String code;
  String name;
  String? char;
  Friend(this.code, this.name, [this.char]);
  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'char': char};
  static Friend fromJson(Map m) => Friend(m['code'] as String, m['name'] as String? ?? 'صديق', m['char'] as String?);
}

/// حالة الصديق: متصل، يلعب، بغرفة، أو مو متصل (null)
enum FriendStatus { online, playing, room }

/// الأصدقاء: كل جهاز له كود صداقة، والقائمة تنحفظ بالجهاز لين يصير فيه تسجيل دخول
class Friends extends ChangeNotifier {
  Friends._();
  static final instance = Friends._();

  String myCode = '';
  final List<Friend> list = [];
  final Map<String, FriendStatus> status = {}; // من السيرفر

  static String _newCode([Random? r]) {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بدون الحروف اللي تتلخبط (O و0، I و1)
    final rnd = r ?? Random.secure();
    return List.generate(6, (_) => abc[rnd.nextInt(abc.length)]).join();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    myCode = p.getString('friendCode') ?? '';
    if (myCode.isEmpty) {
      myCode = _newCode();
      await p.setString('friendCode', myCode);
    }
    list
      ..clear()
      ..addAll(((jsonDecode(p.getString('friends') ?? '[]') as List).cast<Map>()).map(Friend.fromJson));
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('friends', jsonEncode([for (final f in list) f.toJson()]));
  }

  static String clean(String code) => code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  /// إضافة بالكود: يرجع رسالة خطأ أو null إذا انضاف
  String? add(String code, {String? name, String? char}) {
    final c = clean(code);
    if (c.length != 6) return 'الكود 6 حروف وأرقام';
    if (c == myCode) return 'هذا كودك أنت';
    if (list.any((f) => f.code == c)) return 'موجود عندك';
    list.add(Friend(c, name ?? 'صديق', char));
    notifyListeners();
    _save();
    refresh();
    return null;
  }

  void remove(String code) {
    list.removeWhere((f) => f.code == code);
    status.remove(code);
    notifyListeners();
    _save();
  }

  int get onlineCount => list.where((f) => status[f.code] != null).length;

  /// الترتيب: المتصلين فوق (يلعب، بغرفة، متصل)، وبعدهم الباقي
  List<Friend> get sorted {
    int rank(Friend f) => switch (status[f.code]) { FriendStatus.online => 0, FriendStatus.room => 1, FriendStatus.playing => 2, null => 3 };
    return [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  // ---------- الاتصال بالسيرفر ----------
  // اتصال «حضور» خفيف طول ما اللعبة مفتوحة: يعرّف السيرفر بكودي، ويسأل عن أصدقائي كل 15 ثانية،
  // ويستقبل الدعوات لغرف الأصدقاء
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _poll, _retry;
  String _url = '', _name = '';
  String? _char;

  /// دعوة وصلتني من صديق لغرفته
  ({String from, String code})? invite;

  /// يبدأ الاتصال (أو يحدّث اسمي وشخصيتي إذا متصل)
  void start({required String url, required String name, String? char}) {
    _url = url;
    _name = name.trim();
    _char = char;
    if (_ch != null) return _hello();
    _connect();
  }

  void _connect() {
    _retry?.cancel();
    if (_url.isEmpty || _name.isEmpty || _ch != null) return;
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(Uri.parse(_url));
    } catch (_) {
      return _scheduleRetry();
    }
    _ch = ch;
    ch.ready.then((_) {
      if (_ch != ch) return;
      _hello();
      refresh();
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    }).catchError((_) {
      if (_ch == ch) _drop();
    });
    _sub = ch.stream.listen(_onMessage, onDone: () {
      if (_ch == ch) _drop();
    }, onError: (_) {
      if (_ch == ch) _drop();
    });
  }

  void _drop() {
    _ch = null;
    _sub?.cancel();
    _poll?.cancel();
    if (status.isNotEmpty) {
      status.clear();
      notifyListeners();
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 10), _connect);
  }

  void _send(Map<String, dynamic> m) {
    try {
      _ch?.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  void _hello() => _send({'t': 'hello', 'fc': myCode, 'name': _name, 'char': ?_char});

  /// نسأل السيرفر مين من أصدقائي متصل
  void refresh() {
    if (list.isNotEmpty) _send({'t': 'friends', 'list': [for (final f in list) f.code]});
  }

  void _onMessage(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (m['t']) {
      case 'friends':
        status.clear();
        var changed = false;
        (m['online'] as Map).forEach((code, v) {
          final st = switch ((v as Map)['s']) { 'playing' => FriendStatus.playing, 'room' => FriendStatus.room, _ => FriendStatus.online };
          status[code as String] = st;
          // اسمه وشخصيته مثل ما هو مسميها الحين
          for (final f in list.where((f) => f.code == code)) {
            final name = v['name'] as String?, char = v['char'] as String?;
            if (name != null && name != f.name) {
              f.name = name;
              changed = true;
            }
            if (char != null && char != f.char) {
              f.char = char;
              changed = true;
            }
          }
        });
        if (changed) _save();
        notifyListeners();
      case 'invited':
        invite = (from: m['from'] as String? ?? 'صديقك', code: m['code'] as String);
        notifyListeners();
    }
  }

  /// أدعو صديق متصل لغرفتي
  void inviteToRoom(String friendCode, String roomCode) => _send({'t': 'invite', 'to': friendCode, 'code': roomCode});

  void clearInvite() {
    invite = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(List<Friend> friends, Map<String, FriendStatus> st, {String? code}) {
    list
      ..clear()
      ..addAll(friends);
    status
      ..clear()
      ..addAll(st);
    if (code != null) myCode = code;
    notifyListeners();
  }
}

const _green = Color(0xFF4FCB6B), _orange = Color(0xFFF2A33A), _blue = Color(0xFF6FB2FF), _grey = Color(0xFF8A8D92);

({String label, Color color}) statusLook(FriendStatus? s) => switch (s) {
      FriendStatus.online => (label: 'متصل', color: _green),
      FriendStatus.playing => (label: 'يلعب الحين', color: _orange),
      FriendStatus.room => (label: 'بغرفة', color: _blue),
      null => (label: 'مو متصل', color: _grey),
    };

/// زر الأصدقاء فوق على اليسار: وعليه عدد المتصلين
class FriendsButton extends StatelessWidget {
  final VoidCallback onTap;
  const FriendsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Friends.instance,
        builder: (_, _) {
          final n = Friends.instance.onlineCount;
          return Pressable(child: OutlinedButton(
            onPressed: withTap(onTap),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), minimumSize: const Size(44, 44)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_alt, size: 22),
              if (n > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
                  child: Text('$n', style: const TextStyle(fontSize: 13, height: 1.2, color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
          ));
        },
      );
}

/// صفحة الأصدقاء: كودك، وإضافة صديق بكوده، والقائمة مع حالة كل واحد
class FriendsPage extends StatefulWidget {
  final VoidCallback onBack;
  const FriendsPage({super.key, required this.onBack});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _add() {
    final err = Friends.instance.add(_code.text);
    setState(() => _error = err);
    if (err == null) _code.clear();
  }

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.fromLTRB(14, 10, 14, 12)}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: padding,
        decoration: BoxDecoration(color: const Color(0xFF1B1C1F), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
        child: child,
      );

  Widget _friendTile(Friend f) {
    final s = Friends.instance.status[f.code];
    final look = statusLook(s);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(color: const Color(0xFF2A2C31), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Opacity(opacity: s == null ? 0.5 : 1, child: CharacterAvatar(charId: f.char, size: 42, ring: look.color)),
          Positioned(
            bottom: -1,
            left: -1,
            child: Container(width: 14, height: 14, decoration: BoxDecoration(color: look.color, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2A2C31), width: 2.5))),
          ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s == null ? const Color(0xFFAAAAAA) : Colors.white)),
            Text(look.label, style: TextStyle(fontSize: 13, color: look.color)),
          ]),
        ),
        Pressable(child: IconButton(
          tooltip: 'شيله',
          icon: const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
          onPressed: withTap(() => Friends.instance.remove(f.code)),
        )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Friends.instance,
        builder: (context, _) {
          final fr = Friends.instance;
          final online = fr.onlineCount;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: BackRow(title: 'الأصدقاء', onBack: widget.onBack)),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                    // كودك: ترسله لربعك عشان يضيفونك
                    _panel(
                      child: Row(children: [
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('كودك', style: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB))),
                            Text('أرسله لربعك عشان يضيفونك', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                          ]),
                        ),
                        Pressable(child: GestureDetector(
                          onTap: withTap(() {
                            Clipboard.setData(ClipboardData(text: fr.myCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('نسخت كودك', style: TextStyle(color: Colors.black, fontFamily: 'ElMessiri', fontSize: 18)),
                              backgroundColor: Colors.white,
                              duration: Duration(seconds: 2),
                            ));
                          }),
                          child: MenuChip(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(fr.myCode, style: const TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: 3, color: Color(0xFFFFE08A))),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy, size: 16, color: Color(0xFFBBBBBB)),
                            ]),
                          ),
                        )),
                      ]),
                    ),
                    // أضف صديق بكوده
                    _panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('أضف صديق', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _code,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              style: const TextStyle(fontSize: 20, letterSpacing: 4, color: Colors.white),
                              decoration: InputDecoration(hintText: 'كود صديقك', counterText: '', isDense: true, errorText: _error),
                              onSubmitted: (_) => _add(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Pressable(child: FilledButton.icon(
                            onPressed: withTap(_add),
                            icon: const Icon(Icons.person_add_alt_1, size: 20),
                            label: const Text('أضف', style: TextStyle(fontSize: 16)),
                          )),
                        ]),
                      ]),
                    ),
                    // القائمة: المتصلين فوق
                    _panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          const Text('أصدقاؤك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Spacer(),
                          Text('$online متصل من ${fr.list.length}', style: const TextStyle(fontSize: 13, color: _green)),
                        ]),
                        const SizedBox(height: 8),
                        if (fr.list.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('ما عندك أصدقاء للحين. أضفهم بكودهم، أو من الغرفة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))),
                          )
                        else
                          for (final f in fr.sorted) _friendTile(f),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// دعوة وصلت من صديق: بانر فوق الصفحة، «ادخل» يدخلك غرفته
class InviteBanner extends StatelessWidget {
  final void Function(String code) onJoin;
  const InviteBanner({super.key, required this.onJoin});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Friends.instance,
        builder: (_, _) {
          final inv = Friends.instance.invite;
          return Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => SlideTransition(position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(a), child: child),
              child: inv == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(inv.code),
                      margin: const EdgeInsets.only(top: 8, left: 12, right: 12),
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      constraints: const BoxConstraints(maxWidth: 460),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1C1F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFE08A), width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.mail, color: Color(0xFFFFE08A), size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('${inv.from} يدعوك لغرفته', maxLines: 2, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Pressable(child: FilledButton(
                          onPressed: withTap(() {
                            Friends.instance.clearInvite();
                            onJoin(inv.code);
                          }),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), minimumSize: const Size(0, 38)),
                          child: const Text('ادخل', style: TextStyle(fontSize: 16)),
                        )),
                        const SizedBox(width: 6),
                        Pressable(child: IconButton(
                          tooltip: 'لا',
                          icon: const Icon(Icons.close, color: Color(0xFFBBBBBB), size: 20),
                          onPressed: withTap(Friends.instance.clearInvite),
                        )),
                      ]),
                    ),
            ),
          );
        },
      );
}

/// بنافذة الدعوة بالغرفة: أصدقائي المتصلين، وجنب كل واحد «ادعه»
class FriendsToInvite extends StatefulWidget {
  final String roomCode;
  const FriendsToInvite({super.key, required this.roomCode});

  @override
  State<FriendsToInvite> createState() => _FriendsToInviteState();
}

class _FriendsToInviteState extends State<FriendsToInvite> {
  final Set<String> _sent = {};

  @override
  void initState() {
    super.initState();
    Friends.instance.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Friends.instance,
        builder: (_, _) {
          final fr = Friends.instance;
          // اللي يلعب الحين ما ندعيه (بنص مباراة)
          final online = fr.sorted.where((f) => fr.status[f.code] == FriendStatus.online || fr.status[f.code] == FriendStatus.room).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('أصدقاؤك المتصلون', style: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB))),
            const SizedBox(height: 6),
            if (online.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(fr.list.isEmpty ? 'ما عندك أصدقاء للحين' : 'ما فيه أحد متصل الحين', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final f in online)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          CharacterAvatar(charId: f.char, size: 32, ring: statusLook(fr.status[f.code]).color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.white))),
                          Pressable(child: FilledButton(
                            onPressed: _sent.contains(f.code)
                                ? null
                                : withTap(() {
                                    fr.inviteToRoom(f.code, widget.roomCode);
                                    setState(() => _sent.add(f.code));
                                  }),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: const Size(0, 32)),
                            child: Text(_sent.contains(f.code) ? 'انرسلت ✓' : 'ادعه', style: const TextStyle(fontSize: 14)),
                          )),
                        ]),
                      ),
                  ]),
                ),
              ),
          ]);
        },
      );
}
