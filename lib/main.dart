import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app_config.dart';
import 'app/app_providers.dart';
import 'app/custom_scroll_behavior.dart';
import 'controllers/controllers.dart';
import 'database/database.dart';
import 'models/store_settings_model.dart';
import 'services/svg_sprite_service.dart';
import 'views/views.dart';
import 'widgets/inactivity_auto_lock_wrapper.dart';

// ============================================================================
// 1. PRIMARY CASHIER DISPLAY ENTRY POINT
// ============================================================================
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sprite Icons from sprite.svg for unified iconography
  try {
    await SvgSpriteService.instance.initialize();
  } catch (e) {
    debugPrint('SvgSpriteService init notice: $e');
  }

  // Initialize SQLite FFI for Windows & Linux desktop support
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    try {
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final dllPath = '$exeDir\\sqlite3.dll';
        if (File(dllPath).existsSync()) {
          DynamicLibrary.open(dllPath);
        }
      }
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('SQLite FFI initialization notice: $e');
    }
  }

  // Initialize SQLite Database schema & initial seeding
  try {
    await DbHelper().database;
  } catch (e) {
    debugPrint('Database connection notice: $e');
  }

  // Check if launched as Secondary Customer-Facing Display (CFD) Window
  if (args.contains('--cfd') ||
      args.contains('--customer-display') ||
      args.contains('--secondary')) {
    runApp(
      MultiProvider(
        providers: AppProviders.providers,
        child: const MaterialApp(
          title: 'POS Customer Display (CFD)',
          debugShowCheckedModeBanner: false,
          scrollBehavior: PosCustomScrollBehavior(),
          home: CustomerPresentationView(),
        ),
      ),
    );
    return;
  }

  // Enforce Landscape Orientation on Commercial Android POS Terminals
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(
    MultiProvider(providers: AppProviders.providers, child: const CashierApp()),
  );
}

class CartSettingsSync extends StatelessWidget {
  final Widget child;

  const CartSettingsSync({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = context.select<SettingsController, StoreSettingsModel>(
      (c) => c.settings,
    );
    final cart = context.read<CartController>();

    final hasTaxMismatch =
        (cart.taxRate - settings.defaultTaxRate).abs() > 0.0001;
    final hasCurrencyMismatch = cart.currencySymbol != settings.currencySymbol;

    if (hasTaxMismatch || hasCurrencyMismatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentSettings = context.read<SettingsController>().settings;
        final currentCart = context.read<CartController>();
        final taxMismatch =
            (currentCart.taxRate - currentSettings.defaultTaxRate).abs() >
            0.0001;
        final currencyMismatch =
            currentCart.currencySymbol != currentSettings.currencySymbol;

        if (taxMismatch || currencyMismatch) {
          currentCart.updateConfig(
            taxRate: currentSettings.defaultTaxRate,
            currencySymbol: currentSettings.currencySymbol,
          );
        }
      });
    }

    return child;
  }
}

class CashierApp extends StatelessWidget {
  const CashierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fontScale = context.select<SettingsController, double>(
      (c) => c.settings.fontSizeScale,
    );

    return CartSettingsSync(
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppConfig.lightTheme,
        scrollBehavior: const PosCustomScrollBehavior(),
        builder: (context, child) {
          return InactivityAutoLockWrapper(
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(fontScale)),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const SplashScreen(),
      ),
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
    MultiProvider(
      providers: AppProviders.providers,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: PosCustomScrollBehavior(),
        home: CustomerMainView(),
      ),
    ),
  );
}
