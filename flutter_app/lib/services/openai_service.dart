import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:vioo_app/services/remote/proxy_config.dart';

class OpenAIService {
  static const String _endpoint = ProxyConfig.scriptProxyEndpoint;

  static Future<String?> generateJsonScript({
    required String topic,
    required int length,
    required String style,
    String? cta,
    List<String>? searchFacts,
  }) async {
    if (_endpoint.isEmpty) {
      if (kDebugMode) {
        debugPrint('SCRIPT_PROXY_ENDPOINT not provided; skipping hosted generation.');
      }
      return null;
    }

    final Uri endpoint = Uri.parse(_endpoint);
    final Map<String, dynamic> payload = <String, dynamic>{
      'topic': topic,
      'length': length,
      'style': style,
      'searchFacts': searchFacts ?? <String>[],
    };
    if (cta != null && cta.trim().isNotEmpty) {
      payload['cta'] = cta.trim();
    }

    final RetryOptions retryOptions = RetryOptions(
      maxAttempts: 3,
      delayFactor: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 2),
    );

    try {
      final http.Response response = await retryOptions.retry(
        () => http
            .post(
              endpoint,
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15)),
        retryIf: (Exception _) => true,
        onRetry: (Exception e) {
          if (kDebugMode) {
            debugPrint('Retrying script proxy request after failure: $e');
          }
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final dynamic script = data['text'] ?? data['script'];
          if (script is String && script.trim().isNotEmpty) {
            return script.trim();
          }
        } else if (data is String && data.trim().isNotEmpty) {
          return data.trim();
        }
      } else if (kDebugMode) {
        debugPrint('OpenAIService error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OpenAIService request failed: $e');
      }
    }

    return null; // Fallback if needed
  }
}