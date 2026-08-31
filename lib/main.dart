import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_config.dart';
import 'controllers/controllers.dart';
import 'database/database.dart';
import 'views/views.dart';

// Custom POS Scroll Behavior: Removes the "gummy/stretchy" overscroll distortion
// and provides crisp, solid clamping scroll physics for POS touchscreens & desktop.
class PosCustomScrollBehavior extends MaterialScrollBehavior {
  const PosCustomScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: ColorTheme.buttonPrimary.withValues(alpha: 0.2),
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ============================================================================
// 1. PRIMARY CASHIER DISPLAY ENTRY POINT
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows & Linux desktop support
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Enforce Landscape Orientation on Commercial Android POS Terminals
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Initialize SQLite Database schema & initial seeding
  await DbHelper().database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => CartController()),
        ChangeNotifierProvider(create: (_) => PosController()),
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => TableController()),
      ],
      child: const CashierApp(),
    ),
  );
}

class CashierApp extends StatelessWidget {
  const CashierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fontScale = context.select<SettingsController, double>(
      (c) => c.settings.fontSizeScale,
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppConfig.lightTheme,
      scrollBehavior: const PosCustomScrollBehavior(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}

// ============================================================================
// 2. SECONDARY CUSTOMER-FACING DISPLAY (CFD) ENTRY POINT
// ============================================================================
@pragma('vm:entry-point')
void secondaryDisplayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: PosCustomScrollBehavior(),
      home: CustomerMainView(),
    ),
  );
}
