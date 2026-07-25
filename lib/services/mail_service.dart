import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class MailService {
  /// Sends an email via Resend API to real external email addresses (like Gmail/Outlook).
  static Future<bool> sendResendEmail({
    required List<String> to,
    required String subject,
    required String body,
    String? senderName,
    List<Map<String, String>>? attachments,
  }) async {
    final apiKey = AppConfig.resendApiKey;
    if (apiKey.isEmpty) {
      debugPrint('MailService: Resend API key is empty. Email not sent via HTTP.');
      return false;
    }

    final validRecipients = to.where((e) => e.contains('@')).toList();
    if (validRecipients.isEmpty) {
      debugPrint('MailService: No valid email addresses in recipient list $to');
      return false;
    }

    try {
      final fromHeader = (senderName != null && senderName.isNotEmpty)
          ? '$senderName via EduGaming <notificacoes@edugaming.pt>'
          : 'EduGaming <notificacoes@edugaming.pt>';

      final htmlContent = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #0F172A; color: #FFFFFF; border-radius: 12px;">
  <div style="border-bottom: 2px solid #7B61FF; padding-bottom: 12px; margin-bottom: 20px;">
    <h2 style="color: #00D1FF; margin: 0;">EduGaming - Centro de Comunicação</h2>
  </div>
  <p style="font-size: 14px; color: #94A3B8;">De: <strong style="color: #FFFFFF;">${senderName ?? 'EduGaming'}</strong></p>
  <p style="font-size: 16px; font-weight: bold; color: #FFFFFF;">${htmlEscape(subject)}</p>
  <div style="background-color: #1E293B; padding: 16px; border-radius: 8px; font-size: 14px; line-height: 1.6; color: #E2E8F0; margin: 16px 0;">
    ${body.replaceAll('\n', '<br>')}
  </div>
  <div style="border-top: 1px solid #334155; padding-top: 12px; margin-top: 20px; font-size: 12px; color: #64748B; text-align: center;">
    Mensagem enviada através da Plataforma EduGaming.<br>
    Para responder, aceda à plataforma ou responda a este e-mail.
  </div>
</div>
''';

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': fromHeader,
          'to': validRecipients,
          'subject': subject,
          'html': htmlContent,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('MailService: Email sent via Resend to $validRecipients');
        return true;
      } else {
        debugPrint('MailService: Resend error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('MailService: Failed to send email via Resend: $e');
      return false;
    }
  }

  static String htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Sends an email with certificate information.
  static Future<void> sendCertificateEmail({
    required String studentEmail,
    required String studentName,
    required String subjectName,
    required String certificateUrl,
  }) async {
    final sent = await sendResendEmail(
      to: [studentEmail],
      subject: 'Certificado de Aproveitamento - $subjectName',
      body: 'Olá $studentName,\n\nParabéns por concluíres a disciplina de $subjectName!\n\nPodes aceder ao teu certificado aqui: $certificateUrl\n\nMelhores cumprimentos,\nA Equipa EduGaming',
    );

    if (!sent) {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: studentEmail,
        queryParameters: {
          'subject': 'Certificado de Aproveitamento - $subjectName',
          'body': 'Olá $studentName,\n\nParabéns por concluíres a disciplina de $subjectName!\n\nPodes aceder ao teu certificado aqui: $certificateUrl\n\nMelhores cumprimentos,\nA Equipa EduGaming'
        },
      );

      try {
        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        }
      } catch (e) {
        debugPrint('Erro ao abrir cliente de email: $e');
      }
    }
  }
}
