/// Represents the response received from backend `/api/aba/create-qr`
/// (or `/generate-qr`) after PayWay dynamic QR generation.
class AbaQrResponse {
  /// Status code or status string returned by backend (e.g. 0, "0", 200, "success")
  final String status;

  /// Response message or description from backend
  final String message;

  /// Merchant transaction ID associated with this payment
  final String tranId;

  /// Raw EMVCo KHQR payload string to be rendered as QR code
  final String qrString;

  /// Optional base64-encoded image or hosted image URL (if backend provides one)
  final String? qrImage;

  /// Transaction amount
  final double? amount;

  /// Currency code ('USD' or 'KHR')
  final String currency;

  /// Full raw JSON response for debugging or backend-specific extensions
  final Map<String, dynamic> rawJson;

  const AbaQrResponse({
    required this.status,
    required this.message,
    required this.tranId,
    required this.qrString,
    this.qrImage,
    this.amount,
    this.currency = 'USD',
    this.rawJson = const {},
  });

  /// Whether the QR generation was successful
  bool get isSuccess {
    final s = status.trim().toLowerCase();
    return s == '0' || s == '200' || s == 'success' || s == 'ok';
  }

  /// Parse backend response with robust field fallbacks and type safety
  factory AbaQrResponse.fromJson(Map<String, dynamic> json) {
    // Status can be integer, string, or boolean
    final rawStatus = json['status'] ?? json['code'] ?? json['status_code'];
    final statusStr = rawStatus != null ? rawStatus.toString() : '0';

    // Message / Description
    final messageStr = (json['message'] ??
            json['description'] ??
            json['msg'] ??
            (statusStr == '0' ? 'Success' : ''))
        .toString();

    // Transaction ID (support tran_id, tranId, transaction_id)
    final tranIdStr = (json['tran_id'] ??
            json['tranId'] ??
            json['transaction_id'] ??
            json['order_id'] ??
            '')
        .toString();

    // Raw QR string (support qr_string, qrString, qr_data, qr, khqr)
    final qrDataStr = (json['qr_string'] ??
            json['qrString'] ??
            json['qr_data'] ??
            json['qr'] ??
            json['khqr'] ??
            json['data']?['qr_string'] ??
            '')
        .toString();

    // QR Image (optional)
    final qrImageStr = (json['qr_image'] ??
            json['qrImage'] ??
            json['qr_url'] ??
            json['data']?['qr_image'])
        ?.toString();

    // Amount parsing (handles num, int, double, String)
    double? parsedAmount;
    final rawAmount = json['amount'] ?? json['data']?['amount'];
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount);
    }

    // Currency
    final currencyStr = (json['currency'] ??
            json['data']?['currency'] ??
            'USD')
        .toString()
        .toUpperCase();

    return AbaQrResponse(
      status: statusStr,
      message: messageStr,
      tranId: tranIdStr,
      qrString: qrDataStr,
      qrImage: qrImageStr,
      amount: parsedAmount,
      currency: currencyStr,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        'tran_id': tranId,
        'qr_string': qrString,
        'qr_image': qrImage,
        'amount': amount,
        'currency': currency,
      };

  @override
  String toString() =>
      'AbaQrResponse(tranId: $tranId, status: $status, message: $message, qrStringLen: ${qrString.length})';
}

/// Represents the response received from backend `/api/aba/check-status`
/// (or `/check-transaction`) during polling.
class AbaCheckStatusResponse {
  /// Status code from PayWay / backend.
  /// In ABA PayWay standard:
  /// - "0" (or 0) = Approved / Successful payment
  /// - "1" (or 1) = Pending / Customer has not completed payment yet
  /// - "2" or other = Declined / Cancelled / Expired / Failed
  final String status;

  /// Informational message from backend or bank
  final String message;

  /// Transaction ID checked
  final String tranId;

  /// Confirmed payment amount (if returned by backend)
  final double? amount;

  /// Confirmed currency ('USD' or 'KHR')
  final String? currency;

  /// Approval Code / Bank authorization code (APV)
  final String? apv;

  /// Date & time payment was completed
  final String? paymentDate;

  /// Payment method detail (e.g. 'ABA Mobile', 'KHQR')
  final String? paymentType;

  /// Full raw JSON payload
  final Map<String, dynamic> rawJson;

  const AbaCheckStatusResponse({
    required this.status,
    required this.message,
    required this.tranId,
    this.amount,
    this.currency,
    this.apv,
    this.paymentDate,
    this.paymentType,
    this.rawJson = const {},
  });

  /// Returns true when payment is officially Approved / Settled
  bool get isSuccess {
    final s = status.trim().toLowerCase();
    return s == '0' ||
        s == '200' ||
        s == 'approved' ||
        s == 'success' ||
        s == 'completed' ||
        s == 'paid';
  }

  /// Returns true when payment is still pending customer action
  bool get isPending {
    final s = status.trim().toLowerCase();
    return s == '1' ||
        s == 'pending' ||
        s == 'waiting' ||
        s == 'processing' ||
        s == 'in_progress';
  }

  /// Returns true if payment was cancelled, declined, or failed
  bool get isFailed => !isSuccess && !isPending;

  /// Parse backend status response with robust fallbacks
  factory AbaCheckStatusResponse.fromJson(Map<String, dynamic> json) {
    // Status normalization
    final rawStatus = json['status'] ?? json['code'] ?? json['status_code'];
    final statusStr = rawStatus != null ? rawStatus.toString() : '1';

    // Message
    final messageStr = (json['message'] ??
            json['description'] ??
            json['msg'] ??
            (statusStr == '0' ? 'Approved' : 'Pending'))
        .toString();

    // Transaction ID
    final tranIdStr = (json['tran_id'] ??
            json['tranId'] ??
            json['transaction_id'] ??
            json['order_id'] ??
            '')
        .toString();

    // Amount
    double? parsedAmount;
    final rawAmount = json['amount'] ??
        json['total_amount'] ??
        json['data']?['amount'];
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount);
    }

    // Currency
    final currencyStr = (json['currency'] ?? json['data']?['currency'])?.toString();

    // Approval code (apv)
    final apvStr = (json['apv'] ?? json['approval_code'] ?? json['data']?['apv'])?.toString();

    // Payment Date
    final paymentDateStr = (json['payment_date'] ??
            json['transaction_date'] ??
            json['paid_at'] ??
            json['date'])
        ?.toString();

    // Payment Type
    final paymentTypeStr = (json['payment_type'] ??
            json['payment_method'] ??
            json['type'])
        ?.toString();

    return AbaCheckStatusResponse(
      status: statusStr,
      message: messageStr,
      tranId: tranIdStr,
      amount: parsedAmount,
      currency: currencyStr,
      apv: apvStr,
      paymentDate: paymentDateStr,
      paymentType: paymentTypeStr,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        'tran_id': tranId,
        'amount': amount,
        'currency': currency,
        'apv': apv,
        'payment_date': paymentDate,
        'payment_type': paymentType,
      };

  @override
  String toString() =>
      'AbaCheckStatusResponse(tranId: $tranId, status: $status, isSuccess: $isSuccess, message: $message)';
}

/// Custom exception thrown when ABA PayWay API interactions fail
class AbaPaymentException implements Exception {
  final String message;
  final int? statusCode;
  final String? tranId;
  final dynamic details;

  const AbaPaymentException({
    required this.message,
    this.statusCode,
    this.tranId,
    this.details,
  });

  @override
  String toString() =>
      'AbaPaymentException(message: $message, statusCode: $statusCode, tranId: $tranId)';
}
