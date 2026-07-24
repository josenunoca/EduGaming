import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/internal_message.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/ai_text_field.dart';

class ComposeMessageScreen extends StatefulWidget {
  final List<String>? initialRecipientIds;
  final List<String>? initialCcIds;
  final String? initialSubject;

  const ComposeMessageScreen({
    super.key,
    this.initialRecipientIds,
    this.initialCcIds,
    this.initialSubject,
  });

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<String> _selectedRecipientIds = [];
  final List<String> _selectedCcIds = [];
  final List<Map<String, String>> _attachments = [];
  List<UserModel> _potentialRecipients = [];
  bool _isSending = false;
  bool _showCc = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipientIds != null) {
      _selectedRecipientIds.addAll(widget.initialRecipientIds!);
    }
    if (widget.initialCcIds != null) {
      _selectedCcIds.addAll(widget.initialCcIds!);
      _showCc = true;
    }
    if (widget.initialSubject != null) {
      _subjectController.text = widget.initialSubject!;
    }
    _fetchPotentialRecipients();
  }

  Future<void> _fetchPotentialRecipients() async {
    final service = context.read<FirebaseService>();
    final currentUserData =
        await service.getUserData(service.currentUser?.uid ?? '');
    if (currentUserData == null) return;

    // Fetch all relevant users for the role
    List<UserModel> recipients = await service.getUsers().first;

    // Remove self
    recipients.removeWhere((u) => u.id == currentUserData.id);

    setState(() {
      _potentialRecipients = recipients;
    });
  }

  void _insertImageIntoBody(String name, String base64OrUrl) {
    final tag = '\n![$name]($base64OrUrl)\n';
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    
    if (selection.isValid && selection.start >= 0) {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, tag);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + tag.length),
      );
    } else {
      _bodyController.text = text + tag;
    }
  }

  void _promptInsertImage(String name, String base64OrUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Imagem Adicionada', style: TextStyle(color: Colors.white)),
        content: const Text('Deseja inserir esta imagem diretamente no corpo do e-mail?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Apenas Anexo', style: TextStyle(color: Colors.white38)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
            child: const Text('Inserir no Corpo', style: TextStyle(color: Colors.white)),
            onPressed: () {
              _insertImageIntoBody(name, base64OrUrl);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Imagem inserida no corpo da mensagem!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageAndInsert() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final base64Data = base64Encode(file.bytes!);
          final ext = file.extension?.toLowerCase() ?? 'png';
          final dataUri = 'data:image/$ext;base64,$base64Data';
          
          setState(() {
            _attachments.add({
              'name': file.name,
              'type': 'image',
              'data': dataUri,
            });
          });
          
          _insertImageIntoBody(file.name, dataUri);
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imagem "${file.name}" inserida no corpo da mensagem!')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar imagem: $e')),
      );
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.bytes != null) {
            final base64Data = base64Encode(file.bytes!);
            final ext = file.extension?.toLowerCase() ?? '';
            final isImg = (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif');
            final mimeType = ext == 'pdf'
                ? 'application/pdf'
                : isImg
                    ? 'image/$ext'
                    : 'application/octet-stream';
            final dataUri = 'data:$mimeType;base64,$base64Data';
            
            setState(() {
              _attachments.add({
                'name': file.name,
                'type': isImg ? 'image' : 'file',
                'data': dataUri,
              });
            });

            if (isImg && mounted) {
              _promptInsertImage(file.name, dataUri);
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao anexar ficheiro: $e')),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!.trim();
        // Check if it's a base64 image or a web URL
        if (text.startsWith('data:image/') && text.contains(';base64,')) {
          final name = 'imagem_colada_${DateTime.now().millisecondsSinceEpoch}.png';
          setState(() {
            _attachments.add({
              'name': name,
              'type': 'image',
              'data': text,
            });
          });
          if (!mounted) return;
          _promptInsertImage(name, text);
          return;
        } else if (text.startsWith('http://') || text.startsWith('https://')) {
          final isImage = text.endsWith('.png') || text.endsWith('.jpg') || text.endsWith('.jpeg') || text.endsWith('.gif');
          if (isImage) {
            final name = text.split('/').last;
            setState(() {
              _attachments.add({
                'name': name,
                'type': 'image',
                'data': text,
              });
            });
            if (!mounted) return;
            _promptInsertImage(name, text);
            return;
          }
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma imagem ou link de imagem detectado na área de transferência. Use a opção "Inserir Imagem".'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao colar: $e')),
      );
    }
  }

  void _sendMessage() async {
    if (_selectedRecipientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText(
                'Por favor, selecione pelo menos um destinatário.')),
      );
      return;
    }
    if (_subjectController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText(
                'Por favor, preencha o assunto e a mensagem.')),
      );
      return;
    }

    setState(() => _isSending = true);
    final service = context.read<FirebaseService>();
    final currentUserData =
        await service.getUserData(service.currentUser?.uid ?? '');

    final message = InternalMessage(
      id: const Uuid().v4(),
      senderId: currentUserData!.id,
      senderName: currentUserData.name,
      recipientIds: _selectedRecipientIds,
      ccIds: _selectedCcIds,
      subject: _subjectController.text,
      body: _bodyController.text,
      timestamp: DateTime.now(),
      attachments: _attachments.map((att) => jsonEncode(att)).toList(),
    );

    await service.sendInternalMessage(message);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText('Mensagem enviada com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AiTranslatedText('Compor Mensagem'),
        actions: [
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecipientField('Para:', _selectedRecipientIds, isCc: false),
              const SizedBox(height: 12),
              if (!_showCc)
                TextButton(
                  onPressed: () => setState(() => _showCc = true),
                  child: const AiTranslatedText('+ Adicionar Cc',
                      style: TextStyle(color: Color(0xFF00D1FF))),
                )
              else
                _buildRecipientField('Cc:', _selectedCcIds, isCc: true),
              const SizedBox(height: 24),
              AiTextField(
                controller: _subjectController,
                labelText: 'Assunto',
              ),
              const SizedBox(height: 16),
              AiTextField(
                controller: _bodyController,
                maxLines: 10,
                labelText: 'Mensagem',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Anexos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste, size: 16, color: Color(0xFF00D1FF)),
                        label: const Text('Colar Imagem', style: TextStyle(color: Color(0xFF00D1FF), fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _pickImageAndInsert,
                        icon: const Icon(Icons.image, size: 16, color: Color(0xFF00FF85)),
                        label: const Text('Inserir Imagem', style: TextStyle(color: Color(0xFF00FF85), fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: const Text('Anexo', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Nenhum anexo adicionado. Cole uma imagem ou anexe um ficheiro.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final att = _attachments[index];
                    final isImage = att['type'] == 'image';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          if (isImage && att['data'] != null && att['data']!.startsWith('data:'))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                base64Decode(att['data']!.split(',').last),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Icon(
                              isImage ? Icons.image : Icons.insert_drive_file,
                              color: const Color(0xFF00D1FF),
                              size: 24,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  att['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isImage ? 'Imagem' : 'Documento / Ficheiro',
                                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            onPressed: () => setState(() => _attachments.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientField(String label, List<String> selectedIds,
      {required bool isCc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiTranslatedText(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ...selectedIds.map((id) {
              final user = _potentialRecipients.firstWhere((u) => u.id == id,
                  orElse: () => UserModel(
                      id: id,
                      name: id.contains('@') ? id : '...',
                      email: id.contains('@') ? id : '',
                      role: UserRole.student,
                      adConsent: false,
                      dataConsent: false));
              final displayName = user.name != '...' ? user.name : id;
              return InputChip(
                label: Text(displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.3),
                onDeleted: () => setState(() => selectedIds.remove(id)),
              );
            }),
            ActionChip(
              label:
                  const Text('+', style: TextStyle(color: Color(0xFF7B61FF))),
              onPressed: () => _showRecipientPicker(isCc),
            ),
          ],
        ),
      ],
    );
  }

  void _showRecipientPicker(bool isCc) {
    String searchQuery = '';
    final service = context.read<FirebaseService>();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) => StreamBuilder<List<UserModel>>(
              stream: service.getUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }

                final allUsers = snapshot.data ?? [];
                // Filter self out
                final currentUserId = service.currentUser?.uid ?? '';
                allUsers.removeWhere((u) => u.id == currentUserId);

                return StatefulBuilder(
                  builder: (context, setModalState) {
                    final filteredList = allUsers.where((u) {
                      final nameMatch = u.name
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());
                      final emailMatch = u.email
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());
                      return nameMatch || emailMatch;
                    }).toList();

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  AiTranslatedText(
                                      isCc
                                          ? 'Selecionar Cc'
                                          : 'Selecionar Destinatários',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close,
                                          color: Colors.white54)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                onChanged: (val) =>
                                    setModalState(() => searchQuery = val),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar nome ou email...',
                                  hintStyle:
                                      const TextStyle(color: Colors.white38),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Color(0xFF00D1FF)),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (searchQuery.trim().contains('@')) ...[
                          ListTile(
                            leading: const Icon(Icons.mark_email_unread, color: Color(0xFF00FF85)),
                            title: Text('Adicionar e-mail externo: ${searchQuery.trim()}',
                                style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
                            subtitle: const Text('Enviar mensagem direta para este e-mail',
                                style: TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFF00FF85)),
                              onPressed: () {
                                final email = searchQuery.trim();
                                final listToUpdate = isCc ? _selectedCcIds : _selectedRecipientIds;
                                if (!listToUpdate.contains(email)) {
                                  setState(() => listToUpdate.add(email));
                                }
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const Divider(color: Colors.white10),
                        ],
                        Expanded(
                          child: filteredList.isEmpty && !searchQuery.trim().contains('@')
                              ? const Center(
                                  child: AiTranslatedText(
                                      'Nenhum resultado encontrado.',
                                      style: TextStyle(color: Colors.white38)))
                              : ListView.builder(
                                  controller: controller,
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final user = filteredList[index];
                                    final listToUpdate = isCc
                                        ? _selectedCcIds
                                        : _selectedRecipientIds;
                                    final isSelected =
                                        listToUpdate.contains(user.id);

                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            listToUpdate.add(user.id);
                                          } else {
                                            listToUpdate.remove(user.id);
                                          }
                                        });
                                        setState(() {}); // Update main screen
                                      },
                                      title: Text(user.name,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      subtitle: Text(
                                          '${user.email} • ${user.role.toString().split('.').last}',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                      activeColor: const Color(0xFF7B61FF),
                                      secondary: CircleAvatar(
                                        backgroundColor: const Color(0xFF7B61FF)
                                            .withValues(alpha: 0.2),
                                        child: Text(
                                            user.name
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: Color(0xFF7B61FF),
                                                fontSize: 12)),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        });
  }
}
