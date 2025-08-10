import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

Future<void> openInExternalMaps({
  required double lat,
  required double lng,
  String? label,
}) async {
  final encodedLabel = Uri.encodeComponent(label ?? 'Destination');
  final uri = Platform.isIOS
      ? Uri.parse('http://maps.apple.com/?q=$encodedLabel&ll=$lat,$lng')
      : Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    // Fallback to Google Maps web
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
