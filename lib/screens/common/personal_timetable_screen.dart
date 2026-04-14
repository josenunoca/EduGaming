import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/facility_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class PersonalTimetableScreen extends StatelessWidget {
  const PersonalTimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final currentUser = service.currentUser;

    if (currentUser == null) return const Scaffold(body: Center(child: Text('User not found')));

    return StreamBuilder<UserModel?>(
      stream: service.getUserStream(currentUser.uid),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = userSnapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const AiTranslatedText('O Meu Horário Semanal'),
            actions: [
              IconButton(
                onPressed: () => _printTimetable(context),
                icon: const Icon(Icons.print),
                tooltip: 'Imprimir Horário',
              ),
            ],
          ),
          body: StreamBuilder<List<TimetableEntry>>(
            stream: service.getTimetableForUser(user.id, user.role),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final entries = snapshot.data!;

              return _buildTimetableGrid(entries);
            },
          ),
        );
      },
    );
  }

  Widget _buildTimetableGrid(List<TimetableEntry> entries) {
    final days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 80), // Time column spacer
                ...days.map((d) => Container(
                  width: 150,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: AiTranslatedText(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
            const Divider(color: Colors.white10),
            ...List.generate(12, (index) {
              final hour = 8 + index;
              final timeStr = '${hour.toString().padLeft(2, '0')}:00';
              
              return Row(
                children: [
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  ...List.generate(6, (dayIndex) {
                    final day = dayIndex + 1;
                    final entry = entries.firstWhere(
                      (e) => e.weekday == day && e.startTime.startsWith(timeStr.substring(0, 2)),
                      orElse: () => TimetableEntry(id: '', weekday: 0, startTime: '', institutionId: ''),
                    );

                    return Container(
                      width: 150,
                      height: 80,
                      margin: const EdgeInsets.all(2),
                      child: entry.id.isNotEmpty 
                        ? GlassCard(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(entry.subjectId ?? '', // In real app, resolve subject name
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(entry.classroomId ?? '', // Resolve room name
                                      style: const TextStyle(color: Colors.white54, fontSize: 8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.01)))),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _printTimetable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A preparar versão para impressão...')),
    );
    // Future: Use pdf package to generate printable timetable
  }
}
