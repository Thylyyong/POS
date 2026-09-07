import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../controllers/controllers.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
    ChangeNotifierProvider(create: (_) => AuthController()),
    ChangeNotifierProvider(create: (_) => SettingsController()),
    ChangeNotifierProvider(create: (_) => RegisterController()),
    ChangeNotifierProvider(create: (_) => AccountingController()),
    ChangeNotifierProvider(create: (_) => CartController()),
    ChangeNotifierProvider(create: (_) => PosController()),
    ChangeNotifierProvider(create: (_) => DashboardController()),
    ChangeNotifierProvider(create: (_) => TableController()),
  ];
}
