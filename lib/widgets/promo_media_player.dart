import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win_plugin.dart';

import '../models/store_settings_model.dart';

/// Versatile promotional media player capable of rendering both videos and images.
/// - Automatically detects Video vs Image based on extension.
/// - Controls hardware video playback (auto-play, looping, muted for retail display).
/// - Supports full screen edge-to-edge display (BoxFit.cover / BoxFit.fill) with NO side bars.
/// - Robust multi-path resolution (file://, assets/, http://, Windows backslashes).
/// - Transparent error reporting for missing media files instead of silently falling back
///   to stale/old demo images.
class PromoMediaPlayer extends StatefulWidget {
  final String mediaPath;
  final int index;
  final bool showFull;
  final BoxFit fit;
  final bool autoPlay;
  final bool loop;
  final bool muted;

  const PromoMediaPlayer({
    super.key,
    required this.mediaPath,
    this.index = 0,
    this.showFull = false,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.loop = true,
    this.muted = true,
  });

  /// Check if the path is a supported video format
  static bool isVideo(String path) {
    final clean = path.trim().toLowerCase().split('?').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.m4v') ||
        clean.endsWith('.wmv') ||
        clean.endsWith('.3gp');
  }

  /// Sanitizes and normalizes media path across Windows & POS environments
  static String sanitizePath(String path) {
    var p = path.trim();
    // Strip surrounding quotes
    if ((p.startsWith('"') && p.endsWith('"')) ||
        (p.startsWith("'") && p.endsWith("'"))) {
      p = p.substring(1, p.length - 1).trim();
    }
    // Handle file:// URIs
    if (p.startsWith('file:///')) {
      try {
        p = Uri.parse(p).toFilePath();
      } catch (_) {
        p = p.replaceFirst('file:///', '');
      }
    } else if (p.startsWith('file://')) {
      try {
        p = Uri.parse(p).toFilePath();
      } catch (_) {
        p = p.replaceFirst('file://', '');
      }
    }
    return p;
  }

  /// Fallback bundled promotion banner asset
  static String getFallbackAsset(int index) {
    final list = StoreSettingsModel.defaultPromoBanners;
    if (list.isEmpty) return 'assets/images/asian_mains.png';
    return list[index.abs() % list.length];
  }

  static String? _cachedDocPath;

