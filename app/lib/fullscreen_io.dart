import 'package:flutter/foundation.dart';

/// خارج المتصفح: ما فيه ملء شاشة (التطبيق أصلاً بالشاشة كلها)
class Fullscreen {
  static bool get supported => debugShow;
  /// للاختبارات والصور فقط
  static bool debugShow = false;
  static final ValueNotifier<bool> on = ValueNotifier(false);
  static void toggle() {}
}
