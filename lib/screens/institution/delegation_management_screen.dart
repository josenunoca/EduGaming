import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../models/delegation_event_model.dart';
import '../../services/firebase_service.dart';
import '../../services/delegation_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/custom_button.dart';

class DelegationManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const DelegationManagementScreen({super.key, required this.institution});

  @override
  State<DelegationManagementScreen> createState() => _DelegationManagementScreenState();
}

class _DelegationManagementScreenState extends State<DelegationManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final delegationService = context.read<DelegationService>();
    final firebaseService = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Delegação Profissional'),
        actions: [
          StreamBuilder<List<DelegationEvent>>(
            stream: delegationService.getDelegationHistory(widget.institution.id),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.orangeAccent),
                onPressed: () {
                  if (snapshot.hasData) {
                    delegationService.generateAuditPdf(widget.institution, snapshot.data!);
                  }
                },
                tooltip: 'Gerar PDF de Auditoria',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          tabs: const [
            Tab(text: 'Ativas'),
            Tab(text: 'Histórico Auditável'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveDelegations(context, firebaseService, delegationService),
          _buildDelegationHistory(delegationService),
        ],
      ),
    );
  }

  Widget _buildActiveDelegations(BuildContext context, FirebaseService firebaseService, DelegationService delegationService) {
    return StreamBuilder<InstitutionModel?>(
      stream: firebaseService.getInstitutionStream(widget.institution.id),
      builder: (context, instSnapshot) {
        final currentInst = instSnapshot.data ?? widget.institution;

        return StreamBuilder<List<UserModel>>(
          stream: firebaseService.getCollaboratorsByInstitution(widget.institution.id),
          builder: (context, collaboratorsSnapshot) {
            final collaborators = collaboratorsSnapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AiTranslatedText('Controlo de Responsabilidades',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        AiTranslatedText(
                            'Sistema de delegação granular (SAP Style). Cada atribuição é registada para auditoria futura e controlo de responsabilidade.',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildSectionHeader('GESTÃO GLOBAL 360º', Icons.language, const Color(0xFF7B61FF)),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'global_360', 'Gestão Total da Instituição', Icons.admin_panel_settings, const Color(0xFF7B61FF), collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'global_360:spaces', 'Gestão de Espaços e Salas', Icons.room, const Color(0xFF7B61FF), collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'global_360:timetable', 'Horários e Calendários', Icons.calendar_today, const Color(0xFF7B61FF), collaborators),

                const SizedBox(height: 24),
                _buildSectionHeader('RECURSOS HUMANOS', Icons.people, const Color(0xFF00D1FF)),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'professors', 'Gestão de Professores', Icons.group, const Color(0xFF00D1FF), collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'professors:recruitment', 'Recrutamento e Candidaturas', Icons.person_add, const Color(0xFF00D1FF), collaborators),

                const SizedBox(height: 24),
                _buildSectionHeader('GESTÃO ACADÉMICA', Icons.school, Colors.indigo),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'academic:enrollment', 'Matrículas e Inscrições', Icons.assignment_ind, Colors.indigo, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'academic:grades', 'Avaliações e Notas', Icons.grade, Colors.indigo, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'academic:attendance', 'Assiduidade e Faltas', Icons.how_to_reg, Colors.indigo, collaborators),

                const SizedBox(height: 24),
                _buildSectionHeader('APROVISIONAMENTO E STOCKS', Icons.inventory_2, Colors.orange),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'procurement:global', 'Gestão Global de Stocks', Icons.warehouse, Colors.orange, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'procurement:fulfillment', 'Satisfação de Encomendas', Icons.local_shipping, Colors.orange, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'procurement:invoicing', 'Registo de Faturação Manual', Icons.receipt_long, Colors.orange, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'procurement:audit', 'Auditoria de Inventário', Icons.analytics, Colors.orange, collaborators),

                const SizedBox(height: 24),
                _buildSectionHeader('FINANCEIRO', Icons.account_balance_wallet, Colors.greenAccent),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'finance:payments', 'Controlo de Pagamentos', Icons.payments, Colors.greenAccent, collaborators),
                _buildTaskTile(context, delegationService, firebaseService, currentInst, 'finance:expenses', 'Aprovação de Despesas', Icons.price_check, Colors.greenAccent, collaborators),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDelegationHistory(DelegationService service) {
    return StreamBuilder<List<DelegationEvent>>(
      stream: service.getDelegationHistory(widget.institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final history = snapshot.data!;

        if (history.isEmpty) {
          return const Center(child: AiTranslatedText('Sem registos de alteração.', style: TextStyle(color: Colors.white24)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final event = history[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    event.isActive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: event.isActive ? Colors.greenAccent : Colors.redAccent,
                  ),
                  title: Text('${event.delegateName} -> ${event.moduleLabel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Atribuído por: ${event.assignedByName}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      Text(
                        'Início: ${DateFormat('dd/MM/yyyy HH:mm').format(event.startDate)}${event.endDate != null ? ' | Fim: ${DateFormat('dd/MM/yyyy HH:mm').format(event.endDate!)}' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (event.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: (event.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      event.isActive ? 'ATIVA' : 'CONCLUÍDA',
                      style: TextStyle(color: event.isActive ? Colors.green : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
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

  Widget _buildTaskTile(BuildContext context, DelegationService service, FirebaseService firebaseService, InstitutionModel institution, String key, String label, IconData icon, Color color, List<UserModel> collaborators) {
    final List<String> assignedUids = institution.delegatedRoles[key] ?? [];
    
    String subtitleText = 'Nenhum responsável nomeado';
    if (assignedUids.isNotEmpty) {
      final names = assignedUids.map((uid) {
        final user = collaborators.where((u) => u.id == uid).firstOrNull;
        return user?.name ?? 'ID: $uid';
      }).join(', ');
      subtitleText = names;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            radius: 14,
            child: Icon(icon, color: color, size: 14),
          ),
          title: AiTranslatedText(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(subtitleText, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: CustomButton(
            onPressed: () => _showAssignDialog(context, service, firebaseService, institution, key, label, collaborators),
            label: 'Delegar',
            variant: CustomButtonVariant.secondary,
            width: 70,
            height: 28,
          ),
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, DelegationService delegationService, FirebaseService firebaseService, InstitutionModel institution, String moduleKey, String moduleLabel, List<UserModel> collaborators) {
    final List<String> currentSelected = List<String>.from(institution.delegatedRoles[moduleKey] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: AiTranslatedText('Delegar Responsabilidade: $moduleLabel', style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: collaborators.length,
                itemBuilder: (context, index) {
                  final colab = collaborators[index];
                  final isSelected = currentSelected.contains(colab.id);

                  return CheckboxListTile(
                    activeColor: Colors.orangeAccent,
                    title: Text(colab.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(colab.role.toString().split('.').last, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
                child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              CustomButton(
                onPressed: () async {
                  await delegationService.updateDelegation(
                    institution: widget.institution,
                    moduleKey: moduleKey,
                    moduleLabel: moduleLabel,
                    newUserIds: currentSelected,
                    allCollaborators: collaborators,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                label: 'Confirmar Delegação',
                width: 150,
                height: 36,
              ),
            ],
          );
        });
      },
    );
  }
}

