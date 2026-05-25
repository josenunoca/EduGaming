import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_schedule_model.dart';
import '../../../../services/firebase_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Minhas Escalas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<HRScheduleEntry>>(
        stream: service.getHRScheduleEntries(
          widget.user.institutionId ?? '',
          employeeId: widget.user.id,
        ),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          
          return Column(
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
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: _buildDayDetails(entries),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayDetails(List<HRScheduleEntry> entries) {
    if (_selectedDay == null) return const SizedBox.shrink();
    
    final dayEntries = entries.where((e) => isSameDay(e.date, _selectedDay!)).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText(
            DateFormat('EEEE, d MMMM').format(_selectedDay!),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (dayEntries.isEmpty)
             const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: AiTranslatedText('Sem escala definida para este dia.', style: TextStyle(color: Colors.white24)),
              ),
            )
          else
            ...dayEntries.map((entry) => _ScheduleEntryCard(entry: entry)),
        ],
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
