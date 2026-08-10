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
      final stream = aiChatService.sendMessage(prompt);
      await for (final chunk in stream) {
        yield chunk;
      }
    } catch (e) {
      yield 'Ocorreu um erro ao consultar o assistente de ajuda: $e';
    }
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
