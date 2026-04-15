import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../models/institution_organ_model.dart';
import '../../models/activity_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/branded_title.dart';
import '../../widgets/messaging_badge.dart';
import '../../widgets/advanced_search_anchor.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/user_notices_widget.dart';
import 'subject_details_screen.dart';
import '../common/personal_profile_screen.dart';
import '../common/communication_center_screen.dart';
import '../common/timetable_user_screen.dart';
import '../institution/institutional_management_screen.dart';
import '../institution/academic_management_screen.dart';
import '../institution/activity_details_screen.dart';
import '../institution/institution_collaborator_management_screen.dart';
import '../institution/credit_management_screen.dart';
import '../institution/lifestyle_management_screen.dart';
import '../institution/delegation_management_screen.dart';
import '../institutional/institutional_organs_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String? _selectedYearFilter;
  String _searchQuery = '';

  void _createNewSubject(BuildContext context, UserModel teacher) {
    if (teacher.institutionId == null || teacher.institutionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Aviso: Ainda não está associado a nenhuma Instituição. Contacte o Administrador.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateSubjectModal(teacher: teacher),
    );
  }

  void _showDuplicateDialog(
      BuildContext context, FirebaseService service, Subject subject) {
    String selectedYear = '2024/2025';
    showDialog(
      context: context,
      builder: (context) {
        bool isDuplicating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const AiTranslatedText('Duplicar Disciplina',
                  style: TextStyle(color: Colors.white)),
              content: isDuplicating
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00D1FF)),
                        SizedBox(height: 20),
                        AiTranslatedText('A duplicar conteúdos e jogos...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AiTranslatedText(
                            'Selecione o novo ano letivo para a cópia:',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedYear,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: ['2023/2024', '2024/2025', '2025/2026']
                              .map((y) =>
                                  DropdownMenuItem(value: y, child: Text(y)))
                              .toList(),
                          onChanged: (v) => selectedYear = v!,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                        ),
                      ],
                    ),
              actions: isDuplicating
                  ? []
                  : [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => isDuplicating = true);
                          try {
                            await service.duplicateSubject(
                                subject, selectedYear);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isDuplicating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao duplicar: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D1FF),
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        child: const Text('Duplicar'),
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
    final service = context.watch<FirebaseService>();

    return StreamBuilder<User?>(
      stream: service.user,
      builder: (context, authSnapshot) {
        final userId = authSnapshot.data?.uid ?? '';
        if (userId.isEmpty) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<UserModel?>(
          stream: service.getUserStream(userId),
          builder: (context, userSnapshot) {
            final teacher = userSnapshot.data;
            if (teacher == null) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            return StreamBuilder<InstitutionModel?>(
              stream: teacher.institutionId != null
                  ? service.getInstitutionStream(teacher.institutionId!)
                  : Stream.value(null),
              builder: (context, instSnap) {
                final institution = instSnap.data;

                return Scaffold(
                  appBar: AppBar(
                    title: BrandedTitle(
                      logoUrl: institution?.logoUrl,
                      institutionName: institution?.name,
                      defaultTitle: 'Painel do Professor',
                    ),
                    actions: [
                      Tooltip(
                        message: 'Ver e editar os seus dados pessoais',
                        child: IconButton(
                          icon: const Icon(Icons.person),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PersonalProfileScreen(user: teacher))),
                        ),
                      ),
                      Tooltip(
                        message: 'Abrir centro de mensagens e correspondência',
                        child: MessagingBadge(
                          icon: const Icon(Icons.mail),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const CommunicationCenterScreen())),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TimetableUserScreen(user: teacher),
                          ),
                        ),
                        tooltip: 'Ver o meu horário escolar',
                      ),
                      Tooltip(
                        message: 'Sair da conta e voltar ao ecrã de login',
                        child: IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  floatingActionButton: Tooltip(
                    message: 'Criar uma nova disciplina para lecionar',
                    child: FloatingActionButton.extended(
                      onPressed: () => _createNewSubject(context, teacher),
                      label: const AiTranslatedText('Nova Disciplina'),
                      icon: const Icon(Icons.add),
                      backgroundColor: const Color(0xFF7B61FF),
                    ),
                  ),
                  body: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdvancedSearchAnchor(
                            hintText: 'Pesquisar disciplinas ou alunos...',
                            onSearchQuery: (query) async {
                              final results = <SearchResult>[];

                              // Search Subjects
                              final subs = await service
                                  .searchSubjects(query, teacherId: teacher.id)
                                  .first;
                              results.addAll(subs.map((s) => SearchResult(
                                    id: s.id,
                                    title: s.name,
                                    subtitle: '${s.level} • ${s.academicYear}',
                                    icon: Icons.book,
                                    category: 'As Minhas Disciplinas',
                                    originalObject: s,
                                  )));

                              // Search Students
                              final students = await service
                                  .searchTeacherStudents(teacher.id, query)
                                  .first;
                              results.addAll(students.map((u) => SearchResult(
                                    id: u.id,
                                    title: u.name,
                                    subtitle: u.email,
                                    icon: Icons.person,
                                    category: 'Alunos',
                                    originalObject: u,
                                  )));

                              return results;
                            },
                            onResultSelected: (res) {
                              if (res.category == 'As Minhas Disciplinas') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => SubjectDetailsScreen(
                                            subject: res.originalObject
                                                as Subject)));
                              } else {
                                setState(() => _searchQuery = res.title);
                              }
                            },
                            onClear: () => setState(() => _searchQuery = ''),
                          ),
                          if (_searchQuery.isNotEmpty)
                            Expanded(
                                child: _buildSearchResults(
                                    context, service, teacher.id))
                          else ...[
                            AiTranslatedText('Bem-vindo, ${teacher.name}',
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.white70)),
                            const AiTranslatedText('As Minhas Disciplinas',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 12),
                            UserNoticesWidget(user: teacher),
                            const SizedBox(height: 16),
                            DropdownButton<String?>(
                              value: _selectedYearFilter,
                              hint: const AiTranslatedText(
                                  'Filtrar por Ano Letivo',
                                  style: TextStyle(color: Colors.white70)),
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Todos os Anos')),
                                ...[
                                  '2023/2024',
                                  '2024/2025',
                                  '2025/2026'
                                ].map((y) =>
                                    DropdownMenuItem(value: y, child: Text(y))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedYearFilter = v),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: DefaultTabController(
                                length: 3,
                                child: Column(
                                  children: [
                                    const TabBar(
                                      indicatorColor: Color(0xFF7B61FF),
                                      labelColor: Colors.white,
                                      unselectedLabelColor: Colors.white54,
                                      tabs: [
                                        Tab(text: 'Minhas Turmas'),
                                        Tab(text: 'Minhas Atividades'),
                                        Tab(text: 'Gestão Delegada'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          // TAB 1: Subjects
                                          StreamBuilder<List<Subject>>(
                                            stream: service.getSubjectsByTeacher(teacher.id, academicYear: _selectedYearFilter),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                              final subjects = snapshot.data ?? [];
                                              if (subjects.isEmpty) return const Center(child: AiTranslatedText('Sem turmas atribuídas.', style: TextStyle(color: Colors.white54)));
                                              return ListView.builder(
                                                itemCount: subjects.length,
                                                itemBuilder: (context, index) {
                                                  final subject = subjects[index];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 12.0),
                                                    child: GlassCard(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 32,
                                                            height: 32,
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: const Icon(Icons.book, color: Color(0xFF7B61FF), size: 16),
                                                          ),
                                                          const SizedBox(width: 16),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                AiTranslatedText(subject.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                                                AiTranslatedText('${subject.level} • ${subject.academicYear}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                                                AiTranslatedText('${subject.contents.length} conteúdos', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                                              ],
                                                            ),
                                                          ),
                                                          Column(
                                                            children: [
                                                              ElevatedButton(
                                                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectDetailsScreen(subject: subject))),
                                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF), foregroundColor: Colors.white),
                                                                child: const AiTranslatedText('GERIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                              ),
                                                              TextButton.icon(
                                                                onPressed: () => _showDuplicateDialog(context, service, subject),
                                                                icon: const Icon(Icons.copy, size: 14, color: Colors.blueAccent),
                                                                label: const AiTranslatedText('Duplicar', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          
                                          StreamBuilder<List<InstitutionalActivity>>(
                                            stream: service.getActivitiesByResponsible(teacher.id, academicYear: _selectedYearFilter),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                              
                                              // Standardized sorting: planned first, then nearest date
                                              final activities = snapshot.data ?? [];
                                              activities.sort((a, b) {
                                                if (a.status == 'planned' && b.status == 'completed') return -1;
                                                if (a.status == 'completed' && b.status == 'planned') return 1;
                                                return a.startDate.compareTo(b.startDate);
                                              });

                                              if (activities.isEmpty) return const Center(child: AiTranslatedText('Nenhuma atividade atribuída como responsável.', style: TextStyle(color: Colors.white54)));
                                              
                                              return ListView.builder(
                                                itemCount: activities.length,
                                                itemBuilder: (context, index) {
                                                  final activity = activities[index];
                                                  final isCompleted = activity.status == 'completed';
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 12.0),
                                                    child: GlassCard(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      child: ListTile(
                                                        leading: Container(
                                                          width: 40, height: 40,
                                                          decoration: BoxDecoration(
                                                            color: (isCompleted ? Colors.green : Colors.teal).withValues(alpha: 0.2),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(
                                                            isCompleted ? Icons.check_circle : Icons.event,
                                                            color: isCompleted ? Colors.greenAccent : Colors.teal,
                                                          ),
                                                        ),
                                                        title: Text(
                                                          activity.title,
                                                          style: TextStyle(
                                                            color: isCompleted ? Colors.white54 : Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                          ),
                                                        ),
                                                        subtitle: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              '${activity.startDate.day}/${activity.startDate.month}/${activity.startDate.year} - ${activity.activityGroup}',
                                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                            ),
                                                            if (activity.responsibleName != null && activity.responsibleUserId != teacher.id)
                                                              Text(
                                                                'Resp: ${activity.responsibleName}',
                                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                              ),
                                                          ],
                                                        ),
                                                        trailing: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (!isCompleted)
                                                              IconButton(
                                                                icon: const Icon(Icons.check_circle_outline,
                                                                    color: Colors.greenAccent),
                                                                onPressed: () => service.updateActivityStatus(
                                                                    activity.id, 'completed'),
                                                                tooltip: 'Concluir Atividade',
                                                              ),
                                                            ElevatedButton(
                                                              onPressed: () {
                                                                if (institution != null) {
                                                                  Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                          builder: (_) =>
                                                                              ActivityDetailsScreen(
                                                                                  activity: activity,
                                                                                  institution:
                                                                                      institution)));
                                                                }
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: isCompleted
                                                                    ? Colors.white10
                                                                    : Colors.teal,
                                                                foregroundColor: Colors.white,
                                                                padding: const EdgeInsets.symmetric(
                                                                    horizontal: 12),
                                                              ),
                                                              child: const Text('GERIR',
                                                                  style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight:
                                                                          FontWeight.bold)),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),

                                          // TAB 3: Delegated Management (SAP Style)
                                          _buildDelegatedTab(context, teacher, institution),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(
      BuildContext context, FirebaseService service, String teacherId) {
    return ListView(
      children: [
        const AiTranslatedText('Resultados da Pesquisa',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7B61FF))),
        const SizedBox(height: 16),
        _buildSearchSection<Subject>(
          title: 'As Minhas Disciplinas',
          stream: service.searchSubjects(_searchQuery, teacherId: teacherId),
          itemBuilder: (s) => ListTile(
            leading: const Icon(Icons.book, color: Color(0xFF7B61FF)),
            title: Text(s.name, style: const TextStyle(color: Colors.white)),
            subtitle: AiTranslatedText('${s.level} • ${s.academicYear}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SubjectDetailsScreen(subject: s))),
          ),
        ),
        _buildSearchSection<UserModel>(
          title: 'Alunos',
          stream: service.searchTeacherStudents(teacherId, _searchQuery),
          itemBuilder: (u) => ListTile(
            leading: const Icon(Icons.person, color: Colors.greenAccent),
            title: Text(u.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(u.email,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSection<T>({
    required String title,
    required Stream<List<T>> stream,
    required Widget Function(T) itemBuilder,
  }) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AiTranslatedText(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            ...results.map((item) => itemBuilder(item)),
            const Divider(color: Colors.white10),
          ],
        );
      },
    );
  }

  Widget _buildDelegatedTab(BuildContext context, UserModel teacher, InstitutionModel? institution) {
    if (institution == null) return const Center(child: CircularProgressIndicator());

    final service = context.read<FirebaseService>();

    return StreamBuilder<List<InstitutionOrgan>>(
      stream: service.getInstitutionOrgans(institution.id),
      builder: (context, organSnapshot) {
        final organs = organSnapshot.data ?? [];
        final delegated = <Map<String, dynamic>>[];
        
        // Helper to check if a specific key OR its parent is delegated
        bool isAnyDelegated(String key) {
          if (institution.delegatedRoles[key]?.contains(teacher.id) ?? false) return true;
          // Check parent if applicable
          if (key.contains(':')) {
            final parent = key.split(':').first;
            if (institution.delegatedRoles[parent]?.contains(teacher.id) ?? false) return true;
          }
          return false;
        }

        // 1. Check Global Modules
        if (isAnyDelegated('professors')) {
          delegated.add({
            'label': 'Gerir Colaboradores',
            'icon': Icons.people,
            'color': const Color(0xFF00D1FF),
            'page': InstitutionCollaboratorManagementScreen(institution: institution),
          });
        }
        
        if (isAnyDelegated('global_360')) {
          delegated.add({
            'label': 'Gestão Global 360º',
            'icon': Icons.admin_panel_settings,
            'color': const Color(0xFF7B61FF),
            'page': InstitutionalManagementScreen(institution: institution),
          });
        } else {
          // Check sub-modules of global_360 if full access isn't granted
          if (isAnyDelegated('global_360:activities')) {
            delegated.add({
              'label': 'Gestão Atividades',
              'icon': Icons.event,
              'color': const Color(0xFF7B61FF),
              'page': InstitutionalManagementScreen(institution: institution, initialTab: 1), 
            });
          }
          if (isAnyDelegated('global_360:spaces')) {
            delegated.add({
              'label': 'Gestão Espaços',
              'icon': Icons.room,
              'color': const Color(0xFF7B61FF),
              'page': InstitutionalManagementScreen(institution: institution, initialTab: 0),
            });
          }
          if (isAnyDelegated('global_360:timetable')) {
            delegated.add({
              'label': 'Gestão Horários',
              'icon': Icons.calendar_today,
              'color': const Color(0xFF7B61FF),
              'page': InstitutionalManagementScreen(institution: institution, initialTab: 2),
            });
          }
        }

        if (isAnyDelegated('credits')) {
          delegated.add({
            'label': 'Gestão de Créditos',
            'icon': Icons.token,
            'color': Colors.amber,
            'page': InstitutionCreditManagementScreen(institution: institution),
          });
        }

        if (isAnyDelegated('academic')) {
          delegated.add({
            'label': 'Gestão Académica',
            'icon': Icons.school,
            'color': Colors.indigo,
            'page': AcademicManagementScreen(institution: institution),
          });
        }

        if (isAnyDelegated('lifestyle')) {
          delegated.add({
            'label': 'Estilo de Vida',
            'icon': Icons.favorite,
            'color': Colors.pinkAccent,
            'page': const LifestyleManagementScreen(),
          });
        }

        if (isAnyDelegated('delegations')) {
          delegated.add({
            'label': 'Gestão de Delegações',
            'icon': Icons.supervised_user_circle,
            'color': Colors.tealAccent,
            'page': DelegationManagementScreen(institution: institution),
          });
        }

        // 2. Check Specific Organs
        for (final organ in organs) {
          final organKey = 'organs:${organ.id}';
          if (institution.delegatedRoles[organKey]?.contains(teacher.id) ?? false) {
            delegated.add({
              'label': organ.name,
              'icon': Icons.account_balance,
              'color': Colors.tealAccent,
              'page': InstitutionalOrgansScreen(institution: institution),
            });
          }
        }

        if (delegated.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: AiTranslatedText(
                'Não possui responsabilidades delegadas pela instituição neste momento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (delegated.any((d) => d['label'].startsWith('Gestão') || d['label'].startsWith('Gerir'))) ...[
              const _SectionHeader(title: 'MÓDULOS INSTITUCIONAIS'),
              ...delegated.where((d) => !d['label'].contains('Conselho') && !organs.any((o) => o.name == d['label'])).map((d) => _buildDelegatedTile(context, d)),
            ],
            if (delegated.any((d) => organs.any((o) => o.name == d['label']))) ...[
              const SizedBox(height: 16),
              const _SectionHeader(title: 'ÓRGÃOS E ATAS DELEGADOS'),
              ...delegated.where((d) => organs.any((o) => o.name == d['label'])).map((d) => _buildDelegatedTile(context, d)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDelegatedTile(BuildContext context, Map<String, dynamic> d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: GlassCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => d['page'])),
        child: ListTile(
          leading: Icon(d['icon'], color: d['color']),
          title: AiTranslatedText(d['label'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 12),
      child: AiTranslatedText(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CreateSubjectModal extends StatefulWidget {
  final UserModel teacher;
  const _CreateSubjectModal({required this.teacher});

  @override
  State<_CreateSubjectModal> createState() => _CreateSubjectModalState();
}

class _CreateSubjectModalState extends State<_CreateSubjectModal> {
  final _nameController = TextEditingController();
  String _selectedLevel = '1.º Ciclo';
  String _selectedYear = '2024/2025';
  String? _selectedScientificArea;
  final _teachingHoursController = TextEditingController(text: '0.0');
  final _nonTeachingHoursController = TextEditingController(text: '0.0');

  @override
  Widget build(BuildContext context) {
    final scientificAreas = FirebaseService.getScientificAreas();

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova Disciplina',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Nome da Disciplina', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            items: [
              'Creche',
              'Pré-Escolar',
              '1.º Ciclo',
              '2.º Ciclo',
              '3.º Ciclo',
              'Secundário',
              'Ensino Profissional',
              'Licenciatura',
              'Mestrado',
              'Doutoramento'
            ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _selectedLevel = v!),
            decoration: const InputDecoration(
                labelText: 'Nível de Ensino', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedYear,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            items: ['2023/2024', '2024/2025', '2025/2026']
                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                .toList(),
            onChanged: (v) => setState(() => _selectedYear = v!),
            decoration: const InputDecoration(
                labelText: 'Ano Letivo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _selectedScientificArea,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            hint: const Text('Área Científica (Opcional)',
                style: TextStyle(color: Colors.white54)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nenhuma')),
              ...scientificAreas
                  .map((a) => DropdownMenuItem(value: a, child: Text(a))),
            ],
            onChanged: (v) => setState(() => _selectedScientificArea = v),
            decoration: const InputDecoration(
                labelText: 'Área Científica', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _teachingHoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Horas Letivas', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nonTeachingHoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Horas Não Letivas',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty) return;
              final service = context.read<FirebaseService>();
              final s = Subject(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                level: _selectedLevel,
                academicYear: _selectedYear,
                teacherId: widget.teacher.id,
                institutionId: widget.teacher.institutionId ?? 'pending',
                allowedStudentEmails: [],
                contents: [],
                games: [],
                scientificArea: _selectedScientificArea,
                courseId: 'standalone',
                theoreticalHours:
                    double.tryParse(_teachingHoursController.text) ?? 0.0,
                otherHours:
                    double.tryParse(_nonTeachingHoursController.text) ?? 0.0,
                syllabusStatus: SyllabusStatus.provisional,
              );
              await service.updateSubject(s);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color(0xFF7B61FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Criar Disciplina',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
