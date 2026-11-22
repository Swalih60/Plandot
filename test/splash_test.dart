import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ticklist/ui/splash.dart';

void main() {
  testWidgets('splash plays through and reveals the app', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: SplashGate(child: Scaffold(body: Text('APP'))),
    ));
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    }
    await t.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
    expect(find.byType(CustomPaint).evaluate().where((e) => e.widget.runtimeType == CustomPaint), isNotNull);
  });
}
