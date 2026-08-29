import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/views/customer_display/customer_main_view.dart';

void main() {
  testWidgets('Customer display entry point renders successfully', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerMainView(),
      ),
    );
    await tester.pump();
    expect(find.text('The Culinary Canvas'), findsWidgets);
    expect(find.text('Live Customer Display'), findsOneWidget);
  });
}


