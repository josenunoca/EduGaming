import 'activity_model.dart';

class ReportSection {
  final String title;
  final String content;

  ReportSection({required this.title, required this.content});

  Map<String, dynamic> toMap() => {'title': title, 'content': content};
  factory ReportSection.fromMap(Map<String, dynamic> map) => ReportSection(
        title: map['title'] ?? '',
        content: map['content'] ?? '',
      );
}

class CourseReport {
  final String id;
  final String courseId;
  final String institutionId;
  final String academicYear;
  final String title;
  final String description;
  final List<ReportSection> sections;
  final List<String> selectedActivityPhotoUrls;
  final Map<String, dynamic> snapshotMetrics;
  final Map<String, dynamic> surveyAggregates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'draft' | 'finalized'
  final String? coordinatorId;

  CourseReport({
    required this.id,
    required this.courseId,
    required this.institutionId,
    required this.academicYear,
    required this.title,
    required this.description,
    this.sections = const [],
    this.selectedActivityPhotoUrls = const [],
    this.snapshotMetrics = const {},
    this.surveyAggregates = const {},
    required this.createdAt,
    required this.updatedAt,
    this.status = 'draft',
    this.coordinatorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'institutionId': institutionId,
      'academicYear': academicYear,
      'title': title,
      'description': description,
      'sections': sections.map((e) => e.toMap()).toList(),
      'selectedActivityPhotoUrls': selectedActivityPhotoUrls,
      'snapshotMetrics': snapshotMetrics,
      'surveyAggregates': surveyAggregates,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      if (coordinatorId != null) 'coordinatorId': coordinatorId,
    };
  }

  factory CourseReport.fromMap(Map<String, dynamic> map) {
    return CourseReport(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      academicYear: map['academicYear'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      sections: (map['sections'] as List? ?? [])
          .map((e) => ReportSection.fromMap(e))
          .toList(),
      selectedActivityPhotoUrls:
          List<String>.from(map['selectedActivityPhotoUrls'] ?? []),
      snapshotMetrics: Map<String, dynamic>.from(map['snapshotMetrics'] ?? {}),
      surveyAggregates:
          Map<String, dynamic>.from(map['surveyAggregates'] ?? {}),
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          map['updatedAt'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'draft',
      coordinatorId: map['coordinatorId'],
    );
  }

  CourseReport copyWith({
    String? id,
    String? courseId,
    String? institutionId,
    String? academicYear,
    String? title,
    String? description,
    List<ReportSection>? sections,
    List<String>? selectedActivityPhotoUrls,
    Map<String, dynamic>? snapshotMetrics,
    Map<String, dynamic>? surveyAggregates,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? coordinatorId,
  }) {
    return CourseReport(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      institutionId: institutionId ?? this.institutionId,
      academicYear: academicYear ?? this.academicYear,
      title: title ?? this.title,
      description: description ?? this.description,
      sections: sections ?? this.sections,
      selectedActivityPhotoUrls:
          selectedActivityPhotoUrls ?? this.selectedActivityPhotoUrls,
      snapshotMetrics: snapshotMetrics ?? this.snapshotMetrics,
      surveyAggregates: surveyAggregates ?? this.surveyAggregates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      coordinatorId: coordinatorId ?? this.coordinatorId,
    );
  }
}
