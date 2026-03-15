import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Translation service that batches all pending requests into a single API call.
/// This avoids hitting rate limits by replacing N individual calls with 1 batch call.
class AiTranslationService {
  final String _apiKey;
  final Map<String, String> _cache = {};

  // Batch system: collect all translate() calls for 300ms then fire as one request
  final List<_PendingTranslation> _pending = [];
  Timer? _batchTimer;

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  AiTranslationService(String apiKey) : _apiKey = apiKey;

  Future<String> translate(String text, String targetLanguage,
      {String? context}) async {
    if (targetLanguage == 'pt' || text.isEmpty) return text;

    final cacheKey = '${targetLanguage}_$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final completer = Completer<String>();
    _pending.add(_PendingTranslation(
      text: text,
      targetLanguage: targetLanguage,
      cacheKey: cacheKey,
      completer: completer,
    ));

    // Reset the debounce timer — wait 300ms after the last call before firing
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 300), _flushBatch);

    return completer.future;
  }

  Future<void> _flushBatch() async {
    if (_pending.isEmpty) return;

    // Take all pending translations and clear the list
    final batch = List<_PendingTranslation>.from(_pending);
    _pending.clear();

    // Filter out already-cached ones
    final toTranslate =
        batch.where((t) => !_cache.containsKey(t.cacheKey)).toList();

    // Complete cached ones immediately
    for (final t in batch.where((t) => _cache.containsKey(t.cacheKey))) {
      t.completer.complete(_cache[t.cacheKey]);
    }

    if (toTranslate.isEmpty) return;

    final targetLanguage = toTranslate.first.targetLanguage;

    try {
      // Build a numbered list of all texts to translate in one prompt
      final numbered = toTranslate
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value.text}')
          .join('\n');

      final prompt = '''Translate the following texts to $targetLanguage.
Context: Educational platform (professional, academic tone).
Return ONLY a numbered list matching the input format. Do not add explanations.

$numbered''';

      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates']?[0]?['content']?['parts']?[0]
                    ?['text']
                ?.toString()
                .trim() ??
            '';

        // Parse the numbered response: "1. translation\n2. translation\n..."
        final lines = responseText.split('\n');
        final translationMap = <int, String>{};

        for (final line in lines) {
          final match = RegExp(r'^(\d+)\.\s*(.+)$').firstMatch(line.trim());
          if (match != null) {
            final index = int.tryParse(match.group(1)!);
            final translation = match.group(2)!.trim();
            if (index != null) translationMap[index] = translation;
          }
        }

        // Complete all pending futures with their translations
        for (int i = 0; i < toTranslate.length; i++) {
          final translation = translationMap[i + 1];
          final original = toTranslate[i].text;
          final result = (translation != null &&
                  translation.isNotEmpty &&
                  translation != original)
              ? translation
              : original;

          _cache[toTranslate[i].cacheKey] = result;
          toTranslate[i].completer.complete(result);
        }

        debugPrint(
            'Batch translated ${toTranslate.length} texts to $targetLanguage in 1 API call ✅');
      } else if (response.statusCode == 429) {
        debugPrint('Translation rate limited [429] — returning originals');
        for (final t in toTranslate) {
          t.completer.complete(t.text);
        }
      } else {
        debugPrint(
            'Translation HTTP Error [${response.statusCode}]: ${response.body}');
        for (final t in toTranslate) {
          t.completer.complete(t.text);
        }
      }
    } catch (e) {
      debugPrint('Batch translation error: $e');
      for (final t in toTranslate) {
        if (!t.completer.isCompleted) {
          t.completer.complete(t.text);
        }
      }
    }
  }
}

class _PendingTranslation {
  final String text;
  final String targetLanguage;
  final String cacheKey;
  final Completer<String> completer;

  _PendingTranslation({
    required this.text,
    required this.targetLanguage,
    required this.cacheKey,
    required this.completer,
  });
}
