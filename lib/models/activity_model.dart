enum ActivityVisibility {
  participantsOnly,
  wholeInstitution,
  courseSpecific,
  subjectSpecific,
  public
}

class ActivityResource {
  final String id;
  final String name;
  final String type; // 'human' | 'material'
  final String? role; // for humans
  final int? quantity; // for materials

  ActivityResource({
    required this.id,
    required this.name,
    required this.type,
    this.role,
    this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      if (role != null) 'role': role,
      if (quantity != null) 'quantity': quantity,
    };
  }

  factory ActivityResource.fromMap(Map<String, dynamic> map) {
    return ActivityResource(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'material',
      role: map['role'],
      quantity: map['quantity'],
    );
  }
}

class ActivityParticipant {
  final String id;
  final String name;
  final String email;
  final String role; // 'organizer' | 'participant' | 'guest'
  final String? groupType; // 'institution' | 'course' | 'subject'
  final String? groupId;

  ActivityParticipant({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.groupType,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      if (groupType != null) 'groupType': groupType,
      if (groupId != null) 'groupId': groupId,
    };
  }

  factory ActivityParticipant.fromMap(Map<String, dynamic> map) {
    return ActivityParticipant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'participant',
      groupType: map['groupType'],
      groupId: map['groupId'],
    );
  }
}

class ActivityMedia {
  final String id;
  final String name;
  final String url;
  final String type; // 'document' | 'image' | 'video'
  final ActivityVisibility visibility;
  final DateTime uploadedAt;
  final bool isSocialMediaSelected;
  final bool isAnnualReportSelected;

  ActivityMedia({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.visibility,
    required this.uploadedAt,
    this.isSocialMediaSelected = false,
    this.isAnnualReportSelected = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'visibility': visibility.name,
      'uploadedAt': uploadedAt.toIso8601String(),
      'isSocialMediaSelected': isSocialMediaSelected,
      'isAnnualReportSelected': isAnnualReportSelected,
    };
  }

  factory ActivityMedia.fromMap(Map<String, dynamic> map) {
    return ActivityMedia(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? 'document',
      visibility: ActivityVisibility.values.firstWhere(
        (e) => e.name == (map['visibility'] ?? 'participantsOnly'),
        orElse: () => ActivityVisibility.participantsOnly,
      ),
      uploadedAt:
          DateTime.parse(map['uploadedAt'] ?? DateTime.now().toIso8601String()),
      isSocialMediaSelected: map['isSocialMediaSelected'] ?? false,
      isAnnualReportSelected: map['isAnnualReportSelected'] ?? false,
    );
  }
}

class ActivityGoal {
  final String id;
  final String description;
  final double targetValue;
  final double currentValue;
  final String unit;

  ActivityGoal({
    required this.id,
    required this.description,
    required this.targetValue,
    this.currentValue = 0.0,
    this.unit = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
    };
  }

  factory ActivityGoal.fromMap(Map<String, dynamic> map) {
    return ActivityGoal(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      targetValue: (map['targetValue'] ?? 0.0).toDouble(),
      currentValue: (map['currentValue'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
    );
  }
}

class ActivityFinancialRecord {
  final String id;
  final String type; // 'income' | 'expense'
  final String category; // 'Receita' or 'Consumíveis', 'Subcontratação', etc.
  final double amount;
  final String description;
  final String comment;
  final String? documentUrl;
  final DateTime date;

  ActivityFinancialRecord({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    this.comment = '',
    this.documentUrl,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'comment': comment,
      'documentUrl': documentUrl,
      'date': date.toIso8601String(),
    };
  }

  factory ActivityFinancialRecord.fromMap(Map<String, dynamic> map) {
    return ActivityFinancialRecord(
      id: map['id'] ?? '',
      type: map['type'] ?? 'expense',
      category: map['category'] ?? 'Outros',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      comment: map['comment'] ?? '',
      documentUrl: map['documentUrl'],
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class InstitutionalActivity {
  final String id;
  final String title;
  final String description;
  final String institutionId;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String activityGroup;
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

  InstitutionalActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.institutionId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.activityGroup = 'Outras Atividades',
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
      'activityGroup': activityGroup,
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

  factory InstitutionalActivity.fromMap(Map<String, dynamic> map) {
    return InstitutionalActivity(
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
      activityGroup: map['activityGroup'] ?? 'Outras Atividades',
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
