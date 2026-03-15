import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/course_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';

class AcademicManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const AcademicManagementScreen({super.key, required this.institution});

  @override
  State<AcademicManagementScreen> createState() => _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Gestão Académica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            onPressed: () => _showAddProgramDialog(context, service),
            tooltip: 'Carregar Programas',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSectionHeader(
              title: 'Ciclos de Estudo',
              onAdd: () => _showAddCycleDialog(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 1,
              child: StreamBuilder<List<StudyCycle>>(
                stream: service.getStudyCycles(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final cycles = snapshot.data!;
                  if (cycles.isEmpty) return const Center(child: AiTranslatedText('Nenhum ciclo criado.', style: TextStyle(color: Colors.white54)));
                  
                  return ListView.builder(
                    itemCount: cycles.length,
                    itemBuilder: (context, index) => _CycleListTile(cycle: cycles[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
              title: 'Cursos',
              onAdd: () => _showAddCourseDialog(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 2,
              child: StreamBuilder<List<Course>>(
                stream: service.getCourses(widget.institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final courses = snapshot.data!;
                  if (courses.isEmpty) return const Center(child: AiTranslatedText('Nenhum curso criado.', style: TextStyle(color: Colors.white54)));

                  return ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (context, index) => _CourseListTile(course: courses[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AiTranslatedText(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: Color(0xFF00D1FF)),
        ),
      ],
    );
  }

  void _showAddCycleDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Ciclo de Estudo', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nome do Ciclo (ex: Mestrado)', labelStyle: TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              final cycle = StudyCycle(
                id: const Uuid().v4(),
                name: controller.text.trim(),
                institutionId: widget.institution.id,
              );
              await context.read<FirebaseService>().saveStudyCycle(cycle);
              if (mounted) Navigator.pop(ctx);
            },
            child: const AiTranslatedText('Criar'),
          ),
        ],
      ),
    );
  }

  void _showAddProgramDialog(BuildContext context, FirebaseService service) {
    String? selectedCourseId;
    final programController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Carregar Programa de Disciplina', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<Course>>(
                stream: service.getCourses(widget.institution.id),
                builder: (context, snapshot) {
                  final courses = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Curso', labelStyle: TextStyle(color: Colors.white70)),
                    items: courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCourseId = val),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: programController,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Conteúdo do Programa',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'Insira aqui o programa detalhado da disciplina...',
                ),
              ),
              const SizedBox(height: 8),
              const AiTranslatedText('O programa será visível para todos os professores desta disciplina.', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCourseId == null || programController.text.isEmpty) return;
                // In a real app, logic to save this program to the specific course/subject
                // and update all related Subject objects for teachers.
                await service.saveInstitutionalProgram(widget.institution.id, selectedCourseId!, programController.text);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const AiTranslatedText('Carregar'),
            ),
          ],
        ),
      ),
    );
  }
  void _showAddCourseDialog(BuildContext context) {
    final controller = TextEditingController();
    String? selectedCycleId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Adicionar Novo Curso', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<List<StudyCycle>>(
                stream: context.read<FirebaseService>().getStudyCycles(widget.institution.id),
                builder: (context, snapshot) {
                  final cycles = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: selectedCycleId,
                    items: cycles.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCycleId = val),
                    decoration: const InputDecoration(labelText: 'Ciclo de Estudo', labelStyle: TextStyle(color: Colors.white70)),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome do Curso', labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isEmpty || selectedCycleId == null) return;
                final course = Course(
                  id: const Uuid().v4(),
                  name: controller.text.trim(),
                  studyCycleId: selectedCycleId!,
                  institutionId: widget.institution.id,
                );
                await context.read<FirebaseService>().saveCourse(course);
                if (!mounted) return;
                Navigator.pop(ctx);
              },
              child: const AiTranslatedText('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleListTile extends StatelessWidget {
  final StudyCycle cycle;
  const _CycleListTile({required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(cycle.name, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.settings, color: Colors.white24),
      ),
    );
  }
}

class _CourseListTile extends StatelessWidget {
  final Course course;
  const _CourseListTile({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(course.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: AiTranslatedText('Clique para gerir disciplinas', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () {
          // Future: Navigate to Course Subject Management
        },
      ),
    );
  }
}
