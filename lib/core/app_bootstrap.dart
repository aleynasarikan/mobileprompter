import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:talker/talker.dart';

void registerCrashHandlers(Talker talker) {
  FlutterError.onError = (FlutterErrorDetails details) {
    talker.handle(details.exception, details.stack, 'Flutter framework error');
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack, 'Uncaught platform error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    talker.handle(details.exception, details.stack, 'Widget build error');
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return const Material(
      color: Color(0xFF0B0C0F),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong. Go back and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFF4F1EA), fontSize: 16),
          ),
        ),
      ),
    );
  };
}
