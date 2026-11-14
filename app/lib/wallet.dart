import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// غرض بالمتجر: شخصية أو لون طاولة أو خلفية
class ShopItem {
  final String id;
  final String kind; // char / table / bg
  final String name;
  final int price; // بالغوازي (0 = مجاني)
  final String usd; // سعره بالفلوس الحقيقية (للعرض الحين، الشراء «قريباً»)
  const ShopItem(this.id, this.kind, this.name, this.price, this.usd);
}

/// ألوان وسط الطاولة: الأول هو الحالي ومجاني
class TableTheme {
  final String id, name;
  final List<Color> felt; // تدرج من الوسط للأطراف
  final Color edge; // لمعة حافة الخشب من جوا
  const TableTheme(this.id, this.name, this.felt, this.edge);
}

const tableThemes = [
  TableTheme('grey', 'رمادي', [Color(0xFFF7F8F9), Color(0xFFB9BCC0), Color(0xFF7A7F85)], Color(0xFFC08A55)),
  TableTheme('blue', 'أزرق ملكي', [Color(0xFF9CC4FF), Color(0xFF2F64C8), Color(0xFF14306E)], Color(0xFFC08A55)),
  TableTheme('maroon', 'عنابي', [Color(0xFFE79A9A), Color(0xFF8E2232), Color(0xFF4A0E18)], Color(0xFFC08A55)),
  TableTheme('black', 'أسود فاخر', [Color(0xFF6A6D72), Color(0xFF26282C), Color(0xFF0B0C0D)], Color(0xFFD4AF37)),
];

/// خلفية الطاولة: نفس الحصير بلون ثاني (null = الحصير الأصلي)
class BgTheme {
  final String id, name;
  final Color? tint;
  const BgTheme(this.id, this.name, this.tint);
}

const bgThemes = [
  BgTheme('mat', 'حصير', null),
  BgTheme('sand', 'رملي', Color(0xFFE8C98E)),
  BgTheme('navy', 'كحلي', Color(0xFF3A4E7A)),
  BgTheme('wood', 'خشب غامق', Color(0xFF7A4E2E)),
];

/// الشخصيات المقفلة وسعرها (الباقي مجاني)
const lockedChars = {'khalfan': 3000, 'bodhirs': 2500, 'marhoon': 2000, 'mundaghit': 1500, 'buhamdan': 1000};
const _charUsd = {'khalfan': '2.99\$', 'bodhirs': '2.49\$', 'marhoon': '1.99\$', 'mundaghit': '1.49\$', 'buhamdan': '0.99\$'};
const _tablePrices = {'blue': 300, 'maroon': 600, 'black': 1000};
const _bgPrices = {'sand': 300, 'navy': 600, 'wood': 1000};
const _colorUsd = {300: '0.49\$', 600: '0.99\$', 1000: '1.49\$'};

List<ShopItem> shopItems(Map<String, String> charNames) => [
      for (final e in lockedChars.entries) ShopItem(e.key, 'char', charNames[e.key] ?? e.key, e.value, _charUsd[e.key]!),
      for (final t in tableThemes.skip(1)) ShopItem(t.id, 'table', t.name, _tablePrices[t.id]!, _colorUsd[_tablePrices[t.id]]!),
      for (final b in bgThemes.skip(1)) ShopItem(b.id, 'bg', b.name, _bgPrices[b.id]!, _colorUsd[_bgPrices[b.id]]!),
    ];

/// مبالغ الدخول لكل نوع دور (من كم نقطة)
const stakeLevels = {54: [160, 400], 34: [100, 250]};

/// الغوازي والمشتريات: تنحفظ بالجهاز لين يصير فيه تسجيل دخول
class Wallet extends ChangeNotifier {
  Wallet._();
  static final instance = Wallet._();

  static const startBalance = 1000, dailyGift = 200;
  static const winBonus = 0.7; // الفايز يرجع له اللي حطه وفوقه 70%

  int balance = startBalance;
  final Set<String> owned = {}; // 'char:khalfan' / 'table:blue' / 'bg:sand'
  String table = 'grey', bg = 'mat';
  int stake = 0; // المبلغ المختار للبحث الجاي
  int? giftToday; // إذا انضافت هدية اليوم الحين (عشان نعلم اللاعب)

  // الجيم اللي حط فيه غوازي: كود الغرفة والمبلغ
  String? _stakeRoom;
  int? _stakeAmount;
  String? stakedRoom; // غرفة بحث أونلاين (كل مباراة فيها بغوازي)
  int? roomStake;

  TableTheme get tableTheme => tableThemes.firstWhere((t) => t.id == table, orElse: () => tableThemes.first);
  BgTheme get bgTheme => bgThemes.firstWhere((b) => b.id == bg, orElse: () => bgThemes.first);

