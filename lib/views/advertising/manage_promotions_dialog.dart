import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../models/store_settings_model.dart';
import '../../services/presentation_service.dart';
import '../../widgets/image_picker_dialog.dart';
import '../../widgets/promo_media_player.dart';

/// Modal dialog allowing Store Owner / Admin to manage advertising promo slides
class ManagePromotionsDialog extends StatefulWidget {
  const ManagePromotionsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ManagePromotionsDialog(),
    );
  }

  @override
  State<ManagePromotionsDialog> createState() => _ManagePromotionsDialogState();
}

class _ManagePromotionsDialogState extends State<ManagePromotionsDialog> {
  late List<String> _promoList;
  late int _autoPlaySeconds;
  late String _promoMediaFit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _promoList = List<String>.from(
      settings.promoBanners.isNotEmpty
          ? settings.promoBanners
          : StoreSettingsModel.defaultPromoBanners,
    );
    _autoPlaySeconds = settings.promoAutoPlaySeconds;
    _promoMediaFit = (settings.promoMediaFit == 'contain') ? 'cover' : settings.promoMediaFit;
  }

  Future<void> _addNewImage() async {
    final pickedPath = await ImagePickerDialog.pickImage(
      context,
      title: 'Select Promotion Image / Video',
      allowVideo: true,
    );
    if (pickedPath != null && pickedPath.trim().isNotEmpty) {
      setState(() {
        _promoList.add(pickedPath.trim());
      });
    }
  }

  Future<void> _saveAndClose() async {
    setState(() => _isSaving = true);
    final settingsCtrl = context.read<SettingsController>();
    final current = settingsCtrl.settings;

    final updated = current.copyWith(
      promoBanners: _promoList,
      promoAutoPlaySeconds: _autoPlaySeconds,
      promoMediaFit: _promoMediaFit,
    );

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await settingsCtrl.updateSettings(updated);

    // Live broadcast immediately to Customer Display (CFD/CDS)
    PresentationService().syncStoreSettings(updated);
    PresentationService().sendToCustomerDisplay(
      PresentationService().latestPayload.copyWith(
        promoBanners: _promoList,
        promoAutoPlaySeconds: _autoPlaySeconds,
        promoMediaFit: _promoMediaFit,
        storeName: updated.storeName,
        storeAddress: updated.storeAddress,
        logoPath: updated.logoPath,
      ),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Advertising display promotions updated!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _restoreDefaults() {
    setState(() {
      _promoList = List<String>.from(StoreSettingsModel.defaultPromoBanners);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Color(0xFF0D9488), size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Manage Promotion Ads & Displays',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'These images will display automatically in a smooth fullscreen carousel when the register is idle or no customer order is active.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Controls: Auto-advance interval
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text(
                          'Slide Rotation Speed:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    DropdownButton<int>(
                      value: _autoPlaySeconds,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(10),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 Seconds (Live Promo)')),
                        DropdownMenuItem(value: 3, child: Text('3 Seconds')),
                        DropdownMenuItem(value: 5, child: Text('5 Seconds')),
                        DropdownMenuItem(value: 8, child: Text('8 Seconds')),
                        DropdownMenuItem(value: 12, child: Text('12 Seconds')),
                        DropdownMenuItem(value: 15, child: Text('15 Seconds')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _autoPlaySeconds = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Controls: Media Display Fit Mode
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fullscreen_rounded, size: 20, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text(
                          'Media Display Fit:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: (_promoMediaFit == 'contain') ? 'cover' : _promoMediaFit,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(10),
                      items: const [
                        DropdownMenuItem(value: 'cover', child: Text('Full Screen (Cover)')),
                        DropdownMenuItem(value: 'fill', child: Text('Stretch to Full (Fill)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _promoMediaFit = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Toolbar: Add Image + Reset Defaults
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Slides (${_promoList.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _restoreDefaults,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset Defaults', style: TextStyle(fontSize: 12.5)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addNewImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: const Text('Add Image / Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Banners Grid View
              Expanded(
                child: _promoList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image_not_supported_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text('No promotion slides configured yet', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _restoreDefaults,
                              child: const Text('Load Default Food & Drink Slides'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        itemCount: _promoList.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.4,
                        ),
                        itemBuilder: (context, index) {
                          final path = _promoList[index];
                          final isVid = PromoMediaPlayer.isVideo(path);
                          final cleanPath = PromoMediaPlayer.sanitizePath(path);
                          final isAsset = cleanPath.startsWith('assets/') || cleanPath.startsWith('lib/assets/');
                          final isFile = !isAsset && File(cleanPath).existsSync();

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isVid ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: isVid
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF38BDF8), size: 36),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: Text(
                                                  path.split(Platform.isWindows ? '\\' : '/').last,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : (isAsset
                                          ? Image.asset(cleanPath.replaceAll('\\', '/'), fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackThumb(index))
                                          : (isFile
                                              ? Image.file(File(cleanPath), fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackThumb(index))
                                              : _fallbackThumb(index))),
                                ),
                              ),

                              // Slide number badge
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),

                              // Delete button
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _promoList.removeAt(index);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Bottom Save / Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Apply Ads', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumb(int index) {
    return Image.asset(
      PromoMediaPlayer.getFallbackAsset(index),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
