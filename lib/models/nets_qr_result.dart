class NetsQrResult {
  final String txnRetrievalRef;
  final String txnId;
  final String qrCodeBase64;
  final double amountInDollars;
  final String responseCode;

  NetsQrResult({
    required this.txnRetrievalRef,
    required this.txnId,
    required this.qrCodeBase64,
    required this.amountInDollars,
    required this.responseCode,
  });

  factory NetsQrResult.fromJson(Map<String, dynamic> json) {
    final data = json['result']['data'] as Map<String, dynamic>;
    return NetsQrResult(
      txnRetrievalRef: data['txn_retrieval_ref'].toString(),
      txnId: data['txn_id'].toString(),
      qrCodeBase64: data['qr_code'].toString(),
      amountInDollars: (data['amt_in_dollars'] as num).toDouble(),
      responseCode: data['response_code']?.toString() ?? '',
    );
  }
}
