import 'dart:io';

void main() async {
  final result = await Process.run(
      'git', ['show', '4e2d593:lib/services/ai_chat_service.dart']);
  if (result.exitCode == 0) {
    final lines = result.stdout.toString().split('\n');
    for (var i = 0; i < lines.length && i < 100; i++) {
      print(lines[i]);
    }
  } else {
    print('Error: ${result.stderr}');
  }
}
