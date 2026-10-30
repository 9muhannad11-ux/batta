import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// إشارة (نوع أو أكثر، أو جوكر "J") أرسلها لاعب. تظهر للجميع ثانية ونص.
class SuitSignal {
  final int seat;
  final List<String> suits;
  final DateTime at = DateTime.now();
  SuitSignal(this.seat, this.suits);
}

const signalDuration = Duration(milliseconds: 1500);

/// الاتصال بالسيرفر وحالة الغرفة واللعبة.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  String serverUrl = '';
  String name = '';
  String? code;
  String? token;
  bool connected = false;
  bool _wantConnection = false;

  Map<String, dynamic>? room; // معلومات اللوبي
  Map<String, dynamic>? view; // حالة اللعبة الخاصة بهذا اللاعب
  final Map<int, SuitSignal> signals = {};
  // صاحب الجوكر الكبير أرسل إشارة الجوكر: ما تطلع فوقه، وورقته الجاية ينزل عليها كف
  final Set<int> slapPending = {};
  String? error;
  bool kicked = false;

  DateTime? deadline; // متى يخلص وقت اللاعب اللي عليه الدور

  int get mySeat => (room?['you'] as int?) ?? 0;
  bool get isHost => room?['isHost'] == true;
  bool get started => room?['started'] == true;
  int get mode => (room?['mode'] as int?) ?? 6;
  List get seats => (room?['seats'] as List?) ?? const [];

  Map? seatInfo(int seat) => seat < seats.length ? seats[seat] as Map? : null;

  String seatName(int seat) {
    final s = seatInfo(seat);
    return s == null ? 'فاضي' : s['name'] as String;
  }

  /// الثواني الباقية للاعب اللي عليه الدور
  double? get secondsLeft {
    final d = deadline;
    if (d == null) return null;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    return ms < 0 ? 0 : ms / 1000;
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    name = p.getString('name') ?? '';
    // على الويب السيرفر دايماً هو نفس الموقع. وعلى الجوال نستخدم رابط النسخة، إلا إذا اللاعب كتب رابط ثاني بنفسه
    // (المفتاح القديم 'server' ما نقرأه: نسخ قديمة حفظت فيه روابط غلط وكانت تمنع الاتصال)
    serverUrl = kIsWeb ? defaultServerUrl() : (p.getString('serverCustom') ?? defaultServerUrl());
    await p.remove('server');
  }

  static String defaultServerUrl() {
    // يمكن تحديده وقت البناء: --dart-define=SERVER_URL=ws://192.168.0.100:8080
    const fromBuild = String.fromEnvironment('SERVER_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    if (kIsWeb) {
      // نفس عنوان الصفحة: يشتغل محلياً وعبر رابط https (wss)
      final base = Uri.base;
      if (base.host.isEmpty) return 'ws://localhost:8080';
      final scheme = base.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'ws://10.0.2.2:8080'; // محاكي أندرويد
    return 'ws://localhost:8080';
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
    if (serverUrl.isEmpty || serverUrl == defaultServerUrl()) {
      await p.remove('serverCustom');
    } else {
      await p.setString('serverCustom', serverUrl);
    }
    if (code != null && token != null) {
      await p.setString('room', code!);
      await p.setString('token', token!);
    }
  }

  Future<void> createRoom() async {
    await _savePrefs();
    _open(() => _send({'t': 'create', 'name': name}));
  }

  Future<void> joinRoom(String roomCode) async {
    await _savePrefs();
    final p = await SharedPreferences.getInstance();
    // لو نفس الغرفة اللي كنا فيها، نرجع لمقعدنا
    final savedToken = p.getString('room') == roomCode ? p.getString('token') : null;
    _open(() => _send({'t': 'join', 'code': roomCode, 'name': name, 'token': ?savedToken}));
  }

  /// يحاول يتصل لين دقيقة ونص: سيرفر Render المجاني ينام إذا ما أحد يلعب، ويحتاج 30-60 ثانية يصحى
  static const _connectTries = 30;
  bool connecting = false;

  void _open(void Function() onOpen, {int attempt = 0}) {
    _wantConnection = true;
    error = null;
    kicked = false;
    connecting = true;
    _sub?.cancel();
    _ch?.sink.close();
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(Uri.parse(serverUrl));
    } catch (e) {
      connecting = false;
      error = 'رابط السيرفر غير صحيح';
      notifyListeners();
      return;
    }
    _ch = ch;
    notifyListeners();
    ch.ready.timeout(const Duration(seconds: 15)).then((_) {
      if (_ch != ch) return;
      connected = true;
      connecting = false;
      onOpen();
      notifyListeners();
    }).catchError((_) {
      if (_ch != ch || !_wantConnection) return;
      if (attempt + 1 < _connectTries) {
        // نعيد المحاولة: كل محاولة تصحّي السيرفر لين يرد
        Future.delayed(const Duration(seconds: 3), () {
          if (_wantConnection && !connected && _ch == ch) _open(onOpen, attempt: attempt + 1);
        });
      } else {
        connecting = false;
        error = 'ما قدرت أتصل بالسيرفر، تأكد من الإنترنت وحاول مرة ثانية';
        notifyListeners();
      }
    });
    _sub = ch.stream.listen(_onMessage, onDone: () { if (_ch == ch) _onDone(); }, onError: (_) { if (_ch == ch) _onDone(); });
  }

  void _onDone() {
    connected = false;
    notifyListeners();
    if (_wantConnection && code != null && token != null) {
      // إعادة الاتصال تلقائياً لنفس المقعد
      Future.delayed(const Duration(seconds: 2), () {
        if (!_wantConnection || connected) return;
        _open(() => _send({'t': 'join', 'code': code, 'token': token, 'name': name}));
      });
    }
  }

  void _onMessage(dynamic raw) {
    final m = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (m['t']) {
      case 'joined':
        code = m['code'] as String;
        token = m['token'] as String;
        _savePrefs();
      case 'room':
        room = m;
        if (m['started'] != true) view = null;
      case 'state':
        view = m['view'] as Map<String, dynamic>;
        final ms = view!['turnMsLeft'] as int?;
        deadline = ms == null ? null : DateTime.now().add(Duration(milliseconds: ms));
      case 'signal':
        final seat = m['seat'] as int;
        var incoming = (m['suits'] as List).cast<String>();
        if (m['big'] == true) {
          slapPending.add(seat);
          incoming = incoming.where((s) => s != 'J').toList();
          if (incoming.isEmpty) break;
        }
        // إذا اللاعب ضغط أكثر من نوع ورا بعض، تظهر كلها مع بعض ويتجدد الوقت
        final shown = signals[seat]?.suits ?? const <String>[];
        final sig = SuitSignal(seat, [...shown, ...incoming.where((s) => !shown.contains(s))]);
        signals[seat] = sig;
        Future.delayed(signalDuration, () {
          if (signals[sig.seat] == sig) {
            signals.remove(sig.seat);
            notifyListeners();
          }
        });
      case 'error':
        error = m['msg'] as String;
      case 'kicked':
        kicked = true;
        leave();
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) => _ch?.sink.add(jsonEncode(msg));

  void clearError() {
    error = null;
    notifyListeners();
  }

  // أوامر اللوبي
  void sit(int seat) => _send({'t': 'sit', 'seat': seat});
  void addBots() => _send({'t': 'addBots'});
  void kick(int seat) => _send({'t': 'kick', 'seat': seat});
  void start() => _send({'t': 'start'});
  void setMode(int mode) => _send({'t': 'mode', 'mode': mode});
  void rematch() => _send({'t': 'rematch'});

  // أوامر اللعب
  void bid(Object value) => _send({'t': 'bid', 'value': value});
  void chooseTrump(String suit) => _send({'t': 'trump', 'suit': suit});
  void play(String card) => _send({'t': 'play', 'card': card});
  void answerBawan(bool accept) => _send({'t': 'bawan', 'accept': accept});
  void signal(List<String> suits) => _send({'t': 'signal', 'suits': suits});

  void leave() {
    _wantConnection = false;
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    connected = false;
    connecting = false;
    room = null;
    view = null;
    code = null;
    token = null;
    notifyListeners();
  }
}
