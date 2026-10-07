import 'package:url_launcher/url_launcher.dart';

Future<bool> launchUrlFromString(String uri) async {
  try {
    final url = Uri.parse(uri);
    return await launchUrl(url);
  } catch (_) {
    return false;
  }
}
