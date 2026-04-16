import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/custom_button.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InstitutionCollaboratorManagementScreen extends StatelessWidget {
  final InstitutionModel institution;
  const InstitutionCollaboratorManagementScreen(
      {super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: AiTranslatedText('Colaboradores - ${institution.name}'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF7B61FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Pessoal Docente'),
              Tab(text: 'Pessoal Não Docente'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCollaboratorDialog(context),
          label: const AiTranslatedText('Adicionar Colaborador'),
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
            final authorizedUsers = allUsers
                .where((u) => institution.authorizedProfessorIds.contains(u.id))
                .toList();

            final docentes = authorizedUsers
                .where((u) =>
                    u.role == UserRole.teacher ||
                    u.role == UserRole.courseCoordinator)
                .toList();

            final naoDocentes = authorizedUsers
                .where((u) =>
                    u.role != UserRole.teacher &&
                    u.role != UserRole.courseCoordinator &&
                    u.role != UserRole.student &&
                    u.role != UserRole.parent) // Adjust based on your non-teaching roles
                .toList();

            return TabBarView(
              children: [
                _buildCollaboratorList(context, service, docentes),
                _buildCollaboratorList(context, service, naoDocentes),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCollaboratorList(
      BuildContext context, FirebaseService service, List<UserModel> users) {
    if (users.isEmpty) {
      return const Center(
        child: AiTranslatedText('Nenhum colaborador encontrado nesta categoria.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                onTap: () => _showCollaboratorDetails(context, user),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF7B61FF),
                  backgroundImage: user.signatureUrl != null
                      ? NetworkImage(user.signatureUrl!) // If you adapt signatureUrl or add photoUrl in UserModel later
                      : null,
                  child: const Icon(Icons.person, color: Colors.white), // Fallback icon
                ),
                title: AiTranslatedText(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email,
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    if (user.phone != null && user.phone!.isNotEmpty)
                      Text(user.phone!,
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.white70, size: 20),
                      onPressed: () => _showEditCollaboratorDialog(context, user),
                      tooltip: 'Editar Colaborador',
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
                              value: !user.isSuspended,
                              onChanged: (val) =>
                                  service.toggleUserSuspension(user.id, !val),
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
  }

  void _showCollaboratorDetails(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AiTranslatedText('Detalhes do Colaborador',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF7B61FF),
                      child: const Icon(Icons.person, color: Colors.white, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                  Center(
                    child: Text(user.role.toString().split('.').last,
                        style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 14)),
                  ),
                  const SizedBox(height: 32),
                  _buildDetailItem(Icons.email, 'Email', user.email),
                  _buildDetailItem(Icons.phone, 'Telemóvel', user.phone ?? 'Não preenchido'),
                  _buildDetailItem(Icons.location_on, 'Morada', user.address ?? 'Não preenchido'),
                  _buildDetailItem(Icons.mark_as_unread, 'Código Postal', user.postalCode ?? 'Não preenchido'),
                  _buildDetailItem(
                      Icons.cake,
                      'Data de Nascimento',
                      user.birthDate != null
                          ? '${user.birthDate!.day}/${user.birthDate!.month}/${user.birthDate!.year}'
                          : 'Não preenchida'),
                  _buildDetailItem(Icons.badge, 'NIF', user.nif ?? 'Não preenchido'),
                  
                  const SizedBox(height: 32),
                  const AiTranslatedText('Resumo Curricular (CV)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (user.curriculum == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: AiTranslatedText(
                            'O colaborador ainda não carregou a informação curricular, ou ela ainda não foi traduzida pelo sistema.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  else ...[
                    _buildCvSection('Habilitações Académicas', user.curriculum!.academicQualifications),
                    _buildCvSection('Área do Curso', user.curriculum!.courseArea),
                    _buildCvSection('Habilitações Profissionais', user.curriculum!.professionalQualifications),
                    _buildCvSection('Prémios e Reconhecimentos', user.curriculum!.awards),
                    _buildCvSection('Experiência Profissional', user.curriculum!.experience),
                    _buildCvSection('Publicações', user.curriculum!.publications),
                    _buildCvSection('Outros Assuntos', user.curriculum!.otherInterests),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: CustomButton(
                onPressed: () => _printCollaboratorSheet(context, user),
                label: 'Imprimir / Exportar Ficha',
                icon: Icons.print,
                width: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCvSection(String title, String? content) {
    if (content == null || content.isEmpty || content.toLowerCase() == 'n/a' || content.toLowerCase() == 'não aplicável') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 14)),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  Future<void> _printCollaboratorSheet(BuildContext context, UserModel user) async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A preparar o documento para impressão...')));
        
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Ficha de Colaborador', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Instituição: ${institution.name}', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            
            pw.Header(level: 1, child: pw.Text('Dados Pessoais')),
            pw.Text('Nome: ${user.name}'),
            pw.Text('Email: ${user.email}'),
            pw.Text('Telemóvel: ${user.phone ?? "N/A"}'),
            pw.Text('Função: ${user.role.toString().split('.').last}'),
            pw.Text('Morada: ${user.address ?? "N/A"}'),
            pw.Text('Código Postal: ${user.postalCode ?? "N/A"}'),
            pw.Text('Data Nascimento: ${user.birthDate != null ? "${user.birthDate!.day}/${user.birthDate!.month}/${user.birthDate!.year}" : "N/A"}'),
            pw.Text('NIF: ${user.nif ?? "N/A"}'),
            
            pw.SizedBox(height: 20),
            if (user.curriculum != null) ...[
              pw.Header(level: 1, child: pw.Text('Curriculum Vitae (Extraído por IA)')),
              if (user.curriculum!.academicQualifications?.isNotEmpty ?? false) ...[
                pw.Text('Habilitações Académicas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.academicQualifications!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.courseArea?.isNotEmpty ?? false) ...[
                pw.Text('Área do Curso:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.courseArea!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.professionalQualifications?.isNotEmpty ?? false) ...[
                pw.Text('Habilitações Profissionais:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.professionalQualifications!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.experience?.isNotEmpty ?? false) ...[
                pw.Text('Experiência Profissional:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.experience!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.awards?.isNotEmpty ?? false) ...[
                pw.Text('Prémios:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.awards!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.publications?.isNotEmpty ?? false) ...[
                pw.Text('Publicações:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.publications!),
                pw.SizedBox(height: 10),
              ],
              if (user.curriculum!.otherInterests?.isNotEmpty ?? false) ...[
                pw.Text('Outros Assuntos de Interesse:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(user.curriculum!.otherInterests!),
                pw.SizedBox(height: 10),
              ],
            ] else 
              pw.Text('Curriculum Vitae: O(A) colaborador(a) não preencheu e/ou carregou a informação curricular.'),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCollaboratorDialog(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Editar Colaborador',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome do Colaborador',
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
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Telemóvel',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
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
              await service.updateUserProfile(user.id, {
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'phone': phoneController.text.trim(),
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

  void _showAddCollaboratorDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Novo Colaborador',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome do Colaborador',
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
                  const SnackBar(
                      content: Text('Colaborador adicionado com sucesso!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF)),
            child: const AiTranslatedText('Adicionar'),
          ),
        ],
      ),
    );
  }
}
