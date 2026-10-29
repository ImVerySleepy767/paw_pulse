import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/providers/nets_provider.dart';
import 'package:pawpulse/providers/nets_state.dart';
import 'package:pawpulse/providers/exchange_rate_provider.dart';

/// NETS QR Payment screen, backed by the OPENAPIPASS sandbox API and
/// driven by netsProvider (Riverpod StateNotifier — see nets_provider.dart).
///
///  - RequestAPI generates a genuine dynamic QR (scannable by the real
///    TWallet simulator app, configured to Environment: UAT, Source of
///    Fund: DBS).
///  - S2SWebhookAPI (SSE) listens for real-time payment status.
///  - QueryAPI is used as a fallback poll if the SSE stream disconnects
///    or times out, matching the taught 5-minute fallback pattern.
///  - On confirmed payment (status == success), a real transaction
///    record is written to Firestore.
class NetsPaymentScreen extends ConsumerStatefulWidget {
  static const String routeName = '/nets-payment';
  final String trainerId;
  final String packageTitle;
  final double amount;

  const NetsPaymentScreen({
    super.key,
    required this.trainerId,
    required this.packageTitle,
    required this.amount,
  });

  @override
  ConsumerState<NetsPaymentScreen> createState() => _NetsPaymentScreenState();
}

class _NetsPaymentScreenState extends ConsumerState<NetsPaymentScreen> {
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    // Matches the mini-project's addPostFrameCallback pattern: kick off
    // generateQR() once the widget has finished its first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(netsProvider.notifier).generateQR(amount: widget.amount);
    });
  }

  @override
  void dispose() {
    ref.read(netsProvider.notifier).cleanup();
    super.dispose();
  }

  String _formattedTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _recordPaymentIfNeeded(String? txnRef) async {
    if (_recorded || txnRef == null) return;
    _recorded = true;
    try {
      await ref.read(firebaseServiceProvider).recordTransaction(
            transactionId: txnRef,
            trainerId: widget.trainerId,
            amount: widget.amount,
          );
    } catch (_) {
      // Payment already confirmed by NETS; a Firestore write failure
      // here shouldn't block the success UI the user already earned.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(netsProvider);

    // Fire the Firestore write exactly once, the first time we see success.
    if (state.status == NetsStatus.success) {
      _recordPaymentIfNeeded(state.txnRef);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('NETS QR Payment')),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(NetsState state) {
    switch (state.status) {
      case NetsStatus.idle:
      case NetsStatus.loading:
        return const Padding(
          key: ValueKey('loading'),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Requesting NETS QR...'),
            ],
          ),
        );

      case NetsStatus.fail:
        return Padding(
          key: const ValueKey('error'),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 12),
              Text(state.message ?? 'Something went wrong.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.read(netsProvider.notifier).generateQR(amount: widget.amount),
                child: const Text('Request New QR'),
              ),
            ],
          ),
        );

      case NetsStatus.success:
      case NetsStatus.complete:
        return _buildSuccessView();

      case NetsStatus.checking:
      case NetsStatus.awaitingScan:
        return _buildQrView(state);
    }
  }

  Widget _buildQrView(NetsState state) {
    return Padding(
      key: const ValueKey('qr'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.packageTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('SGD ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Consumer(
            builder: (context, ref, _) {
              final rateAsync = ref.watch(rateMYRProvider);
              return rateAsync.when(
                data: (rate) => rate == null
                    ? const SizedBox.shrink()
                    : Text(
                        '≈ MYR ${(widget.amount * rate).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                loading: () => const SizedBox(
                  height: 14,
                  child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))),
                ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: 24),
          if (state.qrCode != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: Image.memory(state.qrCode!, width: 220, height: 220),
            ),
          const SizedBox(height: 16),
          if (state.txnRef != null)
            Text('Ref: ${state.txnRef}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          if (state.message != null) ...[
            const SizedBox(height: 4),
            Text(state.message!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text('Expires in ${_formattedTime(state.timeLeft)}', style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan with the TWallet simulator app\n(Environment: UAT · Source of Fund: DBS)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (state.status == NetsStatus.checking)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(),
            ),
          OutlinedButton.icon(
            onPressed: state.status == NetsStatus.checking || state.txnRef == null
                ? null
                : () => ref.read(netsProvider.notifier).checkPayment(state.txnRef!),
            icon: const Icon(Icons.refresh),
            label: const Text('Check Payment Status Now'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 100),
        ),
        const SizedBox(height: 16),
        const Text('Payment Confirmed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Trainer slot reserved · SGD ${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ],
    );
  }
}