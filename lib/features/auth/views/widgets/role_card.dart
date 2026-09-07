import 'package:flutter/material.dart';

import '../../../../models/user_model.dart';

class RoleCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const RoleCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color cardBorderColor;
    Color iconBgColor;
    Color iconColor;
    IconData icon;
    String description;
    String badgeText;

    switch (user.role) {
      case UserRole.mainBoss:
        cardBorderColor = const Color(0xFFD8B4FE);
        iconBgColor = const Color(0xFFFAF5FF);
        iconColor = const Color(0xFF7C3AED);
        icon = Icons.shield;
        description =
            'Boss (Admin / Owner): Full System Control, P&L, Inventory & Settings';
        badgeText = 'BOSS';
        break;
      case UserRole.subBoss:
        cardBorderColor = const Color(0xFFBAE6FD);
        iconBgColor = const Color(0xFFF0F9FF);
        iconColor = const Color(0xFF0284C7);
        icon = Icons.store;
        description = 'Store Manager: Local Branch P&L, Inventory & Petty Cash';
        badgeText = (user.branchName ?? '').toUpperCase();
        break;
      case UserRole.cashier:
        cardBorderColor = const Color(0xFFBBF7D0);
        iconBgColor = const Color(0xFFF0FDF4);
        iconColor = const Color(0xFF16A34A);
        icon = Icons.point_of_sale;
        description =
            'Frontline Staff: High-Speed Checkout, POS Cart & Cash Drawer';
        badgeText = 'CASHIER';
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: iconBgColor.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cardBorderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
