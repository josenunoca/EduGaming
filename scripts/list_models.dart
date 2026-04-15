import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final apiKey = 'AIzaSyBijmKqyafP2tDtoe_Jkab1gzGdJXHxefo';

  final url =
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  try {
    final response = await http.get(Uri.parse(url));
    final file = File('scripts/models_output.txt');
    String output = '';

    // Test Gemini Flash Latest
    output += '\n--- Gemini Flash Latest Test ---\n';
    final geminiUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey';
    final geminiResponse = await http.post(
      Uri.parse(geminiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Olá, estás a funcionar?'}
            ]
          }
        ]
      }),
    );

    if (geminiResponse.statusCode == 200) {
      output += 'Gemini Flash Latest Success: Content generated.\n';
    } else {
      output +=
          'Gemini Flash Latest Error: ${geminiResponse.statusCode} - ${geminiResponse.body}\n';
    }

    // Test TTS
    output += '\n--- TTS Test ---\n';
    final ttsUrl =
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey';
    final ttsResponse = await http.post(
      Uri.parse(ttsUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': 'Teste de voz'},
        'voice': {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-B'},
        'audioConfig': {'audioEncoding': 'MP3'}
      }),
    );

    if (ttsResponse.statusCode == 200) {
      output += 'TTS Success: Audio generated.\n';
    } else {
      output += 'TTS Error: ${ttsResponse.statusCode} - ${ttsResponse.body}\n';
    }

    await file.writeAsString(output);
    print('Output saved to scripts/models_output.txt');
  } catch (e) {
    print('Exception: $e');
  }
}
