import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/hr/hr_schedule_model.dart';
import '../../../../models/user_model.dart';
import '../../../../widgets/ai_translated_text.dart';

class HRSchedulePlanner extends StatefulWidget {
  final List<UserModel> employees;
  final List<HRShift> availableShifts;
  final Function(List<String> employeeIds, List<DateTime> dates, HRShift shift) onAssign;

  const HRSchedulePlanner({
    super.key,
    required this.employees,
    required this.availableShifts,
    required this.onAssign,
  });

  @override
  State<HRSchedulePlanner> createState() => _HRSchedulePlannerState();
}

class _HRSchedulePlannerState extends State<HRSchedulePlanner> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  
  DateTime _currentMonth = DateTime.now();
  
  // Selection state
  final Set<String> _selectedCellIds = {}; // Format: "employeeId_yyyy-MM-dd"
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            children: [
              // fixed column of employees
              SizedBox(
                width: 150,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) => _buildEmployeeRow(widget.employees[index]),
                ),
              ),
              // Scrollable grid
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: daysInMonth.length * 60.0,
                    child: ListView.builder(
                      controller: _verticalController,
                      itemCount: widget.employees.length,
                      itemBuilder: (context, empIndex) => _buildGridRow(widget.employees[empIndex], daysInMonth),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
          ),
          AiTranslatedText(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(UserModel employee) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10), right: BorderSide(color: Colors.white10)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        employee.name,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildGridRow(UserModel employee, List<DateTime> days) {
    return SizedBox(
      height: 60,
      child: Row(
        children: days.map((day) {
          final cellId = "${employee.id}_${DateFormat('yyyy-MM-dd').format(day)}";
          final isSelected = _selectedCellIds.contains(cellId);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) _selectedCellIds.remove(cellId);
                else _selectedCellIds.add(cellId);
              });
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00D1FF).withValues(alpha: 0.2) : Colors.transparent,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Center(
                child: Text(
                  DateFormat('dd').format(day),
                  style: TextStyle(color: isSelected ? const Color(0xFF00D1FF) : Colors.white24, fontSize: 10),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectionActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
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
          ],
        ),
      ),
    );
  }

  void _assignShift(HRShift shift) {
    // Parse selected IDs back to employeeIds and Dates
    final employeeIds = _selectedCellIds.map((id) => id.split('_')[0]).toSet().toList();
    final dates = _selectedCellIds.map((id) => DateFormat('yyyy-MM-dd').parse(id.split('_')[1])).toSet().toList();
    
    widget.onAssign(employeeIds, dates, shift);
    setState(() => _selectedCellIds.clear());
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return List.generate(lastDay, (i) => DateTime(month.year, month.month, i + 1));
  }
}
