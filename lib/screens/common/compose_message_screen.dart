import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
                      name: '...',
                      email: '',
                      role: UserRole.student,
                      adConsent: false,
                      dataConsent: false));
              return InputChip(
                label: Text(user.name,
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
                        Expanded(
                          child: filteredList.isEmpty
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
