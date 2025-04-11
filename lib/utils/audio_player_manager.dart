import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:io';
import '../models/podcast_episode.dart';
import '../models/player_state.dart' as app_state;
import 'audio_helpers.dart';

class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();

  factory AudioPlayerManager() {
    return _instance;
  }

  AudioPlayerManager._internal() {
    _init();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  PodcastEpisode? _currentEpisode;
  Timer? _positionSaveTimer;

  // Stream controllers
  final _currentEpisodeController = BehaviorSubject<PodcastEpisode?>();

  // Public streams
  Stream<PodcastEpisode?> get currentEpisodeStream =>
      _currentEpisodeController.stream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  // Getters
  PodcastEpisode? get currentEpisode => _currentEpisode;
  AudioPlayer get audioPlayer => _audioPlayer;

  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  Stream<app_state.PlayerState> get combinedPlayerStateStream =>
      Rx.combineLatest2<ProcessingState, bool, app_state.PlayerState>(
        _audioPlayer.processingStateStream,
        _audioPlayer.playingStream,
        (processingState, playing) =>
            app_state.PlayerState(processingState, playing),
      );

  void _init() async {
    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Start position saving timer (save every 5 seconds)
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _savePlaybackPosition();
    });

    // Load last played episode on startup
    _loadLastPlayedEpisode();

    // Listen for playback completion
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Auto-advance logic could be added here if desired
      }
    });
  }

  Future<void> _savePlaybackPosition() async {
    if (_currentEpisode != null && _audioPlayer.position.inSeconds > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Save current episode details
        await prefs.setString('last_episode_title', _currentEpisode!.title);
        await prefs.setString(
          'last_episode_audio_url',
          _currentEpisode!.audioUrl,
        );
        await prefs.setString(
          'last_episode_image_url',
          _currentEpisode!.imageUrl,
        );
        await prefs.setString('last_episode_summary', _currentEpisode!.summary);
        await prefs.setString(
          'last_episode_html_summary',
          _currentEpisode!.htmlSummary,
        );

        // Save position
        await prefs.setInt(
          'last_playback_position',
          _audioPlayer.position.inMilliseconds,
        );

        // Save speed
        await prefs.setDouble('last_playback_speed', _playbackSpeed);
      } catch (e) {
        if (kDebugMode) {
          print('Error saving playback position: $e');
        }
      }
    }
  }

  Future<void> _loadLastPlayedEpisode() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have a last played episode
      final lastEpisodeUrl = prefs.getString('last_episode_audio_url');
      if (lastEpisodeUrl == null) return;

      // Restore episode details
      final title = prefs.getString('last_episode_title') ?? 'Unknown Episode';
      final imageUrl = prefs.getString('last_episode_image_url') ?? '';
      final summary = prefs.getString('last_episode_summary') ?? '';
      final htmlSummary = prefs.getString('last_episode_html_summary') ?? '';

      // Recreate episode
      final episode = PodcastEpisode(
        title: title,
        audioUrl: lastEpisodeUrl,
        imageUrl: imageUrl,
        summary: summary,
        htmlSummary: htmlSummary,
      );

      // Restore position
      final position = prefs.getInt('last_playback_position') ?? 0;

      // Restore speed
      _playbackSpeed = prefs.getDouble('last_playback_speed') ?? 1.0;

      // Load but don't play automatically
      await playEpisode(episode, autoPlay: false);

      // Seek to saved position
      if (position > 0) {
        await _audioPlayer.seek(Duration(milliseconds: position));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading last played episode: $e');
      }
    }
  }

  Future<void> playEpisode(
    PodcastEpisode episode, {
    bool autoPlay = true,
  }) async {
    try {
      // Save current position before switching episodes
      if (_currentEpisode != null) {
        await _savePlaybackPosition();
      }

      // Stop current playback
      await _audioPlayer.stop();

      // Set new episode
      _currentEpisode = episode;
      _currentEpisodeController.add(episode);

      // Try to load from local file if available
      final localPath = await _getLocalFilePath(episode.audioUrl);

      if (localPath != null) {
        await _audioPlayer.setFilePath(localPath);
      } else {
        await _audioPlayer.setUrl(episode.audioUrl);
      }

      // Set playback speed
      await _audioPlayer.setSpeed(_playbackSpeed);

      // Play if requested
      if (autoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing episode: $e');
      }
    }
  }

  Future<String?> _getLocalFilePath(String audioUrl) async {
    if (_currentEpisode == null) return null;

    try {
      final directory = await getDownloadDirectory();
      if (directory == null) return null;

      // We need to get the podcast title from somewhere
      // This is a simplification - ideally would get from a central source
      const sanitizedPodcastTitle = "Downloaded_Podcasts"; // Default fallback
      final podcastPath = '${directory.path}/Podcasts/$sanitizedPodcastTitle';

      final sanitizedEpisodeTitle = sanitizeFileName(_currentEpisode!.title);
      final filename = '$sanitizedEpisodeTitle.mp3';
      final filePath = '$podcastPath/$filename';

      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting local file path: $e');
      }
    }

    return null;
  }

  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _savePlaybackPosition();
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> skipForward(int seconds) async {
    final position = _audioPlayer.position;
    final newPosition = position + Duration(seconds: seconds);
    await _audioPlayer.seek(newPosition);
  }

  Future<void> skipBackward(int seconds) async {
    final position = _audioPlayer.position;
    final newPosition = position - Duration(seconds: seconds);
    await _audioPlayer.seek(newPosition);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _audioPlayer.setSpeed(speed);

    // Save the speed preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_playback_speed', speed);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving playback speed: $e');
      }
    }
  }

  void dispose() {
    _positionSaveTimer?.cancel();
    _savePlaybackPosition();
    _audioPlayer.dispose();
    _currentEpisodeController.close();
  }
}
