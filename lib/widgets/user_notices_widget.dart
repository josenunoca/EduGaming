import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/institutional_service.dart';
import '../services/firebase_service.dart';
import '../models/institution_organ_model.dart';
import '../models/user_model.dart';
import '../models/questionnaire_model.dart';
import '../models/internal_message.dart';
import '../models/meeting_model.dart';
import '../models/agenda_item_model.dart';
import '../screens/common/unified_agenda_screen.dart';
import '../screens/common/communication_center_screen.dart';
import '../screens/institutional/meeting_recording_screen.dart';
import 'glass_card.dart';
import 'ai_translated_text.dart';
import 'survey_runner_widget.dart';

class UserNoticesWidget extends StatelessWidget {
  final UserModel user;

  const UserNoticesWidget({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.institutionId == null) return const SizedBox.shrink();

    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final service = Provider.of<FirebaseService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Agenda Summary (Compliance)
        StreamBuilder<List<AgendaItem>>(
          stream: service.getUnifiedAgendaStream(
              user.id, user.email, user.role, user.institutionId ?? ''),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox.shrink();

            final overdue = items.where((i) => i.isOverdue).toList();
            final upcoming = items
                .where((i) =>
                    !i.isOverdue &&
                    i.status != AgendaItemStatus.completed &&
                    i.dueDate.difference(DateTime.now()).inDays <= 14) // Increased to 14 days
                .toList();
            
            // Also grab pending items that are further out just to show the card if it's the only thing pending
            final anyPending = items.where((i) => i.status != AgendaItemStatus.completed).toList();

            if (overdue.isEmpty && upcoming.isEmpty && anyPending.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlassCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UnifiedAgendaScreen(user: user)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (overdue.isNotEmpty) ...[
                        _buildCompactAgendaSection(
                            context, 'EM ATRASO', overdue.take(3).toList(), Colors.redAccent),
                        if (upcoming.isNotEmpty) const SizedBox(height: 12),
                      ],
                      if (upcoming.isNotEmpty)
                        _buildCompactAgendaSection(
                            context, 'PRÓXIMOS PRAZOS', upcoming.take(3).toList(), const Color(0xFF00D1FF)),
                      if (upcoming.isEmpty && overdue.isEmpty && anyPending.isNotEmpty)
                         _buildCompactAgendaSection(
                            context, 'TAREFAS PENDENTES', anyPending.take(3).toList(), Colors.white54),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 2. Academic Alerts (from Coordinator)
        StreamBuilder<List<InternalMessage>>(
          stream: service.getMessagesByCategory(user.id, 'academic_alert'),
          builder: (context, snapshot) {
            final alerts = snapshot.data ?? [];
            if (alerts.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GlassCard(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    title: Text(alert.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(alert.body, maxLines: 1, overflow: TextOverflow.ellipsis, 
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CommunicationCenterScreen())
                      );
                    },
                  ),
                ),
              )).toList(),
            );
          },
        ),

        // 3. Existing Meetings Notice
        StreamBuilder<List<Meeting>>(
          stream: instService.getActiveMeetingsStream(user.institutionId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final activeNotices = snapshot.data!.where((m) {
              final isParticipant = m.participants
                  .any((p) => p.email.toLowerCase() == user.email.toLowerCase());
              return isParticipant;
            }).toList();

            if (activeNotices.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: AiTranslatedText(
                    'Reuniões e Convocatórias',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                ...activeNotices.map((meeting) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeetingRecordingScreen(meeting: meeting, canManage: false),
                      ),
                    ),
                    child: GlassCard(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room, color: Color(0xFF00D1FF)),
                        title: Text(meeting.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${meeting.date.day}/${meeting.date.month} | ${meeting.location ?? "N/A"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        trailing: _buildStatusBadge(meeting.status),
                      ),
                    ),
                  ),
                )),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactAgendaSection(
      BuildContext context, String title, List<AgendaItem> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 6, color: color),
            const SizedBox(width: 8),
            AiTranslatedText(title,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildCompactAgendaItem(context, item, color)),
      ],
    );
  }

  Widget _buildCompactAgendaItem(BuildContext context, AgendaItem item, Color color) {
    final now = DateTime.now();
    final isToday = item.dueDate.year == now.year &&
        item.dueDate.month == now.month &&
        item.dueDate.day == now.day;
    final isTomorrow = item.dueDate.year == now.year &&
        item.dueDate.month == now.month &&
        item.dueDate.day == now.day + 1;

    String dateStr;
    if (isToday) {
      dateStr = 'Hoje';
    } else if (isTomorrow) {
      dateStr = 'Amanhã';
    } else {
      dateStr = DateFormat('dd MMM').format(item.dueDate);
    }

    IconData icon;
    switch (item.type) {
      case AgendaItemType.assignment:
        icon = Icons.assignment_outlined;
        break;
      case AgendaItemType.questionnaire:
        icon = Icons.quiz_outlined;
        break;
      case AgendaItemType.deadline:
        icon = Icons.gavel_rounded;
        break;
      case AgendaItemType.activity:
        icon = Icons.event;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          if (item.type == AgendaItemType.questionnaire && item.relatedId != null) {
            final service = context.read<FirebaseService>();
            final q = await service.getQuestionnaireById(item.relatedId!);
            if (q != null && context.mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SurveyRunnerWidget(q: q, userId: service.currentUser!.uid),
              );
            }
          } else {
            // Navigate to main agenda screen for other types
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnifiedAgendaScreen(user: user),
              ),
            );
          }
        },
        child: Row(
          children: [
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: AiTranslatedText(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            AiTranslatedText(
              dateStr,
              style: TextStyle(
                  color: item.isOverdue ? Colors.redAccent : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'ongoing' ? Colors.green : Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'ongoing' ? 'A Decorrer' : 'Agendada',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
