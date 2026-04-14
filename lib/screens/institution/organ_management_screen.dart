import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/institutional_organ_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/institution_member_selector.dart';
import '../../widgets/custom_button.dart';

class OrganManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const OrganManagementScreen({super.key, required this.institution});

  @override
  State<OrganManagementScreen> createState() => _OrganManagementScreenState();
}

class _OrganManagementScreenState extends State<OrganManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Órgãos e Atas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(onAdd: () => _showAddOrganDialog(context)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<InstitutionalOrgan>>(
                stream: service.getOrgans(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final organs = snapshot.data!;
                  if (organs.isEmpty) return const Center(child: AiTranslatedText('Nenhum órgão criado.', style: TextStyle(color: Colors.white54)));

                  return ListView.builder(
                    itemCount: organs.length,
                    itemBuilder: (context, index) => _OrganCard(organ: organs[index]),
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
        const AiTranslatedText(
          'Órgãos Sociais',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        CustomButton(
          onPressed: onAdd,
          icon: Icons.add,
          label: 'Novo Órgão',
        ),
      ],
    );
  }

  void _showAddOrganDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Criar Órgão Institucional', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nome (ex: Conselho Pedagógico)', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Descrição', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          CustomButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final organ = InstitutionalOrgan(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                institutionId: widget.institution.id,
                description: descController.text.trim(),
              );
              await context.read<FirebaseService>().saveOrgan(organ);
              if (mounted) Navigator.pop(ctx);
            },
            label: 'Criar',
          ),
        ],
      ),
    );
  }
}

class _OrganCard extends StatelessWidget {
  final InstitutionalOrgan organ;
  const _OrganCard({required this.organ});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: ExpansionTile(
          collapsedIconColor: Colors.white,
          iconColor: const Color(0xFF7B61FF),
          title: Text(organ.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(organ.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AiTranslatedText('${organ.members.length} Membros', style: const TextStyle(color: Colors.white70)),
                      TextButton.icon(
                        onPressed: () => _showAddMemberDialog(context),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const AiTranslatedText('Convidar'),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  ...organ.members.map((m) => ListTile(
                    dense: true,
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1E293B), child: Icon(Icons.person, size: 16, color: Colors.white54)),
                    title: Text(m.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                        '${m.function ?? "Membro"} • ${m.email}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      onPressed: () => _showMinutesDialog(context),
                      icon: Icons.article,
                      label: 'Gerar Atas (IA)',
                      variant: CustomButtonVariant.secondary,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    List<UserModel> selectedMembers = [];
    String selectedFunction = 'Membro';
    final functions = [
      'Presidente',
      'Vice-Presidente',
      'Secretário',
      'Vogal',
      'Membro',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Convidar Membros',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFunction,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Função / Cargo',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                items: functions
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: AiTranslatedText(f),
                        ))
                    .toList(),
                onChanged: (val) => setModalState(() => selectedFunction = val!),
              ),
              const SizedBox(height: 16),
              InstitutionMemberSelector(
                institutionId: organ.institutionId,
                onSelectionChanged: (users) => selectedMembers = users,
              ),
              const SizedBox(height: 24),
               CustomButton(
                onPressed: () async {
                  final service = context.read<FirebaseService>();
                  for (var user in selectedMembers) {
                    await service.inviteMemberToOrgan(
                      organ.id,
                      OrganMember(
                        userId: user.id,
                        name: user.name,
                        email: user.email,
                        function: selectedFunction,
                      ),
                    );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                label: 'Confirmar Convites',
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMinutesDialog(BuildContext context) {
    final transcriptionController = TextEditingController();
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Gerar Ata com IA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const AiTranslatedText(
                  'Transcreva ou cole as notas da reunião para que a IA possa gerar uma ata estruturada.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: transcriptionController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Ex: Discutimos o orçamento de 2024...',
                    hintStyle: TextStyle(color: Colors.white24)),
              ),
              const SizedBox(height: 24),
              isGenerating
                  ? const CircularProgressIndicator()
                  : CustomButton(
                      onPressed: () async {
                        if (transcriptionController.text.isEmpty) return;
                        setModalState(() => isGenerating = true);
                        try {
                          final service = context.read<FirebaseService>();
                          final minuteText = await service.generateAiMinute(
                              transcriptionController.text);

                          // Save the minute document
                          final minute = MeetingMinute(
                            id: const Uuid().v4(),
                            organId: organ.id,
                            title: 'Ata - ${DateTime.now().toIso8601String().substring(0, 10)}',
                            generatedText: minuteText,
                            rawTranscription: transcriptionController.text,
                            date: DateTime.now(),
                          );
                          await service.saveMinute(minute);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        AiTranslatedText('Ata gerada e guardada com sucesso!')));
                          }
                        } finally {
                          if (context.mounted) setModalState(() => isGenerating = false);
                        }
                      },
                      icon: Icons.auto_awesome,
                      label: 'Gerar Ata',
                      isFullWidth: true,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
