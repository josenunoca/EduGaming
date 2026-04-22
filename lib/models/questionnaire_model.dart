enum QuestionType {
  text,
  singleChoice,
  multipleChoice,
  likertScale,
  openText,
  // Legacy support
  selection,
  audio,
  video,
}

enum SurveyObjective {
  performanceEvaluation,
  equipmentEvaluation,
  programEvaluation,
  satisfactionClients,
  satisfactionCollaborators,
  custom,
}

enum SurveyAudience {
  students,
  parents,
  teachers,
  nonTeachingStaff,
  externalEmail,
}

enum SurveyStatus {
  draft,
  active,
  closed,
  locked,
}

enum SurveyVisibility {
  directionOnly,
  departments,
  publicAccess,
}

extension SurveyObjectiveLabel on SurveyObjective {
  String get label {
    switch (this) {
      case SurveyObjective.performanceEvaluation:
        return 'Avaliação de Desempenho de Colaboradores';
      case SurveyObjective.equipmentEvaluation:
        return 'Avaliação de Equipamentos e Infraestruturas';
      case SurveyObjective.programEvaluation:
        return 'Avaliação de Programas, Projetos ou Atividades';
      case SurveyObjective.satisfactionClients:
        return 'Grau de Satisfação (Clientes/Utentes)';
      case SurveyObjective.satisfactionCollaborators:
        return 'Grau de Satisfação (Colaboradores)';
      case SurveyObjective.custom:
        return 'Objetivo Personalizado';
    }
  }
}

extension SurveyAudienceLabel on SurveyAudience {
  String get label {
    switch (this) {
      case SurveyAudience.students:
        return 'Alunos';
      case SurveyAudience.parents:
        return 'Encarregados de Educação';
      case SurveyAudience.teachers:
        return 'Pessoal Docente';
      case SurveyAudience.nonTeachingStaff:
        return 'Pessoal Não Docente';
      case SurveyAudience.externalEmail:
        return 'Emails Externos';
    }
  }
}

