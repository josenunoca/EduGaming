import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subject_model.dart';
import '../services/firebase_service.dart';

class SubjectStudentManagementDialog extends StatefulWidget {
  final Subject subject;
  final String institutionId;

  const SubjectStudentManagementDialog({
    super.key,
    required this.subject,
    required this.institutionId,
  });

  static void show(BuildContext context, Subject subject, String institutionId) {
    showDialog(
      context: context,
      builder: (context) => SubjectStudentManagementDialog(
        subject: subject,
        institutionId: institutionId,
      ),
    );
  }

  @override
  State<SubjectStudentManagementDialog> createState() =>
      _SubjectStudentManagementDialogState();
}

class _SubjectStudentManagementDialogState
    extends State<SubjectStudentManagementDialog> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isImporting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _downloadCsvTemplate() {
    final csvContent =
        'Nome,Data de Nascimento,Email Encarregado/Aluno\n'
        'Ana Silva,15/05/2015,pais.silva@email.com\n'
        'Bruno Silva,20/11/2017,pais.silva@email.com\n'
        'Carlos Santos,03/02/2016,carlos@email.com\n';

    final bytes = utf8.encode(csvContent);
    final base64Str = base64Encode(bytes);
    final uri = 'data:text/csv;charset=utf-8;base64,$base64Str';
    launchUrl(Uri.parse(uri));
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isImporting = true);

    try {
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      final List<Map<String, String>> students = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Skip header row if present
        if (i == 0 &&
            (line.toLowerCase().contains('nome') ||
                line.toLowerCase().contains('email') ||
                line.toLowerCase().contains('nascimento'))) {
          continue;
        }

        final parts = line.split(RegExp(r'[,;\t]'));
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          final name = parts[0].trim();
          final birthDate = parts.length > 1 ? parts[1].trim() : '';
          final email = parts.length > 2 ? parts[2].trim() : '';

          students.add({
            'name': name,
            'birthDate': birthDate,
            'email': email,
          });
        }
      }

      if (students.isNotEmpty) {
        final service = context.read<FirebaseService>();
        await service.bulkImportStudentsToSubject(
          subjectId: widget.subject.id,
          institutionId: widget.institutionId,
          students: students,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${students.length} alunos importados com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum aluno encontrado no ficheiro importado.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar ficheiro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showCopyFromSubjectDialog() {
    final service = context.read<FirebaseService>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Importar Alunos de Outra Disciplina',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: StreamBuilder<List<Subject>>(
            stream: service.getSubjectsByInstitution(widget.institutionId),
            builder: (context, snapshot) {
              final otherSubjects = (snapshot.data ?? [])
                  .where((s) => s.id != widget.subject.id)
                  .toList();

              if (otherSubjects.isEmpty) {
                return const Text(
                  'Nenhuma outra disciplina encontrada na instituição.',
                  style: TextStyle(color: Colors.white54),
                );
              }

              Subject? selectedSource;
              return StatefulBuilder(
                builder: (context, setSubState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Subject>(
                      dropdownColor: const Color(0xFF1E1E2E),
                      hint: const Text('Selecione a Disciplina de Origem',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      items: otherSubjects
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.name} (${s.academicYear})',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) => setSubState(() => selectedSource = val),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B61FF),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: selectedSource == null
                          ? null
                          : () async {
                              await service.copyStudentsBetweenSubjects(
                                sourceSubjectId: selectedSource!.id,
                                targetSubjectId: widget.subject.id,
                                institutionId: widget.institutionId,
                              );
                              if (mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Alunos de ${selectedSource!.name} importados com sucesso!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      child: const Text('Importar Alunos'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addSingleStudent() async {
    if (_nameController.text.trim().isEmpty) return;

    if (_birthDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de nascimento é obrigatória para registar educandos menores.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final service = context.read<FirebaseService>();
    await service.addStudentToSubject(
      subjectId: widget.subject.id,
      institutionId: widget.institutionId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      birthDate: _birthDateController.text.trim(),
    );

    _nameController.clear();
    _birthDateController.clear();
    _emailController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aluno adicionado à disciplina com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alunos: ${widget.subject.name}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'Ano Letivo: ${widget.subject.academicYear} | Ciclo Yr: ${widget.subject.cycleYear}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions Bar (Import Excel/CSV, Download Template, Copy from other subject)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _downloadCsvTemplate,
                  icon: const Icon(Icons.download, size: 16, color: Color(0xFF00D1FF)),
                  label: const Text('Descarregar Modelo Excel/CSV',
                      style: TextStyle(color: Color(0xFF00D1FF), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00D1FF)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importFromFile,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file, size: 16),
                  label: const Text('Importar Ficheiro (Excel/CSV)',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCopyFromSubjectDialog,
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Importar de Outra Disciplina',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E3E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // Manual Add Form
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nome do Aluno',
                        labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _birthDateController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Data Nasc. (DD/MM/AAAA)',
                        labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Email (Encarregado / Aluno)',
                        labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addSingleStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(80, 40),
                    ),
                    child: const Text('➕ Adicionar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Enrolled Students
            Expanded(
              child: StreamBuilder<List<Enrollment>>(
                stream: service.getEnrollmentsForSubject(widget.subject.id),
                builder: (context, snapshot) {
                  final enrollments = snapshot.data ?? [];

                  if (enrollments.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum aluno inscrito nesta disciplina ainda.\n'
                        'Importe um ficheiro Excel/CSV ou adicione manualmente acima.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: enrollments.length,
                    itemBuilder: (context, index) {
                      final st = enrollments[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                            child: Text(
                              st.studentName.isNotEmpty
                                  ? st.studentName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                  color: Color(0xFF7B61FF),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(st.studentName,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Row(
                            children: [
                              if (st.birthDate != null && st.birthDate!.isNotEmpty) ...[
                                Text('🎂 ${st.birthDate}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                const SizedBox(width: 12),
                              ],
                              if (st.studentEmail.isNotEmpty)
                                Text('✉️ ${st.studentEmail}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () async {
                              await service.removeStudentFromSubject(st.id);
                            },
                            tooltip: 'Remover Aluno',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
