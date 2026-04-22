import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/institutional_organ_model.dart';
import '../services/firebase_service.dart';
import 'glass_card.dart';

enum ParticipantGroupType {
  docentes,
  naoDocentes,
  alunos,
  encarregados,
  orgaos,
  manual,
}

extension ParticipantGroupTypeLabel on ParticipantGroupType {
  String get label {
    switch (this) {
      case ParticipantGroupType.docentes:
        return 'Pessoal Docente';
      case ParticipantGroupType.naoDocentes:
        return 'Pessoal Não Docente';
      case ParticipantGroupType.alunos:
        return 'Alunos';
      case ParticipantGroupType.encarregados:
        return 'Encarregados de Educação';
      case ParticipantGroupType.orgaos:
        return 'Membros de Orgãos';
      case ParticipantGroupType.manual:
        return 'Adicionar Manualmente';
    }
  }
}

class ParticipantSelectorDialog extends StatefulWidget {
  final String institutionId;
  final List<String> initialSelectedEmails;
  final bool showGroups;

  const ParticipantSelectorDialog({
    super.key,
    required this.institutionId,
    this.initialSelectedEmails = const [],
    this.showGroups = true,
  });

  @override
  State<ParticipantSelectorDialog> createState() => _ParticipantSelectorDialogState();
}

class _ParticipantSelectorDialogState extends State<ParticipantSelectorDialog> {
  ParticipantGroupType? _selectedGroup;
  String? _selectedOrganId;
  List<UserModel> _availableParticipants = [];
  final Set<String> _selectedEmails = {};
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedEmails.addAll(widget.initialSelectedEmails);
  }

  Future<void> _loadGroup(ParticipantGroupType group, {String? organId}) async {
    setState(() {
      _isLoading = true;
      _selectedGroup = group;
      _selectedOrganId = organId;
    });

    final service = context.read<FirebaseService>();
    List<UserModel> members = [];

    try {
      switch (group) {
        case ParticipantGroupType.docentes:
          members = await service.getInstitutionDocentes(widget.institutionId);
          break;
        case ParticipantGroupType.naoDocentes:
          members = await service.getInstitutionNaoDocentes(widget.institutionId);
          break;
        case ParticipantGroupType.alunos:
          // Ideally a service method getInstitutionStudents
          final all = await service.getAllInstitutionMembers(widget.institutionId);
          members = all.where((u) => u.role == UserRole.student).toList();
          break;
        case ParticipantGroupType.encarregados:
          final all = await service.getAllInstitutionMembers(widget.institutionId);
          members = all.where((u) => u.role == UserRole.parent).toList();
          break;
        case ParticipantGroupType.orgaos:
          if (organId != null) {
            members = await service.getOrganMembers(widget.institutionId, organId);
          }
          break;
        case ParticipantGroupType.manual:
          members = [];
          break;
      }

      setState(() {
        _availableParticipants = members;
        // Auto-select all from group if it's the first load of this group
        for (var m in members) {
          if (!widget.initialSelectedEmails.contains(m.email)) {
             _selectedEmails.add(m.email);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar grupo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selecionar Participantes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedGroup == null) _buildGroupSelection() else _buildMemberSelection(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedEmails.toList());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B61FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Confirmar (${_selectedEmails.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelection() {
    return Column(
      children: [
        const Text(
          'Escolha um grupo para começar ou adicione manualmente.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ParticipantGroupType.values.map((type) {
            if (type == ParticipantGroupType.orgaos) {
              return _buildOrganDropdown();
            }
            return _buildGroupChip(type);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupChip(ParticipantGroupType type) {
    return ActionChip(
      label: Text(type.label),
      backgroundColor: Colors.white.withOpacity(0.1),
      labelStyle: const TextStyle(color: Colors.white),
      onPressed: () => _loadGroup(type),
    );
  }

  Widget _buildOrganDropdown() {
    final service = context.read<FirebaseService>();
    return FutureBuilder<List<InstitutionalOrgan>>(
      future: _loadOrgans(service),
      builder: (context, snapshot) {
        final organs = snapshot.data ?? [];
        if (organs.isEmpty) return const SizedBox.shrink();
        
        return PopupMenuButton<String>(
          child: Chip(
            label: const Text('Orgãos Institucionais', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.white.withOpacity(0.1),
            deleteIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            onDeleted: () {}, // Just to show the icon
          ),
          onSelected: (id) => _loadGroup(ParticipantGroupType.orgaos, organId: id),
          itemBuilder: (context) => organs.map((o) => PopupMenuItem(
            value: o.id,
            child: Text(o.name),
          )).toList(),
        );
      },
    );
  }

  Future<List<InstitutionalOrgan>> _loadOrgans(FirebaseService service) async {
    // There is probably a getInstitutionalOrgansStream, but we need a future here for simplicity in build
    // Returning mock or empty if not easily fetchable as future
    final snapshot = await service.getInstitutionalOrgans(widget.institutionId).first;
    return snapshot;
  }

  Widget _buildMemberSelection() {
    final filteredMembers = _availableParticipants.where((m) => 
      m.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      m.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => setState(() {
                _selectedGroup = null;
                _availableParticipants = [];
              }),
            ),
            Text(
              _selectedGroup?.label ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedEmails.length == filteredMembers.length) {
                    _selectedEmails.clear();
                  } else {
                    _selectedEmails.addAll(filteredMembers.map((m) => m.email));
                  }
                });
              },
              child: Text(
                _selectedEmails.length == filteredMembers.length ? 'Desmarcar Todos' : 'Marcar Todos',
                style: const TextStyle(color: Color(0xFF7B61FF), fontSize: 12),
              ),
            ),
          ],
        ),
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Filtrar membros...',
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 350,
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                final isSelected = _selectedEmails.contains(member.email);
                return CheckboxListTile(
                  title: Text(member.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(member.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  value: isSelected,
                  activeColor: const Color(0xFF7B61FF),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedEmails.add(member.email);
                      } else {
                        _selectedEmails.remove(member.email);
                      }
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
