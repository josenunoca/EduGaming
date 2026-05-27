import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
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

  String _formatDate(DateTime date, String pattern) {
    try {
      return DateFormat(pattern).format(date);
    } catch (_) {
      if (pattern == 'dd/MM/yyyy') {
        final d = date.day.toString().padLeft(2, '0');
        final m = date.month.toString().padLeft(2, '0');
        final y = date.year.toString().padLeft(4, '0');
        return '$d/$m/$y';
      }
      return date.toIso8601String().split('T')[0];
    }
  }

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

  void _showManualAttendanceRegistration(BuildContext context) async {
    final service = context.read<FirebaseService>();
    final employees = await service.getAllInstitutionMembers(widget.institution.id);
    final activeEmployees = employees.where((m) =>
        m.role != UserRole.student &&
        m.role != UserRole.parent &&
        !m.isSuspended).toList();

    if (!context.mounted) return;

    UserModel? selectedEmployee;
    AttendanceType selectedType = AttendanceType.checkIn;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const AiTranslatedText('Registo de Ponto Manual por RH'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Selecionar Colaborador', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UserModel>(
                      value: activeEmployees.contains(selectedEmployee) ? selectedEmployee : null,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: activeEmployees.map((emp) => DropdownMenuItem(
                        value: emp,
                        child: Text(emp.name),
                      )).toList(),
                      onChanged: (val) => setState(() => selectedEmployee = val),
                    ),
                    const SizedBox(height: 16),
                    const AiTranslatedText('Tipo de Registo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AttendanceType>(
                      value: selectedType,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: AttendanceType.checkIn, child: Text('Entrada (Check-In)')),
                        DropdownMenuItem(value: AttendanceType.checkOut, child: Text('Saída (Check-Out)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const AiTranslatedText('Data e Hora', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => selectedDate = d);
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_formatDate(selectedDate, 'dd/MM/yyyy')),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (t != null) setState(() => selectedTime = t);
                            },
                            icon: const Icon(Icons.access_time, size: 14),
                            label: Text(selectedTime.format(context)),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedEmployee == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um colaborador!')));
                      return;
                    }
                    final timestamp = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    final record = HRAttendanceRecord(
                      id: '',
                      employeeId: selectedEmployee!.id,
                      employeeName: selectedEmployee!.name,
                      institutionId: widget.institution.id,
                      timestamp: timestamp,
                      type: selectedType,
                      method: AttendanceMethod.manual,
                    );
                    await service.saveHRAttendance(record);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto registado com sucesso!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF85), foregroundColor: Colors.black),
                  child: const AiTranslatedText('Registar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<UserModel>>(
      stream: service.streamInstitutionMembers(widget.institution.id),
      builder: (context, empSnapshot) {
        if (empSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allMembers = empSnapshot.data ?? [];
        final staffIds = allMembers
            .where((e) => e.role != UserRole.student && e.role != UserRole.parent)
            .map((e) => e.id)
            .toSet();

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
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showManualAttendanceRegistration(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const AiTranslatedText('Manual'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FF85)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HRAttendanceReportScreen(institution: widget.institution),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.analytics_outlined, size: 16),
                              label: const AiTranslatedText('Mapa Mensal'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<HRAttendanceRecord>>(
                      stream: service.getHRAttendance(widget.institution.id, date: DateTime.now()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final allRecords = snapshot.data ?? [];
                        final records = allRecords.where((r) => staffIds.contains(r.employeeId)).toList();
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
      },
    );
  }
}

class _AttendanceItem extends StatelessWidget {
  final HRAttendanceRecord record;

  const _AttendanceItem({required this.record});

  @override
  Widget build(BuildContext context) {
    String formatTime(DateTime date) {
      try {
        return DateFormat('HH:mm').format(date);
      } catch (_) {
        final h = date.hour.toString().padLeft(2, '0');
        final m = date.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: record.photoUrl != null ? NetworkImage(record.photoUrl!) : null,
            child: record.photoUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(
                  record.type == AttendanceType.checkIn ? 'Check-In' : 'Check-Out',
                  style: TextStyle(
                    color: record.type == AttendanceType.checkIn ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTime(record.timestamp),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                record.method == AttendanceMethod.manual
                    ? 'Manual (RH/Delegado)'
                    : (record.method == AttendanceMethod.qrCode || record.method == AttendanceMethod.faceId)
                        ? 'QR Code (Área Pessoal)'
                        : 'Outro',
                style: TextStyle(
                  color: record.method == AttendanceMethod.manual
                      ? Colors.orangeAccent
                      : const Color(0xFF00D1FF),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
