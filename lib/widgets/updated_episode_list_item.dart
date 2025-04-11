import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/podcast_episode.dart';
import '../utils/audio_player_manager.dart';

class UpdatedEpisodeListItem extends StatelessWidget {
  final PodcastEpisode episode;
  final bool isExpanded;
  final bool isPlaying;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onToggleExpansion;
  final VoidCallback onDownload;
  final VoidCallback onPlay;

  const UpdatedEpisodeListItem({
    super.key,
    required this.episode,
    required this.isExpanded,
    required this.isPlaying,
    required this.isDownloaded,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onToggleExpansion,
    required this.onDownload,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final playerManager = AudioPlayerManager();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onToggleExpansion,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      episode.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                episode.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (isDownloaded)
                              const Tooltip(
                                message: 'Downloaded',
                                child: Icon(
                                  Icons.download_done,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!isExpanded)
                          Text(
                            episode.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (isDownloading)
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: downloadProgress,
                                ),
                              )
                            else if (!isDownloaded)
                              ElevatedButton.icon(
                                onPressed: onDownload,
                                icon: const Icon(Icons.download),
                                label: const Text('Download'),
                              ),
                            const SizedBox(width: 8),
                            StreamBuilder<bool>(
                              stream: playerManager.playingStream,
                              builder: (context, snapshot) {
                                final playing = snapshot.data ?? false;

                                if (isPlaying) {
                                  return IconButton(
                                    icon: Icon(
                                      playing ? Icons.pause : Icons.play_arrow,
                                    ),
                                    onPressed: () {
                                      if (playing) {
                                        playerManager.pause();
                                      } else {
                                        playerManager.play();
                                      }
                                    },
                                  );
                                } else {
                                  return IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: onPlay,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        // If playing, show a playback position indicator
                        if (isPlaying)
                          StreamBuilder<Duration>(
                            stream: playerManager.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration =
                                  playerManager.duration ?? Duration.zero;

                              if (duration.inMilliseconds == 0) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(
                                  value: position.inMilliseconds /
                                      duration.inMilliseconds,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                Html(
                  data: episode.htmlSummary,
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(14.0),
                      lineHeight: const LineHeight(1.4),
                    ),
                    "a": Style(color: Colors.blue),
                  },
                  onLinkTap: (url, _, __) {
                    if (url != null) {
                      launchUrlString(url);
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                      Text(
                        'Tap to collapse',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
