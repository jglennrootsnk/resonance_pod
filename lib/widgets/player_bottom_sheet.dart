import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../utils/audio_player_manager.dart';
import '../utils/audio_helpers.dart';

class PlayerBottomSheet extends StatefulWidget {
  const PlayerBottomSheet({Key? key}) : super(key: key);

  @override
  State<PlayerBottomSheet> createState() => _PlayerBottomSheetState();
}

class _PlayerBottomSheetState extends State<PlayerBottomSheet> {
  final AudioPlayerManager _playerManager = AudioPlayerManager();
  final List<double> _availablePlaybackSpeeds = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];
  bool _showShowNotes = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          // Podcast info
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Podcast artwork
                  if (_playerManager.currentEpisode != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _playerManager.currentEpisode!.imageUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey,
                            child: const Icon(Icons.music_note, size: 64),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Episode title
                  Text(
                    _playerManager.currentEpisode?.title ?? 'No Episode',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Progress bar and timestamps
                  StreamBuilder<Duration>(
                    stream: _playerManager.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _playerManager.duration ?? Duration.zero;

                      return Column(
                        children: [
                          Slider(
                            value: position.inMilliseconds.toDouble(),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              _playerManager.seek(
                                Duration(milliseconds: value.round()),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatDuration(position)),
                                Text(formatDuration(duration)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_30),
                        onPressed: () => _playerManager.skipBackward(30),
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<bool>(
                        stream: _playerManager.playingStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;

                          return StreamBuilder<ProcessingState>(
                            stream: _playerManager
                                .audioPlayer.processingStateStream,
                            builder: (context, processingSnapshot) {
                              final processingState = processingSnapshot.data;

                              if (processingState == ProcessingState.loading ||
                                  processingState ==
                                      ProcessingState.buffering) {
                                return const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    _playerManager.pause();
                                  } else {
                                    _playerManager.play();
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_30),
                        onPressed: () => _playerManager.skipForward(30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Playback speed button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.speed),
                        label: Text('${_playerManager.playbackSpeed}x'),
                        onPressed: _changePlaybackSpeed,
                      ),
                      const SizedBox(width: 24),
                      TextButton.icon(
                        icon: Icon(
                          _showShowNotes
                              ? Icons.arrow_upward
                              : Icons.description,
                        ),
                        label: Text(
                          _showShowNotes ? 'Hide Show Notes' : 'Show Notes',
                        ),
                        onPressed: () {
                          setState(() {
                            _showShowNotes = !_showShowNotes;
                          });
                        },
                      ),
                    ],
                  ),
                  // Show notes section (conditionally displayed)
                  if (_showShowNotes &&
                      _playerManager.currentEpisode != null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Show Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Html(
                      data: _playerManager.currentEpisode!.htmlSummary,
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
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changePlaybackSpeed() {
    int currentIndex = _availablePlaybackSpeeds.indexOf(
      _playerManager.playbackSpeed,
    );
    int nextIndex = (currentIndex + 1) % _availablePlaybackSpeeds.length;
    double newSpeed = _availablePlaybackSpeeds[nextIndex];

    _playerManager.setPlaybackSpeed(newSpeed);

    // Force refresh of UI
    setState(() {});
  }
}
