import 'dart:io';

void main() {
  // Fix infrastructure_management_screen.dart
  final mgtPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_management_screen.dart';
  var mgtContent = File(mgtPath).readAsStringSync();
  mgtContent = mgtContent.replaceAll("final Institution institution;", "final InstitutionModel institution;");
  mgtContent = mgtContent.replaceAll("import 'package:loan_calc_mvp/models/institution_model.dart';", "import '../../../../models/institution_model.dart';");
  File(mgtPath).writeAsStringSync(mgtContent);

  // Fix infrastructure_details_screen.dart
  final detPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart';
  var detContent = File(detPath).readAsStringSync();
  detContent = detContent.replaceAll("final Institution institution;", "final InstitutionModel institution;");
  detContent = detContent.replaceAll("import 'package:loan_calc_mvp/models/institution_model.dart';", "import '../../../../models/institution_model.dart';");
  detContent = detContent.replaceAll("uploadContentFile(\n                _currentInfra.id, file.bytes!, file.name);", "uploadContentFile(file.bytes!, file.name);");
  detContent = detContent.replaceAll("uploadContentFile(\r\n                _currentInfra.id, file.bytes!, file.name);", "uploadContentFile(file.bytes!, file.name);");
  // Also try replacing without newlines just in case
  detContent = detContent.replaceAll("uploadContentFile(_currentInfra.id, file.bytes!, file.name);", "uploadContentFile(file.bytes!, file.name);");

  // Fix Tab issue if it is still there? No, the previous script changed it to child: AiTranslatedText.
  // Wait, the error for Tab said: `Tab(icon: const Icon(Icons.info), text: AiTranslatedText('Detalhes').translate()),`
  // Wait, did my previous script fail? Let's check. 
  // Let's replace the EXACT text from the error just to be sure.
  detContent = detContent.replaceAll("text: AiTranslatedText('Detalhes').translate()", "child: AiTranslatedText('Detalhes')");
  detContent = detContent.replaceAll("text: AiTranslatedText('Avaliação Financeira').translate()", "child: AiTranslatedText('Avaliação Financeira')");
  detContent = detContent.replaceAll("text: AiTranslatedText('Multimédia').translate()", "child: AiTranslatedText('Multimédia')");

  File(detPath).writeAsStringSync(detContent);
}
