import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateNotifierProvider lives here in Riverpod 3.x
import 'package:uuid/uuid.dart';
import 'package:pawpulse/services/nets_service.dart';
import 'package:pawpulse/providers/nets_state.dart';

final netsServiceProvider = Provider<NetsService>((Ref ref) => NetsService());

final netsProvider = StateNotifierProvider<NetsNotifier, NetsState>((Ref ref) {
  return NetsNotifier(ref.read(netsServiceProvider));
});

class NetsNotifier extends StateNotifier<NetsState> {
  final NetsService _service;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _webhookSub;

  NetsNotifier(this._service) : super(const NetsState());

 String _generateTxnId() => 'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b';

  /// Calls requestQR(), decodes and stores the QR + txnRef in state,
  /// then starts the countdown timer and webhook listener.
  Future<void> generateQR({double amount = 2.0}) async {
    state = state.copyWith(status: NetsStatus.loading, message: null);
    try {
      final result = await _service.requestQR(
        txnId: _generateTxnId(),
        amountInDollars: amount,
      );
      state = state.copyWith(
        qrCode: base64Decode(result.qrCodeBase64),
        txnRef: result.txnRetrievalRef,
        status: NetsStatus.awaitingScan,
        timeLeft: 300,
      );
      startTimer(result.txnRetrievalRef);
      startWebhookListener(result.txnRetrievalRef);
    } catch (e) {
      state = state.copyWith(status: NetsStatus.fail, message: e.toString());
    }
  }

  /// Runs a 1-second countdown, calls checkPayment() when time ends.
  void startTimer(String txnRef) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeLeft <= 0) {
        timer.cancel();
        checkPayment(txnRef);
      } else {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      }
    });
  }

  /// Listens to the SSE stream and updates state.message on events
  /// such as "QR code scanned". Triggers checkPayment on a success signal.
  void startWebhookListener(String txnRef) {
    _webhookSub?.cancel();
    _webhookSub = _service.webhookStream(txnRef).listen(
      (event) {
        final code = event['response_code']?.toString();
        state = state.copyWith(message: event['message']?.toString());
        if (code == '00') {
          checkPayment(txnRef);
        }
      },
      onError: (_) {
        // SSE dropped silently — the timer-triggered checkPayment()
        // fallback below still catches the final status.
      },
    );
  }

  /// Calls the QueryAPI to check payment status, reads response_code
  /// and message, and updates state to success or fail accordingly.
  Future<void> checkPayment(String txnRef) async {
    state = state.copyWith(status: NetsStatus.checking);
    try {
      final data = await _service.queryStatus(txnRef);
      final code = data['response_code']?.toString();
      if (code == '00') {
        state = state.copyWith(status: NetsStatus.success, message: 'Payment successful');
        _timer?.cancel();
        _webhookSub?.cancel();
        // Show success UI for 10s, then mark complete and clean up.
        await Future.delayed(const Duration(seconds: 10));
        state = state.copyWith(status: NetsStatus.complete);
      } else {
        state = state.copyWith(status: NetsStatus.fail, message: 'Payment failed (code: ${code ?? 'unknown'})');
      }
    } catch (e) {
      state = state.copyWith(status: NetsStatus.fail, message: 'Could not verify payment: $e');
    }
  }

  /// Cancels the active timer and webhook subscription to prevent
  /// memory leaks — call this on navigation away / after registration.
  void cleanup() {
    _timer?.cancel();
    _webhookSub?.cancel();
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}