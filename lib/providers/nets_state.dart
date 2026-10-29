import 'dart:typed_data';

enum NetsStatus { idle, loading, awaitingScan, checking, success, fail, complete }

class NetsState {
  final Uint8List? qrCode;
  final NetsStatus status;
  final int timeLeft;
  final String? message;
  final String? txnRef;

  const NetsState({
    this.qrCode,
    this.status = NetsStatus.idle,
    this.timeLeft = 300,
    this.message,
    this.txnRef,
  });

  NetsState copyWith({
    Uint8List? qrCode,
    NetsStatus? status,
    int? timeLeft,
    String? message,
    String? txnRef,
  }) {
    return NetsState(
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      timeLeft: timeLeft ?? this.timeLeft,
      message: message ?? this.message,
      txnRef: txnRef ?? this.txnRef,
    );
  }
}