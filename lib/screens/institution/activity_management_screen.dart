import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'activity_details_screen.dart';
import 'activity_report_screen.dart';

class ActivityManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const ActivityManagementScreen({super.key, required this.institution});

  @override
  State<ActivityManagementScreen> createState() => _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Gestão de Atividades'),
        actions: [
          StreamBuilder<List<InstitutionalActivity>>(
            stream: context.read<FirebaseService>().getActivities(widget.institution.id),
            builder: (context, snapshot) {
              final activities = snapshot.data ?? [];
              return IconButton(
                icon: const Icon(Icons.analytics),
                tooltip: 'Gerar Relatório Anual',
                onPressed: activities.isEmpty ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityReportScreen(activities: activities),
                    ),
                  );
                },
              );
            }
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(onAdd: () => _showCreateActivityDialog(context)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<InstitutionalActivity>>(
                stream: service.getActivities(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final activities = snapshot.data!;
                  if (activities.isEmpty) {
                    return const Center(
                      child: AiTranslatedText('Nenhuma atividade planeada.', 
                        style: TextStyle(color: Colors.white54))
                    );
                  }

                  return ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) => _ActivityCard(
                      activity: activities[index],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivityDetailsScreen(
                            activity: activities[index],
                            institution: widget.institution,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Plano de Atividades',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            AiTranslatedText(
              'Ano Letivo ${DateTime.now().year}/${DateTime.now().year + 1}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const AiTranslatedText('Nova Atividade'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B61FF),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showCreateActivityDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Planear Atividade', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título da Atividade',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Descrição/Objetivos',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const AiTranslatedText('Data Início', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  subtitle: Text("${startDate.day}/${startDate.month}/${startDate.year}", 
                    style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setDialogState(() => startDate = date);
                  },
                ),
                ListTile(
                  title: const AiTranslatedText('Data Fim', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  subtitle: Text("${endDate.day}/${endDate.month}/${endDate.year}", 
                    style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setDialogState(() => endDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                final activity = InstitutionalActivity(
                  id: const Uuid().v4(),
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  institutionId: widget.institution.id,
                  startDate: startDate,
                  endDate: endDate,
                  startTime: '09:00',
                  endTime: '17:00',
                );
                await context.read<FirebaseService>().saveActivity(activity);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const AiTranslatedText('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final InstitutionalActivity activity;
  final VoidCallback onTap;
  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24.0),
        child: GlassCard(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B61FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available, color: Color(0xFF7B61FF)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      "${activity.startDate.day}/${activity.startDate.month} - ${activity.endDate.day}/${activity.endDate.month}",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