  static Future<void> _ensureDocPath() async {
    if (_cachedDocPath == null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _cachedDocPath = dir.path;
      } catch (_) {}
    }
  }

  /// Resolves local media files across Android scoped storage, documents, and cache
  static File? resolveLocalFile(String rawPath) {
    if (rawPath.trim().isEmpty) return null;
    final clean = rawPath.trim();

    // 1. Direct file check
    try {
      final f = File(clean);
      if (f.existsSync()) return f;
    } catch (_) {}

    // 2. URI decoded check (e.g. %20 for spaces)
    try {
      final decoded = Uri.decodeComponent(clean);
      final f = File(decoded);
      if (f.existsSync()) return f;
    } catch (_) {}

    // 3. Alternate path separators (Windows \ vs Android /)
    try {
      final altPath = clean.contains('/')
          ? clean.replaceAll('/', '\\')
          : clean.replaceAll('\\', '/');
      final f = File(altPath);
      if (f.existsSync()) return f;
    } catch (_) {}

    // 4. Resolve against app documents / product_images directory
    if (_cachedDocPath != null && _cachedDocPath!.isNotEmpty) {
      try {
        final fileName = clean.split(RegExp(r'[/\\]')).last;
        if (fileName.isNotEmpty) {
          final inProdDir = File('$_cachedDocPath/product_images/$fileName');
          if (inProdDir.existsSync()) return inProdDir;

          final inDocDir = File('$_cachedDocPath/$fileName');
          if (inDocDir.existsSync()) return inDocDir;
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  State<PromoMediaPlayer> createState() => _PromoMediaPlayerState();
}

class _PromoMediaPlayerState extends State<PromoMediaPlayer> {
  VideoPlayerController? _videoCtrl;
  bool _isVideo = false;
  bool _videoInitialized = false;
  bool _videoError = false;
  String _videoErrorMessage = '';

  @override
  void initState() {
    super.initState();
    PromoMediaPlayer._ensureDocPath().then((_) {
      if (mounted) setState(() {});
    });
    _checkAndInitMedia();
  }

  @override
  void didUpdateWidget(PromoMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath) {
      _disposeVideo();
      _checkAndInitMedia();
    }
  }

  void _disposeVideo() {
    try {
      _videoCtrl?.pause();
      _videoCtrl?.dispose();
    } catch (_) {}
    _videoCtrl = null;
    _videoInitialized = false;
    _videoError = false;
    _videoErrorMessage = '';
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _checkAndInitMedia() {
    final path = PromoMediaPlayer.sanitizePath(widget.mediaPath);
    _isVideo = PromoMediaPlayer.isVideo(path);

    if (_isVideo) {
      _initVideo(path);
    }
  }

  Future<void> _initVideo(String path) async {
    try {
      // Ensure Windows video player engine is registered
      if (!kIsWeb && Platform.isWindows) {
        try {
          WindowsVideoPlayer.registerWith();
        } catch (_) {}
      }

      await PromoMediaPlayer._ensureDocPath();

      final normalized = path.replaceAll('\\', '/');
      final isAsset = normalized.startsWith('assets/') ||
          normalized.startsWith('lib/assets/') ||
          normalized.contains('assets/images/');
      final isNetwork = path.startsWith('http://') || path.startsWith('https://');

      if (isAsset) {
        final assetPath = normalized.startsWith('assets/')
            ? normalized
            : (normalized.startsWith('lib/assets/')
                ? normalized.substring(4)
                : 'assets/$normalized');
        _videoCtrl = VideoPlayerController.asset(assetPath);
      } else if (isNetwork) {
        _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        File? file = PromoMediaPlayer.resolveLocalFile(path);
        if (file == null || !await file.exists()) {
          debugPrint('[PromoMediaPlayer] Video file not found: $path');
          if (mounted) {
            setState(() {
              _videoError = true;
              _videoErrorMessage = 'Video file not found at:\n$path';
            });
          }
          return;
        }
        _videoCtrl = VideoPlayerController.file(file);
      }

      await _videoCtrl!.initialize();
      if (widget.loop) {
        await _videoCtrl!.setLooping(true);
      }
      if (widget.muted) {
        await _videoCtrl!.setVolume(0.0);
      }
      if (widget.autoPlay) {
        await _videoCtrl!.play();
      }

      if (mounted) {
        setState(() {
          _videoInitialized = true;
          _videoError = false;
        });
      }
    } catch (e) {
      debugPrint('[PromoMediaPlayer] Video init failed for $path: $e');
      if (mounted) {
        setState(() {
          _videoError = true;
          _videoInitialized = false;
          _videoErrorMessage = 'Failed to play video: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      if (_videoError || _videoCtrl == null) {
        return _buildVideoErrorDisplay();
      }

      if (!_videoInitialized) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF0F172A)),
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        );
      }

      return _buildVideoDisplay(_videoCtrl!);
    }

    return _buildImageDisplay();
  }

  Widget _buildVideoErrorDisplay() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Color(0xFFF43F5E), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Video Playback Notice',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _videoErrorMessage.isNotEmpty
                  ? _videoErrorMessage
                  : 'Unable to initialize video playback for this file.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a video player filling the full screen edge-to-edge
  Widget _buildVideoDisplay(VideoPlayerController ctrl) {
    final videoSize = ctrl.value.size;
    final hasValidSize = videoSize.width > 0 && videoSize.height > 0;
    final effectiveFit = (widget.fit == BoxFit.contain || widget.fit == BoxFit.cover)
        ? BoxFit.cover
        : widget.fit;

    return SizedBox.expand(
      child: FittedBox(
        fit: effectiveFit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: hasValidSize ? videoSize.width : 1920,
          height: hasValidSize ? videoSize.height : 1080,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  /// Builds an image filling 100% of the screen edge-to-edge (no borders, no blur, no shrinking)
  Widget _buildImageDisplay() {
    final cleanPath = PromoMediaPlayer.sanitizePath(widget.mediaPath);
    final normalized = cleanPath.replaceAll('\\', '/');
    final isAsset = normalized.startsWith('assets/') ||
        normalized.startsWith('lib/assets/') ||
        normalized.contains('assets/images/');
    final isNetwork = cleanPath.startsWith('http://') || cleanPath.startsWith('https://');

    final effectiveFit = (widget.fit == BoxFit.contain || widget.fit == BoxFit.cover)
        ? BoxFit.cover
        : widget.fit;

    if (isAsset) {
      final assetPath = normalized.startsWith('assets/')
          ? normalized
          : (normalized.startsWith('lib/assets/')
              ? normalized.substring(4)
              : 'assets/$normalized');
      return SizedBox.expand(
        child: Image.asset(
          assetPath,
          key: ValueKey('${assetPath}_${effectiveFit}_fullscreen'),
          fit: effectiveFit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        ),
      );
    }

    if (isNetwork) {
      return SizedBox.expand(
        child: Image.network(
          cleanPath,
          key: ValueKey('${cleanPath}_${effectiveFit}_fullscreen'),
          fit: effectiveFit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        ),
      );
    }

    final File? file = PromoMediaPlayer.resolveLocalFile(cleanPath);
    if (file != null) {
      return SizedBox.expand(
        child: Image.file(
          file,
          key: ValueKey('${file.path}_${effectiveFit}_fullscreen'),
          fit: effectiveFit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        ),
      );
    }

    // Check if filename matches any bundled default promo banners
    final fileName = cleanPath.split(RegExp(r'[/\\]')).last;
    for (final defBanner in StoreSettingsModel.defaultPromoBanners) {
      if (defBanner.endsWith(fileName)) {
        return SizedBox.expand(
          child: Image.asset(
            defBanner,
            fit: effectiveFit,
            errorBuilder: (_, _, _) => _buildFallbackImage(),
          ),
        );
      }
    }

    // Gracefully fallback to high-resolution default promo poster
    return _buildFallbackImage();
  }

  /// High-resolution bundled fallback poster filling 100% of the screen
  Widget _buildFallbackImage() {
    final assetPath = PromoMediaPlayer.getFallbackAsset(widget.index);
    final effectiveFit = (widget.fit == BoxFit.contain || widget.fit == BoxFit.cover)
        ? BoxFit.cover
        : widget.fit;

    return SizedBox.expand(
      child: Image.asset(
        assetPath,
        fit: effectiveFit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Icon(Icons.restaurant_menu_rounded, color: Colors.white24, size: 64),
          ),
        ),
      ),
    );
  }
}
