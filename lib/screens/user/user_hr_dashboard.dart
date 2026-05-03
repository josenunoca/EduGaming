import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../../models/hr/hr_attendance_model.dart';
import '../../../models/hr/hr_schedule_model.dart';
import '../../../models/hr/hr_absence_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import 'widgets/hr_attendance_scanner.dart';
import 'widgets/hr_face_scanner.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UserHRDashboard extends StatefulWidget {
  final UserModel user;

  const UserHRDashboard({super.key, required this.user});

  @override
  State<UserHRDashboard> createState() => _UserHRDashboardState();
}

class _UserHRDashboardState extends State<UserHRDashboard> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final institutionId = widget.user.institutionId;

    if (institutionId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(title: const AiTranslatedText('Minha Área RH')),
        body: const Center(child: AiTranslatedText('Não está associado a nenhuma instituição.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const AiTranslatedText('Minha Área RH')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayShift(service, institutionId),
            const SizedBox(height: 32),
            _buildQuickActions(),
            const SizedBox(height: 32),
            const AiTranslatedText(
              'Histórico de Assiduidade (Este Mês)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAttendanceHistory(service, institutionId),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayShift(FirebaseService service, String instId) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText(
                  'Próximo Horário',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HRAttendanceScanner(
                          onScan: (qrCode) async {
                            // After QR, open Face Scanner
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HRFaceScanner(
                                  onFaceVerified: (photo) async {
                                    // 1. Upload proof photo
                                    final ref = FirebaseStorage.instance
                                        .ref()
                                        .child('attendance_proofs/${instId}/${widget.user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                                    await ref.putFile(File(photo.path));
                                    final photoUrl = await ref.getDownloadURL();

                                    // 2. Register attendance
                                    await service.saveHRAttendance(HRAttendanceRecord(
                                      id: '',
                                      institutionId: instId,
                                      employeeId: widget.user.id,
                                      employeeName: widget.user.name,
                                      timestamp: DateTime.now(),
                                      type: AttendanceType.checkIn, 
                                      method: AttendanceMethod.faceId,
                                      photoUrl: photoUrl,
                                    ));

                                    if (mounted) {
                                      Navigator.pop(context); // Close Face Scanner
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: AiTranslatedText('Ponto registado com sucesso com Face ID!')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const AiTranslatedText('Registar Ponto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_filled, color: Color(0xFF00D1FF), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '09:00 - 18:00',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const AiTranslatedText(
                      'Turno Geral - Hoje',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionSquare(
            icon: Icons.beach_access,
            label: 'Marcar Férias',
            color: Colors.orange,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionSquare(
            icon: Icons.assignment_late_outlined,
            label: 'Justificar Falta',
            color: Colors.redAccent,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionSquare(
            icon: Icons.visibility_outlined,
            label: 'Ver Escalas',
            color: Colors.blue,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistory(FirebaseService service, String instId) {
    return StreamBuilder<List<HRAttendanceRecord>>(
      stream: service.getHRAttendance(instId, employeeId: widget.user.id),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(child: AiTranslatedText('Sem registos este mês.', style: TextStyle(color: Colors.white24)));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    record.type == AttendanceType.checkIn ? Icons.login : Icons.logout,
                    color: record.type == AttendanceType.checkIn ? Colors.greenAccent : Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  AiTranslatedText(
                    record.type == AttendanceType.checkIn ? 'Check-In' : 'Check-Out',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM HH:mm').format(record.timestamp),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionSquare extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionSquare({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              AiTranslatedText(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
