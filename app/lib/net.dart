import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'progress.dart';
import 'wallet.dart';

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
  String? char; // الشخصية اللي اختارها اللاعب (تنحفظ وتنرسل مع كل دخول)
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

  // الأنميشن ما تتأثر بالاتصال:
  // 1) حركتي (رمي ورقة، مزايدة، حكم، باون) تبين على طول بدون ما تنتظر رد السيرفر
  // 2) لو وصلت حالات ورا بعض (النت علّق وفك)، كل وحدة تنتظر أنميشن اللي قبلها يخلص
  Map<String, dynamic>? _serverView; // آخر حالة من السيرفر (نرجع لها لو رفض حركتي)
  final List<({Map<String, dynamic> view, DateTime at})> _pending = [];
  DateTime _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pendingTimer;

  int get mySeat => (room?['you'] as int?) ?? 0;
  bool get isHost => room?['isHost'] == true;
  bool get started => room?['started'] == true;
  bool get searching => room?['search'] == true;
  bool get practicing => room?['practice'] == true;
  DateTime? searchEnds; // متى يخلص البحث وتكمّل البوتات
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

  bool intro = true; // أنميشن الشعار عند الفتح

  Future<void> setIntro(bool on) async {
    intro = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool('intro', on);
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    name = p.getString('name') ?? '';
    char = p.getString('char');
    // شخصية مقفلة (ما انشرت): ما تنستخدم
    if (char != null && !Wallet.instance.owns('char', char!)) char = null;
    intro = p.getBool('intro') ?? true;
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

  /// اسم اللاعب (مثل الحساب): ينكتب أول مرة وينحفظ، ويتغير من التفضيلات
  Future<void> saveName(String value) async {
    name = value.trim();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
  }

  Future<void> createRoom() async {
    Wallet.instance.roomStake = null;
    await _savePrefs();
    _open(() => _send({'t': 'create', 'name': name, 'char': ?char}));
  }

  /// بحث عن لاعبين: mode 6 أو 4، و score هدف المباراة 54 أو 34
  Future<void> search(int mode, int score) async {
    Wallet.instance.enterSearch();
    await _savePrefs();
    _open(() => _send({'t': 'search', 'mode': mode, 'score': score, 'name': name, 'char': ?char}));
  }

  /// تدريب مع البوتات بدون وقت
  Future<void> practice(int mode) async {
    Wallet.instance.roomStake = null;
    await _savePrefs();
    _open(() => _send({'t': 'practice', 'mode': mode, 'name': name, 'char': ?char}));
  }

  Future<void> joinRoom(String roomCode) async {
    Wallet.instance.roomStake = null;
    await _savePrefs();
    final p = await SharedPreferences.getInstance();
    // لو نفس الغرفة اللي كنا فيها، نرجع لمقعدنا
    final savedToken = p.getString('room') == roomCode ? p.getString('token') : null;
    _open(() => _send({'t': 'join', 'code': roomCode, 'name': name, 'token': ?savedToken, 'char': ?char}));
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
        if (m['started'] != true) {
          view = null;
          _resetPending();
        }
        final searchMs = m['searchMsLeft'] as int?;
        searchEnds = searchMs == null ? null : DateTime.now().add(Duration(milliseconds: searchMs));
      case 'state':
        _pending.add((view: m['view'] as Map<String, dynamic>, at: DateTime.now()));
        _drain();
        return;
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
        // السيرفر رفض حركتي: نرجع للحالة الصحيحة
        if (_serverView != null) view = _serverView;
      case 'kicked':
        kicked = true;
        leave();
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) => _ch?.sink.add(jsonEncode(msg));

  /// الحالات اللي وصلت تنطبق بالترتيب، وكل وحدة تنتظر لين يخلص أنميشن اللي قبلها
  void _drain() {
    _pendingTimer?.cancel();
    while (_pending.isNotEmpty) {
      final wait = _holdUntil.difference(DateTime.now());
      if (wait > Duration.zero) {
        _pendingTimer = Timer(wait, _drain);
        return;
      }
      final next = _pending.removeAt(0);
      _applyState(next.view, next.at);
    }
  }

  void _resetPending() {
    _pending.clear();
    _pendingTimer?.cancel();
    _holdUntil = DateTime.fromMillisecondsSinceEpoch(0);
    _serverView = null;
  }

  void _applyState(Map<String, dynamic> v, DateTime receivedAt) {
    final before = _serverView;
    _serverView = v;
    view = v;
    // الوقت من لحظة وصول الرسالة، مو من لحظة تطبيقها
    final ms = v['turnMsLeft'] as int?;
    deadline = ms == null ? null : receivedAt.add(Duration(milliseconds: ms));
    _holdUntil = DateTime.now().add(Duration(milliseconds: _animMs(before, v)));
    // الإحصائيات قبل المحفظة (المحفظة تنسى المبلغ بعد نهاية المباراة)
    Progress.instance.onState(code: code, view: v, mySeat: mySeat, online: Wallet.instance.roomStake != null);
    Wallet.instance.onState(code: code, phase: v['phase'] as String?, winner: v['winner'] as int?, myTeam: mySeat % 2);
    notifyListeners();
  }

  /// كم ياخذ أنميشن التغيير من الحالة اللي قبل لهذي (توزيع، لمّ لمّة، طيران ورقة)
  static int _animMs(Map<String, dynamic>? a, Map<String, dynamic> b) {
    if (a == null) return 0;
    if (b['round'] != a['round'] && b['phase'] == 'bidding' && (b['bids'] as List).isEmpty) return 2650;
    if (b['round'] == a['round'] && (b['trickNo'] as int) > (a['trickNo'] as int)) return 2250;
    if (b['round'] == a['round'] && (b['trick'] as List).length > (a['trick'] as List).length) return 240;
    return 0;
  }

  /// حركتي تبين على طول: نعدّل الحالة عندنا لين يرد السيرفر بالحالة الصحيحة
  void _optimistic(Map<String, dynamic> Function(Map<String, dynamic> v) change) {
    final v = view;
    if (v == null) return;
    view = change(Map.of(v));
    deadline = null;
    notifyListeners();
  }


  void clearError() {
    error = null;
    notifyListeners();
  }

  // أوامر اللوبي
  void sit(int seat) => _send({'t': 'sit', 'seat': seat});
  Future<void> chooseChar(String id) async {
    char = id;
    if (room != null) _send({'t': 'char', 'char': id});
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('char', id);
  }
  void addBots() => _send({'t': 'addBots'});
  void kick(int seat) => _send({'t': 'kick', 'seat': seat});
  void start() => _send({'t': 'start'});
  void setMode(int mode) => _send({'t': 'mode', 'mode': mode});
  void rematch() => _send({'t': 'rematch'});

  // أوامر اللعب
  void bid(Object value) {
    _send({'t': 'bid', 'value': value});
    if (!((view?['legalBids'] as List?)?.contains(value) ?? false)) return;
    _optimistic((v) => v
      ..['bids'] = [...v['bids'] as List, {'seat': mySeat, 'bid': value}]
      ..['legalBids'] = const []
      ..['turn'] = -1);
  }

  void chooseTrump(String suit) {
    _send({'t': 'trump', 'suit': suit});
    final v = view;
    if (v == null || v['phase'] != 'trump' || v['buyer'] != mySeat) return;
    _optimistic((v) => v
      ..['trump'] = suit
      ..['phase'] = 'playing'
      ..['legalCards'] = const []
      ..['turn'] = (mySeat + 1) % (v['players'] as int)); // أول واحد على يمين الشاري يبدأ
  }

  void play(String card) {
    _send({'t': 'play', 'card': card});
    final v = view;
    if (v == null || v['phase'] != 'playing' || v['turn'] != mySeat || !(v['legalCards'] as List).contains(card)) return;
    _optimistic((v) => v
      ..['hand'] = [for (final h in v['hand'] as List) if (h != card) h]
      ..['trick'] = [...v['trick'] as List, {'seat': mySeat, 'card': card}]
      ..['legalCards'] = const []
      // الدور للي بعدي، إلا إذا خلصت اللمّة (الفايز يعرفه السيرفر)
      ..['turn'] = (v['trick'] as List).length + 1 < (v['players'] as int) ? (mySeat + 1) % (v['players'] as int) : -1);
  }

  void answerBawan(bool accept) {
    _send({'t': 'bawan', 'accept': accept});
    _optimistic((v) => v..['bawanOffer'] = false);
  }
  void signal(List<String> suits) => _send({'t': 'signal', 'suits': suits});

  void leave() {
    Wallet.instance.onLeave();
    _wantConnection = false;
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    connected = false;
    connecting = false;
    room = null;
    view = null;
    _resetPending();
    code = null;
    token = null;
    notifyListeners();
  }
}
