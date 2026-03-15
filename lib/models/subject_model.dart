class ModificationEntry {
  final String userId;
  final String userName;
  final String userRole;
  final DateTime timestamp;
  final String action;

  ModificationEntry({
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.timestamp,
    required this.action,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
    };
  }

  factory ModificationEntry.fromMap(Map<String, dynamic> map) {
    return ModificationEntry(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userRole: map['userRole'] ?? '',
      timestamp: DateTime.parse(
          map['timestamp'] ?? DateTime.now().toIso8601String()),
      action: map['action'] ?? '',
    );
  }
}

class Enrollment {
  final String id;
  final String userId;
  final String studentName;
  final String studentEmail;
  final String subjectId;
  final String institutionId;
  final String
      status; // 'pending_admin' | 'pending_teacher' | 'accepted' | 'rejected'
  final bool isSuspended;
  final bool isSealed;
  final double? finalGrade;
  final String? qualitativeGrade;
  final String? certificateUrl;
  final DateTime timestamp;

  Enrollment({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentEmail,
    required this.subjectId,
    required this.institutionId,
    required this.status,
    this.isSuspended = false,
    this.isSealed = false,
    this.finalGrade,
    this.qualitativeGrade,
    this.certificateUrl,
    required this.timestamp,
  });

  static String toQualitative(double grade) {
    if (grade < 5) return 'Mau';
    if (grade < 10) return 'Medíocre';
    if (grade < 14) return 'Suficiente';
    if (grade < 18) return 'Bom';
    return 'Muito Bom';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'subjectId': subjectId,
      'institutionId': institutionId,
      'status': status,
      'isSuspended': isSuspended,
      'isSealed': isSealed,
      if (finalGrade != null) 'finalGrade': finalGrade,
      if (qualitativeGrade != null) 'qualitativeGrade': qualitativeGrade,
      if (certificateUrl != null) 'certificateUrl': certificateUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Enrollment.fromMap(Map<String, dynamic> map) {
    return Enrollment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      subjectId: map['subjectId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      status: map['status'] ?? 'pending_admin',
      isSuspended: map['isSuspended'] ?? false,
      isSealed: map['isSealed'] ?? false,
      finalGrade: (map['finalGrade'] as num?)?.toDouble(),
      qualitativeGrade: map['qualitativeGrade'],
      certificateUrl: map['certificateUrl'],
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class EvaluationComponent {
  final String id;
  final String name;
  final double weight;
  final List<String> contentIds; // IDs of SubjectContent or GameContent
  final String? pin;
  final DateTime? startTime;
  final DateTime? endTime;

  EvaluationComponent({
    required this.id,
    required this.name,
    required this.weight,
    required this.contentIds,
    this.pin,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'contentIds': contentIds,
      if (pin != null) 'pin': pin,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
    };
  }

  factory EvaluationComponent.fromMap(Map<String, dynamic> map) {
    return EvaluationComponent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      weight: (map['weight'] as num? ?? 0.0).toDouble(),
      contentIds: List<String>.from(map['contentIds'] ?? []),
      pin: map['pin'],
      startTime:
          map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
    );
  }
}

class GameContent {
  final String id;
  final String name;
  final String url;
  final String
      type; // words, calculation, puzzle, platform, mobile_android, mobile_ios
  final double weight; // weight of this specific game/question in its category

  GameContent({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'weight': weight,
    };
  }

  factory GameContent.fromMap(Map<String, dynamic> map) {
    return GameContent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? 'general',
      weight: (map['weight'] as num? ?? 1.0).toDouble(),
    );
  }
}

class GameQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final double points;
  final int timeLimitSeconds;
  final List<String> allowedAnswerTypes;
  final String? evaluationCriteria;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'audio', 'video'
  final bool isDictation;

  GameQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.points,
    required this.timeLimitSeconds,
    this.allowedAnswerTypes = const ['options'],
    this.evaluationCriteria,
    this.mediaUrl,
    this.mediaType,
    this.isDictation = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'points': points,
      'timeLimitSeconds': timeLimitSeconds,
      'allowedAnswerTypes': allowedAnswerTypes,
      if (evaluationCriteria != null) 'evaluationCriteria': evaluationCriteria,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaType != null) 'mediaType': mediaType,
      'isDictation': isDictation,
    };
  }

  factory GameQuestion.fromMap(Map<String, dynamic> map) {
    return GameQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      points: (map['points'] as num? ?? 10.0).toDouble(),
      timeLimitSeconds: map['timeLimitSeconds'] ?? 20,
      allowedAnswerTypes:
          List<String>.from(map['allowedAnswerTypes'] ?? ['options']),
      evaluationCriteria: map['evaluationCriteria'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      isDictation: map['isDictation'] ?? false,
    );
  }
}

