import 'package:flutter/material.dart';
import '../models/podcast_episode.dart';
import '../widgets/episode_notes_dialog.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void showEpisodeNotes(PodcastEpisode episode) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => EpisodeNotesDialog(episode: episode),
      );
    }
  }
}
