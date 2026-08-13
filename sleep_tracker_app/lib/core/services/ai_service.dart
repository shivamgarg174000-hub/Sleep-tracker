import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import '../../models/chat_message.dart';

/// Direct-from-client Gemini API integration (per your choice — faster to
/// ship, the key ships inside the app bundle). Uses `gemini-2.5-flash`,
/// which sits on Google's genuinely free, no-card-required tier as of
/// 2026 (5-15 RPM / hundreds of requests per day depending on model).
///
/// Because the key is client-side, treat it as semi-public: set an HTTP
/// referrer / Android package restriction on the key in Google AI Studio
/// before shipping to real users, and expect to rotate it if abused.
class KittyAiException implements Exception {
  final String message;
  KittyAiException(this.message);
  @override
  String toString() => message;
}

class GeminiAiService {
  GeminiAiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            )),
        _logger = Logger();

  final Dio _dio;
  final Logger _logger;
  static const _model = 'gemini-2.5-flash';

  static const _kittySystemPrompt = '''
You are Kitty, an ultra-professional, highly trained sleep, health, and fitness
AI consultant embedded in the Kitty Sleep app. You have real-time access to the
user's onboarding profile and today's health metrics, provided as context below
on every turn. Use that data specifically in your answers instead of speaking
generically. Be warm but precise: give physiologically grounded, actionable
guidance. If the user's question needs a doctor (symptoms of illness, injury,
medication interactions), say so plainly and recommend professional care rather
than diagnosing.
''';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Sends the full conversation plus fresh user/health context and returns
  /// Kitty's reply. Throws [KittyAiException] with a user-safe message on
  /// any failure — never returns fabricated text on error.
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String userContext,
  }) async {
    if (!isConfigured) {
      throw KittyAiException(
        'Kitty AI isn\'t configured yet — add GEMINI_API_KEY to your .env file.',
      );
    }

    final contents = [
      ...history.map((m) => {
            'role': m.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          }),
    ];

    try {
      final response = await _dio.post(
        '/models/$_model:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'system_instruction': {
            'parts': [
              {'text': '$_kittySystemPrompt\n\n$userContext'}
            ],
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 800,
          },
        },
      );

      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw KittyAiException('Kitty didn\'t return a response. Please try again.');
      }

      final parts = candidates.first['content']?['parts'] as List?;
      final text = parts?.map((p) => p['text'] as String? ?? '').join('\n').trim();

      if (text == null || text.isEmpty) {
        throw KittyAiException('Kitty didn\'t return a response. Please try again.');
      }
      return text;
    } on DioException catch (e) {
      _logger.e('Gemini API call failed', error: e);
      if (e.response?.statusCode == 429) {
        throw KittyAiException(
          'Kitty is getting a lot of requests right now (free-tier rate limit). Try again in a minute.',
        );
      }
      if (e.response?.statusCode == 400) {
        throw KittyAiException('That request couldn\'t be processed. Try rephrasing.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw KittyAiException('Kitty is taking too long to respond. Check your connection.');
      }
      throw KittyAiException('Kitty is temporarily unavailable. Please try again.');
    }
  }
}
