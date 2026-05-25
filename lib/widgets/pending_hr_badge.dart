import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../models/hr/hr_absence_model.dart';
import '../screens/institution/hr/hr_management_screen.dart';

class PendingHRBadge extends StatelessWidget {
  final UserModel user;
  final InstitutionModel institution;

  const PendingHRBadge({
    super.key,
    required this.user,
    required this.institution,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    // Check if the user is the Institution itself OR has delegated HR/Global responsibilities
    final isHRManager = user.role == UserRole.institution ||
        user.role == UserRole.admin ||
        (institution.delegatedRoles['hr']?.contains(user.id) ?? false) ||
        (institution.delegatedRoles['global_360']?.contains(user.id) ?? false);

    if (!isHRManager) return const SizedBox.shrink();

    return StreamBuilder<List<HRAbsence>>(
      stream: service.getHRAbsences(institution.id),
      builder: (context, snapshot) {
        final pendingCount = snapshot.hasData
            ? snapshot.data!.where((a) => a.status == 'pending').length
            : 0;

        if (pendingCount == 0) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.assignment_late, color: Colors.orangeAccent),
              tooltip: 'Pedidos de RH Pendentes',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HRManagementScreen(institution: institution),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  pendingCount > 9 ? '9+' : pendingCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
