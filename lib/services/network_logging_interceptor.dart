import 'dart:io';
import 'package:http/http.dart' as http;
import 'debug_logging_service.dart';

/// Network logging interceptor that automatically logs all HTTP requests and responses
class NetworkLoggingInterceptor extends http.BaseClient {
  final http.Client _inner;
  final DebugLoggingService _logger = DebugLoggingService();

  NetworkLoggingInterceptor(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    
    // Log the request
    _logger.logNetworkRequest(
      request.method,
      request.url.toString(),
      headers: request.headers,
      body: request is http.Request ? request.body : null,
    );

    try {
      // Send the request
      final response = await _inner.send(request);
      stopwatch.stop();
      
      // Read the response body
      final responseBody = await response.stream.bytesToString();
      
      // Log the response
      _logger.logNetworkResponse(
        request.method,
        request.url.toString(),
        response.statusCode,
        response: responseBody,
        duration: stopwatch.elapsed,
      );
      
      // Return a new response with the body
      return http.StreamedResponse(
        Stream.value(responseBody.codeUnits),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      stopwatch.stop();
      _logger.error(
        'Network request failed: ${request.method} ${request.url}',
        tag: 'NETWORK',
        data: {
          'error': e.toString(),
          'duration_ms': stopwatch.elapsed.inMilliseconds,
        },
      );
      rethrow;
    }
  }
} 