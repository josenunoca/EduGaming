class SurveyResponseSummary {
  final String id;
  final String questionnaireId;
  final DateTime generatedAt;

  /// Per-question quantitative data.
  /// Structure: { questionId: { optionOrValue: count } }
  final Map<String, Map<String, int>> quantitativeData;

  /// Per-question qualitative AI insights (for open-text questions).
  /// Structure: { questionId: "AI insight text" }
  final Map<String, String> qualitativeInsights;

  /// Overall satisfaction score (0.0 - 10.0), null if not applicable
  final double? overallSatisfactionScore;

  /// Key trends identified by AI
  final List<String> keyTrends;

  /// Total number of responses analysed
  final int totalResponses;

  /// Human-editable notes/interpretations added by admin
  final String humanNotes;

  /// Whether this report has been finalised and locked
  final bool isLocked;

  /// Timestamp when report was locked
  final DateTime? lockedAt;

  SurveyResponseSummary({
    required this.id,
    required this.questionnaireId,
    required this.generatedAt,
    this.quantitativeData = const {},
    this.qualitativeInsights = const {},
    this.overallSatisfactionScore,
    this.keyTrends = const [],
    this.totalResponses = 0,
    this.humanNotes = '',
    this.isLocked = false,
    this.lockedAt,
  });

  SurveyResponseSummary copyWith({
    String? id,
    String? questionnaireId,
    DateTime? generatedAt,
    Map<String, Map<String, int>>? quantitativeData,
    Map<String, String>? qualitativeInsights,
    double? overallSatisfactionScore,
    List<String>? keyTrends,
    int? totalResponses,
    String? humanNotes,
    bool? isLocked,
    DateTime? lockedAt,
  }) {
    return SurveyResponseSummary(
      id: id ?? this.id,
      questionnaireId: questionnaireId ?? this.questionnaireId,
      generatedAt: generatedAt ?? this.generatedAt,
      quantitativeData: quantitativeData ?? this.quantitativeData,
      qualitativeInsights: qualitativeInsights ?? this.qualitativeInsights,
      overallSatisfactionScore:
          overallSatisfactionScore ?? this.overallSatisfactionScore,
      keyTrends: keyTrends ?? this.keyTrends,
      totalResponses: totalResponses ?? this.totalResponses,
      humanNotes: humanNotes ?? this.humanNotes,
      isLocked: isLocked ?? this.isLocked,
      lockedAt: lockedAt ?? this.lockedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionnaireId': questionnaireId,
      'generatedAt': generatedAt.toIso8601String(),
      'quantitativeData': quantitativeData.map(
        (qId, counts) => MapEntry(qId, counts.map((k, v) => MapEntry(k, v))),
      ),
      'qualitativeInsights': qualitativeInsights,
      if (overallSatisfactionScore != null)
        'overallSatisfactionScore': overallSatisfactionScore,
      'keyTrends': keyTrends,
      'totalResponses': totalResponses,
      'humanNotes': humanNotes,
      'isLocked': isLocked,
      if (lockedAt != null) 'lockedAt': lockedAt!.toIso8601String(),
    };
  }

  factory SurveyResponseSummary.fromMap(Map<String, dynamic> map) {
    final rawQuant = map['quantitativeData'] as Map<String, dynamic>? ?? {};
    final quantitativeData = rawQuant.map((qId, rawCounts) {
      final counts = (rawCounts as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
      return MapEntry(qId, counts);
    });

    return SurveyResponseSummary(
      id: map['id'] ?? '',
      questionnaireId: map['questionnaireId'] ?? '',
      generatedAt: map['generatedAt'] != null
          ? DateTime.parse(map['generatedAt'])
          : DateTime.now(),
      quantitativeData: quantitativeData,
      qualitativeInsights: Map<String, String>.from(
          map['qualitativeInsights'] ?? {}),
      overallSatisfactionScore: map['overallSatisfactionScore'] != null
          ? (map['overallSatisfactionScore'] as num).toDouble()
          : null,
      keyTrends: List<String>.from(map['keyTrends'] ?? []),
      totalResponses: map['totalResponses'] ?? 0,
      humanNotes: map['humanNotes'] ?? '',
      isLocked: map['isLocked'] ?? false,
      lockedAt: map['lockedAt'] != null
          ? DateTime.parse(map['lockedAt'])
          : null,
    );
  }
}
