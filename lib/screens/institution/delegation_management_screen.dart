import 'package:flutter/material.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/custom_button.dart';
import '../../models/institution_organ_model.dart';
import 'package:provider/provider.dart';

class DelegationManagementScreen extends StatelessWidget {
  final InstitutionModel institution;

  const DelegationManagementScreen({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return StreamBuilder<List<UserModel>>(
      stream: service.getCollaboratorsByInstitution(institution.id),
      builder: (context, collaboratorsSnapshot) {
        final collaborators = collaboratorsSnapshot.data ?? [];

        final List<Map<String, dynamic>> modules = [
          {
            'key': 'professors',
            'label': 'Gerir Professores',
            'icon': Icons.people,
            'color': const Color(0xFF00D1FF),
          },
          {
            'key': 'global_360',
            'label': 'Gestão Global 360º (Total)',
            'icon': Icons.admin_panel_settings,
            'color': const Color(0xFF7B61FF),
          },
          {
            'key': 'global_360:spaces',
            'label': 'Gestão 360º: Espaços e Salas',
            'icon': Icons.room,
            'color': const Color(0xFF7B61FF).withValues(alpha: 0.8),
          },
          {
            'key': 'global_360:activities',
            'label': 'Gestão 360º: Atividades Institucionais',
            'icon': Icons.event,
            'color': const Color(0xFF7B61FF).withValues(alpha: 0.8),
          },
          {
            'key': 'global_360:timetable',
            'label': 'Gestão 360º: Horários',
            'icon': Icons.calendar_today,
            'color': const Color(0xFF7B61FF).withValues(alpha: 0.8),
          },
          {
            'key': 'credits',
            'label': 'Gestão de Créditos',
            'icon': Icons.token,
            'color': Colors.amber,
          },
          {
            'key': 'academic',
            'label': 'Gestão Académica',
            'icon': Icons.school,
            'color': Colors.indigo,
          },
          {
            'key': 'lifestyle',
            'label': 'Estilo de Vida',
            'icon': Icons.favorite,
            'color': Colors.pinkAccent,
          },
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const AiTranslatedText('Delegação de Responsabilidades'),
          ),
          body: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AiTranslatedText('Gestão de Delegados',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        AiTranslatedText(
                            'Nomeie colaboradores para gerir módulos ou áreas específicas. Os delegados terão acesso total às funções atribuídas.',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _buildSectionHeader('GESTÃO GLOBAL 360º', Icons.language, const Color(0xFF7B61FF)),
                      ...modules.where((m) => m['key'].startsWith('global_360')).map((module) => _buildModuleTile(context, service, module, collaborators)),
                      
                      const SizedBox(height: 16),
                      _buildSectionHeader('RECURSOS HUMANOS', Icons.people, const Color(0xFF00D1FF)),
                      ...modules.where((m) => m['key'] == 'professors').map((module) => _buildModuleTile(context, service, module, collaborators)),

                      const SizedBox(height: 16),
                      _buildSectionHeader('GESTÃO ACADÉMICA', Icons.school, Colors.indigo),
                      ...modules.where((m) => m['key'] == 'academic' || m['key'] == 'lifestyle' || m['key'] == 'credits').map((module) => _buildModuleTile(context, service, module, collaborators)),
                      
                      const SizedBox(height: 16),
                      _buildSectionHeader('ÓRGÃOS INSTITUCIONAIS', Icons.account_balance, Colors.tealAccent),
                      StreamBuilder<List<InstitutionOrgan>>(
                        stream: service.getInstitutionOrgans(institution.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                          final organs = snapshot.data!;
                          if (organs.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: AiTranslatedText('Nenhum órgão registado.', style: TextStyle(color: Colors.white24)));
                          
                          return Column(
                            children: organs.map((organ) {
                              final key = 'organs:${organ.id}';
                              final assignedUids = institution.delegatedRoles[key] ?? [];
                              
                              String subtitleText = 'Sem delegado';
                              if (assignedUids.isNotEmpty) {
                                final names = assignedUids.map((uid) {
                                  final user = collaborators.where((u) => u.id == uid).firstOrNull;
                                  return user?.name ?? 'Utilizador desconhecido';
                                }).join(', ');
                                subtitleText = names;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: GlassCard(
                                  child: ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.subdirectory_arrow_right, color: Colors.white24, size: 16),
                                    title: Text(organ.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(
                                      subtitleText,
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: CustomButton(
                                      onPressed: () => _showAssignDialog(context, service, key, organ.name),
                                      label: 'Gerir',
                                      variant: CustomButtonVariant.secondary,
                                      width: 60,
                                      height: 28,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
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
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 8),
          AiTranslatedText(title, 
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildModuleTile(BuildContext context, FirebaseService service, Map<String, dynamic> module, List<UserModel> collaborators) {
    final List<String> assignedUids = institution.delegatedRoles[module['key']] ?? [];
    final bool isSubModule = module['key'].contains(':');

    String subtitleText = 'Nenhum responsável';
    if (assignedUids.isNotEmpty) {
      final names = assignedUids.map((uid) {
        final user = collaborators.where((u) => u.id == uid).firstOrNull;
        return user?.name ?? 'Utilizador desconhecido';
      }).join(', ');
      subtitleText = names;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: isSubModule ? 32 : 16, right: 16),
          leading: isSubModule 
              ? const Icon(Icons.subdirectory_arrow_right, color: Colors.white24, size: 16)
              : CircleAvatar(
                  backgroundColor: module['color'].withValues(alpha: 0.1),
                  radius: 14,
                  child: Icon(module['icon'], color: module['color'], size: 14),
                ),
          title: AiTranslatedText(module['label'],
              style: TextStyle(
                  color: isSubModule ? Colors.white70 : Colors.white,
                  fontWeight: isSubModule ? FontWeight.normal : FontWeight.bold,
                  fontSize: 13)),
          subtitle: Text(
              subtitleText,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          trailing: CustomButton(
            onPressed: () => _showAssignDialog(
                context, service, module['key'], module['label']),
            label: 'Gerir',
            variant: CustomButtonVariant.secondary,
            width: 60,
            height: 28,
          ),
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, FirebaseService service,
      String moduleKey, String moduleLabel) {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<UserModel>>(
          stream: service.getCollaboratorsByInstitution(institution.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final collaborators = snapshot.data!;
            final List<String> currentSelected =
                List<String>.from(institution.delegatedRoles[moduleKey] ?? []);

            return StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: AiTranslatedText('Nomear Responsáveis: $moduleLabel'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: collaborators.length,
                    itemBuilder: (context, index) {
                      final colab = collaborators[index];
                      final isSelected = currentSelected.contains(colab.id);

                      return CheckboxListTile(
                        title: Text(colab.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(colab.role.toString().split('.').last,
                            style: const TextStyle(color: Colors.white54)),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              currentSelected.add(colab.id);
                            } else {
                              currentSelected.remove(colab.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const AiTranslatedText('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await service.updateInstitutionDelegation(
                          institution.id, moduleKey, currentSelected);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const AiTranslatedText('Guardar Alterações'),
                  ),
                ],
              );
            });
          },
        );
      },
    );
  }
}
