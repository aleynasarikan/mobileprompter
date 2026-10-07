import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showPrivacyDialog(BuildContext context) async {
  await context.push('/privacy');
}

Future<void> showAboutAppDialog(
  BuildContext context, {
  required String version,
  required String buildNumber,
}) async {
  await context.push('/about');
}
