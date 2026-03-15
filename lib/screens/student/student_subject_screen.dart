import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/subject_model.dart';
import '../../../models/live_session_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/ai_chat_dialog.dart';
import 'ai_game_player_screen.dart';
import 'student_syllabus_screen.dart';
import 'virtual_classroom_student_screen.dart';

class StudentSubjectScreen extends StatefulWidget {
  final String subjectId;
  final String? studentId;

  const StudentSubjectScreen({
    super.key,
    required this.subjectId,
    this.studentId,
  });

  @override
  State<StudentSubjectScreen> createState() => _StudentSubjectScreenState();
}

class _StudentSubjectScreenState extends State<StudentSubjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<SubjectContent> _selectedContents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkAndRecordAttendance());
  }

  Future<void> _checkAndRecordAttendance() async {
    final service = context.read<FirebaseService>();
    final subject = await service.getSubject(widget.subjectId);
    if (subject == null) return;

    final userId = widget.studentId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var session in subject.sessions) {
      final sessionDate =
          DateTime(session.date.year, session.date.month, session.date.day);
      if (sessionDate.isAtSameMomentAs(today)) {
        if (session.startTime != null && session.endTime != null) {
          final startParts = session.startTime!.split(':');
          final endParts = session.endTime!.split(':');

          final startTime = DateTime(now.year, now.month, now.day,
              int.parse(startParts[0]), int.parse(startParts[1]));
          final endTime = DateTime(now.year, now.month, now.day,
              int.parse(endParts[0]), int.parse(endParts[1]));

          if (now.isAfter(startTime) && now.isBefore(endTime)) {
            final alreadyRecorded =
                await service.hasAlreadyRecordedAttendance(userId, session.id);
            if (!alreadyRecorded) {
              final user = await service.getUserData(userId);
              final attendance = Attendance(
                id: '${userId}_${session.id}',
                userId: userId,
                userName: user?.name ?? 'Aluno',
                subjectId: subject.id,
                sessionId: session.id,
                timestamp: now,
              );
              await service.registerAttendance(attendance);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: AiTranslatedText(
                        'Presença registada automaticamente na sessão: ${session.topic}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return FutureBuilder<Subject?>(
      future: service.getSubject(widget.subjectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(child: CircularProgressIndicator()));
        }
        final subject = snapshot.data;
        if (subject == null) {
          return const Scaffold(
              body: Center(child: Text('Disciplina não encontrada')));
        }

        return StreamBuilder<LiveSession?>(
          stream: service.getActiveSessionStream(widget.subjectId),
          builder: (context, liveSnapshot) {
            final liveSession = liveSnapshot.data;

            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                title: AiTranslatedText(subject.name),
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.library_books),
                        child: AiTranslatedText('Conteúdos')),
                    Tab(
                        icon: Icon(Icons.auto_awesome),
                        child: AiTranslatedText('IA Gamer')),
                    Tab(
                        icon: Icon(Icons.assignment_turned_in),
                        child: AiTranslatedText('Avaliação')),
                    Tab(
                        icon: Icon(Icons.grade),
                        child: AiTranslatedText('Notas')),
                    Tab(
                        icon: Icon(Icons.menu_book),
                        child: AiTranslatedText('Programa e Sumários')),
                  ],
                ),
              ),
              floatingActionButton: liveSession != null
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VirtualClassroomStudentScreen(
                              subject: subject,
                              liveSession: liveSession,
                            ),
                          ),
                        );
                      },
                      label: const AiTranslatedText('Entrar na Aula em Direto'),
                      icon: const Icon(Icons.video_call),
                      backgroundColor: Colors.redAccent,
                    )
                  : null,
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContentsTab(subject),
                    _buildGamesTab(subject),
                    _buildEvaluationTab(subject),
                    _buildGradesTab(subject),
                    StudentSyllabusScreen(subject: subject),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentsTab(Subject subject) {
    // Filter out contents that belong to an evaluation component
    final Set<String> evaluationContentIds = {};
    for (var comp in subject.evaluationComponents) {
      evaluationContentIds.addAll(comp.contentIds);
    }

    final filteredContents = subject.contents
        .where((c) => !evaluationContentIds.contains(c.id))
        .toList();

    if (filteredContents.isEmpty) {
      return const Center(
          child: AiTranslatedText('Nenhum conteúdo disponível.',
              style: TextStyle(color: Colors.white38)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_tabController.index != 2) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiChatDialog(
                          selectedContents: List.from(filteredContents),
                          isStudent: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const AiTranslatedText(
                      'DocTalk: Conversar com IA sobre todos os conteúdos'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              if (_selectedContents.isNotEmpty &&
                  _tabController.index != 2) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiChatDialog(
                          selectedContents: List.from(_selectedContents),
                          isStudent: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: AiTranslatedText(
                      'Conversar com IA sobre ${_selectedContents.length} itens selecionados'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredContents.length,
            itemBuilder: (context, index) {
              final content = filteredContents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GlassCard(
                  child: ListTile(
                    leading: Icon(_getFileIcon(content.type),
                        color: const Color(0xFF00D1FF)),
                    title: AiTranslatedText(content.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: AiTranslatedText(content.type.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    trailing: Checkbox(
                      value: _selectedContents.any((c) => c.id == content.id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedContents.add(content);
                          } else {
                            _selectedContents
                                .removeWhere((c) => c.id == content.id);
                          }
                        });
                      },
                      activeColor: const Color(0xFF00D1FF),
                      checkColor: const Color(0xFF0F172A),
                    ),
                    onTap: () {
                      _checkAccessAndLaunch(
                        subject: subject,
                        itemId: content.id,
                        onGranted: () async {
                          final uri = Uri.tryParse(content.url);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGamesTab(Subject subject) {
    final service = context.watch<FirebaseService>();
    return StreamBuilder<List<AiGame>>(
      stream: service.getAiGamesBySubject(subject.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final Set<String> evaluationContentIds = {};
        for (var comp in subject.evaluationComponents) {
          evaluationContentIds.addAll(comp.contentIds);
        }

        final games = (snapshot.data ?? [])
            .where(
                (g) => !g.isAssessment && !evaluationContentIds.contains(g.id))
            .toList();

        if (games.isEmpty) {
          return const Center(
              child: AiTranslatedText(
                  'Ainda não existem jogos de IA para esta disciplina.',
                  style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                            game.type == 'kahoot'
                                ? Icons.quiz
                                : Icons.extension,
                            color: Colors.amber,
                            size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AiTranslatedText(game.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              AiTranslatedText(
                                game.isAssessment
                                    ? 'MODO AVALIAÇÃO'
                                    : 'MODO TREINO',
                                style: TextStyle(
                                    color: game.isAssessment
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Historical Game Stats
                    StreamBuilder<AiGameStats?>(
                      stream: service.getStudentGameStats(
                        widget.studentId ??
                            FirebaseAuth.instance.currentUser?.uid ??
                            '',
                        game.id,
                      ),
                      builder: (context, statsSnapshot) {
                        if (!statsSnapshot.hasData ||
                            statsSnapshot.data == null) {
                          return const SizedBox(); // Handle null data
                        }
                        final stats = statsSnapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                0.05), // Changed withValues to withOpacity
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                  'Jogou?',
                                  stats.playCount > 0 ? 'Sim' : 'Não',
                                  stats.playCount > 0
                                      ? Colors.green
                                      : Colors.redAccent),
                              _buildStatItem('Vezes',
                                  stats.playCount.toString(), Colors.white),
                              _buildStatItem(
                                  'Máx',
                                  '${stats.maxScore.toStringAsFixed(0)} pts',
                                  const Color(0xFF00D1FF)),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _checkAccessAndLaunch(
                          subject: subject,
                          itemId: game.id,
                          onGranted: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      AiGamePlayerScreen(game: game)),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B61FF),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const AiTranslatedText('JOGAR AGORA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvaluationTab(Subject subject) {
    final service = context.watch<FirebaseService>();

    // Get all evaluation IDs
    final Set<String> evaluationContentIds = {};
    for (var comp in subject.evaluationComponents) {
      evaluationContentIds.addAll(comp.contentIds);
    }

    if (evaluationContentIds.isEmpty) {
      return const Center(
        child: AiTranslatedText('Nenhuma avaliação definida pelo professor.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return StreamBuilder<List<AiGame>>(
      stream: service.getAiGamesBySubject(subject.id),
      builder: (context, gameSnapshot) {
        final games = (gameSnapshot.data ?? [])
            .where((g) => g.isAssessment || evaluationContentIds.contains(g.id))
            .toList();

        final evaluationFiles = subject.contents
            .where((c) => evaluationContentIds.contains(c.id))
            .toList();

        if (games.isEmpty && evaluationFiles.isEmpty) {
          return const Center(
            child: AiTranslatedText(
                'Ainda não existem itens de avaliação disponíveis.',
                style: TextStyle(color: Colors.white38)),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (evaluationFiles.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0, left: 4),
                child: AiTranslatedText('Ficheiros e Testes',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              ...evaluationFiles.map((content) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GlassCard(
                      child: ListTile(
                        leading: Icon(_getFileIcon(content.type),
                            color: Colors.redAccent),
                        title: AiTranslatedText(content.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: const AiTranslatedText('ITEM DE AVALIAÇÃO',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        onTap: () {
                          _checkAccessAndLaunch(
                            subject: subject,
                            itemId: content.id,
                            onGranted: () async {
                              final uri = Uri.tryParse(content.url);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (games.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0, left: 4),
                child: AiTranslatedText('Jogos Avaliados',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              ...games.map((game) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                  game.type == 'kahoot'
                                      ? Icons.quiz
                                      : Icons.extension,
                                  color: Colors.amber,
                                  size: 30),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AiTranslatedText(game.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const AiTranslatedText('MODO AVALIAÇÃO',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<AiGameStats?>(
                            stream: service.getStudentGameStats(
                              widget.studentId ??
                                  FirebaseAuth.instance.currentUser?.uid ??
                                  '',
                              game.id,
                              isEvaluation:
                                  true, // Filter for actual exam attempts
                            ),
                            builder: (context, statsSnapshot) {
                              if (!statsSnapshot.hasData ||
                                  statsSnapshot.data == null) {
                                return const SizedBox();
                              }
                              final stats = statsSnapshot.data!;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatItem(
                                        'Avaliado?',
                                        stats.playCount > 0 ? 'Sim' : 'Não',
                                        stats.playCount > 0
                                            ? Colors.green
                                            : Colors.redAccent),
                                    _buildStatItem(
                                        'Vezes',
                                        stats.playCount.toString(),
                                        Colors.white),
                                    _buildStatItem(
                                        'Melhor Nota',
                                        '${stats.maxScore.toStringAsFixed(0)} pts',
                                        const Color(0xFF00D1FF)),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Builder(builder: (context) {
                            return StreamBuilder<AiGameStats?>(
                                stream: service.getStudentGameStats(
                                  widget.studentId ??
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      '',
                                  game.id,
                                  isEvaluation:
                                      true, // Ensure we check evaluation attempts specifically
                                ),
                                builder: (context, statsSnapshot) {
                                  final stats = statsSnapshot.data;
                                  final bool hasPlayed =
                                      stats != null && stats.playCount > 0;

                                  return ElevatedButton(
                                    onPressed: hasPlayed
                                        ? null
                                        : () {
                                            _checkAccessAndLaunch(
                                              subject: subject,
                                              itemId: game.id,
                                              onGranted: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          AiGamePlayerScreen(
                                                            game: game,
                                                            isEvaluation: true,
                                                          )),
                                                );
                                              },
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasPlayed
                                          ? Colors.grey
                                          : const Color(0xFF7B61FF),
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: AiTranslatedText(
                                        hasPlayed
                                            ? 'AVALIAÇÃO CONCLUÍDA'
                                            : 'INICIAR AVALIAÇÃO',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  );
                                });
                          }),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }

  IconData _getFileIcon(String type) {
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('video') || type.contains('mp4')) {
      return Icons.play_circle_outline;
    }
    if (type.contains('audio') || type.contains('mp3')) return Icons.audiotrack;
    if (type.contains('jpg') ||
        type.contains('png') ||
        type.contains('image')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AiTranslatedText(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildGradesTab(Subject subject) {
    final service = context.watch<FirebaseService>();
    final effectiveStudentId =
        widget.studentId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<StudentGradeAdjustment>>(
      stream: service.getGradeAdjustments(subject.id),
      builder: (context, adjustmentSnapshot) {
        return StreamBuilder<List<AiGameResult>>(
          stream:
              Stream.fromFuture(service.getAllSubjectGameResults(subject.id)),
          builder: (context, resultsSnapshot) {
            if (resultsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final adjustments = adjustmentSnapshot.data ?? [];
            final adjustment = adjustments.firstWhere(
              (a) => a.studentId == effectiveStudentId,
              orElse: () =>
                  StudentGradeAdjustment(id: '', studentId: '', subjectId: ''),
            );

            final results = resultsSnapshot.data ?? [];
            final studentResults = results
                .where((r) => r.studentId == effectiveStudentId)
                .toList();

            double weightedSum = 0;
            double totalWeight = 0;
            bool hasMissing = false;

            // Fetch games map for calculations
            return FutureBuilder<List<AiGame>>(
              future: service.getAiGamesBySubject(subject.id).first,
              builder: (context, gamesSnapshot) {
                if (!gamesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final gamesMap = {for (var g in gamesSnapshot.data!) g.id: g};

                List<Widget> componentWidgets = [];

                for (var component in subject.evaluationComponents) {
                  double? grade;

                  // 1. Check override
                  if (adjustment.componentOverrides.containsKey(component.id)) {
                    grade = adjustment.componentOverrides[component.id];
                  } else {
                    // 2. Real calculation
                    double totalEarned = 0;
                    double totalPossible = 0;
                    bool playedSomething = false;

                    for (var contentId in component.contentIds) {
                      final game = gamesMap[contentId];
                      if (game == null) continue;

                      double gameMax =
                          game.questions.fold(0.0, (sum, q) => sum + q.points);
                      totalPossible += gameMax;

                      final gameResults =
                          studentResults.where((r) => r.gameId == contentId);
                      if (gameResults.isNotEmpty) {
                        playedSomething = true;
                        double best = gameResults
                            .map((r) => r.score)
                            .reduce((a, b) => a > b ? a : b);
                        totalEarned += best;
                      }
                    }

                    if (totalPossible > 0) {
                      if (!playedSomething) {
                        if (component.endTime != null &&
                            DateTime.now().isAfter(component.endTime!)) {
                          grade = null; // F
                        } else {
                          grade = 0.0;
                        }
                      } else {
                        grade = (totalEarned / totalPossible) * 20;
                      }
                    } else {
                      grade = 0.0;
                    }
                  }

                  if (grade == null) {
                    hasMissing = true;
                  } else {
                    weightedSum += grade * component.weight;
                    totalWeight += component.weight;
                  }

                  componentWidgets.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AiTranslatedText(component.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                AiTranslatedText(
                                    'Peso: ${(component.weight * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                            Text(
                              grade == null ? 'F' : grade.toStringAsFixed(1),
                              style: TextStyle(
                                color: grade == null
                                    ? Colors.redAccent
                                    : const Color(0xFF00D1FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                double calculatedFinal =
                    totalWeight > 0 ? weightedSum / totalWeight : 0.0;
                double finalGrade =
                    adjustment.finalGradeOverride ?? calculatedFinal;
                String finalStr =
                    hasMissing ? 'F' : finalGrade.toStringAsFixed(1);

                if (subject.pautaStatus == PautaStatus.sealed && !hasMissing) {
                  finalStr = finalGrade.round().toString();
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPautaStatusHeader(subject),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16, left: 4),
                      child: AiTranslatedText('Classificações por Componente',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                    ),
                    ...componentWidgets,
                    const SizedBox(height: 24),
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const AiTranslatedText('CLASSIFICAÇÃO FINAL PROPOSTA',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          Text(
                            finalStr,
                            style: TextStyle(
                              color: hasMissing
                                  ? Colors.redAccent
                                  : const Color(0xFF00D1FF),
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subject.pautaStatus == PautaStatus.sealed) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: AiTranslatedText(
                                  '(Nota Oficial Arredondada)',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                            ),
                            const SizedBox(height: 24),
                            // Certificate Button for Student
                            StreamBuilder<List<Enrollment>>(
                              stream:
                                  service.getEnrollmentsForSubject(subject.id),
                              builder: (context, enrollmentSnapshot) {
                                if (!enrollmentSnapshot.hasData) {
                                  return const SizedBox();
                                }
                                try {
                                  final enrollment =
                                      enrollmentSnapshot.data!.firstWhere(
                                    (e) => e.userId == effectiveStudentId,
                                  );

                                  if (enrollment.certificateUrl != null &&
                                      enrollment.certificateUrl!.isNotEmpty) {
                                    return ElevatedButton.icon(
                                      onPressed: () async {
                                        final url = Uri.parse(
                                            enrollment.certificateUrl!);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      },
                                      icon: const Icon(Icons.workspace_premium),
                                      label: const AiTranslatedText(
                                          'VER CERTIFICADO OFICIAL'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00D1FF),
                                        foregroundColor:
                                            const Color(0xFF0F172A),
                                        minimumSize:
                                            const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  return const SizedBox();
                                }
                                return const SizedBox();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPautaStatusHeader(Subject subject) {
    Color color;
    String text;
    String sub;
    IconData icon;

    switch (subject.pautaStatus) {
      case PautaStatus.draft:
        color = Colors.grey;
        text = 'Em Processamento';
        sub = 'As notas ainda estão a ser lançadas pelo professor.';
        icon = Icons.hourglass_empty;
        break;
      case PautaStatus.finalized:
        color = Colors.orange;
        text = 'Pauta Finalizada';
        sub = 'As notas foram finalizadas. Aguarde a lacragem oficial.';
        icon = Icons.check_circle_outline;
        break;
      case PautaStatus.sealed:
        color = Colors.greenAccent;
        text = 'Pauta Lacrada';
        sub = 'Esta é a sua classificação oficial final.';
        icon = Icons.lock;
        break;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AiTranslatedText(text,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                AiTranslatedText(sub,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _checkAccessAndLaunch({
    required Subject subject,
    required String itemId,
    required VoidCallback onGranted,
  }) {
    // Check if the item is part of an evaluation component
    EvaluationComponent? evalComp;
    try {
      evalComp = subject.evaluationComponents.firstWhere(
        (comp) => comp.contentIds.contains(itemId),
      );
    } catch (e) {
      evalComp = null;
    }

    if (evalComp == null) {
      // Not part of an evaluation component, allow access immediately
      onGranted();
      return;
    }

    final now = DateTime.now();

    // Check time limits
    if (evalComp.startTime != null && now.isBefore(evalComp.startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Este item de avaliação só estará disponível a partir de ${evalComp.startTime!.day}/${evalComp.startTime!.month}/${evalComp.startTime!.year} às ${evalComp.startTime!.hour}:${evalComp.startTime!.minute.toString().padLeft(2, '0')}.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (evalComp.endTime != null && now.isAfter(evalComp.endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Este item de avaliação já expirou a ${evalComp.endTime!.day}/${evalComp.endTime!.month}/${evalComp.endTime!.year} às ${evalComp.endTime!.hour}:${evalComp.endTime!.minute.toString().padLeft(2, '0')}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Check if PIN is required
    if (evalComp.pin != null && evalComp.pin!.isNotEmpty) {
      final pinController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('PIN de Acesso Necessário',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText(
                  'Para aceder a esta avaliação, introduza o PIN fornecido pelo professor.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == evalComp!.pin) {
                  Navigator.pop(context); // Close dialog
                  onGranted(); // Launch
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN incorreto.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const AiTranslatedText('Aceder'),
            ),
          ],
        ),
      );
    } else {
      // No PIN required, launch normally
      onGranted();
    }
  }
}
