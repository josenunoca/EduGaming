class StudyCycle {
  final String id;
  final String name; // e.g., "1º Ciclo", "Mestrado"
  final String institutionId;
  final int durationValue; // e.g., 3, 6
  final String durationUnit; // "Anos", "Meses"

  StudyCycle({
    required this.id,
    required this.name,
    required this.institutionId,
    this.durationValue = 1,
    this.durationUnit = 'Anos',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'institutionId': institutionId,
      'durationValue': durationValue,
      'durationUnit': durationUnit,
    };
  }

  factory StudyCycle.fromMap(Map<String, dynamic> map) {
    return StudyCycle(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      institutionId: map['institutionId'] ?? '',
      durationValue: map['durationValue'] ?? 1,
      durationUnit: map['durationUnit'] ?? 'Anos',
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
  final int durationYears; // New: standard duration

  Course({
    required this.id,
    required this.name,
    required this.studyCycleId,
    required this.institutionId,
    this.subjectIds = const [],
    this.academicYears = const [],
    this.coordinatorId,
    this.delegateId,
    this.durationYears = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'studyCycleId': studyCycleId,
      'institutionId': institutionId,
      'subjectIds': subjectIds,
      'academicYears': academicYears,
      'durationYears': durationYears,
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
      durationYears: map['durationYears'] ?? 3,
      coordinatorId: map['coordinatorId'],
      delegateId: map['delegateId'],
    );
  }
}
