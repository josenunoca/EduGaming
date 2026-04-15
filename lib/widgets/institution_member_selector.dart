import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class InstitutionMemberSelector extends StatefulWidget {
  final String institutionId;
  final List<String> initialSelectedEmails;
  final Function(List<UserModel>) onSelectionChanged;

  const InstitutionMemberSelector({
    super.key,
    required this.institutionId,
    this.initialSelectedEmails = const [],
    required this.onSelectionChanged,
  });

  @override
  State<InstitutionMemberSelector> createState() =>
      _InstitutionMemberSelectorState();
}

class _InstitutionMemberSelectorState extends State<InstitutionMemberSelector> {
  final List<UserModel> _selectedUsers = [];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Column(
      children: [
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Pesquisar nome ou email...',
            prefixIcon: Icon(Icons.search, color: Colors.white54),
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<UserModel>>(
          future: service.searchInstitutionMembers(
              widget.institutionId, _searchQuery),
          builder: (context, snapshot) {
            final members = snapshot.data ?? [];
            return SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final user = members[index];
                  final isSelected =
                      _selectedUsers.any((u) => u.email == user.email) ||
                          widget.initialSelectedEmails.contains(user.email);

                  return CheckboxListTile(
                    title: Text(user.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(user.email,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    value: isSelected,
                    activeColor: const Color(0xFF7B61FF),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (!_selectedUsers
                              .any((u) => u.email == user.email)) {
                            _selectedUsers.add(user);
                          }
                        } else {
                          _selectedUsers
                              .removeWhere((u) => u.email == user.email);
                        }
                      });
                      widget.onSelectionChanged(_selectedUsers);
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
