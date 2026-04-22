class SchoolCalendar {
  final String id;
  final String institutionId;
  final String academicYear; // e.g., "2024/2025"
  final List<SchoolTerm> terms;
  final List<Holiday> holidays;
  final List<VacationPeriod> vacations;

  final AcademicDeadlines? deadlines;

  SchoolCalendar({
    required this.id,
    required this.institutionId,
    required this.academicYear,
    this.terms = const [],
    this.holidays = const [],
    this.vacations = const [],
    this.deadlines,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'institutionId': institutionId,
      'academicYear': academicYear,
      'terms': terms.map((t) => t.toMap()).toList(),
      'holidays': holidays.map((h) => h.toMap()).toList(),
      'vacations': vacations.map((v) => v.toMap()).toList(),
      if (deadlines != null) 'deadlines': deadlines!.toMap(),
    };
  }

  factory SchoolCalendar.fromMap(Map<String, dynamic> map) {
    return SchoolCalendar(
      id: map['id'] ?? '',
      institutionId: map['institutionId'] ?? '',
      academicYear: map['academicYear'] ?? '',
      terms: (map['terms'] as List? ?? [])
          .map((t) => SchoolTerm.fromMap(t))
          .toList(),
      holidays: (map['holidays'] as List? ?? [])
          .map((h) => Holiday.fromMap(h))
          .toList(),
      vacations: (map['vacations'] as List? ?? [])
          .map((v) => VacationPeriod.fromMap(v))
          .toList(),
      deadlines: map['deadlines'] != null
          ? AcademicDeadlines.fromMap(map['deadlines'])
          : null,
    );
  }
}

class AcademicDeadlines {
  final DateTime? programSubmissionDeadline;
  final DateTime? gradingDeadline; // Final pauta seal deadline
  final DateTime? surveyDeadline;

  AcademicDeadlines({
    this.programSubmissionDeadline,
    this.gradingDeadline,
    this.surveyDeadline,
  });

  Map<String, dynamic> toMap() {
    return {
      if (programSubmissionDeadline != null)
        'programSubmissionDeadline':
            programSubmissionDeadline!.toIso8601String(),
      if (gradingDeadline != null)
        'gradingDeadline': gradingDeadline!.toIso8601String(),
      if (surveyDeadline != null)
        'surveyDeadline': surveyDeadline!.toIso8601String(),
    };
  }

  factory AcademicDeadlines.fromMap(Map<String, dynamic> map) {
    return AcademicDeadlines(
      programSubmissionDeadline: map['programSubmissionDeadline'] != null
          ? DateTime.parse(map['programSubmissionDeadline'])
          : null,
      gradingDeadline: map['gradingDeadline'] != null
          ? DateTime.parse(map['gradingDeadline'])
          : null,
      surveyDeadline: map['surveyDeadline'] != null
          ? DateTime.parse(map['surveyDeadline'])
          : null,
    );
  }
}

class SchoolTerm {
  final String id;
  final String name; // e.g., "1º Semestre", "2º Trimestre"
  final DateTime startDate;
  final DateTime endDate;

  SchoolTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory SchoolTerm.fromMap(Map<String, dynamic> map) {
    return SchoolTerm(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
}

class Holiday {
  final String id;
  final String name;
  final DateTime date;
  final bool isRecurring; // e.g., Christmas

  Holiday({
    required this.id,
    required this.name,
    required this.date,
    this.isRecurring = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      date: DateTime.parse(map['date']),
      isRecurring: map['isRecurring'] ?? false,
    );
  }
}

class VacationPeriod {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  VacationPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory VacationPeriod.fromMap(Map<String, dynamic> map) {
    return VacationPeriod(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
}
