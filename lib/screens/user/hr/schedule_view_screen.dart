import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_schedule_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/hr_pdf_generator.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRScheduleViewScreen extends StatefulWidget {
  final UserModel user;

  const HRScheduleViewScreen({super.key, required this.user});

  @override
  State<HRScheduleViewScreen> createState() => _HRScheduleViewScreenState();
}

class _HRScheduleViewScreenState extends State<HRScheduleViewScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  String _formatLongDate(DateTime date) {
    try {
      return DateFormat('EEEE, d MMMM', 'pt_PT').format(date);
    } catch (_) {
      try {
        return DateFormat('EEEE, d MMMM').format(date);
      } catch (_) {
        final weekdays = [
          'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
          'Sexta-feira', 'Sábado', 'Domingo'
        ];
        final months = [
          'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
          'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
        ];
        return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
      }
    }
  }

  HRAbsence? _getAbsenceForDay(DateTime day, List<HRAbsence> absences) {
    final checkDay = DateTime(day.year, day.month, day.day);
    for (var a in absences) {
      final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
      final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
      if ((checkDay.isAtSameMomentAs(start) || checkDay.isAfter(start)) &&
          (checkDay.isAtSameMomentAs(end) || checkDay.isBefore(end))) {
        return a;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<HRAbsence>>(
      stream: service.getHRAbsences(widget.user.institutionId ?? ''),
      builder: (context, absencesSnapshot) {
        final allAbsences = absencesSnapshot.data ?? [];
        final absences = allAbsences.where((a) => a.employeeId == widget.user.id).toList();

        return StreamBuilder<List<HRScheduleEntry>>(
          stream: service.getHRScheduleEntries(
            widget.user.institutionId ?? '',
            employeeId: widget.user.id,
          ),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];

            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                title: const AiTranslatedText('Minhas Escalas'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.print, color: Color(0xFF00D1FF)),
                    tooltip: 'Imprimir Escala e Resumo',
                    onPressed: () async {
                      final institutionId = widget.user.institutionId;
                      if (institutionId == null || institutionId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: AiTranslatedText('Não está associado a nenhuma instituição.')),
                        );
                        return;
                      }

                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00D1FF)),
                        ),
                      );

                      try {
                        final institution = await service.getInstitution(institutionId);
                        final institutionName = institution?.name ?? 'Minha Instituição';

                        // Get first and last day of the currently focused month
                        final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
                        final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

                        await HRPdfGenerator.generateAndPrintDetailedReport(
                          staff: [widget.user],
                          entries: entries,
                          absences: absences,
                          start: start,
                          end: end,
                          institutionName: institutionName,
                          isSingleEmployee: true,
                        );
                      } catch (e) {
                        debugPrint('Error printing: $e');
                      } finally {
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.pop(context); // Close loading dialog
                        }
                      }
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  GlassCard(
                    margin: const EdgeInsets.all(16),
                    child: TableCalendar<HRScheduleEntry>(
                      firstDay: DateTime.now().subtract(const Duration(days: 90)),
                      lastDay: DateTime.now().add(const Duration(days: 90)),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      eventLoader: (day) {
                        return entries.where((e) => isSameDay(e.date, day)).toList();
                      },
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.white70),
                        outsideTextStyle: TextStyle(color: Colors.white24),
                        todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: Color(0xFF00D1FF), shape: BoxShape.circle),
                        markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Colors.white54),
                        weekendStyle: TextStyle(color: Colors.white54),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final absence = _getAbsenceForDay(day, absences);
                          if (absence != null) {
                            final isVacation = absence.type == AbsenceType.vacation;
                            final isPending = absence.status == 'pending';
                            final isRejected = absence.status == 'rejected';
                            if (isRejected) return null;

                            return Positioned(
                              right: 4,
                              top: 4,
                              child: Icon(
                                isPending 
                                    ? Icons.pending_actions 
                                    : (isVacation ? Icons.beach_access : Icons.assignment_late_outlined),
                                size: 10,
                                color: isPending
                                    ? Colors.amberAccent
                                    : (isVacation ? Colors.orangeAccent : Colors.redAccent),
                              ),
                            );
                          }
                          return null;
                        },
                        defaultBuilder: (context, day, focusedDay) {
                          final absence = _getAbsenceForDay(day, absences);
                          if (absence != null) {
                            final isVacation = absence.type == AbsenceType.vacation;
                            final isPending = absence.status == 'pending';
                            final isRejected = absence.status == 'rejected';
                            if (isRejected) return null;

                            return Container(
                              margin: const EdgeInsets.all(4.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isPending
                                    ? Colors.amber.withValues(alpha: 0.1)
                                    : (isVacation 
                                        ? Colors.orange.withValues(alpha: 0.15) 
                                        : Colors.redAccent.withValues(alpha: 0.15)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isPending
                                      ? Colors.amberAccent.withValues(alpha: 0.5)
                                      : (isVacation ? Colors.orangeAccent : Colors.redAccent), 
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isPending
                                      ? Colors.amberAccent
                                      : (isVacation ? Colors.orangeAccent : Colors.redAccent),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: _buildDayDetails(entries, absences),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayDetails(List<HRScheduleEntry> entries, List<HRAbsence> absences) {
    if (_selectedDay == null) return const SizedBox.shrink();
    
    final dayEntries = entries.where((e) => isSameDay(e.date, _selectedDay!)).toList();
    final dayAbsences = absences.where((a) {
      final checkDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
      final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
      return (checkDay.isAtSameMomentAs(start) || checkDay.isAfter(start)) &&
             (checkDay.isAtSameMomentAs(end) || checkDay.isBefore(end));
    }).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: ListView(
        children: [
          AiTranslatedText(
            _formatLongDate(_selectedDay!),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (dayAbsences.isNotEmpty) ...[
            ...dayAbsences.map((absence) => _AbsenceDetailCard(absence: absence)),
            const SizedBox(height: 12),
          ],
          if (dayEntries.isEmpty && dayAbsences.isEmpty)
             const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: AiTranslatedText('Sem escala ou ausência definida para este dia.', style: TextStyle(color: Colors.white24)),
              ),
            )
          else
            ...dayEntries.map((entry) => _ScheduleEntryCard(entry: entry)),
        ],
      ),
    );
  }
}

class _AbsenceDetailCard extends StatelessWidget {
  final HRAbsence absence;

  const _AbsenceDetailCard({required this.absence});

  @override
  Widget build(BuildContext context) {
    final isVacation = absence.type == AbsenceType.vacation;
    
    Color statusBgColor = Colors.orange.withValues(alpha: 0.1);
    Color statusTextColor = Colors.orangeAccent;
    String statusText = 'Pendente';
    
    if (absence.status == 'approved') {
      statusBgColor = Colors.green.withValues(alpha: 0.1);
      statusTextColor = Colors.greenAccent;
      statusText = 'Aprovada';
    } else if (absence.status == 'rejected') {
      statusBgColor = Colors.red.withValues(alpha: 0.1);
      statusTextColor = Colors.redAccent;
      statusText = 'Rejeitada';
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isVacation ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVacation ? Icons.beach_access : Icons.assignment_late_outlined,
                color: isVacation ? Colors.orangeAccent : Colors.redAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AiTranslatedText(
                        isVacation ? 'Férias' : 'Ausência / Justificação',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    absence.description.isNotEmpty ? absence.description : (isVacation ? 'Pedido de férias via App' : 'Ausência comunicada pelo colaborador.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEntryCard extends StatelessWidget {
  final HRScheduleEntry entry;

  const _ScheduleEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: entry.isOffDay ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                entry.isOffDay ? Icons.hotel : Icons.work,
                color: entry.isOffDay ? Colors.redAccent : Colors.greenAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiTranslatedText(
                    entry.isOffDay ? 'Dia de Folga' : 'Turno de Trabalho',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (!entry.isOffDay)
                    Text(
                      '${entry.customStartTime} - ${entry.customEndTime}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
            if (entry.status == 'completed')
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          ],
        ),
      ),
    );
  }
}
