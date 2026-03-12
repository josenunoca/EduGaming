import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/subject_model.dart';

class AiChatService {
  final String _apiKey;
  final List<Map<String, dynamic>> _history = [];
  String _systemPrompt = '';

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const _systemInstruction =
      'Você é um professor e pesquisador de vanguarda, um especialista altamente qualificado na área científica dos documentos fornecidos. '
      'Seu objetivo é travar um diálogo profissional, profundo e pedagógico com o usuário (que pode ser um aluno ou outro professor). '
      'Você deve basear suas respostas INTEGRALMENTE nos documentos fornecidos como contexto. '
      'Se o usuário perguntar algo fora do escopo dos documentos, explique educadamente que sua especialidade nestas sessões se limita ao conteúdo selecionado. '
      'Mantenha um tom encorajador, acadêmico e visionário. Responda no idioma em que for questionado.';

  AiChatService(String apiKey) : _apiKey = apiKey;

  Future<void> initializeSession(List<SubjectContent> contents) async {
    _history.clear();

    // Build context from content URLs (text-based summary for v1 REST)
    final contentSummaries = contents
        .where((c) => c.url.isNotEmpty)
        .map((c) => '- ${c.name} (${c.type}): ${c.url}')
        .join('\n');

    _systemPrompt =
        '$_systemInstruction\n\nDocumentos de referência disponíveis:\n$contentSummaries';

    // Prime the conversation with context
    _history.add({
      'role': 'user',
      'parts': [
        {
          'text':
              'Aqui estão os documentos que vamos discutir:\n$contentSummaries'
        }
      ]
    });
    _history.add({
      'role': 'model',
      'parts': [
        {
          'text':
              'Entendido. Analisei os documentos e estou pronto para discutir os temas abordados de forma profissional e detalhada. Como posso ajudar?'
        }
      ]
    });
  }