class AiGame {
  final String id;
  final String title;
  final List<GameQuestion> questions;
  final String type; // 'kahoot', 'quiz', 'flashcards', 'jigsaw', 'memory'
  final bool isAssessment; // if true, counts for evaluation
  final String subjectId;
  final List<String> sourceContentIds;
  final String? imageUrl;
  final Map<String, dynamic>? settings;
  final String? pin;

  AiGame({
    required this.id,
    required this.title,
    required this.questions,
    required this.type,
    required this.isAssessment,
    required this.subjectId,
    required this.sourceContentIds,
    this.imageUrl,
    this.settings,
    this.pin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'questions': questions.map((q) => q.toMap()).toList(),
      'type': type,
      'isAssessment': isAssessment,
      'subjectId': subjectId,
      'sourceContentIds': sourceContentIds,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (settings != null) 'settings': settings,
      if (pin != null) 'pin': pin,
    };
  }

  factory AiGame.fromMap(Map<String, dynamic> map) {
    return AiGame(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      questions: (map['questions'] as List? ?? [])
          .map((q) => GameQuestion.fromMap(q))
          .toList(),
      type: map['type'] ?? 'kahoot',
      isAssessment: map['isAssessment'] ?? false,
      subjectId: map['subjectId'] ?? '',
      sourceContentIds: List<String>.from(map['sourceContentIds'] ?? []),
      imageUrl: map['imageUrl'],
      settings: map['settings'] != null
          ? Map<String, dynamic>.from(map['settings'])
          : null,
      pin: map['pin'],
    );
  }
}

class SubjectContent {
  final String id;
  final String name;
  final String url;
  final String
      type; // gamma, image, video, audio, spreadsheet, ai_comment, document
  final String category; // 'support' | 'exam' | 'game'
  final double weight; // weight if it's exam or game
  final List<ModificationEntry> modificationLog;

  SubjectContent({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.category = 'support',
    this.weight = 0.0,
    this.modificationLog = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'category': category,
      'weight': weight,
      'modificationLog': modificationLog.map((e) => e.toMap()).toList(),
    };
  }

  factory SubjectContent.fromMap(Map<String, dynamic> map) {
    return SubjectContent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? 'file',
      category: map['category'] ?? 'support',
      weight: (map['weight'] as num? ?? 0.0).toDouble(),
      modificationLog: (map['modificationLog'] as List? ?? [])
          .map((e) => ModificationEntry.fromMap(e))
          .toList(),
    );
  }
}

class SyllabusSession {
  final String id;
  final int sessionNumber;
  final String topic;
  final DateTime date;
  final List<String> materialIds; // IDs from SubjectContent
  final String bibliography;
  final String? proposedSummary;
  final String? finalSummary;
  final bool isFinalized;
  final String? startTime; // HH:mm
  final String? endTime; // HH:mm
  final List<ModificationEntry> modificationLog;

  SyllabusSession({
    required this.id,
    required this.sessionNumber,
    required this.topic,
    required this.date,
    required this.materialIds,
    required this.bibliography,
    this.proposedSummary,
    this.finalSummary,
    this.isFinalized = false,
    this.startTime,
    this.endTime,
    this.modificationLog = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionNumber': sessionNumber,
      'topic': topic,
      'date': date.toIso8601String(),
      'materialIds': materialIds,
      'bibliography': bibliography,
      if (proposedSummary != null) 'proposedSummary': proposedSummary,
      if (finalSummary != null) 'finalSummary': finalSummary,
      'isFinalized': isFinalized,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'modificationLog': modificationLog.map((e) => e.toMap()).toList(),
    };
  }

