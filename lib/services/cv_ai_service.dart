import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/curriculum_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class CvAiService {
  late final GenerativeModel _model;

  CvAiService({required String apiKey}) {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  Future<CurriculumModel> parseCvPdf(Uint8List pdfBytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final String cvText = PdfTextExtractor(document).extractText();
      document.dispose();

      if (cvText.trim().isEmpty) {
        throw Exception('O PDF não contém texto extraível.');
      }

      return parseCvText(cvText);
    } catch (e) {
      debugPrint('Error parsing PDF: $e');
      rethrow;
    }
  }

  Future<CurriculumModel> parseCvText(String extractedText) async {
    final prompt = '''
You are an expert HR assistant. Extract the following information from the provided Curriculum Vitae text and format it as a JSON object.
Use exactly these keys:
- "academicQualifications": (string) Summary of academic degrees, universities, and years.
- "courseArea": (string) Main area of study.
- "professionalQualifications": (string) Professional certificates or qualifications.
- "awards": (string) Any awards or honors. 
- "experience": (string) Chronological summary of work experience, roles, and companies.
- "publications": (string) Any books, papers, or articles published.
- "otherInterests": (string) Any other relevant interests or skills.

Return ONLY a valid JSON object. Do not include markdown code block syntax (like ```json), just the raw JSON. If some sections are missing, leave them as null or an empty string.

Text to analyze:
$extractedText
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      
      var responseText = response.text ?? '{}';
      // Clean up potential markdown formatting from Gemini
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> data = jsonDecode(responseText);
      
      return CurriculumModel(
        academicQualifications: data['academicQualifications']?.toString(),
        courseArea: data['courseArea']?.toString(),
        professionalQualifications: data['professionalQualifications']?.toString(),
        awards: data['awards']?.toString(),
        experience: data['experience']?.toString(),
        publications: data['publications']?.toString(),
        otherInterests: data['otherInterests']?.toString(),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error calling AI to parse CV text: $e');
      rethrow;
    }
  }
}
