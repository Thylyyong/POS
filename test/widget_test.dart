import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/views/customer_display/customer_main_view.dart';

void main() {
  testWidgets('Customer display entry point renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const CustomerMainView());
    expect(find.text('CUSTOMER DISPLAY'), findsOneWidget);
    expect(find.text('Welcome!'), findsOneWidget);
  });
}
