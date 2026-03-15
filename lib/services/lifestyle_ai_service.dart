import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/questionnaire_model.dart';

class LifestyleAiService {
  final String apiKey;
  late final GenerativeModel _model;

  LifestyleAiService(this.apiKey) {
    _model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
  }

  Future<Map<String, dynamic>> analyzeResults(
    Questionnaire questionnaire,
    List<QuestionnaireResponse> responses,
  ) async {
    final prompt = '''
Analise os resultados deste inquérito sobre Estilo de Vida Saudável para uma instituição.
Título do Inquérito: ${questionnaire.title}
Descrição: ${questionnaire.description}

Respostas (JSON):
${jsonEncode(responses.map((r) => r.answers).toList())}

Por favor, forneça o seguinte em formato JSON:
1. "descriptiveStatistics": Um resumo estatístico detalhado de cada pergunta.
   - Para perguntas de seleção: percentagens e distribuição.
   - Para perguntas de texto: análise de sentimentos e temas recorrentes.
2. "advancedMetrics": 
   - "distributions": Dados para histogramas (frequências).
   - "quartiles": Valores para diagramas de extremos e quartis (mínimo, Q1, mediana, Q3, máximo).
3. "qualitativeAnalysis": Uma análise qualitativa profunda do estado de bem-estar dos colaboradores.
4. "strategies": Uma lista de 5 estratégias concretas (eventos, medidas, mudanças de infraestrutura) para melhorar o estilo de vida, baseadas nos problemas identificados.
5. "pdfSummary": Um parágrafo executivo para o relatório oficial.

Retorne APENAS o JSON.
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    
    try {
      final text = response.text ?? '{}';
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      return {'error': 'Failed to parse AI response: $e'};
    }
  }

  Future<String> generateProposalEvent(String strategy) async {
    final prompt = 'Baseado nesta estratégia de melhoria do estilo de vida: "$strategy", descreva um evento detalhado (nome, duração, atividades, impacto esperado) para a instituição implementar.';
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? 'Detalhes não disponíveis';
  }
}
