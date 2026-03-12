import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';
import '../../models/subject_model.dart';
import '../../models/live_session_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class VirtualClassroomStudentScreen extends StatefulWidget {
  final Subject subject;
  final LiveSession liveSession;

  const VirtualClassroomStudentScreen({
    super.key,
    required this.subject,
    required this.liveSession,
  });

  @override
  State<VirtualClassroomStudentScreen> createState() => _VirtualClassroomStudentScreenState();
}

class _VirtualClassroomStudentScreenState extends State<VirtualClassroomStudentScreen> {
  final _jitsiMeet = JitsiMeet();

  @override
  void initState() {
    super.initState();
    _joinMeeting();
  }

  void _joinMeeting() async {
    var options = JitsiMeetConferenceOptions(
      room: widget.liveSession.jitsiRoomName,
      configOverrides: {
        "startWithAudioMuted": true,
        "startWithVideoMuted": true,
        "subject": widget.liveSession.topic,
      },
      featureFlags: {
        "unsecure-meeting-indicator.enabled": false,
        "raise-hand.enabled": true,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: "Aluno", // Idealmente buscar nome real do utilizador autenticado
        email: "student@edugaming.pt",
      ),
    );

    await _jitsiMeet.join(options);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Aula ao Vivo: ${widget.liveSession.topic}'),
      ),
      body: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 80, color: Colors.white24),
                SizedBox(height: 16),
                AiTranslatedText(
                  'A assistir à aula via Jitsi Meet...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                   const Icon(Icons.record_voice_over, color: Colors.greenAccent, size: 16),
                   const SizedBox(width: 8),
                   const AiTranslatedText('Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
           Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AiTranslatedText(
                    'Materiais da Aula',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                   const AiTranslatedText(
                    'Acompanhe os materiais partilhados pelo professor.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
