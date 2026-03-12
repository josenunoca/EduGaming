import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DIdVideoService {
  // D-ID API key in the format provided by D-ID dashboard
  // D-ID documentation: send as "Basic <KEY>" without additional base64 encoding
  static const String _apiKey =
      'am9zZW51bm9jYUBnbWFpbC5jb20:HlLx1Hi0-_0NHNwNBUDA4';
  static const String _baseUrl = 'https://api.d-id.com';

  // Per D-ID docs: Authorization: Basic <base64(API_USER:API_PASSWORD)>
  // We must base64 encode the key.
  Map<String, String> get _headers {
    final bytes = utf8.encode(_apiKey);
    final base64Key = base64.encode(bytes);
    return {
      'Authorization': 'Basic $base64Key',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Fetches real presenter data from D-ID API.
  Future<List<Map<String, dynamic>>> fetchPresenters() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/presenters?limit=20'),
        headers: _headers,
      );
      debugPrint('D-ID Presenters status: ${response.statusCode}');
      debugPrint(
          'D-ID Presenters body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // D-ID may return a plain array OR { "presenters": [...] }
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map) {
          final list =
              decoded['presenters'] ?? decoded['list'] ?? decoded['data'] ?? [];
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      debugPrint('D-ID fetchPresenters error: $e');
    }
    return [];
  }

  /// Creates a single talking-head video clip for one speaker segment.
  Future<String?> _createTalk({
    required String sourceUrl,
    required String text,
    required String voiceId,
  }) async {
    final body = jsonEncode({
      'source_url': sourceUrl,
      'script': {
        'type': 'text',
        'input': text,
        'provider': {
          'type': 'microsoft',
          'voice_id': voiceId,
        },
      },
      'config': {
        'fluent': true,
        'pad_audio': 0.5,
      },
    });

    final response = await http.post(
      Uri.parse('$_baseUrl/talks'),
      headers: _headers,
      body: body,
    );

    debugPrint('D-ID Create Talk: ${response.statusCode} ${response.body}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id'] as String?;
    } else {
      final error = jsonDecode(response.body);
      final msg = error['description'] ?? error['message'] ?? response.body;
      if (msg.toString().toLowerCase().contains('credit')) {
        throw Exception('D-ID: Créditos insuficientes. Verifica a tua conta.');
      }
      throw Exception('D-ID Error ${response.statusCode}: $msg');
    }
  }

  /// Polls a talk until done. Returns the video URL.
  Future<String?> _pollTalkUntilDone(String talkId,
      {int maxAttempts = 30}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));

      final response = await http.get(
        Uri.parse('$_baseUrl/talks/$talkId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        debugPrint('D-ID poll $talkId: $status (${i + 1}/$maxAttempts)');

        if (status == 'done') {
          final resultUrl = data['result_url'] as String?;
          if (resultUrl == null || resultUrl.isEmpty) {
            throw Exception('D-ID: Clip pronto mas sem URL de resultado.');
          }
          return resultUrl;
        }
        if (status == 'error' || status == 'rejected') {
          final error = data['error'];
          throw Exception('D-ID erro ($status): $error');
        }
      } else {
        debugPrint('D-ID poll error: ${response.statusCode} ${response.body}');
      }
    }
    throw Exception('D-ID video timed out (150s).');
  }

  /// Downloads video bytes from a URL.
  Future<Uint8List> _downloadVideo(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Falha ao descarregar o vídeo.');
  }

  /// Main entry: generates an interview-style video from a podcast-format script.
  /// The script should have lines like:
  ///   JOANA: texto...
  ///   PROFESSOR: texto...
  Future<Uint8List?> generateInterviewVideo(
    String script, {
    void Function(String status)? onStatusUpdate,
  }) async {
    // Step 1: Use reliable, publicly accessible portrait photos
    // D-ID accepts any clear frontal face photo from a public HTTPS URL
    // Using Pexels high-quality professional portraits
    // Using professional frontal portraits from Unsplash
    // Use direct high-quality portrait links that end in .jpg to avoid 400 validation errors
    const femaleUrl =
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600&h=600';
    const maleUrl =
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=600&h=600';
    debugPrint('D-ID: Source URLs set. female=$femaleUrl, male=$maleUrl');

    // Step 2: Parse dialogue lines
    final lines = script.split('\n');
    final List<Map<String, dynamic>> segments = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('JOANA:')) {
        final text = trimmed.substring(6).trim();
        if (text.isNotEmpty) {
          segments.add({
            'text': text,
            'sourceUrl': femaleUrl,
            'voiceId': 'pt-PT-RaquelNeural',
            'speaker': 'JOANA',
          });
        }
      } else if (trimmed.startsWith('PROFESSOR:')) {
        final text = trimmed.substring(10).trim();
        if (text.isNotEmpty) {
          segments.add({
            'text': text,
            'sourceUrl': maleUrl,
            'voiceId': 'pt-PT-DuarteNeural',
            'speaker': 'PROFESSOR',
          });
        }
      }
    }

    if (segments.isEmpty) {
      throw Exception('Guião vazio ou em formato inválido.');
    }

    // Limit to first 6 segments to preserve D-ID credits
    final limited = segments.take(6).toList();

    onStatusUpdate?.call('A criar ${limited.length} clips de vídeo...');

    // Step 3: Create all D-ID talk jobs
    final List<String> talkIds = [];
    for (int i = 0; i < limited.length; i++) {
      final seg = limited[i];
      onStatusUpdate?.call(
          'A criar fala ${i + 1}/${limited.length} (${seg['speaker']})...');
      try {
        final id = await _createTalk(
          sourceUrl: seg['sourceUrl'] as String,
          text: seg['text'] as String,
          voiceId: seg['voiceId'] as String,
        );
        if (id != null) talkIds.add(id);
      } catch (e) {
        debugPrint('D-ID segment $i creation failed: $e');
        // Surface first error to user if none succeed
        if (i == 0 && talkIds.isEmpty) rethrow;
      }
    }

    if (talkIds.isEmpty) {
      throw Exception(
          'Nenhum clip criado. Verifica os créditos da D-ID e a chave API.');
    }

    // Step 4: Poll and download
    onStatusUpdate?.call('A processar vídeos (pode demorar 1-3 min)...');
    final List<Uint8List> videoParts = [];

    final List<String> errors = [];
    for (int i = 0; i < talkIds.length; i++) {
      onStatusUpdate?.call('A aguardar clip ${i + 1}/${talkIds.length}...');
      try {
        final videoUrl = await _pollTalkUntilDone(talkIds[i]);
        if (videoUrl != null) {
          final bytes = await _downloadVideo(videoUrl);
          if (bytes.isNotEmpty) {
            videoParts.add(bytes);
            debugPrint(
                'D-ID: Clip ${i + 1} downloaded (${(bytes.length / 1024).toStringAsFixed(0)} KB)');
          }
        }
      } catch (e) {
        debugPrint('D-ID poll/download $i error: $e');
        errors.add('Clip ${i + 1}: $e');
      }
    }

    if (videoParts.isEmpty) {
      final errorMsg = errors.isNotEmpty ? errors.join('\n') : 'Sem detalhes.';
      throw Exception(
          'Nenhum vídeo foi gerado com sucesso.\nErros:\n$errorMsg');
    }

    onStatusUpdate?.call('Vídeo pronto! A descarregar...');
    // Return first (or only) clip
    return videoParts.first;
  }
}
