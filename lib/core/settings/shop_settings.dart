import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shop profile shown on invoices (name, phone, address, currency, logo).
class ShopSettings {
  final String shopName;
  final String phone;
  final String address;
  final String currency;
  final String logoPath;

  const ShopSettings({
    this.shopName = 'محلي',
    this.phone = '',
    this.address = '',
    this.currency = 'ج.م',
    this.logoPath = '',
  });

  static const _kName = 'shop_name';
  static const _kPhone = 'shop_phone';
  static const _kAddress = 'shop_address';
  static const _kCurrency = 'shop_currency';
  static const _kLogo = 'shop_logo';

  static Future<ShopSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShopSettings(
      shopName: prefs.getString(_kName) ?? 'محلي',
      phone: prefs.getString(_kPhone) ?? '',
      address: prefs.getString(_kAddress) ?? '',
      currency: prefs.getString(_kCurrency) ?? 'ج.م',
      logoPath: prefs.getString(_kLogo) ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, shopName);
    await prefs.setString(_kPhone, phone);
    await prefs.setString(_kAddress, address);
    await prefs.setString(_kCurrency, currency);
    await prefs.setString(_kLogo, logoPath);
  }

  String money(double value) => '${value.toStringAsFixed(2)} $currency';

  bool get hasLogo => logoPath.isNotEmpty && File(logoPath).existsSync();

  /// Copies a picked logo into app storage and returns the new path.
  static Future<String> persistLogo(String pickedPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(pickedPath);
    final dest = p.join(dir.path, 'shop_logo$ext');
    await File(pickedPath).copy(dest);
    return dest;
  }
}
