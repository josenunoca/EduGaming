import 'dart:io';

void main() {
  // Fix infrastructure_management_screen.dart
  final mgtPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_management_screen.dart';
  var mgtContent = File(mgtPath).readAsStringSync();
  // Fix Institution import
  mgtContent = mgtContent.replaceAll("import '../../../../models/institution_model.dart';", "import 'package:loan_calc_mvp/models/institution_model.dart';");
  File(mgtPath).writeAsStringSync(mgtContent);

  // Fix infrastructure_details_screen.dart
  final detPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart';
  var detContent = File(detPath).readAsStringSync();
  // Fix Institution import
  detContent = detContent.replaceAll("import '../../../../models/institution_model.dart';", "import 'package:loan_calc_mvp/models/institution_model.dart';");
  
  // Fix Tab text vs child
  detContent = detContent.replaceAll("Tab(icon: const Icon(Icons.info), text: AiTranslatedText('Detalhes').translate()),", "Tab(icon: const Icon(Icons.info), child: AiTranslatedText('Detalhes')),");
  detContent = detContent.replaceAll("Tab(icon: const Icon(Icons.attach_money), text: AiTranslatedText('Avaliação Financeira').translate()),", "Tab(icon: const Icon(Icons.attach_money), child: AiTranslatedText('Avaliação Financeira')),");
  detContent = detContent.replaceAll("Tab(icon: const Icon(Icons.photo_library), text: AiTranslatedText('Multimédia').translate()),", "Tab(icon: const Icon(Icons.photo_library), child: AiTranslatedText('Multimédia')),");
  
  // Fix ActivityVisibility.internal
  detContent = detContent.replaceAll("visibility: ActivityVisibility.internal,", "visibility: ActivityVisibility.wholeInstitution,");
  
  // Fix uploadContentFile arguments
  detContent = detContent.replaceAll("uploadContentFile(_currentInfra.id, file.bytes!, file.name);", "uploadContentFile(file.bytes!, file.name);");
  
  File(detPath).writeAsStringSync(detContent);
}
