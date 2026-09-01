import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/controllers/auth_controller.dart';
import 'package:pos_flutter/views/cashier/widgets/product_grid.dart';
import 'package:pos_flutter/views/customer_display/customer_presentation_view.dart';

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
        home: CustomerPresentationView(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomerPresentationView), findsOneWidget);
    expect(find.text('TOTAL DUE'), findsOneWidget);
  });

  test('Product grid layout adapts to the available width', () {
    final compact = ProductGrid.resolveGridLayout(maxWidth: 500, gridTemplate: '4x6');
    final standard = ProductGrid.resolveGridLayout(maxWidth: 1000, gridTemplate: '4x6');
    final large = ProductGrid.resolveGridLayout(maxWidth: 1200, gridTemplate: '3x6');

    expect(compact.crossAxisCount, 2);
    expect(standard.crossAxisCount, 4);
    expect(large.crossAxisCount, 4);
    expect(large.childAspectRatio, greaterThan(0.7));
  });

  test('AuthController PIN authentication verifies master PIN correctly', () {
    final authCtrl = AuthController();
    expect(authCtrl.isAdminAuthenticated, false);

    // Wrong PIN
    final wrongResult = authCtrl.authenticateAdmin('0000', '1234');
    expect(wrongResult, false);
    expect(authCtrl.isAdminAuthenticated, false);

    // Correct PIN
    final correctResult = authCtrl.authenticateAdmin('1234', '1234');
    expect(correctResult, true);
    expect(authCtrl.isAdminAuthenticated, true);

    // Lock Admin
    authCtrl.lockAdmin();
    expect(authCtrl.isAdminAuthenticated, false);
  });
}


