import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/institutional_service.dart';
import '../models/institution_organ_model.dart';
import '../models/user_model.dart';
import '../screens/institutional/meeting_recording_screen.dart';
import 'glass_card.dart';
import 'ai_translated_text.dart';

class UserNoticesWidget extends StatelessWidget {
  final UserModel user;

  const UserNoticesWidget({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.institutionId == null) return const SizedBox.shrink();

    final instService =
        Provider.of<InstitutionalService>(context, listen: false);

    return StreamBuilder<List<Meeting>>(
      stream: instService.getActiveMeetingsStream(user.institutionId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        // Filter meetings where the user is a participant
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
                'Convocatórias e Reuniões Ativas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ...activeNotices
                .map((meeting) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingRecordingScreen(
                                meeting: meeting,
                                canManage: false,
                              ),
                            ),
                          );
                        },
                        child: GlassCard(
                          child: ListTile(
                            leading: const Icon(Icons.meeting_room,
                                color: Color(0xFF00D1FF)),
                            title: Text(
                              meeting.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Data: ${meeting.date.day}/${meeting.date.month}/${meeting.date.year} | Local: ${meeting.location ?? "N/A"}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: meeting.status == 'ongoing'
                                    ? Colors.green
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meeting.status == 'ongoing'
                                    ? 'A Decorrer'
                                    : 'Agendada',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
