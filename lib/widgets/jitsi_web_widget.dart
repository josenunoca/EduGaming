import 'package:flutter/material.dart';
import 'dart:ui_web' as ui;
import 'dart:html' as html;

class JitsiWebWidget extends StatefulWidget {
  final String roomName;
  final String displayName;
  final String email;

  const JitsiWebWidget({
    super.key,
    required this.roomName,
    required this.displayName,
    this.email = '',
  });

  @override
  State<JitsiWebWidget> createState() => _JitsiWebWidgetState();
}

class _JitsiWebWidgetState extends State<JitsiWebWidget> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'jitsi-view-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final div = html.DivElement()
        ..id = 'jitsi-container'
        ..style.width = '100%'
        ..style.height = '100%';

      final script = html.ScriptElement()
        ..text = '''
          var domain = "meet.jit.si";
          var options = {
            roomName: "${widget.roomName}",
            width: "100%",
            height: "100%",
            parentNode: document.getElementById('jitsi-container'),
            userInfo: {
              displayName: "${widget.displayName}",
              email: "${widget.email}"
            },
            interfaceConfigOverwrite: {
              SHOW_JITSI_WATERMARK: false,
            },
            configOverwrite: {
              startWithAudioMuted: false,
              startWithVideoMuted: false,
            }
          };
          var api = new JitsiMeetExternalAPI(domain, options);
        ''';

      // We need to wait for the DOM to be ready to find the parentNode
      // In this case, we append the script to the div itself
      div.append(script);
      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
