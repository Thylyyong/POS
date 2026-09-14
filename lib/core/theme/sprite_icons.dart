/// Centralized constants for all icons available in `assets/images/sprite.svg`.
///
/// Use these with [AppSvgIcon] or [AppSvgIcon.sprite] across the entire POS app:
/// ```dart
/// AppSvgIcon(SpriteIcons.pos, size: 24, color: Colors.blue)
/// // or
/// AppSvgIcon.sprite(SpriteIcons.cash, size: 20)
/// ```
class SpriteIcons {
  SpriteIcons._();

  // Navigation & Core App
  static const pos = 'icon-pos';
  static const tables = 'icon-table';
  static const products = 'icon-box-v2';
  static const categories = 'icon-category-v2';
  static const history = 'icon-receipt';
  static const accounting = 'icon-bar-chart';
  static const analytics = 'icon-bar-chart';
  static const dashboard = 'icon-dashboard';
  static const settings = 'icon-settings';
  static const profile = 'icon-profile';
  static const profileOutline = 'icon-profile-outline';

  // Cashier & Orders
  static const cash = 'icon-cash';
  static const cashRegister = 'icon-cash-register';
  static const vault = 'icon-vault';
  static const cart = 'icon-cart';
  static const ticket = 'icon-ticket';
  static const shift = 'icon-shift';
  static const calculator = 'icon-calculator';
  static const spreadsheet = 'icon-file-spreadsheet';
  static const banknote = 'icon-banknote';
  static const wallet = 'icon-wallet';
  static const walletSolid = 'icon-wallet-solid';

  // Printing & Payments
  static const printer = 'icon-printer';
  static const print = 'icon-print';
  static const receipt = 'icon-receipt';
  static const receiptV2 = 'icon-receipt-v2';
  static const qr = 'icon-qr';
  static const khqr = 'icon-khqr';
  static const barcode = 'icon-barcode';

  // Actions & Controls
  static const search = 'icon-search';
  static const searchGlass = 'icon-search-glass';
  static const filter = 'icon-filter';
  static const plus = 'icon-plus';
  static const plusV2 = 'icon-plus-v2';
  static const minus = 'icon-arrow-down';
  static const close = 'icon-x';
  static const check = 'icon-check';
  static const checkCircle = 'icon-check-circle';
  static const trash = 'icon-trash';
  static const delete = 'icon-delete';
  static const deleteBack = 'icon-delete-back';
  static const copy = 'icon-copy';
  static const share = 'icon-share';
  static const refresh = 'icon-refresh';
  static const edit = 'icon-edit-outline';
  static const editV2 = 'icon-edit-v2';
  static const more = 'icon-more';
  static const dots = 'icon-3-dots';
  static const dotsV2 = 'icon-3-dots-v2';

  // Status & Feedback
  static const warning = 'icon-warning';
  static const alert = 'icon-alert';
  static const alertCircle = 'icon-alert-circle';
  static const info = 'icon-info';
  static const star = 'icon-star';
  static const starOutline = 'icon-star-outline';
  static const starFill = 'icon-star-fill';
  static const clock = 'icon-clock';
  static const calendar = 'icon-calendar';
  static const trendingUp = 'icon-trending-up';
  static const trendingDown = 'icon-trending-down';

  // Security & Users
  static const lock = 'icon-lock';
  static const unlock = 'icon-unlock';
  static const shieldLock = 'icon-shield-lock';
  static const user = 'icon-user';
  static const users = 'icon-users';
  static const staff = 'icon-staff';
  static const role = 'icon-role';

  // Restaurant & Catalog
  static const utensils = 'icon-utensils-crossed';
  static const cupSoda = 'icon-cup-soda';
  static const room = 'icon-room';
  static const table = 'icon-table';
  static const building = 'icon-building';
  static const image = 'icon-image';
  static const imageOff = 'icon-image-off';
  static const tag = 'icon-tag';
  static const list = 'icon-list';
  static const layout = 'icon-layout';

  // Hardware & Devices
  static const computer = 'icon-computer';
  static const pcMobile = 'icon-pc-mobile';
  static const bolt = 'icon-bolt';
  static const server = 'icon-server';
  static const phone = 'icon-phone';

  // Directional
  static const arrowLeft = 'icon-arrow-left';
  static const arrowRight = 'icon-arrow-right';
  static const arrowDown = 'icon-arrow-down';
}
