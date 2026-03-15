import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../models/credit_pricing_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'virtual_classroom_teacher_screen.dart';
import '../../services/pdf_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart' as archive;
import 'package:xml/xml.dart' as xml;

class SyllabusManagementScreen extends StatefulWidget {
  final Subject subject;
  const SyllabusManagementScreen({super.key, required this.subject});

  @override
  State<SyllabusManagementScreen> createState() =>
      _SyllabusManagementScreenState();
}

class _SyllabusManagementScreenState extends State<SyllabusManagementScreen> {
  late List<SyllabusSession> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.subject.sessions);
    _sessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
  }

  @override
  void didUpdateWidget(SyllabusManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subject.sessions != oldWidget.subject.sessions) {
      setState(() {
        _sessions = List.from(widget.subject.sessions);
        _sessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
      });
    }
  }

  void _addOrEditSession([SyllabusSession? session]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionEditorModal(
        subject: widget.subject,
        session: session,
        onSave: (newSession) async {
          final service = context.read<FirebaseService>();

          // If finalizing for the first time, deduct credits
          final isNewlyFinalized = newSession.isFinalized &&
              !widget.subject.sessions
                  .any((s) => s.id == newSession.id && s.isFinalized);

          if (isNewlyFinalized) {
            final success = await service.deductCreditsForAction(
                widget.subject.teacherId, CreditAction.registerSyllabus);
            if (!success) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: AiTranslatedText(
                        'Créditos insuficientes para finalizar sumário.')));
              }
              return;
            }
          }

          if (!mounted) return;
          setState(() {
            if (session != null) {
              _sessions.removeWhere((s) => s.id == session.id);
            }
            _sessions.add(newSession);
            _sessions
                .sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
          });
          final updatedSubject = Subject(
            id: widget.subject.id,
            name: widget.subject.name,
            level: widget.subject.level,
            academicYear: widget.subject.academicYear,
            teacherId: widget.subject.teacherId,
            institutionId: widget.subject.institutionId,
            allowedStudentEmails: widget.subject.allowedStudentEmails,
            contents: widget.subject.contents,
            games: widget.subject.games,
            evaluationComponents: widget.subject.evaluationComponents,
            scientificArea: widget.subject.scientificArea,
            pautaStatus: widget.subject.pautaStatus,
            sealedAt: widget.subject.sealedAt,
            sealedBy: widget.subject.sealedBy,
            sessions: _sessions,
          );
          await context.read<FirebaseService>().updateSubject(updatedSubject);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Programa e Sumários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => PdfService.generateProgramPDF(widget.subject),
            tooltip: 'Download Programa',
          ),
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () async {
              final service = context.read<FirebaseService>();
              final allAttendances =
                  await service.getAttendanceForSubject(widget.subject.id);
              PdfService.generateSummariesPDF(widget.subject, allAttendances);
            },
            tooltip: 'Download Sumários',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditSession(),
        icon: const Icon(Icons.add),
        label: const AiTranslatedText('Nova Sessão'),
        backgroundColor: const Color(0xFF7B61FF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildProgramHeader(context);
                  }
                  final session = _sessions[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: ListTile(
                        onTap: () => _addOrEditSession(session),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF7B61FF).withValues(alpha: 0.2),
                          child: Text(
                            session.sessionNumber.toString(),
                            style: const TextStyle(
                                color: Color(0xFF7B61FF),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          session.topic,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AiTranslatedText(
                              DateFormat('dd/MM/yyyy').format(session.date),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                            if (session.finalSummary != null) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: AiTranslatedText(
                                  'Sumário Finalizado:',
                                  style: TextStyle(
                                      color: Color(0xFF00D1FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (session.finalSummary != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Text(
                                    session.finalSummary!,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (session.materialIds.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: session.materialIds.map((id) {
                                    final content =
                                        widget.subject.contents.firstWhere(
                                      (c) => c.id == id,
                                      orElse: () => SubjectContent(
                                          id: '',
                                          name: 'Material',
                                          url: '',
                                          type: ''),
                                    );
                                    if (content.url.isEmpty) {
                                      return const SizedBox();
                                    }
                                    return GestureDetector(
                                      onTap: () async {
                                        final uri = Uri.tryParse(content.url);
                                        if (uri != null &&
                                            await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      },
                                      child: Text(
                                        '🔗 ${content.name}',
                                        style: const TextStyle(
                                            color: Color(0xFF00D1FF),
                                            fontSize: 10,
                                            decoration:
                                                TextDecoration.underline),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.video_call,
                                  color: Color(0xFF00D1FF)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VirtualClassroomTeacherScreen(
                                      subject: widget.subject,
                                      session: session,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Iniciar Aula em Direto',
                            ),
                            IconButton(
                              icon: const Icon(Icons.people_outline,
                                  color: Colors.greenAccent),
                              onPressed: () =>
                                  _showAttendanceList(context, session),
                              tooltip: 'Ver Presenças',
                            ),
                            const Icon(Icons.edit,
                                color: Colors.white24, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAttendanceList(BuildContext context, SyllabusSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => _AttendanceManagementModal(
        subject: widget.subject,
        session: session,
      ),
    );
  }

  Widget _buildProgramHeader(BuildContext context) {
    final service = context.read<FirebaseService>();
    final teacherProgram = _currentProgram;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<String?>(
                stream: service.getInstitutionalProgram(
                    widget.subject.institutionId, widget.subject.name),
                builder: (context, snapshot) {
                  final institutionalProgram = snapshot.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AiTranslatedText(
                            'Programa da Disciplina',
                            style: TextStyle(
                                color: Color(0xFF00D1FF),
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              if (institutionalProgram != null &&
                                  institutionalProgram != teacherProgram)
                                IconButton(
                                  icon: const Icon(Icons.sync_alt,
                                      color: Colors.greenAccent),
                                  onPressed: () =>
                                      _syncWithInstitutional(institutionalProgram),
                                  tooltip: 'Sincronizar com Instituição',
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_note,
                                    color: Colors.white70),
                                onPressed: () => _showProgramEditor(context),
                                tooltip: 'Editar Programa',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (institutionalProgram != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.account_balance,
                                  color: Colors.blueAccent, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: AiTranslatedText(
                                  'A instituição carregou um programa oficial para esta disciplina.',
                                  style: TextStyle(
                                      color: Colors.blueAccent, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (teacherProgram == null || teacherProgram.isEmpty)
                        AiTranslatedText(
                          institutionalProgram != null
                              ? 'Visualize o programa carregado pela instituição ou crie o seu próprio.'
                              : 'O programa da disciplina ainda não foi introduzido. Clique no ícone de edição para começar.',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                        )
                      else
                        Text(
                          teacherProgram,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _currentProgram => widget.subject.programDescription;

  Future<void> _syncWithInstitutional(String content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Sincronizar Programa'),
        content: const AiTranslatedText(
            'Deseja substituir o seu programa pelo programa oficial da instituição?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AiTranslatedText('Não')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AiTranslatedText('Sim, Substituir')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updatedSubject = Subject(
        id: widget.subject.id,
        name: widget.subject.name,
        level: widget.subject.level,
        academicYear: widget.subject.academicYear,
        teacherId: widget.subject.teacherId,
        institutionId: widget.subject.institutionId,
        allowedStudentEmails: widget.subject.allowedStudentEmails,
        contents: widget.subject.contents,
        games: widget.subject.games,
        evaluationComponents: widget.subject.evaluationComponents,
        scientificArea: widget.subject.scientificArea,
        programDescription: content,
        pautaStatus: widget.subject.pautaStatus,
        sealedAt: widget.subject.sealedAt,
        sealedBy: widget.subject.sealedBy,
        sessions: widget.subject.sessions,
      );
      await context.read<FirebaseService>().updateSubject(updatedSubject);
    }
  }

  void _showProgramEditor(BuildContext context) {
    final controller =
        TextEditingController(text: widget.subject.programDescription);
    bool isDragging = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DropTarget(
            onDragEntered: (details) => setModalState(() => isDragging = true),
            onDragExited: (details) => setModalState(() => isDragging = false),
            onDragDone: (details) async {
              setModalState(() => isDragging = false);
              if (details.files.isNotEmpty) {
                final file = details.files.first;
                final name = file.name.toLowerCase();
                final bool isSupported = name.endsWith('.txt') ||
                    name.endsWith('.md') ||
                    name.endsWith('.pdf') ||
                    name.endsWith('.docx');
                if (isSupported) {
                  try {
                    String extractedText = '';

                    if (name.endsWith('.txt') || name.endsWith('.md')) {
                      final bytes = await file.readAsBytes();
                      extractedText = utf8.decode(bytes);
                    } else if (name.endsWith('.pdf')) {
                      final bytes = await file.readAsBytes();
                      final PdfDocument document =
                          PdfDocument(inputBytes: bytes);
                      extractedText = PdfTextExtractor(document).extractText();
                      document.dispose();
                    } else if (name.endsWith('.docx')) {
                      final bytes = await file.readAsBytes();
                      final decodedArchive =
                          archive.ZipDecoder().decodeBytes(bytes);
                      final documentXmlFile =
                          decodedArchive.findFile('word/document.xml');
                      if (documentXmlFile != null) {
                        final xmlDoc = xml.XmlDocument.parse(
                            utf8.decode(documentXmlFile.content));
                        final paragraphs = xmlDoc.findAllElements('w:p');
                        final buffer = StringBuffer();
                        for (final p in paragraphs) {
                          final textElements = p.findAllElements('w:t');
                          for (final t in textElements) {
                            buffer.write(t.innerText);
                          }
                          buffer.writeln();
                        }
                        extractedText = buffer.toString().trim();
                      }
                    }

                    setModalState(() {
                      controller.text = extractedText;
                    });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao extrair texto: $e')),
                      );
                    }
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Apenas ficheiros .txt, .md, .pdf ou .docx são suportados.')),
                    );
                  }
                }
              }
            },
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDragging
                    ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                    : const Color(0xFF1E293B),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: isDragging
                    ? Border.all(color: const Color(0xFF00D1FF), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AiTranslatedText(
                        'Editar Programa da Disciplina',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file,
                            color: Color(0xFF00D1FF)),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['txt', 'md', 'pdf', 'docx'],
                            withData: true,
                          );
                          if (result != null &&
                              result.files.single.bytes != null) {
                            final file = result.files.single;
                            final name = file.name.toLowerCase();
                            String extractedText = '';

                            try {
                              if (name.endsWith('.txt') ||
                                  name.endsWith('.md')) {
                                extractedText = utf8.decode(file.bytes!);
                              } else if (name.endsWith('.pdf')) {
                                final PdfDocument document =
                                    PdfDocument(inputBytes: file.bytes!);
                                extractedText =
                                    PdfTextExtractor(document).extractText();
                                document.dispose();
                              } else if (name.endsWith('.docx')) {
                                final decodedArchive = archive.ZipDecoder()
                                    .decodeBytes(file.bytes!);
                                final documentXmlFile = decodedArchive
                                    .findFile('word/document.xml');
                                if (documentXmlFile != null) {
                                  final xmlDoc = xml.XmlDocument.parse(
                                      utf8.decode(documentXmlFile.content));
                                  final paragraphs =
                                      xmlDoc.findAllElements('w:p');
                                  final buffer = StringBuffer();
                                  for (final p in paragraphs) {
                                    final textElements =
                                        p.findAllElements('w:t');
                                    for (final t in textElements) {
                                      buffer.write(t.innerText);
                                    }
                                    buffer.writeln();
                                  }
                                  extractedText = buffer.toString().trim();
                                }
                              }

                              setModalState(() {
                                controller.text = extractedText;
                              });
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Erro ao extrair texto: $e')),
                                );
                              }
                            }
                          }
                        },
                        tooltip: 'Carregar ficheiro (.txt, .md, .pdf, .docx)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isDragging)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.file_download,
                                size: 64, color: Color(0xFF00D1FF)),
                            SizedBox(height: 16),
                            AiTranslatedText(
                              'Largue o ficheiro aqui',
                              style: TextStyle(
                                  color: Color(0xFF00D1FF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: controller,
                      maxLines: 15,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText:
                            'Introduza os objetivos gerais, conteúdos programáticos e bibliografia geral ou arraste um ficheiro aqui...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final updatedSubject = Subject(
                        id: widget.subject.id,
                        name: widget.subject.name,
                        level: widget.subject.level,
                        academicYear: widget.subject.academicYear,
                        teacherId: widget.subject.teacherId,
                        institutionId: widget.subject.institutionId,
                        allowedStudentEmails:
                            widget.subject.allowedStudentEmails,
                        contents: widget.subject.contents,
                        games: widget.subject.games,
                        evaluationComponents:
                            widget.subject.evaluationComponents,
                        scientificArea: widget.subject.scientificArea,
                        programDescription: controller.text,
                        pautaStatus: widget.subject.pautaStatus,
                        sealedAt: widget.subject.sealedAt,
                        sealedBy: widget.subject.sealedBy,
                        sessions: widget.subject.sessions,
                      );
                      await context
                          .read<FirebaseService>()
                          .updateSubject(updatedSubject);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const AiTranslatedText('Guardar Programa'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceManagementModal extends StatefulWidget {
  final Subject subject;
  final SyllabusSession session;

  const _AttendanceManagementModal({
    required this.subject,
    required this.session,
  });

  @override
  State<_AttendanceManagementModal> createState() =>
      _AttendanceManagementModalState();
}

class _AttendanceManagementModalState
    extends State<_AttendanceManagementModal> {
  @override
  Widget build(BuildContext context) {
    final firebaseService = context.read<FirebaseService>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText(
                      'Folha de Presenças',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.session.topic,
                      style: const TextStyle(
                          color: Color(0xFF00D1FF), fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              // Collective attendance
              final enrollments = await firebaseService
                  .getEnrollmentsForSubject(widget.subject.id)
                  .first;
              for (var enrollment in enrollments) {
                if (enrollment.status == 'accepted') {
                  final attendance = Attendance(
                    id: '${enrollment.userId}_${widget.session.id}',
                    userId: enrollment.userId,
                    userName: enrollment.studentName,
                    subjectId: widget.subject.id,
                    sessionId: widget.session.id,
                    timestamp: DateTime.now(),
                  );
                  await firebaseService.registerAttendance(attendance);
                }
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: AiTranslatedText(
                          'Presença coletiva registada com sucesso!')),
                );
              }
            },
            icon: const Icon(Icons.group_add, color: Color(0xFF0F172A)),
            label: const AiTranslatedText(
              'Marcar Presença Coletiva',
              style: TextStyle(
                  color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D1FF),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Enrollment>>(
              stream:
                  firebaseService.getEnrollmentsForSubject(widget.subject.id),
              builder: (context, enrollmentSnapshot) {
                if (!enrollmentSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final enrolledStudents = enrollmentSnapshot.data!
                    .where((e) => e.status == 'accepted')
                    .toList();

                if (enrolledStudents.isEmpty) {
                  return const Center(
                    child: AiTranslatedText(
                      'Nenhum aluno inscrito nesta disciplina.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return StreamBuilder<List<Attendance>>(
                  stream: firebaseService
                      .getAttendanceForSession(widget.session.id),
                  builder: (context, attendanceSnapshot) {
                    final attendances = attendanceSnapshot.data ?? [];
                    final Map<String, Attendance> attendanceMap = {
                      for (var a in attendances) a.userId: a
                    };

                    return ListView.builder(
                      itemCount: enrolledStudents.length,
                      itemBuilder: (context, index) {
                        final enrollment = enrolledStudents[index];
                        final isPresent =
                            attendanceMap.containsKey(enrollment.userId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPresent
                                  ? Colors.greenAccent.withOpacity(0.2)
                                  : Colors.white10,
                              child: Icon(
                                Icons.person,
                                color: isPresent
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                            title: Text(
                              enrollment.studentName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Switch(
                              value: isPresent,
                              activeThumbColor: Colors.greenAccent,
                              onChanged: (val) async {
                                if (val) {
                                  final attendance = Attendance(
                                    id: '${enrollment.userId}_${widget.session.id}',
                                    userId: enrollment.userId,
                                    userName: enrollment.studentName,
                                    subjectId: widget.subject.id,
                                    sessionId: widget.session.id,
                                    timestamp: DateTime.now(),
                                  );
                                  await firebaseService
                                      .registerAttendance(attendance);
                                } else {
                                  await firebaseService.deleteAttendance(
                                      enrollment.userId, widget.session.id);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionEditorModal extends StatefulWidget {
  final Subject subject;
  final SyllabusSession? session;
  final Function(SyllabusSession) onSave;

  const _SessionEditorModal({
    required this.subject,
    this.session,
    required this.onSave,
  });

  @override
  State<_SessionEditorModal> createState() => _SessionEditorModalState();
}

class _SessionEditorModalState extends State<_SessionEditorModal> {
  final _topicController = TextEditingController();
  final _numberController = TextEditingController();
  final _biblioController = TextEditingController();
  final _summaryController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<String> _selectedMaterialIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _topicController.text = widget.session!.topic;
      _numberController.text = widget.session!.sessionNumber.toString();
      _biblioController.text = widget.session!.bibliography;
      _summaryController.text =
          widget.session!.finalSummary ?? widget.session!.proposedSummary ?? '';
      _selectedDate = widget.session!.date;
      _selectedMaterialIds = List.from(widget.session!.materialIds);
      if (widget.session!.startTime != null) {
        final parts = widget.session!.startTime!.split(':');
        _startTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (widget.session!.endTime != null) {
        final parts = widget.session!.endTime!.split(':');
        _endTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } else {
      _numberController.text = (widget.subject.sessions.length + 1).toString();
    }
  }

  void _generateProposedSummary() {
    if (_topicController.text.isNotEmpty) {
      setState(() {
        _summaryController.text =
            'Sumário da Sessão: ${_topicController.text}. Foram abordados os conceitos fundamentais do tópico e explorados os materiais de apoio disponibilizados.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiTranslatedText(
              widget.session == null ? 'Nova Sessão' : 'Editar Sessão',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'N.º Sessão', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Tópico', border: OutlineInputBorder()),
                    onChanged: (v) {
                      if (_summaryController.text.isEmpty) {
                        _generateProposedSummary();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const AiTranslatedText('Data da Sessão',
                  style: TextStyle(color: Colors.white70)),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              trailing:
                  const Icon(Icons.calendar_today, color: Color(0xFF00D1FF)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const AiTranslatedText('Início',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text(_startTime?.format(context) ?? '--:--',
                        style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime ??
                              const TimeOfDay(hour: 9, minute: 0));
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const AiTranslatedText('Fim',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text(_endTime?.format(context) ?? '--:--',
                        style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime:
                              _endTime ?? const TimeOfDay(hour: 10, minute: 0));
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AiTranslatedText('Materiais a Entregar/Apoio',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.subject.contents.map((content) {
                final isSelected = _selectedMaterialIds.contains(content.id);
                return FilterChip(
                  label: Text(content.name,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedMaterialIds.add(content.id);
                      } else {
                        _selectedMaterialIds.remove(content.id);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF7B61FF),
                  backgroundColor: Colors.white10,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _biblioController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Bibliografia Recomendada',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Sumário',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _generateProposedSummary,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const AiTranslatedText('Gerar Proposta',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            TextField(
              controller: _summaryController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: 'Escreva o sumário da aula...',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final s = SyllabusSession(
                        id: widget.session?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionNumber:
                            int.tryParse(_numberController.text) ?? 0,
                        topic: _topicController.text,
                        date: _selectedDate,
                        materialIds: _selectedMaterialIds,
                        bibliography: _biblioController.text,
                        proposedSummary: widget.session?.proposedSummary ??
                            _summaryController.text,
                        finalSummary: null, // Keep as draft
                        isFinalized: false,
                        startTime: _startTime != null
                            ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                            : null,
                        endTime: _endTime != null
                            ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                            : null,
                      );
                      widget.onSave(s);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24),
                    child: const AiTranslatedText('Guardar Rascunho'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final s = SyllabusSession(
                        id: widget.session?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionNumber:
                            int.tryParse(_numberController.text) ?? 0,
                        topic: _topicController.text,
                        date: _selectedDate,
                        materialIds: _selectedMaterialIds,
                        bibliography: _biblioController.text,
                        proposedSummary: widget.session?.proposedSummary ??
                            _summaryController.text,
                        finalSummary: _summaryController.text,
                        isFinalized: true,
                        startTime: _startTime != null
                            ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                            : null,
                        endTime: _endTime != null
                            ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                            : null,
                      );
                      widget.onSave(s);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D1FF)),
                    child: const AiTranslatedText('Finalizar Sumário'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
