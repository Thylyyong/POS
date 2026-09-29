import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('Test extracting svg string from sprite.svg', () async {
    final file = File('lib/assets/images/sprite.svg');
    final content = await file.readAsString();
    
    final regExp = RegExp(r'(<svg\s+[^>]*id="icon-pos"[^>]*>[\s\S]*?<\/svg>)');
    final match = regExp.firstMatch(content);
    expect(match != null, isTrue);
    final svgString = match!.group(1)!;
    expect(svgString, isNotEmpty);
    expect(svgString.contains('id="icon-pos"'), isTrue);
  });
}
