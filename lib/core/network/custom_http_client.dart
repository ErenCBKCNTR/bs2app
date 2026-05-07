import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:blind_social/core/utils/logger.dart';

class CustomHttpClient extends http.BaseClient {
  static final CustomHttpClient _instance = CustomHttpClient._internal();
  factory CustomHttpClient() => _instance;
  
  CustomHttpClient._internal();

  final http.Client _inner = http.Client();
  static int requestCount = 0;
  static int _activeRequests = 0;
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    _activeRequests++;
    
    // Ağ isteklerini biraz yavaşlatmak, DDOS / Router engellemelerini önlemek için.
    int delayMs = 150;
    if (_activeRequests > 3) {
       delayMs = 300 * _activeRequests;
    }
    await Future.delayed(Duration(milliseconds: delayMs));
    
    try {
      final response = await _inner.send(request);
      return response;
    } finally {
      _activeRequests--;
      if (requestCount % 50 == 0) {
        AppLogger.instance.warning('Ağ İstek Limit Uyarısı: Uygulama şu ana kadar $requestCount API isteği başlattı. Aşırı yoğunluk olabilir.');
      }
    }
  }
}
