import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String get apiUrl {
  if (kIsWeb) return 'http://localhost:3000';

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}

final Color corPrincipal = Colors.blue.shade900;
