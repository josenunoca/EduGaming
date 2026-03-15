import 'package:flutter/material.dart';

class JitsiWebWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
