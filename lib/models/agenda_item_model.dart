import 'package:uuid/uuid.dart';

enum AgendaItemType { assignment, questionnaire, deadline, activity }
enum AgendaItemStatus { pending, completed, overdue }

class AgendaItem {
  final String id;
  final String title;
  final String description;
  final AgendaItemType type;
  final DateTime startDate;
  final DateTime dueDate;
  final AgendaItemStatus status;
  final String? relatedId;
  final Map<String, dynamic>? metadata;

  AgendaItem({
    String? id,
    required this.title,
    this.description = '',
    required this.type,
    required this.startDate,
    required this.dueDate,
    this.status = AgendaItemStatus.pending,
    this.relatedId,
    this.metadata,
  }) : id = id ?? const Uuid().v4();

  bool get isOverdue => status != AgendaItemStatus.completed && DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'relatedId': relatedId,
      'metadata': metadata,
    };
  }

  factory AgendaItem.fromMap(Map<String, dynamic> map) {
    return AgendaItem(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: AgendaItemType.values.firstWhere((e) => e.name == map['type'], orElse: () => AgendaItemType.activity),
      startDate: DateTime.parse(map['startDate']),
      dueDate: DateTime.parse(map['dueDate']),
      status: AgendaItemStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => AgendaItemStatus.pending),
      relatedId: map['relatedId'],
      metadata: map['metadata'],
    );
  }
}
