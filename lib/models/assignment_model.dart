import 'package:uuid/uuid.dart';

enum AssignmentType { treino, avaliacao }

class AssignmentSubmission {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final List<String> fileUrls;
  final String? studentComments;

  // Evaluation & Grading
  final bool isGraded;
  final double? grade;
  final String? teacherFeedback;

  // Plagiarism Info
  final bool plagiarismChecked;
  final double? plagiarismScore; // 0.0 to 100.0
  final List<String>? plagiarismMatchedSources;

  // Group Info
  final List<String>? groupMemberIds;

  AssignmentSubmission({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    required this.fileUrls,
    this.studentComments,
    this.isGraded = false,
    this.grade,
    this.teacherFeedback,
    this.plagiarismChecked = false,
    this.plagiarismScore,
    this.plagiarismMatchedSources,
    this.groupMemberIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'submittedAt': submittedAt.toIso8601String(),
      'fileUrls': fileUrls,
      if (studentComments != null) 'studentComments': studentComments,
      'isGraded': isGraded,
      if (grade != null) 'grade': grade,
      if (teacherFeedback != null) 'teacherFeedback': teacherFeedback,
      'plagiarismChecked': plagiarismChecked,
      if (plagiarismScore != null) 'plagiarismScore': plagiarismScore,
      if (plagiarismMatchedSources != null)
        'plagiarismMatchedSources': plagiarismMatchedSources,
      if (groupMemberIds != null) 'groupMemberIds': groupMemberIds,
    };
  }

  factory AssignmentSubmission.fromMap(Map<String, dynamic> map) {
    return AssignmentSubmission(
      id: map['id'] ?? const Uuid().v4(),
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      submittedAt: DateTime.parse(map['submittedAt'] ?? DateTime.now().toIso8601String()),
      fileUrls: List<String>.from(map['fileUrls'] ?? []),
      studentComments: map['studentComments'],
      isGraded: map['isGraded'] ?? false,
      grade: (map['grade'] as num?)?.toDouble(),
      teacherFeedback: map['teacherFeedback'],
      plagiarismChecked: map['plagiarismChecked'] ?? false,
      plagiarismScore: (map['plagiarismScore'] as num?)?.toDouble(),
      plagiarismMatchedSources: map['plagiarismMatchedSources'] != null 
          ? List<String>.from(map['plagiarismMatchedSources']) 
          : null,
      groupMemberIds: map['groupMemberIds'] != null 
          ? List<String>.from(map['groupMemberIds']) 
          : null,
    );
  }
}

class Assignment {
  final String id;
  final String subjectId;
  final String teacherId;
  final String title;
  final String description;
  final AssignmentType type; 
  final String? linkedEvaluationComponentId; 

  final DateTime createdAt;
  final DateTime startDate;
  final DateTime dueDate;
  final bool allowLateSubmissions;
  final int effortHours;

  final List<String> attachmentsUrls;
  final bool isVisibleToStudents;
  final List<String>? specificStudentIds; 
  final List<String>? notifyTeacherIds;
  final String dashboardVisibility; 
  final bool allowRevisionAfterDelivery;

  final bool autoPlagiarismDetection;
  final bool addToPlagiarismRepo;
  final bool allowGroupSubmissions;

  final List<AssignmentSubmission> submissions;

  Assignment({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    required this.description,
    this.type = AssignmentType.treino,
    this.linkedEvaluationComponentId,
    required this.createdAt,
    required this.startDate,
    required this.dueDate,
    this.allowLateSubmissions = false,
    this.effortHours = 2,
    this.attachmentsUrls = const [],
    this.isVisibleToStudents = false,
    this.specificStudentIds,
    this.notifyTeacherIds,
    this.dashboardVisibility = 'Professor',
    this.allowRevisionAfterDelivery = true,
    this.autoPlagiarismDetection = true,
    this.addToPlagiarismRepo = true,
    this.allowGroupSubmissions = false,
    this.submissions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'type': type.name,
      if (linkedEvaluationComponentId != null) 'linkedEvaluationComponentId': linkedEvaluationComponentId,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'allowLateSubmissions': allowLateSubmissions,
      'effortHours': effortHours,
      'attachmentsUrls': attachmentsUrls,
      'isVisibleToStudents': isVisibleToStudents,
      if (specificStudentIds != null) 'specificStudentIds': specificStudentIds,
      if (notifyTeacherIds != null) 'notifyTeacherIds': notifyTeacherIds,
      'dashboardVisibility': dashboardVisibility,
      'allowRevisionAfterDelivery': allowRevisionAfterDelivery,
      'autoPlagiarismDetection': autoPlagiarismDetection,
      'addToPlagiarismRepo': addToPlagiarismRepo,
      'allowGroupSubmissions': allowGroupSubmissions,
      'submissions': submissions.map((e) => e.toMap()).toList(),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] ?? const Uuid().v4(),
      subjectId: map['subjectId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: AssignmentType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'treino'),
        orElse: () => AssignmentType.treino,
      ),
      linkedEvaluationComponentId: map['linkedEvaluationComponentId'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      dueDate: DateTime.parse(map['dueDate'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String()),
      allowLateSubmissions: map['allowLateSubmissions'] ?? false,
      effortHours: map['effortHours'] ?? 2,
      attachmentsUrls: List<String>.from(map['attachmentsUrls'] ?? []),
      isVisibleToStudents: map['isVisibleToStudents'] ?? false,
      specificStudentIds: map['specificStudentIds'] != null ? List<String>.from(map['specificStudentIds']) : null,
      notifyTeacherIds: map['notifyTeacherIds'] != null ? List<String>.from(map['notifyTeacherIds']) : null,
      dashboardVisibility: map['dashboardVisibility'] ?? 'Professor',
      allowRevisionAfterDelivery: map['allowRevisionAfterDelivery'] ?? true,
      autoPlagiarismDetection: map['autoPlagiarismDetection'] ?? true,
      addToPlagiarismRepo: map['addToPlagiarismRepo'] ?? true,
      allowGroupSubmissions: map['allowGroupSubmissions'] ?? false,
      submissions: (map['submissions'] as List? ?? [])
          .map((e) => AssignmentSubmission.fromMap(e))
          .toList(),
    );
  }
}
