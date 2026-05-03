import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../../../models/institution_model.dart';
import '../../../../models/hr/hr_attendance_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';
import '../hr_attendance_report_screen.dart';

class HRAttendanceTab extends StatefulWidget {
  final InstitutionModel institution;

  const HRAttendanceTab({super.key, required this.institution});

  @override
  State<HRAttendanceTab> createState() => _HRAttendanceTabState();
}

class _HRAttendanceTabState extends State<HRAttendanceTab> {
  String _currentQrData = "";
  Timer? _qrTimer;

  @override
  void initState() {
    super.initState();
    _startQrRotation();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }

  void _startQrRotation() {
    _generateNewQr();
    _qrTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() => _generateNewQr());
    });
  }

  void _generateNewQr() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentQrData = "HR_ATTENDANCE_${widget.institution.id}_$timestamp";
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const AiTranslatedText(
                          'Ponto Digital (QR)',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const AiTranslatedText(
                          'Exiba este código no tablet da recepção para registo de entrada/saída.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: QrImageView(
                            data: _currentQrData,
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D1FF)),
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(height: 8),
                        const AiTranslatedText('O código atualiza em 30 segundos para evitar fraude.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AiTranslatedText(
                          'Registos de Hoje',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HRAttendanceReportScreen(institution: widget.institution),
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const AiTranslatedText('Mapa Mensal'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<HRAttendanceRecord>>(
                      stream: service.getHRAttendance(widget.institution.id, date: DateTime.now()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final records = snapshot.data ?? [];
                        if (records.isEmpty) {
                          return const Center(child: AiTranslatedText('Nenhum registo hoje.', style: TextStyle(color: Colors.white24)));
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: records.length,
                          itemBuilder: (context, index) => _AttendanceItem(record: records[index]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceItem extends StatelessWidget {
  final HRAttendanceRecord record;

  const _AttendanceItem({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: record.photoUrl != null ? NetworkImage(record.photoUrl!) : null, child: record.photoUrl == null ? const Icon(Icons.person) : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(record.type == AttendanceType.checkIn ? 'Check-In' : 'Check-Out', style: TextStyle(color: record.type == AttendanceType.checkIn ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(record.timestamp),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
