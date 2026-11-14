/// بالتطبيق: الدعوة بنسخ الكود (بدون مكتبات زيادة)
class Invite {
  static bool get canShare => false;
  static bool get canOpen => false;
  static Future<bool> share(String text) async => false;
  static void open(String url) {}
}
