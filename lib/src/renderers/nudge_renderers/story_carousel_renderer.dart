import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/campaign.dart';

/// StoryCarousel Nudge Renderer
///
/// Renders Instagram-style story carousel:
/// - Swipeable slides with page indicator
/// - Auto-progress timer per slide
/// - Pause on tap and hold
/// - Progress bars at top
class StoryCarouselNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const StoryCarouselNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<StoryCarouselNudgeRenderer> createState() =>
      _StoryCarouselNudgeRendererState();
}

class _StoryCarouselNudgeRendererState extends State<StoryCarouselNudgeRenderer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentPage = 0;
  Timer? _autoProgressTimer;
  bool _isPaused = false;
  List<Map<String, dynamic>> _slides = [];

  @override
  void initState() {
    super.initState();

    final config = widget.campaign.config;
    _slides = (config['slides'] as List?)?.cast<Map<String, dynamic>>() ??
        [config]; // Fallback to single slide

    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: (config['slideDuration'] as int?) ?? 5),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSlide();
      }
    });

    _startProgress();
  }

  @override
  void dispose() {
    _autoProgressTimer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progressController.forward(from: 0);
  }

  void _pauseProgress() {
    setState(() {
      _isPaused = true;
    });
    _progressController.stop();
  }

  void _resumeProgress() {
    setState(() {
      _isPaused = false;
    });
    _progressController.forward();
  }

  void _nextSlide() {
    if (_currentPage < _slides.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    } else {
      // End of carousel
      _handleDismiss();
    }
  }

  void _previousSlide() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    }
  }

  Future<void> _handleDismiss() async {
    widget.onDismiss?.call();
  }

  void _handleCTA(String action) {
    final config = widget.campaign.config;
    widget.onCTAClick?.call(action, config);
    _handleDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black, // Full-screen immersive
      child: Stack(
        children: [
          // Story slides
          PageView.builder(
            controller: _pageController,
            physics:
                const NeverScrollableScrollPhysics(), // Control via buttons
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _startProgress();
            },
            itemBuilder: (context, index) {
              return _buildSlide(_slides[index]);
            },
          ),

          // Progress bars at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: List.generate(_slides.length, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: index == _currentPage
                        ? AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressController.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          )
                        : index < _currentPage
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _handleDismiss,
            ),
          ),

          // Tap zones for navigation
          Row(
            children: [
              // Left tap - previous slide
              Expanded(
                child: GestureDetector(
                  onTap: _previousSlide,
                  onLongPress: _pauseProgress,
                  onLongPressUp: _resumeProgress,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Right tap - next slide
              Expanded(
                child: GestureDetector(
                  onTap: _nextSlide,
                  onLongPress: _pauseProgress,
                  onLongPressUp: _resumeProgress,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),

          // Pause indicator
          if (_isPaused)
            const Center(
              child: Icon(
                Icons.pause_circle_filled,
                color: Colors.white,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    final imageUrl = slide['imageUrl']?.toString();
    final videoUrl = slide['videoUrl']?.toString();
    final title = slide['title']?.toString();
    final text = slide['text']?.toString();
    final buttonText = slide['buttonText']?.toString();
    final textColor = _parseColor(slide['textColor']) ?? Colors.white;

    return Stack(
      children: [
        // Background image/video
        if (imageUrl != null)
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1F2937),
              ),
            ),
          )
        else if (videoUrl != null)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1F2937),
              child: const Center(
                child: Text(
                  'Video Player',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _parseColor(slide['backgroundColor']) ??
                        const Color(0xFF6366F1),
                    _parseColor(slide['backgroundColor'])?.withOpacity(0.7) ??
                        const Color(0xFF8B5CF6),
                  ],
                ),
              ),
            ),
          ),

        // Gradient overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: 100,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ),

              // Text
              if (text != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                ),

              // CTA Button
              if (buttonText != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleCTA('primary'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is Color) return color;

    final colorStr = color.toString();
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.replaceFirst('#', '');
      final value = int.tryParse('FF$hexColor', radix: 16);
      return value != null ? Color(value) : null;
    }
    return null;
  }
}
