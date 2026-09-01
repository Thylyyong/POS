import 'package:flutter/material.dart';
import 'customer_presentation_view.dart';

export 'customer_presentation_view.dart';

/// Backward-compatible alias for CustomerPresentationView
class CustomerMainView extends StatelessWidget {
  final bool showDashboardButton;

  const CustomerMainView({
    super.key,
    this.showDashboardButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerPresentationView(
      showDashboardButton: showDashboardButton,
    );
  }
}
