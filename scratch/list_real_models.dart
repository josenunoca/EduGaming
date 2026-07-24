import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const apiKey = 'AIzaSyAxzoL9Q5ijTohxTSgD2OY9O-nFwBKdSg0';
  const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  print('Requesting models for the current API key...');
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      for (var model in data['models']) {
        print('Model: ${model['name']}');
      }
    } else {
      print('Error ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
