import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../app_config.dart';

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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_special, color: AppConfig.accentGreen, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Options Row (Real Folder vs Gallery vs Camera)
              Row(
                children: [
                  // 1. Browse Real Storage Folder (File Manager)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _pickFromFileManager,
                      icon: const Icon(Icons.drive_folder_upload, size: 20),
                      label: const Text('Browse Real Folders / Storage', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Photo Gallery
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _pickFromImagePicker(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF334155)),
                      label: const Text('Photo Gallery', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Discovered Images in Real Machine Folders
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PHOTOS FOUND IN DEVICE FOLDERS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _scanCommonDeviceFolders,
                    icon: const Icon(Icons.refresh, size: 16, color: AppConfig.accentGreenDark),
                    label: const Text('Rescan', style: TextStyle(fontSize: 12, color: AppConfig.accentGreenDark)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Image Grid from Device Storage
              Expanded(
                child: _isScanningFolders
                    ? const Center(child: CircularProgressIndicator(color: AppConfig.accentGreen))
                    : _foundImages.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.folder_open, size: 54, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No photos found in default folders',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap "Browse Real Folders / Storage" above to open your device file manager and pick any image file from Downloads, USB, SD Card, etc.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentCyan, foregroundColor: Colors.white),
                                    onPressed: _pickFromFileManager,
                                    icon: const Icon(Icons.drive_folder_upload, size: 18),
                                    label: const Text('Open Device File Manager'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
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
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
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
