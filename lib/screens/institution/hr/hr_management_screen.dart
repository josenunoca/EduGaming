import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/institution_model.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import 'tabs/hr_dashboard_tab.dart';
import 'tabs/hr_staff_tab.dart';
import 'tabs/hr_schedule_tab.dart';
import 'tabs/hr_attendance_tab.dart';
import 'tabs/hr_absences_tab.dart';
import 'tabs/hr_evaluation_tab.dart';

class HRManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const HRManagementScreen({super.key, required this.institution});

  @override
  State<HRManagementScreen> createState() => _HRManagementScreenState();
}

class _HRManagementScreenState extends State<HRManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Gestão de Recursos Humanos 360º'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF00D1FF).withValues(alpha: 0.2),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF00D1FF),
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumo'),
                Tab(icon: Icon(Icons.people_outline), text: 'Funcionários'),
                Tab(icon: Icon(Icons.calendar_view_week_outlined), text: 'Escalas'),
                Tab(icon: Icon(Icons.fingerprint_outlined), text: 'Assiduidade'),
                Tab(icon: Icon(Icons.beach_access_outlined), text: 'Férias/Faltas'),
                Tab(icon: Icon(Icons.assessment_outlined), text: 'Avaliação'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          HRDashboardTab(institution: widget.institution),
          HRStaffTab(institution: widget.institution),
          HRScheduleTab(institution: widget.institution),
          HRAttendanceTab(institution: widget.institution),
          HRAbsencesTab(institution: widget.institution),
          HREvaluationTab(institution: widget.institution),
        ],
      ),
    );
  }
}
