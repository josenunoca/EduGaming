import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/institution_model.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class SubjectSelectionScreen extends StatefulWidget {
  final UserModel student;
  const SubjectSelectionScreen({super.key, required this.student});

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  InstitutionModel? _selectedInstitution;
  UserModel? _selectedTeacher;

  void _resetSelection() {
    setState(() {
      if (_selectedTeacher != null) {
        _selectedTeacher = null;
      } else {
        _selectedInstitution = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    String title = 'Selecionar Instituição';
    if (_selectedInstitution != null && _selectedTeacher == null) {
      title = 'Selecionar Professor';
    } else if (_selectedTeacher != null) {
      title = 'Selecionar Disciplina';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(title),
        leading: _selectedInstitution != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _resetSelection)
          : null,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: _selectedInstitution == null 
          ? _buildInstitutionList(service)
          : _selectedTeacher == null
              ? _buildTeacherList(service)
              : _buildSubjectList(service),
      ),
    );
  }

  Widget _buildInstitutionList(FirebaseService service) {
    return StreamBuilder<List<InstitutionModel>>(
      stream: service.getInstitutions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final institutions = snapshot.data!;
        if (institutions.isEmpty) return const Center(child: Text('Nenhuma instituição disponível.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          itemCount: institutions.length,
          itemBuilder: (context, index) {
            final inst = institutions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: ListTile(
                  title: Text(inst.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(inst.address, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF00D1FF)),
                  onTap: () => setState(() => _selectedInstitution = inst),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherList(FirebaseService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professores em ${_selectedInstitution!.name}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: service.getTeachersByInstitution(_selectedInstitution!.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final teachers = snapshot.data ?? [];
              if (teachers.isEmpty) return const Center(child: Text('Nenhum professor encontrado.', style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF7B61FF),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(teacher.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(teacher.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF00D1FF)),
                        onTap: () => setState(() => _selectedTeacher = teacher),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectList(FirebaseService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disciplinas de ${_selectedTeacher!.name}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Subject>>(
            // Filter by selected teacher and selected institution (implicit if teacher is in that institution)
            stream: service.getSubjectsByTeacher(_selectedTeacher!.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final subjects = snapshot.data!.where((s) => s.institutionId == _selectedInstitution!.id).toList();
              
              if (subjects.isEmpty) return const Center(child: Text('Nenhuma disciplina deste professor.', style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final isMarketplace = subject.isMarketplaceEnabled;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: ListTile(
                        title: Text(subject.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Row(
                          children: [
                            Text(subject.level, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            if (isMarketplace) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('€${subject.price.toStringAsFixed(2)}', 
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _confirmEnrollment(context, service, subject),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
                          child: Text(isMarketplace ? 'Comprar' : 'Inscrever'),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmEnrollment(BuildContext context, FirebaseService service, Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Confirmar Inscrição', style: TextStyle(color: Colors.white)),
        content: AiTranslatedText(
          subject.isMarketplaceEnabled
          ? 'Deseja adquirir o acesso à disciplina ${subject.name} por €${subject.price.toStringAsFixed(2)}?\n\n'
            'Após confirmar, as instruções de pagamento serão enviadas para o seu email.'
          : widget.student.parentId != null
          ? 'Deseja inscrever a criança na disciplina ${subject.name} lecionada por ${_selectedTeacher!.name}?\n\n'
            'Após o pedido, o Professor autorizará o seu acesso (pagamento validado via Encarregado de Educação).'
          : 'Deseja inscrever-se na disciplina ${subject.name} lecionada por ${_selectedTeacher!.name}?\n\n'
            'Após o pedido, o Administrador validará o pagamento e o Professor autorizará o seu acesso.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await service.requestEnrollment(
                student: widget.student,
                subjectId: subject.id,
                institutionId: _selectedInstitution!.id,
              );
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pedido de inscrição enviado com sucesso!')),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
