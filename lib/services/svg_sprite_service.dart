import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// High-performance SVG Sprite service that parses `sprite.svg`
/// and caches extracted standalone SVGs for instant rendering.
class SvgSpriteService {
  SvgSpriteService._();
  static final SvgSpriteService instance = SvgSpriteService._();

  final Map<String, String> _cache = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  int get iconCount => _cache.length;

  /// Initialize and parse `sprite.svg` into memory.
  Future<void> initialize() async {
    if (_isInitialized && _cache.isNotEmpty) return;

    String? svgContent;

    // 1. Try loading from assets
    final assetPaths = [
      'assets/images/sprite.svg',
      'lib/assets/images/sprite.svg',
      'assets/sprite.svg',
    ];

    for (final path in assetPaths) {
      try {
        svgContent = await rootBundle.loadString(path);
        if (svgContent.isNotEmpty) break;
      } catch (_) {
        // Try next path
      }
    }

    // 2. Fallback to direct File read if in tests or local execution
    if (svgContent == null || svgContent.isEmpty) {
      final filePaths = [
        'lib/assets/images/sprite.svg',
        'assets/images/sprite.svg',
      ];
      for (final p in filePaths) {
        try {
          final file = File(p);
          if (await file.exists()) {
            svgContent = await file.readAsString();
            if (svgContent.isNotEmpty) break;
          }
        } catch (_) {}
      }
    }

    if (svgContent != null && svgContent.isNotEmpty) {
      _parseSpriteContent(svgContent);
      _isInitialized = true;
    } else {
      if (kDebugMode) {
        print('SvgSpriteService: Failed to load sprite.svg from known locations.');
      }
    }
  }

  /// Synchronously parse SVG content string
  void parseFromString(String svgContent) {
    _parseSpriteContent(svgContent);
    _isInitialized = true;
  }

  void _parseSpriteContent(String content) {
    // Matches: <svg ...id="..."...>...</svg>
    final regExp = RegExp(r'<svg\s+([^>]*id="([^"]+)"[^>]*)>([\s\S]*?)<\/svg>');
    final matches = regExp.allMatches(content);

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
      _cache[id] = standaloneSvg;

      // Also register shorthand without "icon-" prefix
      if (id.startsWith('icon-')) {
        _cache[id.substring(5)] = standaloneSvg;
      }
    }

    if (kDebugMode) {
      print('SvgSpriteService: Successfully loaded ${_cache.length} sprite icon mappings.');
    }
  }

  /// Check if a sprite icon exists for [nameOrId]
  bool hasIcon(String nameOrId) {
    if (_cache.containsKey(nameOrId)) return true;
    if (_cache.containsKey('icon-$nameOrId')) return true;
    if (nameOrId.startsWith('icon-') && _cache.containsKey(nameOrId.substring(5))) return true;
    return false;
  }

  /// Get standalone SVG string for [nameOrId]
  String? getSvg(String nameOrId) {
    if (_cache.containsKey(nameOrId)) return _cache[nameOrId];
    final withPrefix = 'icon-$nameOrId';
    if (_cache.containsKey(withPrefix)) return _cache[withPrefix];
    if (nameOrId.startsWith('icon-')) {
      final withoutPrefix = nameOrId.substring(5);
      if (_cache.containsKey(withoutPrefix)) return _cache[withoutPrefix];
    }
    return null;
  }
}
