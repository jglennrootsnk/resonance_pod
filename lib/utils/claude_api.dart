import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ClaudeApi {
  static String? _apiKey;

  static Future<void> initialize() async {
    await dotenv.load();
    _apiKey = dotenv.env['CLAUDE_API_KEY'];
  }

  static Future<String?> generateSummary(String prompt) async {
    if (_apiKey == null) {
      try {
        await initialize();
      } catch (e) {
        if (kDebugMode) {
          print('Error initializing Claude API: $e');
        }
        return 'Unable to access AI summary service.';
      }
    }

    if (_apiKey == null) {
      return 'API key not configured.';
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-7-sonnet-20250219',
          'max_tokens': 500,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'system':
              'You are an avid podcast listener that wants to catalog your favorite podcasts for searchabilty. Focus on the main themes and topics discussed. Pay special attention to mentioned books, authors, and guests.',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        if (kDebugMode) {
          print(
            'Error from Claude API: ${response.statusCode} - ${response.body}',
          );
        }
        return 'Error generating summary. Try again later.';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception calling Claude API: $e');
      }
      return 'Failed to connect to summary service.';
    }
  }
}
