import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/podcast_episode.dart';

class EpisodeNotesDialog extends StatelessWidget {
  final PodcastEpisode episode;

  const EpisodeNotesDialog({
    Key? key,
    required this.episode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Episode image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      episode.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey,
                          child:
                              const Icon(Icons.music_note, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Episode title
                  Expanded(
                    child: Text(
                      episode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Episode notes with scrolling
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show Notes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    // HTML content with clickable links
                    Html(
                      data: episode.htmlSummary,
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(16.0),
                          lineHeight: const LineHeight(1.5),
                        ),
                        "a": Style(
                          color: Colors.blue,
                          textDecoration: TextDecoration.underline,
                        ),
                        "p": Style(margin: Margins.only(bottom: 16)),
                        "h1": Style(
                          fontSize: FontSize(24.0),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 16, bottom: 8),
                        ),
                        "h2": Style(
                          fontSize: FontSize(20.0),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 16, bottom: 8),
                        ),
                        "h3": Style(
                          fontSize: FontSize(18.0),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(top: 16, bottom: 8),
                        ),
                        "li": Style(margin: Margins.only(bottom: 8)),
                        "ul": Style(margin: Margins.only(left: 16, bottom: 16)),
                        "ol": Style(margin: Margins.only(left: 16, bottom: 16)),
                        "blockquote": Style(
                          margin: Margins.only(
                              left: 16, right: 16, top: 8, bottom: 8),
                          padding: HtmlPaddings.all(8),
                          backgroundColor: const Color(0xFFF5F5F5),
                          border: const Border(
                            left: BorderSide(
                              color: Colors.grey,
                              width: 3,
                            ),
                          ),
                        ),
                      },
                      onLinkTap: (url, _, __) {
                        if (url != null) {
                          launchUrlString(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
