import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
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

class _KnowledgeManagementScreenState extends State<KnowledgeManagementScreen> {
  bool _isUploading = false;
  KnowledgeAccessType _selectedAccess = KnowledgeAccessType.all;
  final TextEditingController _emailsController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  Future<String?> _extractText(PlatformFile file) async {
    try {
      final bytes = file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);
      if (bytes == null) return null;

      if (file.extension == 'pdf') {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      } else if (file.extension == 'txt') {
        return utf8.decode(bytes);
      } else if (file.extension == 'docx') {
        // Simple fallback or warning for docx if extractor fails
        return 'Conteúdo do documento Word: ${file.name} (Extração de texto total para DOCX em desenvolvimento)';
      }
    } catch (e) {
      debugPrint('Text extraction error: $e');
    }
    return null;
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    
    // Fetch providers before async gap
    final service = context.read<InstitutionalKnowledgeService>();
    final firebase = context.read<FirebaseService>();
    final messenger = ScaffoldMessenger.of(context);

    if (_titleController.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: AiTranslatedText('Por favor, defina um título.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Não foi possível ler os dados do ficheiro.');
      }

      // 1. Upload to Storage using bytes (Web-compatible)
      final url = await firebase.uploadFileBytes(
        bytes,
        'institutions/${widget.institution.id}/knowledge/${file.name}',
      );

      // 2. Extract Text for AI
      final extractedText = await _extractText(file);

      // 3. Save Metadata
      final doc = InstitutionalKnowledgeDocument(
        id: const Uuid().v4(),
        title: _titleController.text,
        url: url,
        fileName: file.name,
        fileType: file.extension ?? 'pdf',
        uploadDate: DateTime.now(),
        accessType: _selectedAccess,
        restrictedEmails: _emailsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        extractedText: extractedText,
        institutionId: widget.institution.id,
      );

      await service.addDocument(doc);

      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: AiTranslatedText('Documento adicionado com sucesso!')));
        _titleController.clear();
        _emailsController.clear();
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadSection(),
            const SizedBox(height: 32),
            const AiTranslatedText('Documentos Ativos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<List<InstitutionalKnowledgeDocument>>(
              stream: service.streamAllDocuments(widget.institution.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildDocTile(docs[index], service),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título do Documento',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<KnowledgeAccessType>(
              value: _selectedAccess,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Quem pode acessar?', labelStyle: TextStyle(color: Colors.white54)),
              items: KnowledgeAccessType.values.map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.name.toUpperCase()),
              )).toList(),
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
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: _isUploading ? const CircularProgressIndicator() : const Icon(Icons.upload_file),
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

  Widget _buildDocTile(InstitutionalKnowledgeDocument doc, InstitutionalKnowledgeService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Icon(_getIconForType(doc.fileType), color: Colors.blueAccent),
          title: Text(doc.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Acesso: ${doc.accessType.name}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
            onPressed: () => service.deleteDocument(widget.institution.id, doc.id, doc.url),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'docx': return Icons.description;
      default: return Icons.text_snippet;
    }
  }
}
