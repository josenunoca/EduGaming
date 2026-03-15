import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/firebase_service.dart';
import '../../models/course_model.dart';
import '../../models/meeting_model.dart';
import '../../models/institution_model.dart';
import '../../models/institutional_organ_model.dart';
import '../../models/council_request_model.dart';
import '../../models/organ_document_model.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../widgets/management_document_section.dart';
import '../../models/management_document_model.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
            Tab(text: 'Ciclos e Inst.'),
            Tab(text: 'Conselhos'),
            Tab(text: 'Órgãos'),
            Tab(text: 'Docentes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoursesTab(),
          _buildCyclesAndInstitutionTab(),
          _buildMeetingsTab(),
          _buildOrgansTab(),
          _buildTeachersTab(),
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
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateCycleDialog(),
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Novo Ciclo'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E2E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateCourseDialog(),
                      icon: const Icon(Icons.school),
                      label: const Text('Criar Curso'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF)),
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
                        .map((cycle) => ActionChip(
                              backgroundColor: const Color(0xFF1E1E2E),
                              avatar: const Icon(Icons.description, size: 16, color: Colors.white54),
                              label: Text(cycle.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              onPressed: () => _showCycleDocsDialog(cycle),
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
                      subtitle: Text(
                          'Ciclo: ${course.studyCycleId} | Anos: ${course.academicYears.length}',
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                      iconColor: Colors.white,
                      collapsedIconColor: Colors.white,
                      children: [
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
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white54),
                                onPressed: () =>
                                    _showAssignCoordinatorDialog(course),
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
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                service.ensureAcademicYear(course.id),
                            icon: const Icon(Icons.add),
                            label: const Text('Gerar Próximo Ano Letivo'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B61FF)
                                    .withValues(alpha: 0.5)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Novo Ciclo de Estudos',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText: 'Nome (ex: Mestrado)',
              labelStyle: TextStyle(color: Colors.white54)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final cycle = StudyCycle(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  institutionId: widget.institution.id,
                );
                await service.saveStudyCycle(cycle);
                Navigator.pop(context);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showCreateCourseDialog() {
    final service = context.read<FirebaseService>();
    final nameController = TextEditingController();
    String? selectedCycleId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title:
              const Text('Novo Curso', style: TextStyle(color: Colors.white)),
          content: Column(
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
                    initialValue: selectedCycleId,
                    hint: const Text('Selecionar Ciclo',
                        style: TextStyle(color: Colors.white54)),
                    items: cycles
                        .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name,
                                style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (v) => setState(() => selectedCycleId = v),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && selectedCycleId != null) {
                  final course = Course(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    studyCycleId: selectedCycleId!,
                    institutionId: widget.institution.id,
                    academicYears: ["2024/2025"],
                  );
                  await service.saveCourse(course);
                  Navigator.pop(context);
                }
              },
              child: const Text('Criar'),
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
                    .where((u) => u.role == UserRole.teacher)
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
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () =>
                                    _confirmDeleteStudyCycle(cycle),
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

  Widget _buildMeetingsTab() {
    final service = context.read<FirebaseService>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            label: const Text('Agendar Reunião de Conselho'),
            onPressed: () => _showOrganSelectionForMeeting(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AcademicMeeting>>(
            stream: service.getAcademicMeetings(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final meetings = snapshot.data!;
              if (meetings.isEmpty) {
                return const Center(
                    child: Text('Nenhuma reunião agendada.',
                        style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: meetings.length,
                itemBuilder: (context, index) {
                  final meeting = meetings[index];
                  return Card(
                    color: const Color(0xFF1E1E2E),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(meeting.title,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(meeting.date),
                          style: const TextStyle(color: Colors.white54)),
                      trailing: Icon(
                          meeting.isFinalized
                              ? Icons.check_circle
                              : Icons.pending,
                          color: meeting.isFinalized
                              ? Colors.green
                              : Colors.orange),
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

  void _showOrganSelectionForMeeting() {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<InstitutionalOrgan>>(
          stream: service.getInstitutionalOrgans(widget.institution.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final organs = snapshot.data!;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Escolha o Órgão',
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: organs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(organs[index].name,
                          style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateMeetingDialog(organs[index]);
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateMeetingDialog(InstitutionalOrgan organ) {
    final service = context.read<FirebaseService>();
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final customPointController = TextEditingController();
    List<String> selectedRequestIds = [];
    List<String> customPoints = [];
    String convocationText = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: Text('Agendar: ${organ.name}',
                  style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Título da Reunião',
                          labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    TextField(
                      controller: locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Localização',
                          labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Temas Solicitados:',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    StreamBuilder<List<CouncilRequest>>(
                      stream: service.getPendingRequestsByOrgan(organ.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final requests = snapshot.data!;
                        return Column(
                          children: requests
                              .map((req) => CheckboxListTile(
                                    title: Text(req.title,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14)),
                                    value: selectedRequestIds.contains(req.id),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          selectedRequestIds.add(req.id);
                                        } else {
                                          selectedRequestIds.remove(req.id);
                                        }
                                      });
                                    },
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customPointController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                                labelText: 'Ponto Adicional',
                                labelStyle: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            if (customPointController.text.isNotEmpty) {
                              setState(() {
                                customPoints.add(customPointController.text);
                                customPointController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final tempMeeting = AcademicMeeting(
                          id: 'temp',
                          title: titleController.text,
                          institutionId: widget.institution.id,
                          organId: organ.id,
                          date: DateTime.now(),
                          customAgendaPoints: customPoints,
                          location: locationController.text,
                        );
                        final aiText = await service
                            .generateConvocationWithAi(tempMeeting);
                        setState(() => convocationText = aiText);
                      },
                      icon: const Icon(Icons.psychology),
                      label: const Text('Gerar Convocatória AI'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey),
                    ),
                    if (convocationText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(convocationText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty) {
                      final meeting = AcademicMeeting(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text,
                        institutionId: widget.institution.id,
                        organId: organ.id,
                        date: DateTime.now().add(const Duration(days: 7)),
                        requestedTopicIds: selectedRequestIds,
                        customAgendaPoints: customPoints,
                        location: locationController.text,
                        convocationText: convocationText,
                      );
                      await service.scheduleMeetingAndNotify(meeting);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirmar Agendamento'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOrgansTab() {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<InstitutionalOrgan>>(
      stream: service.getInstitutionalOrgans(widget.institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final organs = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: organs.length,
          itemBuilder: (context, index) {
            final organ = organs[index];
            return Card(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(organ.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${organ.members.length} Membros',
                    style: const TextStyle(color: Colors.white54)),
                children: [
                  ManagementDocumentSection(
                    ownerId: organ.id,
                    ownerType: ManagementDocumentOwnerType.organ,
                    title: 'Gestão de Atas e Documentos',
                  ),
                  const Divider(color: Colors.white10),
                  ...organ.members.map((m) => ListTile(
                        title: Text(m.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${m.email} | ${m.function ?? "Membro"}',
                            style: const TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                      )),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showInviteDialog(organ),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Convidar Membro'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B61FF)),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showPublishDocumentDialog(organ),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Publicar Doc'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteDialog(InstitutionalOrgan organ) {
    final service = context.read<FirebaseService>();
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedFunction = 'membro';
    final functions = [
      'presidente',
      'vice-presidente',
      'vogal',
      'secretário',
      'membro'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text('Convidar para ${organ.name}',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E1E2E),
                initialValue: selectedFunction,
                items: functions
                    .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.toUpperCase(),
                            style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) => setState(() => selectedFunction = v!),
                decoration: const InputDecoration(
                    labelText: 'Função/Cargo',
                    labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.contains('@') &&
                    nameController.text.isNotEmpty) {
                  final member = OrganMember(
                    email: emailController.text.trim(),
                    name: nameController.text.trim(),
                    function: selectedFunction,
                  );
                  // Update organ members list
                  final updatedMembers = List<OrganMember>.from(organ.members)
                    ..add(member);
                  await service.updateOrgan(organ.id, {
                    'members': updatedMembers.map((m) => m.toMap()).toList()
                  });

                  await service.sendExternalInvite(
                    email: emailController.text.trim(),
                    institutionId: widget.institution.id,
                    organId: organ.id,
                    invitedBy: widget.institution.id,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Convidar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublishDocumentDialog(InstitutionalOrgan organ) {
    final service = context.read<FirebaseService>();
    final titleController = TextEditingController();
    OrganDocumentType selectedType = OrganDocumentType.minutes;
    bool isVisibleToAll = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Publicar Documento',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<OrganDocumentType>(
                dropdownColor: const Color(0xFF1E1E2E),
                initialValue: selectedType,
                items: OrganDocumentType.values
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase(),
                            style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) => setState(() => selectedType = v!),
                decoration: const InputDecoration(
                    labelText: 'Tipo',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              SwitchListTile(
                title: const Text('Visível para todos',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                value: isVisibleToAll,
                onChanged: (v) => setState(() => isVisibleToAll = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final doc = OrganDocument(
                    id: const Uuid().v4(),
                    organId: organ.id,
                    title: titleController.text,
                    type: selectedType,
                    isVisibleToAllMembers: isVisibleToAll,
                    createdBy: 'admin',
                    createdAt: DateTime.now(),
                  );
                  await service.saveOrganDocument(doc);
                  Navigator.pop(context);
                }
              },
              child: const Text('Publicar'),
            ),
          ],
        ),
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
            'Tem certeza que deseja anular o ciclo "${cycle.name}"? Esta ação só será permitida se não existirem cursos associados.',
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
}
