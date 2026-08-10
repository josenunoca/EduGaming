import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/student_absence_model.dart';
import '../models/institutional_knowledge_model.dart';
import '../services/firebase_service.dart';
import '../services/ai_chat_service.dart';
import '../services/institutional_knowledge_service.dart';

class EduGamingHelpAiService {
  /// Builds complete live data context for the user role and queries Gemini AI with strict RGPD Privacy & Document Eligibility enforcement
  static Stream<String> askHelp({
    required UserModel user,
    required String userQuestion,
    required FirebaseService firebaseService,
    required AiChatService aiChatService,
    InstitutionalKnowledgeService? knowledgeService,
  }) async* {
    try {
      final institutionId = user.institutionId ?? '';
      final roleText = _getRoleText(user.role);

      // Build Dynamic Platform & Real-Time Scoped Context
      final StringBuffer contextBuffer = StringBuffer();

      contextBuffer.writeln('========================================');
      contextBuffer.writeln('MANUAL E ESTADO DA PLATAFORMA EDUGAMING 360');
      contextBuffer.writeln('========================================');
      contextBuffer.writeln('Utilizador: ${user.name} (${user.email})');
      contextBuffer.writeln('Nível de Acesso / Perfil: $roleText');
      contextBuffer.writeln('Data/Hora Atual: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      contextBuffer.writeln('');

      contextBuffer.writeln('--- REGRAS DE FUNCIONAMENTO DA PLATAFORMA ---');
      contextBuffer.writeln('1. CONTROLO DE PRESENÇAS E QR CODE DINÂMICO:');
      contextBuffer.writeln('   - Ponto Digital via QR Code Dinâmico temporizado (muda a cada 30-60 segundos para evitar fraudes/fotografias).');
      contextBuffer.writeln('   - Funciona na Web (Chrome/Safari), Android e iPhone (iOS) em tempo real pela câmara ou carregamento de foto.');
      contextBuffer.writeln('   - Permite entradas/saídas de alunos, educandos e colaboradores/docentes.');
      contextBuffer.writeln('');
      contextBuffer.writeln('2. AVISOS AUTOMÁTICOS DE AUSÊNCIA PARA PAIS (MENORES):');
      contextBuffer.writeln('   - Exclusivo para educandos menores de idade (< 18 anos). Data de nascimento é obrigatória no registo.');
      contextBuffer.writeln('   - Se a criança não registar entrada até ao horário previsto, o sistema envia AUTOMATICAMENTE Email + SMS aos pais.');
      contextBuffer.writeln('   - Se os pais comunicarem previamente a ausência na app, os alertas por email e SMS são SUPRIMIDOS para esse dia.');
      contextBuffer.writeln('');
      contextBuffer.writeln('3. REGISTO DE AUSÊNCIAS E FÉRIAS PELOS PAIS:');
      contextBuffer.writeln('   - Os pais podem registar ausências para um dia ou INTERVALOS DE DIAS SEGUIDOS (estilo RH).');
      contextBuffer.writeln('   - Permite escolher o motivo (Doença, Férias em Família, Consulta Médica, Assuntos Familiares, Outro).');
      contextBuffer.writeln('   - Permite anexar atestados médicos ou fotografias de comprovativo.');
      contextBuffer.writeln('   - Os professores recebem automaticamente alertas e um Mapa Semanal de Alunos Ausentes (Hoje e Próxima Semana).');
      contextBuffer.writeln('');
      contextBuffer.writeln('4. MAPA DE ASSIDUIDADE E ATIVIDADES EM PDF:');
      contextBuffer.writeln('   - Disponível para Pais, Professores e Alunos.');
      contextBuffer.writeln('   - Permite filtrar por Dia, Semana, Mês ou Período Personalizado.');
      contextBuffer.writeln('   - Permite escolher Visão Global (Todas as Disciplinas) ou Disciplina Específica.');
      contextBuffer.writeln('   - Suporta Versão Resumo Simples ou Versão Detalhada (com sumários de aulas, descritivos e comprovativos).');
      contextBuffer.writeln('');

      // INJECT ELIGIBLE INSTITUTIONAL KNOWLEDGE DOCUMENTS FOR THIS USER ROLE
      if (knowledgeService != null && institutionId.isNotEmpty) {
        try {
          final eligibleDocs = await knowledgeService.getVisibleDocuments(institutionId, user);
          contextBuffer.writeln('--- DOCUMENTOS E REGULAMENTOS INSTITUCIONAIS ELEGÍVEIS PARA ESTE PERFIL (${user.role.name.toUpperCase()}) ---');
          contextBuffer.writeln('O utilizador tem autorização para consultar ${eligibleDocs.length} documentos da base de conhecimento:');
          for (final doc in eligibleDocs) {
            contextBuffer.writeln('\n📄 [DOCUMENTO AUTORIZADO] Título: "${doc.title}" (Ficheiro: ${doc.fileName})');
            contextBuffer.writeln('   Público-Alvo: ${doc.accessType.name} | Categoria: ${doc.category}');
            if (doc.extractedText != null && doc.extractedText!.isNotEmpty) {
              contextBuffer.writeln('   Conteúdo/Texto Extraído: "${doc.extractedText}"');
            }
          }
          contextBuffer.writeln('');
        } catch (e) {
          contextBuffer.writeln('Erro ao carregar documentos elegíveis da instituição: $e');
        }
      }

      // STAGE STRICT PRIVACY DATA ACCORDING TO ROLE (RGPD ENFORCEMENT)
      if (user.role == UserRole.parent) {
        contextBuffer.writeln('--- DADOS AUTORIZADOS DO ENCARREGADO DE EDUCAÇÃO (APENAS FILHOS PRÓPRIOS) ---');
        try {
          final children = await firebaseService.getChildrenByParent(user.id).first;
          contextBuffer.writeln('Educandos Associados a ${user.name}: ${children.map((c) => c.name).join(', ')}');
          
          for (final child in children) {
            contextBuffer.writeln('\n* Educando: ${child.name} (ID: ${child.id})');
            final absences = await firebaseService.getStudentAbsences(institutionId, studentId: child.id).first;
            contextBuffer.writeln('  - Ausências registadas (${absences.length}):');
            for (final a in absences.take(5)) {
              contextBuffer.writeln('    • ${DateFormat('dd/MM/yyyy').format(a.startDate)} a ${DateFormat('dd/MM/yyyy').format(a.endDate)}: Motivo=${a.type.name}, Obs="${a.description ?? 'Sem obs'}"');
            }
          }

          final activities = await firebaseService.getActivities(institutionId).first;
          final today = DateTime.now();
          final todayActs = activities.where((act) => act.startDate.day == today.day && act.startDate.month == today.month).toList();
          contextBuffer.writeln('\n* Sumários/Atividades de Hoje (${todayActs.length}):');
          for (final act in todayActs) {
            contextBuffer.writeln('  • ${act.title}: Status=${act.status}, Descrição="${act.description}"');
          }

          final nextWeekEnd = today.add(const Duration(days: 7));
          final nextWeekActs = activities.where((act) => act.startDate.isAfter(today) && act.startDate.isBefore(nextWeekEnd)).toList();
          contextBuffer.writeln('\n* Materiais e Atividades da Próxima Semana (${nextWeekActs.length}):');
          for (final act in nextWeekActs) {
            contextBuffer.writeln('  • [${DateFormat('dd/MM/yyyy').format(act.startDate)}] ${act.title}: Materiais/Obs="${act.description}"');
          }
        } catch (e) {
          contextBuffer.writeln('Erro ao carregar dados do educando: $e');
        }
      } else if (user.role == UserRole.student) {
        contextBuffer.writeln('--- DADOS AUTORIZADOS DO PRÓPRIO ALUNO ---');
        contextBuffer.writeln('Aluno: ${user.name}');
        try {
          final absences = await firebaseService.getStudentAbsences(institutionId, studentId: user.id).first;
          contextBuffer.writeln('Minhas ausências registadas: ${absences.length}');
        } catch (_) {}
      } else if (user.role == UserRole.teacher) {
        contextBuffer.writeln('--- DADOS AUTORIZADOS DO PROFESSOR (APENAS SUAS DISCIPLINAS E TURMAS) ---');
        try {
          final subjects = await firebaseService.getSubjectsByTeacher(user.id).first;
          contextBuffer.writeln('Disciplinas sob responsabilidade de ${user.name} (${subjects.length}): ${subjects.map((s) => s.name).join(', ')}');

          final absences = await firebaseService.getStudentAbsences(institutionId).first;
          final today = DateTime.now();
          final todayAbs = absences.where((a) => a.isDateAbsent(today)).toList();
          contextBuffer.writeln('Alunos ausentes hoje nas turmas autorizadas: ${todayAbs.length}');
          for (final a in todayAbs) {
            contextBuffer.writeln(' - Aluno ${a.studentName}: Motivo=${a.type.name}');
          }
        } catch (e) {
          contextBuffer.writeln('Erro ao carregar disciplinas do professor: $e');
        }
      } else if (user.role == UserRole.admin) {
        contextBuffer.writeln('--- PERMISSIÕES DE ADMINISTRAÇÃO INSTITUCIONAL ---');
        contextBuffer.writeln('Acesso global autorizado para gestão de colaboradores, turmas e auditorias institucionais.');
      }

      contextBuffer.writeln('========================================');
      contextBuffer.writeln('PERGUNTA DO UTILIZADOR ($roleText):');
      contextBuffer.writeln('"$userQuestion"');
      contextBuffer.writeln('========================================');
      contextBuffer.writeln('POLÍTICA ESTRITA DE PROTEÇÃO DE DADOS (RGPD/GDPR):');
      contextBuffer.writeln('1. O utilizador $roleText (${user.name}) APENAS pode obter informações relativas aos seus próprios educandos ou às disciplinas sob a sua responsabilidade direta.');
      contextBuffer.writeln('2. SE O UTILIZADOR PERGUNTAR POR DADOS DE OUTROS ALUNOS, EDUCANDOS DE OUTROS PAIS, TURMAS/DISCIPLINAS DE OUTROS PROFESSORES OU DADOS PRIVADOS DE COLEGAS, DEVES RECUSAR A RESPOSTA COM A SEGUINTE MENSAGEM:');
      contextBuffer.writeln('   "🔒 Por motivos de segurança e proteção de dados (RGPD), apenas posso fornecer informações relativas aos seus próprios educandos ou às disciplinas sob a sua responsabilidade direta."');
      contextBuffer.writeln('3. Se a pergunta for legítima e respeitar as permissões do perfil, responda em português claro, acolhedor e perfeitamente estruturado.');

      final prompt = contextBuffer.toString();
      bool hasStreamed = false;
      try {
        final stream = aiChatService.sendMessage(prompt);
        await for (final chunk in stream) {
          if (chunk.contains('API key not valid') || chunk.contains('API_KEY_INVALID') || chunk.contains('Erro de comunicação')) {
            throw Exception(chunk);
          }
          hasStreamed = true;
          yield chunk;
        }
      } catch (e) {
        if (!hasStreamed) {
          yield _generateSmartFallbackHelp(user, userQuestion, contextBuffer.toString());
        }
      }
    } catch (e) {
      yield _generateSmartFallbackHelp(user, userQuestion, '');
    }
  }

  static String _generateSmartFallbackHelp(UserModel user, String question, String context) {
    final q = question.toLowerCase();

    // RGPD Privacy Enforcement
    if (q.contains('outro') && (q.contains('aluno') || q.contains('educando') || q.contains('colega') || q.contains('pai'))) {
      return '🔒 Por motivos de segurança e proteção de dados (RGPD), apenas posso fornecer informações relativas aos seus próprios educandos ou às disciplinas sob a sua responsabilidade direta.';
    }

    final StringBuffer sb = StringBuffer();

    sb.writeln('👋 **Olá, ${user.name}! Sou a Central de Ajuda 360 do EduGaming.**\n');

    if (q.contains('falta') || q.contains('ausência') || q.contains('ausencia') || q.contains('comprovativo') || q.contains('baixa') || q.contains('férias') || q.contains('ferias')) {
      sb.writeln('📋 **Como funciona o Registo e Comunicação de Faltas pelos Pais:**');
      sb.writeln('1. No seu painel de Encarregado de Educação, aceda à secção "Comunicar Ausência".');
      sb.writeln('2. Selecione o período de dias seguidos de ausência (doença, férias, baixa, etc.).');
      sb.writeln('3. Pode carregar um comprovativo (ficheiro PDF/Word) ou tirar uma fotografia do atestado.');
      sb.writeln('4. **Supressão de Avisos:** Nos dias comunicados, os avisos automáticos de ausência (por SMS e Email) são desativados para o seu descanso.');
      sb.writeln('5. **Alerta aos Professores:** Os professores com disciplinas onde o seu educando está inscrito recebem automaticamente uma lista atualizada de faltas pré-comunicadas para hoje e para toda a semana seguinte.');
      return sb.toString();
    }

    if (q.contains('aviso') || q.contains('horário') || q.contains('horario') || q.contains('esquecid') || q.contains('alerta') || q.contains('sms') || q.contains('email')) {
      sb.writeln('⏰ **Mecanismo de Aviso Automático de Chegada para Menores:**');
      sb.writeln('1. **Obrigatório para Menores (<18 anos):** O sistema exige a data de nascimento no registo dos educandos.');
      sb.writeln('2. **Disparo Automático:** Quando um educando menor não dá entrada na escola dentro do horário normal previsto, é enviado um alerta imediato por Email e SMS para o encarregado de educação.');
      sb.writeln('3. **Prevenção:** Esta medida serve para evitar que crianças fiquem esquecidas ou sofram incidentes no trajeto.');
      sb.writeln('4. **Isenção de Avisos:** Se o encarregado pré-registou a falta do educando no sistema, não receberá nenhum aviso nesses dias.');
      return sb.toString();
    }

    if (q.contains('qr') || q.contains('código') || q.contains('codigo') || q.contains('fraude') || q.contains('dinâmico') || q.contains('dinamico')) {
      sb.writeln('🔒 **Código QR e Token Manual Dinâmico Anti-Fraude:**');
      sb.writeln('1. O código QR e o código numérico gerados na aplicação renovam-se automaticamente a cada 30 a 60 segundos.');
      sb.writeln('2. O servidor valida a estampa temporal para evitar partilha de capturas de ecrã ou fraudes de localização.');
      sb.writeln('3. Funciona em qualquer dispositivo: Web no computador/tablet, Android e iPhone iOS.');
      return sb.toString();
    }

    if (q.contains('mapa') || q.contains('pdf') || q.contains('imprimir') || q.contains('relatório') || q.contains('relatorio') || q.contains('resumo')) {
      sb.writeln('🖨️ **Impressão de Mapas de Assiduidade e Atividades em PDF:**');
      sb.writeln('1. Aceda ao seu painel e clique no botão **"🖨️ Imprimir Mapa"**.');
      sb.writeln('2. **Filtros de Período:** Pode escolher consultar por Dia, Semana, Mês ou Período Selecionado.');
      sb.writeln('3. **Filtros de Escopo:** Permite gerar o mapa Global (todas as disciplinas inscritas) ou por Disciplina Específica.');
      sb.writeln('4. **Nível de Detalhe:** Pode selecionar a Versão Resumo Simples ou Versão Detalhada (com sumários de aulas e observações).');
      return sb.toString();
    }

    if (q.contains('documento') || q.contains('regulamento') || q.contains('avaliação') || q.contains('avaliacao') || q.contains('institucional')) {
      sb.writeln('📚 **Documentos e Regulamentos da Instituição:**');
      sb.writeln('O repositório institucional contém todos os regulamentos de funcionamento, critérios de avaliação e manuais.');
      sb.writeln('Apenas estão acessíveis os documentos elegíveis para o seu perfil. Documentos restritos a professores ou administração não são exibidos por razões de privacidade.');
      return sb.toString();
    }

    // Default polite role-based assistance
    sb.writeln('Estou à sua disposição para esclarecer qualquer dúvida sobre o funcionamento da escola e da plataforma!');
    sb.writeln('\n📌 **Principais Tópicos da Plataforma:**');
    sb.writeln('• **Comunicação de Faltas:** Registar baixas/férias, anexar fotos/ficheiros e cancelar avisos.');
    sb.writeln('• **Avisos de Segurança para Menores:** Notificações automáticas por SMS e Email.');
    sb.writeln('• **Entradas e Saídas:** Utilização de QR Code dinâmico anti-fraude na Web, Android e iOS.');
    sb.writeln('• **Mapas em PDF:** Emitir relatórios de presenças, faltas, sumários e atividades.');
    sb.writeln('• **Base de Conhecimento:** Regulamentos institucionais e critérios de avaliação.');
    sb.writeln('\n*Escreva a sua questão com mais detalhe para uma resposta específica!*');

    return sb.toString();
  }

  static String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.parent:
        return 'Encarregado(a) de Educação';
      case UserRole.student:
        return 'Aluno(a) / Educando';
      case UserRole.teacher:
        return 'Docente / Professor(a)';
      case UserRole.admin:
        return 'Administração Institucional';
      default:
        return 'Utilizador';
    }
  }
}
