import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility class for converting images into high-contrast monochrome (pure 1-bit Black & White)
/// specially optimized for physical thermal receipt printers (203 DPI heads).
///
/// Thermal printer pins can only burn black dots or leave white space.
/// Color images (blue, red, orange, green, gold, gray) normally cause printer drivers
/// to halftone/dither or drop dots, causing the logo to appear faint, fragmented, or missing.
/// This helper converts all logo elements into solid, crisp black dots on a pure white background.
class ThermalImageHelper {
  /// Converts an [img.Image] in-memory to pure Black & White.
  ///
  /// - Blends transparency with a solid pure white background (255, 255, 255).
  /// - Any pixel darker than [threshold] (0-255) becomes pure solid Black (0, 0, 0).
  /// - Any pixel at or above [threshold] becomes pure White (255, 255, 255).
  /// - If [invert] is true, dark and light are swapped.
  static img.Image convertToMonochromeImage(
    img.Image image, {
    int threshold = 210,
    bool invert = false,
  }) {
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a;

        double r, g, b;
        if (a < 30) {
          // Transparent or nearly transparent pixel -> blend to pure white paper
          r = 255.0;
          g = 255.0;
          b = 255.0;
        } else if (a < 255) {
          // Semi-transparent pixel -> alpha blend with white background
          final alphaNorm = a / 255.0;
          r = pixel.r * alphaNorm + 255.0 * (1.0 - alphaNorm);
          g = pixel.g * alphaNorm + 255.0 * (1.0 - alphaNorm);
          b = pixel.b * alphaNorm + 255.0 * (1.0 - alphaNorm);
        } else {
          r = pixel.r.toDouble();
          g = pixel.g.toDouble();
          b = pixel.b.toDouble();
        }

        // Standard ITU-R BT.601 perceived luminance
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;

        bool isBlack;
        if (!invert) {
          // Non-white logo elements (text, graphics, colors) -> solid black
          isBlack = lum < threshold;
        } else {
          isBlack = lum >= threshold;
        }

        if (isBlack) {
          image.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          image.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    return image;
  }

  /// Converts raw image bytes (PNG, JPEG, etc.) into pure Black & White PNG bytes.
  ///
  /// Optionally resizes to [targetWidth] (e.g. 260 for 80mm roll, 180 for 58mm roll)
  /// maintaining aspect ratio.
  static Uint8List convertToMonochromeLogoBytes(
    Uint8List rawBytes, {
    int threshold = 210,
    int? targetWidth,
    bool invert = false,
  }) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      img.Image working = decoded;
      if (targetWidth != null && targetWidth > 0 && targetWidth != decoded.width) {
        working = img.copyResize(decoded, width: targetWidth);
      }

      final monochrome = convertToMonochromeImage(
        working,
        threshold: threshold,
        invert: invert,
      );

      final pngBytes = img.encodePng(monochrome);
      return Uint8List.fromList(pngBytes);
    } catch (_) {
      return rawBytes;
    }
  }
}
