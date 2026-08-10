import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/hr/hr_attendance_model.dart';
import '../models/hr/hr_absence_model.dart';
import '../services/firebase_service.dart';
import 'glass_card.dart';
import 'ai_translated_text.dart';
import '../screens/user/widgets/hr_attendance_scanner.dart';
import '../screens/parent/student_absence_registration_screen.dart';
import 'student_attendance_report_dialog.dart';

class ParentChildAttendanceWidget extends StatefulWidget {
  final UserModel child;
  final bool isViewingAsParent;

  const ParentChildAttendanceWidget({
    super.key,
    required this.child,
    required this.isViewingAsParent,
  });

  @override
  State<ParentChildAttendanceWidget> createState() =>
      _ParentChildAttendanceWidgetState();
}

class _ParentChildAttendanceWidgetState
    extends State<ParentChildAttendanceWidget> {
  bool _isSubmitting = false;

  void _openQRScanner(BuildContext context, AttendanceType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
          type == AttendanceType.checkIn
              ? 'Registo de Entrada da Criança'
              : 'Registo de Saída da Criança',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: Color(0xFF00D1FF)),
            const SizedBox(height: 16),
            const AiTranslatedText(
              'Utilize a câmara do dispositivo para ler o QR Code Dinâmico afixado ou selecione uma opção:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HRAttendanceScanner(
                      onScan: (scannedCode) async {
                        await _registerAttendance(type, scannedCode);
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const AiTranslatedText('📸 Abrir Câmara / Ler QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D1FF),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _registerAttendance(type, 'QR_CODE_DYNAMIC_DIRECT');
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white70),
              label: AiTranslatedText(
                type == AttendanceType.checkIn
                    ? 'Confirmar Entrada Direta'
                    : 'Confirmar Saída Direta',
                style: const TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerAttendance(AttendanceType type, String qrCode) async {
    setState(() => _isSubmitting = true);
    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      final instId = widget.child.institutionId ?? 'default_inst';

      final record = HRAttendanceRecord(
        id: '',
        institutionId: instId,
        employeeId: widget.child.id,
        employeeName: widget.child.name,
        timestamp: DateTime.now(),
        type: type,
        method: AttendanceMethod.qrCode,
      );

      await firebaseService.saveHRAttendance(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == AttendanceType.checkIn
                  ? 'Entrada registada com sucesso!'
                  : 'Saída registada com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReportAbsenceModal(BuildContext context) {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String absenceType = 'Doença / Baixa';
    final reasonController = TextEditingController();
    Uint8List? fileBytes;
    String? fileName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctxState, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctxState).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AiTranslatedText(
                        'Comunicar Ausência da Criança',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctxState),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AiTranslatedText(
                    'Selecione as datas em que a criança não irá ao colégio:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctxState,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF00D1FF)),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(startDate),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('até', style: TextStyle(color: Colors.white54)),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctxState,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setModalState(() => endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF00D1FF)),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(endDate),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AiTranslatedText(
                    'Motivo da Ausência',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: absenceType,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      'Doença / Baixa',
                      'Assunto Familiar',
                      'Férias',
                      'Consulta Médica',
                      'Outro',
                    ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setModalState(() => absenceType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Descrição / Justificação adicional...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AiTranslatedText(
                    'Documento Comprovativo (Baixa/Atestado)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        withData: true,
                      );
                      if (res != null && res.files.isNotEmpty) {
                        setModalState(() {
                          fileBytes = res.files.first.bytes;
                          fileName = res.files.first.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file, color: Color(0xFF00D1FF)),
                    label: Text(
                      fileName ?? 'Anexar Ficheiro (PDF ou Imagem)',
                      style: TextStyle(
                        color: fileName != null ? const Color(0xFF00D1FF) : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: fileName != null ? const Color(0xFF00D1FF) : Colors.white24,
                      ),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final firebaseService =
                            Provider.of<FirebaseService>(context, listen: false);
                        final instId = widget.child.institutionId ?? 'default_inst';

                        String? documentUrl;
                        if (fileBytes != null && fileName != null) {
                          documentUrl = await firebaseService.uploadFileBytes(
                            fileBytes!,
                            'absence_documents/${widget.child.id}_${DateTime.now().millisecondsSinceEpoch}_$fileName',
                          );
                        }

                        final record = HRAbsence(
                          id: '',
                          institutionId: instId,
                          employeeId: widget.child.id,
                          startDate: startDate,
                          endDate: endDate,
                          type: AbsenceType.sickLeave,
                          description: '$absenceType: ${reasonController.text}',
                          medicalCertificateUrl: documentUrl,
                          status: 'pending',
                        );

                        await firebaseService.saveHRAbsence(record);
                        if (context.mounted) {
                          Navigator.pop(ctxState);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ausência e documento comunicados ao colégio com sucesso!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const AiTranslatedText('Enviar Comunicação'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B61FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();
    final instId = widget.child.institutionId ?? 'default_inst';

    return StreamBuilder<List<HRAttendanceRecord>>(
      stream: firebaseService.getHRAttendance(instId, employeeId: widget.child.id),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        final today = DateTime.now();

        HRAttendanceRecord? todayCheckIn;
        HRAttendanceRecord? todayCheckOut;

        for (final r in records) {
          if (r.timestamp.year == today.year &&
              r.timestamp.month == today.month &&
              r.timestamp.day == today.day) {
            if (r.type == AttendanceType.checkIn) todayCheckIn = r;
            if (r.type == AttendanceType.checkOut) todayCheckOut = r;
          }
        }

        final now = DateTime.now();
        final isPast930 = now.hour > 9 || (now.hour == 9 && now.minute >= 30);
        final bool show930Alert = isPast930 && todayCheckIn == null;

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2, color: Color(0xFF00D1FF), size: 22),
                      SizedBox(width: 8),
                      AiTranslatedText(
                        'Controlo de Entrada e Saída',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showReportAbsenceModal(context),
                    icon: const Icon(Icons.event_busy, size: 16, color: Color(0xFFFF9F1C)),
                    label: const AiTranslatedText(
                      'Justificar Ausência',
                      style: TextStyle(fontSize: 12, color: Color(0xFFFF9F1C)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- 9:30 AM ALERT BANNER ---
              if (show930Alert) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AiTranslatedText(
                              'ALERTA AUTOMÁTICO DE PRESENÇA',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            AiTranslatedText(
                              'A criança ${widget.child.name} não deu entrada no colégio até às 9h30.',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // --- CURRENT STATUS CARD ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          todayCheckIn != null ? Icons.check_circle : Icons.error_outline,
                          color: todayCheckIn != null ? Colors.greenAccent : Colors.orangeAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          todayCheckIn != null
                              ? 'Entrada: ${DateFormat('HH:mm').format(todayCheckIn.timestamp)}'
                              : 'Entrada pendente hoje',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          todayCheckOut != null ? Icons.logout : Icons.schedule,
                          color: todayCheckOut != null ? Colors.blueAccent : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          todayCheckOut != null
                              ? 'Saída: ${DateFormat('HH:mm').format(todayCheckOut.timestamp)}'
                              : 'Saída pendente',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- ACTION BUTTONS (ENTRADA / SAÍDA POR QR CODE) ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _openQRScanner(context, AttendanceType.checkIn),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const AiTranslatedText('Entrada QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _openQRScanner(context, AttendanceType.checkOut),
                      icon: const Icon(Icons.sensor_door_outlined, size: 18),
                      label: const AiTranslatedText('Saída QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF00D1FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final parent = context.read<FirebaseService>().currentUserModel ?? widget.child;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentAbsenceRegistrationScreen(
                              child: widget.child,
                              parent: parent,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.event_note, color: Colors.orangeAccent, size: 18),
                      label: const AiTranslatedText(
                        '📝 Comunicar Ausência',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => StudentAttendanceReportDialog(student: widget.child),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const AiTranslatedText(
                        '🖨️ Imprimir Mapa',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B61FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
