import 'package:flutter/material.dart';

/// Supported hardware terminal profiles
class DeviceProfile {
  /// Automatically detect screen aspect ratio & resolution
  static const String auto = 'auto';

  /// CA Solution CA H2 (GD215-H2) 21.5-inch vertical portrait kiosk (1080×1920)
  static const String caH2Kiosk = 'ca_h2_kiosk';

  /// POS CA9 15.6-inch horizontal countertop touch POS (1366×768)
  static const String ca9Desktop = 'ca9_desktop';

  /// Resolves whether the UI should render in Kiosk Mode (Tall / Portrait 21.5" CA H2)
  static bool isKiosk(BuildContext context, {String? deviceProfile}) {
    final profile = deviceProfile ?? auto;
    if (profile == caH2Kiosk) return true;
    if (profile == ca9Desktop) return false;

    // Auto-detect mode: inspect window orientation and size
    final size = MediaQuery.of(context).size;
    return size.height > size.width;
  }

  /// Get human-readable display label for profile
  static String getLabel(String profile) {
    switch (profile) {
      case caH2Kiosk:
        return 'CA H2 Kiosk (21.5" Portrait • 1080×1920)';
      case ca9Desktop:
        return 'POS CA9 Desktop (15.6" Landscape • 1366×768)';
      case auto:
      default:
        return 'Auto-Detect (Adaptive)';
    }
  }

  /// Get detailed description of layout characteristics
  static String getDescription(String profile) {
    switch (profile) {
      case caH2Kiosk:
        return 'Optimized for 21.5" vertical standing kiosk: 640px wide cards, 60px+ touch buttons, large touch numpads, prominent fonts.';
      case ca9Desktop:
        return 'Optimized for 15.6" countertop widescreen POS: 1366×768 compact vertical layout, 70/30 side-by-side split, fits without scrolling.';
      case auto:
      default:
        return 'Automatically adapts based on screen orientation: portrait = CA H2 Kiosk, landscape = POS CA9 Desktop.';
    }
  }

  /// Max card width for login / splash cards
  static double getCardMaxWidth(BuildContext context, {String? deviceProfile}) {
    return isKiosk(context, deviceProfile: deviceProfile) ? 640.0 : 420.0;
  }

  /// Primary action button height
  static double getButtonHeight(BuildContext context, {String? deviceProfile}) {
    return isKiosk(context, deviceProfile: deviceProfile) ? 60.0 : 46.0;
  }

  /// Store brand logo dimension
  static double getBrandLogoSize(BuildContext context, {String? deviceProfile}) {
    return isKiosk(context, deviceProfile: deviceProfile) ? 98.0 : 72.0;
  }
}
