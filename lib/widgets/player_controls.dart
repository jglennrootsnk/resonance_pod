import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/audio_helpers.dart';

class PlayerControls extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final double playbackSpeed;
  final Function() onSpeedChange;

  const PlayerControls({
    super.key,
    required this.audioPlayer,
    required this.playbackSpeed,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<Duration?>(
          stream: audioPlayer.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = audioPlayer.duration ?? Duration.zero;

            return Column(
              children: [
                Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    audioPlayer.seek(Duration(milliseconds: value.round()));
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final position = audioPlayer.position;
                audioPlayer.seek(position - const Duration(seconds: 10));
              },
            ),
            StreamBuilder<PlayerState>(
              stream: audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final processingState = snapshot.data?.processingState;
                final playing = snapshot.data?.playing ?? false;

                if (processingState == ProcessingState.loading ||
                    processingState == ProcessingState.buffering) {
                  return const SizedBox(
                    height: 48,
                    width: 48,
                    child: CircularProgressIndicator(),
                  );
                } else if (playing) {
                  return IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.pause_circle_filled),
                    onPressed: audioPlayer.pause,
                  );
                } else {
                  return IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.play_circle_filled),
                    onPressed: audioPlayer.play,
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_30),
              onPressed: () {
                final position = audioPlayer.position;
                audioPlayer.seek(position + const Duration(seconds: 30));
              },
            ),
            TextButton(
              onPressed: onSpeedChange,
              child: Text('${playbackSpeed}x'),
            ),
          ],
        ),
      ],
    );
  }
}
