import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_market_pro_max/core/theme/app_theme.dart';

void main() {
  testWidgets('app theme builds a themed scaffold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('سوبر ماركت برو ماكس')),
      ),
    );

    expect(find.text('سوبر ماركت برو ماكس'), findsOneWidget);
  });
}
