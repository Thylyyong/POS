import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/settings_dao.dart';
import '../models/store_settings_model.dart';
import '../services/presentation_service.dart';

class SettingsController extends ChangeNotifier {
  final SettingsDao _settingsDao = SettingsDao();
  final PresentationService _presentationService = PresentationService();
  final ImagePicker _picker = ImagePicker();

  StoreSettingsModel _settings = const StoreSettingsModel();
  StoreSettingsModel get settings => _settings;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  SettingsController() {
    loadSettings();
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _settingsDao.getSettings();
      if (_settings.cfdEnabled) {
        await _presentationService.refreshDisplays();
      }
    } catch (e) {
      _error = 'Failed to load settings: $e';
      debugPrint('[SettingsController] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Save helpers ──────────────────────────────────────────────────────────

  /// Persists [newSettings], updates local state, and notifies listeners.
  Future<void> updateSettings(StoreSettingsModel newSettings) =>
      _save(newSettings);

  Future<void> toggleAutoPrint(bool value) =>
      _save(_settings.copyWith(autoPrintOnPayment: value));

  Future<void> toggleAutoKickDrawer(bool value) =>
      _save(_settings.copyWith(autoKickCashDrawer: value));

  Future<void> setFontSizeScale(double scale) =>
      _save(_settings.copyWith(fontSizeScale: scale));

  Future<void> setGridTemplate(String template) =>
      _save(_settings.copyWith(gridTemplate: template));

  Future<void> togglePaperSize(bool is80mm) =>
      _save(_settings.copyWith(isPaperSize80mm: is80mm));

  Future<void> updateAdminPin(String pin) =>
      _save(_settings.copyWith(adminPin: pin));

  Future<void> toggleCfd(bool enabled) async {
    await _save(_settings.copyWith(cfdEnabled: enabled));
    try {
      if (enabled) {
        await _presentationService.showCustomerDisplay();
      } else {
        await _presentationService.hideCustomerDisplay();
      }
    } catch (e) {
      _error = 'CFD toggle failed: $e';
      debugPrint('[SettingsController] $_error');
      notifyListeners();
    }
  }

  // ── Logo management ───────────────────────────────────────────────────────

  Future<void> pickStoreLogo() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'store_logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedFile =
          await File(pickedFile.path).copy('${appDir.path}/$fileName');

      await _save(_settings.copyWith(logoPath: savedFile.path));
    } catch (e) {
      _error = 'Failed to pick logo: $e';
      debugPrint('[SettingsController] $_error');
      notifyListeners();
    }
  }

  Future<void> removeStoreLogo() async {
    if (_settings.logoPath != null && _settings.logoPath!.isNotEmpty) {
      try {
        final file = File(_settings.logoPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Non-critical — proceed even if deletion fails
      }
    }
    await _save(_settings.copyWith(logoPath: ''));
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  /// Single-point persistence: update model, persist, notify — once.
  Future<void> _save(StoreSettingsModel s) async {
    try {
      _settings = s;
      await _settingsDao.saveSettings(_settings);
    } catch (e) {
      _error = 'Failed to save settings: $e';
      debugPrint('[SettingsController] $_error');
    }
    notifyListeners();
  }
}
