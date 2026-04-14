import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/institution_organ_model.dart';
import '../../models/user_model.dart';
import '../../services/institutional_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import 'meeting_list_screen.dart';

class InstitutionalOrgansScreen extends StatelessWidget {
  const InstitutionalOrgansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final institutionalService = Provider.of<InstitutionalService>(context);
    final firebaseService = Provider.of<FirebaseService>(context);
    final currentUser = firebaseService.currentUser;

    return StreamBuilder<UserModel?>(
      stream: firebaseService.getUserStream(currentUser?.uid ?? ''),
      builder: (context, userSnapshot) {
        final userModel = userSnapshot.data;
        final bool isInstitution = userModel?.role == UserRole.institution || 
                                    userModel?.role == UserRole.admin ||
                                    (currentUser?.email?.startsWith('instituicao@') == true);
        
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const AiTranslatedText('Órgãos da Instituição',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: StreamBuilder<List<InstitutionOrgan>>(
            stream: institutionalService.getOrgansStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              var organs = snapshot.data ?? [];
              
              if (!isInstitution) {
                organs = organs.where((o) => 
                  o.isActive && (
                    o.memberIds.contains(currentUser?.uid) || 
                    o.presidentEmail == currentUser?.email || 
                    o.vicePresidentEmail == currentUser?.email
                  )
                ).toList();
              }

              if (organs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_tree_outlined, color: Colors.white24, size: 64),
                      const SizedBox(height: 16),
                      const AiTranslatedText('Nenhum órgão registado',
                          style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 24),
                      if (isInstitution)
                        ElevatedButton.icon(
                          onPressed: () => _showAddOrganDialog(context),
                          icon: const Icon(Icons.add),
                          label: const AiTranslatedText('Adicionar Órgão'),
                        ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: organs.length,
                itemBuilder: (context, index) {
                  final organ = organs[index];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Opacity(
                      opacity: organ.isActive ? 1.0 : 0.5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: organ.isActive ? const Color(0xFF7B61FF) : Colors.grey,
                          child: const Icon(Icons.groups, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(organ.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            if (!organ.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                                child: const Text('INATIVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Text(organ.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54)),
                        trailing: isInstitution 
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white54),
                              onSelected: (value) async {
                                if (value == 'toggle') {
                                  await institutionalService.updateOrganActiveStatus(organ.id, !organ.isActive);
                                } else if (value == 'delete') {
                                  final count = await institutionalService.getMeetingsForOrganCount(organ.id);
                                  if (count > 0) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: AiTranslatedText('Não é possível apagar órgãos com documentos associados.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  } else {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E293B),
                                        title: const AiTranslatedText('Confirmar Exclusão', style: TextStyle(color: Colors.white)),
                                        content: AiTranslatedText('Deseja realmente apagar o órgão "${organ.name}"?', style: const TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const AiTranslatedText('Cancelar')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const AiTranslatedText('Apagar', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await institutionalService.deleteOrgan(organ.id);
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(organ.isActive ? Icons.visibility_off : Icons.visibility, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      AiTranslatedText(organ.isActive ? 'Marcar como Inativo' : 'Marcar como Ativo'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      AiTranslatedText('Apagar Órgão'),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const Icon(Icons.chevron_right, color: Colors.white24),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MeetingListScreen(organ: organ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: isInstitution ? FloatingActionButton(
            backgroundColor: const Color(0xFF7B61FF),
            onPressed: () => _showAddOrganDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ) : null,
        );
      },
    );
  }

  void _showAddOrganDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final presidentController = TextEditingController();
    final vicePresidentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Novo Órgão', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome do Órgão',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Descrição/Objetivo',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: presidentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'E-mail do Presidente',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vicePresidentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'E-mail do Vice-Presidente',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final service = Provider.of<InstitutionalService>(context, listen: false);
                await service.createOrgan(InstitutionOrgan(
                  id: '',
                  name: nameController.text,
                  description: descController.text,
                  memberIds: [],
                  presidentEmail: presidentController.text.isEmpty ? null : presidentController.text,
                  vicePresidentEmail: vicePresidentController.text.isEmpty ? null : vicePresidentController.text,
                  createdAt: DateTime.now(),
                ));
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const AiTranslatedText('Criar'),
          ),
        ],
      ),
    );
  }
}