  factory SyllabusSession.fromMap(Map<String, dynamic> map) {
    return SyllabusSession(
      id: map['id'] ?? '',
      sessionNumber: map['sessionNumber'] ?? 0,
      topic: map['topic'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      materialIds: List<String>.from(map['materialIds'] ?? []),
      bibliography: map['bibliography'] ?? '',
      proposedSummary: map['proposedSummary'],
      finalSummary: map['finalSummary'],
      isFinalized: map['isFinalized'] ?? false,
      startTime: map['startTime'],
      endTime: map['endTime'],
      modificationLog: (map['modificationLog'] as List? ?? [])
          .map((e) => ModificationEntry.fromMap(e))
          .toList(),
    );
  }
}

enum PautaStatus { draft, finalized, sealed }

enum SyllabusStatus { provisional, inValidationScientific, inValidationPedagogical, approved }

class Subject {
  final String id;
  final String name;
  final String level;
  final String academicYear; // e.g., "2023/2024"
  final String teacherId;
  final String institutionId;
  final List<String> allowedStudentEmails;
  final List<SubjectContent> contents;
  final List<GameContent> games;
  final List<EvaluationComponent> evaluationComponents;
  final String? scientificArea;
  final String? programDescription;
  final PautaStatus pautaStatus;
  final double teachingHours; // Legacy
  final double nonTeachingHours; // Legacy
  final DateTime? sealedAt;
  final String? sealedBy;
  final List<SyllabusSession> sessions;

  // New Academic Fields (Detailed Hours)
  final double theoreticalHours;
  final double theoreticalPracticalHours;
  final double practicalHours;
  final double otherHours;
  final double ects;
  final SyllabusStatus syllabusStatus;
  
  // Approval Info
  final DateTime? scientificApprovalDate;
  final String? scientificApprovedBy;
  final DateTime? pedagogicalApprovalDate;
  final String? pedagogicalApprovedBy;
  final List<String> pedagogicalSignatures;
  final String? syllabusFileUrl;

  // Marketplace & Revenue
  final double price;
  final String currency;
  final bool isMarketplaceEnabled;

