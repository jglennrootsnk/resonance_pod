import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:dio/dio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../models/podcast_episode.dart';
import '../models/player_state.dart' as app_state;
import '../widgets/episode_list_item.dart';
import '../utils/audio_helpers.dart';

class PodcastRSSReader extends StatefulWidget {
  const PodcastRSSReader({super.key});

  @override
  State<PodcastRSSReader> createState() => _PodcastRSSReaderState();
}

class _PodcastRSSReaderState extends State<PodcastRSSReader> {
  final TextEditingController _urlController = TextEditingController();
  final List<PodcastEpisode> _episodes = [];
  bool _isLoading = false;
  String _podcastTitle = '';
  String _podcastImageUrl = '';
  bool _downloadingAll = false;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloadedEpisodes = {};
  int? _expandedEpisodeIndex;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  double _playbackSpeed = 1.0;
  final List<double> _availablePlaybackSpeeds = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  void initState() {
    super.initState();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchRssFeed() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid RSS feed URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _episodes.clear();
      _podcastTitle = '';
      _podcastImageUrl = '';
      _downloadedEpisodes.clear();
      _expandedEpisodeIndex = null;
    });

    try {
      final response = await http.get(Uri.parse(url));
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

  Future<String?> _getLocalFilePath(String audioUrl) async {
    final directory = await getDownloadDirectory();
    if (directory == null) return null;

    final sanitizedPodcastTitle = sanitizeFileName(_podcastTitle);
    final podcastPath = '${directory.path}/Podcasts/$sanitizedPodcastTitle';

    // Find episode with this URL
    final episode = _episodes.firstWhere((e) => e.audioUrl == audioUrl);
    final filename = '${sanitizeFileName(episode.title)}.mp3';
    final filePath = '$podcastPath/$filename';

    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  Future<void> _playAudio(String audioUrl) async {
    if (_currentlyPlayingUrl == audioUrl && _audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }

    try {
      // Stop current playback if any
      await _audioPlayer.stop();

      // Check if the episode is downloaded
      if (_downloadedEpisodes[audioUrl] == true) {
        final localPath = await _getLocalFilePath(audioUrl);
        if (localPath != null) {
          await _audioPlayer.setFilePath(localPath);
        } else {
          await _audioPlayer.setUrl(audioUrl);
        }
      } else {
        await _audioPlayer.setUrl(audioUrl);
      }

      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.play();
      setState(() {
        _currentlyPlayingUrl = audioUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: ${e.toString()}')),
      );
    }
  }

  void _changePlaybackSpeed() {
    int currentIndex = _availablePlaybackSpeeds.indexOf(_playbackSpeed);
    int nextIndex = (currentIndex + 1) % _availablePlaybackSpeeds.length;
    double newSpeed = _availablePlaybackSpeeds[nextIndex];

    setState(() {
      _playbackSpeed = newSpeed;
    });

    _audioPlayer.setSpeed(newSpeed);
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

  Stream<app_state.PlayerState> get _playerStateStream =>
      Rx.combineLatest2<ProcessingState, bool, app_state.PlayerState>(
        _audioPlayer.processingStateStream,
        _audioPlayer.playingStream,
        (processingState, playing) =>
            app_state.PlayerState(processingState, playing),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podcast RSS Reader')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Podcast RSS Feed URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchRssFeed,
                  child: const Text('Load'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          if (_podcastTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _podcastTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _downloadingAll
                            ? _cancelAllDownloads
                            : _downloadAllEpisodes,
                        icon: Icon(
                          _downloadingAll
                              ? Icons.cancel
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          _downloadingAll ? 'Cancel' : 'Download All Episodes',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _episodes.isEmpty && !_isLoading
                ? const Center(child: Text('No episodes found'))
                : ListView.builder(
                    itemCount: _episodes.length,
                    itemBuilder: (context, index) {
                      final episode = _episodes[index];
                      final isDownloading = _downloadProgress.containsKey(
                        episode.audioUrl,
                      );
                      final isDownloaded =
                          _downloadedEpisodes[episode.audioUrl] == true;
                      final progress =
                          _downloadProgress[episode.audioUrl] ?? 0.0;
                      final isExpanded = _expandedEpisodeIndex == index;
                      final isPlaying =
                          _currentlyPlayingUrl == episode.audioUrl;

                      return EpisodeListItem(
                        episode: episode,
                        isExpanded: isExpanded,
                        isPlaying: isPlaying,
                        isDownloaded: isDownloaded,
                        isDownloading: isDownloading,
                        downloadProgress: progress,
                        audioPlayer: _audioPlayer,
                        playbackSpeed: _playbackSpeed,
                        playerStateStream: _playerStateStream,
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
                        onPlay: () => _playAudio(episode.audioUrl),
                        onSpeedChange: _changePlaybackSpeed,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
