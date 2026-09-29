import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Official ABA PAY KHQR Card Template Widget.
/// Faithfully reproduces the official ABA Bank KHQR merchant partner template.
class AbaKhqrCard extends StatelessWidget {
  final String storeName;
  final double amount;
  final int khrAmount;
  final String currencySymbol;
  final String qrData;
  final String? qrImagePath;
  final double qrSize;
  final bool showLogoHeader;
  final bool showFooter;
  final double cardWidth;

  const AbaKhqrCard({
    super.key,
    required this.storeName,
    required this.amount,
    required this.khrAmount,
    this.currencySymbol = '\$',
    required this.qrData,
    this.qrImagePath,
    this.qrSize = 180.0,
    this.showLogoHeader = true,
    this.showFooter = true,
    this.cardWidth = 280.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = qrImagePath != null &&
        qrImagePath!.trim().isNotEmpty &&
        File(qrImagePath!).existsSync();

    final cleanStoreName = storeName.isNotEmpty ? storeName : 'CA POS';
    final formattedKhr = NumberFormat('#,###').format(khrAmount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. ABA' PAY Top Header Brand Logo ──
        if (showLogoHeader) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'ABA',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF005A70),
                          letterSpacing: 2.0,
                        ),
                      ),
                      TextSpan(
                        text: '\'',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD41A22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'PAY',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00AFD8),
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── 2. Official KHQR Template Card ──
        Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(0), // Chamfered by ClipPath header
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Red KHQR Header Ribbon with Top-Right Signature Cut
              ClipPath(
                clipper: const _KhqrHeaderClipper(radius: 18.0, cutSize: 22.0),
                child: Container(
                  height: 44,
                  color: const Color(0xFFD41A22),
                  alignment: Alignment.center,
                  child: const Text(
                    'KHQR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),

              // Card Content Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Merchant / Store Name
                    Text(
                      cleanStoreName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Amount Display (KHR Priority as seen on ABA KHQR standard)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '៛ $formattedKhr',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (currencySymbol == '\$' && amount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(\$${amount.toStringAsFixed(2)})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dashed Horizontal Line Separator
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // QR Code with Center KHQR Red Emblem
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: hasCustomImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(qrImagePath!),
                                  width: qrSize,
                                  height: qrSize,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: qrData.isNotEmpty ? qrData : 'KHQR:MERCHANT:CAPOS',
                                    version: QrVersions.auto,
                                    size: qrSize,
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.all(4),
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),

                                  // Central Red KHQR Rosette Emblem
                                  Container(
                                    width: qrSize * 0.17,
                                    height: qrSize * 0.17,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: const CustomPaint(
                                      painter: _KhqrCenterEmblemPainter(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── 3. Footer Subtext ──
        if (showFooter) ...[
          const SizedBox(height: 14),
          const SizedBox(
            width: 260,
            child: Text(
              'Scan with ABA Mobile or any KHQR supported banking app',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashGap = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashGap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Custom clipper that cuts the top-right corner at 45 degrees, matching KHQR ribbon
class _KhqrHeaderClipper extends CustomClipper<Path> {
  final double radius;
  final double cutSize;

  const _KhqrHeaderClipper({this.radius = 18.0, this.cutSize = 22.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Top-left corner rounded
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    // Across to top-right cut
    path.lineTo(size.width - cutSize, 0);
    path.lineTo(size.width, cutSize);
    // Down to bottom-right
    path.lineTo(size.width, size.height);
    // Across to bottom-left
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Draws the official KHQR rosette floral center badge
class _KhqrCenterEmblemPainter extends CustomPainter {
  const _KhqrCenterEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Solid red circle background
    final bgPaint = Paint()..color = const Color(0xFFD41A22);
    canvas.drawCircle(center, radius, bgPaint);

    // Crisp white outer border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.8, borderPaint);

    // 8-petal motif in white
    final flowerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final petalR = radius * 0.58;
    final path = Path();
    const count = 8;
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi) / count;
      final x = center.dx + petalR * math.cos(angle);
      final y = center.dy + petalR * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, flowerPaint);

    // Center white dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.22, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
