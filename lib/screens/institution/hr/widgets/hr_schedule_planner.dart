import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../models/hr/hr_schedule_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/hr_pdf_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HRSchedulePlanner extends StatefulWidget {
  final InstitutionModel institution;
  final List<UserModel> employees;
  final List<HRShift> availableShifts;
  final List<HRScheduleEntry> entries;
  final List<Map<String, dynamic>> closedDays;
  final List<HRAbsence> absences;
  final Function(List<HRScheduleEntry> newEntries) onAssign;

  const HRSchedulePlanner({
    super.key,
    required this.institution,
    required this.employees,
    required this.availableShifts,
    required this.entries,
    required this.closedDays,
    required this.absences,
    required this.onAssign,
  });

  @override
  State<HRSchedulePlanner> createState() => _HRSchedulePlannerState();
}

class _HRSchedulePlannerState extends State<HRSchedulePlanner> {
  late ScrollController _employeeVerticalController;
  late ScrollController _gridVerticalController;
  late ScrollController _headerHorizontalController;
  late ScrollController _gridHorizontalController;

  @override
  void initState() {
    super.initState();
    _employeeVerticalController = ScrollController();
    _gridVerticalController = ScrollController();
    _headerHorizontalController = ScrollController();
    _gridHorizontalController = ScrollController();

    // Sync vertical scrolls
    _employeeVerticalController.addListener(() {
      if (_employeeVerticalController.hasClients && _gridVerticalController.hasClients) {
        if (_employeeVerticalController.offset != _gridVerticalController.offset) {
          _gridVerticalController.jumpTo(_employeeVerticalController.offset);
        }
      }
    });
    _gridVerticalController.addListener(() {
      if (_gridVerticalController.hasClients && _employeeVerticalController.hasClients) {
        if (_gridVerticalController.offset != _employeeVerticalController.offset) {
          _employeeVerticalController.jumpTo(_gridVerticalController.offset);
        }
      }
    });

    // Sync horizontal scrolls
    _headerHorizontalController.addListener(() {
      if (_headerHorizontalController.hasClients && _gridHorizontalController.hasClients) {
        if (_headerHorizontalController.offset != _gridHorizontalController.offset) {
          _gridHorizontalController.jumpTo(_headerHorizontalController.offset);
        }
      }
    });
    _gridHorizontalController.addListener(() {
      if (_gridHorizontalController.hasClients && _headerHorizontalController.hasClients) {
        if (_gridHorizontalController.offset != _headerHorizontalController.offset) {
          _headerHorizontalController.jumpTo(_gridHorizontalController.offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _employeeVerticalController.dispose();
    _gridVerticalController.dispose();
    _headerHorizontalController.dispose();
    _gridHorizontalController.dispose();
    super.dispose();
  }

  DateTime _currentMonth = DateTime.now();
  
  // Selection state
  final Set<String> _selectedCellIds = {}; // Format: "employeeId_yyyy-MM-dd"
  String? _copiedEmployeeId;

  String _formatMonthYear(DateTime date) {
    try {
      final name = DateFormat('MMMM yyyy', 'pt_PT').format(date);
      return name[0].toUpperCase() + name.substring(1);
    } catch (_) {
      try {
        final name = DateFormat('MMMM yyyy').format(date);
        return name[0].toUpperCase() + name.substring(1);
      } catch (_) {
        final months = [
          'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
          'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
        ];
        return '${months[date.month - 1]} ${date.year}';
      }
    }
  }

  String _formatWeekday(DateTime day) {
    try {
      return DateFormat('E', 'pt_PT').format(day).toUpperCase();
    } catch (_) {
      try {
        return DateFormat('E').format(day).toUpperCase();
      } catch (_) {
        switch (day.weekday) {
          case DateTime.monday:
            return 'SEG';
          case DateTime.tuesday:
            return 'TER';
          case DateTime.wednesday:
            return 'QUA';
          case DateTime.thursday:
            return 'QUI';
          case DateTime.friday:
            return 'SEX';
          case DateTime.saturday:
            return 'SÁB';
          case DateTime.sunday:
            return 'DOM';
          default:
            return '';
        }
      }
    }
  }

  String _formatDateString(DateTime date, String pattern) {
    try {
      return DateFormat(pattern).format(date);
    } catch (_) {
      if (pattern == 'yyyy-MM-dd') {
        final y = date.year.toString().padLeft(4, '0');
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      } else if (pattern == 'dd/MM/yyyy') {
        final d = date.day.toString().padLeft(2, '0');
        final m = date.month.toString().padLeft(2, '0');
        final y = date.year.toString().padLeft(4, '0');
        return '$d/$m/$y';
      } else if (pattern == 'dd/MM') {
        final d = date.day.toString().padLeft(2, '0');
        final m = date.month.toString().padLeft(2, '0');
        return '$d/$m';
      }
      return date.toIso8601String().split('T')[0];
    }
  }

  DateTime _parseDateString(String dateStr) {
    try {
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? 2026;
        final m = int.tryParse(parts[1]) ?? 1;
        final d = int.tryParse(parts[2]) ?? 1;
        return DateTime(y, m, d);
      }
      return DateTime.now();
    }
  }

  Map<String, HRScheduleEntry> _getEntryMap() {
    final map = <String, HRScheduleEntry>{};
    for (var e in widget.entries) {
      final dateStr = _formatDateString(e.date, 'yyyy-MM-dd');
      map['${e.employeeId}_$dateStr'] = e;
    }
    return map;
  }

  String? _getClosedReason(DateTime day) {
    // 1. Check special closed days
    for (var cd in widget.closedDays) {
      final startVal = cd['startDate'];
      final endVal = cd['endDate'];
      final DateTime? start = startVal is Timestamp ? startVal.toDate() : (startVal != null ? DateTime.tryParse(startVal.toString()) : null);
      final DateTime? end = endVal is Timestamp ? endVal.toDate() : (endVal != null ? DateTime.tryParse(endVal.toString()) : null);
      
      if (start != null && end != null) {
        final checkDay = DateTime(day.year, day.month, day.day);
        final checkStart = DateTime(start.year, start.month, start.day);
        final checkEnd = DateTime(end.year, end.month, end.day);
        if ((checkDay.isAtSameMomentAs(checkStart) || checkDay.isAfter(checkStart)) &&
            (checkDay.isAtSameMomentAs(checkEnd) || checkDay.isBefore(checkEnd))) {
          return cd['name'] ?? 'Fechado';
        }
      }
    }
    // 2. Check regular weekly closing
    if (!widget.institution.workingDays.contains(day.weekday)) {
      return 'Fim de Semana';
    }
    return null;
  }

  HRAbsence? _getApprovedAbsence(String employeeId, DateTime day) {
    final checkDay = DateTime(day.year, day.month, day.day);
    for (var a in widget.absences) {
      if (a.employeeId == employeeId && a.status == 'approved') {
        final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
        final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
        if ((checkDay.isAtSameMomentAs(start) || checkDay.isAfter(start)) &&
            (checkDay.isAtSameMomentAs(end) || checkDay.isBefore(end))) {
          return a;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final entryMap = _getEntryMap();
    final gridWidth = daysInMonth.length * 85.0;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Employee Names list (Fixed horizontally)
              SizedBox(
                width: 160,
                child: Column(
                  children: [
                    // Corner spacer (aligns with day headers)
                    Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white10),
                          right: BorderSide(color: Colors.white10),
                        ),
                      ),
                    ),
                    // Vertical scrollable list of employee rows
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _employeeVerticalController,
                        physics: const NeverScrollableScrollPhysics(), // Synced with the main grid
                        scrollDirection: Axis.vertical,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.employees.map((emp) => _buildEmployeeRow(emp, daysInMonth, entryMap)).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Column 2: Scrollable day headers and grid cells
              Expanded(
                child: Scrollbar(
                  controller: _gridHorizontalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _gridHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Frozen Day headers (fixed vertically but scrolls horizontally)
                          Container(
                            height: 40,
                            child: Row(
                              children: daysInMonth.map((day) {
                                final closedReason = _getClosedReason(day);
                                final isClosed = closedReason != null;
                                return Container(
                                  width: 85,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: const Border(
                                      bottom: BorderSide(color: Colors.white10),
                                      right: BorderSide(color: Colors.white10),
                                    ),
                                    color: isClosed
                                        ? const Color(0xFFFF4E4E).withValues(alpha: 0.08)
                                        : Colors.transparent,
                                  ),
                                  child: Text(
                                    '${_formatWeekday(day)}\n${day.day}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isClosed ? const Color(0xFFFF8585) : Colors.white,
                                      fontSize: 11,
                                      fontWeight: isClosed ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // Scrollable grid cells (Scrolls both vertically and horizontally)
                          Expanded(
                            child: Scrollbar(
                              controller: _gridVerticalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _gridVerticalController,
                                scrollDirection: Axis.vertical,
                                child: Column(
                                  children: widget.employees.map((emp) => _buildGridRow(emp, daysInMonth, entryMap)).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_selectedCellIds.isNotEmpty) _buildSelectionActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
          ),
          AiTranslatedText(
            _formatMonthYear(_currentMonth),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showConfigClosingDialog,
            icon: const Icon(Icons.settings, size: 16),
            label: const AiTranslatedText('Configurar Fecho'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Exportar PDF',
            onSelected: (val) async {
              if (val == 'schedule') {
                final days = _getDaysInMonth(_currentMonth);
                await HRPdfGenerator.generateAndPrintStaffSchedule(
                  staff: widget.employees,
                  entries: widget.entries,
                  start: days.first,
                  end: days.last,
                  institutionName: widget.institution.name,
                );
              } else if (val == 'detailed_report') {
                final days = _getDaysInMonth(_currentMonth);
                await HRPdfGenerator.generateAndPrintDetailedReport(
                  staff: widget.employees,
                  entries: widget.entries,
                  absences: widget.absences,
                  start: days.first,
                  end: days.last,
                  institutionName: widget.institution.name,
                  isSingleEmployee: false,
                );
              } else if (val == 'closed_map') {
                await HRPdfGenerator.generateAndPrintInstitutionClosedMap(
                  institution: widget.institution,
                  closedDays: widget.closedDays,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'schedule',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.blue),
                    SizedBox(width: 8),
                    AiTranslatedText('Escala Mensal'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'detailed_report',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Color(0xFF00D1FF)),
                    SizedBox(width: 8),
                    AiTranslatedText('Relatório de Contabilidade'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'closed_map',
                child: Row(
                  children: [
                    Icon(Icons.domain_disabled, color: Colors.red),
                    SizedBox(width: 8),
                    AiTranslatedText('Mapa de Encerramentos'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(UserModel employee, List<DateTime> daysInMonth, Map<String, HRScheduleEntry> entryMap) {
    // Calculate total hours for this month
    double totalHours = 0;
    for (var day in daysInMonth) {
      final cellId = "${employee.id}_${_formatDateString(day, 'yyyy-MM-dd')}";
      final entry = entryMap[cellId];
      if (entry != null && !entry.isOffDay) {
        final partsStart = entry.customStartTime.split(':');
        final partsEnd = entry.customEndTime.split(':');
        if (partsStart.length == 2 && partsEnd.length == 2) {
          final start = (int.tryParse(partsStart[0]) ?? 0) + (int.tryParse(partsStart[1]) ?? 0) / 60.0;
          final end = (int.tryParse(partsEnd[0]) ?? 0) + (int.tryParse(partsEnd[1]) ?? 0) / 60.0;
          double diff = end - start;
          if (entry.mealStartTime != null && entry.mealEndTime != null) {
            final mPartsStart = entry.mealStartTime!.split(':');
            final mPartsEnd = entry.mealEndTime!.split(':');
            if (mPartsStart.length == 2 && mPartsEnd.length == 2) {
              final mStart = (int.tryParse(mPartsStart[0]) ?? 0) + (int.tryParse(mPartsStart[1]) ?? 0) / 60.0;
              final mEnd = (int.tryParse(mPartsEnd[0]) ?? 0) + (int.tryParse(mPartsEnd[1]) ?? 0) / 60.0;
              diff -= (mEnd - mStart);
            }
          } else if (diff > 4) {
            diff -= 1.0;
          }
          totalHours += diff;
        }
      }
    }
    // Expected contracted hours
    final expectedHours = (daysInMonth.length / 7) * employee.contractedHours;
    final diff = totalHours - expectedHours;
    final diffColor = diff < -2 ? Colors.redAccent : diff > 2 ? Colors.greenAccent : Colors.white54;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10), right: BorderSide(color: Colors.white10)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalHours.toStringAsFixed(1)}h / ${expectedHours.toStringAsFixed(1)}h',
                  style: TextStyle(color: diffColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_copiedEmployeeId == null)
            IconButton(
              icon: const Icon(Icons.copy, size: 13, color: Colors.white54),
              onPressed: () {
                setState(() => _copiedEmployeeId = employee.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Escala de ${employee.name} copiada. Clique noutro funcionário para colar.')),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else if (_copiedEmployeeId != employee.id)
            IconButton(
              icon: const Icon(Icons.paste, size: 13, color: Color(0xFF00D1FF)),
              onPressed: () {
                _pasteSchedule(employee.id, entryMap, daysInMonth);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 13, color: Colors.redAccent),
              onPressed: () => setState(() => _copiedEmployeeId = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  void _pasteSchedule(String targetEmployeeId, Map<String, HRScheduleEntry> entryMap, List<DateTime> daysInMonth) {
    if (_copiedEmployeeId == null) return;
    final entriesToPaste = <HRScheduleEntry>[];
    for (var day in daysInMonth) {
      final sourceCellId = "${_copiedEmployeeId}_${_formatDateString(day, 'yyyy-MM-dd')}";
      final sourceEntry = entryMap[sourceCellId];
      if (sourceEntry != null) {
        entriesToPaste.add(HRScheduleEntry(
          id: '',
          employeeId: targetEmployeeId,
          institutionId: widget.institution.id,
          date: day,
          shiftId: sourceEntry.shiftId,
          customStartTime: sourceEntry.customStartTime,
          customEndTime: sourceEntry.customEndTime,
          mealStartTime: sourceEntry.mealStartTime,
          mealEndTime: sourceEntry.mealEndTime,
          isOffDay: sourceEntry.isOffDay,
          status: 'planned',
        ));
      }
    }
    if (entriesToPaste.isNotEmpty) {
      widget.onAssign(entriesToPaste);
      setState(() => _copiedEmployeeId = null);
    }
  }

  Widget _buildGridRow(UserModel employee, List<DateTime> days, Map<String, HRScheduleEntry> entryMap) {
    return SizedBox(
      height: 60,
      child: Row(
        children: days.map((day) {
          final cellId = "${employee.id}_${_formatDateString(day, 'yyyy-MM-dd')}";
          final isSelected = _selectedCellIds.contains(cellId);
          final entry = entryMap[cellId];
          final closedReason = _getClosedReason(day);
          final isClosedDay = closedReason != null;
          final approvedAbsence = _getApprovedAbsence(employee.id, day);

          Color cellColor = Colors.transparent;
          Widget cellChild = const SizedBox();

          if (isSelected) {
            cellColor = const Color(0xFF00D1FF).withValues(alpha: 0.3);
          } else if (approvedAbsence != null) {
            final isVacation = approvedAbsence.type == AbsenceType.vacation;
            cellColor = isVacation
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.redAccent.withValues(alpha: 0.15);
            cellChild = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVacation ? Icons.beach_access : Icons.assignment_late_outlined,
                  size: 12,
                  color: isVacation ? Colors.orangeAccent : Colors.redAccent,
                ),
                const SizedBox(height: 2),
                Text(
                  isVacation ? 'Férias' : 'Ausente',
                  style: TextStyle(
                    color: isVacation ? Colors.orangeAccent : Colors.redAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          } else if (entry != null) {
            if (entry.isOffDay) {
              cellColor = Colors.white.withValues(alpha: 0.05);
              cellChild = const Text('Folga', style: TextStyle(color: Colors.white38, fontSize: 10));
            } else {
              cellColor = const Color(0xFF00FF85).withValues(alpha: 0.15);
              cellChild = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${entry.customStartTime}-${entry.customEndTime}',
                    style: const TextStyle(color: Color(0xFF00FF85), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  if (entry.mealStartTime != null && entry.mealEndTime != null)
                    Text(
                      'Ref: ${entry.mealStartTime}-${entry.mealEndTime}',
                      style: const TextStyle(color: Colors.white30, fontSize: 8),
                    ),
                ],
              );
            }
          } else if (isClosedDay) {
            cellColor = const Color(0xFFFF4E4E).withValues(alpha: 0.1);
            cellChild = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 10, color: const Color(0xFFFF4E4E).withValues(alpha: 0.6)),
                const SizedBox(height: 2),
                Text(
                  closedReason,
                  style: TextStyle(color: const Color(0xFFFF4E4E).withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          } else {
            cellChild = const Text('-', style: TextStyle(color: Colors.white24, fontSize: 10));
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) _selectedCellIds.remove(cellId);
                else _selectedCellIds.add(cellId);
              });
            },
            child: Container(
              width: 81,
              height: 56,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cellColor,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: cellChild),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectionActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          AiTranslatedText(
            '${_selectedCellIds.length} células selecionadas',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => setState(() => _selectedCellIds.clear()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
            child: const AiTranslatedText('Limpar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showShiftSelector,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1FF), foregroundColor: Colors.black),
            child: const AiTranslatedText('Atribuir Horário'),
          ),
        ],
      ),
    );
  }

  void _showShiftSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Selecionar Tipo de Horário',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...widget.availableShifts.map((shift) => ListTile(
              leading: Icon(Icons.schedule, color: Color(int.parse(shift.color.replaceAll('#', '0xFF')))),
              title: Text(shift.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${shift.startTime} - ${shift.endTime}', style: const TextStyle(color: Colors.white54)),
              onTap: () {
                _assignShift(shift);
                Navigator.pop(context);
              },
            )),
            ListTile(
              leading: const Icon(Icons.beach_access, color: Colors.orange),
              title: const Text('Folga', style: TextStyle(color: Colors.white)),
              onTap: () {
                final shift = HRShift(id: 'off', institutionId: widget.institution.id, name: 'Folga', startTime: '00:00', endTime: '00:00');
                _assignShift(shift, isOffDay: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar, color: Color(0xFF00D1FF)),
              title: const AiTranslatedText('Horário Personalizado', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showCustomShiftEntryDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomShiftEntryDialog() {
    final entryController = TextEditingController(text: "09:00");
    final exitController = TextEditingController(text: "18:00");
    final mealStartController = TextEditingController(text: "13:00");
    final mealEndController = TextEditingController(text: "14:00");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Definir Horário Personalizado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: entryController,
                  decoration: const InputDecoration(
                    labelText: 'Hora de Entrada (HH:mm)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                TextField(
                  controller: exitController,
                  decoration: const InputDecoration(
                    labelText: 'Hora de Saída (HH:mm)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                TextField(
                  controller: mealStartController,
                  decoration: const InputDecoration(
                    labelText: 'Início de Refeição (HH:mm)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                TextField(
                  controller: mealEndController,
                  decoration: const InputDecoration(
                    labelText: 'Fim de Refeição (HH:mm)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                  ),
                  style: const TextStyle(color: Colors.white),
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
              onPressed: () {
                final customShift = HRShift(
                  id: 'custom',
                  institutionId: widget.institution.id,
                  name: 'Customizado',
                  startTime: entryController.text,
                  endTime: exitController.text,
                );
                _assignShift(
                  customShift,
                  mealStart: mealStartController.text.isNotEmpty ? mealStartController.text : null,
                  mealEnd: mealEndController.text.isNotEmpty ? mealEndController.text : null,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1FF), foregroundColor: Colors.black),
              child: const AiTranslatedText('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _assignShift(HRShift shift, {bool isOffDay = false, String? mealStart, String? mealEnd}) {
    final employeeIds = _selectedCellIds.map((id) => id.split('_')[0]).toSet().toList();
    final dates = _selectedCellIds.map((id) => _parseDateString(id.split('_')[1])).toSet().toList();
    
    final entries = <HRScheduleEntry>[];
    for (var empId in employeeIds) {
      for (var date in dates) {
        entries.add(HRScheduleEntry(
          id: '',
          employeeId: empId,
          institutionId: widget.institution.id,
          date: date,
          shiftId: isOffDay ? null : shift.id,
          customStartTime: shift.startTime,
          customEndTime: shift.endTime,
          mealStartTime: mealStart,
          mealEndTime: mealEnd,
          isOffDay: isOffDay,
          status: 'planned',
        ));
      }
    }
    
    widget.onAssign(entries);
    setState(() => _selectedCellIds.clear());
  }

  void _showConfigClosingDialog() {
    final service = context.read<FirebaseService>();
    final nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    String selectedType = 'closed';

    showDialog(
      context: context,
      builder: (context) {
        List<int> currentWorkingDays = List<int>.from(widget.institution.workingDays);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const AiTranslatedText('Configuração de Encerramentos e Funcionamento'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AiTranslatedText(
                        'Dias de Funcionamento Semanal',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          final dayNum = index + 1;
                          final isWorking = currentWorkingDays.contains(dayNum);
                          final labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
                          return FilterChip(
                            label: Text(labels[index], style: TextStyle(color: isWorking ? Colors.black : Colors.white70, fontSize: 11)),
                            selected: isWorking,
                            selectedColor: const Color(0xFF00FF85),
                            checkmarkColor: Colors.black,
                            backgroundColor: Colors.white10,
                            onSelected: (selected) async {
                              setState(() {
                                if (selected) {
                                  currentWorkingDays.add(dayNum);
                                } else {
                                  currentWorkingDays.remove(dayNum);
                                }
                              });
                              await service.updateInstitutionWorkingDays(widget.institution.id, currentWorkingDays);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const AiTranslatedText(
                        'Períodos de Fecho Anuais e Férias',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      if (widget.closedDays.isEmpty)
                        const Center(child: AiTranslatedText('Sem encerramentos extraordinários.', style: TextStyle(color: Colors.white38, fontSize: 11)))
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.closedDays.length,
                            itemBuilder: (context, idx) {
                              final cd = widget.closedDays[idx];
                              final start = cd['startDate'] is Timestamp ? (cd['startDate'] as Timestamp).toDate() : DateTime.parse(cd['startDate'].toString());
                              final end = cd['endDate'] is Timestamp ? (cd['endDate'] as Timestamp).toDate() : DateTime.parse(cd['endDate'].toString());
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(cd['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: Text('${_formatDateString(start, 'dd/MM')} a ${_formatDateString(end, 'dd/MM')} (${cd['type']})', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                  onPressed: () async {
                                    await service.deleteHRClosedDay(widget.institution.id, cd['id']);
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const AiTranslatedText(
                        'Adicionar Encerramento / Férias',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Designação (ex: Férias Coletivas de Natal)',
                          hintStyle: TextStyle(color: Colors.white38),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) setState(() => startDate = d);
                              },
                              icon: const Icon(Icons.calendar_today, size: 12),
                              label: Text(startDate == null ? 'Início' : _formatDateString(startDate!, 'dd/MM/yyyy'), style: const TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: startDate ?? DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) setState(() => endDate = d);
                              },
                              icon: const Icon(Icons.calendar_today, size: 12),
                              label: Text(endDate == null ? 'Fim' : _formatDateString(endDate!, 'dd/MM/yyyy'), style: const TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        dropdownColor: const Color(0xFF1E293B),
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 'closed', child: Text('Encerramento Geral')),
                          DropdownMenuItem(value: 'holiday', child: Text('Feriado')),
                          DropdownMenuItem(value: 'training', child: Text('Formação Geral')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedType = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty || startDate == null || endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
                            return;
                          }
                          await service.saveHRClosedDay(widget.institution.id, {
                            'name': nameController.text,
                            'startDate': Timestamp.fromDate(startDate!),
                            'endDate': Timestamp.fromDate(endDate!),
                            'type': selectedType,
                          });
                          nameController.clear();
                          startDate = null;
                          endDate = null;
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF85),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(36),
                        ),
                        child: const AiTranslatedText('Adicionar Período'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AiTranslatedText('Concluído', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return List.generate(lastDay, (i) => DateTime(month.year, month.month, i + 1));
  }
}
