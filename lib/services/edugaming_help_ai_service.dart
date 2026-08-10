import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/ai_chat_service.dart';

class EduGamingHelpAiService {
  /// Builds complete live data context for the user role and queries Gemini AI
  static Stream<String> askHelp({
    required UserModel user,
    required String userQuestion,
    required FirebaseService firebaseService,
    required AiChatService aiChatService,
  }) async* {
    try {
      final institutionId = user.institutionId ?? '';
      final roleText = _getRoleText(user.role);

      // Build Dynamic Platform & Real-Time Context
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

      // Inject Real-Time Firestore Data based on User Role
      if (user.role == UserRole.parent || user.role == UserRole.student) {
        contextBuffer.writeln('--- DADOS EM TEMPO REAL DO EDUCANDO / ALUNO ---');
        try {
          final absences = await firebaseService.getStudentAbsences(institutionId, studentId: user.id).first;
          contextBuffer.writeln('Total de ausências registadas: ${absences.length}');
          for (final a in absences.take(5)) {
            contextBuffer.writeln(' - Ausência de ${DateFormat('dd/MM/yyyy').format(a.startDate)} a ${DateFormat('dd/MM/yyyy').format(a.endDate)}: Motivo=${a.type.name}, Obs="${a.description ?? 'Sem obs'}"');
          }
        } catch (_) {}

        try {
          final activities = await firebaseService.getActivities(institutionId).first;
          contextBuffer.writeln('Total de atividades/aulas registadas: ${activities.length}');
          final today = DateTime.now();
          final todayActs = activities.where((act) => act.startDate.day == today.day && act.startDate.month == today.month).toList();
          contextBuffer.writeln('Sumários/Atividades de Hoje (${todayActs.length}):');
          for (final act in todayActs) {
            contextBuffer.writeln(' * ${act.title}: Status=${act.status}, Descrição="${act.description}"');
          }

          final nextWeekEnd = today.add(const Duration(days: 7));
          final nextWeekActs = activities.where((act) => act.startDate.isAfter(today) && act.startDate.isBefore(nextWeekEnd)).toList();
          contextBuffer.writeln('Atividades e Materiais da Próxima Semana (${nextWeekActs.length}):');
          for (final act in nextWeekActs) {
            contextBuffer.writeln(' * [${DateFormat('dd/MM/yyyy').format(act.startDate)}] ${act.title}: Materiais/Obs="${act.description}"');
          }
        } catch (_) {}
      } else if (user.role == UserRole.teacher) {
        contextBuffer.writeln('--- DADOS EM TEMPO REAL DO PROFESSOR ---');
        try {
          final subjects = await firebaseService.getSubjectsByTeacher(user.id).first;
          contextBuffer.writeln('As minhas disciplinas (${subjects.length}): ${subjects.map((s) => s.name).join(', ')}');
        } catch (_) {}

        try {
          final absences = await firebaseService.getStudentAbsences(institutionId).first;
          final today = DateTime.now();
          final todayAbs = absences.where((a) => a.isDateAbsent(today)).toList();
          contextBuffer.writeln('Alunos ausentes hoje na instituição: ${todayAbs.length}');
          for (final a in todayAbs) {
            contextBuffer.writeln(' - Aluno ${a.studentName}: Encarregado=${a.parentName}, Motivo=${a.type.name}');
          }
        } catch (_) {}
      }

      contextBuffer.writeln('========================================');
      contextBuffer.writeln('PERGUNTA DO UTILIZADOR ($roleText):');
      contextBuffer.writeln('"$userQuestion"');
      contextBuffer.writeln('========================================');
      contextBuffer.writeln('INSTRUÇÕES DE RESPOSTA PARA A INTELIGÊNCIA ARTIFICIAL:');
      contextBuffer.writeln('Responda sempre em português claro, profissional, acolhedor e perfeitamente estruturado.');
      contextBuffer.writeln('Se a pergunta for sobre dados do educando (sumários de hoje, materiais para a próxima semana, faltas da professora ou comportamento), consulte e apresente com exatidão os dados do contexto real acima.');
      contextBuffer.writeln('Se a pergunta for sobre o funcionamento da plataforma (QR codes, ausências de vários dias, avisos aos pais, PDFs), explique o mecanismo passo-a-passo.');

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
