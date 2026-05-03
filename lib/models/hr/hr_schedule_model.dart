import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftType { fixed, variable, rotational, partTime, fullTime }

class HRShift {
  final String id;
  final String institutionId;
  final String name;
  final ShiftType type;
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final double breakDurationHours;
  final String color; // Hex string

  HRShift({
    required this.id,
    required this.institutionId,
    required this.name,
    this.type = ShiftType.fixed,
    required this.startTime,
    required this.endTime,
    this.breakDurationHours = 1.0,
    this.color = '#7B61FF',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'institutionId': institutionId,
    'name': name,
    'type': type.name,
    'startTime': startTime,
    'endTime': endTime,
    'breakDurationHours': breakDurationHours,
    'color': color,
  };

  factory HRShift.fromMap(Map<String, dynamic> map) => HRShift(
    id: map['id'] ?? '',
    institutionId: map['institutionId'] ?? '',
    name: map['name'] ?? '',
    type: ShiftType.values.firstWhere((e) => e.name == map['type'], orElse: () => ShiftType.fixed),
    startTime: map['startTime'] ?? '09:00',
    endTime: map['endTime'] ?? '18:00',
    breakDurationHours: (map['breakDurationHours'] as num?)?.toDouble() ?? 1.0,
    color: map['color'] ?? '#7B61FF',
  );
}

class HRScheduleEntry {
  final String id;
  final String employeeId;
  final String institutionId;
  final DateTime date;
  final String? shiftId;
  final String customStartTime;
  final String customEndTime;
  final bool isOffDay;
  final String status; // 'planned', 'actual', 'completed'

  HRScheduleEntry({
    required this.id,
    required this.employeeId,
    required this.institutionId,
    required this.date,
    this.shiftId,
    this.customStartTime = "09:00",
    this.customEndTime = "18:00",
    this.isOffDay = false,
    this.status = 'planned',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'institutionId': institutionId,
    'date': Timestamp.fromDate(date),
    'shiftId': shiftId,
    'customStartTime': customStartTime,
    'customEndTime': customEndTime,
    'isOffDay': isOffDay,
    'status': status,
  };

  factory HRScheduleEntry.fromMap(Map<String, dynamic> map) => HRScheduleEntry(
    id: map['id'] ?? '',
    employeeId: map['employeeId'] ?? '',
    institutionId: map['institutionId'] ?? '',
    date: (map['date'] as Timestamp).toDate(),
    shiftId: map['shiftId'],
    customStartTime: map['customStartTime'] ?? '09:00',
    customEndTime: map['customEndTime'] ?? '18:00',
    isOffDay: map['isOffDay'] ?? false,
    status: map['status'] ?? 'planned',
  );
}
