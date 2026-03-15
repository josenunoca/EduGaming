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
                  u.role == UserRole.teacher &&
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
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF7B61FF),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: AiTranslatedText(professor.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(professor.email,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AiTranslatedText('Acesso Plataforma',
                            style:
                                TextStyle(fontSize: 10, color: Colors.white70)),
                        Switch(
                          value: !professor.isSuspended,
                          onChanged: (val) =>
                              service.toggleUserSuspension(professor.id, !val),
                          activeThumbColor: Colors.green,
                          activeTrackColor: Colors.green.withValues(alpha: 0.3),
                          inactiveThumbColor: Colors.red,
                          inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                        ),
                      ],
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
