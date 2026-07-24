import 'activity_model.dart';

class MarketingEvent {
  final String id;
  final String title;
  final String description;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String marketingGroup; // Replaces activityGroup
  final String academicYear;
  final bool hasFinancialImpact;
  final List<ActivityResource> resources;
  final List<ActivityParticipant> participants;
  final List<ActivityMedia> media;
  final List<ActivityGoal> goals;
  final List<ActivityFinancialRecord> financials;
  final Map<String, dynamic> indicators;
  final String status;
  final String? responsibleName;
  final String? responsibleEmail;
  final String? responsiblePhone;
  final String? responsibleUserId;
  final Map<String, dynamic> socialMediaImpact;
  final bool includeInAnnualReport;
  final String? targetCourseId;
  final bool isControlActivity;

  MarketingEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.marketingGroup = 'Marketing Social',
    this.academicYear = '2024/2025',
    this.hasFinancialImpact = false,
    this.resources = const [],
    this.participants = const [],
    this.media = const [],
    this.goals = const [],
    this.financials = const [],
    this.indicators = const {},
    this.status = 'planned',
    this.responsibleName,
    this.responsibleEmail,
    this.responsiblePhone,
    this.responsibleUserId,
    this.socialMediaImpact = const {},
    this.includeInAnnualReport = false,
    this.targetCourseId,
    this.isControlActivity = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'institutionId': institutionId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'marketingGroup': marketingGroup,
      'academicYear': academicYear,
      'hasFinancialImpact': hasFinancialImpact,
      'resources': resources.map((e) => e.toMap()).toList(),
      'participants': participants.map((e) => e.toMap()).toList(),
      'media': media.map((e) => e.toMap()).toList(),
      'goals': goals.map((e) => e.toMap()).toList(),
      'financials': financials.map((e) => e.toMap()).toList(),
      'indicators': indicators,
      'status': status,
      if (responsibleName != null) 'responsibleName': responsibleName,
      if (responsibleEmail != null) 'responsibleEmail': responsibleEmail,
      if (responsiblePhone != null) 'responsiblePhone': responsiblePhone,
      if (responsibleUserId != null) 'responsibleUserId': responsibleUserId,
      'socialMediaImpact': socialMediaImpact,
      'includeInAnnualReport': includeInAnnualReport,
      if (targetCourseId != null) 'targetCourseId': targetCourseId,
      'isControlActivity': isControlActivity,
    };
  }

  factory MarketingEvent.fromMap(Map<String, dynamic> map) {
    return MarketingEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      institutionId: map['institutionId'] ?? '',
      startDate:
          DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate:
          DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      startTime: map['startTime'] ?? '09:00',
      endTime: map['endTime'] ?? '17:00',
      marketingGroup: map['marketingGroup'] ?? 'Marketing Social',
      academicYear: map['academicYear'] ?? '2024/2025',
      hasFinancialImpact: map['hasFinancialImpact'] ?? false,
      resources: (map['resources'] as List? ?? [])
          .map((e) => ActivityResource.fromMap(e))
          .toList(),
      participants: (map['participants'] as List? ?? [])
          .map((e) => ActivityParticipant.fromMap(e))
          .toList(),
      media: (map['media'] as List? ?? [])
          .map((e) => ActivityMedia.fromMap(e))
          .toList(),
      goals: (map['goals'] as List? ?? [])
          .map((e) => ActivityGoal.fromMap(e))
          .toList(),
      financials: (map['financials'] as List? ?? [])
          .map((e) => ActivityFinancialRecord.fromMap(e))
          .toList(),
      indicators: Map<String, dynamic>.from(map['indicators'] ?? {}),
      status: map['status'] ?? 'planned',
      responsibleName: map['responsibleName'],
      responsibleEmail: map['responsibleEmail'],
      responsiblePhone: map['responsiblePhone'],
      responsibleUserId: map['responsibleUserId'],
      socialMediaImpact: map['socialMediaImpact'] != null
          ? Map<String, dynamic>.from(map['socialMediaImpact'])
          : {},
      includeInAnnualReport: map['includeInAnnualReport'] ?? false,
      targetCourseId: map['targetCourseId'],
      isControlActivity: map['isControlActivity'] ?? false,
    );
  }
}
