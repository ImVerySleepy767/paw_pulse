import 'dart:convert';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  Future<double?> getMYRRate() async {
    final url = Uri.parse('https://open.er-api.com/v6/latest/SGD');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['rates']['MYR'] as num?)?.toDouble();
    }
    return null;
  }
}
