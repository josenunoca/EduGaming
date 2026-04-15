import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/subject_model.dart';
import '../../../models/credit_pricing_model.dart';
import '../../../models/institution_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import '../../../services/pdf_service.dart';
import '../../../models/user_model.dart';
import 'package:uuid/uuid.dart';
import 'student_exam_detail_screen.dart';

import '../../../services/mail_service.dart';
import 'package:url_launcher/url_launcher.dart';

class GradesManagementScreen extends StatefulWidget {
  final Subject subject;

  const GradesManagementScreen({super.key, required this.subject});

  @override
  State<GradesManagementScreen> createState() => _GradesManagementScreenState();
}

class _GradesManagementScreenState extends State<GradesManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  bool _isGenerating = false;
  List<Enrollment> _students = [];
  List<AiGameResult> _allResults = [];
  List<StudentGradeAdjustment> _adjustments = [];
  Map<String, AiGame> _gamesMap = {};
  late Subject _subject;
  UserModel? _teacher;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subject = widget.subject;
    _setupStreams();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(GradesManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subject != oldWidget.subject) {
      setState(() {
        _subject = widget.subject;
      });
      // Re-setup if subject ID changed
      if (widget.subject.id != oldWidget.subject.id) {
        _setupStreams();
      }
    }
  }

  void _setupStreams() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    setState(() => _isLoading = true);

    // 1. Students Stream
    _subscriptions.add(
      _firebaseService.getEnrollmentsForSubject(_subject.id).listen((students) {
        setState(() => _students = students);
        _checkLoading();
      }),
    );

    // 2. Results Stream
    _subscriptions.add(
      _firebaseService
          .getAllSubjectGameResultsStream(_subject.id)
          .listen((results) {
        setState(() => _allResults = results);
        _checkLoading();
      }),
    );

    // 3. Adjustments Stream
    _subscriptions.add(
      _firebaseService.getGradeAdjustments(_subject.id).listen((adjustments) {
        setState(() => _adjustments = adjustments);
        _checkLoading();
      }),
    );

    // 4. Games Stream
    _subscriptions.add(
      _firebaseService.getAiGamesBySubject(_subject.id).listen((games) {
        Map<String, AiGame> gMap = {};
        for (var g in games) {
          gMap[g.id] = g;
        }
        setState(() => _gamesMap = gMap);
        _checkLoading();
      }),
    );

    // 5. Teacher (One-time fetch is okay, but let's keep it separate)
    _firebaseService.getUserModel(_subject.teacherId).then((teacher) {
      if (mounted) {
        setState(() => _teacher = teacher);
        _checkLoading();
      }
    });
  }

  void _checkLoading() {
    // We consider it loaded when we have all initial data
    if (_students.isNotEmpty ||
        _allResults.isNotEmpty ||
        _gamesMap.isNotEmpty) {
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
    } else {
      // If everything is empty, it might still be loading or just empty
      // For now, let's just stop loading after a short delay if nothing comes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  Future<void> _updatePautaStatus(PautaStatus newStatus) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
          newStatus == PautaStatus.finalized
              ? 'Finalizar Pauta?'
              : 'Lacrar Pauta?',
          style: const TextStyle(color: Colors.white),
        ),
        content: AiTranslatedText(
          newStatus == PautaStatus.finalized
              ? 'Ao finalizar a pauta, os alunos poderão visualizar as suas classificações propostas. Poderá reabrir a pauta se necessário.'
              : 'ATENÇÃO: Ao lacrar a pauta, as classificações serão arredondadas à unidade e NÃO poderá fazer mais alterações. Os certificados serão emitidos e enviados por email imediatamente. acção IRREVERSÍVEL.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == PautaStatus.sealed
                  ? Colors.redAccent
                  : const Color(0xFF00D1FF),
            ),
            child: AiTranslatedText(newStatus == PautaStatus.finalized
                ? 'Finalizar'
                : 'Lacrar Agora'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updatedSubject = Subject(
        id: _subject.id,
        name: _subject.name,
        level: _subject.level,
        academicYear: _subject.academicYear,
        teacherId: _subject.teacherId,
        institutionId: _subject.institutionId,
        allowedStudentEmails: _subject.allowedStudentEmails,
        contents: _subject.contents,
        games: _subject.games,
        evaluationComponents: _subject.evaluationComponents,
        scientificArea: _subject.scientificArea,
        pautaStatus: newStatus,
        courseId: _subject.courseId,
        teachingHours: _subject.teachingHours,
        nonTeachingHours: _subject.nonTeachingHours,
        sealedAt: newStatus == PautaStatus.sealed
            ? DateTime.now()
            : _subject.sealedAt,
        sealedBy: newStatus == PautaStatus.sealed
            ? (_teacher?.name ?? _subject.teacherId)
            : _subject.sealedBy,
      );

      await _firebaseService.updateSubject(updatedSubject);

      // If sealed, process each student for certification
      if (newStatus == PautaStatus.sealed) {
        final institutions = await _firebaseService.getInstitutions().first;
        final institution = institutions.firstWhere(
          (i) => i.id == _subject.institutionId,
          orElse: () => InstitutionModel(
              id: 'unknown',
              name: 'EduGaming Platform',
              nif: '',
              address: '',
              email: '',
              phone: '',
              educationLevels: [],
              createdAt: DateTime.now()),
        );

        for (var student in _students) {
          // 1. Calculate final grade
          double weightedSum = 0;
          double totalWeight = 0;
          bool hasMissing = false;

          for (var component in _subject.evaluationComponents) {
            final grade = _calculateComponentGrade(student.userId, component);
            if (grade == null) {
              hasMissing = true;
              break;
            }
            weightedSum += grade * component.weight;
            totalWeight += component.weight;
          }

          if (hasMissing) {
            continue; // Cannot seal if grades are missing? Actually SEALED usually means current status.
          }

          final adjustment = _adjustments.firstWhere(
            (a) => a.studentId == student.userId,
            orElse: () =>
                StudentGradeAdjustment(id: '', studentId: '', subjectId: ''),
          );

          double finalVal = adjustment.finalGradeOverride ??
              (totalWeight > 0 ? weightedSum / totalWeight : 0.0);
          final roundedGrade = finalVal.roundToDouble();

          // 2. If approved (grade >= 9.5 or 10 depending on rule, usually 10), issue certificate
          if (roundedGrade >= 10) {
            final ql = Enrollment.toQualitative(roundedGrade);

            // Generate PDF Certificate
            final pdfBytes = await PdfService.generateCertificate(
              institution: institution,
              teacher: _teacher!,
              subject: updatedSubject,
              studentName: student.studentName,
              finalGrade: roundedGrade,
              qualitativeGrade: ql,
              date: DateTime.now(),
            );

            // Deduct credits for certificate
            final success = await _firebaseService.deductCreditsForAction(
                _subject.teacherId, CreditAction.generateCertificate);
            if (!success) {
              debugPrint(
                  'Insufficient credits for certificate of ${student.studentName}');
              continue;
            }

            // Upload to storage
            final certUrl =
                await _firebaseService.uploadCertificate(student.id, pdfBytes);

            // Update enrollment
            await _firebaseService.updateEnrollment(student.id, {
              'isSealed': true,
              'finalGrade': roundedGrade,
              'qualitativeGrade': ql,
              'certificateUrl': certUrl,
            });

            // Send Email
            await MailService.sendCertificateEmail(
              studentEmail: student.studentEmail,
              studentName: student.studentName,
              subjectName: _subject.name,
              certificateUrl: certUrl,
            );
          } else {
            // Just mark as sealed
            await _firebaseService.updateEnrollment(student.id, {
              'isSealed': true,
              'finalGrade': roundedGrade,
            });
          }
        }

        _setupStreams(); // Ensure we have updated subject in state
        await _generatePauta(full: false);
      } else {
        _setupStreams();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AiTranslatedText(newStatus == PautaStatus.finalized
              ? 'Pauta finalizada com sucesso.'
              : 'Pauta lacrada com sucesso e certificados enviados.'),
        ));
      }
    } catch (e) {
      debugPrint('Error updating pauta status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar pauta: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _calculateComponentGrade(
      String studentId, EvaluationComponent component) {
    // 1. Check for manual override
    final adjustment = _adjustments.firstWhere(
      (a) => a.studentId == studentId,
      orElse: () =>
          StudentGradeAdjustment(id: '', studentId: '', subjectId: ''),
    );

    if (adjustment.componentOverrides.containsKey(component.id)) {
      return adjustment.componentOverrides[component.id];
    }

    // 2. Real calculation
    double totalEarned = 0;
    double totalPossible = 0;
    bool playedSomething = false;

    for (var contentId in component.contentIds) {
      final game = _gamesMap[contentId];
      if (game == null) continue;

      double gameMax = game.questions.fold(0.0, (sum, q) => sum + q.points);
      totalPossible += gameMax;

      final studentGameResults = _allResults
          .where((r) => r.studentId == studentId && r.gameId == contentId);
      if (studentGameResults.isNotEmpty) {
        playedSomething = true;
        double best = studentGameResults
            .map((r) => r.score)
            .reduce((a, b) => a > b ? a : b);
        totalEarned += best;
      }
    }

    if (totalPossible == 0) return 0.0;

    if (!playedSomething) {
      if (component.endTime != null &&
          DateTime.now().isAfter(component.endTime!)) {
        return null; // Represents "F"
      }
      return 0.0;
    }

    return (totalEarned / totalPossible) * 20;
  }

  void _showEditGradeDialog(Enrollment student, String? componentId,
      String label, double? currentValue) {
    final TextEditingController controller =
        TextEditingController(text: currentValue?.toStringAsFixed(1) ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText('Ajustar Nota: ${student.studentName}',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiTranslatedText(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nota (0-20)',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = double.tryParse(controller.text);
              if (newValue != null && (newValue < 0 || newValue > 20)) return;

              final existingAdjustment = _adjustments.firstWhere(
                (a) => a.studentId == student.userId,
                orElse: () => StudentGradeAdjustment(
                  id: const Uuid().v4(),
                  studentId: student.userId,
                  subjectId: widget.subject.id,
                ),
              );

              StudentGradeAdjustment updated;
              if (componentId == null) {
                updated = StudentGradeAdjustment(
                  id: existingAdjustment.id,
                  studentId: existingAdjustment.studentId,
                  subjectId: existingAdjustment.subjectId,
                  finalGradeOverride: newValue,
                  componentOverrides: existingAdjustment.componentOverrides,
                  notes: existingAdjustment.notes,
                );
              } else {
                final newOverrides = Map<String, double>.from(
                    existingAdjustment.componentOverrides);
                if (newValue == null) {
                  newOverrides.remove(componentId);
                } else {
                  newOverrides[componentId] = newValue;
                }
                updated = StudentGradeAdjustment(
                  id: existingAdjustment.id,
                  studentId: existingAdjustment.studentId,
                  subjectId: existingAdjustment.subjectId,
                  finalGradeOverride: existingAdjustment.finalGradeOverride,
                  componentOverrides: newOverrides,
                  notes: existingAdjustment.notes,
                );
              }

              await _firebaseService.saveGradeAdjustment(updated);
              if (context.mounted) Navigator.pop(context);
              _setupStreams(); // Refresh
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePauta({required bool full}) async {
    setState(() => _isGenerating = true);
    try {
      final institutions = await _firebaseService.getInstitutions().first;
      final institution = institutions.firstWhere(
        (i) => i.id == widget.subject.institutionId,
        orElse: () => InstitutionModel(
          id: 'unknown',
          name: 'EduGaming Platform',
          nif: '000000000',
          address: 'Digital Campus',
          email: 'admin@edugaming.com',
          phone: '+351 000 000 000',
          educationLevels: [],
          createdAt: DateTime.now(),
        ),
      );

      Map<String, Map<String, String>> gradesMap = {};

      for (var student in _students) {
        Map<String, String> studentGrades = {};
        double weightedSum = 0;
        double totalWeight = 0;
        bool hasMissing = false;

        for (var component in widget.subject.evaluationComponents) {
          final grade = _calculateComponentGrade(student.userId, component);
          if (grade == null) {
            hasMissing = true;
            studentGrades[component.id] = 'F';
          } else {
            studentGrades[component.id] = grade.toStringAsFixed(1);
            weightedSum += grade * component.weight;
            totalWeight += component.weight;
          }
        }

        final adjustment = _adjustments.firstWhere(
          (a) => a.studentId == student.userId,
          orElse: () =>
              StudentGradeAdjustment(id: '', studentId: '', subjectId: ''),
        );

        double calculatedFinal =
            totalWeight > 0 ? weightedSum / totalWeight : 0.0;
        String finalStr = hasMissing
            ? 'F'
            : (adjustment.finalGradeOverride ?? calculatedFinal)
                .toStringAsFixed(1);
        studentGrades['final'] = finalStr;

        gradesMap[student.userId] = studentGrades;
      }

      final pdfBytes = await PdfService.generateTranscriptPdf(
        institution: institution,
        subject: _subject,
        students: _students,
        components: _subject.evaluationComponents,
        grades: gradesMap,
        isFull: full,
        sealedByUserName: _teacher?.name,
      );

      final fileName =
          'Pauta_${full ? "Completa" : "Final"}_${_subject.name.replaceAll(' ', '_')}.pdf';
      await PdfService.downloadPdf(pdfBytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pauta gerada com sucesso!')));
      }
    } catch (e) {
      debugPrint('Error generating pauta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao gerar pauta: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const AiTranslatedText('Notas e Pautas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const AiTranslatedText('Notas e Pautas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _showPautaOptions(),
                tooltip: 'Exportar Pautas',
              ),
            ],
          ),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AiTranslatedText(_subject.name,
                              style: const TextStyle(
                                  color: Color(0xFF00D1FF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const AiTranslatedText(
                              'Gestão de classificações e pautas de avaliação.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.05)),
                      columns: [
                        const DataColumn(
                            label: AiTranslatedText('Estudante',
                                style: TextStyle(color: Colors.white54))),
                        ...widget.subject.evaluationComponents
                            .map((ec) => DataColumn(
                                  label: Tooltip(
                                    message:
                                        'Peso: ${(ec.weight * 100).toStringAsFixed(0)}%',
                                    child: Text(
                                      '${ec.name}\n(${(ec.weight * 100).toStringAsFixed(0)}%)',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )),
                        const DataColumn(
                            label: AiTranslatedText('Média Calc.',
                                style: TextStyle(color: Color(0xFF7B61FF)))),
                        const DataColumn(
                            label: AiTranslatedText('Nota Prop.',
                                style: TextStyle(color: Color(0xFF00D1FF)))),
                        const DataColumn(
                            label: AiTranslatedText('Final',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        const DataColumn(
                            label: AiTranslatedText('Cert.',
                                style: TextStyle(color: Colors.amber))),
                      ],
                      rows: _students.map((student) {
                        double weightedSum = 0;
                        double totalWeight = 0;
                        bool hasMissing = false;

                        List<DataCell> cells = [
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Text(student.studentName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ];

                        for (var component
                            in widget.subject.evaluationComponents) {
                          final studentGameResults = _allResults
                              .where((r) =>
                                  r.studentId == student.userId &&
                                  component.contentIds.contains(r.gameId) &&
                                  r.isEvaluation)
                              .toList();

                          final hasResults = studentGameResults.isNotEmpty;
                          final grade = _calculateComponentGrade(
                              student.userId, component);

                          if (grade == null) {
                            hasMissing = true;
                            cells.add(DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('F',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold)),
                                  if (hasResults) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          size: 16, color: Color(0xFF00D1FF)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        final sortedResults =
                                            List<AiGameResult>.from(
                                                studentGameResults)
                                              ..sort((a, b) =>
                                                  b.score.compareTo(a.score));
                                        _viewExamDetail(student, component,
                                            sortedResults.first);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              onTap: _subject.pautaStatus == PautaStatus.sealed
                                  ? null
                                  : () => _showEditGradeDialog(student,
                                      component.id, component.name, null),
                            ));
                          } else {
                            weightedSum += grade * component.weight;
                            totalWeight += component.weight;
                            cells.add(DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(grade.toStringAsFixed(1),
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  if (hasResults) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          size: 16, color: Color(0xFF00D1FF)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        final sortedResults =
                                            List<AiGameResult>.from(
                                                studentGameResults)
                                              ..sort((a, b) =>
                                                  b.score.compareTo(a.score));
                                        _viewExamDetail(student, component,
                                            sortedResults.first);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              onTap: _subject.pautaStatus == PautaStatus.sealed
                                  ? null
                                  : () => _showEditGradeDialog(student,
                                      component.id, component.name, grade),
                            ));
                          }
                        }

                        final adjustment = _adjustments.firstWhere(
                          (a) => a.studentId == student.userId,
                          orElse: () => StudentGradeAdjustment(
                              id: '', studentId: '', subjectId: ''),
                        );

                        double calculatedFinal =
                            totalWeight > 0 ? weightedSum / totalWeight : 0.0;
                        String finalStr = hasMissing
                            ? 'F'
                            : (adjustment.finalGradeOverride ?? calculatedFinal)
                                .toStringAsFixed(1);

                        cells.add(DataCell(
                          Center(
                              child: Text(
                                  hasMissing
                                      ? 'F'
                                      : calculatedFinal.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Color(0xFF7B61FF)))),
                        ));

                        cells.add(DataCell(
                          Center(
                              child: Text(
                                  adjustment.finalGradeOverride
                                          ?.toStringAsFixed(1) ??
                                      '-',
                                  style: const TextStyle(
                                      color: Color(0xFF00D1FF)))),
                          onTap: _subject.pautaStatus == PautaStatus.sealed
                              ? null
                              : () => _showEditGradeDialog(
                                  student,
                                  null,
                                  'Nota Final Proposta',
                                  adjustment.finalGradeOverride),
                        ));

                        cells.add(DataCell(
                          Center(
                              child: Text(finalStr,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                        ));

                        cells.add(DataCell(
                          Center(
                            child: student.certificateUrl != null &&
                                    student.certificateUrl!.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.workspace_premium,
                                        color: Colors.amber),
                                    onPressed: () async {
                                      final url =
                                          Uri.parse(student.certificateUrl!);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                    tooltip: 'Ver Certificado',
                                  )
                                : const Icon(Icons.pending_actions,
                                    color: Colors.white10, size: 16),
                          ),
                        ));

                        return DataRow(cells: cells);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isGenerating)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00D1FF)),
                  SizedBox(height: 16),
                  AiTranslatedText('A gerar pauta profissional...',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    switch (_subject.pautaStatus) {
      case PautaStatus.draft:
        color = Colors.grey;
        text = 'Rascunho';
        break;
      case PautaStatus.finalized:
        color = Colors.orange;
        text = 'Finalizada';
        break;
      case PautaStatus.sealed:
        color = Colors.redAccent;
        text = 'LACRADA';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons() {
    if (_subject.pautaStatus == PautaStatus.sealed) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock, color: Colors.redAccent, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: AiTranslatedText(
                'Esta pauta foi lacrada e não permite mais edições.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        if (_subject.pautaStatus == PautaStatus.draft)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const AiTranslatedText('Finalizar Pauta'),
              onPressed: () => _updatePautaStatus(PautaStatus.finalized),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1FF)),
            ),
          ),
        if (_subject.pautaStatus == PautaStatus.finalized) ...[
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const AiTranslatedText('Reabrir para Edição'),
              onPressed: () => _updatePautaStatus(PautaStatus.draft),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: const AiTranslatedText('Lacrar Pauta'),
              onPressed: () => _updatePautaStatus(PautaStatus.sealed),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ),
        ],
      ],
    );
  }

  void _showPautaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiTranslatedText('Exportar Pautas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF00D1FF)),
              title: const AiTranslatedText('Pauta Completa',
                  style: TextStyle(color: Colors.white)),
              subtitle: const AiTranslatedText(
                  'Inclui todos os momentos de avaliação',
                  style: TextStyle(color: Colors.white38)),
              onTap: () {
                Navigator.pop(context);
                _generatePauta(full: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, color: Color(0xFF7B61FF)),
              title: const AiTranslatedText('Pauta Final',
                  style: TextStyle(color: Colors.white)),
              subtitle: const AiTranslatedText(
                  'Inclui apenas a classificação final',
                  style: TextStyle(color: Colors.white38)),
              onTap: () {
                Navigator.pop(context);
                _generatePauta(full: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewExamDetail(
      Enrollment student, EvaluationComponent component, AiGameResult result) {
    final game = _gamesMap[result.gameId];
    if (game == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentExamDetailScreen(
          result: result,
          game: game,
          studentName: student.studentName,
        ),
      ),
    );
  }
}
