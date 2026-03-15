import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';

class MarketingCommunicationScreen extends StatefulWidget {
  const MarketingCommunicationScreen({super.key});

  @override
  State<MarketingCommunicationScreen> createState() =>
      _MarketingCommunicationScreenState();
}

class _MarketingCommunicationScreenState
    extends State<MarketingCommunicationScreen> {
  UserRole? _filterRole;
  String? _filterInstitutionId;
  String? _filterScientificArea;
  final List<String> _selectedInterests = [];

  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  List<UserModel> _filteredUsers = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFilter());
  }

  void _addInterest(String interest) {
    if (interest.isNotEmpty && !_selectedInterests.contains(interest)) {
      setState(() => _selectedInterests.add(interest));
      _runFilter();
    }
  }

  Future<void> _runFilter() async {
    setState(() => _isLoading = true);
    final service = context.read<FirebaseService>();
    final users = await service.getFilteredUsersForMarketing(
      role: _filterRole,
      institutionId: _filterInstitutionId,
      interests: _selectedInterests.isEmpty ? null : _selectedInterests,
      scientificArea: _filterScientificArea,
    );
    setState(() {
      _filteredUsers = users;
      _isLoading = false;
      // Reset selection if users change significantly?
      // For now, keep selection if the user is still in the list
      _selectedUserIds.retainWhere((id) => users.any((u) => u.id == id));
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedUserIds.addAll(_filteredUsers.map((u) => u.id));
      } else {
        _selectedUserIds.clear();
      }
    });
  }

  void _sendCommunication() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText('Nenhum destinatário selecionado.')),
      );
      return;
    }

    final selectedUsers =
        _filteredUsers.where((u) => _selectedUserIds.contains(u.id)).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Simulação de Envio',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Enviando para ${selectedUsers.length} utilizadores selecionados...\n\nAssunto: ${_subjectController.text}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    final scientificAreas = FirebaseService.getScientificAreas();

    return Scaffold(
      appBar: AppBar(title: const AiTranslatedText('Marketing & Comunicação')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Filtros Segmentados',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 16),

                    // Filter Row 1: Role & Institution
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<UserRole?>(
                            initialValue: _filterRole,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                                labelText: 'Nível de Utilizador',
                                border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Todos')),
                              ...UserRole.values.map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.toString().split('.').last))),
                            ],
                            onChanged: (v) {
                              setState(() => _filterRole = v);
                              _runFilter();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StreamBuilder<List<InstitutionModel>>(
                              stream: service.getInstitutions(),
                              builder: (context, snapshot) {
                                final institutions = snapshot.data ?? [];
                                return DropdownButtonFormField<String?>(
                                  initialValue: _filterInstitutionId,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      labelText: 'Instituição',
                                      border: OutlineInputBorder()),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('Todas')),
                                    ...institutions.map((i) => DropdownMenuItem(
                                        value: i.id, child: Text(i.name))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _filterInstitutionId = v);
                                    _runFilter();
                                  },
                                );
                              }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Row 2: Scientific Area
                    DropdownButtonFormField<String?>(
                      initialValue: _filterScientificArea,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Área Científica (via Disciplina)',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Qualquer')),
                        ...scientificAreas.map(
                            (a) => DropdownMenuItem(value: a, child: Text(a))),
                      ],
                      onChanged: (v) {
                        setState(() => _filterScientificArea = v);
                        _runFilter();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Interests Filter
                    const AiTranslatedText('Interesses (Incluir qualquer):',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._selectedInterests.map((i) => Chip(
                              label: Text(i,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)),
                              backgroundColor: const Color(0xFF7B61FF)
                                  .withValues(alpha: 0.3),
                              onDeleted: () {
                                setState(() => _selectedInterests.remove(i));
                                _runFilter();
                              },
                            )),
                        ActionChip(
                          label: const Text('+',
                              style: TextStyle(color: Color(0xFF7B61FF))),
                          onPressed: () {
                            final controller = TextEditingController();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const AiTranslatedText(
                                    'Adicionar Interesse ao Filtro',
                                    style: TextStyle(color: Colors.white)),
                                content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child:
                                          const AiTranslatedText('Cancelar')),
                                  ElevatedButton(
                                    onPressed: () {
                                      _addInterest(controller.text);
                                      Navigator.pop(context);
                                    },
                                    child: const AiTranslatedText('Adicionar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AiTranslatedText(
                            'Destinatários Encontrados: ${_filteredUsers.length}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold),
                          ),
                          if (_filteredUsers.isNotEmpty)
                            Row(
                              children: [
                                const AiTranslatedText('Selecionar Todos',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                                Checkbox(
                                  value: _selectedUserIds.length ==
                                          _filteredUsers.length &&
                                      _filteredUsers.isNotEmpty,
                                  onChanged: _toggleSelectAll,
                                  activeColor: const Color(0xFF7B61FF),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      ..._filteredUsers.map((user) => Card(
                            color: Colors.white.withValues(alpha: 0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CheckboxListTile(
                              value: _selectedUserIds.contains(user.id),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUserIds.add(user.id);
                                  } else {
                                    _selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                              title: Text(user.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  '${user.email} • ${user.role.toString().split('.').last}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              activeColor: const Color(0xFF7B61FF),
                              checkColor: Colors.white,
                            ),
                          )),
                    ],
                    const SizedBox(height: 24),

                    // Message fields could go here if needed to be persistent
                    const AiTranslatedText('Composição da Mensagem',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _subjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Assunto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bodyController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Mensagem',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 80), // Spacer for fab/button
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(color: const Color(0xFF0F172A), boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ]),
              child: ElevatedButton.icon(
                onPressed: _sendCommunication,
                icon: const Icon(Icons.send),
                label: AiTranslatedText(
                    'Enviar para o Grupo (${_selectedUserIds.length})'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: const Color(0xFF7B61FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
