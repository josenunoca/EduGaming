import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = "AIzaSyBijmKqyafP2tDtoe_Jkab1gzGdJXHxefo";
  const ttsEndpoint = 'https://texttospeech.googleapis.com/v1/text:synthesize';

  print('Testing TTS API with key: ${apiKey.substring(0, 5)}...');

  try {
    final response = await http.post(
      Uri.parse('$ttsEndpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': 'Olá, isto é um teste.'},
        'voice': {'languageCode': 'pt-PT', 'name': 'pt-PT-Wavenet-B'},
        'audioConfig': {
          'audioEncoding': 'MP3',
        }
      }),
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('SUCCESS: TTS API is working with this key.');
    } else {
      print('FAILURE: TTS API returned an error.');
    }
  } catch (e) {
    print('EXCEPTION: $e');
  }
}
