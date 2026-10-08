import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility class for converting images into high-contrast monochrome (pure 1-bit Black & White)
/// specially optimized for physical thermal receipt printers (203 DPI heads).
///
/// Thermal printer pins can only burn black dots or leave white space.
/// Color images (blue, red, orange, green, gold, gray) normally cause printer drivers
/// to halftone or drop dots, causing the logo to appear faint, fragmented, or missing.
/// This helper converts logo elements into solid, crisp black dots on a pure white background.
class ThermalImageHelper {
  /// Converts an [img.Image] to pure Black & White using Floyd-Steinberg dithering
  /// and crisp alpha blending with pure white background.
  ///
  /// - Blends transparency with pure white (255, 255, 255) so paper stays clean.
  /// - Applies Floyd-Steinberg error diffusion dithering for smooth gradients and crisp logo edges.
  static img.Image convertToMonochromeImage(
    img.Image image, {
    int threshold = 140,
    bool invert = false,
    bool useDithering = true,
  }) {
    final width = image.width;
    final height = image.height;

    final result = img.Image(width: width, height: height, numChannels: 4);

    if (useDithering) {
      // Dithering needs neighboring luminance values, so only allocate its
      // working buffer when the caller asks for it.
      final luminance = List<List<double>>.generate(
        height,
        (_) => List<double>.filled(width, 255.0),
      );
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final p = image.getPixel(x, y);
          final a = p.a;
          if (a >= 30) {
            final alphaNorm = a / 255.0;
            final r = p.r * alphaNorm + 255.0 * (1.0 - alphaNorm);
            final g = p.g * alphaNorm + 255.0 * (1.0 - alphaNorm);
            final b = p.b * alphaNorm + 255.0 * (1.0 - alphaNorm);
            luminance[y][x] = 0.299 * r + 0.587 * g + 0.114 * b;
          }
        }
      }
      // 2. Floyd-Steinberg Error Diffusion Dithering
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final oldVal = luminance[y][x];
          final newVal = oldVal < threshold ? 0.0 : 255.0;
          final error = oldVal - newVal;

          final bool isBlack = invert ? (newVal == 255.0) : (newVal == 0.0);
          if (isBlack) {
            result.setPixelRgba(x, y, 0, 0, 0, 255);
          } else {
            result.setPixelRgba(x, y, 255, 255, 255, 255);
          }

          // Distribute error to neighboring pixels
          if (x + 1 < width) {
            luminance[y][x + 1] += error * 7.0 / 16.0;
          }
          if (y + 1 < height) {
            if (x > 0) {
              luminance[y + 1][x - 1] += error * 3.0 / 16.0;
            }
            luminance[y + 1][x] += error * 5.0 / 16.0;
            if (x + 1 < width) {
              luminance[y + 1][x + 1] += error * 1.0 / 16.0;
            }
          }
        }
      }
    } else {
      // Simple high-contrast thresholding
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final p = image.getPixel(x, y);
          final a = p.a;
          final alphaNorm = a / 255.0;
          final lum = a < 30
              ? 255.0
              : 0.299 * (p.r * alphaNorm + 255.0 * (1.0 - alphaNorm)) +
                    0.587 * (p.g * alphaNorm + 255.0 * (1.0 - alphaNorm)) +
                    0.114 * (p.b * alphaNorm + 255.0 * (1.0 - alphaNorm));
          final bool isBlack = invert ? (lum >= threshold) : (lum < threshold);
          if (isBlack) {
            result.setPixelRgba(x, y, 0, 0, 0, 255);
          } else {
            result.setPixelRgba(x, y, 255, 255, 255, 255);
          }
        }
      }
    }

    return result;
  }

  /// Converts raw image bytes (PNG, JPEG, ICO, etc.) into pure Black & White PNG bytes.
  /// When [targetWidth] is supplied, it is preserved as-is so callers can keep
  /// the exact size they want for preview/export workflows.
  static Uint8List convertToMonochromeLogoBytes(
  Uint8List rawBytes, {
    int threshold = 140,
    int? targetWidth,
    bool invert = false,
    bool useDithering = true,
  }) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    img.Image working = decoded;
    if (targetWidth != null && targetWidth > 0) {
      working = img.copyResize(
        decoded,
        width: targetWidth,
        interpolation: img.Interpolation.linear,
      );
    }

      final monochrome = convertToMonochromeImage(
        working,
        threshold: threshold,
        invert: invert,
        useDithering: useDithering,
      );

      final pngBytes = img.encodePng(monochrome);
      return Uint8List.fromList(pngBytes);
    } catch (_) {
      return rawBytes;
    }
  }
}
