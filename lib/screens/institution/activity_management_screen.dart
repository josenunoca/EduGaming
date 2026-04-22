import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity_model.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'activity_details_screen.dart';
import 'activity_report_screen.dart';
import '../../widgets/ai_text_field.dart';

class ActivityManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const ActivityManagementScreen({super.key, required this.institution});

  @override
  State<ActivityManagementScreen> createState() =>
      _ActivityManagementScreenState();
}

class _ActivityManagementScreenState extends State<ActivityManagementScreen> {
  String? selectedResponsibleFilter;
  String? selectedGroupFilter;
  String? selectedStatusFilter;
  String? selectedAcademicYearFilter = '2024/2025';

  static const List<String> activityGroups = [
    'Atividades Curriculares',
    'Atividades Extra-Curriculares',
    'Atividades Oficiais',
    'Convívios',
    'Conferências',
    'Outras Atividades',
  ];

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Gestão de Atividades'),
        actions: [
          StreamBuilder<List<InstitutionalActivity>>(
              stream: service.getActivities(widget.institution.id),
              builder: (context, snapshot) {
                final activities = snapshot.data ?? [];
                return IconButton(
                  icon: const Icon(Icons.analytics),
                  tooltip: 'Gerar Relatório Anual',
                  onPressed: activities.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActivityReportScreen(activities: activities, institution: widget.institution),
                            ),
                          );
                        },
                );
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(onAdd: () => _showActivityFormDialog(context), service: service),
            const SizedBox(height: 16),
            _buildFilterBar(service),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<InstitutionalActivity>>(
                stream: service.getActivities(
                  widget.institution.id,
                  responsibleUserId: selectedResponsibleFilter,
                  activityGroup: selectedGroupFilter,
                  status: selectedStatusFilter,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Sorting: planned first, then closest startDate first
                  final activities = snapshot.data!;
                  activities.sort((a, b) {
                    if (a.status == 'planned' && b.status == 'completed') return -1;
                    if (a.status == 'completed' && b.status == 'planned') return 1;
                    return a.startDate.compareTo(b.startDate);
                  });

                  if (activities.isEmpty) {
                    return const Center(
                        child: AiTranslatedText('Nenhuma atividade encontrada.',
                            style: TextStyle(color: Colors.white54)));
                  }

                  // If filtering by group, only show that group
                  final List<String> groupNames = selectedGroupFilter != null 
                    ? [selectedGroupFilter!] 
                    : activityGroups;

                  // Group activities
                  final Map<String, List<InstitutionalActivity>> grouped = {};
                  for (var group in groupNames) {
                    grouped[group] = activities
                        .where((a) => a.activityGroup == group)
                        .where((a) => selectedAcademicYearFilter == null || a.academicYear == selectedAcademicYearFilter)
                        .toList();
                  }

                  return ListView(
                    children: groupNames.map((groupName) {
                      final groupActivities = grouped[groupName] ?? [];
                      if (groupActivities.isEmpty && selectedGroupFilter == null) return const SizedBox.shrink();
                      return _buildGroupSection(
                        context,
                        groupName,
                        groupActivities,
                        service,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(FirebaseService service) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Responsible Filter
          StreamBuilder<List<UserModel>>(
            stream: service.getCollaboratorsByInstitution(widget.institution.id),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              return _buildFilterDropdown<String?>(
                label: 'Responsável',
                value: selectedResponsibleFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (val) => setState(() => selectedResponsibleFilter = val),
              );
            },
          ),
          const SizedBox(width: 8),
          // Group Filter
          _buildFilterDropdown<String?>(
            label: 'Tipo',
            value: selectedGroupFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ...activityGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))),
            ],
            onChanged: (val) => setState(() => selectedGroupFilter = val),
          ),
          const SizedBox(width: 8),
          // Status Filter
          _buildFilterDropdown<String?>(
            label: 'Estado',
            value: selectedStatusFilter,
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: 'planned', child: Text('Em Curso')),
              DropdownMenuItem(value: 'completed', child: Text('Concluída')),
            ],
            onChanged: (val) => setState(() => selectedStatusFilter = val),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(Icons.filter_list, size: 16, color: Colors.white54),
          hint: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    String groupName,
    List<InstitutionalActivity> activities,
    FirebaseService service,
  ) {
    return DragTarget<InstitutionalActivity>(
      onWillAcceptWithDetails: (details) =>
          details.data.activityGroup != groupName,
      onAcceptWithDetails: (details) async {
        final activity = details.data;
        final updated = InstitutionalActivity(
          id: activity.id,
          title: activity.title,
          description: activity.description,
          institutionId: activity.institutionId,
          startDate: activity.startDate,
          endDate: activity.endDate,
          startTime: activity.startTime,
          endTime: activity.endTime,
          activityGroup: groupName,
          hasFinancialImpact: activity.hasFinancialImpact,
          resources: activity.resources,
          participants: activity.participants,
          media: activity.media,
          goals: activity.goals,
          financials: activity.financials,
          indicators: activity.indicators,
          status: activity.status,
        );
        await service.saveActivity(updated);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Atividade movida para $groupName'.toUpperCase())),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? const Color(0xFF7B61FF).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getGroupIcon(groupName),
                    color: const Color(0xFF7B61FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    groupName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Arraste atividades para aqui',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ),
              ),
            ...activities.map((a) => Draggable<InstitutionalActivity>(
                  data: a,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 300,
                      child: _ActivityCard(
                        activity: a,
                        onTap: () {},
                        isFeedback: true,
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _ActivityCard(activity: a, onTap: () {}),
                  ),
                  child: _ActivityCard(
                    activity: a,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailsScreen(activity: a, institution: widget.institution),
                      ),
                    ),
                    onEdit: () => _showActivityFormDialog(context, activity: a),
                    onDuplicate: () => service.duplicateActivity(a.id, a.startDate.add(const Duration(days: 7)), a.endDate.add(const Duration(days: 7))),
                    onDelete: () => _confirmDeleteActivity(context, a, service),
                    onComplete: () async {
                      final updated = InstitutionalActivity(
                        id: a.id,
                        title: a.title,
                        description: a.description,
                        institutionId: a.institutionId,
                        startDate: a.startDate,
                        endDate: a.endDate,
                        startTime: a.startTime,
                        endTime: a.endTime,
                        activityGroup: a.activityGroup,
                        academicYear: a.academicYear,
                        hasFinancialImpact: a.hasFinancialImpact,
                        resources: a.resources,
                        participants: a.participants,
                        media: a.media,
                        goals: a.goals,
                        financials: a.financials,
                        indicators: a.indicators,
                        status: 'completed',
                        responsibleName: a.responsibleName,
                        responsibleEmail: a.responsibleEmail,
                        responsiblePhone: a.responsiblePhone,
                        responsibleUserId: a.responsibleUserId,
                      );
                      await service.saveActivity(updated);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ATIVIDADE CONCLUÍDA')),
                        );
                      }
                    },
                  ),
                )),
          ],
        );
      },
    );
  }

  IconData _getGroupIcon(String groupName) {
    switch (groupName) {
      case 'Atividades Curriculares':
        return Icons.school;
      case 'Atividades Extra-Curriculares':
        return Icons.sports_soccer;
      case 'Atividades Oficiais':
        return Icons.verified_user;
      case 'Convívios':
        return Icons.groups;
      case 'Conferências':
        return Icons.record_voice_over;
      default:
        return Icons.category;
    }
  }


  void _confirmDeleteActivity(BuildContext context, InstitutionalActivity activity, FirebaseService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar Atividade'),
        content: Text('Tem a certeza que pretende eliminar a atividade "${activity.title}"? Esta ação não pode ser desfeita.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await service.deleteActivity(activity.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const AiTranslatedText('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllActivities(BuildContext context, FirebaseService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar Todas as Atividades'),
        content: const Text('Tem a certeza que pretende eliminar TODAS as atividades deste ano letivo? Esta ação não pode ser desfeita.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await service.deleteAllActivities(widget.institution.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const AiTranslatedText('Eliminar Todas'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActivitiesByGroup(BuildContext context, String group, FirebaseService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Eliminar: $group', style: const TextStyle(color: Colors.white)),
        content: Text('Tem a certeza que pretende eliminar todas as atividades do grupo "$group"? Esta ação não pode ser desfeita.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await service.deleteAllActivitiesByGroup(widget.institution.id, group);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const AiTranslatedText('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required VoidCallback onAdd, required FirebaseService service}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Plano de Atividades',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            AiTranslatedText(
              'Ano Letivo ${DateTime.now().year}/${DateTime.now().year + 1}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Eliminar Atividades',
              color: const Color(0xFF1E293B),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Eliminar Todas as Atividades', style: TextStyle(color: Colors.redAccent)),
                ),
                const PopupMenuDivider(),
                ...activityGroups.map((g) => PopupMenuItem(
                  value: g,
                  child: Text('Eliminar: $g', style: const TextStyle(color: Colors.white)),
                )),
              ],
              onSelected: (value) {
                if (value == 'all') {
                  _confirmDeleteAllActivities(context, service);
                } else {
                  _confirmDeleteActivitiesByGroup(context, value, service);
                }
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const AiTranslatedText('Nova Atividade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showActivityFormDialog(BuildContext context, {InstitutionalActivity? activity}) {
    final isEditing = activity != null;
    final titleController = TextEditingController(text: activity?.title);
    final descController = TextEditingController(text: activity?.description);
    final respNameController = TextEditingController(text: activity?.responsibleName);
    final respEmailController = TextEditingController(text: activity?.responsibleEmail);
    final respPhoneController = TextEditingController(text: activity?.responsiblePhone);
    String? selectedResponsibleUserId = activity?.responsibleUserId;
    UserModel? selectedResponsibleUser; // We'll need to fetch this if we have a UID
    
    String selectedGroup = activity?.activityGroup ?? activityGroups.last;
    DateTime startDate = activity?.startDate ?? DateTime.now();
    DateTime endDate = activity?.endDate ?? DateTime.now();
    bool hasFinancialImpact = activity?.hasFinancialImpact ?? false;
    bool includeInAnnualReport = activity?.includeInAnnualReport ?? false;
    String? targetCourseId = activity?.targetCourseId;
    bool isControlActivity = activity?.isControlActivity ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: AiTranslatedText(isEditing ? 'Editar Atividade' : 'Planear Atividade',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AiTextField(
                  controller: titleController,
                  labelText: 'Título da Atividade',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGroup,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Grupo de Atividade',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: activityGroups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedGroup = val!),
                ),
                const SizedBox(height: 16),
                AiTextField(
                  controller: descController,
                  maxLines: 3,
                  labelText: 'Objetivos',
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const AiTranslatedText('Data Início',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  subtitle: Text(
                      "${startDate.day}/${startDate.month}/${startDate.year}",
                      style: const TextStyle(color: Colors.white)),
                  trailing:
                      const Icon(Icons.calendar_today, color: Colors.white54),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setDialogState(() => startDate = date);
                  },
                ),
                ListTile(
                  title: const AiTranslatedText('Data Fim',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  subtitle: Text(
                      "${endDate.day}/${endDate.month}/${endDate.year}",
                      style: const TextStyle(color: Colors.white)),
                  trailing:
                      const Icon(Icons.calendar_today, color: Colors.white54),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                      firstDate: DateTime(startDate.year, startDate.month, startDate.day),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setDialogState(() => endDate = date);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AiTranslatedText('Configurações de Relatório',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const AiTranslatedText('Incluir no Relatório Anual',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: includeInAnnualReport,
                  onChanged: (val) => setDialogState(() => includeInAnnualReport = val),
                  activeColor: const Color(0xFF7B61FF),
                ),
                SwitchListTile(
                  title: const AiTranslatedText('Atividade de Controlo (Prazos)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: isControlActivity,
                  onChanged: (val) => setDialogState(() => isControlActivity = val),
                  activeColor: const Color(0xFF7B61FF),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Course>>(
                  stream: context.read<FirebaseService>().getCoursesStream(widget.institution.id),
                  builder: (context, snapshot) {
                    final courses = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      value: targetCourseId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Associar a um Curso',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Nenhum (Institucional)')),
                        ...courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setDialogState(() => targetCourseId = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AiTranslatedText('Responsável pela Atividade',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<UserModel>>(
                  stream: context.read<FirebaseService>().getCollaboratorsByInstitution(widget.institution.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final users = snapshot.data ?? [];
                    
                    // Try to resolve the user object if we have a UID and users list
                    if (selectedResponsibleUserId != null && selectedResponsibleUser == null) {
                        selectedResponsibleUser = users.where((u) => u.id == selectedResponsibleUserId).firstOrNull;
                    }

                    return DropdownButtonFormField<String?>(
                      value: selectedResponsibleUserId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Colaborador Registado na Instituição'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Externo (Registo Manual)')),
                        ...users.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.email})'))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedResponsibleUserId = val;
                          if (val != null) {
                            selectedResponsibleUser = users.firstWhere((usr) => usr.id == val);
                            respNameController.text = selectedResponsibleUser!.name;
                            respEmailController.text = selectedResponsibleUser!.email;
                            respPhoneController.text = selectedResponsibleUser!.phone ?? '';
                          } else {
                            selectedResponsibleUser = null;
                            respNameController.clear();
                            respEmailController.clear();
                            respPhoneController.clear();
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (selectedResponsibleUserId == null) ...[
                  AiTextField(
                    controller: respNameController,
                    labelText: 'Nome do Responsável',
                  ),
                  const SizedBox(height: 12),
                  AiTextField(
                    controller: respEmailController,
                    labelText: 'Email do Responsável (Opcional)',
                  ),
                  const SizedBox(height: 12),
                  AiTextField(
                    controller: respPhoneController,
                    labelText: 'Telefone do Responsável (Opcional)',
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nome: ${selectedResponsibleUser?.name ?? activity?.responsibleName}', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('Email: ${selectedResponsibleUser?.email ?? activity?.responsibleEmail}', style: const TextStyle(color: Colors.white70)),
                        if ((selectedResponsibleUser?.phone ?? activity?.responsiblePhone) != null) ...[
                          const SizedBox(height: 4),
                          Text('Telemóvel: ${selectedResponsibleUser?.phone ?? activity?.responsiblePhone}', style: const TextStyle(color: Colors.white70)),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const AiTranslatedText('Impacto Financeiro',
                      style: TextStyle(color: Colors.white70)),
                  value: hasFinancialImpact,
                  activeThumbColor: const Color(0xFF7B61FF),
                  onChanged: (val) =>
                      setDialogState(() => hasFinancialImpact = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                final newActivity = InstitutionalActivity(
                  id: activity?.id ?? const Uuid().v4(),
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  institutionId: widget.institution.id,
                  activityGroup: selectedGroup,
                  startDate: startDate,
                  endDate: endDate,
                  startTime: activity?.startTime ?? '09:00',
                  endTime: activity?.endTime ?? '17:00',
                  hasFinancialImpact: hasFinancialImpact,
                  includeInAnnualReport: includeInAnnualReport,
                  targetCourseId: targetCourseId,
                  isControlActivity: isControlActivity,
                  responsibleName: respNameController.text.trim().isEmpty ? null : respNameController.text.trim(),
                  responsibleEmail: respEmailController.text.trim().isEmpty ? null : respEmailController.text.trim(),
                  responsiblePhone: respPhoneController.text.trim().isEmpty ? null : respPhoneController.text.trim(),
                  responsibleUserId: selectedResponsibleUserId,
                  status: activity?.status ?? 'planned',
                  participants: activity?.participants ?? [],
                  media: activity?.media ?? [],
                  indicators: activity?.indicators ?? {},
                  goals: activity?.goals ?? [],
                  resources: activity?.resources ?? [],
                );
                await context.read<FirebaseService>().saveActivity(newActivity);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: AiTranslatedText(isEditing ? 'Guardar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final InstitutionalActivity activity;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onComplete;
  final bool isFeedback;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.onComplete,
    this.isFeedback = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = activity.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: GlassCard(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isCompleted ? Colors.green : const Color(0xFF7B61FF)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.event_available,
                  color: isCompleted ? Colors.greenAccent : const Color(0xFF7B61FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        color: isCompleted ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          "${activity.startDate.day}/${activity.startDate.month} - ${activity.endDate.day}/${activity.endDate.month}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        if (activity.responsibleName != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.person, size: 10, color: Colors.white38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              activity.responsibleName!,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isFeedback) ...[
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white24, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                if (onDuplicate != null)
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white24, size: 18),
                    onPressed: onDuplicate,
                    tooltip: 'Duplicar',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                  ),
                if (!isCompleted && onComplete != null)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                    onPressed: onComplete,
                    tooltip: 'Concluir',
                  ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
