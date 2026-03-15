import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/messaging_badge.dart';
import '../../widgets/glass_card.dart';
import '../common/communication_center_screen.dart';
import '../student/student_dashboard.dart';
import '../student/subject_selection_screen.dart';
import '../login_screen.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Painel de Encarregado'),
        actions: [
          MessagingBadge(
            icon: const Icon(Icons.mail),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CommunicationCenterScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: service.getUserStream(currentUserId),
        builder: (context, parentSnap) {
          final parent = parentSnap.data;
          if (parentSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (parent == null) {
            return const Center(
                child: AiTranslatedText('Utilizador não encontrado'));
          }

          if (parent.isSuspended) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_person, size: 80, color: Colors.red),
                    SizedBox(height: 24),
                    AiTranslatedText(
                      'O seu acesso está suspenso.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    AiTranslatedText(
                      'Esta suspensão foi aplicada pela Administração Global.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: StreamBuilder<List<UserModel>>(
              stream: service.getChildrenByParent(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final children = snapshot.data ?? [];

                if (children.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.family_restroom,
                            size: 64, color: Colors.orange),
                        SizedBox(height: 16),
                        AiTranslatedText(
                          'Acompanhamento de Alunos',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        AiTranslatedText(
                          'Ainda não registou nenhum dependente.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final child = children[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF7B61FF),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(child.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: FutureBuilder<List<InstitutionModel>>(
                                  future: service.getInstitutions().first,
                                  builder: (context, snapshot) {
                                    final institutions = snapshot.data ?? [];
                                    final inst = institutions.firstWhere(
                                      (i) => i.id == child.institutionId,
                                      orElse: () => InstitutionModel(
                                        id: '',
                                        name: 'Não definida',
                                        email: '',
                                        phone: '',
                                        address: '',
                                        nif: '',
                                        educationLevels: [],
                                        createdAt: DateTime.now(),
                                      ),
                                    );
                                    return AiTranslatedText(
                                      'Instituição: ${inst.name}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    );
                                  }),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.white24, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StudentDashboard(studentId: child.id),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SubjectSelectionScreen(
                                            student: child),
                                      ),
                                    ),
                                    icon: const Icon(Icons.school, size: 18),
                                    label: const AiTranslatedText(
                                        'Inscrever em Disciplinas'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF00D1FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showRegisterChildDialog(context, service, currentUserId),
        label: const AiTranslatedText('Registar Filho'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF7B61FF),
      ),
    );
  }

  void _showRegisterChildDialog(
      BuildContext context, FirebaseService service, String parentId) {
    final nameController = TextEditingController();
    final dobController = TextEditingController();
    DateTime? selectedDob;
    String? selectedInstitutionId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiTranslatedText(
                'Registar Novo Dependente',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dobController,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().subtract(const Duration(days: 365 * 10)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      selectedDob = date;
                      dobController.text =
                          DateFormat('dd/MM/yyyy').format(date);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const AiTranslatedText(
                'Instituição de Ensino',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<InstitutionModel>>(
                future: service.getInstitutions().first,
                builder: (context, snapshot) {
                  final institutions = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: institutions
                        .map((inst) => DropdownMenuItem(
                              value: inst.id,
                              child: Text(inst.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedInstitutionId = val);
                    },
                    initialValue: selectedInstitutionId,
                    hint: const AiTranslatedText('Selecionar Instituição',
                        style: TextStyle(color: Colors.white38)),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      selectedDob == null ||
                      selectedInstitutionId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: AiTranslatedText(
                              'Por favor preencha todos os campos')),
                    );
                    return;
                  }

                  final newChild = UserModel(
                    id: 'child_${DateTime.now().millisecondsSinceEpoch}',
                    email: '', // Logic: Children are linked via parentId
                    name: nameController.text,
                    role: UserRole.student,
                    institutionId: selectedInstitutionId!,
                    birthDate: selectedDob,
                    parentId: parentId,
                    adConsent: true,
                    dataConsent: true,
                  );

                  await service.registerChild(newChild);
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SubjectSelectionScreen(student: newChild),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const AiTranslatedText('Registar'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
