
import 'dart:html' as html;
import 'dart:convert';

Future<void> downloadJson(String jsonContent, String fileName) async {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
