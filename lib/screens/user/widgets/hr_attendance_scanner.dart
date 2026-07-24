import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../widgets/ai_translated_text.dart';

// Conditionally import MobileScanner only on mobile platforms
import 'hr_attendance_scanner_mobile.dart'
    if (dart.library.html) 'hr_attendance_scanner_stub.dart'
    if (dart.library.js_interop) 'hr_attendance_scanner_stub.dart';

export 'hr_attendance_scanner_mobile.dart'
    if (dart.library.html) 'hr_attendance_scanner_stub.dart'
    if (dart.library.js_interop) 'hr_attendance_scanner_stub.dart';
