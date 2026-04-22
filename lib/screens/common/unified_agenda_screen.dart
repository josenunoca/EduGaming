import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/agenda_item_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/survey_runner_widget.dart';
import '../../models/questionnaire_model.dart';

class UnifiedAgendaScreen extends StatelessWidget {
  final UserModel? user;
  const UnifiedAgendaScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    final authUser = service.currentUser;

    if (authUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<UserModel?>(
      stream: user != null ? Stream.value(user) : service.getUserStream(authUser.uid),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final userModel = userSnap.data!;
        
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const AiTranslatedText('A Minha Agenda & Prazos'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: StreamBuilder<List<AgendaItem>>(
            stream: service.getUnifiedAgendaStream(authUser.uid, userModel.email, userModel.role, userModel.institutionId ?? ''),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      AiTranslatedText('Não existem tarefas ou prazos pendentes.', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                );
              }

              final now = DateTime.now();
              final overdue = items.where((i) => i.dueDate.isBefore(now) && i.status != AgendaItemStatus.completed).toList();
              final upcoming = items.where((i) => !i.dueDate.isBefore(now) || i.status == AgendaItemStatus.completed).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (overdue.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: AiTranslatedText('Fora de Prazo', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    ...overdue.map((item) => _AgendaItemCard(item: item)),
                    const SizedBox(height: 24),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AiTranslatedText('Próximos Compromissos', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  ...upcoming.map((item) => _AgendaItemCard(item: item)),
                ],
              );
            },
          ),
        );
      }
    );
  }
}

class _AgendaItemCard extends StatelessWidget {
  final AgendaItem item;

  const _AgendaItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    final isOverdue = item.isOverdue;
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildIcon(),
        title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty)
              Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: isOverdue ? Colors.redAccent : Colors.white24),
                const SizedBox(width: 4),
                Text(
                  'Até: ${dateFormat.format(item.dueDate)}',
                  style: TextStyle(color: isOverdue ? Colors.redAccent : Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: _buildStatusBadge(),
        onTap: () async {
          if (item.type == AgendaItemType.questionnaire && item.relatedId != null) {
             final service = context.read<FirebaseService>();
             // Simple feedback while loading
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: AiTranslatedText('A carregar inquérito...'), duration: Duration(seconds: 1)),
             );
             
             final q = await service.getQuestionnaireById(item.relatedId!);
             if (q != null && context.mounted) {
               showModalBottomSheet(
                 context: context,
                 isScrollControlled: true,
                 backgroundColor: Colors.transparent,
                 builder: (context) => SurveyRunnerWidget(q: q, userId: service.currentUser!.uid),
               );
             }
          }
        },
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;
    switch (item.type) {
      case AgendaItemType.assignment:
        icon = Icons.assignment;
        color = Colors.orange;
        break;
      case AgendaItemType.questionnaire:
        icon = Icons.quiz;
        color = Colors.blue;
        break;
      case AgendaItemType.deadline:
        icon = Icons.notification_important;
        color = Colors.red;
        break;
      case AgendaItemType.activity:
        icon = Icons.event;
        color = Colors.green;
        break;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusBadge() {
    if (item.status == AgendaItemStatus.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.check, color: Colors.green, size: 14),
      );
    }
    if (item.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: const Text('ATRASO', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    return const Icon(Icons.chevron_right, color: Colors.white24);
  }
}
