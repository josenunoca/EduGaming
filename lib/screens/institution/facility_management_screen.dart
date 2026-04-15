import 'package:flutter/material.dart';
import 'timetable_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/facility_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class FacilityManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const FacilityManagementScreen({super.key, required this.institution});

  @override
  State<FacilityManagementScreen> createState() =>
      _FacilityManagementScreenState();
}

class _FacilityManagementScreenState extends State<FacilityManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Espaços e Horários'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(onAdd: () => _showAddClassroomDialog(context)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Classroom>>(
                stream: service.getClassrooms(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final rooms = snapshot.data!;
                  if (rooms.isEmpty)
                    return const Center(
                        child: AiTranslatedText('Nenhuma sala cadastrada.',
                            style: TextStyle(color: Colors.white54)));

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.2),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) =>
                        _ClassroomCard(room: rooms[index]),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Horários Globais',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                CustomButton(
                  onPressed: () => _showTimetableBuilder(context),
                  label: 'Gerir Horários',
                  variant: CustomButtonVariant.secondary,
                  height: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: Center(
                child: AiTranslatedText(
                    'A selecionar sala para visualizar horário...',
                    style: TextStyle(color: Colors.white24)),
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
        const AiTranslatedText('Salas de Aula',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_business, color: Color(0xFFFFB800))),
      ],
    );
  }

  void _showAddClassroomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final capController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Nova Sala/Espaço',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Identificação (ex: Sala 102)',
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Capacidade',
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AiTranslatedText('Cancelar')),
          CustomButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final room = Classroom(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                institutionId: widget.institution.id,
                capacity: int.tryParse(capController.text) ?? 30,
              );
              await context.read<FirebaseService>().saveClassroom(room);
              if (mounted) Navigator.pop(ctx);
            },
            label: 'Salvar',
            height: 36,
          ),
        ],
      ),
    );
  }

  void _showTimetableBuilder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TimetableManagementScreen(institution: widget.institution),
      ),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  final Classroom room;
  const _ClassroomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.room, color: Color(0xFFFFB800), size: 16),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(room.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            AiTranslatedText('Capacidade: ${room.capacity}',
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.calendar_today,
                  size: 14, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }
}
