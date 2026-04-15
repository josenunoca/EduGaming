import 'dart:io';

void main() async {
  final result = await Process.run(
      'git', ['show', '7f4532f:lib/services/ai_chat_service.dart']);
  if (result.exitCode == 0) {
    File('original_ai_fixed.dart').writeAsStringSync(result.stdout);
    print('SUCCESS: SAVED TO original_ai_fixed.dart');
  } else {
    print('Error: ${result.stderr}');
  }
}
