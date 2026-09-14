import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  testWidgets('Test rendering extracted svg string with SvgPicture.string', (tester) async {
    final file = File('lib/assets/images/sprite.svg');
    final content = await file.readAsString();
    
    final regExp = RegExp(r'(<svg\s+[^>]*id="icon-pos"[^>]*>[\s\S]*?<\/svg>)');
    final match = regExp.firstMatch(content);
    expect(match != null, isTrue);
    final svgString = match!.group(1)!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SvgPicture.string(
              svgString,
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    print('SvgPicture rendered successfully!');
  });
}
