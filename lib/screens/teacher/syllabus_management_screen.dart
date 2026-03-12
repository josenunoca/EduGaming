import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'virtual_classroom_teacher_screen.dart';

class SyllabusManagementScreen extends StatefulWidget {
  final Subject subject;
  const SyllabusManagementScreen({super.key, required this.subject});

  @override
  State<SyllabusManagementScreen> createState() => _SyllabusManagementScreenState();
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
          setState(() {
            if (session != null) {
              _sessions.removeWhere((s) => s.id == session.id);
            }
            _sessions.add(newSession);
            _sessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
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
        child: _sessions.isEmpty
            ? const Center(
                child: AiTranslatedText(
                  'Nenhuma sessão definida.',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: ListTile(
                        onTap: () => _addOrEditSession(session),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF7B61FF).withOpacity(0.2),
                          child: Text(
                            session.sessionNumber.toString(),
                            style: const TextStyle(color: Color(0xFF7B61FF), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          session.topic,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AiTranslatedText(
                              DateFormat('dd/MM/yyyy').format(session.date),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            if (session.finalSummary != null)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: AiTranslatedText(
                                  'Sumário Finalizado',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.video_call, color: Color(0xFF00D1FF)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VirtualClassroomTeacherScreen(
                                      subject: widget.subject,
                                      session: session,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Iniciar Aula em Direto',
                            ),
                            const Icon(Icons.edit, color: Colors.white24, size: 20),
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
  List<String> _selectedMaterialIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _topicController.text = widget.session!.topic;
      _numberController.text = widget.session!.sessionNumber.toString();
      _biblioController.text = widget.session!.bibliography;
      _summaryController.text = widget.session!.finalSummary ?? widget.session!.proposedSummary ?? '';
      _selectedDate = widget.session!.date;
      _selectedMaterialIds = List.from(widget.session!.materialIds);
    } else {
      _numberController.text = (widget.subject.sessions.length + 1).toString();
    }
  }

  void _generateProposedSummary() {
    if (_topicController.text.isNotEmpty) {
      setState(() {
        _summaryController.text = 'Sumário da Sessão: ${_topicController.text}. Foram abordados os conceitos fundamentais do tópico e explorados os materiais de apoio disponibilizados.';
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
                    decoration: const InputDecoration(labelText: 'N.º Sessão', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Tópico', border: OutlineInputBorder()),
                    onChanged: (v) {
                      if (_summaryController.text.isEmpty) _generateProposedSummary();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const AiTranslatedText('Data da Sessão', style: TextStyle(color: Colors.white70)),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 16)),
              trailing: const Icon(Icons.calendar_today, color: Color(0xFF00D1FF)),
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
            const AiTranslatedText('Materiais a Entregar/Apoio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.subject.contents.map((content) {
                final isSelected = _selectedMaterialIds.contains(content.id);
                return FilterChip(
                  label: Text(content.name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
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
              decoration: const InputDecoration(labelText: 'Bibliografia Recomendada', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Sumário', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _generateProposedSummary,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const AiTranslatedText('Gerar Proposta', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            TextField(
              controller: _summaryController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Escreva o sumário da aula...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final s = SyllabusSession(
                        id: widget.session?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionNumber: int.tryParse(_numberController.text) ?? 0,
                        topic: _topicController.text,
                        date: _selectedDate,
                        materialIds: _selectedMaterialIds,
                        bibliography: _biblioController.text,
                        proposedSummary: widget.session?.proposedSummary ?? _summaryController.text,
                        finalSummary: null, // Keep as draft
                        isFinalized: false,
                      );
                      widget.onSave(s);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                    child: const AiTranslatedText('Guardar Rascunho'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final s = SyllabusSession(
                        id: widget.session?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        sessionNumber: int.tryParse(_numberController.text) ?? 0,
                        topic: _topicController.text,
                        date: _selectedDate,
                        materialIds: _selectedMaterialIds,
                        bibliography: _biblioController.text,
                        proposedSummary: widget.session?.proposedSummary ?? _summaryController.text,
                        finalSummary: _summaryController.text,
                        isFinalized: true,
                      );
                      widget.onSave(s);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1FF)),
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
