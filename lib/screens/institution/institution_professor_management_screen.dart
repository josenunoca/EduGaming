import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class InstitutionProfessorManagementScreen extends StatelessWidget {
  final InstitutionModel institution;
  const InstitutionProfessorManagementScreen(
      {super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Professores - ${institution.name}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProfessorDialog(context),
        label: const AiTranslatedText('Adicionar Professor'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF7B61FF),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: service.getUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allUsers = snapshot.data ?? [];
          final professors = allUsers
              .where((u) =>
                  (u.role == UserRole.teacher || u.role == UserRole.courseCoordinator) &&
                  institution.authorizedProfessorIds.contains(u.id))
              .toList();

          if (professors.isEmpty) {
            return const Center(
              child: AiTranslatedText('Nenhum professor vinculado.',
                  style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: professors.length,
            itemBuilder: (context, index) {
              final professor = professors[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF7B61FF),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: AiTranslatedText(professor.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14)),
                      subtitle: Text(professor.email,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white70, size: 20),
                            onPressed: () =>
                                _showEditProfessorDialog(context, professor),
                            tooltip: 'Editar Professor',
                          ),
                          const VerticalDivider(
                              color: Colors.white10, indent: 10, endIndent: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AiTranslatedText('Acesso',
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.white70)),
                              SizedBox(
                                height: 32,
                                child: Transform.scale(
                                  scale: 0.7,
                                  child: Switch(
                                    value: !professor.isSuspended,
                                    onChanged: (val) => service
                                        .toggleUserSuspension(professor.id, !val),
                                    activeThumbColor: Colors.green,
                                    activeTrackColor:
                                        Colors.green.withValues(alpha: 0.3),
                                    inactiveThumbColor: Colors.red,
                                    inactiveTrackColor:
                                        Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditProfessorDialog(BuildContext context, UserModel professor) {
    final nameController = TextEditingController(text: professor.name);
    final emailController = TextEditingController(text: professor.email);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Editar Professor',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome do Professor',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AiTranslatedText('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                return;
              }
              final service = context.read<FirebaseService>();
              await service.updateUserProfile(professor.id, {
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
              });
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Dados atualizados com sucesso!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF)),
            child: const AiTranslatedText('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAddProfessorDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Novo Professor',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome do Professor',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AiTranslatedText('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                return;
              }
              final service = context.read<FirebaseService>();
              await service.addProfessorByEmail(
                nameController.text.trim(),
                emailController.text.trim(),
                institution.id,
              );
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Professor adicionado com sucesso!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
            child: const AiTranslatedText('Adicionar'),
          ),
        ],
      ),
    );
  }
}
