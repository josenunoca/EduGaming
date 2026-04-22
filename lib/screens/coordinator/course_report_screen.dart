import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../models/activity_model.dart';
import '../../models/course_report_model.dart';
import '../../services/firebase_service.dart';
import '../../services/reporting_service.dart';
import '../../services/report_pdf_generator.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class CourseReportScreen extends StatefulWidget {
  final Course course;

  const CourseReportScreen({super.key, required this.course});

  @override
  State<CourseReportScreen> createState() => _CourseReportScreenState();
}

class _CourseReportScreenState extends State<CourseReportScreen> {
  String _academicYear = '2024/2025'; // Default fallback
  bool _isLoading = true;
  CourseReport? _currentReport;
  final Map<int, TextEditingController> _contentControllers = {};

  @override
  void initState() {
    super.initState();
    _loadOrCreateReport();
  }

  Future<void> _loadOrCreateReport() async {
    final service = context.read<FirebaseService>();
    final reporting = context.read<ReportingService>();

    // 1. Get Dynamic Academic Year
    _academicYear = await service.getCurrentAcademicYear(widget.course.institutionId);

    // 2. Try to find existing report
    service.getCourseReportsStream(widget.course.id).first.then((reports) async {
      final existing = reports.where((r) => r.academicYear == _academicYear).firstOrNull;
      
      if (existing != null) {
        setState(() {
          _currentReport = existing;
          for (int i = 0; i < existing.sections.length; i++) {
            _contentControllers[i] = TextEditingController(text: existing.sections[i].content);
          }
          _isLoading = false;
        });
      } else {
        // Create new based on snapshot
        final snapshot = await reporting.getCourseReportSnapshot(widget.course.id, _academicYear);
        setState(() {
          _currentReport = CourseReport(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            courseId: widget.course.id,
            institutionId: widget.course.institutionId,
            academicYear: _academicYear,
            title: 'Relatório de Curso - ${widget.course.name}',
            description: 'Relatório gerado automaticamente para o ano lectivo $_academicYear',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            snapshotMetrics: snapshot,
            sections: [
              ReportSection(title: 'Introdução e Objetivos', content: ''),
              ReportSection(title: 'Análise de Resultados e Avaliação', content: ''),
              ReportSection(title: 'Propostas de Melhoria', content: ''),
            ],
            selectedActivityPhotoUrls: [],
          );
          for (int i = 0; i < _currentReport!.sections.length; i++) {
            _contentControllers[i] = TextEditingController();
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _saveReport() async {
    if (_currentReport == null) return;

    final updatedSections = <ReportSection>[];
    for (int i = 0; i < _currentReport!.sections.length; i++) {
      updatedSections.add(ReportSection(
        title: _currentReport!.sections[i].title,
        content: _contentControllers[i]?.text ?? '',
      ));
    }

    final finalReport = _currentReport!.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    await context.read<FirebaseService>().saveCourseReport(finalReport);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Relatório guardado com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('${widget.course.name} - Relatório'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              if (_currentReport != null) {
                ReportPdfGenerator.generateAndPrintCourseReport(_currentReport!, widget.course.name);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsHeader(),
            const SizedBox(height: 24),
            _buildSubjectsTable(),
            const SizedBox(height: 24),
            _buildTeachersSection(),
            const SizedBox(height: 24),
            _buildSurveyStatistics(),
            const SizedBox(height: 24),
            ..._currentReport!.sections.asMap().entries.map((e) => _buildSectionEditor(e.key, e.value)),
            const SizedBox(height: 24),
            _buildPhotoSelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachersSection() {
    final teachers = _currentReport!.snapshotMetrics['teachers'] as Map? ?? {};
    if (teachers.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText(
          'Corpo Docente',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: teachers.entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(e.value['name'] ?? 'Docente', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSurveyStatistics() {
    final surveys = _currentReport!.snapshotMetrics['surveys'] as List? ?? [];
    if (surveys.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText(
          'Análise de Inquéritos',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...surveys.map((s) {
          final summary = s['summary'] as Map<String, dynamic>?;
          if (summary == null) return const SizedBox();
          final total = summary['totalResponses'] ?? 0;

          return GlassCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(s['title'] ?? 'Inquérito', style: const TextStyle(color: Colors.white)),
              subtitle: Text('$total respostas coletadas', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AiTranslatedText('Distribuição de Respostas (Exemplo):', style: TextStyle(color: Colors.amber, fontSize: 12)),
                      const SizedBox(height: 8),
                      // Ideally, we'd render a chart here, but for now we list major trends
                      if (total > 0)
                        const Text(
                          'Nota: As respostas quantitativas foram agregadas e serão incluídas na exportação PDF final.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                        )
                      else
                        const AiTranslatedText('Sem dados estatísticos suficientes.', style: TextStyle(color: Colors.white24)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricsHeader() {
    final Map<String, dynamic> m = _currentReport!.snapshotMetrics;
    return Row(
      children: [
        _MetricCard(
          label: 'Alunos Inscritos',
          value: m['totalAcceptedStudents']?.toString() ?? '0',
          icon: Icons.people,
          color: Colors.blue,
        ),
        _MetricCard(
          label: 'Média Assiduidade',
          value: '${((m['attendancePercentage'] ?? 0.0)).toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _MetricCard(
          label: 'Cobertura Conteúdos',
          value: '${((m['syllabusCoveragePercentage'] ?? 0.0)).toStringAsFixed(1)}%',
          icon: Icons.book,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildSubjectsTable() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: AiTranslatedText(
              'Desempenho por Disciplina',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Disciplina', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Assiduidade', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Sumários', style: TextStyle(color: Colors.white70))),
              ],
              rows: (_currentReport!.snapshotMetrics['subjectMetrics'] as List? ?? []).map((smMap) {
                final sm = smMap as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(sm['subjectName'] ?? '', style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${((sm['attendanceRatio'] ?? 0.0) * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70))),
                  DataCell(Text('${sm['sessionsDelivered']}/${sm['sessionsPlanned']}', style: const TextStyle(color: Colors.white70))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEditor(int index, ReportSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentControllers[index],
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escreva aqui...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AiTranslatedText(
              'Fotos de Atividades Associadas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showPhotoPicker,
              icon: const Icon(Icons.add_a_photo),
              label: const AiTranslatedText('Selecionar Fotos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_currentReport!.selectedActivityPhotoUrls.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: AiTranslatedText('Nenhuma foto selecionada.', style: TextStyle(color: Colors.white24)),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _currentReport!.selectedActivityPhotoUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_currentReport!.selectedActivityPhotoUrls[index], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _currentReport!.selectedActivityPhotoUrls.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  void _showPhotoPicker() async {
    final service = context.read<FirebaseService>();
    final activities = await service.getActivities(widget.course.institutionId).first;
    
    // Filter activities targeted to this course
    final courseActivities = activities.where((a) => a.targetCourseId == widget.course.id).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: AiTranslatedText('Escolher Fotos das Atividades', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: courseActivities.length,
                    itemBuilder: (context, ai) {
                      final act = courseActivities[ai];
                      final images = act.media.where((m) => m.type == 'image').toList();
                      if (images.isEmpty) return const SizedBox();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(act.title, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: images.length,
                              itemBuilder: (context, imi) {
                                final img = images[imi];
                                final isSelected = _currentReport!.selectedActivityPhotoUrls.contains(img.url);

                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        _currentReport!.selectedActivityPhotoUrls.remove(img.url);
                                      } else {
                                        _currentReport!.selectedActivityPhotoUrls.add(img.url);
                                      }
                                    });
                                    setState(() {}); // Update main screen
                                  },
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                                      image: DecorationImage(image: NetworkImage(img.url), fit: BoxFit.cover),
                                    ),
                                    child: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(color: Colors.white10),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
