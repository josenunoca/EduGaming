class StudyCycle {
  final String id;
  final String name; // e.g., "1º Ciclo", "Mestrado"
  final String institutionId;

  StudyCycle({
    required this.id,
    required this.name,
    required this.institutionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'institutionId': institutionId,
    };
  }

  factory StudyCycle.fromMap(Map<String, dynamic> map) {
    return StudyCycle(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      institutionId: map['institutionId'] ?? '',
    );
  }
}

class Course {
  final String id;
  final String name;
  final String studyCycleId;
  final String institutionId;
  final List<String> subjectIds;
  final List<String> academicYears;
  final String? coordinatorId; // New: nominated teacher
  final String? delegateId; // New: nominated student

  Course({
    required this.id,
    required this.name,
    required this.studyCycleId,
    required this.institutionId,
    this.subjectIds = const [],
    this.academicYears = const [],
    this.coordinatorId,
    this.delegateId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'studyCycleId': studyCycleId,
      'institutionId': institutionId,
      'subjectIds': subjectIds,
      'academicYears': academicYears,
      if (coordinatorId != null) 'coordinatorId': coordinatorId,
      if (delegateId != null) 'delegateId': delegateId,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      studyCycleId: map['studyCycleId'] ?? '',
      institutionId: map['institutionId'] ?? '',
      subjectIds: List<String>.from(map['subjectIds'] ?? []),
      academicYears: List<String>.from(map['academicYears'] ?? []),
      coordinatorId: map['coordinatorId'],
      delegateId: map['delegateId'],
    );
  }
}
