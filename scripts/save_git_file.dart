import 'dart:io';

void main() async {
  final result = await Process.run(
      'git', ['show', '4e2d593:lib/services/ai_chat_service.dart']);
  if (result.exitCode == 0) {
    File('temp_working_ai.dart').writeAsStringSync(result.stdout);
    print('SUCCESS: SAVED TO temp_working_ai.dart');
  } else {
    print('Error: ${result.stderr}');
  }
}