class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String> options;
  final int? likertMin;
  final int? likertMax;
  final String? likertMinLabel;
  final String? likertMaxLabel;
  final bool isRequired;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    this.likertMin = 1,
    this.likertMax = 5,
    this.likertMinLabel,
    this.likertMaxLabel,
    this.isRequired = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'options': options,
      if (likertMin != null) 'likertMin': likertMin,
      if (likertMax != null) 'likertMax': likertMax,
      if (likertMinLabel != null) 'likertMinLabel': likertMinLabel,
      if (likertMaxLabel != null) 'likertMaxLabel': likertMaxLabel,
      'isRequired': isRequired,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      type: QuestionType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => QuestionType.text),
      options: List<String>.from(map['options'] ?? []),
      likertMin: map['likertMin'] ?? 1,
      likertMax: map['likertMax'] ?? 5,
      likertMinLabel: map['likertMinLabel'],
      likertMaxLabel: map['likertMaxLabel'],
      isRequired: map['isRequired'] ?? true,
    );
  }

  Question copyWith({
    String? id,
    String? text,
    QuestionType? type,
    List<String>? options,
    int? likertMin,
    int? likertMax,
    String? likertMinLabel,
    String? likertMaxLabel,
    bool? isRequired,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      options: options ?? this.options,
      likertMin: likertMin ?? this.likertMin,
      likertMax: likertMax ?? this.likertMax,
      likertMinLabel: likertMinLabel ?? this.likertMinLabel,
      likertMaxLabel: likertMaxLabel ?? this.likertMaxLabel,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}

class ReopenLog {
  final DateTime startDate;
  final DateTime endDate;
  final String reason;

  ReopenLog({
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
    };
  }

  factory ReopenLog.fromMap(Map<String, dynamic> map) {
    return ReopenLog(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      reason: map['reason'] ?? '',
    );
  }
}

class Questionnaire {
  final String id;
  final String title;
  final String description;
  final List<Question> questions;
  final String institutionId;

  // Creator info
  final String creatorId;
  final String creatorRole; // 'institution' or 'teacher'
  final String? subjectId; // when created by a teacher for a subject

  // Targeting
  final List<String> targetRoles; // legacy + ['student', 'teacher', 'parent', 'nonTeachingStaff']
  final List<SurveyAudience> audiences;
  final List<String> individualTargetIds;
  final List<String> externalEmails; // external email addresses

  // Configuration
  final List<SurveyObjective> objectives;
  final String? customObjective;
  final String? legalBasis; // fundamentação legal/institucional
  final bool linkedToAnnualReport;

  // Lifecycle
  final DateTime startDate;
  final DateTime endDate;
  final SurveyStatus status;
  final bool isActive; // legacy/compat

  // Analysis
  final SurveyVisibility visibility;
  final bool isReportLocked;
  final String? humanNotes;

  // Other
  final bool isSensitive;
  final List<ReopenLog> reopenHistory;

  Questionnaire({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.institutionId,
    required this.creatorId,
    this.creatorRole = 'institution',
    this.subjectId,
    this.targetRoles = const [],
    this.audiences = const [],
    this.individualTargetIds = const [],
    this.externalEmails = const [],
    this.objectives = const [],
    this.customObjective,
    this.legalBasis,
    this.linkedToAnnualReport = false,
    required this.startDate,
    required this.endDate,
    this.status = SurveyStatus.draft,
    this.isActive = false,
    this.visibility = SurveyVisibility.directionOnly,
    this.isReportLocked = false,
    this.humanNotes,
    this.isSensitive = false,
    this.reopenHistory = const [],
  });

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return status == SurveyStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toMap()).toList(),
      'institutionId': institutionId,
      'creatorId': creatorId,
      'creatorRole': creatorRole,
      if (subjectId != null) 'subjectId': subjectId,
      'targetRoles': targetRoles,
      'audiences': audiences.map((a) => a.name).toList(),
      'individualTargetIds': individualTargetIds,
      'externalEmails': externalEmails,
      'objectives': objectives.map((o) => o.name).toList(),
      if (customObjective != null) 'customObjective': customObjective,
      if (legalBasis != null) 'legalBasis': legalBasis,
      'linkedToAnnualReport': linkedToAnnualReport,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.name,
      'isActive': isActive,
      'visibility': visibility.name,
      'isReportLocked': isReportLocked,
      if (humanNotes != null) 'humanNotes': humanNotes,
      'isSensitive': isSensitive,
      'reopenHistory': reopenHistory.map((h) => h.toMap()).toList(),
    };
  }

  factory Questionnaire.fromMap(Map<String, dynamic> map) {
    return Questionnaire(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      questions: (map['questions'] as List?)
              ?.map((q) => Question.fromMap(q))
              .toList() ??
          [],
      institutionId: map['institutionId'] ?? '',
      creatorId: map['creatorId'] ?? '',
      creatorRole: map['creatorRole'] ?? 'institution',
      subjectId: map['subjectId'],
      targetRoles: List<String>.from(map['targetRoles'] ?? []),
      audiences: (map['audiences'] as List?)
              ?.map((a) => SurveyAudience.values.firstWhere(
                  (e) => e.name == a,
                  orElse: () => SurveyAudience.students))
              .toList() ??
          [],
      individualTargetIds:
          List<String>.from(map['individualTargetIds'] ?? []),
      externalEmails: List<String>.from(map['externalEmails'] ?? []),
      objectives: (map['objectives'] as List?)
              ?.map((o) => SurveyObjective.values.firstWhere(
                  (e) => e.name == o,
                  orElse: () => SurveyObjective.custom))
              .toList() ??
          [],
      customObjective: map['customObjective'],
      legalBasis: map['legalBasis'],
      linkedToAnnualReport: map['linkedToAnnualReport'] ?? false,
      startDate: DateTime.parse(
          map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['endDate'] ??
          DateTime.now().add(const Duration(days: 30)).toIso8601String()),
      status: SurveyStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => SurveyStatus.draft),
      isActive: map['isActive'] ?? false,
      visibility: SurveyVisibility.values.firstWhere(
          (e) => e.name == map['visibility'],
          orElse: () => SurveyVisibility.directionOnly),
      isReportLocked: map['isReportLocked'] ?? false,
      humanNotes: map['humanNotes'],
      isSensitive: map['isSensitive'] ?? false,
      reopenHistory: (map['reopenHistory'] as List?)
              ?.map((h) => ReopenLog.fromMap(h))
              .toList() ??
          [],
    );
  }

  Questionnaire copyWith({
    String? id,
    String? title,
    String? description,
    List<Question>? questions,
    String? institutionId,
    String? creatorId,
    String? creatorRole,
    String? subjectId,
    List<String>? targetRoles,
    List<SurveyAudience>? audiences,
    List<String>? individualTargetIds,
    List<String>? externalEmails,
    List<SurveyObjective>? objectives,
    String? customObjective,
    String? legalBasis,
    bool? linkedToAnnualReport,
    DateTime? startDate,
    DateTime? endDate,
    SurveyStatus? status,
    bool? isActive,
    SurveyVisibility? visibility,
    bool? isReportLocked,
    String? humanNotes,
    bool? isSensitive,
    List<ReopenLog>? reopenHistory,
  }) {
    return Questionnaire(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      institutionId: institutionId ?? this.institutionId,
      creatorId: creatorId ?? this.creatorId,
      creatorRole: creatorRole ?? this.creatorRole,
      subjectId: subjectId ?? this.subjectId,
      targetRoles: targetRoles ?? this.targetRoles,
      audiences: audiences ?? this.audiences,
      individualTargetIds: individualTargetIds ?? this.individualTargetIds,
      externalEmails: externalEmails ?? this.externalEmails,
      objectives: objectives ?? this.objectives,
      customObjective: customObjective ?? this.customObjective,
      legalBasis: legalBasis ?? this.legalBasis,
      linkedToAnnualReport: linkedToAnnualReport ?? this.linkedToAnnualReport,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      visibility: visibility ?? this.visibility,
      isReportLocked: isReportLocked ?? this.isReportLocked,
      humanNotes: humanNotes ?? this.humanNotes,
      isSensitive: isSensitive ?? this.isSensitive,
      reopenHistory: reopenHistory ?? this.reopenHistory,
    );
  }
}

