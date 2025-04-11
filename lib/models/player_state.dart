import 'package:just_audio/just_audio.dart';

class PlayerState {
  final ProcessingState processingState;
  final bool playing;

  PlayerState(this.processingState, this.playing);
}
