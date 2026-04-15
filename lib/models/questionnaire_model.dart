enum QuestionType { text, selection, audio, video }

class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<String> options;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'options': options,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      type: QuestionType.values.firstWhere((e) => e.name == map['type'],
          orElse: () => QuestionType.text),
      options: List<String>.from(map['options'] ?? []),
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
  final List<String> targetRoles; // ['student', 'teacher']
  final List<String> individualTargetIds;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool isSensitive;
  final List<ReopenLog> reopenHistory;

  Questionnaire({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    required this.institutionId,
    required this.targetRoles,
    this.individualTargetIds = const [],
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.isSensitive = false,
    this.reopenHistory = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toMap()).toList(),
      'institutionId': institutionId,
      'targetRoles': targetRoles,
      'individualTargetIds': individualTargetIds,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
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
      targetRoles: List<String>.from(map['targetRoles'] ?? []),
      individualTargetIds: List<String>.from(map['individualTargetIds'] ?? []),
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      isActive: map['isActive'] ?? true,
      isSensitive: map['isSensitive'] ?? false,
      reopenHistory: (map['reopenHistory'] as List?)
              ?.map((h) => ReopenLog.fromMap(h))
              .toList() ??
          [],
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

  QuestionnaireResponse({
    required this.id,
    required this.userId,
    required this.questionnaireId,
    required this.answers,
    required this.timestamp,
    this.consentToSpecialist = false,
    this.rgpdConsentDate,
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
    );
  }
}
