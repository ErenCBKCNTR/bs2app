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
  
  // Detaylı endpoint analiz logu
  static final Map<String, int> _endpointRequestCounts = {};
  
  // Performans takibi
  static final Map<String, List<int>> _endpointLatencies = {};
  static int slowRequestCount = 0;
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    _activeRequests++;
    
    // Endpoint analizi
    String path = request.url.path;
    _endpointRequestCounts[path] = (_endpointRequestCounts[path] ?? 0) + 1;
    
    final stopwatch = Stopwatch()..start();
    
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
      stopwatch.stop();
      _activeRequests--;
      
      final latency = stopwatch.elapsedMilliseconds;
      _endpointLatencies.putIfAbsent(path, () => []).add(latency);
      
      if (latency > 1500) {
        slowRequestCount++;
        AppLogger.instance.warning(
          'Yavaş İstek Uyarısı (Performans)',
          details: '$path endpointine yapılan istek $latency ms sürdü. Bu gecikme uygulamanızı yavaşlatabilir.'
        );
      }

      if (requestCount % 50 == 0) {
        String details = "Dağılım:\n";
        _endpointRequestCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..forEach((entry) {
            final latencies = _endpointLatencies[entry.key] ?? [];
            final avgLatency = latencies.isNotEmpty 
                ? (latencies.reduce((a, b) => a + b) / latencies.length).round() 
                : 0;
            details += "${entry.value} istek (Ort.$avgLatency ms): ${entry.key}\n";
          });
          
        AppLogger.instance.warning(
           'Ağ İstek Limit Uyarısı: Uygulama şu ana kadar $requestCount API isteği başlattı.',
           details: details
        );
      }
    }
  }
}
