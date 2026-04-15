import 'dart:io';

void main() async {
  final result = await Process.run('git', [
    'show',
    '7f4532f8191a86906d8b65f4455222a78d6c22679:lib/services/ai_chat_service.dart'
  ]);
  if (result.exitCode == 0) {
    File('first_ai_service.dart').writeAsStringSync(result.stdout);
    print('SUCCESS: SAVED TO first_ai_service.dart');
  } else {
    print('Error: ${result.stderr}');
  }
}
