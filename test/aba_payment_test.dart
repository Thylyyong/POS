import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_flutter/models/models.dart';
import 'package:pos_flutter/services/services.dart';

void main() {
  group('AbaQrResponse & AbaCheckStatusResponse Models', () {
    test('AbaQrResponse.fromJson parses valid payload', () {
      final json = {
        'status': 0,
        'message': 'Success',
        'tran_id': 'TXN_TEST_1001',
        'qr_string': '00020101021230490016A000000727012345...',
        'amount': 15.50,
        'currency': 'USD',
      };

      final response = AbaQrResponse.fromJson(json);

      expect(response.isSuccess, isTrue);
      expect(response.tranId, equals('TXN_TEST_1001'));
      expect(response.amount, equals(15.50));
      expect(response.currency, equals('USD'));
      expect(response.qrString, startsWith('00020101021230490016'));
    });

    test('AbaCheckStatusResponse.fromJson correctly identifies approval code 0', () {
      final jsonApproved = {
        'status': '0',
        'message': 'Approved',
        'tran_id': 'TXN_TEST_1001',
        'apv': '998877',
      };

      final response = AbaCheckStatusResponse.fromJson(jsonApproved);

      expect(response.isSuccess, isTrue);
      expect(response.isPending, isFalse);
      expect(response.isFailed, isFalse);
      expect(response.apv, equals('998877'));
    });

    test('AbaCheckStatusResponse.fromJson correctly identifies pending status', () {
      final jsonPending = {
        'status': '1',
        'message': 'Pending customer scan',
        'tran_id': 'TXN_TEST_1001',
      };

      final response = AbaCheckStatusResponse.fromJson(jsonPending);

      expect(response.isSuccess, isFalse);
      expect(response.isPending, isTrue);
      expect(response.isFailed, isFalse);
    });
  });

  group('AbaPaymentService', () {
    test('createQr issues POST and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/aba/create-qr'));
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body);
        expect(body['tran_id'], equals('TXN_123'));
        expect(body['amount'], equals(25.0));

        return http.Response(
          jsonEncode({
            'status': 0,
            'message': 'QR Generated',
            'tran_id': 'TXN_123',
            'qr_string': '000201010212...SAMPLE_QR',
            'amount': 25.0,
            'currency': 'USD',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AbaPaymentService(
        baseUrl: 'http://testserver.local',
        client: mockClient,
      );

      final qrResponse = await service.createQr(
        tranId: 'TXN_123',
        amount: 25.0,
      );

      expect(qrResponse.isSuccess, isTrue);
      expect(qrResponse.tranId, equals('TXN_123'));
      expect(qrResponse.qrString, contains('SAMPLE_QR'));
    });

    test('checkStatus returns success when backend returns status 0', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/aba/check-status'));
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body);
        expect(body['tran_id'], equals('TXN_123'));

        return http.Response(
          jsonEncode({
            'status': '0',
            'message': 'Payment approved',
            'tran_id': 'TXN_123',
            'apv': '123456',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AbaPaymentService(
        baseUrl: 'http://testserver.local',
        client: mockClient,
      );

      final statusResponse = await service.checkStatus(tranId: 'TXN_123');

      expect(statusResponse.isSuccess, isTrue);
      expect(statusResponse.status, equals('0'));
      expect(statusResponse.apv, equals('123456'));
    });
  });
}
