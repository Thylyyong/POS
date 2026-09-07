import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../app_config.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

class ImagePickerDialog extends StatefulWidget {
  final String title;

  const ImagePickerDialog({super.key, this.title = 'Select Product Image'});

  static Future<String?> pickImage(BuildContext context, {String title = 'Select Product Image'}) {
    return showDialog<String>(
      context: context,
      builder: (_) => ImagePickerDialog(title: title),
    );
  }

  @override
  State<ImagePickerDialog> createState() => _ImagePickerDialogState();
}

class _ImagePickerDialogState extends State<ImagePickerDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _foundImages = [];
  bool _isScanningFolders = false;

  @override
  void initState() {
    super.initState();
    _scanCommonDeviceFolders();
  }

  /// Scans real machine folders on Android / Desktop
  Future<void> _scanCommonDeviceFolders() async {
    setState(() {
      _isScanningFolders = true;
    });

    final List<File> discovered = [];
    final List<String> searchPaths = [];

    try {
      // 1. Android public Download / Pictures directories
      searchPaths.add('/storage/emulated/0/Download');
      searchPaths.add('/storage/emulated/0/Pictures');
      searchPaths.add('/storage/emulated/0/DCIM/Camera');
      searchPaths.add('/sdcard/Download');
      searchPaths.add('/sdcard/Pictures');

      // 2. App storage directories
      final appDir = await getApplicationDocumentsDirectory();
      searchPaths.add('${appDir.path}/product_images');
      searchPaths.add('${appDir.path}/POS_Receipts');
      searchPaths.add(appDir.path);
      searchPaths.add('assets/images');
      searchPaths.add('${Directory.current.path}/assets/images');

      for (var path in searchPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          try {
            final entities = dir.listSync(recursive: false);
            for (var entity in entities) {
              if (entity is File) {
                final ext = entity.path.toLowerCase();
                if (ext.endsWith('.jpg') ||
                    ext.endsWith('.jpeg') ||
                    ext.endsWith('.png') ||
                    ext.endsWith('.webp') ||
                    ext.endsWith('.bmp')) {
                  discovered.add(entity);
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Folder scan notice: $e');
    }

    if (mounted) {
      setState(() {
        _foundImages = discovered;
        _isScanningFolders = false;
      });
    }
  }

  Future<void> _pickFromFileManager() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final savedPath = await _saveImageToAppStorage(result.first.path!);
        if (mounted) Navigator.of(context).pop(savedPath);
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      _pickFromImagePicker(ImageSource.gallery);
    }
  }

  Future<void> _pickFromImagePicker(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );
      if (picked != null) {
        final savedPath = await _saveImageToAppStorage(picked.path);
        if (mounted) Navigator.of(context).pop(savedPath);
      }
    } catch (e) {
      debugPrint('ImagePicker error: $e');
    }
  }

  Future<String> _saveImageToAppStorage(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${appDir.path}/product_images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);

    final ext = sourcePath.split('.').last;
    final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final destination = '${imgDir.path}/$fileName';
    final savedFile = await File(sourcePath).copy(destination);
    return savedFile.path;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const AppSvgIcon(AssetTheme.gallery, color: ColorTheme.buttonPrimary, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorTheme.primary400,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const AppSvgIcon(AssetTheme.close, color: ColorTheme.neutral600, size: 18),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Options Row (Real Folder vs Gallery vs Camera)
              Row(
                children: [
                  // 1. Browse Real Storage Folder (File Manager)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorTheme.buttonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _pickFromFileManager,
                      icon: const AppSvgIcon(AssetTheme.box, size: 18, color: Colors.white),
                      label: const Text('Browse Real Folders / Storage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. Photo Gallery
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: ColorTheme.neutral300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        foregroundColor: ColorTheme.primary400,
                      ),
                      onPressed: () => _pickFromImagePicker(ImageSource.gallery),
                      icon: const AppSvgIcon(AssetTheme.gallery, size: 18, color: ColorTheme.primary400),
                      label: const Text('Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ColorTheme.primary400)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Discovered Images Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PHOTOS FOUND IN DEVICE FOLDERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ColorTheme.neutral600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _scanCommonDeviceFolders,
                    icon: const Icon(Icons.refresh, size: 16, color: ColorTheme.primary400),
                    label: const Text('Rescan', style: TextStyle(fontSize: 12, color: ColorTheme.primary400, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Image Grid from Device Storage
              Expanded(
                child: _isScanningFolders
                    ? const Center(child: CircularProgressIndicator(color: ColorTheme.buttonPrimary))
                    : _foundImages.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: ColorTheme.neutral100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ColorTheme.neutral300),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 8),
                                  const AppSvgIcon(AssetTheme.gallery, size: 44, color: ColorTheme.neutral400),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No photos found in default folders',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: ColorTheme.primary400, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap "Browse Real Folders / Storage" above to open your device file manager and pick any image from Downloads, USB, SD Card, etc.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: ColorTheme.neutral600, fontSize: 11.5),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ColorTheme.buttonPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _pickFromFileManager,
                                    icon: const AppSvgIcon(AssetTheme.box, size: 16, color: Colors.white),
                                    label: const Text('Open Device File Manager', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: _foundImages.length,
                            itemBuilder: (context, index) {
                              final file = _foundImages[index];
                              final fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;

                              return InkWell(
                                onTap: () async {
                                  final savedPath = await _saveImageToAppStorage(file.path);
                                  if (context.mounted) Navigator.of(context).pop(savedPath);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ColorTheme.neutral300),
                                    image: DecorationImage(
                                      image: FileImage(file),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                                      ),
                                      child: Text(
                                        fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 9),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
