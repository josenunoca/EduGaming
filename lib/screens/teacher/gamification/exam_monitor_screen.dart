import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/subject_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class ExamMonitorScreen extends StatelessWidget {
  final Subject subject;

  const ExamMonitorScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AiTranslatedText('Monitorização: ${subject.name}', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<ExamSession>>(
        stream: context.read<FirebaseService>().streamActiveExamSessions(subject.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monitor_heart_outlined, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  AiTranslatedText('Nenhuma sessão de exame ativa', 
                    style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;
          // Sort: abandoned first, then active, then completed
          sessions.sort((a, b) {
            if (a.status == b.status) return b.lastHeartbeat.compareTo(a.lastHeartbeat);
            if (a.status == 'abandoned') return -1;
            if (b.status == 'abandoned') return 1;
            if (a.status == 'active') return -1;
            return 1;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isTimeOut = DateTime.now().difference(session.lastHeartbeat).inSeconds > 30;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GlassCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(session.studentName, 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        _buildStatusBadge(session.status, isTimeOut),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.quiz, color: Colors.blueAccent, size: 14),
                            const SizedBox(width: 4),
                            AiTranslatedText('Pergunta: ${session.currentQuestionIndex + 1}', 
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 16),
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('${session.currentScore.toStringAsFixed(1)} pts', 
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Última atividade: ${session.lastHeartbeat.hour.toString().padLeft(2, '0')}:${session.lastHeartbeat.minute.toString().padLeft(2, '0')}:${session.lastHeartbeat.second.toString().padLeft(2, '0')}',
                          style: TextStyle(color: isTimeOut ? Colors.redAccent : Colors.white24, fontSize: 11)),
                      ],
                    ),
                    trailing: session.status == 'abandoned' && !session.authorizedReentry
                      ? ElevatedButton(
                          onPressed: () => _authorizeReentry(context, session),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          child: const AiTranslatedText('Autorizar'),
                        ).animate().shake()
                      : session.authorizedReentry 
                        ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isTimeOut) {
    Color color;
    String text;
    
    switch (status) {
      case 'active':
        color = isTimeOut ? Colors.orange : Colors.blueAccent;
        text = isTimeOut ? 'Inativo' : 'Ativo';
        break;
      case 'abandoned':
        color = Colors.redAccent;
        text = 'Abandonado';
        break;
      case 'completed':
        color = Colors.greenAccent;
        text = 'Concluído';
        break;
      default:
        color = Colors.white24;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: AiTranslatedText(text, 
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _authorizeReentry(BuildContext context, ExamSession session) async {
    try {
      await context.read<FirebaseService>().authorizeExamReentry(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AiTranslatedText('Reentrada autorizada para ${session.studentName}'))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'))
        );
      }
    }
  }
}
