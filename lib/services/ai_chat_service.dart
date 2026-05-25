import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../models/institutional_knowledge_model.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../models/subject_model.dart';
import '../models/questionnaire_model.dart';
import '../models/activity_model.dart';

/// Controls the information sources used during a DocTalk session.
enum DocSearchMode {
  /// Use only internal discipline documents. No internet access.
  internal,

  /// Use internet search (Google grounding) as the primary source.
  internet,

  /// Use both internal documents and internet search, with internal prioritized.
  both,
}

class AiChatService {
  late GenerativeModel _model;
  final String _apiKey;
  List<Content> _history = [];

  // Keep track of the current document context for generating games/podcasts
  List<SubjectContent> _currentContents = [];

  // Current DocTalk search mode
  DocSearchMode _searchMode = DocSearchMode.internal;
  DocSearchMode get searchMode => _searchMode;

  AiChatService({required String apiKey}) : _apiKey = apiKey {
    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: apiKey,
    );
  }

  // ─── Institutional Chat (with full extracted text) ──────────────────────────

  Future<void> initializeInstitutionalSession(
      List<InstitutionalKnowledgeDocument> docs) async {
    _history.clear();

    final activeDocs = docs.where((d) => d.documentStatus == DocumentStatus.active).toList();
    final archivedDocs = docs.where((d) => d.documentStatus == DocumentStatus.archived).toList();

    final contextBuffer = StringBuffer();
    contextBuffer.writeln(
        'Tu és o Assistente Virtual de Apoio Institucional Oficial. '
        'Responde de forma cordial, profissional e baseada APENAS nos documentos fornecidos. '
        'Se a informação não estiver nos documentos, diz educadamente que não tens essa informação e sugere contactar a secretaria.\n');

    contextBuffer.writeln('REGRAS DE PRIORIDADE DE DOCUMENTOS:');
    contextBuffer.writeln(
        '1. Consulta PRIMEIRO os documentos marcados como [ATIVO]. '
        'Estes são a versão atual e oficial da informação.');
    contextBuffer.writeln(
        '2. Se a informação pedida NÃO existir em documentos [ATIVO], '
        'podes consultar os documentos [ARQUIVO], mas DEVES indicar claramente na tua resposta '
        'que a informação provém de um documento arquivado (versão anterior) e pode estar desatualizada.');
    contextBuffer.writeln(
        '3. Quando usas um documento [ARQUIVO], inclui sempre no início da resposta um aviso como: '
        '"⚠️ NOTA: A seguinte informação provém de um documento arquivado (versão anterior). '
        'Recomendo verificar com a secretaria se existem atualizações."\n');

    int totalCharCount = 0;
    const maxChars = 100000;

    if (activeDocs.isNotEmpty) {
      contextBuffer.writeln('=== DOCUMENTOS ATIVOS (versão oficial atual) ===');
      for (var doc in activeDocs) {
        if (doc.extractedText != null && doc.extractedText!.isNotEmpty) {
          final validityNote = _buildValidityNote(doc);
          final content =
              '--- [ATIVO] DOCUMENTO: ${doc.title}$validityNote ---\n${doc.extractedText}\n--- FIM DO DOCUMENTO ---\n';
          if (totalCharCount + content.length < maxChars) {
            contextBuffer.writeln(content);
            totalCharCount += content.length;
          }
        }
      }
    }

    if (archivedDocs.isNotEmpty) {
      contextBuffer.writeln('\n=== DOCUMENTOS ARQUIVADOS (versões anteriores - usar apenas como fallback) ===');
      for (var doc in archivedDocs) {
        if (doc.extractedText != null && doc.extractedText!.isNotEmpty) {
          final content =
              '--- [ARQUIVO] DOCUMENTO: ${doc.title} (VERSÃO ANTERIOR - ARQUIVADO) ---\n${doc.extractedText}\n--- FIM DO DOCUMENTO ---\n';
          if (totalCharCount + content.length < maxChars) {
            contextBuffer.writeln(content);
            totalCharCount += content.length;
          }
        }
      }
    }

    _history.add(Content.text(contextBuffer.toString()));
    _history.add(Content.model([
      TextPart(
          'Entendido. Sou o seu Assistente Institucional e estou pronto para responder. '
          'Darei prioridade aos documentos ativos e indicarei claramente quando a informação '
          'provém de documentos arquivados.')
    ]));
  }

  /// Builds a validity note string for a document, e.g. " (Vigência: 01/01/2026 - 31/12/2026)"
  String _buildValidityNote(InstitutionalKnowledgeDocument doc) {
    if (doc.validFrom == null && doc.validUntil == null) return '';
    final parts = <String>[];
    if (doc.validFrom != null) {
      parts.add('desde ${_formatDate(doc.validFrom!)}');
    }
    if (doc.validUntil != null) {
      parts.add('até ${_formatDate(doc.validUntil!)}');
    }
    return ' (Vigência: ${parts.join(' ')})';
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─── DocTalk Session (with selected SubjectContent + search mode) ─────────

  /// Initialize a DocTalk session with the chosen search mode.
  /// [mode] controls whether the AI uses only internal docs, web search, or both.
  Future<void> initializeSessionWithMode(
    dynamic contextData,
    DocSearchMode mode,
  ) async {
    _searchMode = mode;
    _history.clear();

    if (contextData is List<SubjectContent> && contextData.isNotEmpty) {
      _currentContents = contextData;

      final contentLines = contextData
          .map((c) => '  • "${c.name}" (tipo: ${c.type})')
          .join('\n');

      final String systemPrompt;

      switch (mode) {
        case DocSearchMode.internal:
          systemPrompt = '''És um professor e tutor educativo especializado e ALTAMENTE VISUAL.
A tua função é responder EXCLUSIVAMENTE com base nos seguintes documentos/conteúdos selecionados.
NÃO PODES consultar nem mencionar informação externa à internet ou a outras fontes.

CONTEÚDOS SELECIONADOS:
$contentLines

REGRAS DE CONTEÚDO:
1. Responde APENAS sobre os temas dos documentos listados acima.
2. Se a pergunta não estiver coberta por estes documentos, responde EXATAMENTE:
   "ℹ️ Não encontrei documentação interna sobre este tema. Para obter mais informações, consulte o professor ou utilize o modo de pesquisa na Internet."
3. Cita sempre o nome do documento de origem.
4. NÃO uses conhecimento externo, nem a internet.

REGRAS DE FORMATAÇÃO (OBRIGATÓRIO — segue SEMPRE estas regras em TODAS as respostas):
- Usa **tabelas markdown** sempre que comparas conceitos, propriedades, fórmulas ou dados numéricos
- Usa **fórmulas LaTeX** entre \$ para expressões matemáticas: \$E = mc^2\$, \$\\frac{a}{b}\$
- Usa **blocos de código** com \`\`\` para algoritmos, pseudocódigo ou fórmulas extensas
- Usa **## Cabeçalhos** e **### Sub-cabeçalhos** para estruturar a resposta em secções claras
- Usa listas numeradas para passos sequenciais e bullets para enumerações
- Usa **negrito** para termos-chave e *itálico* para definições técnicas
- Quando apresentas dados numéricos, cria SEMPRE uma tabela comparativa
- As respostas devem ser RICAS, BEM ESTRUTURADAS e VISUALMENTE APELATIVAS

Estás a agir como especialista nos seguintes temas: ${contextData.map((c) => c.name).join(', ')}.''';

        case DocSearchMode.internet:
          systemPrompt = '''És um professor e tutor educativo especializado, com acesso à internet, e ALTAMENTE VISUAL.
A tua função é responder com base nos melhores conteúdos disponíveis na internet.
Tens TAMBÉM acesso aos seguintes documentos internos como contexto adicional:

CONTEÚDOS INTERNOS DISPONÍVEIS:
$contentLines

REGRAS DE CONTEÚDO:
1. Usa a internet como fonte primária para dar as respostas mais completas e atualizadas.
2. Combina a informação da internet com os documentos internos se relevante.
3. Cita as fontes que utilizas (documentos internos e/ou links da internet).
4. Apresenta sempre informação verificável e de qualidade.

REGRAS DE FORMATAÇÃO (OBRIGATÓRIO — segue SEMPRE estas regras em TODAS as respostas):
- Usa **tabelas markdown** sempre que comparas conceitos, propriedades, fórmulas ou dados numéricos
- Usa **fórmulas LaTeX** entre \$ para expressões matemáticas: \$E = mc^2\$, \$\\frac{a}{b}\$
- Usa **blocos de código** com \`\`\` para algoritmos, pseudocódigo ou fórmulas extensas
- Usa **## Cabeçalhos** e **### Sub-cabeçalhos** para estruturar a resposta em secções claras
- Usa listas numeradas para passos sequenciais e bullets para enumerações
- Usa **negrito** para termos-chave e *itálico* para definições técnicas
- Quando apresentas dados numéricos, cria SEMPRE uma tabela comparativa
- Inclui exemplos concretos, estudos de caso e analogias visuais
- As respostas devem ser RICAS, BEM ESTRUTURADAS e VISUALMENTE APELATIVAS

Estás a agir como professor especializado em: ${contextData.map((c) => c.name).join(', ')}.''';

        case DocSearchMode.both:
          systemPrompt = '''És um professor e tutor educativo especializado e ALTAMENTE VISUAL.
A tua função é dar as respostas mais completas e úteis possíveis, combinando:
1. Os documentos internos selecionados
2. Os melhores conteúdos disponíveis na internet

CONTEÚDOS INTERNOS SELECIONADOS:
$contentLines

REGRAS DE CONTEÚDO:
1. Começa sempre por verificar os documentos internos.
2. Complementa e enriquece com informação da internet.
3. Indica claramente a origem de cada informação ("[Docs Internos]", "[Internet]").
4. Prioriza os documentos internos quando há conflito de informação.
5. Cita as fontes da internet e o nome dos documentos internos.

REGRAS DE FORMATAÇÃO (OBRIGATÓRIO — segue SEMPRE estas regras em TODAS as respostas):
- Usa **tabelas markdown** sempre que comparas conceitos, propriedades, fórmulas ou dados numéricos
  Formato: | Conceito | Definição | Exemplo | \n |---|---|---| \n | ... | ... | ... |
- Usa **fórmulas LaTeX** entre \$ para expressões matemáticas: \$E = mc^2\$, \$\\frac{{a}}{{b}}\$, \$\\sum_{{i=1}}^{{n}} x_i\$
- Usa **blocos de código** com \`\`\` para algoritmos, pseudocódigo, exemplos ou fórmulas extensas
- Usa **## Cabeçalhos** e **### Sub-cabeçalhos** para estruturar a resposta
- Usa listas numeradas para passos sequenciais e listas com bullets para enumerações
- Usa **negrito** para termos-chave e *itálico* para definições técnicas
- Quando a resposta tem dados numéricos, cria SEMPRE uma tabela comparativa
- Quando compara docs internos vs. internet, usa tabela com coluna de fonte
- Inclui exemplos concretos, estudos de caso e analogias visuais
- As respostas devem ser RICAS, BEM ESTRUTURADAS e VISUALMENTE APELATIVAS

Estás a agir como especialista em: ${contextData.map((c) => c.name).join(', ')}.''';
      }

      final contentNames = contextData.map((c) => '"${c.name}"').join(', ');

      _history.add(Content.text(systemPrompt));
      _history.add(Content.model([
        TextPart(
            'Olá! Estou pronto para ajudar com os seguintes conteúdos: $contentNames. '
            'Modo de pesquisa: ${_searchModeLabel(mode)}. '
            'Faça-me qualquer pergunta!')
      ]));
    } else if (contextData is String) {
      _currentContents = [];
      _history.add(Content.text(contextData));
      _history.add(Content.model([TextPart('Olá, em que posso ajudar hoje?')]));
    } else {
      _currentContents = [];
      _history.add(Content.text('És um assistente educativo experiente e útil.'));
      _history.add(Content.model([TextPart('Olá, em que posso ajudar hoje?')]));
    }
  }

  /// Legacy wrapper — defaults to internal-only mode
  Future<void> initializeSession(dynamic contextData) =>
      initializeSessionWithMode(contextData, DocSearchMode.internal);

  String _searchModeLabel(DocSearchMode mode) {
    switch (mode) {
      case DocSearchMode.internal:
        return '📁 Documentos Internos';
      case DocSearchMode.internet:
        return '🌐 Internet';
      case DocSearchMode.both:
        return '📁+🌐 Interno + Internet';
    }
  }

  // ─── Send message (respects current search mode) ────────────────────────────

  Stream<String> sendMessage(String message) async* {
    if (_searchMode == DocSearchMode.internet ||
        _searchMode == DocSearchMode.both) {
      yield* _sendMessageWithWebSearch(message);
    } else {
      yield* _sendMessageInternal(message);
    }
  }

  /// Internal-only streaming: uses the SDK chat history (no web access).
  Stream<String> _sendMessageInternal(String message) async* {
    if (_history.isEmpty) {
      _history.add(Content.text('És um assistente educativo experiente e útil.'));
    }

    final userContent = Content.text(message);
    _history.add(userContent);

    try {
      final response = _model.generateContentStream(_history);
      final fullResponse = StringBuffer();

      await for (final chunk in response) {
        if (chunk.text != null) {
          fullResponse.write(chunk.text);
          yield chunk.text!;
        }
      }

      _history.add(Content.model([TextPart(fullResponse.toString())]));
    } catch (e) {
      debugPrint('AI Chat Service Error: $e');
      yield 'Erro de comunicação: $e';
      rethrow;
    }
  }

  /// Uses the SDK model with a knowledge-enriched prompt to simulate web search.
  /// Works with any standard Gemini API key — no grounding permissions needed.
  Stream<String> _sendMessageWithWebSearch(String message) async* {
    final enhancedHistory = <Content>[];

    // Enhance the system prompt with web-search instructions
    for (int i = 0; i < _history.length; i++) {
      if (i == 0) {
        final originalText = _history[i].parts
            .whereType<TextPart>()
            .map((p) => p.text)
            .join(' ');
        enhancedHistory.add(Content.text(
          '$originalText\n\n'
          'INSTRU\u00c7\u00c3O ADICIONAL \u2014 MODO PESQUISA WEB:\n'
          'Para esta resposta, usa TODO o teu conhecimento de treino '
          '(que inclui vastos conte\u00fados da internet) para dar '
          'a resposta mais completa, atual e bem fundamentada poss\u00edvel. '
          'Menciona conceitos, teorias, exemplos reais e refer\u00eancias reconhecidas. '
          'No final da resposta, inclui sempre uma sec\u00e7\u00e3o '
          '"## \ud83c\udf10 Fontes & Refer\u00eancias" com refer\u00eancias reais: '
          'livros acad\u00e9micos, artigos cient\u00edficos, ou dom\u00ednios de sites relevantes '
          '(Wikipedia, Khan Academy, Britannica, Nature, etc.).',
        ));
      } else {
        enhancedHistory.add(_history[i]);
      }
    }
    enhancedHistory.add(Content.text('[PESQUISA] $message'));

    try {
      final response = _model.generateContentStream(enhancedHistory);
      final fullResponse = StringBuffer();
      await for (final chunk in response) {
        if (chunk.text != null) {
          fullResponse.write(chunk.text);
          yield chunk.text!;
        }
      }
      _history.add(Content.text(message));
      _history.add(Content.model([TextPart(fullResponse.toString())]));
    } catch (e) {
      debugPrint('Web-enriched search error: $e');
      yield 'Erro ao processar pesquisa: $e';
    }
  }

  Stream<String> sendMessageWithImage(String message, Uint8List imageBytes, String mimeType) async* {
    if (_history.isEmpty) {
      _history.add(Content.text('És um assistente educativo experiente e útil.'));
    }

    final userContent = Content.multi([
      DataPart(mimeType, imageBytes),
      TextPart(message.isNotEmpty ? message : 'O que vês nesta imagem? Analisa e discute no contexto dos documentos.'),
    ]);
    _history.add(userContent);

    try {
      final response = _model.generateContentStream(_history);
      final fullResponse = StringBuffer();

      await for (final chunk in response) {
        if (chunk.text != null) {
          fullResponse.write(chunk.text);
          yield chunk.text!;
        }
      }
      _history.add(Content.model([TextPart(fullResponse.toString())]));
    } catch (e) {
      debugPrint('AI Chat Vision Error: $e');
      yield 'Erro ao analisar imagem: $e';
    }
  }

  // ─── AI Game Generation (with real content context) ──────────────────────────

  Future<Map<String, dynamic>> generateAiGame({
    required List<SubjectContent> contents,
    required String gameType,
    String difficulty = 'médio',
    int numQuestions = 10,
  }) async {
    final contentDescriptions = contents
        .map((c) => '  • "${c.name}" (${c.type})')
        .join('\n');

    final topicNames = contents.map((c) => c.name).join(', ');


    final prompt = '''Gera um jogo educativo do tipo "$gameType" com dificuldade "$difficulty" e exatamente $numQuestions perguntas.

O jogo é exclusivamente sobre os seguintes documentos/temas:
$contentDescriptions

As perguntas devem cobrir os conceitos, definições, e aplicações práticas dos temas: $topicNames.

Responde APENAS em JSON válido com esta estrutura (sem texto adicional fora do JSON):
{
  "title": "Título do jogo baseado nos documentos: $topicNames",
  "questions": [
    {
      "question": "Pergunta clara baseada nos temas dos documentos",
      "options": ["Opção A", "Opção B", "Opção C", "Opção D"],
      "correctOptionIndex": 0,
      "points": 10,
      "timeLimitSeconds": 30,
      "explanation": "Explicação da resposta correta, referenciando o conteúdo"
    }
  ]
}

REGRAS:
- correctOptionIndex é 0-indexed (0=A, 1=B, 2=C, 3=D)
- Varia pontos: fáceis=5pts, médias=10pts, difíceis=15pts
- Varia tempos: 20-60 segundos
- As opções erradas devem ser plausíveis mas claramente incorretas
- Inclui a "explanation" em todas as perguntas
- Cobre todos os documentos de forma equilibrada
''';

    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return jsonDecode(_cleanJson(response.text));
    } catch (e) {
      debugPrint('generateAiGame error: $e');
      return {'title': 'Erro ao gerar jogo', 'questions': []};
    }
  }

  // ─── Podcast Script Generation ───────────────────────────────────────────────

  Future<String> generatePodcastScript() async {
    final contentNames = _currentContents.isNotEmpty
        ? _currentContents.map((c) => '"${c.name}"').join(', ')
        : 'conteúdos educativos gerais';

    final prompt = '''Cria um roteiro de podcast educativo de 5-8 minutos sobre os seguintes conteúdos: $contentNames.

Formato OBRIGATÓRIO do roteiro (usa exatamente estes prefixos):
PROFESSOR: [fala do professor/apresentador]
JOANA: [fala da estudante/interlocutora]

Exemplo:
PROFESSOR: Bem-vindos ao nosso podcast. Hoje vamos falar sobre $contentNames.
JOANA: Olá professor! Estou muito curiosa sobre estes temas.
PROFESSOR: Vamos começar pelo conceito mais importante...
JOANA: Pode dar um exemplo prático?

Regras:
- Alterna entre PROFESSOR e JOANA
- Cada fala deve ter 1-3 frases curtas
- Tom conversacional, educativo e envolvente
- Cobre os principais pontos dos documentos selecionados
- NÃO uses outros prefixos além de "PROFESSOR:" e "JOANA:"
''';

    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('generatePodcastScript error: $e');
      return '';
    }
  }

  // ─── Podcast Audio Synthesis (Cloud TTS) ─────────────────────────────────────

  Future<Uint8List?> synthesizePodcastAudio(String script) async {
    final segments = _parsePodcastScript(script);
    if (segments.isEmpty) return null;

    final BytesBuilder combinedAudio = BytesBuilder();
    
    try {
      for (var segment in segments) {
        final voiceName = segment.speaker == 'PROFESSOR' 
            ? 'pt-PT-Standard-B' // Male
            : 'pt-PT-Standard-A'; // Female
        
        final audioPart = await _synthesizeText(segment.text, voiceName);
        if (audioPart != null) {
          combinedAudio.add(audioPart);
        }
      }
      
      return combinedAudio.toBytes();
    } catch (e) {
      debugPrint('Error synthesizing podcast audio: $e');
      rethrow;
    }
  }

  Future<Uint8List?> _synthesizeText(String text, String voiceName) async {
    final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey');
    
    final body = jsonEncode({
      'input': {'text': text},
      'voice': {
        'languageCode': 'pt-PT',
        'name': voiceName,
      },
      'audioConfig': {
        'audioEncoding': 'MP3',
        'pitch': 0,
        'speakingRate': 1.0,
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return base64Decode(data['audioContent']);
      } else {
        final errorDetail = jsonDecode(response.body)['error']?['message'] ?? response.body;
        debugPrint('TTS API Error (${response.statusCode}): $errorDetail');
        throw errorDetail;
      }
    } catch (e) {
      debugPrint('TTS Request Error: $e');
      return null;
    }
  }

  List<_PodcastSegment> _parsePodcastScript(String script) {
    final List<_PodcastSegment> segments = [];
    final lines = script.split('\n');
    
    String currentSpeaker = '';
    StringBuffer currentText = StringBuffer();

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('PROFESSOR:')) {
        if (currentSpeaker.isNotEmpty && currentText.isNotEmpty) {
          segments.add(_PodcastSegment(currentSpeaker, currentText.toString().trim()));
        }
        currentSpeaker = 'PROFESSOR';
        currentText = StringBuffer(trimmed.replaceFirst('PROFESSOR:', '').trim());
      } else if (trimmed.startsWith('JOANA:')) {
        if (currentSpeaker.isNotEmpty && currentText.isNotEmpty) {
          segments.add(_PodcastSegment(currentSpeaker, currentText.toString().trim()));
        }
        currentSpeaker = 'JOANA';
        currentText = StringBuffer(trimmed.replaceFirst('JOANA:', '').trim());
      } else {
        if (currentSpeaker.isNotEmpty) {
          currentText.write(' $trimmed');
        }
      }
    }

    // Add last segment
    if (currentSpeaker.isNotEmpty && currentText.isNotEmpty) {
      segments.add(_PodcastSegment(currentSpeaker, currentText.toString().trim()));
    }

    return segments;
  }

  Future<Uint8List> synthesizeSpeech(String text) async {
    final audio = await _synthesizeText(text, 'pt-PT-Standard-A');
    return audio ?? Uint8List(0);
  }

  // ─── Other AI functions ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> evaluateMultimodalResponse({
    required String question,
    required String criteria,
    required String responseType,
    required String responseValue,
  }) async {
    final prompt =
        'Avalie a seguinte resposta de um aluno.\n\nPergunta: $question\nCritérios: $criteria\nTipo de resposta: $responseType\nResposta do aluno: $responseValue\n\nResponda em JSON: {"suggestedScore": 0.0-10.0, "reasoning": "...", "feedback": "..."}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return jsonDecode(_cleanJson(response.text));
    } catch (e) {
      return {
        'suggestedScore': 0.0,
        'reasoning': 'Erro na avaliação',
        'feedback': 'Não foi possível avaliar'
      };
    }
  }

  Future<Map<String, dynamic>> evaluateResponse({
    required String question,
    required String studentAnswer,
    String? criteria,
    String? audioUrl,
    String? imageUrl,
  }) async {
    final prompt =
        'Avalie se a resposta do aluno está correta.\nPergunta: $question\nResposta: $studentAnswer\n${criteria != null ? "Critérios: $criteria" : ""}\n\nResponda em JSON: {"isCorrect": true/false, "feedback": "..."}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return jsonDecode(_cleanJson(response.text));
    } catch (e) {
      return {'isCorrect': false, 'feedback': 'Erro na avaliação'};
    }
  }

  Future<String> generateSocialMediaPosts({
    required String title,
    required String description,
    List<String>? tags,
    String? platform,
  }) async {
    final prompt =
        'Cria um post para ${platform ?? "redes sociais"} sobre: $title. Descrição: $description. ${tags != null ? "Tags: ${tags.join(", ")}" : ""}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  Future<String> refineMeetingAgenda(String rawAgenda) async {
    final prompt =
        'Melhora e estrutura esta agenda de reunião de forma profissional:\n$rawAgenda';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  Future<String> generateMeetingInvitation({
    required String title,
    required String agenda,
    required String date,
    required String time,
    required String location,
  }) async {
    final prompt =
        'Cria um convite formal de reunião.\nTítulo: $title\nData: $date\nHora: $time\nLocal: $location\nAgenda: $agenda';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  Future<Map<String, dynamic>> generateMeetingMinutes(String audioUrl,
      {String? context}) async {
    final prompt =
        'Com base no seguinte contexto de reunião, cria uma ata profissional:\n${context ?? audioUrl}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    return {'minutes': response.text ?? '', 'transcript': ''};
  }

  Future<String> transcribeAndImproveAgenda(Uint8List audioBytes) async {
    return 'Transcrição não disponível neste dispositivo.';
  }

  Future<List<Map<String, String>>> checkSpelling(String text) async {
    final prompt =
        'Verifica o ortografia e gramática do seguinte texto e devolve uma lista de correções em JSON: [{"original": "...", "corrected": "...", "explanation": "..."}]\n\nTexto:\n$text';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return List<Map<String, String>>.from(
          jsonDecode(_cleanJson(response.text)));
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> generateAnnualReportDraft({
    required InstitutionModel institution,
    required List<InstitutionalActivity> activities,
  }) async {
    final activitiesSummary = activities
        .take(20)
        .map((a) => '- ${a.title}: ${a.description}')
        .join('\n');
    final prompt =
        'Cria um rascunho de relatório anual para a instituição "${institution.name}".\n\nAtividades:\n$activitiesSummary\n\nResponde em JSON: {"introduction": "...", "conclusion": "...", "sections": {"key": "value"}}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return jsonDecode(_cleanJson(response.text));
    } catch (e) {
      return {'introduction': '', 'conclusion': '', 'sections': {}};
    }
  }

  Future<Map<String, dynamic>> analyzeSurveyResponses({
    required Questionnaire survey,
    required List<QuestionnaireResponse> responses,
    required Map<String, List<String>> openTextAnswers,
  }) async {
    final prompt =
        'Analisa ${responses.length} respostas ao inquérito "${survey.title}". '
        'Respostas de texto aberto: ${openTextAnswers.entries.take(5).map((e) => "${e.key}: ${e.value.take(3).join(", ")}").join("; ")}. '
        'Responde em JSON: {"qualitativeInsights": {}, "overallScore": 0, "keyTrends": []}';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return jsonDecode(_cleanJson(response.text));
    } catch (e) {
      return {
        'qualitativeInsights': {},
        'overallScore': 0,
        'keyTrends': []
      };
    }
  }

  Future<String> generateHREvaluationFeedback({
    required UserModel employee,
    required dynamic attendance,
    required List<dynamic> absences,
  }) async {
    final prompt =
        'Cria um feedback de avaliação profissional para o colaborador ${employee.name}. '
        'Número de ausências: ${absences.length}. '
        'Sê construtivo e profissional.';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  Future<List<String>> suggestAnswers(dynamic query) async {
    final prompt =
        'Sugere 3 possíveis respostas curtas e educativas para: $query. Responde em JSON: ["resposta1", "resposta2", "resposta3"]';
    final response =
        await _model.generateContent([Content.text(prompt)]);
    try {
      return List<String>.from(jsonDecode(_cleanJson(response.text)));
    } catch (e) {
      return [];
    }
  }

  Future<String?> generateImage(String prompt) async => null;

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _cleanJson(String? text) {
    if (text == null) return '{}';
    final clean = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    return clean.isEmpty ? '{}' : clean;
  }
}

class _PodcastSegment {
  final String speaker;
  final String text;
  _PodcastSegment(this.speaker, this.text);
}
