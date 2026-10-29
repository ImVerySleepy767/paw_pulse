import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pawpulse/config/nets_config.example.dart';
import 'package:pawpulse/models/nets_qr_result.dart';

class NetsService {
  /// RequestAPI — generates the dynamic NETS QR and a transaction
  /// reference used to track it.
  Future<NetsQrResult> requestQR({
    required String txnId,
    required double amountInDollars,
  }) async {
    final url = Uri.parse('${NetsConfig.baseUrl}/api/v1/common/payments/nets-qr/request');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': NetsConfig.apiKey.trim(),
        'project-id': NetsConfig.projectId.trim(),
        // Matching Postman's auto-generated headers, since the server
        // may key off client-identification headers we hadn't set before.
        'User-Agent': 'PostmanRuntime/7.53.0',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
      },
      body: jsonEncode({
        'txn_id': txnId,
        // Match Postman exactly: send a whole number as an int (e.g. 3),
        // not a float (3.0), since some backends validate strictly.
        'amt_in_dollars': amountInDollars % 1 == 0 ? amountInDollars.toInt() : amountInDollars,
        'notify_mobile': 0,
      }),
    ).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw Exception('NETS sandbox did not respond within 45 seconds — their server may be under heavy load, try again shortly.'),
    );

    if (response.statusCode != 200) {
      throw Exception('NETS RequestAPI failed (${response.statusCode}): ${response.body}');
    }

    return NetsQrResult.fromJson(jsonDecode(response.body));
  }

  /// S2SWebhookAPI — real-time payment status via Server-Sent Events.
  /// Emits a decoded JSON map for every `data: {...}` line received,
  /// e.g. {"message": "QR code scanned", "response_code": "00"}.
  Stream<Map<String, dynamic>> webhookStream(String txnRetrievalRef) async* {
    final url = Uri.parse(
      '${NetsConfig.baseUrl}/api/v1/common/payments/nets/webhook?txn_retrieval_ref=$txnRetrievalRef',
    );
    final request = http.Request('GET', url);
    request.headers.addAll({
      'Accept': 'text/event-stream',
      'api-key': NetsConfig.apiKey.trim(),
      'project-id': NetsConfig.projectId.trim(),
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      final lines = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in lines) {
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          try {
            yield jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {
            // Ignore malformed/keep-alive lines that aren't valid JSON.
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// QueryAPI — fallback poll used when the SSE stream times out
  /// (matches the taught "Query API Fallback after 5 mins" pattern).
  Future<Map<String, dynamic>> queryStatus(String txnRetrievalRef) async {
    final url = Uri.parse('${NetsConfig.baseUrl}/api/v1/common/payments/nets-qr/query');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': NetsConfig.apiKey.trim(),
        'project-id': NetsConfig.projectId.trim(),
      },
      body: jsonEncode({
        'txn_retrieval_ref': txnRetrievalRef,
        'frontend_timeout_status': 1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('NETS QueryAPI failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body);
    return json['result']['data'] as Map<String, dynamic>;
  }
}