# 🛒 OmniPOS Enterprise — Odoo-Grade Dual-Screen POS & Mini-Accounting Suite

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Odoo 17 POS](https://img.shields.io/badge/Odoo%2017-POS%20%26%20Restaurant-714B67?style=for-the-badge)
![Odoo Accounting](https://img.shields.io/badge/Odoo-Profit%20%26%20Loss-875A7B?style=for-the-badge)
![Hybrid Model](https://img.shields.io/badge/Settlement-Hybrid%20Rent%20%2B%20%25%20Royalty-FF6F00?style=for-the-badge)

**A high-performance, 100% offline-first Dual-Screen Point of Sale (POS), Restaurant Floor Manager, Cash Register Session Controller, and Odoo-Style Mini-Accounting System with Multi-Branch Hybrid Franchise Settlement for Android hardware terminals and Windows POS machines.**

</div>

---

## 📑 Table of Contents

- [🌟 Odoo POS & Accounting Parity Overview](#-odoo-pos--accounting-parity-overview)
- [🏢 Multi-Branch Governance & Splash Screen RBAC](#-multi-branch-governance--splash-screen-rbac)
  - [Splash Screen Role Login & PIN Authentication](#splash-screen-role-login--pin-authentication)
  - [Role Hierarchy (1 Main Boss, 2 Sub Bosses, 1 Staff Cashier)](#role-hierarchy-1-main-boss-2-sub-bosses-1-staff-cashier)
  - [RBAC Permission Matrix](#rbac-permission-matrix)
- [🍽️ Odoo Restaurant & Floor Management](#️-odoo-restaurant--floor-management)
  - [Interactive Multi-Zone Floor Plan](#interactive-multi-zone-floor-plan)
  - [Table Order Transfer & Split Bill Engine](#table-order-transfer--split-bill-engine)
  - [Kitchen Course Sequencing & Order Routing](#kitchen-course-sequencing--order-routing)
- [🛒 Odoo Fast POS Terminal & Action Numpad](#-odoo-fast-pos-terminal--action-numpad)
  - [Action Numpad (Qty, % Disc, Price Modifier)](#action-numpad-qty--disc-price-modifier)
  - [Combos, Product Variants & Attributes](#combos-product-variants--attributes)
  - [Multi-Order Park & Customer Loyalty Points](#multi-order-park--customer-loyalty-points)
- [💵 Odoo Session & Cash Register Lifecycle](#-odoo-session--cash-register-lifecycle)
  - [1. 🔓 Opening Control (Open Register)](#1--opening-control-open-register)
  - [2. 💸 Cash In / Cash Out (Petty Cash Movements)](#2--cash-in--cash-out-petty-cash-movements)
  - [3. 🔒 Closing Register & Discrepancy Reconciliation](#3--closing-register--discrepancy-reconciliation)
  - [4. 📥 Daily Sale Export & Thermal Z-Report Printing](#4--daily-sale-export--thermal-z-report-printing)
- [💰 Hybrid Profit-Sharing & Settlement Model (Sub Bosses ➔ Main Boss)](#-hybrid-profit-sharing--settlement-model-sub-bosses--main-boss)
  - [Hybrid Revenue Mechanism Explained](#hybrid-revenue-mechanism-explained)
  - [Interactive Side-by-Side Settlement Demonstration](#interactive-side-by-side-settlement-demonstration)
- [📊 Odoo-Style Mini-Accounting System (Profit & Loss)](#-odoo-style-mini-accounting-system-profit--loss)
  - [Odoo P&L Financial Statement Architecture](#odoo-pl-financial-statement-architecture)
  - [Sub Boss Branch P&L (Store A & Store B View)](#sub-boss-branch-pl-store-a--store-b-view)
  - [Main Boss Consolidated Master Executive P&L](#main-boss-consolidated-master-executive-pl)
  - [Chart of Accounts (COA) & POS Journal Entries](#chart-of-accounts-coa--pos-journal-entries)
- [🧾 Invoice & Digital Receipt Specification](#-invoice--digital-receipt-specification)
  - [Thermal Receipt (80mm / 58mm) & Customer Display (CFD)](#thermal-receipt-80mm--58mm--customer-display-cfd)
  - [Full Enterprise Tax Invoice Layout](#full-enterprise-tax-invoice-layout)
- [🖨️ Physical Hardware Setup & Cash Drawer Integration](#️-physical-hardware-setup--cash-drawer-integration)
- [🖥️ Technical Architecture & Project Map](#️-technical-architecture--project-map)
- [🗄️ Database Schema & Entities](#️-database-schema--entities)
- [🚀 Quick Start & Installation](#-quick-start--installation)
  - [Default Credentials & Access PINs](#default-credentials--access-pins)

---

## 🌟 Odoo POS & Accounting Parity Overview

OmniPOS is architected to replicate the renowned modular workflow of **Odoo Enterprise (POS, Restaurant, Accounting, and Multi-Company)** into an ultra-fast, local-first Flutter application with zero cloud downtime dependencies:

| Odoo Feature Module | OmniPOS Implementation |
| :--- | :--- |
| **Odoo POS Session Control** | Complete Session lifecycle: Opening Control float, mid-shift Cash In/Out, Closing Register counting, difference auditing, and Daily Z-Report export. |
| **Odoo Restaurant / Bar** | Interactive multi-zone floor plan, table visual states, guest seat allocation, Bill Splitting (by item/equal), Table Transfer, and Kitchen Course routing. |
| **Odoo Action Numpad** | Touch numpad with dynamic mode toggles (`Qty`, `% Disc`, `Price`), quick tender bills (`$10`, `$20`, `$50`, `$100`, Exact), and line discounts. |
| **Odoo Products & Combos** | Product variants (Sizes, Modifiers), Combo meal builder (Burger + Fries + Drink), SKU search, and HID barcode scanning. |
| **Odoo Mini-Accounting** | Official Odoo Profit and Loss report (US GAAP/IFRS), COGS tracking per line item, automated POS journal entries, and multi-period comparisons. |
| **Odoo Multi-Company** | Multi-branch architecture with 1 Main Boss (Holding Company) and 2 Sub Bosses (Store Branches) operating on a Hybrid (Low Rent + % Sales) model. |
| **Odoo IoT Box / Hardware** | Native direct integration with dual-screen presentation API, 80mm/58mm ESC/POS thermal printing, and 24V RJ11 cash drawer kick without external IoT hardware. |

---

## 🏢 Multi-Branch Governance & Splash Screen RBAC

OmniPOS supports hierarchical multi-store enterprise management: **1 Enterprise Master Company** with **2 Store Branches (Store A & Store B)**, owned by **1 Main Boss**, managed by **2 Sub Bosses**, and operated on the floor by **1 Staff Cashier**.

### Splash Screen Role Login & ![alt text](image.png) Authentication

Upon app launch, the **Splash Screen** presents a secure **Role Selection & Quick PIN Authentication Gateway**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       🛒 OMNIPOS ENTERPRISE PORTAL                           │
│                      Select Your Role to Authenticate                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌───────────────────────┐                 ┌───────────────────────┐       │
│   │   👑 MAIN BOSS        │                 │   👔 SUB BOSS 1       │       │
│   │   Master Enterprise   │                 │   Store A (Downtown)  │       │
│   │   [ Enter PIN: **** ] │                 │   [ Enter PIN: **** ] │       │
│   └───────────────────────┘                 └───────────────────────┘       │
│                                                                             │
│   ┌───────────────────────┐                 ┌───────────────────────┐       │
│   │   👔 SUB BOSS 2       │                 │   🏷️ STAFF (Cashier)  │       │
│   │   Store B (Uptown)    │                 │   POS Frontline Ops   │       │
│   │   [ Enter PIN: **** ] │                 │   [ Enter PIN: **** ] │       │
│   └───────────────────────┘                 └───────────────────────┘       │
│                                                                             │
│                     [ Quick Shift Login | Offline Mode ]                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Role Hierarchy (1 Main Boss, 2 Sub Bosses, 1 Staff Cashier)

```
                    ┌──────────────────────────────────────────────┐
                    │       👑 MAIN BOSS (Holding Company Owner)   │
                    │   - Controls Global Enterprise & Settings    │
                    │   - Consolidated Multi-Branch P&L & Audits   │
                    │   - Receives Hybrid Payout (Rent + % Sales)  │
                    │   - Master Catalog & Wholesale Cost Control  │
                    └──────────────────────┬───────────────────────┘
                                           │
                        ▲ Hybrid Royalty   │   ▲ Hybrid Royalty
                        │ (Low Rent +      │   │ (Low Rent +
                        │  Low % Products) │   │  Low % Products)
                                           │
                    ┌──────────────────────┴───────────────────────┐
                    │                                              │
     ┌──────────────▼───────────────┐               ┌──────────────▼───────────────┐
     │   👔 SUB BOSS 1 (Manager)    │               │   👔 SUB BOSS 2 (Manager)    │
     │   Branch Store A (Downtown)  │               │   Branch Store B (Uptown)    │
     │   - Store A Inventory & P&L  │               │   - Store B Inventory & P&L  │
     │   - Approves Cash In/Out     │               │   - Approves Cash In/Out     │
     │   - Closing Shift Audit      │               │   - Closing Shift Audit      │
     └──────────────┬───────────────┘               └──────────────┬───────────────┘
                    │                                              │
                    └──────────────────────┬───────────────────────┘
                                           │
                            ┌──────────────▼───────────────┐
                            │    🏷️ STAFF (Cashier)        │
                            │   - Frontline POS Terminal   │
                            │   - Open / Close Register    │
                            │   - Order Entry & Splitting  │
                            │   - Cash Drawer & Checkout   │
                            └──────────────────────────────┘
```

---

### RBAC Permission Matrix

| Feature / Module Action | 👑 Main Boss | 👔 Sub Boss (Assigned Store) | 🏷️ Staff (Cashier) |
| :--- | :---: | :---: | :---: |
| **Multi-Store Branch Switching** | ✅ Full Access | ❌ Restricted | ❌ Restricted |
| **Configure Hybrid Rent & Royalty Rates** | ✅ Full Control | ❌ View Only (Contract) | ❌ No Access |
| **Consolidated Multi-Branch P&L** | ✅ Yes | ❌ Isolated to Own Store | ❌ No Access |
| **Branch Profit & Loss (P&L) Reports** | ✅ All Branches | ✅ Own Branch Only | ❌ No Access |
| **Master Product Catalog & Base Costs** | ✅ Full CRUD | ⚠️ Stock Adjust Only | ❌ Read Only (POS Grid) |
| **Open / Close Register Session Control** | ✅ Yes | ✅ Supervisor Audit | ✅ Primary Function |
| **Cash In / Cash Out (Petty Cash)** | ✅ Yes | ✅ Supervisor Approval | ✅ Log with Reason |
| **Frontline Order Entry & Numpad** | ✅ Yes | ✅ Yes | ✅ Primary Function |
| **Table Management & Bill Splitting** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Cash Drawer Kick & Thermal Printing** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Reprint Past Receipts** | ✅ All Receipts | ✅ Own Branch Receipts | ⚠️ Current Shift Only |
| **Daily Sale Export & Z-Report** | ✅ Global & Branch | ✅ Own Branch Only | ✅ Current Shift Only |
| **Void / Cancel Completed Orders** | ✅ Yes | ✅ Manager PIN Required | ❌ Requires Manager PIN |
| **Excel (.xlsx) Financial Export** | ✅ Global & Branch | ✅ Own Branch Only | ❌ Restricted |
| **Hardware & Terminal Settings** | ✅ Global Defaults | ✅ Branch Terminals | ❌ Restricted |
| **User & Staff Account / PIN Config** | ✅ Full Control | ⚠️ Staff PIN Reset Only | ❌ Restricted |

---

## 🍽️ Odoo Restaurant & Floor Management

OmniPOS includes a full-featured **Odoo Restaurant** floor plan engine tailored for table service, bars, cafes, and fine dining:

### Interactive Multi-Zone Floor Plan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [ Floor 1: Main Hall ]  [ Floor 2: Terrace ]  [ Bar Lounge ]  [ + New Zone ] │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│   │   TABLE 01   │     │   TABLE 02   │     │   TABLE 03   │                │
│   │  🟢 AVAILABLE │     │  🔴 OCCUPIED │     │  🟡 BILLED   │                │
│   │   Seats: 4   │     │  4 Guests    │     │  2 Guests    │                │
│   │   $ 0.00     │     │  $ 84.50     │     │  $ 42.00     │                │
│   └──────────────┘     └──────────────┘     └──────────────┘                │
│                                                                             │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│   │   TABLE 04   │     │   TABLE 05   │     │   BAR 01     │                │
│   │  🔴 OCCUPIED │     │  🟢 AVAILABLE │     │  🔴 OCCUPIED │                │
│   │   6 Guests   │     │   Seats: 2   │     │   1 Guest    │                │
│   │   $ 126.00   │     │   $ 0.00     │     │   $ 14.50    │                │
│   └──────────────┘     └──────────────┘     └──────────────┘                │
│                                                                             │
│  [ Transfer Table ]  [ Split Bill ]  [ Direct Takeaway ]  [ Quick Sale ]   │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Visual Table States**:
  - 🟢 **Available (Green)**: Clean and ready for guest seating.
  - 🔴 **Occupied (Red)**: Active order running with live headcount and current order total.
  - 🟡 **Billed (Yellow)**: Digital receipt preview / bill printed, awaiting payment settlement.

---

### Table Order Transfer & Split Bill Engine

- **Transfer Table**: Seamlessly move active dining tabs from one table to another (e.g., moving from Bar 01 to Table 04) with complete item history preserved.
- **Split Bill by Item**: Selectively assign individual burgers, drinks, or sides to separate customer tickets.
- **Split Bill Equal**: Evenly divide total balance across $N$ guests with automated penny-rounding reconciliation.

---

### Kitchen Course Sequencing & Order Routing

- **Course Sequencing**: Group items by dining phases (**Starters**, **Main Courses**, **Desserts**, **Beverages**).
- **Kitchen / Bar Order Routing**: Dispatches beverage tickets to the Bar printer and food orders to the Kitchen station printer with custom kitchen notes (e.g., *"Medium Rare"*, *"No Peanuts - Allergy"*).

---

## 🛒 Odoo Fast POS Terminal & Action Numpad

The cashier checkout layout replicates the ultra-fast touch ergonomics of the **Odoo 17 POS Action Numpad**:

```
┌──────────────────────────────────────┬──────────────────────────────────────┐
│  ACTIVE CART (Table 04 - 6 Guests)   │           PRODUCT CATALOG            │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ Wagyu Burger Deluxe            x 2   │ [All] [Burgers] [Sides] [Drinks]     │
│   * Medium Rare, Extra Cheese        ├──────────────────────────────────────┤
│   $ 18.50 ea               $ 37.00   │ ┌──────────────┐  ┌──────────────┐    │
│ Truffle Parmesan Fries         x 1   │ │ Wagyu Burger │  │ Truffle Fries│    │
│   $ 8.50                   $  8.50   │ │ $ 18.50      │  │ $ 8.50       │    │
│ Iced Caramel Macchiato         x 2   │ └──────────────┘  └──────────────┘    │
│   $ 5.50 ea                $ 11.00   │ ┌──────────────┐  ┌──────────────┐    │
├──────────────────────────────────────┤ │ Macchiato    │  │ Craft Beer   │    │
│ Subtotal:                   $ 56.50  │ │ $ 5.50       │  │ $ 7.00       │    │
│ Discount (10%):            -$  5.65  │ └──────────────┘  └──────────────┘    │
│ Tax/VAT (10%):              $  5.09  ├──────────────────────────────────────┤
│ TOTAL DUE:                  $ 55.94  │          ODOO ACTION NUMPAD          │
├──────────────────────────────────────┤ ┌───┬───┬───┬──────────────────────┐ │
│ [ 👤 Customer: John Doe (240 Pts) ]  │ │ 1 │ 2 │ 3 │  [ Qty ]             │ │
│ [ 📌 Hold Order ] [ 🍽️ Transfer ]    │ ├───┼───┼───┼──────────────────────┤ │
├──────────────────────────────────────┤ │ 4 │ 5 │ 6 │  [ % Disc ]          │ │
│ [ 💵 Pay Cash ]     [ 📱 Pay QR ]    │ ├───┼───┼───┼──────────────────────┤ │
│ [ 💳 Credit Card ]  [ 🏛️ Customer AR]│ │ 7 │ 8 │ 9 │  [ Price ]           │ │
│                                      │ ├───┼───┼───┼──────────────────────┤ │
│                                      │ │ +/-│ 0 │ . │  [ ⌫ Backspace ]     │ │
│                                      │ └───┴───┴───┴──────────────────────┘ │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### Action Numpad (Qty, % Disc, Price Modifier)
- **`[ Qty ]` Mode**: Tap any line item, then press `3` to instantly update quantity to 3.
- **`[ % Disc ]` Mode**: Apply item-level promotional discounts (e.g., `10%`) with manager authorization thresholds.
- **`[ Price ]` Mode**: Override item unit price (protected by Sub Boss / Main Boss PIN).

---

### Combos, Product Variants & Add-ons (Admin Editable)
- **Smart Product Variants**:
  - **Drink / Beverage Customization**: Sugar level options (`Normal Sugar (100%)`, `Less Sugar (50%)`, `No Sugar (0%)`), Ice level options (`Normal Ice`, `Less Ice`, `No Ice`).
  - **Food Customization**: Spiciness level options (`Not Spicy`, `Normal Spicy`, `Extra Spicy`).
  - **Paid Add-ons with Extra Charges**: E.g., `Extra Cheese (+$0.50)`, `Extra Size / Upsize (+$0.75 / +$1.00)`, extra sauce, or bacon.
- **Admin Configuration**:
  - Navigate to **Products** in the navigation menu.
  - Tap the **Edit (pencil icon)** on any item or click **"+ Add Product"**.
  - Under the **Product Variants & Add-ons** section, toggle the switches for Sugar, Ice, and Spiciness.
  - Click **"+ Add Extra"** to define custom paid add-ons with custom names and extra charge prices (or delete existing extras).
  - Tap **"Save Product"** to persist modifiers in the database.
- **Cashier POS Customization Modal**:
  - Tapping a product with configured variants in the POS grid opens the interactive **Product Customization Modal**.
  - The cashier can select desired sweetness, ice, and spice levels, and check off add-ons.
  - The unit price updates dynamically in real-time `(Base Price + Add-ons Total) * Quantity`.
  - Configured modifiers are clearly displayed on cart item badges, kitchen tickets, and printed receipts.
- **Combo Meals Builder**: Create bundle meals (e.g., *Lunch Combo: 1 Burger + 1 Side + 1 Soft Drink*) with automated combo discount calculation.

---

### Multi-Order Park & Customer Loyalty Points
- **Park / Hold Orders**: Park unlimited simultaneous customer orders and recall them instantly with elapsed time tags.
- **Customer Loyalty Points**: Real-time points accumulation ($1 spent = 1 point) and point redemption directly on the cart panel.

---

## 💵 Odoo Session & Cash Register Lifecycle

OmniPOS features an enterprise-grade Cash Register and Cash Drawer lifecycle modeled after **Odoo POS**, ensuring complete accountability for all physical cash and electronic payments.

```
                  ┌──────────────────────────────────────────────┐
                  │          1. OPENING CONTROL                  │
                  │   - Enter Opening Cash Float                 │
                  │   - Denomination Breakdown Note              │
                  │   - Automatic Cash Drawer Kick               │
                  └──────────────────────┬───────────────────────┘
                                         │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │          2. MID-SHIFT TRANSACTIONS           │
                  │   - Sales: Cash / Card / QR Payments         │
                  │   - Cash In: Adding Change / Float           │
                  │   - Cash Out: Safe Drops / Vendor Expenses   │
                  │   - Auto Drawer Kick on Cash Tender          │
                  └──────────────────────┬───────────────────────┘
                                         │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │          3. CLOSING REGISTER                 │
                  │   - Count Physical Cash & Card Tenders       │
                  │   - Auto Difference Discrepancy Calc         │
                  │   - Add Closing Shift Notes                  │
                  └──────────────────────┬───────────────────────┘
                                         │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │          4. DAILY SALE & Z-REPORT            │
                  │   - One-Tap Daily Sale Export (PDF/Excel)    │
                  │   - Thermal 80mm Z-Report Printout           │
                  │   - Manager Sign-off & Shift Archiving       │
                  └──────────────────────────────────────────────┘
```

---

### 1. 🔓 Opening Control (Open Register)

When the cashier logs in to start a new shift, the **Opening Control** dialog opens:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Opening Control                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  Opening cash                                                               │
│  ┌───────────────────────────────────────────────────────────────┬───────┐  │
│  │ 345.00                                                      ✖ │  💵   │  │
│  └───────────────────────────────────────────────────────────────┴───────┘  │
│                                                                             │
│  Opening note                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Opening details:                                                      │  │
│  │   1 x $ 5.00                                                          │  │
│  │   2 x $ 20.00                                                         │  │
│  │   1 x $ 100.00                                                        │  │
│  │   1 x $ 200.00                                                        │  │
│  │ Total: $ 345.00                                                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  [ Open Register ]        [ Discard ]                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Hardware Action**: Clicking **Open Register** triggers an ESC/POS drawer kick pulse (`ESC p 0 25 250`) to allow the cashier to place the starting float into the drawer.
- **Denomination Calculator**: Quick bill/coin counter generates structured opening notes.

---

### 2. 💸 Cash In / Cash Out (Petty Cash Movements)

During the shift, non-sales cash adjustments are tracked with strict accountability:
- **Cash In**: Adding additional change float or coin bags from the safe.
- **Cash Out**: Safe drops (removing excess cash for security), paying local delivery drivers, or paying emergency store supplies.
- **Supervisor Audit**: Cash Out above configured thresholds requires a Sub Boss PIN.

---

### 3. 🔒 Closing Register & Discrepancy Reconciliation

At shift completion, the cashier triggers **Closing Register** to reconcile expected vs. actual money:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Closing Register                                         2 orders: $ 0.00  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cash                                                                       │
│    Opening                                                         $ 337.28 │
│    Payments in Cash                                                $ 345.00 │
│  ▸ Cash In / Out                                                    $  7.72 │
│    Counted                                                         + $ 0.00 │
│    Difference                                                      $ 337.28 │
│                                                                             │
│  Card                                                                       │
│    Counted                                                          $  7.72 │
│    Difference                                                       $  0.00 │
│                                                                             │
│  Customer Account                                                           │
│    Counted                                                          $  0.00 │
│    Difference                                                       $  0.00 │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cash Count                                 Card Count                      │
│  ┌───────────────────────┬───┬───┐          ┌───────────────────────┬───┐   │
│  │ 337.28                │ ✖ │ 💵│          │ 7.72                  │ ✖ │   │
│  └───────────────────────┴───┴───┘          └───────────────────────┴───┘   │
│                                                                             │
│  Opening note                               Closing note                    │
│  ┌───────────────────────────────────────┐  ┌────────────────────────────┐  │
│  │ Opening details:                      │  │ Add a closing note...      │  │
│  │   1 x $ 5.00                          │  │                            │  │
│  │   2 x $ 20.00                         │  │ Shift balanced, no short.  │  │
│  │   1 x $ 100.00                        │  │ All change verified.       │  │
│  │   1 x $ 200.00                        │  │                            │  │
│  │ Total: $ 345.00                       │  │                            │  │
│  └───────────────────────────────────────┘  └────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────────────┤
│  [ Close Register ]  [ Discard ]            [ Cash In/Out ]  [ Daily Sale 📥]│
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Discrepancy Formula**:
  $$\text{Expected Cash} = \text{Opening Float} + \text{Cash Sales} + \text{Cash In} - \text{Cash Out}$$
  $$\text{Cash Difference} = \text{Counted Cash} - \text{Expected Cash}$$
- **Color-Coded Feedback**: Green if difference is `$0.00` (Balanced), Red if negative (Shortage), Blue if positive (Overage).

---

### 4. 📥 Daily Sale Export & Thermal Z-Report Printing

Clicking **Daily Sale 📥** produces both digital exports and physical thermal audit receipts:
- **PDF & Excel (.xlsx) Register Summary**: Multi-tender breakdown, itemized hourly sales, cashier name, and shift duration.
- **Thermal Z-Report (80mm / 58mm)**: Prints directly to the receipt printer with:
  - Store Name & Branch ID
  - Register Session ID & Timestamp
  - Opening Float Amount
  - Total Cash, Card, and QR Sales
  - Total Cash In / Cash Out Movements
  - Final Counted Cash & Discrepancy (+/-)
  - Signature line for Cashier and Store Manager

---

## 💰 Hybrid Profit-Sharing & Settlement Model (Sub Bosses ➔ Main Boss)

To provide an equitable, high-incentive commercial partnership between the **Main Boss** and the **2 Sub Bosses**, OmniPOS incorporates a built-in **Hybrid Royalty Settlement Engine**.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                        HYBRID FRANCHISE SETTLEMENT FORMULA                        │
│                                                                                   │
│   Total Payout to Main Boss = [ Fixed Low Base Rent ]                             │
│                               + [ (Low Royalty %) x (Product Sales Revenue) ]     │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Hybrid Revenue Mechanism Explained

1. **Low Fixed Base Rent (Fixed Component)**:
   - A modest, affordable fixed facility/brand lease fee (e.g., **\$500 / month** or **\$15 / day**) paid by each Sub Boss to the Main Boss.
   - Covers store location usage rights, central server hosting, and software licensing.
   - Low enough so Sub Bosses do not suffer heavy cash drag during slower seasons.

2. **Low Percentage of Products Sold (Variable Royalty Component)**:
   - A low percentage commission (e.g., **3.0%** of gross product sales) automatically accrued upon each completed POS checkout.
   - Accurately tracks every product line item sold through the cashier terminal.
   - Aligns the Main Boss's incentives with the Sub Bosses' sales volume growth.

---

### Interactive Side-by-Side Settlement Demonstration

Below is a live financial settlement demonstration for a standard operating month (September 2026) with:
- **Base Rent**: \$500 / month per store
- **Product Sales Royalty**: 3.0% of product sales
- **Store A Sales**: \$45,280.00 | **Store B Sales**: \$38,500.00

| Financial Metric | 👔 Sub Boss 1 (Store A) | 👔 Sub Boss 2 (Store B) | 👑 Main Boss (Owner Executive) |
| :--- | :---: | :---: | :---: |
| **Gross Product Sales** | \$ 45,280.00 | \$ 38,500.00 | — *(Central Inflow)* |
| **Cost of Goods Sold (COGS)** | (\$ 18,120.00) | (\$ 15,400.00) | — |
| **Store Gross Margin** | **\$ 27,160.00** | **\$ 23,100.00** | — |
| 🏷️ **Low Base Rent Paid to Main Boss** | (\$ 500.00) | (\$ 500.00) | **+ \$ 1,000.00** *(Rent Inflow)* |
| 🏷️ **Low % Product Royalty Paid (3%)** | (\$ 1,358.40) | (\$ 1,155.00) | **+ \$ 2,513.40** *(Royalty Inflow)* |
| **Total Hybrid Paid to Main Boss** | **(\$ 1,858.40)** | **(\$ 1,655.00)** | **+ \$ 3,513.40** *(Total Hybrid Revenue)* |
| **Local Store Expenses (Staff, Power)** | (\$ 4,200.00) | (\$ 3,800.00) | (\$ 300.00) *(Central Cloud & Admin)* |
| **Other Income / Fees** | + \$ 240.00 | + \$ 180.00 | — |
| 🏆 **NET PROFIT (Take-Home)** | **\$ 21,341.60** | **\$ 17,825.00** | **\$ 3,213.40** *(Passive Executive Net)* |

---

## 📊 Odoo-Style Mini-Accounting System (Profit & Loss)

The accounting engine matches the structured **Profit and Loss (P&L)** financial reporting architecture modeled after **Odoo Accounting (US GAAP / IFRS Standard)**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ODOO PROFIT AND LOSS REPORT — MASTER ENTERPRISE             │
│  Period: [ 2026 ]  |  Comparison  |  Posted Entries  | Currency: [ In $ ]   │
├──────────────────────────────────────────────────────────────┬──────────────┤
│  Income                                                      │      Balance │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Cost of Sales                                             │         0.00 │
│    Gross Profit                                              │         0.00 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  Expense                                                     │              │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Net Operating Income                                      │         0.00 │
│    Other Income                                              │         0.00 │
│    Other Expense                                             │         0.00 │
│    Net Other Income                                          │         0.00 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  Net Income                                                  │         0.00 │
└──────────────────────────────────────────────────────────────┴──────────────┘
```

---

### Sub Boss Branch P&L (Store A & Store B View)

Sub Bosses view their branch-specific P&L reflecting sales, COGS, the hybrid settlement payment to the Main Boss, and local operating expenses:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ODOO PROFIT AND LOSS REPORT — STORE A (DOWNTOWN)            │
│  Period: [ 2026 ]  |  Branch: [ Store A - Downtown ]  |  Currency: [ $ ]    │
├──────────────────────────────────────────────────────────────┬──────────────┤
│  INCOME                                                      │      BALANCE │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Product Sales Revenue (Gross Sales - Discounts)           │  $ 45,280.00 │
│    Cost of Sales (COGS - Cost of Goods Sold)                 │ ($ 18,120.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  GROSS PROFIT                                                │  $ 27,160.00 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  EXPENSE                                                     │              │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Hybrid Settlement to Main Boss:                           │              │
│      - Base Store Rent (Fixed Low Rent)                      │ ($    500.00)│
│      - Product Sales Royalty (3.0% of Products Sold)         │ ($  1,358.40)│
│    Local Store Operating Expenses (Staff Wages, Utilities)   │ ($  4,200.00)│
│    Store Supplies & POS Hardware Maintenance                 │ ($    420.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET OPERATING INCOME                                        │  $ 20,681.60 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Other Income (Vendor Rebates, Delivery Fee Share)         │  $    350.00 │
│    Other Expense (Merchant Card Fees, Bank Charges)          │ ($    110.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET OTHER INCOME                                            │  $    240.00 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET INCOME (Sub Boss Net Take-Home)                         │  $ 20,921.60 │
└──────────────────────────────────────────────────────────────┴──────────────┘
```

---

### Main Boss Consolidated Master Executive P&L

The Main Boss has access to an **Executive Master P&L Statement** that aggregates hybrid payouts across all branches alongside enterprise-wide financials:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ODOO PROFIT AND LOSS REPORT — MASTER EXECUTIVE              │
│  Period: [ 2026 ]  |  Entity: [ Consolidated Enterprise ] | Currency: [ $ ] │
├──────────────────────────────────────────────────────────────┬──────────────┤
│  INCOME                                                      │      BALANCE │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Hybrid Store Base Rent Inflows:                           │              │
│      - Store A Fixed Rent                                    │  $    500.00 │
│      - Store B Fixed Rent                                    │  $    500.00 │
│    Hybrid Product Sales Royalty Inflows:                     │              │
│      - Store A Sales Royalty (3.0% on $45,280.00)            │  $  1,358.40 │
│      - Store B Sales Royalty (3.0% on $38,500.00)            │  $  1,155.00 │
│    Direct Enterprise Sales (Master Central Channels)         │  $  6,200.00 │
│    Master Direct COGS                                        │ ($  2,100.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  GROSS REVENUE & ROYALTY INFLOW                              │  $  7,613.40 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  EXPENSE                                                     │              │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Central Software Hosting, Cloud DB & Infrastructure       │ ($    300.00)│
│    Master Enterprise Insurance & Legal Audits                │ ($    450.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET OPERATING INCOME                                        │  $  6,863.40 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│    Other Income (Master Asset Appreciation / Investments)    │  $    200.00 │
│    Other Expense (Corporate Banking & Filing Fees)           │ ($     80.00)│
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET OTHER INCOME                                            │  $    120.00 │
├──────────────────────────────────────────────────────────────┼──────────────┤
│  NET EXECUTIVE INCOME (Main Boss Net Bottom Line)            │  $  6,983.40 │
└──────────────────────────────────────────────────────────────┴──────────────┘
```

---

### Chart of Accounts (COA) & POS Journal Entries

OmniPOS automatically creates double-entry accounting records for every session and sale:

```text
[POS Order Checkout #042]
  Debit:  101000 Cash on Hand (or 102000 Bank QR)       $ 55.94
  Credit: 400000 Product Sales Revenue                  $ 50.85
  Credit: 201000 Output Tax / VAT Payable               $  5.09

[Inventory COGS Realization]
  Debit:  500000 Cost of Goods Sold (COGS)              $ 22.40
  Credit: 105000 Inventory Asset                       $ 22.40

[Monthly Hybrid Royalty Accrual]
  Debit:  605000 Franchise Royalty Expense (Store A)    $ 1,858.40
  Credit: 203000 Main Boss Royalty Payable              $ 1,858.40
```

---

## 🧾 Invoice & Digital Receipt Specification

OmniPOS produces both **80mm/58mm ESC/POS Thermal Receipts** and **Standard Full-Page A4 / Letter PDF Invoices**.

### Thermal Receipt (80mm / 58mm) & Customer Display (CFD)

```text
================================================
               GOURMET BISTRO POS               
           Store Branch A - Downtown           
      123 Boulevard St, Suite 100, City        
               Tel: +1 (555) 019-2834           
------------------------------------------------
Receipt #: RCP-20260902-0042      Order #: #042
Date: 2026-09-02 16:45:10         Type: Dine-In
Cashier: Cashier 01               Table: Table 04
Customer: John Doe
Payment: CASH
------------------------------------------------
ITEM                          QTY        TOTAL
------------------------------------------------
Wagyu Burger Deluxe             2      $ 37.00
  * Medium Rare, Extra Cheese
Truffle Parmesan Fries          1      $  8.50
Iced Caramel Macchiato          2      $ 11.00
------------------------------------------------
Subtotal:                              $ 56.50
Discount (10%):                       -$  5.65
Tax/VAT (10%):                         $  5.09
------------------------------------------------
TOTAL DUE:                             $ 55.94
Cash Tendered:                         $ 60.00
Change Due:                            $  4.06
------------------------------------------------
             [ QR CODE PAYMENT ]                
        Scan to verify receipt & pay            
------------------------------------------------
     Thank you for dining with us!              
          Please visit again!                   
       *** OmniPOS Dual-Screen ***              
================================================
```

---

### Full Enterprise Tax Invoice Layout

For corporate accounts, wholesale orders, and official accounting documentation, the system exports standardized PDF invoices with:
- **Enterprise Header**: Registered Business Name, Tax ID / VAT Number, Branch Address, Contact Information, and Official Logo.
- **Invoice Meta**: Unique Invoice Number (`INV-YYYYMMDD-XXXX`), Issue Date, Due Date, Payment Terms, and Serving Cashier ID.
- **Billed To**: Client Name, Company Name, Tax Registration, and Billing Address.
- **Itemized Ledger**: SKU / Code, Item Description, Quantity, Base Unit Price, Line Discount %, Net Amount, and Tax Rate.
- **Financial Summary**: Net Subtotal, Aggregate Discount, Applicable Tax (Breakdown by rate), and Final Total Payable.
- **Settlement Record**: Payment Channel (Cash / Bank QR / Card), Transaction Reference, and Balance Due.

---

## 🖨️ Physical Hardware Setup & Cash Drawer Integration

OmniPOS is optimized for commercial heavy-duty desktop dual-screen POS hardware rigs:

```
                   ┌───────────────────────────────┐
                   │    PRIMARY CASHIER TOUCH      │
                   │    15.6" Capacitive Touch     │
                   └───────────────┬───────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
 ┌────────────▼────────────┐               ┌────────────▼────────────┐
 │ CUSTOMER DISPLAY (CFD)  │               │ THERMAL RECEIPT PRINTER │
 │ 10.1" - 15.6" Secondary │               │ Built-in 80mm High Speed│
 └─────────────────────────┘               └────────────┬────────────┘
                                                        │ RJ11 / RJ12
                                                        │ Kick Pulse
                                           ┌────────────▼────────────┐
                                           │ HEAVY-DUTY CASH DRAWER  │
                                           │ Metal 5-Bill / 8-Coin   │
                                           └─────────────────────────┘
```

- **Dual Display Terminal**: White/silver commercial POS unit with 15.6" cashier landscape touch monitor and secondary customer display.
- **Built-in 80mm Thermal Printer**: High-speed receipt printer supporting direct bitmap logos and ESC/POS barcodes.
- **RJ11 Cash Drawer Interface**: Heavy-duty black metal cash drawer sitting directly beneath the POS terminal, auto-triggered on opening control and cash checkout.

---

## 🖥️ Technical Architecture & Project Map

```text
lib/
├── app_config.dart                    # Theme constants, palette, typography, grid configs
├── main.dart                          # Dual entry points (Cashier App & Secondary CFD)
│
├── core/                              # Core Architecture & Utilities
│   ├── async_guard.dart               # Safe asynchronous execution handlers
│   ├── debouncer.dart                 # Real-time search debouncing
│   └── theme/
│       └── color_theme.dart           # UI color palettes & typography tokens
│
├── models/                            # Immutable Data Models
│   ├── models.dart                    # Barrel export
│   ├── user_model.dart                # Main Boss, Sub Boss, Staff roles & permissions
│   ├── register_session_model.dart    # Opening/Closing cash, discrepancy, notes
│   ├── cash_movement_model.dart       # Cash In / Cash Out petty cash movements
│   ├── dining_table_model.dart        # Table floor plan & seating states
│   ├── order_model.dart               # Orders, Order Items & Receipt Logs
│   ├── product_model.dart             # Products, Categories, Combos & Variants
│   ├── hybrid_settlement_model.dart   # Low rent, % product royalty, payout records
│   ├── accounting_model.dart          # P&L entries, Expense journal & COGS records
│   └── store_settings_model.dart      # Branch config, hardware & printer toggles
│
├── controllers/                       # State Management (Provider / ChangeNotifier)
│   ├── controllers.dart               # Barrel export
│   ├── auth_controller.dart           # Role-based auth (Main Boss, Sub Boss, Cashier)
│   ├── register_controller.dart       # Open/Close register, Cash In/Out, Daily Sales
│   ├── cart_controller.dart           # Cart state, Action Numpad, discounts, taxes
│   ├── pos_controller.dart            # Order lifecycle, tender, receipt dispatch
│   ├── table_controller.dart          # Table seating, Bill Splitting, Table Transfer
│   ├── hybrid_settlement_controller.dart # Computes Sub Boss ➔ Main Boss royalty & rent
│   ├── accounting_controller.dart     # Odoo-style P&L computation & journal entries
│   ├── dashboard_controller.dart      # Real-time KPIs, charts & sales rankings
│   └── settings_controller.dart       # Store branding, printer & peripheral config
│
├── database/                          # Local SQLite Persistence Layer
│   ├── database.dart                  # Barrel export
│   ├── db_helper.dart                 # Database initialization, migrations & seeds
│   ├── register_dao.dart              # Register sessions & Cash In/Out movements
│   ├── order_dao.dart                 # Orders, receipts & sales history queries
│   ├── product_dao.dart               # Product catalog CRUD & barcode lookups
│   ├── table_dao.dart                 # Dining table queries & floor plan persistence
│   ├── hybrid_settlement_dao.dart     # Royalty agreements & payout ledger queries
│   ├── accounting_dao.dart            # P&L ledger, expense journals & COGS queries
│   └── settings_dao.dart              # Key-value store for branch preferences
│
├── services/                          # Hardware Drivers & IO Services
│   ├── services.dart                  # Barrel export
│   ├── presentation_service.dart      # Dual-screen Customer Display bridge
│   ├── printer_service.dart           # ESC/POS 58mm/80mm thermal receipt driver
│   ├── pdf_receipt_service.dart       # High-res PDF invoice & Daily Sale export
│   ├── excel_export_service.dart      # Multi-sheet Excel (.xlsx) financial exporter
│   ├── receipt_file_service.dart      # Receipt archive & file system manager
│   └── barcode_service.dart           # USB/HID hardware scanner stream listener
│
├── views/                             # Presentation Layer UI
│   ├── splash/                        # Splash Screen & Role Selection / PIN Login
│   │   └── splash_screen.dart
│   ├── register/                      # Cash Register Modals & Views
│   │   ├── open_register_dialog.dart  # Opening Control with denomination calculator
│   │   ├── close_register_dialog.dart # Closing Register with Cash/Card count & Daily Sale
│   │   └── cash_in_out_dialog.dart    # Cash In / Cash Out petty adjustment modal
│   ├── cashier/                       # Cashier 3-Column POS Landscape Screen
│   │   ├── cashier_main_layout.dart
│   │   └── widgets/
│   │       ├── top_header_bar.dart    # Branch info, cashier name, clock, register status
│   │       ├── nav_sidebar.dart       # Module navigation (POS, Tables, History, Admin)
│   │       ├── category_bar.dart      # Category & subcategory horizontal selector
│   │       ├── product_grid.dart      # Responsive grid with item cards
│   │       └── cart_panel.dart        # Action Numpad, discounts, tender buttons
│   ├── tables/                        # Visual Dine-In Floor Plan
│   │   ├── table_management_screen.dart
│   │   └── widgets/
│   │       ├── assign_table_dialog.dart
│   │       └── split_bill_dialog.dart # Odoo-style Bill Split modal
│   ├── accounting/                    # Odoo-Style Profit & Loss Screen
│   │   ├── profit_loss_screen.dart    # Income, COGS, Expense, Net Income layout
│   │   └── widgets/
│   │       ├── pl_table_widget.dart   # Interactive collapsible P&L rows
│   │       ├── hybrid_settlement_card.dart # Sub Boss ➔ Main Boss royalty summary
│   │       └── expense_entry_dialog.dart # Quick operating expense logger
│   ├── customer_display/              # Secondary Screen Customer View
│   │   ├── customer_main_view.dart
│   │   ├── customer_presentation_view.dart
│   │   └── widgets/
│   │       └── qr_display.dart        # Dynamic payment QR & total due
│   ├── dashboard/                     # Analytics & KPI Screen
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       └── metrics_card.dart
│   ├── products/                      # Product Catalog & Category Management
│   │   ├── product_list_screen.dart
│   │   └── category_screen.dart
│   ├── history/                       # Receipts History & Reprint Archive
│   │   └── receipt_history_screen.dart
│   └── settings/                      # Hardware & Branch Settings
│       └── store_settings_screen.dart
│
└── widgets/                           # Reusable UI Components & Modals
    ├── custom_dialogs.dart            # Cash tender calculator & QR pay modal
    ├── image_picker_dialog.dart       # File picker dialog for logos & assets
    ├── receipt_preview_dialog.dart    # On-screen thermal receipt digital preview
    └── error_banner.dart              # Offline status banner & notification toasts
```

---

## 🗄️ Database Schema & Entities

The SQLite database (`pos_database.db`) contains structured tables with referential integrity:

```sql
-- Store Branches
CREATE TABLE branches (
    id TEXT PRIMARY KEY,
    branch_name TEXT NOT NULL,
    branch_code TEXT UNIQUE NOT NULL,
    address TEXT,
    phone TEXT,
    is_active INTEGER DEFAULT 1
);

-- Users & Role-Based Access Control
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL, -- 'MAIN_BOSS', 'SUB_BOSS', 'STAFF_CASHIER'
    branch_id TEXT,     -- NULL for Main Boss (Global), Branch ID for Sub Boss & Staff
    pin_code TEXT NOT NULL,
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (branch_id) REFERENCES branches(id)
);

-- Cash Register Sessions (Odoo Register Lifecycle)
CREATE TABLE register_sessions (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    cashier_id TEXT NOT NULL,
    opened_at TEXT NOT NULL,
    closed_at TEXT,
    opening_cash REAL NOT NULL DEFAULT 0.0,
    opening_notes TEXT,
    closing_cash_counted REAL,
    closing_card_counted REAL,
    expected_cash REAL,
    cash_difference REAL,
    closing_notes TEXT,
    status TEXT DEFAULT 'OPEN', -- 'OPEN', 'CLOSED'
    FOREIGN KEY (branch_id) REFERENCES branches(id),
    FOREIGN KEY (cashier_id) REFERENCES users(id)
);

-- Cash In / Cash Out Movements (Petty Cash)
CREATE TABLE cash_movements (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    type TEXT NOT NULL, -- 'CASH_IN', 'CASH_OUT'
    amount REAL NOT NULL,
    reason TEXT NOT NULL,
    authorized_by_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES register_sessions(id),
    FOREIGN KEY (authorized_by_id) REFERENCES users(id)
);

-- Hybrid Franchise Settlement Configuration (Per Store)
CREATE TABLE hybrid_settlement_configs (
    id TEXT PRIMARY KEY,
    branch_id TEXT UNIQUE NOT NULL,
    base_rent_amount REAL NOT NULL DEFAULT 500.0,      -- Fixed Low Base Rent ($)
    royalty_percent REAL NOT NULL DEFAULT 3.0,          -- Low % of Products Sold
    settlement_cycle TEXT DEFAULT 'MONTHLY',            -- 'DAILY', 'WEEKLY', 'MONTHLY'
    FOREIGN KEY (branch_id) REFERENCES branches(id)
);

-- Hybrid Royalty Payout Ledger
CREATE TABLE hybrid_royalty_payouts (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    gross_product_sales REAL NOT NULL,
    base_rent_paid REAL NOT NULL,
    royalty_amount_paid REAL NOT NULL,
    total_payout_to_main_boss REAL NOT NULL,
    payment_status TEXT DEFAULT 'SETTLED', -- 'PENDING', 'SETTLED'
    settled_at TEXT,
    FOREIGN KEY (branch_id) REFERENCES branches(id)
);

-- Categories & Subcategories
CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon_name TEXT,
    display_order INTEGER DEFAULT 0
);

-- Product Catalog with Cost of Goods Sold (COGS) tracking
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    sku TEXT UNIQUE NOT NULL,
    barcode TEXT,
    name TEXT NOT NULL,
    category_id TEXT NOT NULL,
    cost_price REAL NOT NULL DEFAULT 0.0, -- Used for COGS in P&L
    selling_price REAL NOT NULL,
    tax_rate REAL DEFAULT 0.0,
    stock_quantity INTEGER DEFAULT 0,
    image_path TEXT,
    is_available INTEGER DEFAULT 1,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Dining Tables
CREATE TABLE dining_tables (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    table_number TEXT NOT NULL,
    capacity INTEGER DEFAULT 4,
    status TEXT DEFAULT 'AVAILABLE', -- 'AVAILABLE', 'OCCUPIED', 'RESERVED'
    current_order_id TEXT,
    FOREIGN KEY (branch_id) REFERENCES branches(id)
);

-- Orders Ledger
CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    receipt_no TEXT UNIQUE NOT NULL,
    order_number TEXT,
    cashier_id TEXT NOT NULL,
    table_id TEXT,
    customer_name TEXT,
    order_type TEXT DEFAULT 'DINE_IN',
    subtotal REAL NOT NULL,
    discount_amount REAL DEFAULT 0.0,
    discount_percent REAL DEFAULT 0.0,
    tax_amount REAL DEFAULT 0.0,
    tax_rate REAL DEFAULT 0.0,
    total_amount REAL NOT NULL,
    payment_method TEXT NOT NULL, -- 'CASH', 'QR', 'CARD'
    cash_tendered REAL DEFAULT 0.0,
    change_amount REAL DEFAULT 0.0,
    status TEXT DEFAULT 'COMPLETED',
    created_at TEXT NOT NULL,
    FOREIGN KEY (branch_id) REFERENCES branches(id),
    FOREIGN KEY (cashier_id) REFERENCES users(id)
);

-- Order Items (Itemized breakdown)
CREATE TABLE order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    cost_price REAL NOT NULL DEFAULT 0.0, -- Historical cost snapshot for P&L COGS
    unit_price REAL NOT NULL,
    total_price REAL NOT NULL,
    notes TEXT,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Operating Expenses Journal (For Odoo-style P&L)
CREATE TABLE expenses (
    id TEXT PRIMARY KEY,
    branch_id TEXT NOT NULL,
    expense_category TEXT NOT NULL, -- 'OPERATING', 'SUPPLIES', 'UTILITIES', 'OTHER'
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    notes TEXT,
    logged_by_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (branch_id) REFERENCES branches(id)
);
```

---

## 🚀 Quick Start & Installation

### Prerequisites

- **Flutter SDK**: `^3.13.0` or higher ([Download Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK**: Included with Flutter
- **Platform Toolchains**:
  - **Android**: Android Studio with Android SDK API 24+ & NDK
  - **Windows**: Visual Studio 2022 with *Desktop development with C++* workload installed

---

### Installation Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Thylyyong/POS.git
   cd POS
   ```

2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Automated Test Suite**:
   ```bash
   flutter test
   ```

4. **Launch on Connected Device or Desktop**:
   ```bash
   # Run on Windows Desktop
   flutter run -d windows

   # Run on Connected Android POS Terminal (e.g., Sunmi, iMin)
   flutter run -d android
   ```

5. **Build Production Release**:
   ```bash
   # Android Release APK
   flutter build apk --release

   # Windows Release Executable
   flutter build windows --release
   ```

---

### Default Credentials & Access PINs

| Role / Feature | Account Username | Default PIN | Permissions & Scope |
| :--- | :--- | :---: | :--- |
| 👑 **Owner / Main Boss** | `admin` / `main_boss` | **`9999`** | Full System Access: Master Accounting, Product & Variant Editor, Changing Staff PINs, Global Settings |
| 🏷️ **Staff Cashier** | `cashier_01` | **`1234`** | Frontline POS Terminal, Cash Register Float & Cash Movements, Order Taking & Checkout |
| 👨‍🍳 **Kitchen Chef** | `chef_01` | **`5555`** | Kitchen Display Screen (KDS), Course Sequencing, Order Preparation Status |
| 🔒 **Close Register PIN** | *Owner / Supervisor* | **`9999`** | Authorizes physical drawer tally verification, discrepancy logging, and shift closing |
| ⚙️ **Manager Override** | *Supervisor PIN* | **`9999`** | Line-item discount approval and price overrides |

---

### 🛡️ PIN Entry Behavior: Manual Confirmation Required (No Auto-Login)

To eliminate accidental logins and unauthorized access:
- **No Automatic Login on 4th Digit**: Entering 4 digits will **NOT** immediately submit or unlock the screen.
- **Manual Confirm Action**: The user must explicitly tap the **"Confirm & Sign In"** / **"Confirm"** button (or press the **Enter** key on a physical keyboard / barcode scanner).
- **Clear Action ('C')**: Users can tap **`C`** to clear the PIN pad buffer at any time if a mistake is made.

---

### 🔑 How to Change PINs for Staff and Owner

1. Log into the system using the Owner account (`9999`).
2. Open **Settings** (`⚙️`) from the left navigation sidebar.
3. Locate the **Security & Staff Accounts** card.
4. Each account (`Owner (Boss)`, `Staff Cashier`, `Kitchen Chef`) is listed with its active role.
5. Tap **"Change PIN"** or choose the desired account from the dropdown selector.
6. Enter a new 4-digit numeric PIN, re-enter it to confirm, and click **"Save PIN"**.
7. The PIN is saved instantly to the local SQLite database and becomes active immediately across all authentication dialogs.

---

### 🏪 Single-Store Operation

The application is configured specifically for **Single Store** retail and food & beverage operations:
- Unnecessary multi-branch dropdown switchers (Store A / Store B / Global) have been removed from the header and accounting views to provide a fast, distraction-free interface.
- All session reporting, Z-reports, and order receipts represent the unified current store.

---

## 📄 License & Intellectual Property

This project is proprietary software developed for **OmniPOS Enterprise Systems**. All rights reserved. Unauthorized copying, distribution, or modification is strictly prohibited.