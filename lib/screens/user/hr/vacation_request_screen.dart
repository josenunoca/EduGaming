import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRVacationRequestScreen extends StatefulWidget {
  final UserModel user;

  const HRVacationRequestScreen({super.key, required this.user});

  @override
  State<HRVacationRequestScreen> createState() => _HRVacationRequestScreenState();
}

class _HRVacationRequestScreenState extends State<HRVacationRequestScreen> {
  DateTimeRange? _selectedRange;
  bool _isLoading = false;
  HRVacationPlan? _plan;

  String _formatDateString(DateTime date, String pattern) {
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
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final service = context.read<FirebaseService>();
    final plan = await service.getHRVacationPlan(
      widget.user.institutionId ?? '',
      widget.user.id,
      DateTime.now().year,
    );
    setState(() => _plan = plan);
  }

  Future<void> _submit() async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, selecione o período de férias.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = context.read<FirebaseService>();
      
      final absence = HRAbsence(
        id: const Uuid().v4(),
        employeeId: widget.user.id,
        institutionId: widget.user.institutionId ?? '',
        startDate: _selectedRange!.start,
        endDate: _selectedRange!.end,
        type: AbsenceType.vacation,
        description: 'Pedido de férias via App',
        status: 'pending',
      );

      await service.saveHRAbsence(absence);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('Pedido de férias enviado para aprovação!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = _plan != null ? (_plan!.totalDaysAllowed - _plan!.daysUsed) : 22;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Marcar Férias'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.beach_access, color: Colors.orange, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AiTranslatedText('Dias Disponíveis', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          '$daysRemaining Dias',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const AiTranslatedText(
              'Escolher Período',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Date Selection
            InkWell(
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.orange,
                          onPrimary: Colors.black,
                          surface: Color(0xFF1E293B),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) setState(() => _selectedRange = range);
              },
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.date_range, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _selectedRange == null 
                            ? 'Clique para selecionar as datas' 
                            : '${_formatDateString(_selectedRange!.start, 'dd/MM/yyyy')} - ${_formatDateString(_selectedRange!.end, 'dd/MM/yyyy')}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedRange == null ? Colors.white38 : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedRange != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Total: ${_selectedRange!.end.difference(_selectedRange!.start).inDays + 1} dias',
                            style: const TextStyle(color: Colors.orange, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const AiTranslatedText('Solicitar Férias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 24),
            const Center(
              child: AiTranslatedText(
                'Nota: O seu pedido será revisto pelo departamento de RH.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