  Subject({
    required this.id,
    required this.name,
    required this.level,
    required this.academicYear,
    required this.teacherId,
    required this.institutionId,
    required this.allowedStudentEmails,
    required this.contents,
    required this.games,
    this.evaluationComponents = const [],
    this.scientificArea,
    this.programDescription,
    this.pautaStatus = PautaStatus.draft,
    this.teachingHours = 0.0,
    this.nonTeachingHours = 0.0,
    this.sealedAt,
    this.sealedBy,
    this.sessions = const [],
    this.price = 0.0,
    this.currency = 'EUR',
    this.isMarketplaceEnabled = false,
    this.theoreticalHours = 0.0,
    this.theoreticalPracticalHours = 0.0,
    this.practicalHours = 0.0,
    this.otherHours = 0.0,
    this.ects = 0.0,
    this.syllabusStatus = SyllabusStatus.provisional,
    this.scientificApprovalDate,
    this.scientificApprovedBy,
    this.pedagogicalApprovalDate,
    this.pedagogicalApprovedBy,
    this.pedagogicalSignatures = const [],
    this.syllabusFileUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'academicYear': academicYear,
      'teacherId': teacherId,
      'institutionId': institutionId,
      'allowedStudentEmails': allowedStudentEmails,
      'contents': contents.map((e) => e.toMap()).toList(),
      'games': games.map((e) => e.toMap()).toList(),
      'evaluationComponents':
          evaluationComponents.map((e) => e.toMap()).toList(),
      'scientificArea': scientificArea,
      'programDescription': programDescription,
      'pautaStatus': pautaStatus.name,
      'teachingHours': teachingHours,
      'nonTeachingHours': nonTeachingHours,
      if (sealedAt != null) 'sealedAt': sealedAt!.toIso8601String(),
      if (sealedBy != null) 'sealedBy': sealedBy,
      'sessions': sessions.map((e) => e.toMap()).toList(),
      'price': price,
      'currency': currency,
      'isMarketplaceEnabled': isMarketplaceEnabled,
      'theoreticalHours': theoreticalHours,
      'theoreticalPracticalHours': theoreticalPracticalHours,
      'practicalHours': practicalHours,
      'otherHours': otherHours,
      'ects': ects,
      'syllabusStatus': syllabusStatus.name,
      if (scientificApprovalDate != null)
        'scientificApprovalDate': scientificApprovalDate!.toIso8601String(),
      if (scientificApprovedBy != null)
        'scientificApprovedBy': scientificApprovedBy,
      if (pedagogicalApprovalDate != null)
        'pedagogicalApprovalDate': pedagogicalApprovalDate!.toIso8601String(),
      if (pedagogicalApprovedBy != null)
        'pedagogicalApprovedBy': pedagogicalApprovedBy,
      'pedagogicalSignatures': pedagogicalSignatures,
      if (syllabusFileUrl != null) 'syllabusFileUrl': syllabusFileUrl,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      level: map['level'] ?? '',
      academicYear: map['academicYear'] ?? '2023/2024',
      teacherId: map['teacherId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      allowedStudentEmails:
          List<String>.from(map['allowedStudentEmails'] ?? []),
      contents: (map['contents'] as List? ?? [])
          .map((e) => SubjectContent.fromMap(e))
          .toList(),
      games: (map['games'] as List? ?? [])
          .map((e) => GameContent.fromMap(e))
          .toList(),
      evaluationComponents: (map['evaluationComponents'] as List? ?? [])
          .map((e) => EvaluationComponent.fromMap(e))
          .toList(),
      scientificArea: map['scientificArea'],
      programDescription: map['programDescription'],
      pautaStatus: PautaStatus.values.firstWhere(
        (e) => e.name == (map['pautaStatus'] ?? 'draft'),
        orElse: () => PautaStatus.draft,
      ),
      teachingHours: (map['teachingHours'] as num? ?? 0.0).toDouble(),
      nonTeachingHours: (map['nonTeachingHours'] as num? ?? 0.0).toDouble(),
      sealedAt:
          map['sealedAt'] != null ? DateTime.parse(map['sealedAt']) : null,
      sealedBy: map['sealedBy'],
      sessions: (map['sessions'] as List? ?? [])
          .map((e) => SyllabusSession.fromMap(e))
          .toList(),
      price: (map['price'] as num? ?? 0.0).toDouble(),
      currency: map['currency'] ?? 'EUR',
      isMarketplaceEnabled: map['isMarketplaceEnabled'] ?? false,
      theoreticalHours: (map['theoreticalHours'] as num? ?? 0.0).toDouble(),
      theoreticalPracticalHours:
          (map['theoreticalPracticalHours'] as num? ?? 0.0).toDouble(),
      practicalHours: (map['practicalHours'] as num? ?? 0.0).toDouble(),
      otherHours: (map['otherHours'] as num? ?? 0.0).toDouble(),
      ects: (map['ects'] as num? ?? 0.0).toDouble(),
      syllabusStatus: SyllabusStatus.values.firstWhere(
        (e) => e.name == (map['syllabusStatus'] ?? 'provisional'),
        orElse: () => SyllabusStatus.provisional,
      ),
      scientificApprovalDate: map['scientificApprovalDate'] != null
          ? DateTime.parse(map['scientificApprovalDate'])
          : null,
      scientificApprovedBy: map['scientificApprovedBy'],
      pedagogicalApprovalDate: map['pedagogicalApprovalDate'] != null
          ? DateTime.parse(map['pedagogicalApprovalDate'])
          : null,
      pedagogicalApprovedBy: map['pedagogicalApprovedBy'],
      pedagogicalSignatures:
          List<String>.from(map['pedagogicalSignatures'] ?? []),
      syllabusFileUrl: map['syllabusFileUrl'],
    );
  }
}

class AiGameResult {
  final String id;
  final String gameId;
  final String studentId;
  final String studentName; // Added to avoid extra queries in ranking
  final String subjectId;
  final double score;
  final List<int> correctAnswers; // Indices of questions answered correctly
  final List<int> incorrectAnswers; // Indices of questions answered incorrectly
  final Map<int, int>
      selectedOptions; // New field: question index -> selected option index
  final Map<int, Map<String, dynamic>>
      studentResponses; // questionIndex -> { 'type': 'text'|'audio'|'image', 'value': 'text'|'url' }
  final Map<int, Map<String, dynamic>>
      aiGradingDetails; // questionIndex -> { 'suggestedScore': 8.5, 'reasoning': '...' }
  final Map<int, double> teacherAdjustments; // questionIndex -> score
  final DateTime playedAt;
  final bool isEvaluation; // New field to distinguish mode

