import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _baseUrl = 'https://app-git-vercel-lisa-mollicas-projects-f40db721.vercel.app';

  static Future<String?> generateJsonScript({
    required String topic,
    required int length,
    required String style,
    List<String>? searchFacts,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/generate-script'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'length': length,
        'style': style,
        'searchFacts': searchFacts ?? [],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] as String?;
    } else {
      if (kDebugMode) {
        debugPrint('OpenAIService error: ${response.statusCode} - ${response.body}');
      }
      return null; // Fallback if needed
    }
  }
}
