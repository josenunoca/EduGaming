import 'package:cloud_firestore/cloud_firestore.dart';

enum ErpModule {
  hr,
  finance,
  procurement,
  marketing,
  international,
  infrastructure,
  legal,
  other
}

enum ErpRecordStatus { active, pending, completed, cancelled, archived }

class ErpRecord {
  final String id;
  final String institutionId;
  final ErpModule module;
  final String title;
  final String description;
  final ErpRecordStatus status;
  final Map<String, dynamic> data; // Module-specific JSON data
  final List<String> attachments;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ErpRecord({
    required this.id,
    required this.institutionId,
    required this.module,
    required this.title,
    this.description = '',
    this.status = ErpRecordStatus.active,
    this.data = const {},
    this.attachments = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'institutionId': institutionId,
      'module': module.name,
      'title': title,
      'description': description,
      'status': status.name,
      'data': data,
      'attachments': attachments,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ErpRecord.fromMap(Map<String, dynamic> map) {
    return ErpRecord(
      id: map['id'] ?? '',
      institutionId: map['institutionId'] ?? '',
      module: ErpModule.values.firstWhere(
        (e) => e.name == map['module'],
        orElse: () => ErpModule.other,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: ErpRecordStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ErpRecordStatus.active,
      ),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      attachments: List<String>.from(map['attachments'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  ErpRecord copyWith({
    String? title,
    String? description,
    ErpRecordStatus? status,
    Map<String, dynamic>? data,
    List<String>? attachments,
    DateTime? updatedAt,
  }) {
    return ErpRecord(
      id: id,
      institutionId: institutionId,
      module: module,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      data: data ?? this.data,
      attachments: attachments ?? this.attachments,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
