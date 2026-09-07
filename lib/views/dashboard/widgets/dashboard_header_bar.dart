import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../controllers/dashboard_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class DashboardHeaderBar extends StatelessWidget {
  final VoidCallback onExportExcel;

  const DashboardHeaderBar({super.key, required this.onExportExcel});

  Future<void> _pickCustomDateRange(
    BuildContext context,
    DashboardController dashCtrl,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange:
          dashCtrl.customStartDate != null && dashCtrl.customEndDate != null
          ? DateTimeRange(
              start: dashCtrl.customStartDate!,
              end: dashCtrl.customEndDate!,
            )
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      dashCtrl.setCustomDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashCtrl = context.watch<DashboardController>();
    final auth = context.watch<AuthController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Screen Title
          const Text(
            'Sales & Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 14),

          // User Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: auth.isMainBoss
                  ? const Color(0xFFFAF5FF)
                  : (auth.isSubBoss
                        ? const Color(0xFFF0F9FF)
                        : const Color(0xFFFFEDD5)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: auth.isMainBoss
                    ? const Color(0xFFD8B4FE)
                    : (auth.isSubBoss
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFFFFEDD5)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  auth.isMainBoss ? AssetTheme.verify : AssetTheme.store,
                  size: 13,
                  color: auth.isMainBoss
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 4),
                Text(
                  auth.currentUser.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: auth.isMainBoss
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),

          // Main Boss Branch Selector Dropdown
          if (auth.isMainBoss) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButton<String>(
                value: dashCtrl.selectedBranch,
                underline: const SizedBox(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSvgIcon(
                          AssetTheme.store,
                          size: 14,
                          color: Color(0xFF0F172A),
                        ),
                        SizedBox(width: 6),
                        Text('All Stores (Global)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'store_a',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSvgIcon(
                          AssetTheme.location,
                          size: 14,
                          color: Color(0xFF0F172A),
                        ),
                        SizedBox(width: 6),
                        Text('Store A (Downtown)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'store_b',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSvgIcon(
                          AssetTheme.location,
                          size: 14,
                          color: Color(0xFF0F172A),
                        ),
                        SizedBox(width: 6),
                        Text('Store B (Uptown)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    dashCtrl.setBranch(val);
                  }
                },
              ),
            ),
          ],

          const Spacer(),

          // Date Range Filter Pills
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: DashboardDateFilter.values.map((filter) {
                    final isSelected = dashCtrl.selectedFilter == filter;
                    return InkWell(
                      onTap: () {
                        if (filter == DashboardDateFilter.custom) {
                          _pickCustomDateRange(context, dashCtrl);
                        } else {
                          dashCtrl.setFilter(filter);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          filter.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Excel Export Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: dashCtrl.isExporting ? null : onExportExcel,
            icon: dashCtrl.isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : const AppSvgIcon(
                    AssetTheme.files,
                    size: 14,
                    color: Color(0xFF0F172A),
                  ),
            label: Text(
              dashCtrl.isExporting ? 'Exporting...' : 'Export (.xlsx)',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
