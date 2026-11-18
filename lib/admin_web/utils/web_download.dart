// lib/admin_web/utils/web_download.dart
//
// web-only -- deliberately never imported from main.dart/app_router.dart
// (the mobile app's entrypoint), only from lib/admin_web/**, which is
// itself only reachable via lib/main_web_admin.dart (`flutter build
// web -t lib/main_web_admin.dart`). dart:html is unavailable/unused on
// the mobile build targets, but since nothing in the mobile app's
// dependency graph imports this file, it's never compiled into them.
import 'dart:html' as html;

/// Triggers a browser "Save As" download of [bytes] as [filename] --
/// the only way to get Section 8's CSV export to the user's disk from
/// a Flutter Web app without a server-rendered `<a href>` link (which
/// wouldn't carry this app's Bearer auth token; see
/// AdminRepository.fetchPlatformReportCsv's own comment).
void triggerBrowserDownload(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
