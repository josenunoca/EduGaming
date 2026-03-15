import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MailService {
  /// Sends an email with the certificate information.
  ///
  /// NOTE: For a real production app, this should calls a backend function (Firebase Cloud Functions)
  /// that uses a service like SendGrid, Mailgun, or AWS SES to send the email with the PDF attachment.
  ///
  /// In this MVP/Demo version, we simulate the sending and log the action.
  static Future<void> sendCertificateEmail({
    required String studentEmail,
    required String studentName,
    required String subjectName,
    required String certificateUrl,
  }) async {
    debugPrint('--- SIMULAÇÃO DE ENVIO DE EMAIL ---');
    debugPrint('Para: $studentEmail');
    debugPrint('Assunto: Certificado de Aproveitamento - $subjectName');
    debugPrint(
        'Corpo: Parabéns $studentName! Segue o link do teu certificado: $certificateUrl');
    debugPrint('----------------------------------');

    // Optional: Open mail client for the user to see, but this isn't "automatic" sending.
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: studentEmail,
      queryParameters: {
        'subject': 'Certificado de Aproveitamento - $subjectName',
        'body':
            'Olá $studentName,\n\nParabéns por concluíres a disciplina de $subjectName!\n\nPodes aceder ao teu certificado aqui: $certificateUrl\n\nMelhores cumprimentos,\nA Equipa EduGaming'
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
