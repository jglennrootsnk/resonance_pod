class PodcastFeed {
  final String title;
  final String description;
  final String imageUrl;
  final String firstEpisodeImageUrl;
  final String feedUrl;
  final List<String> episodeDescriptions;
  final String aiSummary;

  PodcastFeed({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.firstEpisodeImageUrl,
    required this.feedUrl,
    required this.episodeDescriptions,
    required this.aiSummary,
  });

  factory PodcastFeed.fromJson(Map<String, dynamic> json) {
    return PodcastFeed(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      firstEpisodeImageUrl: json['firstEpisodeImageUrl'] ?? '',
      feedUrl: json['feedUrl'] ?? '',
      episodeDescriptions: List<String>.from(json['episodeDescriptions'] ?? []),
      aiSummary: json['aiSummary'] ?? 'No summary available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'firstEpisodeImageUrl': firstEpisodeImageUrl,
      'feedUrl': feedUrl,
      'episodeDescriptions': episodeDescriptions,
      'aiSummary': aiSummary,
    };
  }

  PodcastFeed copyWith({
    String? title,
    String? description,
    String? imageUrl,
    String? firstEpisodeImageUrl,
    String? feedUrl,
    List<String>? episodeDescriptions,
    String? aiSummary,
  }) {
    return PodcastFeed(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      firstEpisodeImageUrl: firstEpisodeImageUrl ?? this.firstEpisodeImageUrl,
      feedUrl: feedUrl ?? this.feedUrl,
      episodeDescriptions: episodeDescriptions ?? this.episodeDescriptions,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}
