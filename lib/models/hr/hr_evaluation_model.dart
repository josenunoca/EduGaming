import 'package:cloud_firestore/cloud_firestore.dart';

class HRPerformanceEvaluation {
  final String id;
  final String employeeId;
  final String employeeName;
  final String institutionId;
  final DateTime date;
  final double attendanceScore; // 0.0 - 10.0 (Auto-calculated)
  final double technicalScore;
  final double behaviorScore;
  final String feedback;
  final String evaluatorId;
  final Map<String, dynamic> customMetrics;

  HRPerformanceEvaluation({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.institutionId,
    required this.date,
    this.attendanceScore = 10.0,
    this.technicalScore = 0.0,
    this.behaviorScore = 0.0,
    this.feedback = '',
    required this.evaluatorId,
    this.customMetrics = const {},
  });

  double get finalScore => (attendanceScore + technicalScore + behaviorScore) / 3.0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'institutionId': institutionId,
    'date': Timestamp.fromDate(date),
    'attendanceScore': attendanceScore,
    'technicalScore': technicalScore,
    'behaviorScore': behaviorScore,
    'feedback': feedback,
    'evaluatorId': evaluatorId,
    'customMetrics': customMetrics,
  };

  factory HRPerformanceEvaluation.fromMap(Map<String, dynamic> map) => HRPerformanceEvaluation(
    id: map['id'],
    employeeId: map['employeeId'],
    employeeName: map['employeeName'] ?? '',
    institutionId: map['institutionId'],
    date: (map['date'] as Timestamp).toDate(),
    attendanceScore: (map['attendanceScore'] as num?)?.toDouble() ?? 10.0,
    technicalScore: (map['technicalScore'] as num?)?.toDouble() ?? 0.0,
    behaviorScore: (map['behaviorScore'] as num?)?.toDouble() ?? 0.0,
    feedback: map['feedback'] ?? '',
    evaluatorId: map['evaluatorId'],
    customMetrics: Map<String, dynamic>.from(map['customMetrics'] ?? {}),
  );
}

class HRTraining {
  final String id;
  final String title;
  final String institutionId;
  final List<String> attendeeIds;
  final DateTime date;
  final double durationHours;
  final String provider;
  final String evaluationReport;
  final String status; // proposed, approved, completed

  HRTraining({
    required this.id,
    required this.title,
    required this.institutionId,
    this.attendeeIds = const [],
    required this.date,
    this.durationHours = 0.0,
    this.provider = '',
    this.evaluationReport = '',
    this.status = 'proposed',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'institutionId': institutionId,
    'attendeeIds': attendeeIds,
    'date': Timestamp.fromDate(date),
    'durationHours': durationHours,
    'provider': provider,
    'evaluationReport': evaluationReport,
    'status': status,
  };

  factory HRTraining.fromMap(Map<String, dynamic> map) => HRTraining(
    id: map['id'],
    title: map['title'],
    institutionId: map['institutionId'],
    attendeeIds: List<String>.from(map['attendeeIds'] ?? []),
    date: (map['date'] as Timestamp).toDate(),
    durationHours: (map['durationHours'] as num?)?.toDouble() ?? 0.0,
    provider: map['provider'] ?? '',
    evaluationReport: map['evaluationReport'] ?? '',
    status: map['status'] ?? 'proposed',
  );
}
