import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = "AIzaSyBijmKqyafP2tDtoe_Jkab1gzGdJXHxefo";
  const endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:generateContent';

  print('Testing Imagen API with key: ${apiKey.substring(0, 5)}...');

  try {
    final response = await http.post(
      Uri.parse('$endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'A simple educational icon of a book.'}
            ]
          }
        ]
      }),
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('SUCCESS: Imagen API is working with this key.');
    } else {
      print('FAILURE: Imagen API returned an error.');
    }
  } catch (e) {
    print('EXCEPTION: $e');
  }
}
