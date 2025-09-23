import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ApiKeyService {
  ApiKeyService._();

  static final ApiKeyService instance = ApiKeyService._();

  String? _cachedOpenAiKey;

  Future<String?> fetchOpenAiKey() async {
    if (_cachedOpenAiKey != null && _cachedOpenAiKey!.isNotEmpty) {
      return _cachedOpenAiKey;
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('getOpenAiApiKey', options: HttpsCallableOptions(timeout: const Duration(seconds: 5)));
      final HttpsCallableResult<dynamic> result = await callable.call();
      final dynamic data = result.data;

      final String? key = data is Map
          ? data['openaiKey'] as String? ?? data['OPENAI_API_KEY'] as String?
          : data as String?;

      if (key != null && key.trim().isNotEmpty) {
        _cachedOpenAiKey = key.trim();
        return _cachedOpenAiKey;
      }
    } catch (e, stack) {
      debugPrint('Failed to fetch OpenAI key from Firebase Functions: $e');
      debugPrint(stack.toString());
    }
    return null;
  }
}