  AiGameResult({
    required this.id,
    required this.gameId,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.score,
    required this.correctAnswers,
    required this.incorrectAnswers,
    this.selectedOptions = const {},
    this.studentResponses =
        const {}, // questionIndex -> { 'type': 'text'|'audio'|'image', 'value': 'text'|'url' }
    this.aiGradingDetails =
        const {}, // questionIndex -> { 'suggestedScore': 8.5, 'reasoning': '...' }
    this.teacherAdjustments = const {}, // questionIndex -> score
    required this.playedAt,
    this.isEvaluation = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'score': score,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'selectedOptions':
          selectedOptions.map((k, v) => MapEntry(k.toString(), v)),
      'studentResponses':
          studentResponses.map((k, v) => MapEntry(k.toString(), v)),
      'aiGradingDetails':
          aiGradingDetails.map((k, v) => MapEntry(k.toString(), v)),
      'teacherAdjustments':
          teacherAdjustments.map((k, v) => MapEntry(k.toString(), v)),
      'playedAt': playedAt.toIso8601String(),
      'isEvaluation': isEvaluation,
    };
  }

  factory AiGameResult.fromMap(Map<String, dynamic> map) {
    return AiGameResult(
      id: map['id'] ?? '',
      gameId: map['gameId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? 'Aluno desconhecido',
      subjectId: map['subjectId'] ?? '',
      score: (map['score'] as num? ?? 0.0).toDouble(),
      correctAnswers: List<int>.from(map['correctAnswers'] ?? []),
      incorrectAnswers: List<int>.from(map['incorrectAnswers'] ?? []),
      selectedOptions: Map<int, int>.from(
        (map['selectedOptions'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.parse(k.toString()), v as int),
        ),
      ),
      studentResponses: (map['studentResponses'] as Map? ?? {}).map(
        (k, v) =>
            MapEntry(int.parse(k.toString()), Map<String, dynamic>.from(v)),
      ),
      aiGradingDetails: (map['aiGradingDetails'] as Map? ?? {}).map(
        (k, v) =>
            MapEntry(int.parse(k.toString()), Map<String, dynamic>.from(v)),
      ),
      teacherAdjustments: (map['teacherAdjustments'] as Map? ?? {}).map(
        (k, v) => MapEntry(int.parse(k.toString()), (v as num).toDouble()),
      ),
      playedAt: map['playedAt'] != null
          ? DateTime.parse(map['playedAt'])
          : DateTime.now(),
      isEvaluation: map['isEvaluation'] ?? false,
    );
  }
}

class AiGameStats {
  final String gameId;
  final int playCount;
  final double maxScore;

  AiGameStats({
    required this.gameId,
    required this.playCount,
    required this.maxScore,
  });
}

class QuestionStat {
  final String questionText;
  final int correctCount;
  final int incorrectCount;
  final double percentage;

  QuestionStat({
    required this.questionText,
    required this.correctCount,
    required this.incorrectCount,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'percentage': percentage,
    };
  }

  factory QuestionStat.fromMap(Map<String, dynamic> map) {
    return QuestionStat(
      questionText: map['questionText'] ?? '',
      correctCount: map['correctCount'] ?? 0,
      incorrectCount: map['incorrectCount'] ?? 0,
      percentage: (map['percentage'] as num? ?? 0.0).toDouble(),
    );
  }
}

class AdvancedScoreStats {
  final double average;
  final double median;
  final List<double> modes;
  final double min;
  final double max;
  final double q1;
  final double q3;
  final List<int> histogramBins;
  final int totalParticipants;
  final List<QuestionStat> questionStats;
  final List<QuestionStat> topQuestions;
  final List<QuestionStat> bottomQuestions;
  final List<AiGameResult>? topStudents;
  final List<AiGameResult>? bottomStudents;

  AdvancedScoreStats({
    required this.average,
    required this.median,
    required this.modes,
    required this.min,
    required this.max,
    required this.q1,
    required this.q3,
    required this.histogramBins,
    required this.totalParticipants,
    this.questionStats = const [],
    this.topQuestions = const [],
    this.bottomQuestions = const [],
    this.topStudents,
    this.bottomStudents,
  });

  Map<String, dynamic> toMap() {
    return {
      'average': average,
      'median': median,
      'modes': modes,
      'min': min,
      'max': max,
      'q1': q1,
      'q3': q3,
      'histogramBins': histogramBins,
      'totalParticipants': totalParticipants,
      'questionStats': questionStats.map((e) => e.toMap()).toList(),
      'topQuestions': topQuestions.map((e) => e.toMap()).toList(),
      'bottomQuestions': bottomQuestions.map((e) => e.toMap()).toList(),
      if (topStudents != null)
        'topStudents': topStudents!.map((e) => e.toMap()).toList(),
      if (bottomStudents != null)
        'bottomStudents': bottomStudents!.map((e) => e.toMap()).toList(),
    };
  }

