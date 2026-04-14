import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const apiKey = 'AIzaSyDkk9Bo7YXbfBFaJDBE89AE0ZbVLhiiu7E';
  const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['models'] as List;
      print('Available models in v1beta:');
      for (var model in models) {
        print('- ${model['name']}');
      }
    } else {
      print('Error listing models: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
