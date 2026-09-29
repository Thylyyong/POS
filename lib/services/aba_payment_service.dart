import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/aba_payment_models.dart';

/// Service for communicating with backend ABA PayWay integration endpoints.
/// 
/// Handles dynamic KHQR generation and non-blocking transaction verification.
class AbaPaymentService {
  /// Base URL of your backend server (e.g. 'https://api.yourdomain.com' or 'http://localhost:8000')
  final String baseUrl;

  /// Custom endpoint paths
  final String createQrPath;
  final String checkStatusPath;

  /// Underlying HTTP client
  final http.Client _client;

  /// Default HTTP timeout
  final Duration timeout;

  /// Singleton instance for quick access
  static AbaPaymentService? _instance;
  static AbaPaymentService get instance => _instance ??= AbaPaymentService();

  /// Configure the default shared instance
  static void configure({
    required String baseUrl,
    String createQrPath = '/api/aba/create-qr',
    String checkStatusPath = '/api/aba/check-status',
    Duration timeout = const Duration(seconds: 12),
  }) {
    _instance = AbaPaymentService(
      baseUrl: baseUrl,
      createQrPath: createQrPath,
      checkStatusPath: checkStatusPath,
      timeout: timeout,
    );
  }

  AbaPaymentService({
    this.baseUrl = 'http://localhost:8000',
    this.createQrPath = '/api/aba/create-qr',
    this.checkStatusPath = '/api/aba/check-status',
    this.timeout = const Duration(seconds: 12),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Cleanly resolves URL path against baseUrl
  Uri _buildUri(String path) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Request the backend to generate a dynamic ABA PayWay KHQR code.
  /// 
  /// Endpoint: `POST /api/aba/create-qr`
  /// 
  /// Payload:
  /// ```json
  /// {
  ///   "tran_id": "ORD-1727599000",
  ///   "amount": 12.50,
  ///   "currency": "USD"
  /// }
  /// ```
  Future<AbaQrResponse> createQr({
    required String tranId,
    required double amount,
    String currency = 'USD',
    Map<String, dynamic>? additionalPayload,
  }) async {
    assert(tranId.isNotEmpty, 'Transaction ID must not be empty');
    assert(amount > 0, 'Amount must be greater than zero');

    final uri = _buildUri(createQrPath);
    final body = <String, dynamic>{
      'tran_id': tranId,
      'amount': double.parse(amount.toStringAsFixed(2)),
      'currency': currency.toUpperCase(),
      ...?additionalPayload,
    };

    if (kDebugMode) {
      debugPrint('[AbaPaymentService] POST $uri -> ${jsonEncode(body)}');
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (kDebugMode) {
        debugPrint(
          '[AbaPaymentService] Response (${response.statusCode}): ${response.body}',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final result = AbaQrResponse.fromJson(data);

        // Ensure we preserve tranId if backend omitted it
        if (result.tranId.isEmpty) {
          return AbaQrResponse(
            status: result.status,
            message: result.message,
            tranId: tranId,
            qrString: result.qrString,
            qrImage: result.qrImage,
            amount: result.amount ?? amount,
            currency: result.currency,
            rawJson: result.rawJson,
          );
        }
        return result;
      } else {
        String errorMsg = 'Failed to generate QR (HTTP ${response.statusCode})';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map && errorJson.containsKey('message')) {
            errorMsg = errorJson['message'].toString();
          } else if (errorJson is Map && errorJson.containsKey('description')) {
            errorMsg = errorJson['description'].toString();
          }
        } catch (_) {}

        throw AbaPaymentException(
          message: errorMsg,
          statusCode: response.statusCode,
          tranId: tranId,
          details: response.body,
        );
      }
    } on SocketException catch (e) {
      throw AbaPaymentException(
        message: 'Network connection error. Check backend server URL.',
        tranId: tranId,
        details: e.toString(),
      );
    } on TimeoutException {
      throw AbaPaymentException(
        message: 'Request timed out while generating ABA KHQR code.',
        tranId: tranId,
      );
    } on FormatException catch (e) {
      throw AbaPaymentException(
        message: 'Invalid response format received from backend.',
        tranId: tranId,
        details: e.toString(),
      );
    } catch (e) {
      if (e is AbaPaymentException) rethrow;
      throw AbaPaymentException(
        message: 'Unexpected error: ${e.toString()}',
        tranId: tranId,
        details: e,
      );
    }
  }

  /// Check payment verification status with backend.
  /// 
  /// Endpoint: `POST /api/aba/check-status`
  /// 
  /// Payload:
  /// ```json
  /// {
  ///   "tran_id": "ORD-1727599000"
  /// }
  /// ```
  Future<AbaCheckStatusResponse> checkStatus({
    required String tranId,
  }) async {
    assert(tranId.isNotEmpty, 'Transaction ID must not be empty');

    final uri = _buildUri(checkStatusPath);
    final body = <String, dynamic>{
      'tran_id': tranId,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (kDebugMode) {
        debugPrint(
          '[AbaPaymentService.checkStatus] (${response.statusCode}): ${response.body}',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final result = AbaCheckStatusResponse.fromJson(data);

        if (result.tranId.isEmpty) {
          return AbaCheckStatusResponse(
            status: result.status,
            message: result.message,
            tranId: tranId,
            amount: result.amount,
            currency: result.currency,
            apv: result.apv,
            paymentDate: result.paymentDate,
            paymentType: result.paymentType,
            rawJson: result.rawJson,
          );
        }
        return result;
      } else {
        String errorMsg =
            'Failed to check transaction status (HTTP ${response.statusCode})';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map && errorJson.containsKey('message')) {
            errorMsg = errorJson['message'].toString();
          }
        } catch (_) {}

        throw AbaPaymentException(
          message: errorMsg,
          statusCode: response.statusCode,
          tranId: tranId,
          details: response.body,
        );
      }
    } on SocketException catch (e) {
      throw AbaPaymentException(
        message: 'Network connection lost during status check.',
        tranId: tranId,
        details: e.toString(),
      );
    } on TimeoutException {
      throw AbaPaymentException(
        message: 'Status check timed out.',
        tranId: tranId,
      );
    } on FormatException catch (e) {
      throw AbaPaymentException(
        message: 'Invalid status response format from backend.',
        tranId: tranId,
        details: e.toString(),
      );
    } catch (e) {
      if (e is AbaPaymentException) rethrow;
      throw AbaPaymentException(
        message: 'Status check error: ${e.toString()}',
        tranId: tranId,
        details: e,
      );
    }
  }

  /// Close the HTTP client when no longer needed
  void dispose() {
    _client.close();
  }
}
