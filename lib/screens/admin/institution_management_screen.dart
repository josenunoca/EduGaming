import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:uuid/uuid.dart';

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() =>
      _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState
    extends State<InstitutionManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nifController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final _mbwayController = TextEditingController();
  final _entityController = TextEditingController();
  final _referenceController = TextEditingController();

  void _showAddInstitutionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Instituição',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _nifController,
                    decoration: const InputDecoration(labelText: 'NIF'),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Morada'),
                    style: const TextStyle(color: Colors.white)),
                const Divider(height: 32, color: Colors.white24),
                const AiTranslatedText('Dados de Pagamento',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white70)),
                TextFormField(
                    controller: _mbwayController,
                    decoration:
                        const InputDecoration(labelText: 'MBWay (Telemóvel)'),
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _entityController,
                    decoration: const InputDecoration(labelText: 'Entidade'),
                    style: const TextStyle(color: Colors.white)),
                TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(labelText: 'Referência'),
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final institution = InstitutionModel(
                  id: const Uuid().v4(),
                  name: _nameController.text,
                  nif: _nifController.text,
                  email: _emailController.text,
                  phone: _phoneController.text,
                  address: _addressController.text,
                  mbwayPhone: _mbwayController.text,
                  paymentEntity: _entityController.text,
                  paymentReference: _referenceController.text,
                  educationLevels: ['Ensino Básico', 'Ensino Secundário'],
                  createdAt: DateTime.now(),
                );
                final service = context.read<FirebaseService>();
                final currentUser = service.currentUser;
                await service.saveInstitution(institution,
                    creatorUid: currentUser?.uid);
                if (mounted) {
                  Navigator.pop(context);
                  _clearControllers();
                }
              }
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showProfessorsDialog(InstitutionModel institution) {
    showDialog(
      context: context,
      builder: (context) => _ProfessorSelectionDialog(institution: institution),
    );
  }

  void _clearControllers() {
    _nameController.clear();
    _nifController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _mbwayController.clear();
    _entityController.clear();
    _referenceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const AiTranslatedText('Gestão de Instituições')),
      body: StreamBuilder<List<InstitutionModel>>(
        stream: service.getInstitutions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final institutions = snapshot.data ?? [];
          if (institutions.isEmpty) {
            return const Center(
                child: AiTranslatedText('Nenhuma instituição registada.',
                    style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: institutions.length,
            itemBuilder: (context, index) {
              final inst = institutions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  child: ListTile(
                    title: AiTranslatedText(inst.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: AiTranslatedText(
                        'Email: ${inst.email}\nProfessores: ${inst.authorizedProfessorIds.length}',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPlanBadge(inst.subscriptionPlan),
                        const SizedBox(width: 8),
                        const Icon(Icons.token, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text('${inst.aiCredits}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            inst.isSuspended
                                ? Icons.block
                                : Icons.check_circle_outline,
                            color: inst.isSuspended ? Colors.red : Colors.green,
                          ),
                          onPressed: () => service.toggleInstitutionSuspension(
                              inst.id, !inst.isSuspended),
                          tooltip: inst.isSuspended ? 'Reativar' : 'Suspender',
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1,
                              color: Color(0xFF00D1FF)),
                          onPressed: () => _showProfessorsDialog(inst),
                          tooltip: 'Gerir Professores',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInstitutionDialog,
        backgroundColor: const Color(0xFF7B61FF),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    Color color = Colors.white24;
    if (plan == 'pro') color = const Color(0xFF00D1FF);
    if (plan == 'enterprise') color = const Color(0xFF7B61FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(plan.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _ProfessorSelectionDialog extends StatefulWidget {
  final InstitutionModel institution;
  const _ProfessorSelectionDialog({required this.institution});

  @override
  State<_ProfessorSelectionDialog> createState() =>
      _ProfessorSelectionDialogState();
}

class _ProfessorSelectionDialogState extends State<_ProfessorSelectionDialog> {
  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: AiTranslatedText('Professores - ${widget.institution.name}',
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<List<UserModel>>(
          stream: service.getUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final teachers = snapshot.data!
                .where((u) => u.role == UserRole.teacher)
                .toList();

            return ListView.builder(
              shrinkWrap: true,
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                final isLinked = widget.institution.authorizedProfessorIds
                    .contains(teacher.id);

                return CheckboxListTile(
                  title: AiTranslatedText(teacher.name,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: AiTranslatedText(teacher.email,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  value: isLinked,
                  onChanged: (v) async {
                    if (v == true) {
                      await service.linkProfessorToInstitution(
                          teacher.id, widget.institution.id);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Fechar')),
      ],
    );
  }
}
