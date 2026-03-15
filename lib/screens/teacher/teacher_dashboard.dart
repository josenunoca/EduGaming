import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import 'subject_details_screen.dart';
import '../common/personal_profile_screen.dart';
import '../common/communication_center_screen.dart';
import '../../widgets/messaging_badge.dart';
import '../../widgets/advanced_search_anchor.dart';
import '../../widgets/ai_translated_text.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? _selectedYearFilter;
  String _searchQuery = '';

  void _createNewSubject(BuildContext context, UserModel teacher) {
    if (teacher.institutionId == null || teacher.institutionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Aviso: Ainda não está associado a nenhuma Instituição. Contacte o Administrador.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateSubjectModal(teacher: teacher),
    );
  }

  void _showDuplicateDialog(
      BuildContext context, FirebaseService service, Subject subject) {
    String selectedYear = '2024/2025';
    showDialog(
      context: context,
      builder: (context) {
        bool isDuplicating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const AiTranslatedText('Duplicar Disciplina',
                  style: TextStyle(color: Colors.white)),
              content: isDuplicating
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00D1FF)),
                        SizedBox(height: 20),
                        AiTranslatedText('A duplicar conteúdos e jogos...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AiTranslatedText(
                            'Selecione o novo ano letivo para a cópia:',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedYear,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: ['2023/2024', '2024/2025', '2025/2026']
                              .map((y) =>
                                  DropdownMenuItem(value: y, child: Text(y)))
                              .toList(),
                          onChanged: (v) => selectedYear = v!,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                        ),
                      ],
                    ),
              actions: isDuplicating
                  ? []
                  : [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => isDuplicating = true);
                          try {
                            await service.duplicateSubject(
                                subject, selectedYear);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isDuplicating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao duplicar: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D1FF),
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        child: const Text('Duplicar'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return StreamBuilder<User?>(
      stream: service.user,
      builder: (context, authSnapshot) {
        final userId = authSnapshot.data?.uid ?? '';
        if (userId.isEmpty) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<UserModel?>(
          stream: service.getUserStream(userId),
          builder: (context, userSnapshot) {
            final teacher = userSnapshot.data;
            if (teacher == null) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            return Scaffold(
              appBar: AppBar(
                title: const AiTranslatedText('Painel do Professor'),
                actions: [
                  Tooltip(
                    message: 'Ver e editar os seus dados pessoais',
                    child: IconButton(
                      icon: const Icon(Icons.person),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PersonalProfileScreen(user: teacher))),
                    ),
                  ),
                  Tooltip(
                    message: 'Abrir centro de mensagens e correspondência',
                    child: MessagingBadge(
                      icon: const Icon(Icons.mail),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CommunicationCenterScreen())),
                    ),
                  ),
                  Tooltip(
                    message: 'Sair da conta e voltar ao ecrã de login',
                    child: IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: Tooltip(
                message: 'Criar uma nova disciplina para lecionar',
                child: FloatingActionButton.extended(
                  onPressed: () => _createNewSubject(context, teacher),
                  label: const AiTranslatedText('Nova Disciplina'),
                  icon: const Icon(Icons.add),
                  backgroundColor: const Color(0xFF7B61FF),
                ),
              ),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdvancedSearchAnchor(
                        hintText: 'Pesquisar disciplinas ou alunos...',
                        onSearchQuery: (query) async {
                          final results = <SearchResult>[];

                          // Search Subjects
                          final subs = await service
                              .searchSubjects(query, teacherId: teacher.id)
                              .first;
                          results.addAll(subs.map((s) => SearchResult(
                                id: s.id,
                                title: s.name,
                                subtitle: '${s.level} • ${s.academicYear}',
                                icon: Icons.book,
                                category: 'As Minhas Disciplinas',
                                originalObject: s,
                              )));

                          // Search Students
                          final students = await service
                              .searchTeacherStudents(teacher.id, query)
                              .first;
                          results.addAll(students.map((u) => SearchResult(
                                id: u.id,
                                title: u.name,
                                subtitle: u.email,
                                icon: Icons.person,
                                category: 'Alunos',
                                originalObject: u,
                              )));

                          return results;
                        },
                        onResultSelected: (res) {
                          if (res.category == 'As Minhas Disciplinas') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => SubjectDetailsScreen(
                                        subject:
                                            res.originalObject as Subject)));
                          } else {
                            setState(() => _searchQuery = res.title);
                          }
                        },
                        onClear: () => setState(() => _searchQuery = ''),
                      ),
                      if (_searchQuery.isNotEmpty)
                        Expanded(
                            child: _buildSearchResults(
                                context, service, teacher.id))
                      else ...[
                        AiTranslatedText('Bem-vindo, ${teacher.name}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white70)),
                        const AiTranslatedText('As Minhas Disciplinas',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 16),
                        DropdownButton<String?>(
                          value: _selectedYearFilter,
                          hint: const AiTranslatedText('Filtrar por Ano Letivo',
                              style: TextStyle(color: Colors.white70)),
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('Todos os Anos')),
                            ...['2023/2024', '2024/2025', '2025/2026'].map(
                                (y) =>
                                    DropdownMenuItem(value: y, child: Text(y))),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedYearFilter = v),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<List<Subject>>(
                            stream: service.getSubjectsByTeacher(teacher.id,
                                academicYear: _selectedYearFilter),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final subjects = snapshot.data ?? [];
                              return ListView.builder(
                                itemCount: subjects.length,
                                itemBuilder: (context, index) {
                                  final subject = subjects[index];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12.0),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7B61FF)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.book,
                                                color: Color(0xFF7B61FF)),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                AiTranslatedText(subject.name,
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white)),
                                                AiTranslatedText(
                                                    '${subject.level} • ${subject.academicYear}',
                                                    style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 13)),
                                                AiTranslatedText(
                                                    '${subject.contents.length} conteúdos',
                                                    style: const TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          SubjectDetailsScreen(
                                                              subject:
                                                                  subject)),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF7B61FF),
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const AiTranslatedText(
                                                    'GERIR',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12)),
                                              ),
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _showDuplicateDialog(
                                                        context,
                                                        service,
                                                        subject),
                                                icon: const Icon(Icons.copy,
                                                    size: 14,
                                                    color: Colors.blueAccent),
                                                label: const AiTranslatedText(
                                                    'Duplicar',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.blueAccent)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(
      BuildContext context, FirebaseService service, String teacherId) {
    return ListView(
      children: [
        const AiTranslatedText('Resultados da Pesquisa',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B61FF))),
        const SizedBox(height: 16),
        _buildSearchSection<Subject>(
          title: 'As Minhas Disciplinas',
          stream: service.searchSubjects(_searchQuery, teacherId: teacherId),
          itemBuilder: (s) => ListTile(
            leading: const Icon(Icons.book, color: Color(0xFF7B61FF)),
            title: Text(s.name, style: const TextStyle(color: Colors.white)),
            subtitle: AiTranslatedText('${s.level} • ${s.academicYear}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SubjectDetailsScreen(subject: s))),
          ),
        ),
        _buildSearchSection<UserModel>(
          title: 'Alunos',
          stream: service.searchTeacherStudents(teacherId, _searchQuery),
          itemBuilder: (u) => ListTile(
            leading: const Icon(Icons.person, color: Colors.greenAccent),
            title: Text(u.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(u.email,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            // Note: Teacher can view student progress if implemented
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection<T>({
    required String title,
    required Stream<List<T>> stream,
    required Widget Function(T) itemBuilder,
  }) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AiTranslatedText(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            ...results.map((item) => itemBuilder(item)),
            const Divider(color: Colors.white10),
          ],
        );
      },
    );
  }
}

class _CreateSubjectModal extends StatefulWidget {
  final UserModel teacher;
  const _CreateSubjectModal({required this.teacher});

  @override
  State<_CreateSubjectModal> createState() => _CreateSubjectModalState();
}

class _CreateSubjectModalState extends State<_CreateSubjectModal> {
  final _nameController = TextEditingController();
  String _selectedLevel = '1.º Ciclo';
  String _selectedYear = '2024/2025';
  String? _selectedScientificArea;
  final _teachingHoursController = TextEditingController(text: '0.0');
  final _nonTeachingHoursController = TextEditingController(text: '0.0');

  @override
  Widget build(BuildContext context) {
    final scientificAreas = FirebaseService.getScientificAreas();

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova Disciplina',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Nome da Disciplina', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            items: [
              'Creche',
              'Pré-Escolar',
              '1.º Ciclo',
              '2.º Ciclo',
              '3.º Ciclo',
              'Secundário',
              'Ensino Profissional',
              'Licenciatura',
              'Mestrado',
              'Doutoramento'
            ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _selectedLevel = v!),
            decoration: const InputDecoration(
                labelText: 'Nível de Ensino', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedYear,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            items: ['2023/2024', '2024/2025', '2025/2026']
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v!),
            decoration: const InputDecoration(
                labelText: 'Ano Letivo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _selectedScientificArea,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            hint: const Text('Área Científica (Opcional)',
                style: TextStyle(color: Colors.white54)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nenhuma')),
              ...scientificAreas
                  .map((a) => DropdownMenuItem(value: a, child: Text(a))),
            ],
            onChanged: (v) => setState(() => _selectedScientificArea = v),
            decoration: const InputDecoration(
                labelText: 'Área Científica', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teachingHoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Horas Letivas', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nonTeachingHoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Horas Não Letivas',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty) return;
              final service = context.read<FirebaseService>();
              final s = Subject(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                level: _selectedLevel,
                academicYear: _selectedYear,
                teacherId: widget.teacher.id,
                institutionId: widget.teacher.institutionId ?? 'pending',
                allowedStudentEmails: [],
                contents: [],
                games: [],
                scientificArea: _selectedScientificArea,
                theoreticalHours:
                    double.tryParse(_teachingHoursController.text) ?? 0.0,
                otherHours:
                    double.tryParse(_nonTeachingHoursController.text) ?? 0.0,
                syllabusStatus: SyllabusStatus.provisional,
              );
              await service.updateSubject(s);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color(0xFF7B61FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Criar Disciplina',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
