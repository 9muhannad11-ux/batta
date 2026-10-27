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
    // على الويب السيرفر دايماً هو نفس الموقع، فما نعتمد على رابط محفوظ قديم
    serverUrl = kIsWeb ? defaultServerUrl() : (p.getString('server') ?? defaultServerUrl());
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
    await p.setString('server', serverUrl);
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

  void _open(void Function() onOpen) {
    _wantConnection = true;
    error = null;
    kicked = false;
    _sub?.cancel();
    _ch?.sink.close();
    try {
      _ch = WebSocketChannel.connect(Uri.parse(serverUrl));
    } catch (e) {
      error = 'رابط السيرفر غير صحيح';
      notifyListeners();
      return;
    }
    _ch!.ready.then((_) {
      connected = true;
      onOpen();
      notifyListeners();
    }).catchError((_) {
      error = 'ما قدرت أتصل بالسيرفر';
      notifyListeners();
    });
    _sub = _ch!.stream.listen(_onMessage, onDone: _onDone, onError: (_) => _onDone());
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
        final incoming = (m['suits'] as List).cast<String>();
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
    room = null;
    view = null;
    code = null;
    token = null;
    notifyListeners();
  }
}
