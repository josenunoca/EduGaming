import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/institutional_knowledge_model.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../models/subject_model.dart';
import '../models/questionnaire_model.dart';
import '../models/activity_model.dart';

class AiChatService {
  late GenerativeModel _model;
  ChatSession? _currentSession;

  // Keep track of the current document context for generating games/podcasts
  List<SubjectContent> _currentContents = [];

  AiChatService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  // ─── Institutional Chat (with full extracted text) ──────────────────────────

  Future<void> initializeInstitutionalSession(
      List<InstitutionalKnowledgeDocument> docs) async {
    final contextBuffer = StringBuffer();
    contextBuffer.writeln(
        'Tu és o Assistente Virtual de Apoio Institucional Oficial. '
        'Responde de forma cordial, profissional e baseada APENAS nos documentos fornecidos. '
        'Se a informação não estiver nos documentos, diz educadamente que não tens essa informação e sugere contactar a secretaria.');
    contextBuffer.writeln('\nDOCUMENTOS DE REFERÊNCIA:');

    int totalCharCount = 0;
    const maxChars = 100000;

    for (var doc in docs) {
      if (doc.extractedText != null && doc.extractedText!.isNotEmpty) {
        final content =
            '--- INÍCIO DO DOCUMENTO: ${doc.title} ---\n${doc.extractedText}\n--- FIM DO DOCUMENTO ---\n';
        if (totalCharCount + content.length < maxChars) {
          contextBuffer.writeln(content);
          totalCharCount += content.length;
        }
      }
    }

    try {
      _currentSession = _model.startChat(history: [
        Content.text(contextBuffer.toString()),
        Content('model', [
          TextPart(
              'Entendido. Sou o seu Assistente Institucional e estou pronto para responder com base nos documentos carregados.')
        ]),
      ]);
    } catch (e) {
      debugPrint('Error starting institutional chat session: $e');
      rethrow;
    }
  }

  // ─── DocTalk Session (with selected SubjectContent) ─────────────────────────

  Future<void> initializeSession(dynamic contextData) async {
    if (contextData is List<SubjectContent> && contextData.isNotEmpty) {
      _currentContents = contextData;

      final contentLines = contextData
          .map((c) => '  • "${c.name}" (tipo: ${c.type})')
          .join('\n');

      final systemPrompt = '''És um professor e tutor educativo especializado.
A tua função é responder exclusivamente sobre os seguintes documentos/conteúdos selecionados pelo utilizador:

CONTEÚDOS SELECIONADOS:
$contentLines

REGRAS ESTRITAS:
1. Responde APENAS sobre os temas dos documentos listados acima.
2. Se a pergunta não estiver relacionada com nenhum destes documentos, diz: "Esta questão não está relacionada com os conteúdos selecionados. Por favor selecione o documento adequado ou reformule a pergunta."
3. Cita sempre o nome do documento quando forneces informação.
4. Sê pedagógico, claro e usa exemplos quando útil.
5. NÃO respondas sobre assuntos fora dos documentos listados.
6. Se não tiveres informação suficiente sobre um tema específico do documento, pede ao utilizador para fornecer mais contexto.

Estás a agir como especialista nos seguintes temas: ${contextData.map((c) => c.name).join(', ')}.''';

      final contentNames =
          contextData.map((c) => '"${c.name}"').join(', ');

      _currentSession = _model.startChat(history: [
        Content.text(systemPrompt),
        Content('model', [
          TextPart(
              'Olá! Estou pronto para ajudar com os seguintes conteúdos: $contentNames. '
              'Faça-me qualquer pergunta sobre estes materiais!')
        ]),
      ]);
    } else if (contextData is String) {
      _currentContents = [];
      _currentSession = _model.startChat(history: [
        Content.text(contextData),
        Content('model', [TextPart('Olá, em que posso ajudar hoje?')])
      ]);
    } else {
      _currentContents = [];
      _currentSession = _model.startChat(history: [
        Content.text('És um assistente educativo experiente e útil.'),
        Content('model', [TextPart('Olá, em que posso ajudar hoje?')])
      ]);
    }
  }

  // ─── Send streaming message ──────────────────────────────────────────────────

  Stream<String> sendMessage(String message) async* {
    _currentSession ??= _model.startChat();

    try {
      final response =
          _currentSession!.sendMessageStream(Content.text(message));
      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('AI Chat Service Error: $e');
      yield 'Erro de comunicação: $e';
      rethrow;
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
    debugPrint('synthesizePodcastAudio: TTS not implemented in this service');
    return null;
  }

  Future<Uint8List> synthesizeSpeech(String text) async => Uint8List(0);

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
