import 'package:flutter/material.dart';
import '../app_ninja.dart';
import '../models/campaign.dart';

/// NinjaStories - Widget for displaying story-based nudges
///
/// Similar to NudgeStories from nudgecore_v2
///
/// Displays campaigns in a horizontal scrollable story format
/// (similar to Instagram/Facebook stories)
///
/// Example:
/// ```dart
/// NinjaStories(
///   id: 'home_stories',
///   titleColorLightMode: Colors.black,
///   titleColorDarkMode: Colors.white,
/// )
/// ```
class NinjaStories extends StatefulWidget {
  /// Unique identifier for this stories component
  final String id;

  /// Optional properties for filtering
  final Map<String, dynamic>? properties;

  /// Horizontal padding for the story items
  final EdgeInsets horizontalPadding;

  /// Whether to auto-focus on first story
  final bool autoFocus;

  /// Title color in light mode
  final Color titleColorLightMode;

  /// Title color in dark mode
  final Color titleColorDarkMode;

  /// Subtitle color in light mode
  final Color subtitleColorLightMode;

  /// Subtitle color in dark mode
  final Color subtitleColorDarkMode;

  /// Story item height
  final double itemHeight;

  /// Story item width
  final double itemWidth;

  const NinjaStories({
    super.key,
    required this.id,
    this.properties,
    this.horizontalPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.autoFocus = false,
    this.titleColorLightMode = Colors.black,
    this.titleColorDarkMode = Colors.white,
    this.subtitleColorLightMode = Colors.grey,
    this.subtitleColorDarkMode = Colors.grey,
    this.itemHeight = 120,
    this.itemWidth = 90,
  });

  @override
  State<NinjaStories> createState() => _NinjaStoriesState();
}

class _NinjaStoriesState extends State<NinjaStories> {
  List<Campaign> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadStories();

    // Listen for campaign updates
    AppNinja.onCampaigns.listen((campaigns) {
      if (mounted) {
        setState(() {
          _stories = campaigns
              .where((c) =>
                  c.type == 'story' && c.config['stories_id'] == widget.id)
              .toList();
        });
      }
    });
  }

  Future<void> _loadStories() async {
    try {
      final campaigns = await AppNinja.fetchCampaigns();
      if (mounted) {
        setState(() {
          _stories = campaigns
              .where((c) =>
                  c.type == 'story' && c.config['stories_id'] == widget.id)
              .toList();
        });
      }
    } catch (e) {
      AppNinja.debugLog('Error loading stories for ${widget.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDarkMode ? widget.titleColorDarkMode : widget.titleColorLightMode;
    final subtitleColor = isDarkMode
        ? widget.subtitleColorDarkMode
        : widget.subtitleColorLightMode;

    return SizedBox(
      height: widget.itemHeight + 50, // Extra space for text
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: widget.horizontalPadding,
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return _buildStoryItem(story, titleColor, subtitleColor);
        },
      ),
    );
  }

  Widget _buildStoryItem(
      Campaign story, Color titleColor, Color subtitleColor) {
    final imageUrl = story.config['image_url'] as String?;
    final thumbnail = story.config['thumbnail_url'] as String? ?? imageUrl;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _openStory(story),
        child: SizedBox(
          width: widget.itemWidth,
          child: Column(
            children: [
              // Story thumbnail with circular border
              Container(
                height: widget.itemHeight,
                width: widget.itemWidth,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue,
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: thumbnail != null
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 40),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              // Story title
              Text(
                story.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStory(Campaign story) {
    AppNinja.track('story_opened', properties: {
      'story_id': story.id,
      'stories_id': widget.id,
    });

    AppNinja.showStory(story.id, '0');

    // Navigate to story viewer if needed
    // You can implement a full-screen story viewer here
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: _StoryViewer(story: story),
        ),
      );
    }
  }
}

/// Simple story viewer widget
class _StoryViewer extends StatelessWidget {
  final Campaign story;

  const _StoryViewer({required this.story});

  @override
  Widget build(BuildContext context) {
    final imageUrl = story.config['image_url'] as String?;

    return Stack(
      children: [
        // Story content
        Container(
          color: Colors.black,
          child: Center(
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 100,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        story.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (story.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          story.description!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        // Close button
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () {
              AppNinja.track('story_closed', properties: {
                'story_id': story.id,
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}
