import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test sprite parsing and normalization', () async {
    final file = File('lib/assets/images/sprite.svg');
    final content = await file.readAsString();

    final regExp = RegExp(r'<svg\s+([^>]*id="([^"]+)"[^>]*)>([\s\S]*?)<\/svg>');
    final matches = regExp.allMatches(content);
    final icons = <String, String>{};

    for (final match in matches) {
      final attrs = match.group(1)!;
      final id = match.group(2)!;
      final inner = match.group(3)!;

      // Ensure xmlns is present on the extracted root svg
      var cleanAttrs = attrs;
      if (!cleanAttrs.contains('xmlns=')) {
        cleanAttrs = '$cleanAttrs xmlns="http://www.w3.org/2000/svg"';
      }

      final standaloneSvg = '<svg $cleanAttrs>$inner</svg>';
      icons[id] = standaloneSvg;
      if (id.startsWith('icon-')) {
        icons[id.substring(5)] = standaloneSvg;
      }
    }

    print('Extracted ${icons.length} mappings (full & short IDs)');
    expect(icons.containsKey('icon-pos'), isTrue);
    expect(icons.containsKey('pos'), isTrue);
    expect(icons.containsKey('icon-cash'), isTrue);
    expect(icons.containsKey('cash'), isTrue);
    expect(icons.containsKey('icon-settings'), isTrue);
    expect(icons.containsKey('settings'), isTrue);
    expect(icons.containsKey('icon-system'), isTrue);
    expect(icons.containsKey('system'), isTrue);
    expect(icons['system']!.contains('xmlns="http://www.w3.org/2000/svg"'), isTrue);
  });
}
