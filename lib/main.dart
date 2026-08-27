import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'controllers/controllers.dart';
import 'database/database.dart';
import 'views/views.dart';

// ============================================================================
// 1. PRIMARY CASHIER DISPLAY ENTRY POINT
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce Landscape Orientation on Commercial Android POS Terminals
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppConfig.lightTheme,
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
      home: CustomerMainView(),
    ),
  );
}