  factory AdvancedScoreStats.fromMap(Map<String, dynamic> map) {
    return AdvancedScoreStats(
      average: (map['average'] as num? ?? 0.0).toDouble(),
      median: (map['median'] as num? ?? 0.0).toDouble(),
      modes: List<double>.from(
          (map['modes'] as List? ?? []).map((e) => (e as num).toDouble())),
      min: (map['min'] as num? ?? 0.0).toDouble(),
      max: (map['max'] as num? ?? 0.0).toDouble(),
      q1: (map['q1'] as num? ?? 0.0).toDouble(),
      q3: (map['q3'] as num? ?? 0.0).toDouble(),
      histogramBins: List<int>.from(map['histogramBins'] ?? []),
      totalParticipants: map['totalParticipants'] ?? 0,
      questionStats: (map['questionStats'] as List? ?? [])
          .map((e) => QuestionStat.fromMap(e))
          .toList(),
      topQuestions: (map['topQuestions'] as List? ?? [])
          .map((e) => QuestionStat.fromMap(e))
          .toList(),
      bottomQuestions: (map['bottomQuestions'] as List? ?? [])
          .map((e) => QuestionStat.fromMap(e))
          .toList(),
      topStudents: (map['topStudents'] as List?)
          ?.map((e) => AiGameResult.fromMap(e))
          .toList(),
      bottomStudents: (map['bottomStudents'] as List?)
          ?.map((e) => AiGameResult.fromMap(e))
          .toList(),
    );
  }
}

class StudentGradeAdjustment {
  final String id;
  final String studentId;
  final String subjectId;
  final double? finalGradeOverride;
  final Map<String, double>
      componentOverrides; // componentId -> value (0-20 scale)
  final String? notes;

  StudentGradeAdjustment({
    required this.id,
    required this.studentId,
    required this.subjectId,
    this.finalGradeOverride,
    this.componentOverrides = const {},
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'subjectId': subjectId,
      if (finalGradeOverride != null) 'finalGradeOverride': finalGradeOverride,
      'componentOverrides': componentOverrides,
      if (notes != null) 'notes': notes,
    };
  }

  factory StudentGradeAdjustment.fromMap(Map<String, dynamic> map) {
    return StudentGradeAdjustment(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      finalGradeOverride: (map['finalGradeOverride'] as num?)?.toDouble(),
      componentOverrides: Map<String, double>.from(
        (map['componentOverrides'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      notes: map['notes'],
    );
  }
}

class ExamSession {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String gameId;
  final String status; // 'active', 'abandoned', 'completed'
  final bool authorizedReentry;
  final double currentScore;
  final int currentQuestionIndex;
  final DateTime startTime;
  final DateTime lastHeartbeat;

  ExamSession({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.gameId,
    required this.status,
    this.authorizedReentry = false,
    this.currentScore = 0.0,
    this.currentQuestionIndex = 0,
    required this.startTime,
    required this.lastHeartbeat,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'subjectId': subjectId,
      'gameId': gameId,
      'status': status,
      'authorizedReentry': authorizedReentry,
      'currentScore': currentScore,
      'currentQuestionIndex': currentQuestionIndex,
      'startTime': startTime.toIso8601String(),
      'lastHeartbeat': lastHeartbeat.toIso8601String(),
    };
  }

  factory ExamSession.fromMap(Map<String, dynamic> map) {
    return ExamSession(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      subjectId: map['subjectId'] ?? '',
      gameId: map['gameId'] ?? '',
      status: map['status'] ?? 'active',
      authorizedReentry: map['authorizedReentry'] ?? false,
      currentScore: (map['currentScore'] as num? ?? 0.0).toDouble(),
      currentQuestionIndex: map['currentQuestionIndex'] ?? 0,
      startTime:
          DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      lastHeartbeat: DateTime.parse(
          map['lastHeartbeat'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Attendance {
  final String id;
  final String userId;
  final String userName;
  final String subjectId;
  final String sessionId;
  final DateTime timestamp;

  Attendance({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subjectId,
    required this.sessionId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'subjectId': subjectId,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      subjectId: map['subjectId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