class QuestionnaireResponse {
  final String id;
  final String userId;
  final String questionnaireId;
  final Map<String, dynamic> answers; // questionId: answer
  final DateTime timestamp;
  final bool consentToSpecialist;
  final DateTime? rgpdConsentDate;
  final bool isAnonymous;

  QuestionnaireResponse({
    required this.id,
    required this.userId,
    required this.questionnaireId,
    required this.answers,
    required this.timestamp,
    this.consentToSpecialist = false,
    this.rgpdConsentDate,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'questionnaireId': questionnaireId,
      'answers': answers,
      'timestamp': timestamp.toIso8601String(),
      'consentToSpecialist': consentToSpecialist,
      if (rgpdConsentDate != null)
        'rgpdConsentDate': rgpdConsentDate!.toIso8601String(),
      'isAnonymous': isAnonymous,
    };
  }

  factory QuestionnaireResponse.fromMap(Map<String, dynamic> map) {
    return QuestionnaireResponse(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      questionnaireId: map['questionnaireId'] ?? '',
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      timestamp: DateTime.parse(map['timestamp']),
      consentToSpecialist: map['consentToSpecialist'] ?? false,
      rgpdConsentDate: map['rgpdConsentDate'] != null
          ? DateTime.parse(map['rgpdConsentDate'])
          : null,
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }
}
