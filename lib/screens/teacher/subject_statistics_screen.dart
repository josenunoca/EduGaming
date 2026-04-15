import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/subject_model.dart';
import '../../services/firebase_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import 'dart:math' as math;

class SubjectStatisticsScreen extends StatefulWidget {
  final Subject subject;

  const SubjectStatisticsScreen({super.key, required this.subject});

  @override
  State<SubjectStatisticsScreen> createState() =>
      _SubjectStatisticsScreenState();
}

class _SubjectStatisticsScreenState extends State<SubjectStatisticsScreen> {
  bool _isLoading = true;
  List<StudentStats> _studentData = [];
  double _attendanceGradeCorrelation = 0;
  double _trainingGradeCorrelation = 0;

  @override
  void initState() {
    super.initState();
    _computeStats();
  }

  Future<void> _computeStats() async {
    final service = context.read<FirebaseService>();
    try {
      final enrollments =
          await service.getEnrollmentsForSubject(widget.subject.id).first;
      final attendances =
          await service.getAttendanceForSubject(widget.subject.id);
      final gameResults =
          await service.getAllSubjectGameResults(widget.subject.id);
      final grades = await service.getGradeAdjustments(widget.subject.id).first;
      final games = await service.getAiGamesBySubject(widget.subject.id).first;

      final finalizedSessions =
          widget.subject.sessions.where((s) => s.isFinalized).toList();

      List<StudentStats> statsList = [];

      for (var enrollment in enrollments) {
        if (enrollment.status != 'accepted') continue;

        // Attendance %
        int presentCount =
            attendances.where((a) => a.userId == enrollment.userId).length;
        double attPerc = finalizedSessions.isEmpty
            ? 100.0
            : (presentCount / finalizedSessions.length) * 100;

        // Training Games Frequency
        final trainingGames =
            games.where((g) => !g.isAssessment).map((g) => g.id).toSet();
        int trainingCount = gameResults
            .where((r) =>
                r.studentId == enrollment.userId &&
                trainingGames.contains(r.gameId))
            .length;

        // Final Grade (Calculated or Override)
        final adj = grades.firstWhere((g) => g.studentId == enrollment.userId,
            orElse: () =>
                StudentGradeAdjustment(id: '', studentId: '', subjectId: ''));
        double finalGrade = adj.finalGradeOverride ??
            _calculateCalculatedGrade(
                widget.subject,
                gameResults
                    .where((r) => r.studentId == enrollment.userId)
                    .toList(),
                games);

        statsList.add(StudentStats(
          studentName: enrollment.studentName,
          attendancePercentage: attPerc,
          trainingGamesCount: trainingCount,
          finalGrade: finalGrade,
        ));
      }

      setState(() {
        _studentData = statsList;
        _attendanceGradeCorrelation = _calculateCorrelation(
          statsList.map((s) => s.attendancePercentage).toList(),
          statsList.map((s) => s.finalGrade).toList(),
        );
        _trainingGradeCorrelation = _calculateCorrelation(
          statsList.map((s) => s.trainingGamesCount.toDouble()).toList(),
          statsList.map((s) => s.finalGrade).toList(),
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error computing stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateCalculatedGrade(
      Subject subject, List<AiGameResult> results, List<AiGame> games) {
    double weightedSum = 0;
    double totalWeight = 0;

    final gamesMap = {for (var g in games) g.id: g};

    for (var component in subject.evaluationComponents) {
      double totalEarned = 0;
      double totalPossible = 0;
      bool played = false;

      for (var contentId in component.contentIds) {
        final game = gamesMap[contentId];
        if (game == null) continue;
        totalPossible += game.questions.fold(0.0, (sum, q) => sum + q.points);

        final res = results.where((r) => r.gameId == contentId).toList();
        if (res.isNotEmpty) {
          played = true;
          totalEarned +=
              res.map((r) => r.score).reduce((a, b) => a > b ? a : b);
        }
      }

      if (totalPossible > 0 && played) {
        double grade = (totalEarned / totalPossible) * 20;
        weightedSum += grade * component.weight;
        totalWeight += component.weight;
      }
    }
    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.isEmpty || y.isEmpty || x.length != y.length) return 0;
    int n = x.length;
    double sumX = x.reduce((a, b) => a + b);
    double sumY = y.reduce((a, b) => a + b);
    double sumXY = 0;
    double sumX2 = 0;
    double sumY2 = 0;
    for (int i = 0; i < n; i++) {
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
    }
    double numerator = n * sumXY - sumX * sumY;
    double denominator =
        math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
    if (denominator == 0) return 0;
    return numerator / denominator;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const AiTranslatedText('Análise Estatística'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () =>
                PdfService.generateStatisticsPDF(widget.subject, _studentData),
            tooltip: 'Exportar PDF',
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  children: [
                    _buildCorrelationOverview(),
                    const SizedBox(height: 24),
                    _buildScatterPlot(
                        'Presença vs Nota Final',
                        'Presença (%)',
                        'Nota (0-20)',
                        (s) => FlSpot(s.attendancePercentage, s.finalGrade)),
                    const SizedBox(height: 24),
                    _buildScatterPlot(
                        'Jogos Treino vs Nota Final',
                        'Nº Jogos',
                        'Nota (0-20)',
                        (s) => FlSpot(
                            s.trainingGamesCount.toDouble(), s.finalGrade)),
                    const SizedBox(height: 24),
                    _buildGradeDistribution(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCorrelationOverview() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const AiTranslatedText('Índices de Correlação (Pearson)',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCorrelationItem(
                  'Assiduidade / Notas', _attendanceGradeCorrelation),
              _buildCorrelationItem(
                  'Treino / Notas', _trainingGradeCorrelation),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationItem(String label, double val) {
    Color color = val > 0.5
        ? Colors.greenAccent
        : (val > 0.3 ? Colors.amberAccent : Colors.redAccent);
    return Column(
      children: [
        AiTranslatedText(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(val.toStringAsFixed(2),
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildScatterPlot(String title, String xLabel, String yLabel,
      FlSpot Function(StudentStats) spotter) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.5,
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: _studentData.map((s) {
                  final spot = spotter(s);
                  return ScatterSpot(spot.x, spot.y);
                }).toList(),
                minX: 0,
                maxX: title.contains('Presença')
                    ? 100
                    : _studentData
                            .map((s) => s.trainingGamesCount)
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() +
                        1,
                minY: 0,
                maxY: 20,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                      axisNameWidget: AiTranslatedText(xLabel,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                      sideTitles:
                          const SideTitles(showTitles: true, reservedSize: 22)),
                  leftTitles: AxisTitles(
                      axisNameWidget: AiTranslatedText(yLabel,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                      sideTitles:
                          const SideTitles(showTitles: true, reservedSize: 32)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                scatterTouchData: ScatterTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    getTooltipItems: (spot) {
                      final student = _studentData.firstWhere(
                          (s) =>
                              spotter(s).x == spot.x && spotter(s).y == spot.y,
                          orElse: () => StudentStats(
                              studentName: '?',
                              attendancePercentage: 0,
                              trainingGamesCount: 0,
                              finalGrade: 0));
                      return ScatterTooltipItem(
                        '${student.studentName}\nX: ${spot.x.toStringAsFixed(1)}\nY: ${spot.y.toStringAsFixed(1)}',
                        textStyle:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistribution() {
    Map<String, int> distribution = {
      '0-9': 0,
      '10-13': 0,
      '14-16': 0,
      '17-20': 0
    };
    for (var s in _studentData) {
      if (s.finalGrade < 10)
        distribution['0-9'] = distribution['0-9']! + 1;
      else if (s.finalGrade < 14)
        distribution['10-13'] = distribution['10-13']! + 1;
      else if (s.finalGrade < 17)
        distribution['14-16'] = distribution['14-16']! + 1;
      else
        distribution['17-20'] = distribution['17-20']! + 1;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Distribuição de Notas',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (distribution.values.isEmpty
                            ? 1
                            : distribution.values
                                .reduce((a, b) => a > b ? a : b))
                        .toDouble() +
                    1,
                barGroups: [
                  _makeGroup(
                      0, distribution['0-9']!.toDouble(), Colors.redAccent),
                  _makeGroup(
                      1, distribution['10-13']!.toDouble(), Colors.amberAccent),
                  _makeGroup(
                      2, distribution['14-16']!.toDouble(), Colors.blueAccent),
                  _makeGroup(
                      3, distribution['17-20']!.toDouble(), Colors.greenAccent),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const labels = ['0-9', '10-13', '14-16', '17-20'];
                        return Text(labels[val.toInt()],
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 28)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 25,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

class StudentStats {
  final String studentName;
  final double attendancePercentage;
  final int trainingGamesCount;
  final double finalGrade;

  StudentStats({
    required this.studentName,
    required this.attendancePercentage,
    required this.trainingGamesCount,
    required this.finalGrade,
  });
}
