import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class UserAccessScreen extends StatelessWidget {
  const UserAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      appBar: AppBar(title: const AiTranslatedText('Controlo de Acessos')),
      body: StreamBuilder<List<UserModel>>(
        stream: service.getUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: AiTranslatedText('Nenhum utilizador encontrado.'));
          }

          final users = snapshot.data!.where((u) => u.role != UserRole.admin).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: ListTile(
                    title: AiTranslatedText(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: AiTranslatedText('${user.email}\nPapel: ${user.role.name}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AccessToggle(
                          label: 'Pago',
                          value: user.isPaymentVerified,
                          onChanged: (val) => service.updateUserAccess(user.id, isPaymentVerified: val),
                        ),
                        const SizedBox(width: 8),
                        _AccessToggle(
                          label: 'Manual',
                          value: user.hasManualAccess,
                          onChanged: (val) => service.updateUserAccess(user.id, hasManualAccess: val),
                          activeColor: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        _AccessToggle(
                          label: 'Suspenso',
                          value: user.isSuspended,
                          onChanged: (val) => service.toggleUserSuspension(user.id, val),
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AccessToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _AccessToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AiTranslatedText(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
