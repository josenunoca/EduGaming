import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';
import '../../models/subject_model.dart';
import '../../models/live_session_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/jitsi_stub.dart'
    if (dart.library.js_interop) '../../widgets/jitsi_web_widget.dart';
import 'package:uuid/uuid.dart';

class VirtualClassroomTeacherScreen extends StatefulWidget {
  final Subject subject;
  final SyllabusSession session;

  const VirtualClassroomTeacherScreen({
    super.key,
    required this.subject,
    required this.session,
  });

  @override
  State<VirtualClassroomTeacherScreen> createState() =>
      _VirtualClassroomTeacherScreenState();
}

class _VirtualClassroomTeacherScreenState
    extends State<VirtualClassroomTeacherScreen> {
  final _jitsiMeet = JitsiMeet();
  LiveSession? _currentSession;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _startLive();
  }

  void _startLive() async {
    final liveSession = LiveSession(
      id: const Uuid().v4(),
      subjectId: widget.subject.id,
      teacherId: widget.subject.teacherId,
      topic: widget.session.topic,
      jitsiRoomName:
          "EduGaming_${widget.subject.id}_${DateTime.now().millisecondsSinceEpoch}",
      status: 'live',
      startTime: DateTime.now(),
    );

    await context.read<FirebaseService>().startLiveSession(liveSession);

    setState(() {
      _currentSession = liveSession;
      _isLive = true;
    });

    _joinMeeting(liveSession);
  }

  void _joinMeeting(LiveSession session) async {
    if (!kIsWeb) {
      var options = JitsiMeetConferenceOptions(
        room: session.jitsiRoomName,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "subject": session.topic,
        },
        featureFlags: {
          "unsecure-meeting-indicator.enabled": false,
          "ios.screensharing.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: "Prof. ${widget.subject.teacherId}",
          email: "teacher@edugaming.pt",
        ),
      );
      await _jitsiMeet.join(options);
    }
  }

  void _endLive() async {
    if (_currentSession != null) {
      await context.read<FirebaseService>().endLiveSession(_currentSession!.id);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Sala Virtual: ${widget.session.topic}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            onPressed: () => _endLive(),
            tooltip: 'Terminar Aula',
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentSession != null && kIsWeb
              ? JitsiWebWidget(
                  roomName: _currentSession!.jitsiRoomName,
                  displayName: "Prof. ${widget.subject.teacherId}",
                  email: "teacher@edugaming.pt",
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_call, size: 80, color: Colors.white24),
                      SizedBox(height: 16),
                      AiTranslatedText(
                        'A Aula está a decorrer...',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AiTranslatedText(
                          'Materiais de Apoio',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.session.materialIds.length,
                            itemBuilder: (context, index) {
                              final materialId =
                                  widget.session.materialIds[index];
                              final material = widget.subject.contents
                                  .firstWhere((c) => c.id == materialId);
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(material.name,
                                      style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    // Abrir visualizador
                                  },
                                  backgroundColor: Colors.white10,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