  Stream<String> sendMessage(String message) async* {
    _history.add({
      'role': 'user',
      'parts': [
        {'text': message}
      ]
    });

    try {
      final requestBody = {
        'system_instruction': {
          'parts': [
            {
              'text':
                  _systemPrompt.isNotEmpty ? _systemPrompt : _systemInstruction
            }
          ]
        },
        'contents': _history,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 8192,
        }
      };

      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?.toString()
            .trim();

        if (reply != null && reply.isNotEmpty) {
          _history.add({
            'role': 'model',
            'parts': [
              {'text': reply}
            ]
          });
          yield reply;
        } else {
          yield 'Não obtive uma resposta válida. Tente novamente.';
        }
      } else {
        debugPrint(
            'AI Chat HTTP Error [${response.statusCode}]: ${response.body}');
        if (response.statusCode == 403) {
          yield 'Erro: Chave de API inválida ou sem permissões para o Gemini.';
        } else if (response.statusCode == 429) {
          yield 'Erro: Limite de cota atingido. Aguarde um momento.';
        } else {
          yield 'Erro de comunicação [${response.statusCode}]. Tente novamente.';
        }
      }
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      yield 'Erro técnico: $e';
    }
  }

  Future<String?> generateImage(String prompt) async {
    const endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:generateContent';
    final fullPrompt =
        'Educational illustration: $prompt. Style: Professional, clean, and clear.';

    try {
      final response = await http.post(
        Uri.parse('$endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Image = data['candidates']?[0]?['content']?['parts']?[0]
            ?['inlineData']?['data'];
        return base64Image;
      }
      debugPrint('Image Gen Error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('Image Gen Exception: $e');
    }
    return null;
  }

  Future<String> generatePodcastScript() async {
    if (_history.isEmpty) return '';

    // Use the full conversation history as context for the script
    final scriptContents = List<Map<String, dynamic>>.from(_history);

    const prompt =
        'Com base em TODA a conversa acima, cria um roteiro de podcast completo e profissional em português europeu. '
        'O podcast tem dois apresentadores: "JOANA" (entrevistadora dinâmica) e "PROFESSOR" (especialista apaixonado). '
        'O roteiro deve cobrir TODOS os temas importantes discutidos na conversa, de forma natural, fluida e educativa. '
        'Deve ser um podcast LONGO (pelo menos 15 a 20 trocas de falas). '
        'Usa APENAS este formato para cada fala, uma por linha:\n'
        'JOANA: [texto da fala]\n'
        'PROFESSOR: [texto da fala]\n\n'
        'Não uses formatação especial, asteriscos, parênteses, ou marcações. Apenas falas diretas e naturais.\n'
        'Começa com uma introdução cativante da JOANA e termina com uma conclusão inspiradora do PROFESSOR.\n'
        'IMPORTANTE: Retorna APENAS as falas, sem títulos, sem explicações, sem blocos de código.';

    scriptContents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ]
    });

    final requestBody = {
      'contents': scriptContents,
      'generationConfig': {
        'temperature': 0.75,
        'maxOutputTokens': 4096,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text']
                ?.toString()
                .trim() ??
            '';
      }
      debugPrint(
          'Podcast Script Error: ${response.statusCode} - ${response.body}');
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

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('JOANA:')) {
        final text = trimmed.substring('JOANA:'.length).trim();
        if (text.isNotEmpty) segments.add({'text': text, 'voice': voiceJoana});
      } else if (trimmed.startsWith('PROFESSOR:')) {
        final text = trimmed.substring('PROFESSOR:'.length).trim();
        if (text.isNotEmpty) {
          segments.add({'text': text, 'voice': voiceProfessor});
        }
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
          debugPrint('TTS Error for segment $i: $errorMessage');
          // Continue with other segments instead of failing entirely
        }
      } catch (e) {
        debugPrint('TTS segment $i exception: $e');
      }
    }

    if (audioParts.isEmpty) {
      throw Exception(
          'Não foi possível gerar áudio para nenhuma fala do podcast.');
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
      prompt = 'Cria um Jogo de Puzzle (Quebra-Cabeça) baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'O JSON deve conter um "imageUrl" (podes sugerir um prompt para gerar uma imagem educativa relacionada com o tema) '
          'e um objeto "settings" com "gridRows" (ex: 3) e "gridCols" (ex: 3).\n'
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Título do Puzzle",\n'
          '  "type": "jigsaw",\n'
          '  "imageUrl": "https://images.unsplash.com/photo-1614728263952-84ea206f25b1?q=80&w=1000", // Link de exemplo ou prompt para IA\n'
          '  "settings": { "gridRows": 3, "gridCols": 3 },\n'
          '  "questions": []\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'memory') {
       prompt = 'Cria um Jogo da Memória Visual baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Identifica pares de conceitos/imagens relacionados. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Título do Jogo da Memória",\n'
          '  "type": "memory",\n'
          '  "settings": { "pairs": [{"a": "Termo 1", "b": "Definição/Imagem 1"}, ...] },\n'
          '  "questions": []\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'word_search') {
      prompt = 'Cria uma Sopa de Letras baseada nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Identifica pelo menos 10 palavras-chave curtas. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Sopa de Letras Educativa",\n'
          '  "type": "word_search",\n'
          '  "questions": [{"question": "PALAVRA1"}, {"question": "PALAVRA2"}, ...]\n'
          '}\n\n'
          'IMPORTANTE: Retorna APENAS o JSON.';
    } else if (gameType == 'matching') {
      prompt = 'Cria um Jogo de Correspondência (Matching) baseado nos seguintes conteúdos:\n$contentSummaries\n\n'
          'Cria pelo menos 8 pares de conceitos e definições curtas. '
          'Retorna um objecto JSON com esta estrutura:\n'
          '{\n'
          '  "title": "Desafio de Correspondência",\n'
          '  "type": "matching",\n'
          '  "settings": { "pairs": [{"a": "Conceito 1", "b": "Definição 1"}, ...] },\n'
          '  "questions": []\n'
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
          '      "timeLimitSeconds": 20\n'
          '    }\n'
          '  ]\n'
          '}\n\n'
          'Gera pelo menos 10 perguntas variadas e interessantes. '
          'IMPORTANTE: Retorna APENAS o JSON.';
    }

    try {
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
            'temperature': 0.8,
            'maxOutputTokens': 4096,
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        debugPrint('AI Game Raw Response: $textResponse');

        try {
          return jsonDecode(_cleanJsonResponse(textResponse));
        } catch (e) {
          debugPrint('AI Game JSON Parse Error: $e');
          debugPrint('Cleaned JSON: ${_cleanJsonResponse(textResponse)}');
          return null;
        }
      }
      debugPrint(
          'AI Game Gen Error: ${response.statusCode} - ${response.body}');
      debugPrint('Endpoint used: $_endpoint');
    } catch (e) {
      debugPrint('AI Game Gen Exception: $e');
    }
    return null;
  }

  String _cleanJsonResponse(String text) {
    // Remove markdown code blocks if present
    if (text.contains('```')) {
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        return text.substring(startIndex, endIndex + 1);
      }
    }
    return text.trim();
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
            'temperature': 0.3,
            'maxOutputTokens': 1024,
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return jsonDecode(_cleanJsonResponse(textResponse));
      }
    } catch (e) {
      debugPrint('AI Evaluation Exception: $e');
    }
    return null;
  }
}
