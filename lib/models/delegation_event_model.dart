import 'package:cloud_firestore/cloud_firestore.dart';

class DelegationEvent {
  final String id;
  final String institutionId;
  final String moduleKey;
  final String moduleLabel;
  final String delegateId;
  final String delegateName;
  final String assignedById;
  final String assignedByName;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  DelegationEvent({
    required this.id,
    required this.institutionId,
    required this.moduleKey,
    required this.moduleLabel,
    required this.delegateId,
    required this.delegateName,
    required this.assignedById,
    required this.assignedByName,
    required this.startDate,
    this.endDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'institutionId': institutionId,
        'moduleKey': moduleKey,
        'moduleLabel': moduleLabel,
        'delegateId': delegateId,
        'delegateName': delegateName,
        'assignedById': assignedById,
        'assignedByName': assignedByName,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isActive': isActive,
      };

  factory DelegationEvent.fromMap(String id, Map<String, dynamic> map) => DelegationEvent(
        id: id,
        institutionId: map['institutionId'] ?? '',
        moduleKey: map['moduleKey'] ?? '',
        moduleLabel: map['moduleLabel'] ?? '',
        delegateId: map['delegateId'] ?? '',
        delegateName: map['delegateName'] ?? '',
        assignedById: map['assignedById'] ?? '',
        assignedByName: map['assignedByName'] ?? '',
        startDate: (map['startDate'] as Timestamp).toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        isActive: map['isActive'] ?? true,
      );
}
