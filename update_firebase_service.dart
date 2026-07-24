import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/services/firebase_service.dart');
  var content = file.readAsStringSync();
  
  final toAdd = '''
  Future<void> addInfrastructureMaintenance(String id, InfrastructureMaintenance maintenance) async {
    await _db.collection('infrastructures').doc(id).update({
      'maintenances': FieldValue.arrayUnion([maintenance.toMap()])
    });
  }

  Future<void> removeInfrastructureMaintenance(String id, InfrastructureMaintenance maintenance) async {
    await _db.collection('infrastructures').doc(id).update({
      'maintenances': FieldValue.arrayRemove([maintenance.toMap()])
    });
  }
''';

  content = content.replaceAll("Future<void> removeInfrastructureMedia(String id, ActivityMedia mediaItem) async {\n    await _db.collection('infrastructures').doc(id).update({\n      'media': FieldValue.arrayRemove([mediaItem.toMap()])\n    });\n  }", "Future<void> removeInfrastructureMedia(String id, ActivityMedia mediaItem) async {\n    await _db.collection('infrastructures').doc(id).update({\n      'media': FieldValue.arrayRemove([mediaItem.toMap()])\n    });\n  }\n\n" + toAdd);
  
  // also handle CRLF
  content = content.replaceAll("Future<void> removeInfrastructureMedia(String id, ActivityMedia mediaItem) async {\r\n    await _db.collection('infrastructures').doc(id).update({\r\n      'media': FieldValue.arrayRemove([mediaItem.toMap()])\r\n    });\r\n  }", "Future<void> removeInfrastructureMedia(String id, ActivityMedia mediaItem) async {\r\n    await _db.collection('infrastructures').doc(id).update({\r\n      'media': FieldValue.arrayRemove([mediaItem.toMap()])\r\n    });\r\n  }\r\n\r\n" + toAdd);

  file.writeAsStringSync(content);
}
