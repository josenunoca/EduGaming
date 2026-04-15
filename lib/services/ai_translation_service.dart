import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Translation service that batches all pending requests into a single API call.
class AiTranslationService {
  final String _apiKey;
  final Map<String, String> _cache = {};
  late final GenerativeModel _model;

  // Batch system: collect all translate() calls for 300ms then fire as one request
  final List<_PendingTranslation> _pending = [];
  Timer? _batchTimer;

  AiTranslationService(String apiKey) : _apiKey = apiKey {
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
    );
  }

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

    // Reset the debounce timer
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 300), _flushBatch);

    return completer.future;
  }

  Future<void> _flushBatch() async {
    if (_pending.isEmpty) return;

    final batch = List<_PendingTranslation>.from(_pending);
    _pending.clear();

    final toTranslate =
        batch.where((t) => !_cache.containsKey(t.cacheKey)).toList();

    for (final t in batch.where((t) => _cache.containsKey(t.cacheKey))) {
      t.completer.complete(_cache[t.cacheKey]);
    }

    if (toTranslate.isEmpty) return;
    final targetLanguage = toTranslate.first.targetLanguage;

    try {
      final numbered = toTranslate
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value.text}')
          .join('\n');

      final prompt = '''Translate the following texts to $targetLanguage.
Context: Educational platform (professional, academic tone).
Return ONLY a numbered list matching the input format. Do not add explanations.

$numbered''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text?.trim() ?? '';

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
          'Batch translated ${toTranslate.length} texts to $targetLanguage ✅');
    } catch (e) {
      debugPrint('Batch translation error: $e');
      for (final t in toTranslate) {
        if (!t.completer.isCompleted) t.completer.complete(t.text);
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
