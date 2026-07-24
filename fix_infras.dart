import 'dart:io';

void main() {
  // 1. Fix infrastructure_model.dart
  final modelPath = 'c:/Users/josen/apptest/lib/models/infrastructure_model.dart';
  var modelContent = File(modelPath).readAsStringSync();
  modelContent = modelContent.replaceAll("import 'package:apptest/models/activity_model.dart';", "import 'activity_model.dart';");
  File(modelPath).writeAsStringSync(modelContent);

  // 2. Fix infrastructure_management_screen.dart
  final mgtPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_management_screen.dart';
  var mgtContent = File(mgtPath).readAsStringSync();
  mgtContent = mgtContent.replaceAll("import '../../../../utils/ai_translated_text.dart';", "import '../../../../widgets/ai_translated_text.dart';");
  mgtContent = mgtContent.replaceAll("const AiTranslatedText", "AiTranslatedText");
  File(mgtPath).writeAsStringSync(mgtContent);

  // 3. Fix infrastructure_details_screen.dart
  final detPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart';
  var detContent = File(detPath).readAsStringSync();
  detContent = detContent.replaceAll("import '../../../../utils/ai_translated_text.dart';", "import '../../../../widgets/ai_translated_text.dart';");
  detContent = detContent.replaceAll("const AiTranslatedText", "AiTranslatedText");
  detContent = detContent.replaceAll("uploadActivityMedia", "uploadContentFile");
  // Also fix 'visibility: ActivityVisibility.internal,' to remove 'visibility:' if the constructor doesn't have it,
  // or use the correct enum. Let's look at ActivityMedia constructor error:
  // "Member not found: 'internal'." -> The enum might be named something else. Let's fix that too.
  File(detPath).writeAsStringSync(detContent);
}