  bool owns(String kind, String id) => switch (kind) {
        'char' => !lockedChars.containsKey(id) || owned.contains('char:$id'),
        'table' => id == tableThemes.first.id || owned.contains('table:$id'),
        _ => id == bgThemes.first.id || owned.contains('bg:$id'),
      };

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> load({DateTime? now}) async {
    final p = await SharedPreferences.getInstance();
    balance = p.getInt('ghawazi') ?? startBalance;
    owned
      ..clear()
      ..addAll(p.getStringList('owned') ?? const []);
    table = p.getString('tableTheme') ?? 'grey';
    bg = p.getString('bgTheme') ?? 'mat';
    _stakeRoom = p.getString('stakeRoom');
    _stakeAmount = p.getInt('stakeAmount');
    // أول فتح باليوم: هدية (أول مرة باللعبة ياخذ رصيد البداية بس)
    final today = _day(now ?? DateTime.now());
    final last = p.getString('giftDay');
    if (last != today) {
      if (last != null) {
        balance += dailyGift;
        giftToday = dailyGift;
      }
      await p.setString('giftDay', today);
    }
    // جيم كان شغال وانقفلت اللعبة: يعتبر خسارة (المبلغ انخصم من قبل)
    if (_stakeRoom != null) await _clearStake(p);
    await _save(p);
  }

  Future<void> _save([SharedPreferences? p]) async {
    p ??= await SharedPreferences.getInstance();
    await p.setInt('ghawazi', balance);
    await p.setStringList('owned', owned.toList());
    await p.setString('tableTheme', table);
    await p.setString('bgTheme', bg);
  }

  Future<void> _clearStake(SharedPreferences p) async {
    _stakeRoom = null;
    _stakeAmount = null;
    await p.remove('stakeRoom');
    await p.remove('stakeAmount');
  }

  void setStake(int v) => stake = v;

  /// شراء بالغوازي: يرجع false إذا الرصيد ما يكفي
  bool buy(ShopItem item) {
    if (owns(item.kind, item.id) || balance < item.price) return false;
    balance -= item.price;
    owned.add('${item.kind}:${item.id}');
    notifyListeners();
    _save();
    return true;
  }

  void equip(String kind, String id) {
    if (!owns(kind, id)) return;
    if (kind == 'table') table = id;
    if (kind == 'bg') bg = id;
    notifyListeners();
    _save();
  }

  /// جايزة (تحدي)
  void addGhawazi(int amount) {
    balance += amount;
    notifyListeners();
    _save();
  }

  /// قبل البحث عن لاعبين: يكفي الرصيد؟
  bool canEnter() => balance >= stake;

  /// بدأ البحث: كل مباراة بهالغرفة بنفس المبلغ
  void enterSearch() => roomStake = stake;

  /// تحديث من حالة اللعبة: يخصم أول ما تبدأ المباراة، ويعطي الفايز إذا خلصت
  Future<void> onState({required String? code, required String? phase, required int? winner, required int myTeam}) async {
    if (code == null || roomStake == null) return;
    stakedRoom ??= code;
    if (stakedRoom != code) return;
    final p = await SharedPreferences.getInstance();
    if (phase == 'matchEnd') {
      if (_stakeRoom != code || winner == null) return;
      if (winner == myTeam) {
        final payout = (_stakeAmount! * (1 + winBonus)).round();
        balance += payout;
        Progress.instance.addWinnings(payout - _stakeAmount!);
      }
      await _clearStake(p);
      await _save(p);
      notifyListeners();
      return;
    }
    if (_stakeRoom == code) return; // مخصوم من قبل
    if (balance < roomStake!) return; // ما يكفي لمباراة ثانية بنفس الغرفة: تنلعب بدون غوازي
    balance -= roomStake!;
    _stakeRoom = code;
    _stakeAmount = roomStake;
    await p.setString('stakeRoom', code);
    await p.setInt('stakeAmount', roomStake!);
    await _save(p);
    notifyListeners();
  }

  /// طلع من الغرفة: إذا المباراة ما خلصت راح اللي حطه
  Future<void> onLeave() async {
    roomStake = null;
    stakedRoom = null;
    if (_stakeRoom == null) return;
    await _clearStake(await SharedPreferences.getInstance());
    notifyListeners();
  }
}

/// رمز الغوازي: عملة ذهبية
class GhawaziIcon extends StatelessWidget {
  final double size;
  const GhawaziIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFFFFF1B0), Color(0xFFE2B33C), Color(0xFFA77A12)], stops: [0, 0.6, 1], center: Alignment(-0.3, -0.3)),
          border: Border.all(color: const Color(0xFF7A5608), width: size * 0.07),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
        ),
        alignment: Alignment.center,
        child: Text('غ', style: TextStyle(fontFamily: 'ElMessiri', fontSize: size * 0.52, height: 1, fontWeight: FontWeight.w800, color: const Color(0xFF6B4A05))),
      );
}

/// الرصيد: عملة ورقمها
class GhawaziAmount extends StatelessWidget {
  final int amount;
  final double size;
  final Color color;
  final bool label; // يكتب «غوازيك» قبل الرقم
  const GhawaziAmount(this.amount, {super.key, this.size = 18, this.color = Colors.white, this.label = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (label) ...[
          Text('غوازيك', style: TextStyle(fontFamily: 'ElMessiri', fontSize: size * 0.8, fontWeight: FontWeight.w700, color: color)),
          SizedBox(width: size * 0.4),
        ],
        GhawaziIcon(size: size * 1.15),
        SizedBox(width: size * 0.3),
        Text('$amount', style: TextStyle(fontFamily: 'ElMessiri', fontSize: size, fontWeight: FontWeight.w800, color: color)),
      ]);
}
