import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../../models/institution_model.dart';
import '../../../models/institutional_knowledge_model.dart';
import '../../../services/institutional_knowledge_service.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class KnowledgeManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const KnowledgeManagementScreen({super.key, required this.institution});

  @override
  State<KnowledgeManagementScreen> createState() => _KnowledgeManagementScreenState();
}

class _KnowledgeManagementScreenState extends State<KnowledgeManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  KnowledgeAccessType _selectedAccess = KnowledgeAccessType.all;
  final TextEditingController _emailsController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime? _validFrom;
  DateTime? _validUntil;
  late TabController _tabController;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _emailsController.dispose();
    super.dispose();
  }

  Future<String?> _extractText(PlatformFile file) async {
    try {
      final bytes = file.bytes ??
          (file.path != null ? File(file.path!).readAsBytesSync() : null);
      if (bytes == null) return null;

      if (file.extension == 'pdf') {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      } else if (file.extension == 'txt') {
        return utf8.decode(bytes);
      } else if (file.extension == 'docx') {
        return 'Conteúdo do documento Word: ${file.name}';
      }
    } catch (e) {
      debugPrint('Text extraction error: $e');
    }
    return null;
  }

  Future<void> _pickAndUpload() async {
    // Capture context-dependent values before any async gap
    final service = context.read<InstitutionalKnowledgeService>();
    final firebase = context.read<FirebaseService>();
    final messenger = ScaffoldMessenger.of(context);

    if (_titleController.text.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: AiTranslatedText('Por favor, defina um título.')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Não foi possível ler os dados do ficheiro.');

      final url = await firebase.uploadFileBytes(
        bytes,
        'institutions/${widget.institution.id}/knowledge/${file.name}',
      );

      final extractedText = await _extractText(file);

      final doc = InstitutionalKnowledgeDocument(
        id: const Uuid().v4(),
        title: _titleController.text,
        url: url,
        fileName: file.name,
        fileType: file.extension ?? 'pdf',
        uploadDate: DateTime.now(),
        accessType: _selectedAccess,
        restrictedEmails: _emailsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        extractedText: extractedText,
        institutionId: widget.institution.id,
        documentStatus: DocumentStatus.active,
        validFrom: _validFrom,
        validUntil: _validUntil,
      );

      await service.addDocument(doc);

      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: AiTranslatedText('Documento adicionado com sucesso!')));
        _titleController.clear();
        _emailsController.clear();
        setState(() {
          _validFrom = null;
          _validUntil = null;
        });
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_validFrom ?? now) : (_validUntil ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00FF85),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _toggleStatus(InstitutionalKnowledgeDocument doc,
      InstitutionalKnowledgeService service) async {
    final newStatus = doc.documentStatus == DocumentStatus.active
        ? DocumentStatus.archived
        : DocumentStatus.active;

    await service.updateDocumentStatus(
      widget.institution.id,
      doc.id,
      status: newStatus,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: AiTranslatedText(newStatus == DocumentStatus.active
            ? 'Documento marcado como Ativo.'
            : 'Documento arquivado.'),
        backgroundColor: newStatus == DocumentStatus.active
            ? const Color(0xFF00C853).withValues(alpha: 0.8)
            : Colors.orange.withValues(alpha: 0.8),
      ));
    }
  }

  Future<void> _editValidityDialog(
      InstitutionalKnowledgeDocument doc, InstitutionalKnowledgeService service) async {
    DateTime? from = doc.validFrom;
    DateTime? until = doc.validUntil;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Definir Período de Vigência',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _validityPickerRow(
                label: 'Início de Vigência',
                date: from,
                onPick: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: from ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF00FF85),
                          surface: Color(0xFF1E293B),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setStateDialog(() => from = picked);
                },
                onClear: () => setStateDialog(() => from = null),
              ),
              const SizedBox(height: 12),
              _validityPickerRow(
                label: 'Fim de Vigência',
                date: until,
                onPick: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: until ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF00FF85),
                          surface: Color(0xFF1E293B),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setStateDialog(() => until = picked);
                },
                onClear: () => setStateDialog(() => until = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF85),
                  foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                await service.updateDocumentStatus(
                  widget.institution.id,
                  doc.id,
                  status: doc.documentStatus,
                  validFrom: from,
                  validUntil: until,
                  clearValidFrom: from == null,
                  clearValidUntil: until == null,
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _validityPickerRow({
    required String label,
    required DateTime? date,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onPick,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    date != null ? _dateFmt.format(date) : 'Selecionar data',
                    style: TextStyle(
                        color: date != null ? Colors.white : Colors.white38, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
            onPressed: onClear,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<InstitutionalKnowledgeService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Repositório e Docs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF85),
          labelColor: const Color(0xFF00FF85),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Carregar Documento'),
            Tab(text: 'Gerir Documentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Upload ──────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildUploadSection(),
          ),
          // ── Tab 2: Manage ──────────────────────────────────────────
          _buildManageSection(service),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título do Documento',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<KnowledgeAccessType>(
              initialValue: _selectedAccess,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Quem pode acessar?',
                  labelStyle: TextStyle(color: Colors.white54)),
              items: KnowledgeAccessType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _selectedAccess = val!),
            ),
            if (_selectedAccess == KnowledgeAccessType.restricted)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextField(
                  controller: _emailsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Emails autorizados (separados por vírgula)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // ── Validity period ──────────────────────────────────────
            const Text('Período de Vigência (opcional)',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _datePickerButton(
                    label: 'Início',
                    date: _validFrom,
                    onTap: () => _pickDate(true),
                    onClear: () => setState(() => _validFrom = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _datePickerButton(
                    label: 'Fim',
                    date: _validUntil,
                    onTap: () => _pickDate(false),
                    onClear: () => setState(() => _validUntil = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: const AiTranslatedText('Selecionar e Carregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                  foregroundColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text(
                    date != null ? _dateFmt.format(date) : 'Sem data',
                    style: TextStyle(
                        color: date != null ? Colors.white : Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, color: Colors.white38, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageSection(InstitutionalKnowledgeService service) {
    return StreamBuilder<List<InstitutionalKnowledgeDocument>>(
      stream: service.streamAllDocuments(widget.institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF85)));
        }

        final docs = snapshot.data!;
        if (docs.isEmpty) {
          return const Center(
            child: AiTranslatedText('Nenhum documento carregado ainda.',
                style: TextStyle(color: Colors.white54)),
          );
        }

        final active = docs.where((d) => d.documentStatus == DocumentStatus.active).toList();
        final archived = docs.where((d) => d.documentStatus == DocumentStatus.archived).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (active.isNotEmpty) ...[
              _sectionHeader('Documentos Ativos', const Color(0xFF00FF85), Icons.check_circle),
              ...active.map((d) => _buildDocTile(d, service)),
              const SizedBox(height: 24),
            ],
            if (archived.isNotEmpty) ...[
              _sectionHeader('Arquivo', Colors.orange, Icons.inventory_2),
              ...archived.map((d) => _buildDocTile(d, service)),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDocTile(
      InstitutionalKnowledgeDocument doc, InstitutionalKnowledgeService service) {
    final isActive = doc.documentStatus == DocumentStatus.active;
    final statusColor = isActive ? const Color(0xFF00FF85) : Colors.orange;
    final statusLabel = isActive ? 'Ativo' : 'Arquivo';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──────────────────────────────────────────
              Row(
                children: [
                  Icon(_getIconForType(doc.fileType), color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(doc.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Meta info ──────────────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _metaChip(Icons.upload_rounded,
                      'Carregado: ${_dateFmt.format(doc.uploadDate)}'),
                  _metaChip(Icons.group, 'Acesso: ${doc.accessType.name}'),
                  if (doc.validFrom != null || doc.validUntil != null)
                    _metaChip(
                      Icons.event,
                      [
                        if (doc.validFrom != null)
                          'desde ${_dateFmt.format(doc.validFrom!)}',
                        if (doc.validUntil != null)
                          'até ${_dateFmt.format(doc.validUntil!)}',
                      ].join(' '),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Action row ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Toggle status
                  TextButton.icon(
                    onPressed: () => _toggleStatus(doc, service),
                    icon: Icon(
                      isActive ? Icons.inventory_2 : Icons.check_circle,
                      size: 16,
                      color: isActive ? Colors.orange : const Color(0xFF00FF85),
                    ),
                    label: Text(
                      isActive ? 'Arquivar' : 'Ativar',
                      style: TextStyle(
                          color: isActive ? Colors.orange : const Color(0xFF00FF85),
                          fontSize: 12),
                    ),
                  ),
                  // Edit validity
                  TextButton.icon(
                    onPressed: () => _editValidityDialog(doc, service),
                    icon: const Icon(Icons.date_range, size: 16, color: Colors.white54),
                    label: const Text('Vigência',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => _confirmDelete(doc, service),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Future<void> _confirmDelete(
      InstitutionalKnowledgeDocument doc, InstitutionalKnowledgeService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Documento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Tem a certeza que quer eliminar "${doc.title}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.deleteDocument(widget.institution.id, doc.id, doc.url);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.text_snippet;
    }
  }
}
