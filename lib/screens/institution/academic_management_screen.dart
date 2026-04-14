import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/school_calendar_model.dart';
import '../../models/course_model.dart';
import '../../models/subject_model.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../widgets/management_document_section.dart';
import '../../models/management_document_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';

class AcademicManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const AcademicManagementScreen({super.key, required this.institution});

  @override
  State<AcademicManagementScreen> createState() =>
      _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('Gestão Académica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7B61FF),
          tabs: const [
            Tab(text: 'Ciclos'),
            Tab(text: 'Calendário'),
            Tab(text: 'Docentes'),
            Tab(text: 'Inst.'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoursesTab(),
          _buildCalendarTab(),
          _buildTeachersTab(),
          _buildCyclesAndInstitutionTab(),
        ],
      ),
    );
  }

  Widget _buildCoursesTab() {
    final service = context.read<FirebaseService>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: () => _showCreateCycleDialog(),
                      icon: Icons.add_circle,
                      label: 'Novo Ciclo',
                      variant: CustomButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      onPressed: () => _showCreateCourseDialog(),
                      icon: Icons.school,
                      label: 'Novo Curso',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Ciclos de Estudo Disponíveis:',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<List<StudyCycle>>(
                stream: service.getStudyCycles(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Nenhum ciclo definido',
                        style: TextStyle(color: Colors.white54, fontSize: 12));
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.data!
                        .map((cycle) => InputChip(
                              backgroundColor: const Color(0xFF1E1E2E),
                              avatar: const Icon(Icons.description, size: 16, color: Colors.white54),
                              label: Text('${cycle.name} (${cycle.durationValue} ${cycle.durationUnit})',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              onPressed: () => _showCycleDocsDialog(cycle),
                              deleteIcon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                              onDeleted: () => _confirmDeleteStudyCycle(cycle),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Course>>(
            stream: service.getCourses(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final courses = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return Card(
                    color: const Color(0xFF1E1E2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ExpansionTile(
                      title: Text(course.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: StreamBuilder<List<StudyCycle>>(
                        stream: service.getStudyCycles(widget.institution.id),
                        builder: (context, cycleSnap) {
                          final cycleName = cycleSnap.hasData
                              ? cycleSnap.data!
                                  .firstWhere((c) => c.id == course.studyCycleId,
                                      orElse: () => StudyCycle(
                                          id: '',
                                          name: 'Desconhecido',
                                          institutionId: ''))
                                  .name
                              : '...';
                          return Text(
                              'Ciclo: $cycleName | Anos: ${course.academicYears.length}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6)));
                        },
                      ),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      children: [
                        ListTile(
                          onTap: () => _showCourseSubjectsDialog(course),
                          leading: const Icon(Icons.book, color: Color(0xFF00D1FF)),
                          title: const Text('Gerir Disciplinas',
                              style: TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.person, color: Colors.amber),
                          title: const Text('Coordenador de Curso',
                              style: TextStyle(color: Colors.white)),
                          subtitle: FutureBuilder<UserModel?>(
                            future: course.coordinatorId != null
                                ? service.getUserModel(course.coordinatorId!)
                                : Future.value(null),
                            builder: (context, userSnap) {
                              return Text(
                                  userSnap.data?.name ?? 'Não atribuído',
                                  style:
                                      const TextStyle(color: Colors.white54));
                            },
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () => _confirmDeleteCourse(course),
                                tooltip: 'Eliminar Curso',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white54),
                                onPressed: () =>
                                    _showAssignCoordinatorDialog(course),
                                tooltip: 'Atribuir Coordenador',
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Anos Letivos Disponíveis:',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: course.academicYears
                                    .map((year) => Chip(
                                          label: Text(year,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                          backgroundColor:
                                              const Color(0xFF2E2E3E),
                                          deleteIcon: const Icon(Icons.close,
                                              size: 14, color: Colors.redAccent),
                                          onDeleted: () =>
                                              _confirmDeleteYear(course, year),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CustomButton(
                            onPressed: () async {
                              try {
                                await service.ensureAcademicYear(course.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                  );
                                }
                              }
                            },
                            icon: Icons.add,
                            label: 'Gerar Próximo Ano Letivo',
                            isFullWidth: true,
                          ),
                        ),
                      ],
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

  void _showCreateCycleDialog() {
    final service = context.read<FirebaseService>();
    final nameController = TextEditingController();
    int durationValue = 1;
    String durationUnit = 'Anos';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Novo Ciclo de Estudos',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: 'Nome (ex: Mestrado)',
                    labelStyle: TextStyle(color: Colors.white54)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Duração',
                          labelStyle: TextStyle(color: Colors.white54)),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => durationValue = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: durationUnit,
                    dropdownColor: const Color(0xFF1E1E2E),
                    style: const TextStyle(color: Colors.white),
                    items: ['Anos', 'Meses']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => durationUnit = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Cancelar')),
            CustomButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final cycle = StudyCycle(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    institutionId: widget.institution.id,
                    durationValue: durationValue,
                    durationUnit: durationUnit,
                  );
                  await service.saveStudyCycle(cycle);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              label: 'Criar',
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCourseDialog() {
    final service = context.read<FirebaseService>();
    final nameController = TextEditingController();
    final academicYearController = TextEditingController(text: '2024/2025');
    final durationController = TextEditingController(text: '3');
    String? selectedCycleId;
    int durationYears = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title:
              const Text('Novo Curso', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nome do Curso',
                      labelStyle: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<StudyCycle>>(
                  stream: service.getStudyCycles(widget.institution.id),
                  builder: (context, snapshot) {
                    final cycles = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1E1E2E),
                    value: selectedCycleId,
                      hint: const Text('Selecionar Ciclo',
                          style: TextStyle(color: Colors.white54)),
                      items: cycles
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name,
                                  style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (v) => setState(() => selectedCycleId = v),
                      validator: (v) => v == null ? 'Obrigatório' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: academicYearController.text.isEmpty ? '2024/2025' : academicYearController.text,
                  dropdownColor: const Color(0xFF1E1E2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Ano Letivo Inicial',
                      labelStyle: TextStyle(color: Colors.white54)),
                  items: ['2024/2025', '2025/2026', '2026/2027', '2027/2028']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) academicYearController.text = v;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Duração (Anos)',
                      labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (v) => durationYears = int.tryParse(v) ?? 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Cancelar')),
            CustomButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    selectedCycleId != null &&
                    academicYearController.text.isNotEmpty) {
                  final course = Course(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    studyCycleId: selectedCycleId!,
                    institutionId: widget.institution.id,
                    academicYears: [academicYearController.text],
                    durationYears: durationYears,
                  );
                  await service.saveCourse(course);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showCourseSubjectsDialog(course);
                  }
                }
              },
              label: 'Criar',
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignCoordinatorDialog(Course course) {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Atribuir Coordenador',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<UserModel>>(
              stream: service.getUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final teachers = snapshot.data!
                    .where((u) => u.role == UserRole.teacher || u.role == UserRole.courseCoordinator)
                    .toList();
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = teachers[index];
                    return ListTile(
                      title: Text(teacher.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(teacher.email,
                          style: const TextStyle(color: Colors.white54)),
                      onTap: () async {
                        await service.assignCourseCoordinator(
                            course.id, teacher.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCyclesAndInstitutionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ManagementDocumentSection(
          ownerId: 'institution_main',
          ownerType: ManagementDocumentOwnerType.institution,
          title: 'Documentação Institucional (Constituição, etc.)',
        ),
        const SizedBox(height: 32),
        const Text('Ciclos de Estudo',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<List<StudyCycle>>(
          stream: context
              .read<FirebaseService>()
              .getStudyCycles(widget.institution.id),
          builder: (context, snapshot) {
            final cycles = snapshot.data ?? [];
            if (cycles.isEmpty) {
              return const Text('Nenhum ciclo definido.',
                  style: TextStyle(color: Colors.white54));
            }

            return Column(
              children: cycles
                  .map((cycle) => Card(
                        color: const Color(0xFF1E1E2E),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.history_edu,
                              color: Color(0xFF7B61FF)),
                          title: Text(cycle.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: const Text(
                              'Gerir documentos de aprovação e acreditação',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_all,
                                    color: Colors.blueAccent, size: 20),
                                tooltip: 'Duplicar Ciclo',
                                onPressed: () =>
                                    _showDuplicateCycleDialog(cycle),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () =>
                                    _confirmDeleteStudyCycle(cycle),
                                tooltip: 'Eliminar Ciclo',
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.white24),
                            ],
                          ),
                          onTap: () => _showCycleDocsDialog(cycle),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeachersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ManagementDocumentSection(
          ownerId: 'teacher_contracts_global',
          ownerType: ManagementDocumentOwnerType.teacher,
          title: 'Gestão de Contratos de Trabalho',
        ),
        SizedBox(height: 24),
        Text('Fluxo de Assinaturas Pendentes',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(
            'O departamento administrativo pode carregar contratos e selecionar os docentes para assinatura digital.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  void _showCycleDocsDialog(StudyCycle cycle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F1E),
        title: Text('Docs: ${cycle.name}', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: ManagementDocumentSection(
              ownerId: cycle.id,
              ownerType: ManagementDocumentOwnerType.studyCycle,
              title: 'Pasta do Ciclo de Estudos',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showDuplicateCycleDialog(StudyCycle cycle) {
    final service = context.read<FirebaseService>();
    final nameController = TextEditingController(text: '${cycle.name} (Cópia)');
    final yearController = TextEditingController();
    Map<String, String> subjectMappings = {}; // sourceSubjectId -> newTeacherId
    bool isLoading = true;
    List<Course> courses = [];
    List<Subject> subjects = [];
    List<UserModel> teachers = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            // Fetch necessary data
            Future.wait([
              service.getCourses(widget.institution.id).first,
              service.getSubjectsByInstitution(widget.institution.id).first,
              service.getUsers().first,
            ]).then((results) {
              final allCourses = results[0] as List<Course>;
              final allSubjects = results[1] as List<Subject>;
              final allUsers = results[2] as List<UserModel>;

              courses = allCourses.where((c) => c.studyCycleId == cycle.id).toList();
              final courseIds = courses.map((c) => c.id).toSet();
              subjects = allSubjects.where((s) => courseIds.contains(s.courseId)).toList();
              teachers = allUsers
                  .where((u) =>
                      u.role == UserRole.teacher ||
                      u.role == UserRole.courseCoordinator)
                  .toList();

              for (var s in subjects) {
                subjectMappings[s.id] = s.teacherId;
              }

              if (context.mounted) {
                setDialogState(() => isLoading = false);
              }
            });

            return const Center(child: CircularProgressIndicator());
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Text('Duplicar: ${cycle.name}', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Novo Nome do Ciclo',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: yearController.text.isEmpty ? '2024/2025' : yearController.text,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Novo Ano Letivo',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      items: ['2024/2025', '2025/2026', '2026/2027', '2027/2028']
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) yearController.text = v;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Atribuição de Professores:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...subjects.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(s.name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButton<String>(
                                value: subjectMappings[s.id],
                                dropdownColor: const Color(0xFF1E1E2E),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                items: teachers.map((t) {
                                  return DropdownMenuItem(
                                    value: t.id,
                                    child: Text(t.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => subjectMappings[s.id] = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
              CustomButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || yearController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: AiTranslatedText('Preencha o nome e o ano letivo')),
                    );
                    return;
                  }
                  
                  try {
                    await service.duplicateStudyCycle(
                      sourceCycleId: cycle.id,
                      newName: nameController.text,
                      targetAcademicYear: yearController.text,
                      subjectIdToTeacherId: subjectMappings,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: AiTranslatedText('Ciclo duplicado com sucesso!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao duplicar: $e')),
                      );
                    }
                  }
                },
                label: 'Duplicar Agora',
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteStudyCycle(StudyCycle cycle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Anular Ciclo de Estudos',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Tem certeza que deseja anular o ciclo "${cycle.name}"? Esta ação só será permitida se não existirem disciplinas associadas a este ciclo (mesmo em anos letivos diferentes).',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final nav = Navigator.of(context);
                await context.read<FirebaseService>().deleteStudyCycle(cycle.id);
                if (nav.mounted) nav.pop();
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceAll('Exception: ', ''))));
                }
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title:
            const Text('Anular Curso', style: TextStyle(color: Colors.white)),
        content: Text(
            'Tem certeza que deseja anular o curso "${course.name}"? Esta ação só será permitida se não existirem disciplinas registadas.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final nav = Navigator.of(context);
                await context.read<FirebaseService>().deleteCourse(course.id);
                if (nav.mounted) nav.pop();
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceAll('Exception: ', ''))));
                }
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteYear(Course course, String year) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Anular Ano Letivo',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Pretende anular o ano letivo $year do curso ${course.name}? Não será possível se houver disciplinas ativas.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final nav = Navigator.of(context);
                await context
                    .read<FirebaseService>()
                    .deleteAcademicYear(course.id, year);
                if (nav.mounted) nav.pop();
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceAll('Exception: ', ''))));
                }
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  void _showCourseSubjectsDialog(Course course) {
    final service = context.read<FirebaseService>();

    String? filterYear = course.academicYears.isNotEmpty ? course.academicYears.first : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E2E),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Disciplinas: ${course.name}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text('Ciclo: ${course.studyCycleId}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (course.academicYears.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: course.academicYears.map((year) {
                          final isSelected = filterYear == year;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(year),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() => filterYear = year);
                                }
                              },
                              backgroundColor: const Color(0xFF2E2E3E),
                              selectedColor: const Color(0xFF7B61FF),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const Divider(color: Colors.white12, height: 32),
                  Expanded(
                    child: StreamBuilder<List<Subject>>(
                      stream: service.getSubjectsStreamByCourse(course.id),
                      builder: (context, snapshot) {
                        var subjects = snapshot.data ?? [];
                        if (filterYear != null) {
                          subjects = subjects.where((s) => s.academicYear == filterYear).toList();
                        }
                        // Sort by cycle year
                        subjects.sort((a, b) => a.cycleYear.compareTo(b.cycleYear));

                        if (subjects.isEmpty) {
                          return const Center(
                            child: Text('Nenhuma disciplina neste ano letivo.',
                                style: TextStyle(color: Colors.white38)),
                          );
                        }
                        return ListView.builder(
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final sub = subjects[index];
                            return ListTile(
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D1FF).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('Y${sub.cycleYear}',
                                      style: const TextStyle(
                                          color: Color(0xFF00D1FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              title: Text(sub.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  'ECTS: ${sub.ects} | ${sub.academicYear} | Prof: ${sub.teacherId}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  // Logic to remove subject or delete if standalone for this course
                                  // For simplicity, we just delete the subject if it belongs only to this course
                                  await service.deleteSubject(sub.id);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  _AddSubjectForm(course: course, institutionId: widget.institution.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarTab() {
    final service = context.read<FirebaseService>();
    final currentYear = DateFormat('yyyy').format(DateTime.now());
    final nextYear = (int.parse(currentYear) + 1).toString();
    String selectedYear = '$currentYear/$nextYear';

    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<SchoolCalendar?>(
          future: service.getSchoolCalendar(widget.institution.id, selectedYear),
          builder: (context, snapshot) {
            final calendar = snapshot.data;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedYear,
                          dropdownColor: const Color(0xFF1E1E2E),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            '2023/2024',
                            '2024/2025',
                            '2025/2026',
                            '2026/2027'
                          ].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => selectedYear = v);
                          },
                        ),
                      ),
                      if (calendar == null)
                        CustomButton(
                          onPressed: () => _showCalendarSetupWizard(selectedYear),
                          label: 'Configurar Calendário',
                          variant: CustomButtonVariant.secondary,
                          height: 32,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (calendar == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today, size: 48, color: Colors.white24),
                            SizedBox(height: 16),
                            Text('Nenhum calendário configurado para este ano.',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildTermsSection(calendar),
                    const SizedBox(height: 32),
                    _buildHolidaysSection(calendar),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTermsSection(SchoolCalendar calendar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Períodos Letivos',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...calendar.terms.map((term) => GlassCard(
              child: ListTile(
                title: Text(term.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(term.startDate)} - ${DateFormat('dd/MM/yyyy').format(term.endDate)}',
                    style: const TextStyle(color: Colors.white54)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54),
                  onPressed: () => _editTerm(calendar, term),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildHolidaysSection(SchoolCalendar calendar) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Feriados e Pausas',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            CustomButton(
              onPressed: () => _addHoliday(calendar),
              label: 'Adicionar',
              variant: CustomButtonVariant.secondary,
              height: 28,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: calendar.holidays.map((h) => Chip(
            backgroundColor: const Color(0xFF1E1E2E),
            label: Text('${h.name} (${DateFormat('dd/MM').format(h.date)})',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            onDeleted: () => _deleteHoliday(calendar, h),
            deleteIconColor: Colors.redAccent,
          )).toList(),
        ),
      ],
    );
  }

  void _showCalendarSetupWizard(String academicYear) {
    int numPeriods = 2;
    final yearParts = academicYear.split('/');
    final startYear = int.parse(yearParts[0]);
    
    // Default names based on period count
    String getPeriodName(int count, int index) {
      if (count == 2) return '${index + 1}º Semestre';
      if (count == 3) return '${index + 1}º Quadrimestre';
      if (count == 4) return '${index + 1}º Trimestre';
      return 'Período ${index + 1}';
    }

    // Default dates based on period count
    DateTime getStartDate(int count, int index) {
      if (count == 2) {
        return index == 0 ? DateTime(startYear, 9, 1) : DateTime(startYear + 1, 2, 1);
      }
      if (count == 3) {
        if (index == 0) return DateTime(startYear, 9, 1);
        if (index == 1) return DateTime(startYear + 1, 1, 5);
        return DateTime(startYear + 1, 4, 15);
      }
      if (count == 4) {
        if (index == 0) return DateTime(startYear, 9, 1);
        if (index == 1) return DateTime(startYear, 11, 15);
        if (index == 2) return DateTime(startYear + 1, 2, 1);
        return DateTime(startYear + 1, 4, 15);
      }
      return DateTime(startYear, 9, 1);
    }

    DateTime getEndDate(int count, int index) {
       if (count == 2) {
        return index == 0 ? DateTime(startYear, 12, 20) : DateTime(startYear + 1, 6, 30);
      }
      if (count == 3) {
        if (index == 0) return DateTime(startYear, 12, 15);
        if (index == 1) return DateTime(startYear + 1, 3, 30);
        return DateTime(startYear + 1, 6, 30);
      }
      if (count == 4) {
        if (index == 0) return DateTime(startYear, 11, 10);
        if (index == 1) return DateTime(startYear + 1, 1, 25);
        if (index == 2) return DateTime(startYear + 1, 4, 10);
        return DateTime(startYear + 1, 6, 30);
      }
      return DateTime(startYear + 1, 6, 30);
    }

    List<Map<String, dynamic>> periods = List.generate(2, (i) => {
      'name': getPeriodName(2, i),
      'start': getStartDate(2, i),
      'end': getEndDate(2, i),
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final controllers = List.generate(numPeriods, (i) => TextEditingController(text: periods[i]['name']));
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Text('Configurar $academicYear', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de Organização:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: numPeriods,
                      dropdownColor: const Color(0xFF1E1E2E),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 Semestres', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 3, child: Text('3 Quadrimestres', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 4, child: Text('4 Trimestres', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            numPeriods = v;
                            periods = List.generate(numPeriods, (i) => {
                              'name': getPeriodName(numPeriods, i),
                              'start': getStartDate(numPeriods, i),
                              'end': getEndDate(numPeriods, i),
                            });
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Editar Períodos e Datas:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...List.generate(numPeriods, (index) {
                      final p = periods[index];
                      final ctrl = controllers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: ctrl,
                              onChanged: (val) => p['name'] = val,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(labelText: 'Nome do Período'),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    dense: true,
                                    title: const Text('Início', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                    subtitle: Text(DateFormat('dd/MM').format(p['start']), style: const TextStyle(color: Colors.white)),
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate: p['start'],
                                        firstDate: DateTime(startYear, 1, 1),
                                        lastDate: DateTime(startYear + 2, 1, 1),
                                      );
                                      if (d != null) setDialogState(() => p['start'] = d);
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    dense: true,
                                    title: const Text('Fim', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                    subtitle: Text(DateFormat('dd/MM').format(p['end']), style: const TextStyle(color: Colors.white)),
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: ctx,
                                        initialDate: p['end'],
                                        firstDate: DateTime(startYear, 1, 1),
                                        lastDate: DateTime(startYear + 2, 1, 1),
                                      );
                                      if (d != null) setDialogState(() => p['end'] = d);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final calendar = SchoolCalendar(
                    id: academicYear.replaceAll('/', '_'),
                    institutionId: widget.institution.id,
                    academicYear: academicYear,
                    terms: List.generate(numPeriods, (i) => SchoolTerm(
                      id: 't${i + 1}',
                      name: periods[i]['name'],
                      startDate: periods[i]['start'],
                      endDate: periods[i]['end'],
                    )),
                    holidays: [],
                    vacations: [],
                  );
                  await context.read<FirebaseService>().saveSchoolCalendar(calendar);
                  controllers.forEach((c) => c.dispose());
                  if (mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Finalizar'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _editTerm(SchoolCalendar calendar, SchoolTerm term) {
    DateTime start = term.startDate;
    DateTime end = term.endDate;
    final nameController = TextEditingController(text: term.name);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: AiTranslatedText('Editar Período'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const AiTranslatedText('Início', style: TextStyle(color: Colors.white70, fontSize: 12)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(start), style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => start = picked);
                },
              ),
              ListTile(
                title: const AiTranslatedText('Fim', style: TextStyle(color: Colors.white70, fontSize: 12)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(end), style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: end,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => end = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final updatedTerms = calendar.terms.map((t) => t.id == term.id 
                  ? SchoolTerm(id: t.id, name: nameController.text, startDate: start, endDate: end)
                  : t).toList();
                
                final updatedCalendar = SchoolCalendar(
                  id: calendar.id,
                  institutionId: calendar.institutionId,
                  academicYear: calendar.academicYear,
                  terms: updatedTerms,
                  holidays: calendar.holidays,
                  vacations: calendar.vacations,
                );
                await context.read<FirebaseService>().saveSchoolCalendar(updatedCalendar);
                if (mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const AiTranslatedText('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _addHoliday(SchoolCalendar calendar) {
    DateTime date = DateTime.now();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: AiTranslatedText('Adicionar Feriado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome do Feriado'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const AiTranslatedText('Data', style: TextStyle(color: Colors.white70, fontSize: 12)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                
                final newHoliday = Holiday(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  date: date,
                );
                
                final updatedCalendar = SchoolCalendar(
                  id: calendar.id,
                  institutionId: calendar.institutionId,
                  academicYear: calendar.academicYear,
                  terms: calendar.terms,
                  holidays: [...calendar.holidays, newHoliday],
                  vacations: calendar.vacations,
                );
                await context.read<FirebaseService>().saveSchoolCalendar(updatedCalendar);
                if (mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const AiTranslatedText('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _deleteHoliday(SchoolCalendar calendar, Holiday holiday) async {
    final updatedHolidays = calendar.holidays.where((h) => h.id != holiday.id).toList();
    final updatedCalendar = SchoolCalendar(
      id: calendar.id,
      institutionId: calendar.institutionId,
      academicYear: calendar.academicYear,
      terms: calendar.terms,
      holidays: updatedHolidays,
      vacations: calendar.vacations,
    );
    await context.read<FirebaseService>().saveSchoolCalendar(updatedCalendar);
    if (mounted) setState(() {});
  }
}

class _AddSubjectForm extends StatefulWidget {
  final Course course;
  final String institutionId;
  const _AddSubjectForm({required this.course, required this.institutionId});

  @override
  State<_AddSubjectForm> createState() => _AddSubjectFormState();
}

class _AddSubjectFormState extends State<_AddSubjectForm> {
  final _nameController = TextEditingController();
  final _ectsController = TextEditingController(text: '6');
  final _tHoursController = TextEditingController(text: '30');
  final _pHoursController = TextEditingController(text: '30');
  String? _selectedTeacherId;
  String? _selectedYear;
  int _cycleYear = 1;

  bool _attendanceControlEnabled = false;
  final _requiredPercentageController = TextEditingController(text: '75');

  @override
  void initState() {
    super.initState();
    if (widget.course.academicYears.isNotEmpty) {
      _selectedYear = widget.course.academicYears.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nova Disciplina',
            style: TextStyle(
                color: Color(0xFF00D1FF),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ectsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'ECTS',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedYear,
                dropdownColor: const Color(0xFF1E1E2E),
                items: widget.course.academicYears
                    .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedYear = v),
                decoration: const InputDecoration(
                    labelText: 'Ano',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _cycleYear,
                dropdownColor: const Color(0xFF1E1E2E),
                items: List.generate(10, (index) => index + 1)
                    .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('Ano $y',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() => _cycleYear = v ?? 1),
                decoration: const InputDecoration(
                    labelText: 'Ciclo Yr',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tHoursController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'Horas T',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pHoursController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                    labelText: 'Horas P',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FutureBuilder<List<UserModel>>(
                future: service.getAllInstitutionMembers(widget.institutionId),
                builder: (context, snapshot) {
                  final teachers = (snapshot.data ?? [])
                      .where((u) => u.role == UserRole.teacher || u.role == UserRole.courseCoordinator)
                      .toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedTeacherId,
                    dropdownColor: const Color(0xFF1E1E2E),
                    hint: const Text('Professor',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    items: teachers
                        .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTeacherId = v),
                    decoration: const InputDecoration(
                        labelText: 'Docente',
                        labelStyle: TextStyle(color: Colors.white54)),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Controlo de Faltas',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                value: _attendanceControlEnabled,
                onChanged: (v) =>
                    setState(() => _attendanceControlEnabled = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF00D1FF),
                checkColor: Colors.black,
              ),
            ),
            if (_attendanceControlEnabled)
              Expanded(
                child: TextField(
                  controller: _requiredPercentageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: '% Presença Obrigatória',
                    labelStyle: TextStyle(color: Colors.white54),
                    suffixText: '%',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty &&
                  _selectedTeacherId != null &&
                  _selectedYear != null) {
                final sub = Subject(
                  id: const Uuid().v4(),
                  name: _nameController.text,
                  level: 'Curso: ${widget.course.name}',
                  academicYear: _selectedYear!,
                  teacherId: _selectedTeacherId!,
                  institutionId: widget.institutionId,
                  courseId: widget.course.id,
                  cycleYear: _cycleYear,
                  allowedStudentEmails: [],
                  contents: [],
                  games: [],
                  evaluationComponents: [],
                  ects: double.tryParse(_ectsController.text) ?? 6.0,
                  theoreticalHours: double.tryParse(_tHoursController.text) ?? 30.0,
                  practicalHours: double.tryParse(_pHoursController.text) ?? 30.0,
                  attendanceControlEnabled: _attendanceControlEnabled,
                  requiredAttendancePercentage: double.tryParse(_requiredPercentageController.text) ?? 75.0,
                );
                await service.updateSubject(sub);
                
                // Also update course to include this subjectId
                final updatedCourse = Course(
                  id: widget.course.id,
                  name: widget.course.name,
                  studyCycleId: widget.course.studyCycleId,
                  institutionId: widget.course.institutionId,
                  subjectIds: [...widget.course.subjectIds, sub.id],
                  academicYears: widget.course.academicYears,
                  coordinatorId: widget.course.coordinatorId,
                  delegateId: widget.course.delegateId,
                  durationYears: widget.course.durationYears,
                );
                await service.saveCourse(updatedCourse);

                _nameController.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Disciplina adicionada com sucesso!')),
                  );
                }
                setState(() {}); // Refresh form
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D1FF)),
            child: const Text('Adicionar Disciplina'),
          ),
        ),
      ],
    );
  }
}
