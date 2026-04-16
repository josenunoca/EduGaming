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
import 'package:image_picker/image_picker.dart';
import '../../models/subject_model.dart';

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
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rooms = snapshot.data!;
                  if (rooms.isEmpty) {
                    return const Center(
                        child: AiTranslatedText('Nenhuma sala cadastrada.',
                            style: TextStyle(color: Colors.white54)));
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2), // Wider for activity list
                    itemCount: rooms.length,
                    itemBuilder: (context, index) =>
                        _ClassroomCard(room: rooms[index], institutionId: widget.institution.id),
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
              if (!context.mounted) return;
              await context.read<FirebaseService>().saveClassroom(room);
              if (ctx.mounted) Navigator.pop(ctx);
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
  final String institutionId;
  const _ClassroomCard({required this.room, required this.institutionId});

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final bytes = await image.readAsBytes();
      final service = context.read<FirebaseService>();
      
      messenger.showSnackBar(
        const SnackBar(content: AiTranslatedText('A carregar imagem...'))
      );
      
      final url = await service.uploadClassroomImage(room.id, bytes);
      
      if (url != null) {
        messenger.showSnackBar(
          const SnackBar(content: AiTranslatedText('Imagem atualizada com sucesso!'))
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: AiTranslatedText('Erro ao carregar imagem.'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final weekday = DateTime.now().weekday;

    return GlassCard(
      child: Stack(
        children: [
          // Background Image
          if (room.imageUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    room.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Left Side: Name and Photo Button
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.room, color: Color(0xFFFFB800), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.name,
                              style: const TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capacidade: ${room.capacity}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: () => _pickAndUploadImage(context),
                        icon: const Icon(Icons.camera_alt, color: Colors.white38, size: 20),
                        tooltip: 'Carregar Foto',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                const VerticalDivider(color: Colors.white10, width: 24),
                
                // Right Side: Today's Activities
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: AiTranslatedText(
                          'Atividades de Hoje',
                          style: TextStyle(
                              color: Color(0xFFFFB800), 
                              fontSize: 9, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: StreamBuilder<List<TimetableEntry>>(
                          stream: service.getTimetableEntriesStream(
                            institutionId: institutionId,
                            classroomId: room.id,
                            weekday: weekday,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final entries = snapshot.data!;
                            
                            if (entries.isEmpty) {
                              return const Center(
                                child: AiTranslatedText(
                                  'Livre hoje',
                                  style: TextStyle(color: Colors.white24, fontSize: 10),
                                ),
                              );
                            }
                            
                            // Sort by time
                            entries.sort((a, b) => a.startTime.compareTo(b.startTime));

                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              itemBuilder: (context, i) {
                                final entry = entries[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        entry.startTime,
                                        style: const TextStyle(
                                            color: Colors.white70, 
                                            fontSize: 9,
                                            fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: entry.customActivityName != null 
                                          ? Text(
                                              entry.customActivityName!,
                                              style: const TextStyle(color: Colors.white, fontSize: 10),
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : FutureBuilder<Subject?>(
                                              future: entry.subjectId != null 
                                                ? service.getSubject(entry.subjectId!)
                                                : Future.value(null),
                                              builder: (context, subSnap) {
                                                return Text(
                                                  subSnap.data?.name ?? 'Carregar...',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                                  overflow: TextOverflow.ellipsis,
                                                );
                                              },
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
