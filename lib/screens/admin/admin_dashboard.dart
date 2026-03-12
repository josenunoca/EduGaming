import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_card.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/subject_model.dart';
import '../../models/institution_model.dart';
import 'institution_management_screen.dart';
import 'admin_revenue_dashboard.dart';
import 'user_access_screen.dart';
import 'marketing_communication_screen.dart';
import '../common/personal_profile_screen.dart';
import '../common/communication_center_screen.dart';
import '../../widgets/advanced_search_anchor.dart';
import '../../widgets/messaging_badge.dart';
import '../login_screen.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Painel de Administrador'),
        actions: [
          StreamBuilder<User?>(
            stream: service.user,
            builder: (context, snapshot) {
              final uid = snapshot.data?.uid;
              if (uid == null) return const SizedBox();
              return StreamBuilder<UserModel?>(
                stream: service.getUserStream(uid),
                builder: (context, userSnap) {
                  final user = userSnap.data;
                  if (user == null) return const SizedBox();
                  return IconButton(
                    icon: const Icon(Icons.person),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalProfileScreen(user: user))),
                    tooltip: 'Área Pessoal',
                  );
                },
              );
            },
          ),
          MessagingBadge(
            icon: const Icon(Icons.mail),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunicationCenterScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketingCommunicationScreen())),
            tooltip: 'Marketing & Comunicação',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdvancedSearchAnchor(
              hintText: 'Pesquisar instituições, alunos, professores...',
              onSearchQuery: (query) async {
                final results = <SearchResult>[];
                
                // Search Institutions
                final insts = await service.searchInstitutions(query).first;
                results.addAll(insts.map((i) => SearchResult(
                  id: i.id,
                  title: i.name,
                  subtitle: i.address,
                  icon: Icons.business,
                  category: 'Instituições',
                  originalObject: i,
                )));

                // Search Users
                final users = await service.searchUsers(query).first;
                results.addAll(users.map((u) => SearchResult(
                  id: u.id,
                  title: u.name,
                  subtitle: '${u.email} • ${u.role.toString().split('.').last}',
                  icon: Icons.person,
                  category: 'Utilizadores',
                  originalObject: u,
                )));

                // Search Subjects
                final subs = await service.searchSubjects(query).first;
                results.addAll(subs.map((s) => SearchResult(
                  id: s.id,
                  title: s.name,
                  subtitle: '${s.level} • ${s.academicYear}',
                  icon: Icons.book,
                  category: 'Disciplinas',
                  originalObject: s,
                )));

                return results;
              },
              onResultSelected: (res) {
                if (res.category == 'Instituições') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InstitutionManagementScreen()));
                } else if (res.category == 'Utilizadores') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAccessScreen()));
                } else if (res.category == 'Disciplinas') {
                  setState(() => _searchQuery = res.title);
                }
              },
              onClear: () => setState(() => _searchQuery = ''),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isNotEmpty)
              Expanded(child: _buildSearchResults(context, service))
            else ...[
              const AiTranslatedText('Resumo da Plataforma', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Row(
                children: [
                  StreamBuilder<List<InstitutionModel>>(
                    stream: service.getInstitutions(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.length.toString() : '...';
                      return _StatCard(
                        label: 'Instituições', 
                        value: count, 
                        color: const Color(0xFF00D1FF),
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const InstitutionManagementScreen())
                        ),
                      );
                    }
                  ),
                  StreamBuilder<List<UserModel>>(
                    stream: service.getUsers(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.length.toString() : '...';
                      return _StatCard(
                        label: 'Controlo de Acessos', 
                        value: count, 
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const UserAccessScreen())
                        ),
                      );
                    }
                  ),
                  _StatCard(
                    label: 'Receitas & SaaS', 
                    value: '€€', 
                    color: Colors.greenAccent,
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const AdminRevenueDashboard())
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const AiTranslatedText('Pagamentos de Inscrição Pendentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<Enrollment>>(
                  stream: service.getEnrollmentsPendingAdmin(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final pending = snapshot.data ?? [];
                    
                    if (pending.isEmpty) {
                      return const Center(child: AiTranslatedText('Nenhuma inscrição aguarda pagamento.', style: TextStyle(color: Colors.white38)));
                    }

                    return ListView.builder(
                      itemCount: pending.length,
                      itemBuilder: (context, index) {
                        final enrollment = pending[index];
                        return ListTile(
                          title: Text(enrollment.studentName, style: const TextStyle(color: Colors.white)),
                          subtitle: Text('Disciplina ID: ${enrollment.subjectId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: ElevatedButton(
                            onPressed: () => service.adminApprovePayment(enrollment.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B61FF),
                              foregroundColor: Colors.white,
                            ),
                            child: const AiTranslatedText('Validar Pagamento'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, FirebaseService service) {
    return ListView(
      children: [
        const AiTranslatedText('Resultados da Pesquisa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00D1FF))),
        const SizedBox(height: 16),
        
        _buildSearchSection<InstitutionModel>(
          title: 'Instituições',
          stream: service.searchInstitutions(_searchQuery),
          itemBuilder: (i) => ListTile(
            leading: const Icon(Icons.business, color: Color(0xFF00D1FF)),
            title: Text(i.name, style: const TextStyle(color: Colors.white)),
            subtitle: AiTranslatedText(i.address, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstitutionManagementScreen())),
          ),
        ),
        
        _buildSearchSection<UserModel>(
          title: 'Utilizadores (Professores/Alunos)',
          stream: service.searchUsers(_searchQuery),
          itemBuilder: (u) => ListTile(
            leading: const Icon(Icons.person, color: Colors.orange),
            title: Text(u.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${u.email} • ${u.role.toString().split('.').last}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAccessScreen())),
          ),
        ),
        
        _buildSearchSection<Subject>(
          title: 'Disciplinas',
          stream: service.searchSubjects(_searchQuery),
          itemBuilder: (s) => ListTile(
            leading: const Icon(Icons.book, color: Color(0xFF7B61FF)),
            title: Text(s.name, style: const TextStyle(color: Colors.white)),
            subtitle: AiTranslatedText('${s.level} • ${s.academicYear}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            // Note: Admin might need a way to view subject details too, but for now we follow the pattern
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
        final results = snapshot.data!;
        if (results.isEmpty) return const SizedBox();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AiTranslatedText(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            ...results.map((item) => itemBuilder(item)),
            const Divider(color: Colors.white10),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label, 
    required this.value, 
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              AiTranslatedText(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
