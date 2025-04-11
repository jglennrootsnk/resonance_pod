import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}

String sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
}

Future<Directory?> getDownloadDirectory() async {
  if (kIsWeb) {
    return null; // Web doesn't support file downloads this way
  }

  if (Platform.isMacOS) {
    // For macOS, we use the Downloads directory
    final home = Platform.environment['HOME'];
    if (home != null) {
      return Directory('$home/Downloads');
    }
    // Fallback to application documents
    return await getApplicationDocumentsDirectory();
  } else if (Platform.isIOS) {
    // For iOS, use application documents
    return await getApplicationDocumentsDirectory();
  } else {
    // For Android, use external storage or documents
    try {
      return await getExternalStorageDirectory();
    } catch (e) {
      return await getApplicationDocumentsDirectory();
    }
  }
}

Future<void> createShowNotesFile(
  String title,
  String htmlSummary,
  String podcastPath,
) async {
  try {
    final notesFilename = '${sanitizeFileName(title)}.html';
    final notesFilePath = '$podcastPath/$notesFilename';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title - Show Notes</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      line-height: 1.6;
      color: #333;
    }
    h1 {
      color: #333;
      font-size: 24px;
      margin-bottom: 20px;
    }
    a {
      color: #0066cc;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
    p {
      margin-bottom: 16px;
    }
    img {
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
  <h1>$title</h1>
  <div class="show-notes">
    $htmlSummary
  </div>
</body>
</html>
''';

    final file = File(notesFilePath);
    await file.writeAsString(htmlContent);
  } catch (e) {
    if (kDebugMode) {
      print('Error creating show notes file: $e');
    }
  }
}
