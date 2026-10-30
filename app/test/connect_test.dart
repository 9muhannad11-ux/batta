import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kout/net.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an old saved server address is ignored (only one the player typed is kept)', () async {
    SharedPreferences.setMockInitialValues({'server': 'ws://10.0.2.2:8080', 'name': 'مهند'});
    final c = GameClient();
    await c.loadPrefs();
    expect(c.serverUrl, GameClient.defaultServerUrl());
    expect((await SharedPreferences.getInstance()).getString('server'), isNull);

    SharedPreferences.setMockInitialValues({'serverCustom': 'ws://192.168.0.5:8080'});
    final d = GameClient();
    await d.loadPrefs();
    expect(d.serverUrl, 'ws://192.168.0.5:8080');
  });

  test('keeps retrying while the server is still waking up, then connects', () async {
    SharedPreferences.setMockInitialValues({});
    // نحجز منفذ فاضي، والسيرفر ما يشتغل إلا بعد 4 ثواني (مثل Render وهو يصحى)
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final c = GameClient()
      ..name = 'مهند'
      ..serverUrl = 'ws://127.0.0.1:$port';
    unawaited(c.createRoom());
    await Future.delayed(const Duration(seconds: 1));
    expect(c.connecting, isTrue);
    expect(c.error, isNull);

    await Future.delayed(const Duration(seconds: 3));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final created = Completer<void>();
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((m) {
        if ((jsonDecode(m as String) as Map)['t'] == 'create') {
          ws.add(jsonEncode({'t': 'joined', 'code': '1234', 'token': 'x'}));
          if (!created.isCompleted) created.complete();
        }
      });
    });

    await created.future.timeout(const Duration(seconds: 15));
    await Future.delayed(const Duration(milliseconds: 300)); // رد السيرفر يوصل للعميل
    expect(c.connected, isTrue);
    expect(c.connecting, isFalse);
    expect(c.code, '1234');
    c.leave();
    await server.close(force: true);
  }, timeout: const Timeout(Duration(seconds: 40)));
}
