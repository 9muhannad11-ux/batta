import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// بالمتصفح: نشارك نص الدعوة (فيه الكود بس، بدون رابط الموقع)
class Invite {
  /// قائمة المشاركة (بالجوال: واتساب وسناب والرسايل...)
  static bool get canShare => (web.window.navigator as JSObject).has('share');
  static bool get canOpen => true;

  static Future<bool> share(String text) async {
    try {
      await web.window.navigator.share(web.ShareData(text: text)).toDart;
      return true;
    } catch (_) {
      return false; // اللاعب سكّر القائمة أو المتصفح ما يدعمها
    }
  }

  static void open(String url) => web.window.open(url, '_blank');
}
