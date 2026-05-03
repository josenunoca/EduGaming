import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRStaffTab extends StatelessWidget {
  final InstitutionModel institution;

  const HRStaffTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return FutureBuilder<List<UserModel>>(
      future: service.getAllInstitutionMembers(institution.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: AiTranslatedText('Erro ao carregar colaboradores'));
        }
        
        final staff = snapshot.data ?? [];
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pesquisar colaborador...',
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const AiTranslatedText('Novo Colaborador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final employee = staff[index];
                  return _EmployeeTile(employee: employee);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final UserModel employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF00D1FF).withValues(alpha: 0.2),
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  employee.role.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const AiTranslatedText(
                'Entrada: 08:32',
                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
              ),
              Row(
                children: [
                   StreamBuilder<InstitutionModel?>(
                    stream: context.read<FirebaseService>().getInstitutionStream(employee.institutionId ?? ''),
                    builder: (context, snapshot) {
                      final hrRoles = snapshot.data?.delegatedRoles['hr'] ?? [];
                      final financeRoles = snapshot.data?.delegatedRoles['finance'] ?? [];
                      final procurementRoles = snapshot.data?.delegatedRoles['procurement'] ?? [];

                      final isHrManager = hrRoles.contains(employee.id);
                      final isFinanceManager = financeRoles.contains(employee.id);
                      final isProcurementManager = procurementRoles.contains(employee.id);
                      
                      final hasAnyManagement = isHrManager || isFinanceManager || isProcurementManager;

                      return PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: hasAnyManagement ? const Color(0xFF00D1FF) : Colors.white38),
                        onSelected: (val) async {
                          if (val == 'delegate_hr') {
                            await context.read<FirebaseService>().updateDelegatedRole(
                              employee.institutionId!,
                              employee.id,
                              'hr',
                              !isHrManager,
                            );
                          } else if (val == 'delegate_finance') {
                            await context.read<FirebaseService>().updateDelegatedRole(
                              employee.institutionId!,
                              employee.id,
                              'finance',
                              !isFinanceManager,
                            );
                          } else if (val == 'delegate_procurement') {
                            await context.read<FirebaseService>().updateDelegatedRole(
                              employee.institutionId!,
                              employee.id,
                              'procurement',
                              !isProcurementManager,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delegate_hr',
                            child: AiTranslatedText(isHrManager ? 'Remover Gestão RH' : 'Delegar Gestão RH'),
                          ),
                          PopupMenuItem(
                            value: 'delegate_finance',
                            child: AiTranslatedText(isFinanceManager ? 'Remover Gestão Finanças' : 'Delegar Gestão Finanças'),
                          ),
                          PopupMenuItem(
                            value: 'delegate_procurement',
                            child: AiTranslatedText(isProcurementManager ? 'Remover Gestão Aprovisionamento' : 'Delegar Gestão Aprov.'),
                          ),
                          const PopupMenuItem(
                            value: 'profile',
                            child: AiTranslatedText('Ver Perfil'),
                          ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white38, size: 20),
                    onPressed: () {},
                    tooltip: 'Histórico de Assiduidade',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
