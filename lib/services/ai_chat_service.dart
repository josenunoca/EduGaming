import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/subject_model.dart';
import '../models/institution_model.dart';
import '../models/activity_model.dart';

class AiChatService {
  final String _apiKey;
  late GenerativeModel _model;
  ChatSession? _chat;
  String _systemPrompt = '';

  static const _systemInstruction =
      'Você é um professor e pesquisador de vanguarda, um especialista altamente qualificado na área científica dos documentos fornecidos. '
      'Seu objetivo é travar um diálogo profissional, profundo e pedagógico com o usuário (que pode ser um aluno ou outro professor). '
      'Você deve basear suas respostas INTEGRALMENTE nos documentos fornecidos como contexto. '
      'Se o usuário perguntar algo fora do escopo dos documentos, explique educadamente que sua especialidade nestas sessões se limita ao conteúdo selecionado. '
      'Mantenha um tom encorajador, acadêmico e visionário. Responda no idioma em que for questionado.';

  AiChatService(String apiKey) : _apiKey = apiKey {
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
      systemInstruction: Content.system(_systemInstruction),
    );
  }

  Future<void> initializeSession(List<SubjectContent> contents) async {
    // Build context from content URLs
    final contentSummaries = contents
        .where((c) => c.url.isNotEmpty)
        .map((c) => '- ${c.name} (${c.type}): ${c.url}')
        .join('\n');

    _systemPrompt =
        '$_systemInstruction\n\nDocumentos de referência disponíveis:\n$contentSummaries';

    // Initialize new model with updated system instruction
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
      systemInstruction: Content.system(_systemPrompt),
    );

    // Start fresh chat session
    _chat = _model.startChat();
  }

  Stream<String> sendMessage(String message) async* {
    _chat ??= _model.startChat();

    try {
      final response = _chat!.sendMessageStream(Content.text(message));

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      yield 'Erro na comunicação com a IA. Por favor, tente novamente. Detalhes: $e';
    }
  }

  Future<String?> generateImage(String prompt) async {
    const modelId = 'imagen-4.0-fast-generate-001';
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$modelId:predict';
    final fullPrompt =
        'Educational illustration: $prompt. Style: Professional, clean, and clear.';

    try {
      final response = await http.post(
        Uri.parse('$endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'instances': [
            {'prompt': fullPrompt}
          ],
          'parameters': {
            'sampleCount': 1,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictions = data['predictions'];
        if (predictions != null && predictions.isNotEmpty) {
          final base64Image = predictions[0]?['bytesBase64Encoded'];
          if (base64Image != null) return base64Image;
        }
        debugPrint(
            'Image Gen: Success response but no image data found. Body: ${response.body}');
        return null;
      } else {
        if (response.statusCode == 404) {
          throw Exception(
              'Erro ao gerar imagem: 404 (Modelo não encontrado ou acesso restringido à região/allowlist)');
        }
        throw Exception('Erro ao gerar imagem: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Image Gen Exception: $e');
      rethrow;
    }
  }

  Future<String> generatePodcastScript() async {
    if (_chat == null) return '';

    const prompt =
        'Com base em TODA a conversa acima, cria um roteiro de podcast completo e profissional em português europeu. '
        'O podcast tem dois apresentadores: "JOANA" (entrevistadora dinâmica) e "PROFESSOR" (especialista apaixonado). '
        'O roteiro deve cobrir TODOS os temas importantes discutidos na conversa, de forma natural, fluida e educativa. '
        'Deve ser um podcast LONGO (pelo menos 15 a 20 trocas de falas). '
        'Usa APENAS e OBRIGATORIAMENTE este formato para cada fala, uma por linha:\n'
        'JOANA: [texto da fala]\n'
        'PROFESSOR: [texto da fala]\n\n'
        'PROIBIDO: Não uses parênteses, não descrevas sons, não uses asteriscos, não dês nomes diferentes aos personagens. '
        'NÃO incluas marcações de música ou efeitos sonoros como "(Música...)" ou "[Risos]". '
        'Começa com uma introdução cativante da JOANA e termina com uma conclusão inspiradora do PROFESSOR.\n'
        'IMPORTANTE: Retorna APENAS as falas, sem títulos, sem explicações, sem blocos de código.';

    try {
      final response = await _chat!.sendMessage(Content.text(prompt));
      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('Podcast Script Exception: $e');
    }
    return '';
  }

  /// Synthesizes a multi-voice podcast by making separate TTS API calls
  /// for each speaker line and concatenating the raw MP3 bytes.
  /// This is required because the Google TTS v1 API does not support the
  /// SSML <voice> tag for voice switching.
  Future<Uint8List?> synthesizePodcastAudio(String script) async {
    const ttsEndpoint =
        'https://texttospeech.googleapis.com/v1/text:synthesize';

    // Voices: Wavenet-A (female) for JOANA, Wavenet-B (male) for PROFESSOR
    const voiceJoana = {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-A'};
    const voiceProfessor = {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-B'};

    // Parse lines of the form "JOANA: ..." or "PROFESSOR: ..."
    final lines = script.split('\n');
    final List<Map<String, dynamic>> segments = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final upperLine = trimmed.toUpperCase();

      if (upperLine.startsWith('JOANA:') || upperLine.contains('JOANA :')) {
        final text = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        if (text.isNotEmpty) segments.add({'text': text, 'voice': voiceJoana});
      } else if (upperLine.startsWith('PROFESSOR:') ||
          upperLine.startsWith('PROFESSOR(A):') ||
          upperLine.startsWith('PROF:') ||
          upperLine.startsWith('HOST:') ||
          upperLine.startsWith('NARRADOR:') ||
          upperLine.startsWith('PROFESSOR :') ||
          upperLine.startsWith('APRESENTADOR:')) {
        final text = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        if (text.isNotEmpty)
          segments.add({'text': text, 'voice': voiceProfessor});
      } else if (trimmed.startsWith('[') && trimmed.contains(']')) {
        // Skip timestamp or segment markers like [05:00]
        continue;
      } else if (segments.isNotEmpty && !trimmed.contains(':')) {
        // Append lines that don't have a colon to the previous segment's text
        // (This handles bullet points or multi-line speeches)
        final lastSegment = segments.last;
        lastSegment['text'] = (lastSegment['text'] as String) + ' ' + trimmed;
      }
    }

    if (segments.isEmpty) {
      throw Exception(
          'O guião do podcast não continha falas no formato esperado.');
    }

    debugPrint(
        'Podcast: Sintetizando ${segments.length} falas com vozes diferentes...');

    // Collect all the raw MP3 bytes
    final List<Uint8List> audioParts = [];

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final text = segment['text'] as String;
      final voice = segment['voice'] as Map<String, String>;

      try {
        final response = await http.post(
          Uri.parse('$ttsEndpoint?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': {'text': text},
            'voice': voice,
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': 1.0,
              'pitch': 0,
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final base64Audio = data['audioContent'] as String?;
          if (base64Audio != null) {
            audioParts.add(base64Decode(base64Audio));
          }
        } else {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['error']?['message'] ?? 'Erro na API de Voz';
          debugPrint(
              'TTS Error for segment $i: $errorMessage (Status: ${response.statusCode})');
          // If the error is 403 or 404, it's likely a configuration issue that won't resolve per-segment
          if (response.statusCode == 403 || response.statusCode == 404) {
            throw 'Erro na API de Voz (${response.statusCode}): $errorMessage. Verifique se a API "Cloud Text-to-Speech" está ativa e se a sua Chave API tem permissão para a usar.';
          }
        }
      } catch (e) {
        debugPrint('TTS segment $i exception: $e');
      }
    }

    if (audioParts.isEmpty) {
      if (segments.isEmpty) {
        throw Exception(
            'Não foram encontradas falas válidas no roteiro. O formato deve ser "JOANA:" ou "PROFESSOR:".');
      }
      throw Exception(
          'A síntese de áudio falhou (403/404). Verifique se a API "Cloud Text-to-Speech" está ativa e se a sua Chave API tem permissão para a usar no Google Cloud Console.');
    }

    // Concatenate all raw MP3 bytes — browsers can play concatenated MP3 frames
    int totalLength = audioParts.fold(0, (sum, part) => sum + part.length);
    final combined = Uint8List(totalLength);
    int offset = 0;
    for (final part in audioParts) {
      combined.setRange(offset, offset + part.length, part);
      offset += part.length;
    }

    debugPrint(
        'Podcast gerado com sucesso: ${(totalLength / 1024).toStringAsFixed(1)} KB de áudio.');
    return combined;
  }

  /// Synthesizes a single piece of text to speech (MP3)
  Future<Uint8List?> synthesizeSpeech(String text, {bool isMale = true}) async {
    const ttsEndpoint =
        'https://texttospeech.googleapis.com/v1/text:synthesize';
    final voice = isMale
        ? {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-B'}
        : {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-A'};

    try {
      final response = await http.post(
        Uri.parse('$ttsEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': voice,
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
            'pitch': 0,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Audio = data['audioContent'] as String?;
        if (base64Audio != null) return base64Decode(base64Audio);
        return null;
      } else if (response.statusCode == 403) {
        throw Exception(
            'Acesso negado (403). Certifique-se de que a "Cloud Text-to-Speech API" está ativada no seu Google Cloud Console.');
      } else {
        throw Exception(
            'Erro na Síntese de Voz: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('TTS single speech exception: $e');
      rethrow;
    }
  }

  Future<List<String>> suggestAnswers(String question, {int count = 4}) async {
    final prompt =
        'Com base no enunciado/pergunta: "$question", sugere $count opções de resposta curtas e plausíveis, '
        'incluindo a resposta correcta. Uma delas deve ser a correcta. As outras devem parecer plausíveis mas conter erros comuns (ex: erros ortográficos se for um ditado). '
        'Retorna APENAS as opções separadas por linhas.';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(count)
          .toList();
    } catch (e) {
      debugPrint('Suggest answers exception: $e');
    }
    return [];
  }

  String _getAudioMimeType(String url) {
    String mimeType = 'audio/mpeg'; // Default
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m4a') || path.endsWith('.mp4')) {
      mimeType = 'audio/mp4';
    } else if (path.endsWith('.aac')) {
      mimeType = 'audio/aac';
    } else if (path.endsWith('.wav')) {
      mimeType = 'audio/wav';
    } else if (path.endsWith('.ogg')) {
      mimeType = 'audio/ogg';
    }
    return mimeType;
  }

  Future<Map<String, dynamic>> evaluateResponse({
    required String question,
    required String studentAnswer,
    required String? criteria,
    String? audioUrl,
    String? imageUrl,
  }) async {
    try {
      final List<Part> parts = [
        TextPart('Avalia a resposta do aluno para a seguinte pergunta:\n'
            'Pergunta: "$question"\n'
            'Resposta do Aluno (Texto/Transcrição): "$studentAnswer"\n'
            'Critérios de Avaliação: "${criteria ?? "Avalia a correção gramatical e semântica"}"\n\n'
            'Se for fornecido áudio ou imagem em anexo, usa-os como fonte principal para a avaliação. '
            'Retorna um JSON com:\n'
            '- "isCorrect": booleano\n'
            '- "score": número de 0 a 1\n'
            '- "feedback": string curta e motivadora em português\n'
            '- "suggestedCorrection": se estiver errado, a resposta certa')
      ];

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final audioResponse = await http.get(Uri.parse(audioUrl));
        if (audioResponse.statusCode == 200) {
          parts.add(
              DataPart(_getAudioMimeType(audioUrl), audioResponse.bodyBytes));
        }
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode == 200) {
          String mimeType = 'image/jpeg'; // Default
          final path = Uri.parse(imageUrl).path.toLowerCase();
          if (path.endsWith('.png')) {
            mimeType = 'image/png';
          } else if (path.endsWith('.webp')) {
            mimeType = 'image/webp';
          }

          parts.add(DataPart(mimeType, imageResponse.bodyBytes));
        }
      }

      final response = await _model.generateContent(
        [Content.multi(parts)],
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );
      final text = response.text ?? '{}';
      return jsonDecode(text);
    } catch (e) {
      debugPrint('Evaluate response exception: $e');
    }
    return {
      'isCorrect': false,
      'score': 0.0,
      'feedback': 'Erro ao avaliar resposta.',
      'suggestedCorrection': null
    };
  }

  /// Generates meeting minutes from a recorded audio URL
  Future<Map<String, dynamic>> generateMeetingMinutes(String audioUrl,
      {String? previousMinutes, String? context}) async {
    final prompt =
        'Abaixo está uma gravação de uma reunião institucional (em áudio). '
        'Por favor, faz a transcrição completa e gera uma proposta de ATA formal. '
        'A ATA deve conter: Título da Reunião, Data, Ordem de Trabalhos, e Resumo das Decisões e Intervenções. '
        'Mantém o tom formal e profissional de uma instituição de ensino. '
        '${context != null ? "Usa o seguinte contexto de documentos de apoio fornecidos: $context" : ""} '
        '${previousMinutes != null ? "Usa o seguinte estilo de atas anteriores como referência: $previousMinutes" : ""} '
        'Retorna um JSON com os campos "transcript" (texto completo) e "minutes" (a ata formatada para impressão).';

    try {
      final List<Part> parts = [TextPart(prompt)];

      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode == 200) {
        parts.add(
            DataPart(_getAudioMimeType(audioUrl), audioResponse.bodyBytes));
      } else {
        throw Exception('Erro ao baixar o áudio: ${audioResponse.statusCode}');
      }

      final response = await _model.generateContent(
        [Content.multi(parts)],
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );

      final text = response.text ?? '{}';
      final cleaned =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned);
    } catch (e) {
      debugPrint('Generate minutes exception: $e');
      return {
        'transcript': 'Erro na transcrição: $e',
        'minutes': 'Erro na geração da ata.'
      };
    }
  }

  /// Generates a structured game based on selected contents
  Future<Map<String, dynamic>?> generateAiGame({
    required List<SubjectContent> contents,
    required String gameType,
  }) async {
    final contentSummaries = contents
        .where((c) => c.url.isNotEmpty)
        .map((c) => '- ${c.name} (${c.type})')
        .join('\n');

    String prompt = '';

    if (gameType == 'jigsaw') {
      prompt =
          'Cria um Jogo de Puzzle (Quebra-Cabeça) baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'O JSON deve conter um "imageUrl" (podes sugerir um prompt para gerar uma imagem educativa relacionada com o tema) '
          'e um objeto "settings" com "gridRows" (ex: 3) e "gridCols" (ex: 3).\n'
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Título do Puzzle",\n'
          '  "type": "jigsaw",\n'
          '  "imageUrl": "https://images.unsplash.com/photo-1614728263952-84ea206f25b1?q=80&w=1000", // Link de exemplo ou prompt para IA\n'
          '  "settings": { "gridRows": 3, "gridCols": 3 },\n'
          '  "questions": [{"question": "Pergunta sobre a imagem", "studyReference": "Capítulo X, Pág Y"}]\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'memory') {
      prompt =
          'Cria um Jogo da Memória Visual baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Identifica pares de conceitos/imagens relacionados. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Título do Jogo da Memória",\n'
          '  "type": "memory",\n'
          '  "settings": { "pairs": [{"a": "Termo 1", "b": "Definição/Imagem 1"}, ...] },\n'
          '  "questions": [{"question": "Conceito 1", "studyReference": "Capítulo X, Pág Y"}]\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'word_search') {
      prompt =
          'Cria uma Sopa de Letras baseada nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Identifica pelo menos 10 palavras-chave curtas. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Sopa de Letras Educativa",\n'
          '  "type": "word_search",\n'
          '  "questions": [{"question": "PALAVRA1", "studyReference": "Capítulo X, Pág Y"}, {"question": "PALAVRA2", "studyReference": "Capítulo Z, Pág W"}, ...]\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'matching') {
      prompt =
          'Cria um Jogo de Correspondência (Matching) baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Cria pelo menos 8 pares de conceitos e definições curtas. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Desafio de Correspondência",\n'
          '  "type": "matching",\n'
          '  "settings": { "pairs": [{"a": "Conceito 1", "b": "Definição 1"}, ...] },\n'
          '  "questions": [{"question": "Pares de Conceitos", "studyReference": "Capítulo X, Pág Y"}]\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else {
      prompt =
          'Cria um jogo educativo de vanguarda do tipo "$gameType" baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'O jogo deve ser divertido, desafiante e pedagogicamente sólido. '
          'Retorna um objecto JSON com a seguinte estrutura EXACTA:\n'
          '{\n'
          '  "title": "Título Criativo do Jogo",\n'
          '  "type": "$gameType",\n'
          '  "questions": [\n'
          '    {\n'
          '      "question": "Texto da pergunta?",\n'
          '      "options": ["Opção A", "Opção B", "Opção C", "Opção D"],\n'
          '      "correctOptionIndex": 0,\n'
          '      "points": 10.0,\n'
          '      "timeLimitSeconds": 20,\n'
          '      "studyReference": "Capítulo X, Pág Y"\n'
          '    }\n'
          '  ]\n'
          '}\n\n'
          'Gera pelo menos 10 perguntas variadas e interessantes. '
          'Para cada pergunta, identifica obrigatoriamente o Capítulo ou Tópico e a página específica do documento de origem (ex: "Capítulo 2, Pág 12") e inclui no campo "studyReference". '
          'IMPORTANTE: Retorna APENAS o JSON.';
    }

    try {
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 4096,
          responseMimeType: 'application/json',
        ),
      );
      final textResponse = response.text ?? '';

      debugPrint('AI Game Raw Response: $textResponse');

      try {
        return jsonDecode(_cleanJsonResponse(textResponse));
      } catch (e) {
        debugPrint('AI Game JSON Parse Error: $e');
        debugPrint('Cleaned JSON: ${_cleanJsonResponse(textResponse)}');
        return null;
      }
    } catch (e) {
      debugPrint('AI Game Gen Exception: $e');
    }
    return null;
  }

  String _cleanJsonResponse(String text) {
    // 1. Try to extract JSON strictly from a markdown block: ```json ... ```
    final RegExp jsonBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    
    // 2. Fallback: Find the first { or [ and just use that to the end.
    // We avoid lastIndexOf '}' because conversational text at the end with a '}' 
    // would capture garbage and cause 'Unexpected non-whitespace character' errors.
    String cleaned = text.trim();
    final firstBrace = cleaned.indexOf('{');
    final firstBracket = cleaned.indexOf('[');
    
    int startIndex = -1;
    if (firstBrace != -1 && (firstBracket == -1 || firstBrace < firstBracket)) {
      startIndex = firstBrace;
    } else if (firstBracket != -1) {
      startIndex = firstBracket;
    }
    
    if (startIndex != -1) {
      // Return from the first '{' or '[' to the end.
      // jsonDecode is forgiving if there's trailing whitespace, but we must
      // hope there's no trailing garbage. If there is trailing garbage without a code block,
      // it might still fail, but this handles 90% of model quirks.
      String jsonPart = cleaned.substring(startIndex);
      
      // Let's also trim out common conversational endings if we see them after the last real bracket
      // A safer approach: find the last '}' or ']' that makes sense, but since that caused the bug,
      // we just return the substring and let jsonDecode try.
      final lastBrace = jsonPart.lastIndexOf('}');
      final lastBracket = jsonPart.lastIndexOf(']');
      int endIndex = (lastBrace != -1 && lastBracket != -1) 
          ? (lastBrace > lastBracket ? lastBrace : lastBracket)
          : (lastBrace != -1 ? lastBrace : lastBracket);
          
      if (endIndex != -1 && endIndex > 0) {
          return jsonPart.substring(0, endIndex + 1).trim();
      }
      return jsonPart;
    }
    
    return cleaned;
  }


  /// Evaluates a student's multimodal response using IA
  Future<Map<String, dynamic>?> evaluateMultimodalResponse({
    required String question,
    String? criteria,
    required String responseType,
    required String responseValue,
  }) async {
    final prompt = '''
Avalia a seguinte resposta de um aluno a uma questão de exame técnico.
A questão e a resposta podem ser em formato multimodal.

QUESTÃO: "$question"
CRITÉRIOS DE AVALIAÇÃO/REFERÊNCIA: "${criteria ?? 'Avaliar a precisão técnica e clareza.'}"
TIPO DE RESPOSTA DO ALUNO: "$responseType"
${responseType == 'text' ? 'RESPOSTA (Texto):' : 'RESPOSTA (URL do ficheiro):'} "$responseValue"

IMPORTANTE: 
1. Se a resposta for uma imagem ou áudio (URL), deves analisar o conteúdo do ficheiro se tiveres acesso, ou avaliar com base na integridade do envio.
2. Deves retornar um objecto JSON com a tua avaliação:
{
  "suggestedScore": 0.0, // Um valor entre 0 e 10 (ou proporcional aos pontos da questão)
  "reasoning": "Breve explicação pedagógica da tua avaliação em português."
}
''';

    try {
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );
      final textResponse = response.text ?? '';
      return jsonDecode(_cleanJsonResponse(textResponse));
    } catch (e) {
      debugPrint('AI Evaluation Exception: $e');
    }
    return null;
  }

  /// Refines a meeting agenda using IA
  Future<String> refineMeetingAgenda(String currentAgenda) async {
    final prompt =
        'Abaixo está a Ordem de Trabalhos (Agenda) de uma reunião institucional. '
        'Por favor, melhora a redação, organiza os pontos de forma lógica e profissional, '
        'e sugere tópicos adicionais se parecerem relevantes para uma reunião institucional. '
        'Mantém o tom formal. Retorna APENAS o texto da agenda melhorada.\n\n'
        'AGENDA ATUAL:\n$currentAgenda';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? currentAgenda;
    } catch (e) {
      debugPrint('Refine agenda exception: $e');
      return currentAgenda;
    }
  }

  /// Generates a formal meeting invitation/notice
  Future<String> generateMeetingInvitation({
    required String title,
    required String agenda,
    required String date,
    required String time,
    required String location,
  }) async {
    final prompt = 'Abaixo estão os detalhes de uma reunião institucional. '
        'Por favor, gera uma Convocatória (Convite) formal e profissional em português. '
        'A convocatória deve incluir: Título, Data, Hora de Início, Local e a Ordem de Trabalhos. '
        'Deixa um espaço ou marcador [NOME DO PARTICIPANTE] se quiseres que seja personalizada. '
        'O tom deve ser institucional e educado.\n\n'
        'TÍTULO: $title\n'
        'DATA: $date\n'
        'HORA: $time\n'
        'LOCAL: $location\n'
        'ORDEM DE TRABALHOS:\n$agenda\n\n'
        'Retorna APENAS o texto da convocatória pronta para enviar.';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('Generate invitation exception: $e');
      return '';
    }
  }

  /// Transcribes audio dictation and suggests a professional meeting agenda
  Future<String> transcribeAndImproveAgenda(Uint8List audioBytes) async {
    final prompt =
        'Abaixo está um ficheiro de áudio com a gravação de uma pessoa a ditar os pontos da ordem de trabalhos para uma reunião. '
        'Por favor, faz a transcrição e organiza esses pontos de forma profissional, lógica e institucional. '
        'Melhora a redação e sugere tópicos adicionais se necessário. '
        'Retorna APENAS o texto da agenda resultante, formatado com numeração ou pontos.';

    try {
      final parts = [
        TextPart(prompt),
        DataPart('audio/mpeg', audioBytes),
      ];

      final response = await _model.generateContent([Content.multi(parts)]);
      return response.text?.trim() ??
          'Não foi possível gerar a agenda a partir do áudio.';
    } catch (e) {
      debugPrint('Transcribe and improve agenda exception: $e');
      return 'Erro ao processar áudio da agenda: $e';
    }
  }

  Future<String> generateSocialMediaPosts({
    required String title,
    required String description,
    required String platform,
  }) async {
    final prompt = 'Abaixo estão os detalhes de uma atividade institucional. '
        'Por favor, gera uma proposta de publicação para a rede social "$platform" em português. '
        'A publicação deve ser cativante, incluir emojis relevantes e hashtags apropriadas. '
        'Adapta o tom ao público da rede escolhida ($platform). '
        'TÍTULO: $title\n'
        'DESCRIÇÃO: $description\n\n'
        'Retorna APENAS o texto da publicação.';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('Generate social post exception: $e');
      return '';
    }
  }

  Future<List<Map<String, String>>> checkSpelling(String text) async {
    if (text.trim().isEmpty) return [];

    final prompt = 'Atua como um corretor ortográfico e gramatical estrito de Português (Portugal). '
        'Analisa o seguinte texto palavra a palavra. Identifica TODOS os erros ortográficos, gralhas, erros de digitação e gramática (ex: "Lectivv" em vez de "Letivo" ou "Lectivo"). '
        'Para cada erro encontrado, fornece a palavra exatamente como foi escrita e a tua sugestão de correção. '
        'Retorna um JSON estritamente neste formato: [{"original": "palvra", "suggestion": "palavra"}, ...]. '
        'Se o texto estiver 100% correto, retorna apenas uma lista vazia: [].\n\n'
        'TEXTO: "$text"';

    // Let exceptions propagate — callers should handle them appropriately.
    final response = await _model.generateContent(
      [Content.text(prompt)],
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final textResponse = response.text ?? '[]';
    final decoded = jsonDecode(_cleanJsonResponse(textResponse));

    // Handle both plain list [] and wrapped object {"errors": [...]}
    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      final value = decoded['errors'] ?? decoded['corrections'] ?? decoded['erros'] ??
          decoded.values.firstWhere((v) => v is List, orElse: () => []);
      list = value is List ? value : [];
    } else {
      list = [];
    }

    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> generateAnnualReportDraft({
    required InstitutionModel institution,
    required List<InstitutionalActivity> activities,
  }) async {
    final activitiesJson = jsonEncode(activities.map((a) => {
      'title': a.title,
      'type': a.activityGroup,
      'description': a.description,
      'participantsCount': a.participants.length,
      'status': a.status,
    }).toList());

    final prompt = '''
Como consultor sénior de estratégia educativa, gera um esboço profissional e inspirador para o Relatório Anual de Atividades da instituição "${institution.name}".

DADOS DA INSTITUIÇÃO:
- Nome: ${institution.name}
- NIF: ${institution.nif}
- Morada: ${institution.address}

ATIVIDADES DO ANO (JSON):
$activitiesJson

INSTRUÇÕES:
1. "introduction": Escreve uma introdução formal (aprox. 150 palavras) que destaque a resiliência e o sucesso educativo no último ano.
2. "sections": Para cada tipo/categoria de atividade identificada, cria um resumo executivo sintetizando os principais ganhos e impactos (aprox. 100 palavras por categoria).
3. "conclusion": Escreve uma conclusão visionária (aprox. 150 palavras) projetando o próximo ano letivo.

RETORNA APENAS UM JSON COM ESTA ESTRUTURA:
{
  "introduction": "...",
  "conclusion": "...",
  "sections": {
    "Categoria A": "Resumo...",
    "Categoria B": "Resumo..."
  }
}
''';

    try {
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.7,
          responseMimeType: 'application/json',
        ),
      );
      
      final text = response.text ?? '{}';
      return jsonDecode(_cleanJsonResponse(text));
    } catch (e) {
      debugPrint('Error generating annual report draft: $e');
      return {
        'introduction': 'Erro ao gerar introdução automática: $e',
        'conclusion': 'Erro ao gerar conclusão automática: $e',
        'sections': {}
      };
    }
  }
}
