# 📁 POS Flutter — Architecture & Directory Map

A modular, clean, offline-first Flutter POS architecture designed for dual-screen POS systems.

```
lib/
├── app_config.dart                  # App Theme, Colors & Global Configuration
├── main.dart                        # Main entry-point & Secondary CFD entry-point
│
├── core/                            # Core Utilities & Helpers
│   ├── core.dart                    # Barrel export
│   ├── async_guard.dart             # Safe async operation handlers
│   └── debouncer.dart               # Input debounce for live search
│
├── models/                          # Immutable Data Models
│   ├── models.dart                  # Barrel export
│   ├── dining_table_model.dart      # Dining Tables & Status Model
│   ├── order_model.dart             # Orders & Order Items Model
│   ├── product_model.dart           # Products, Categories & Subcategories Model
│   └── store_settings_model.dart    # Terminal Hardware & Branding Model
│
├── controllers/                     # State Management (Provider / ChangeNotifier)
│   ├── controllers.dart             # Barrel export
│   ├── cart_controller.dart         # Cart state, discounts, taxes & CFD sync
│   ├── pos_controller.dart          # Checkout, receipt generation & order flow
│   ├── table_controller.dart        # Dining tables, seating & guest allocation
│   ├── dashboard_controller.dart    # Analytics, revenue metrics & hourly charts
│   └── settings_controller.dart     # Terminal hardware, logo & store preferences
│
├── database/                        # Local SQLite Storage (sqflite)
│   ├── database.dart                # Barrel export
│   ├── db_helper.dart               # DB initialization, schema migrations & seeds
│   ├── order_dao.dart               # Orders & Daily Reports Queries
│   ├── product_dao.dart             # Products, Categories & Search Queries
│   ├── table_dao.dart               # Dining Table queries & status updates
│   └── settings_dao.dart            # Key-value persistent settings store
│
├── services/                        # Hardware Drivers & IO Services
│   ├── services.dart                # Barrel export
│   ├── presentation_service.dart    # Dual-Screen Customer Display Driver
│   ├── printer_service.dart         # 58mm / 80mm ESC/POS Thermal Printing
│   ├── pdf_receipt_service.dart     # PDF Generation & Direct Print
│   ├── excel_export_service.dart    # Analytics Excel Export (.xlsx)
│   ├── receipt_file_service.dart    # Receipt Markdown Archive Generator
│   └── barcode_service.dart         # Hardware USB Barcode Scanner Handler
│
├── views/                           # Feature UI Screens
│   ├── views.dart                   # Barrel export
│   ├── splash/                      # App Launch & Workspace Mode Portal
│   │   └── splash_screen.dart
│   ├── cashier/                     # Cashier Point of Sale (1366x768 3-Column Layout)
│   │   ├── cashier_main_layout.dart
│   │   └── widgets/
│   │       ├── top_header_bar.dart
│   │       ├── nav_sidebar.dart
│   │       ├── item_grid.dart
│   │       └── cart_panel.dart
│   ├── tables/                      # Visual Table Layout Management
│   │   ├── table_management_screen.dart
│   │   └── widgets/
│   │       └── assign_table_dialog.dart
│   ├── customer_display/            # Secondary Customer-Facing Display (CFD)
│   │   ├── customer_main_view.dart
│   │   └── widgets/
│   │       └── qr_display.dart
│   ├── dashboard/                   # Analytics Dashboard & Reports
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       └── metrics_card.dart
│   ├── products/                    # Product Catalog & Category Management
│   │   ├── product_list_screen.dart
│   │   └── category_screen.dart
│   ├── history/                     # Receipts Archive & PDF Export
│   │   └── receipt_history_screen.dart
│   └── settings/                    # Terminal Hardware & Branding Settings
│       └── store_settings_screen.dart
│
└── widgets/                         # Shared Reusable Widgets & Dialogs
    ├── widgets.dart                 # Barrel export
    ├── custom_dialogs.dart          # Smart Cash Tender & QR Dialogs
    ├── image_picker_dialog.dart     # Real Machine Folder & Storage Browser
    ├── receipt_preview_dialog.dart  # Thermal Receipt Preview Modal
    └── error_banner.dart            # Offline notice & error alerts
```
