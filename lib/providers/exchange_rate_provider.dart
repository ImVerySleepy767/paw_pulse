import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/services/exchange_rate_service.dart';

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) => ExchangeRateService());

final rateMYRProvider = FutureProvider<double?>((ref) {
  return ref.read(exchangeRateServiceProvider).getMYRRate();
});
