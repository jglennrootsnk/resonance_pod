import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:dio/dio.dart';
import '../models/podcast_episode.dart';
import '../utils/audio_player_manager.dart';
import '../utils/audio_helpers.dart';
import '../widgets/updated_episode_list_item.dart';

class PodcastFeedScreen extends StatefulWidget {
  final String feedUrl;

  const PodcastFeedScreen({super.key, required this.feedUrl});

  @override
  State<PodcastFeedScreen> createState() => _PodcastFeedScreenState();
}

class _PodcastFeedScreenState extends State<PodcastFeedScreen> {
  final List<PodcastEpisode> _episodes = [];
  bool _isLoading = false;
  String _podcastTitle = '';
  String _podcastImageUrl = '';
  bool _downloadingAll = false;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloadedEpisodes = {};
  int? _expandedEpisodeIndex;

  // Use the global audio player manager
  final AudioPlayerManager _playerManager = AudioPlayerManager();

  @override
  void initState() {
    super.initState();
    _fetchRssFeed();
  }

  Future<void> _fetchRssFeed() async {
    setState(() {
      _isLoading = true;
      _episodes.clear();
      _podcastTitle = '';
      _podcastImageUrl = '';
      _downloadedEpisodes.clear();
      _expandedEpisodeIndex = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.feedUrl));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final channel = document.findAllElements('channel').first;

        // Get podcast title
        final titleElement = channel.findElements('title').first;
        _podcastTitle = titleElement.innerText;

        // Get podcast image
        final imageElement = channel.findElements('image').firstOrNull;
        if (imageElement != null) {
          final imageUrl = imageElement.findElements('url').firstOrNull;
          if (imageUrl != null) {
            _podcastImageUrl = imageUrl.innerText;
          }
        }

        // Get iTunes image if available (higher quality)
        final itunesImage = channel.findElements('itunes:image').firstOrNull;
        if (itunesImage != null) {
          final href = itunesImage.getAttribute('href');
          if (href != null && href.isNotEmpty) {
            _podcastImageUrl = href;
          }
        }

        // Get episodes
        for (var item in document.findAllElements('item')) {
          final title =
              item.findElements('title').firstOrNull?.innerText ?? 'No Title';

          String summary = '';
          String htmlSummary = '';
          final descriptionElement =
              item.findElements('description').firstOrNull;
          final itunesSummaryElement =
              item.findElements('itunes:summary').firstOrNull;
          final contentEncoded =
              item.findElements('content:encoded').firstOrNull;

          if (contentEncoded != null) {
            htmlSummary = contentEncoded.innerText;
            summary = htmlSummary.replaceAll(RegExp(r'<[^>]*>'), '');
          } else if (itunesSummaryElement != null) {
            htmlSummary = itunesSummaryElement.innerText;
            summary = htmlSummary.replaceAll(RegExp(r'<[^>]*>'), '');
          } else if (descriptionElement != null) {
            htmlSummary = descriptionElement.innerText;
            summary = htmlSummary.replaceAll(RegExp(r'<[^>]*>'), '');
          }

          String episodeImageUrl = _podcastImageUrl;
          final itunesEpisodeImage =
              item.findElements('itunes:image').firstOrNull;
          if (itunesEpisodeImage != null) {
            final href = itunesEpisodeImage.getAttribute('href');
            if (href != null && href.isNotEmpty) {
              episodeImageUrl = href;
            }
          }

          String audioUrl = '';
          final enclosure = item.findElements('enclosure').firstOrNull;
          if (enclosure != null) {
            final url = enclosure.getAttribute('url');
            if (url != null && url.isNotEmpty) {
              audioUrl = url;
            }
          }

          if (audioUrl.isNotEmpty) {
            _episodes.add(
              PodcastEpisode(
                title: title,
                summary: summary,
                htmlSummary: htmlSummary,
                imageUrl: episodeImageUrl,
                audioUrl: audioUrl,
              ),
            );
          }
        }

        // Check which episodes are already downloaded
        await _checkDownloadedEpisodes();

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load RSS feed: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _checkDownloadedEpisodes() async {
    if (_episodes.isEmpty || _podcastTitle.isEmpty) return;

    try {
      final directory = await getDownloadDirectory();
      if (directory == null) return;

      final sanitizedPodcastTitle = sanitizeFileName(_podcastTitle);
      final podcastPath = '${directory.path}/Podcasts/$sanitizedPodcastTitle';
      final dir = Directory(podcastPath);

      if (!await dir.exists()) return;

      for (var episode in _episodes) {
        final filename = '${sanitizeFileName(episode.title)}.mp3';
        final file = File('$podcastPath/$filename');
        if (await file.exists()) {
          setState(() {
            _downloadedEpisodes[episode.audioUrl] = true;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking downloaded episodes: $e');
      }
    }
  }

  Future<void> _downloadFile(
    String url,
    String filename,
    String title,
    String htmlSummary,
  ) async {
    try {
      // Get an appropriate directory based on platform
      final directory = await getDownloadDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine download directory'),
          ),
        );
        return;
      }

      // Create podcast-specific subfolder
      final sanitizedPodcastTitle = sanitizeFileName(_podcastTitle);
      final podcastPath = '${directory.path}/Podcasts/$sanitizedPodcastTitle';
      final dir = Directory(podcastPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '$podcastPath/$filename';

      setState(() {
        _downloadProgress[url] = 0;
      });

      // Download the audio file
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[url] = received / total;
            });
          }
        },
      );

      // Create HTML show notes file
      await createShowNotesFile(title, htmlSummary, podcastPath);

      setState(() {
        _downloadProgress.remove(url);
        _downloadedEpisodes[url] = true;
      });
    } catch (e) {
      setState(() {
        _downloadProgress.remove(url);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _downloadAllEpisodes() async {
    if (_episodes.isEmpty) return;

    setState(() {
      _downloadingAll = true;
    });

    for (var episode in _episodes) {
      if (_downloadingAll) {
        if (_downloadedEpisodes[episode.audioUrl] != true) {
          final filename = '${sanitizeFileName(episode.title)}.mp3';
          await _downloadFile(
            episode.audioUrl,
            filename,
            episode.title,
            episode.htmlSummary,
          );
        }
      } else {
        break;
      }
    }

    setState(() {
      _downloadingAll = false;
    });
  }

  void _cancelAllDownloads() {
    setState(() {
      _downloadingAll = false;
    });
  }

  void _toggleEpisodeExpansion(int index) {
    setState(() {
      if (_expandedEpisodeIndex == index) {
        _expandedEpisodeIndex = null;
      } else {
        _expandedEpisodeIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_podcastTitle.isEmpty ? 'Podcast Feed' : _podcastTitle),
        actions: [
          if (_episodes.isNotEmpty)
            IconButton(
              icon: Icon(
                _downloadingAll ? Icons.cancel : Icons.download_rounded,
              ),
              tooltip: _downloadingAll
                  ? 'Cancel Downloads'
                  : 'Download All Episodes',
              onPressed:
                  _downloadingAll ? _cancelAllDownloads : _downloadAllEpisodes,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _episodes.isEmpty
              ? const Center(child: Text('No episodes found'))
              : ListView.builder(
                  // Add padding at bottom to ensure last item is above mini player
                  padding: const EdgeInsets.only(bottom: 70),
                  itemCount: _episodes.length,
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    final isDownloading = _downloadProgress.containsKey(
                      episode.audioUrl,
                    );
                    final isDownloaded =
                        _downloadedEpisodes[episode.audioUrl] == true;
                    final progress = _downloadProgress[episode.audioUrl] ?? 0.0;
                    final isExpanded = _expandedEpisodeIndex == index;

                    // Check if this episode is currently playing
                    final isPlaying = _playerManager.currentEpisode?.audioUrl ==
                        episode.audioUrl;

                    return UpdatedEpisodeListItem(
                      episode: episode,
                      isExpanded: isExpanded,
                      isPlaying: isPlaying,
                      isDownloaded: isDownloaded,
                      isDownloading: isDownloading,
                      downloadProgress: progress,
                      onToggleExpansion: () => _toggleEpisodeExpansion(index),
                      onDownload: () {
                        final filename =
                            '${sanitizeFileName(episode.title)}.mp3';
                        _downloadFile(
                          episode.audioUrl,
                          filename,
                          episode.title,
                          episode.htmlSummary,
                        );
                      },
                      onPlay: () {
                        _playerManager.playEpisode(episode);
                      },
                    );
                  },
                ),
    );
  }
}
