import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'podcast_feed_screen.dart';
import '../models/podcast_feed.dart';
import '../utils/audio_helpers.dart';
import '../widgets/ai_summary_dialog.dart';
import '../utils/claude_api.dart';
import 'package:xml/xml.dart' as xml;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<PodcastFeed> _feeds = [];
  bool _isLoading = false;
  final TextEditingController _feedUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  @override
  void dispose() {
    _feedUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadFeeds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final feedsJson = prefs.getStringList('podcast_feeds') ?? [];

      final List<PodcastFeed> loadedFeeds = [];
      for (var feedJson in feedsJson) {
        final feedMap = jsonDecode(feedJson);
        final feed = PodcastFeed.fromJson(feedMap);
        loadedFeeds.add(feed);
      }

      setState(() {
        _feeds.clear();
        _feeds.addAll(loadedFeeds);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feeds: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveFeeds() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<String> feedsJson = _feeds.map((feed) {
        return jsonEncode(feed.toJson());
      }).toList();

      await prefs.setStringList('podcast_feeds', feedsJson);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving feeds: ${e.toString()}')),
      );
    }
  }

  Future<void> _addFeed() async {
    final feedUrl = _feedUrlController.text.trim();
    if (feedUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid RSS feed URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if feed already exists
      if (_feeds.any((feed) => feed.feedUrl == feedUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This feed is already in your library')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch feed data
      final response = await http.get(Uri.parse(feedUrl));
      if (response.statusCode == 200) {
        final feed = await _parseFeedData(feedUrl, response.body);

        setState(() {
          _feeds.add(feed);
          _feedUrlController.clear();
        });

        await _saveFeeds();

        // Generate AI summary in background
        _generateAiSummary(feed);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load feed: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding feed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<PodcastFeed> _parseFeedData(
    String feedUrl,
    String responseBody,
  ) async {
    final document = xml.XmlDocument.parse(responseBody);
    final channel = document.findAllElements('channel').first;

    // Get podcast title
    final title = channel.findElements('title').first.innerText;

    // Get podcast description
    String description = '';
    final descriptionElement = channel.findElements('description').firstOrNull;
    if (descriptionElement != null) {
      description = descriptionElement.innerText;
    }

    // Get podcast image
    String imageUrl = '';
    final imageElement = channel.findElements('image').firstOrNull;
    if (imageElement != null) {
      final imageUrlElement = imageElement.findElements('url').firstOrNull;
      if (imageUrlElement != null) {
        imageUrl = imageUrlElement.innerText;
      }
    }

    // Get iTunes image if available (higher quality)
    final itunesImage = channel.findElements('itunes:image').firstOrNull;
    if (itunesImage != null) {
      final href = itunesImage.getAttribute('href');
      if (href != null && href.isNotEmpty) {
        imageUrl = href;
      }
    }

    // Get first episode's image if possible
    String firstEpisodeImageUrl = imageUrl;
    final items = document.findAllElements('item');
    if (items.isNotEmpty) {
      final firstItem = items.first;
      final itunesEpisodeImage =
          firstItem.findElements('itunes:image').firstOrNull;
      if (itunesEpisodeImage != null) {
        final href = itunesEpisodeImage.getAttribute('href');
        if (href != null && href.isNotEmpty) {
          firstEpisodeImageUrl = href;
        }
      }
    }

    // Extract episode descriptions for AI summary (up to 5 most recent episodes)
    final episodeDescriptions = <String>[];
    int count = 0;
    for (final item in items) {
      if (count >= 5) break;

      String summary = '';
      final descriptionElement = item.findElements('description').firstOrNull;
      final itunesSummaryElement =
          item.findElements('itunes:summary').firstOrNull;
      final contentEncoded = item.findElements('content:encoded').firstOrNull;

      if (contentEncoded != null) {
        summary = contentEncoded.innerText.replaceAll(RegExp(r'<[^>]*>'), '');
      } else if (itunesSummaryElement != null) {
        summary = itunesSummaryElement.innerText.replaceAll(
          RegExp(r'<[^>]*>'),
          '',
        );
      } else if (descriptionElement != null) {
        summary = descriptionElement.innerText.replaceAll(
          RegExp(r'<[^>]*>'),
          '',
        );
      }

      if (summary.isNotEmpty) {
        final episodeTitle =
            item.findElements('title').firstOrNull?.innerText ??
                'Episode ${count + 1}';
        episodeDescriptions.add('$episodeTitle: $summary');
        count++;
      }
    }

    return PodcastFeed(
      title: title,
      description: description,
      imageUrl: imageUrl,
      firstEpisodeImageUrl: firstEpisodeImageUrl,
      feedUrl: feedUrl,
      episodeDescriptions: episodeDescriptions,
      aiSummary: 'Generating summary...',
    );
  }

  Future<void> _removeFeed(PodcastFeed feed, bool deleteDownloads) async {
    setState(() {
      _feeds.removeWhere((f) => f.feedUrl == feed.feedUrl);
    });

    await _saveFeeds();

    if (deleteDownloads) {
      await _deleteDownloadedEpisodes(feed);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed ${feed.title}')));
  }

  Future<void> _deleteDownloadedEpisodes(PodcastFeed feed) async {
    try {
      final directory = await getDownloadDirectory();
      if (directory == null) return;

      final sanitizedPodcastTitle = sanitizeFileName(feed.title);
      final podcastPath = '${directory.path}/Podcasts/$sanitizedPodcastTitle';
      final dir = Directory(podcastPath);

      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting downloads: ${e.toString()}')),
      );
    }
  }

  Future<void> _generateAiSummary(PodcastFeed feed) async {
    if (feed.episodeDescriptions.isEmpty) return;

    try {
      final descriptions = feed.episodeDescriptions.join('\n\n');
      final prompt =
          """Skip all preamble. Provide a summary of topics covered in this podcast season based on the provided episode descriptions.
          Below the summary, include a list of keywords, referenced authors, guests, and books.
          Descriptions: $descriptions""";

      final summary = await ClaudeApi.generateSummary(prompt);

      if (summary != null && summary.isNotEmpty) {
        // Check if the summary indicates there's an API key issue
        if (summary.contains('API key')) {
          // Skip updating if there's an API key configuration issue
          return;
        }

        final index = _feeds.indexWhere((f) => f.feedUrl == feed.feedUrl);
        if (index != -1) {
          setState(() {
            _feeds[index] = _feeds[index].copyWith(aiSummary: summary);
          });
          await _saveFeeds();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating AI summary: $e');
      }
      // If there's an error, set a fallback message
      final index = _feeds.indexWhere((f) => f.feedUrl == feed.feedUrl);
      if (index != -1) {
        setState(() {
          _feeds[index] = _feeds[index].copyWith(
            aiSummary: 'Summary unavailable. Check Claude API configuration.',
          );
        });
      }
    }
  }

  void _showAiSummaryDialog(PodcastFeed feed) {
    showDialog(
      context: context,
      builder: (context) => AiSummaryDialog(
        podcastTitle: feed.title,
        summary: feed.aiSummary,
        onRegenerateSummary: () async {
          Navigator.of(context).pop();
          final index = _feeds.indexWhere((f) => f.feedUrl == feed.feedUrl);
          if (index != -1) {
            setState(() {
              _feeds[index] = _feeds[index].copyWith(
                aiSummary: 'Regenerating summary...',
              );
            });
            await _generateAiSummary(_feeds[index]);
          }
        },
      ),
    );
  }

  void _navigateToFeedScreen(PodcastFeed feed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PodcastFeedScreen(feedUrl: feed.feedUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podcast Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feedUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Podcast RSS Feed URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addFeed,
                  child: const Text('Add Feed'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _feeds.isEmpty && !_isLoading
                ? const Center(child: Text('No feeds in your library'))
                : ListView.builder(
                    itemCount: _feeds.length,
                    itemBuilder: (context, index) {
                      final feed = _feeds[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              feed.firstEpisodeImageUrl.isNotEmpty
                                  ? feed.firstEpisodeImageUrl
                                  : feed.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey,
                                  child: const Icon(Icons.podcasts),
                                );
                              },
                            ),
                          ),
                          title: Text(
                            feed.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Use a container with SingleChildScrollView for the AI summary
                              SizedBox(
                                height: 40, // Fixed height for scrollable area
                                child: SingleChildScrollView(
                                  child: Text(
                                    feed.aiSummary,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'AI Summary',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _showAiSummaryDialog(feed),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'remove') {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Remove ${feed.title}?'),
                                    content: const Text(
                                      'Do you want to delete downloaded episodes too?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _removeFeed(feed, false);
                                        },
                                        child: const Text(
                                          'No, Keep Downloads',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _removeFeed(feed, true);
                                        },
                                        child: const Text(
                                          'Yes, Delete Everything',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'remove',
                                child: Text('Remove'),
                              ),
                            ],
                          ),
                          onTap: () => _navigateToFeedScreen(feed),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
