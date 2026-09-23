import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/settings/shop_settings.dart';

/// Shop profile: name, phone, address, currency symbol and logo.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _currency = TextEditingController();
  String _logoPath = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await ShopSettings.load();
    if (!mounted) return;
    setState(() {
      _name.text = s.shopName;
      _phone.text = s.phone;
      _address.text = s.address;
      _currency.text = s.currency;
      _logoPath = s.logoPath;
      _loading = false;
    });
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final saved = await ShopSettings.persistLogo(picked.path);
    if (!mounted) return;
    setState(() => _logoPath = saved);
  }

  Future<void> _save() async {
    final s = ShopSettings(
      shopName: _name.text.trim().isEmpty ? 'محلي' : _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      currency: _currency.text.trim().isEmpty ? 'ج.م' : _currency.text.trim(),
      logoPath: _logoPath,
    );
    await s.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المحل')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات المحل')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickLogo,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: _logoPath.isNotEmpty && File(_logoPath).existsSync()
                          ? FileImage(File(_logoPath))
                          : null,
                      child: _logoPath.isEmpty
                          ? const Icon(Icons.add_a_photo, size: 32)
                          : null,
                    ),
                  ),
                ),
                const Center(child: Text('اضغط لاختيار لوجو المحل (يظهر على الفواتير)')),
                const SizedBox(height: 16),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المحل *')),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'التليفون')),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان')),
                TextField(controller: _currency, decoration: const InputDecoration(labelText: 'العملة (مثال: ج.م، ر.س، \$)')),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _save, child: const Text('حفظ')),
              ],
            ),
    );
  }
}
