import 'dart:io';

void main() {
  final path = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart';
  var content = File(path).readAsStringSync();
  
  // 1. Remove Tabs that we don't need (Participants, Wall)
  content = content.replaceAll("Tab(icon: Icon(Icons.people), text: AiTranslatedText('Participantes').translate()),", "");
  content = content.replaceAll("Tab(icon: Icon(Icons.dashboard), text: AiTranslatedText('Mural').translate()),", "");
  content = content.replaceAll("length: 5,", "length: 3,"); // Assuming there are 5 originally (or 4 if hasFinancialImpact is conditional)
  // Let's check how many tabs were defined originally:
  // length: _currentinfra.hasFinancialImpact ? 5 : 4,
  content = content.replaceAll("length: _currentinfra.hasFinancialImpact ? 5 : 4,", "length: 3,");
  
  content = content.replaceAll("if (_currentinfra.hasFinancialImpact) Tab(icon: Icon(Icons.attach_money), text: AiTranslatedText('Finanças').translate()),", "Tab(icon: Icon(Icons.attach_money), text: AiTranslatedText('Avaliação').translate()),");
  
  content = content.replaceAll("_buildParticipantsTab(),", "");
  content = content.replaceAll("_buildWallTab(),", "");
  content = content.replaceAll("if (_currentinfra.hasFinancialImpact) _buildFinancialsTab(),", "_buildFinancialsTab(),");
  
  File(path).writeAsStringSync(content);
}
