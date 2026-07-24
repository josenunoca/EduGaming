import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/models/infrastructure_model.dart');
  var content = file.readAsStringSync();
  
  // 1. Add InfrastructureMaintenance class at the bottom
  final maintenanceClass = '''
class InfrastructureMaintenance {
  final String id;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double cost;
  final String? documentUrl;
  final String? documentName;

  InfrastructureMaintenance({
    required this.id,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.cost,
    this.documentUrl,
    this.documentName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'cost': cost,
      'documentUrl': documentUrl,
      'documentName': documentName,
    };
  }

  factory InfrastructureMaintenance.fromMap(Map<String, dynamic> map) {
    return InfrastructureMaintenance(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      cost: (map['cost'] ?? 0.0).toDouble(),
      documentUrl: map['documentUrl'],
      documentName: map['documentName'],
    );
  }
}
''';

  if (!content.contains('class InfrastructureMaintenance')) {
    content += '\n' + maintenanceClass;
  }
  
  // 2. Add maintenances field to Infrastructure
  content = content.replaceAll("final List<ActivityMedia> media;", "final List<ActivityMedia> media;\n  final List<InfrastructureMaintenance> maintenances;");
  
  // Update constructor
  content = content.replaceAll("this.media = const [],\n  });", "this.media = const [],\n    this.maintenances = const [],\n  });");
  content = content.replaceAll("this.media = const [],\r\n  });", "this.media = const [],\r\n    this.maintenances = const [],\r\n  });");
  
  // Update toMap
  content = content.replaceAll("'media': media.map((x) => x.toMap()).toList(),", "'media': media.map((x) => x.toMap()).toList(),\n      'maintenances': maintenances.map((x) => x.toMap()).toList(),");
  
  // Update fromMap
  content = content.replaceAll('''
      media: map['media'] != null
          ? List<ActivityMedia>.from(
              map['media']?.map((x) => ActivityMedia.fromMap(x)))
          : [],
''', '''
      media: map['media'] != null
          ? List<ActivityMedia>.from(
              map['media']?.map((x) => ActivityMedia.fromMap(x)))
          : [],
      maintenances: map['maintenances'] != null
          ? List<InfrastructureMaintenance>.from(
              map['maintenances']?.map((x) => InfrastructureMaintenance.fromMap(x)))
          : [],
''');

  // Update copyWith
  content = content.replaceAll("List<ActivityMedia>? media,", "List<ActivityMedia>? media,\n    List<InfrastructureMaintenance>? maintenances,");
  content = content.replaceAll("media: media ?? this.media,", "media: media ?? this.media,\n      maintenances: maintenances ?? this.maintenances,");
  
  file.writeAsStringSync(content);
}
