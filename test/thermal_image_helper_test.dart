import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_flutter/services/thermal_image_helper.dart';

void main() {
  test('ThermalImageHelper converts colored image with transparency into solid B&W', () {
    // Create image with:
    // Pixel (0,0): Transparent
    // Pixel (1,0): Blue
    // Pixel (2,0): Pure White
    final image = img.Image(width: 3, height: 1, numChannels: 4);
    image.setPixelRgba(0, 0, 0, 0, 0, 0); // transparent
    image.setPixelRgba(1, 0, 0, 100, 255, 255); // blue
    image.setPixelRgba(2, 0, 255, 255, 255, 255); // pure white

    final mono = ThermalImageHelper.convertToMonochromeImage(image, threshold: 210);

    // Pixel (0,0) transparent should become pure white (paper background)
    final p0 = mono.getPixel(0, 0);
    expect(p0.r, 255);
    expect(p0.g, 255);
    expect(p0.b, 255);

    // Pixel (1,0) blue should become solid black (thermal burn)
    final p1 = mono.getPixel(1, 0);
    expect(p1.r, 0);
    expect(p1.g, 0);
    expect(p1.b, 0);

    // Pixel (2,0) white should stay pure white
    final p2 = mono.getPixel(2, 0);
    expect(p2.r, 255);
    expect(p2.g, 255);
    expect(p2.b, 255);
  });

  test('ThermalImageHelper.convertToMonochromeLogoBytes produces valid PNG', () {
    final image = img.Image(width: 10, height: 10, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(200, 50, 50, 255));
    final png = img.encodePng(image);

    final monoBytes = ThermalImageHelper.convertToMonochromeLogoBytes(
      Uint8List.fromList(png),
      threshold: 210,
      targetWidth: 20,
    );

    expect(monoBytes, isNotEmpty);
    final decoded = img.decodeImage(monoBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 20);
    // Red color should be converted to black
    final p = decoded.getPixel(5, 5);
    expect(p.r, 0);
    expect(p.g, 0);
    expect(p.b, 0);
  });
}
