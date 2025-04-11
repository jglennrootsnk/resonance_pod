import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/audio_player_manager.dart';
import '../utils/navigation_service.dart';
import 'player_bottom_sheet.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioPlayerManager _playerManager = AudioPlayerManager();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _playerManager.audioPlayer.playerStateStream.map((state) =>
          state.processingState != ProcessingState.idle &&
          _playerManager.currentEpisode != null),
      initialData: false,
      builder: (context, snapshot) {
        final isVisible = snapshot.data ?? false;

        if (!isVisible) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Episode image - Now tappable to show episode notes
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _playerManager.currentEpisode != null
                    ? GestureDetector(
                        onTap: () {
                          if (_playerManager.currentEpisode != null) {
                            NavigationService.showEpisodeNotes(
                                _playerManager.currentEpisode!);
                          }
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                _playerManager.currentEpisode!.imageUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey,
                                    child: const Icon(Icons.music_note),
                                  );
                                },
                              ),
                            ),
                            // Add a small info icon overlay to indicate it's tappable
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: 44, height: 44),
              ),
              // Episode title and progress - Tappable to show full player
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPlayerBottomSheet(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _playerManager.currentEpisode?.title ?? 'No Episode',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<Duration>(
                        stream: _playerManager.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration =
                              _playerManager.duration ?? Duration.zero;

                          return LinearProgressIndicator(
                            value: duration.inMilliseconds > 0
                                ? position.inMilliseconds /
                                    duration.inMilliseconds
                                : 0.0,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _playerManager.skipBackward(10),
                  ),
                  StreamBuilder<bool>(
                    stream: _playerManager.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;

                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (isPlaying) {
                            _playerManager.pause();
                          } else {
                            _playerManager.play();
                          }
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_30),
                    onPressed: () => _playerManager.skipForward(30),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlayerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlayerBottomSheet(),
    );
  }
}
