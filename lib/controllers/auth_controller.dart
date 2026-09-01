import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  bool _isAdminAuthenticated = false;
  bool get isAdminAuthenticated => _isAdminAuthenticated;

  /// Authenticate against configured admin PIN
  bool authenticateAdmin(String enteredPin, String correctPin) {
    if (enteredPin.trim() == correctPin.trim()) {
      _isAdminAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void loginAsAdmin() {
    _isAdminAuthenticated = true;
    notifyListeners();
  }

  void loginAsCashier() {
    _isAdminAuthenticated = false;
    notifyListeners();
  }

  void lockAdmin() {
    _isAdminAuthenticated = false;
    notifyListeners();
  }
}
