import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/management_document_model.dart';
import '../../services/firebase_service.dart';
import 'ai_chat_dialog.dart';
import 'signature_dialog.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import 'package:uuid/uuid.dart';

class ManagementDocumentSection extends StatefulWidget {
  final String ownerId;
  final ManagementDocumentOwnerType ownerType;
  final String title;

  const ManagementDocumentSection({
    super.key,
    required this.ownerId,
    required this.ownerType,
    required this.title,
  });

  @override
  State<ManagementDocumentSection> createState() => _ManagementDocumentSectionState();
}

class _ManagementDocumentSectionState extends State<ManagementDocumentSection> {
  final Set<String> _selectedDocIds = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Row(
              children: [
                if (!_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7B61FF)),
                    onPressed: () => _showUploadDialog(context),
                    tooltip: 'Carregar Documento',
                  ),
                IconButton(
                  icon: Icon(_isSelectionMode ? Icons.close : Icons.chat_outlined,
                      color: _isSelectionMode ? Colors.redAccent : Colors.white70),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedDocIds.clear();
                    });
                  },
                  tooltip: _isSelectionMode ? 'Cancelar Seleção' : 'DocTalk (Conversar com Docs)',
                ),
              ],
            ),
          ],
        ),
        if (_isSelectionMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Text('${_selectedDocIds.length} selecionados',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectedDocIds.isEmpty ? null : () => _startDocTalk(context),
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: const Text('Iniciar DocTalk'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        StreamBuilder<List<ManagementDocument>>(
          stream: service.getManagementDocuments(widget.ownerId, widget.ownerType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Nenhum documento disponível.',
                    style: TextStyle(color: Colors.white54)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isSelected = _selectedDocIds.contains(doc.id);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                    color: isSelected ? const Color(0xFF7B61FF) : _getStatusColor(doc.status),
                  ),
                  title: Text(doc.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${doc.category} • ${doc.createdAt.day}/${doc.createdAt.month}/${doc.createdAt.year}',
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      if (doc.requiredSignerIds.isNotEmpty)
                        Text('Assinaturas: ${doc.signatures.length}/${doc.requiredSignerIds.length}',
                            style: TextStyle(
                                color: doc.isFullySigned ? Colors.greenAccent : Colors.amberAccent,
                                fontSize: 11)),
                    ],
                  ),
                  trailing: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF7B61FF),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDocIds.add(doc.id);
                              } else {
                                _selectedDocIds.remove(doc.id);
                              }
                            });
                          },
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isUserRequiredSigner(doc))
                              IconButton(
                                icon: const Icon(Icons.draw, color: Colors.amberAccent, size: 20),
                                onPressed: () => _openSignatureDialog(context, doc),
                                tooltip: 'Assinar Documento',
                              ),
                            IconButton(
                              icon: const Icon(Icons.download, color: Colors.white54, size: 20),
                              onPressed: () => _downloadFile(doc.url),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmDelete(context, doc),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(ManagementDocumentStatus status) {
    switch (status) {
      case ManagementDocumentStatus.completed: return Colors.greenAccent;
      case ManagementDocumentStatus.signing: return Colors.amberAccent;
      case ManagementDocumentStatus.rejected: return Colors.redAccent;
      default: return Colors.white38;
    }
  }

  bool _isUserRequiredSigner(ManagementDocument doc) {
    // Current logical condition: it's not fully signed AND current user is next in line
    if (doc.isFullySigned) return false;
    const currentUserId = 'admin'; // Simulation: In real app, get from Auth service
    
    // Check if user is in requiredSignerIds and hasn't signed yet
    final nextSignerIndex = doc.signatures.length;
    if (nextSignerIndex < doc.requiredSignerIds.length) {
      return doc.requiredSignerIds[nextSignerIndex] == currentUserId;
    }
    return false;
  }

  void _openSignatureDialog(BuildContext context, ManagementDocument doc) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SignatureDialog(
        docTitle: doc.title,
        userName: 'Admin User', // Mock
      ),
    );

    if (result != null && context.mounted) {
      final entry = SignatureEntry(
        userId: 'admin',
        userName: 'Admin User',
        timestamp: DateTime.now(),
        signatureType: result,
        ipAddress: '192.168.1.1',
      );
      await context.read<FirebaseService>().signDocument(doc.id, entry);
    }
  }

  void _showUploadDialog(BuildContext context) {
    final titleController = TextEditingController();
    String category = 'other';
    bool isUploading = false;
    List<String> selectedSignerIds = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Carregar Documento', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título do Documento',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: const Color(0xFF1E1E2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'constitution', child: Text('Constituição/Empresa')),
                    DropdownMenuItem(value: 'approval', child: Text('Aprovação Ciclo')),
                    DropdownMenuItem(value: 'minutes', child: Text('Atas')),
                    DropdownMenuItem(value: 'contract', child: Text('Contrato Docente')),
                    DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val!),
                ),
                const SizedBox(height: 16),
                const Text('Workflow de Assinatura (Opcional):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                StreamBuilder<List<UserModel>>(
                  stream: Stream.fromFuture(context.read<FirebaseService>().getEligibleUsers()),
                  builder: (context, usersSnap) {
                    final users = usersSnap.data ?? [];
                    return Column(
                      children: users.map((u) => CheckboxListTile(
                        title: Text(u.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: Text(u.role.name, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        value: selectedSignerIds.contains(u.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedSignerIds.add(u.id);
                            } else {
                              selectedSignerIds.remove(u.id);
                            }
                          });
                        },
                      )).toList(),
                    );
                  },
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.isEmpty) return;
                      setDialogState(() => isUploading = true);
                      
                      // Mocking file upload
                      await Future.delayed(const Duration(seconds: 1));
                      
                      final newDoc = ManagementDocument(
                        id: const Uuid().v4(),
                        ownerId: widget.ownerId,
                        ownerType: widget.ownerType,
                        title: titleController.text,
                        url: 'https://example.com/mock_doc.pdf',
                        fileType: 'pdf',
                        category: category,
                        createdBy: 'admin', // Simulation
                        createdAt: DateTime.now(),
                        requiredSignerIds: selectedSignerIds,
                      );

                      if (context.mounted) {
                        await context.read<FirebaseService>().saveManagementDocument(newDoc);
                        Navigator.pop(context);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
              child: const Text('Carregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _confirmDelete(BuildContext context, ManagementDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Eliminar Documento', style: TextStyle(color: Colors.white)),
        content: Text('Deseja eliminar o documento "${doc.title}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<FirebaseService>().deleteManagementDocument(doc.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _startDocTalk(BuildContext context) async {
    final service = context.read<FirebaseService>();
    final allDocs = await service.getManagementDocuments(widget.ownerId, widget.ownerType).first;
    final selectedDocs = allDocs.where((d) => _selectedDocIds.contains(d.id)).toList();
    
    // Convert ManagementDocument to SubjectContent to satisfy the dialog
    final mappedContents = selectedDocs.map((d) => SubjectContent(
      id: d.id,
      name: d.title,
      url: d.url,
      type: 'document',
      category: 'support',
      modificationLog: [],
    )).toList();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AiChatDialog(
          selectedContents: mappedContents,
          isStudent: false,
        ),
      );
    }
  }
}
