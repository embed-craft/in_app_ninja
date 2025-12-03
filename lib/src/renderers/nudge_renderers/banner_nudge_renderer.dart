import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../models/campaign.dart';

class BannerNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const BannerNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<BannerNudgeRenderer> createState() => _BannerNudgeRendererState();
}

class _BannerNudgeRendererState extends State<BannerNudgeRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final Map<String, dynamic> _formData = {};
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    final config = widget.campaign.config;
    final duration = config['animationDuration'] as int? ?? 300;
    final position = config['position'] as String? ?? 'top';
    final isTop = position == 'top';
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, isTop ? -1 : 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    final autoClose = config['autoClose'] as bool? ?? false;
    if (autoClose) {
      final autoCloseDuration = (config['autoCloseDuration'] as num?)?.toInt() ?? 5000;
      _autoCloseTimer = Timer(Duration(milliseconds: autoCloseDuration), () {
        if (mounted) _handleDismiss();
      });
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final width = MediaQuery.of(context).size.width;
    
    // Responsive overrides
    final responsiveConfig = _resolveResponsiveConfig(config, width);
    
    final position = responsiveConfig['position'] as String? ?? 'top';
    final isTop = position == 'top';
    
    final mode = responsiveConfig['mode'] as String? ?? 'default';
    final isImageOnly = mode == 'image-only';
    
    final height = _parseHeight(responsiveConfig['height'], MediaQuery.of(context).size.height);
    final backgroundColor = isImageOnly
        ? Colors.transparent
        : (_parseColor(responsiveConfig['backgroundColor']) ?? Colors.white);
    final backgroundImageUrl = responsiveConfig['backgroundImageUrl'] as String?;
    final backgroundSize = responsiveConfig['backgroundSize'] as String? ?? 'cover';
    final opacity = (responsiveConfig['opacity'] as num?)?.toDouble() ?? 1.0;

    // Advanced Styling
    final gradient = _parseGradient(responsiveConfig['backgroundGradient'] ?? responsiveConfig['style']?['background']);
    final borderRadius = _parseBorderRadius(responsiveConfig['borderRadius']);
    final padding = isImageOnly ? EdgeInsets.zero : _parseEdgeInsets(responsiveConfig['padding']);
    final margin = _parseEdgeInsets(responsiveConfig['margin']);
    final showCloseButton = responsiveConfig['showCloseButton'] != false;
    final shadows = _parseBoxShadow(responsiveConfig['shadows'] as List?);
    final elevation = (responsiveConfig['elevation'] as num?)?.toDouble() ?? 2.0;

    // Border Logic
    final borderConfig = responsiveConfig['border'];
    final isDashedBorder = borderConfig is Map && borderConfig['style'] == 'dashed';
    final borderColor = borderConfig is Map ? (_parseColor(borderConfig['color']) ?? Colors.transparent) : Colors.transparent;
    final borderWidth = borderConfig is Map ? (borderConfig['width'] as num?)?.toDouble() ?? 0.0 : 0.0;

    // Overlay Logic
    final showOverlay = responsiveConfig['overlay'] == true;
    final overlayColor = _parseColor(responsiveConfig['overlayColor']) ?? Colors.black.withOpacity(0.5);
    final overlayBlur = (responsiveConfig['overlayBlur'] as num?)?.toDouble() ?? 0.0;

    // Dismissible Logic
    final dismissible = responsiveConfig['dismissible'] == true;

    // Default shadow if none provided
    final effectiveShadows = isImageOnly ? <BoxShadow>[] : (shadows ?? [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: elevation * 2,
        offset: Offset(0, isTop ? elevation : -elevation),
      )
    ]);

    Widget bannerContent = Material(
      color: Colors.transparent,
      child: Container(
        width: margin == null ? width : width - margin.horizontal,
        height: height,
        margin: margin,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5, // Limit banner height
          minHeight: isImageOnly ? (height == null ? 150 : 0) : 100,
        ),
        decoration: BoxDecoration(
          color: gradient == null ? backgroundColor : null,
          gradient: gradient,
          image: backgroundImageUrl != null && backgroundImageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(backgroundImageUrl),
                  fit: _parseBoxFit(backgroundSize),
                )
              : null,
          borderRadius: borderRadius,
          boxShadow: effectiveShadows,
          border: isDashedBorder ? null : _parseBorder(responsiveConfig['border']),
        ),
        child: Stack(
          children: [
            if (isDashedBorder)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: borderColor,
                    strokeWidth: borderWidth,
                    radius: (borderRadius as BorderRadius?)?.topLeft.x ?? 0,
                  ),
                ),
              ),
            SingleChildScrollView(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: _buildContent(responsiveConfig),
              ),
            ),
            if (showCloseButton)
              _buildCloseButton(responsiveConfig, isImageOnly),
          ],
        ),
      ),
    );

    if (dismissible) {
      bannerContent = Dismissible(
        key: UniqueKey(),
        direction: isTop ? DismissDirection.up : DismissDirection.down,
        onDismissed: (_) => _handleDismiss(),
        child: bannerContent,
      );
    }

    // Entrance Animation Wrapper
    return Stack(
      children: [
        if (showOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: _handleDismiss,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: overlayBlur, sigmaY: overlayBlur),
                child: Container(color: overlayColor),
              ),
            ),
          ),
        _EntranceAnimator(
          animation: responsiveConfig['animation'] as Map<String, dynamic>? ?? {},
          child: Align(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: Opacity(
              opacity: opacity,
              child: bannerContent,
            ),
          ),
        ),
      ],
    );
  }

  BoxBorder? _parseBorder(dynamic value) {
    if (value is Map) {
      final color = _parseColor(value['color']) ?? Colors.transparent;
      final width = (value['width'] as num?)?.toDouble() ?? 0.0;
      final style = value['style'] == 'dashed' ? BorderStyle.none : BorderStyle.solid;
      if (width > 0) {
        return Border.all(color: color, width: width, style: style);
      }
    }
    return null;
  }

  Widget _buildCloseButton(Map<String, dynamic> config, bool isImageOnly) {
    final position = config['closeButtonPosition'] as String? ?? 'top-right';
    final color = _parseColor(config['closeButtonColor']) ?? (isImageOnly ? Colors.white : Colors.grey);
    final bgColor = _parseColor(config['closeButtonBackgroundColor']) ?? (isImageOnly ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.1));
    final size = (config['closeButtonSize'] as num?)?.toDouble() ?? 20.0;
    final iconStyle = config['closeButtonIcon'] as String? ?? 'x';

    double? top, right, bottom, left;
    if (position == 'top-right') { top = 8; right = 8; }
    else if (position == 'top-left') { top = 8; left = 8; }
    else if (position == 'bottom-right') { bottom = 8; right = 8; }
    else if (position == 'bottom-left') { bottom = 8; left = 8; }

    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: GestureDetector(
        onTap: _handleDismiss,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: Icon(
            iconStyle == 'arrow' ? Icons.arrow_downward : Icons.close,
            size: size,
            color: color
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _resolveResponsiveConfig(Map<String, dynamic> config, double screenWidth) {
    // Simple pass-through for now, can be expanded for breakpoints
    return config;
  }

  Widget _buildContent(Map<String, dynamic> config) {
    if (config['components'] != null && config['components'] is List) {
      return _buildFlexibleLayout(config);
    }
    return const Center(child: Text('No components configured'));
  }

  Widget _buildFlexibleLayout(Map<String, dynamic> config) {
    final components = config['components'] as List;
    final layout = config['layout'] as Map<String, dynamic>? ?? {};
    
    final direction = layout['direction'] == 'row' ? Axis.horizontal : Axis.vertical;
    final gap = (layout['gap'] as num?)?.toDouble() ?? 0.0;
    final mainAxisAlignment = _parseMainAxisAlignment(layout['justifyContent']);
    final crossAxisAlignment = _parseCrossAxisAlignment(layout['alignItems']);
    final wrap = layout['flexWrap'] == 'wrap';

    // Sort by order
    final sortedComponents = List<Map<String, dynamic>>.from(
      components.map((c) => c as Map<String, dynamic>),
    )..sort((a, b) {
        final aOrder = (a['position']?['order'] as num?) ?? 0;
        final bOrder = (b['position']?['order'] as num?) ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final flowComponents = <Widget>[];
    final absoluteComponents = <Widget>[];

    for (final c in sortedComponents) {
      final style = c['style'] as Map<String, dynamic>? ?? {};
      final position = style['position'] as String? ?? 'relative';
      
      Widget child = _buildComponent(c);

      // Wrap in Entrance Animator
      if (c['animation'] != null) {
        child = _EntranceAnimator(
          animation: c['animation'],
          child: child,
        );
      }

      if (position == 'absolute' || position == 'fixed') {
        // Handle Absolute Positioning
        absoluteComponents.add(Positioned(
          top: (style['top'] as num?)?.toDouble(),
          right: (style['right'] as num?)?.toDouble(),
          bottom: (style['bottom'] as num?)?.toDouble(),
          left: (style['left'] as num?)?.toDouble(),
          child: child,
        ));
      } else {
        // Handle Flex Child Properties for Relative Items
        final flexChild = c['flexChild'] as Map<String, dynamic>?;
        if (flexChild != null) {
          final flexGrow = (flexChild['flexGrow'] as num?)?.toInt() ?? 0;
          final flexShrink = (flexChild['flexShrink'] as num?)?.toInt() ?? 1;
          
          final minWidth = (flexChild['minWidth'] as num?)?.toDouble() ?? 0.0;
          final maxWidth = (flexChild['maxWidth'] as num?)?.toDouble() ?? double.infinity;
          final minHeight = (flexChild['minHeight'] as num?)?.toDouble() ?? 0.0;
          final maxHeight = (flexChild['maxHeight'] as num?)?.toDouble() ?? double.infinity;

          if (minWidth > 0 || maxWidth < double.infinity || minHeight > 0 || maxHeight < double.infinity) {
            child = ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth,
                maxWidth: maxWidth,
                minHeight: minHeight,
                maxHeight: maxHeight,
              ),
              child: child,
            );
          }

          if (!wrap && (flexGrow > 0 || flexShrink != 1)) {
            child = Flexible(
              flex: flexGrow,
              fit: flexGrow > 0 ? FlexFit.tight : FlexFit.loose,
              child: child,
            );
          }
        }
        flowComponents.add(child);
      }
    }

    Widget flowWidget;
    if (wrap) {
      flowWidget = Wrap(
        direction: direction,
        spacing: gap,
        runSpacing: gap,
        alignment: _wrapAlignment(mainAxisAlignment),
        crossAxisAlignment: _wrapCrossAlignment(crossAxisAlignment),
        children: flowComponents,
      );
    } else {
      if (gap > 0) {
        final spacedChildren = <Widget>[];
        for (var i = 0; i < flowComponents.length; i++) {
          spacedChildren.add(flowComponents[i]);
          if (i < flowComponents.length - 1) {
            spacedChildren.add(SizedBox(
              width: direction == Axis.horizontal ? gap : 0,
              height: direction == Axis.vertical ? gap : 0,
            ));
          }
        }
        flowWidget = Flex(
          direction: direction,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: spacedChildren,
        );
      } else {
        flowWidget = Flex(
          direction: direction,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: flowComponents,
        );
      }
    }

    if (absoluteComponents.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          flowWidget,
          ...absoluteComponents,
        ],
      );
    }

    return flowWidget;
  }

  Widget _buildTextComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    String text = content['text'] as String? ?? '';
    text = _substituteVariables(text, widget.campaign.config['variables'] as List?);

    // Apply Text Transform
    final transform = style['textTransform'] as String?;
    if (transform == 'uppercase') text = text.toUpperCase();
    if (transform == 'lowercase') text = text.toLowerCase();
    if (transform == 'capitalize') {
      text = text.split(' ').map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '').join(' ');
    }

    return Text(
      text,
      style: _parseTextStyle(style).copyWith(
        fontSize: (style['fontSize'] as num?)?.toDouble() ?? 16.0,
        color: _parseColor(style['color']) ?? const Color(0xFF1F2937),
      ),
      textAlign: _parseTextAlign(style['textAlign']),
      maxLines: (style['maxLines'] as num?)?.toInt(),
      overflow: _parseTextOverflow(style['overflow']),
      softWrap: true,
    );
  }

  Widget _buildImageComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    final url = content['url'] as String? ?? '';
    final overlayColor = _parseColor(content['overlay']);

    if (url.isEmpty) return const SizedBox.shrink();

    Widget imageWidget = Image.network(
      url,
      fit: _parseBoxFit(content['objectFit'] ?? style['fit']),
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image, color: Colors.grey[400]),
      ),
    );

    if (overlayColor != null) {
      imageWidget = Stack(
        fit: StackFit.passthrough,
        children: [
          imageWidget,
          Positioned.fill(
            child: Container(color: overlayColor),
          ),
        ],
      );
    }

    // Apply Image Filter
    final filter = style['filter'] as Map<String, dynamic>?;
    if (filter != null) {
      if (filter['type'] == 'blur') {
        final sigma = (filter['value'] as num?)?.toDouble() ?? 0.0;
        if (sigma > 0) {
          imageWidget = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: imageWidget,
          );
        }
      } else if (filter['type'] == 'grayscale') {
        final value = (filter['value'] as num?)?.toDouble() ?? 0.0; // 0 to 1
        if (value > 0) {
          imageWidget = ColorFiltered(
            colorFilter: ColorFilter.matrix(<double>[
              0.2126 + 0.7874 * (1 - value), 0.7152 - 0.7152 * (1 - value), 0.0722 - 0.0722 * (1 - value), 0, 0,
              0.2126 - 0.2126 * (1 - value), 0.7152 + 0.2848 * (1 - value), 0.0722 - 0.0722 * (1 - value), 0, 0,
              0.2126 - 0.2126 * (1 - value), 0.7152 - 0.7152 * (1 - value), 0.0722 + 0.9278 * (1 - value), 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: imageWidget,
          );
        }
      }
    }

    // Apply Aspect Ratio
    final aspectRatio = style['aspectRatio'];
    if (aspectRatio != null) {
      double? ratio;
      if (aspectRatio is num) {
        ratio = aspectRatio.toDouble();
      } else if (aspectRatio is String) {
        // Parse "16/9" or "1.5"
        if (aspectRatio.contains('/')) {
          final parts = aspectRatio.split('/');
          if (parts.length == 2) {
            final w = double.tryParse(parts[0]);
            final h = double.tryParse(parts[1]);
            if (w != null && h != null && h != 0) {
              ratio = w / h;
            }
          }
        } else {
          ratio = double.tryParse(aspectRatio);
        }
      }

      if (ratio != null && ratio > 0) {
        imageWidget = AspectRatio(
          aspectRatio: ratio,
          child: imageWidget,
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        (style['borderRadius'] as num?)?.toDouble() ?? 0,
      ),
      child: imageWidget,
    );
  }

  Widget _buildButtonComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    String text = content['label'] as String? ?? content['text'] as String? ?? 'Button';
    text = _substituteVariables(text, widget.campaign.config['variables'] as List?);
    
    final action = content['action'] as String? ?? 'default';
    final variant = content['buttonVariant'] as String? ?? 'primary';
    final themeColor = _parseColor(content['themeColor']) ?? _parseColor(style['backgroundColor']) ?? const Color(0xFF6366F1);
    final textColor = _parseColor(content['textColor']) ?? _parseColor(style['color']) ?? Colors.white;
    final fontSize = (content['fontSize'] as num?)?.toDouble() ?? (style['fontSize'] as num?)?.toDouble() ?? 14.0;
    final fontWeight = _parseFontWeight(content['fontWeight'] ?? style['fontWeight'] ?? 'medium');
    final borderRadius = (style['borderRadius'] as num?)?.toDouble() ?? 8.0;
    
    // Icon Logic
    final iconName = content['buttonIcon'] as String?;
    final iconPosition = content['buttonIconPosition'] as String? ?? 'right';
    Widget? iconWidget;
    if (iconName != null) {
      final iconData = _getIconData(iconName);
      if (iconData != null) {
        iconWidget = Icon(iconData, size: 16, color: textColor);
      }
    }

    // Base Container Decoration
    BoxDecoration decoration = BoxDecoration(
      color: themeColor,
      borderRadius: BorderRadius.circular(borderRadius),
    );
    
    // Text Style
    TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: textColor,
      fontFamily: style['fontFamily'] as String?,
    );

    // Variant Specific Logic
    Widget buttonContent;
    EdgeInsets padding = _parseEdgeInsets(style['padding']) ?? const EdgeInsets.symmetric(vertical: 14, horizontal: 24);
    
    switch (variant) {
      case 'secondary':
        decoration = decoration.copyWith(color: themeColor.withOpacity(0.2));
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'outline':
        decoration = decoration.copyWith(
          color: Colors.transparent,
          border: Border.all(color: themeColor, width: 2),
        );
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'ghost':
        decoration = decoration.copyWith(color: Colors.transparent);
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'soft':
        decoration = decoration.copyWith(color: themeColor.withOpacity(0.15));
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'glass':
        decoration = decoration.copyWith(
          color: themeColor.withOpacity(0.4),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: const Color(0x261F2687), blurRadius: 32, offset: const Offset(0, 8)),
          ],
        );
        break;
      case 'gradient':
        decoration = decoration.copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [themeColor, _adjustColorBrightness(themeColor, -0.2)],
          ),
          boxShadow: [
            BoxShadow(color: themeColor.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        );
        break;
      case '3d':
        decoration = decoration.copyWith(
          color: themeColor,
          boxShadow: [
            BoxShadow(color: _adjustColorBrightness(themeColor, -0.3), offset: const Offset(0, 5), blurRadius: 0),
          ],
        );
        break;
      case 'elevated':
        decoration = decoration.copyWith(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 6)),
          ],
        );
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'neumorphic':
        decoration = decoration.copyWith(
          color: const Color(0xFFEEF2FF),
          boxShadow: [
            const BoxShadow(color: Color(0xFFD1D5DB), offset: Offset(5, 5), blurRadius: 10),
            const BoxShadow(color: Colors.white, offset: Offset(-5, -5), blurRadius: 10),
          ],
        );
        textStyle = textStyle.copyWith(color: themeColor);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'pill':
        decoration = decoration.copyWith(borderRadius: BorderRadius.circular(9999));
        break;
      case 'underline':
        decoration = const BoxDecoration(
          border: Border(bottom: BorderSide(width: 2)),
        ).copyWith(border: Border(bottom: BorderSide(color: themeColor, width: 2)));
        textStyle = textStyle.copyWith(color: themeColor);
        padding = const EdgeInsets.symmetric(vertical: 4, horizontal: 0);
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: themeColor);
        break;
      case 'glow':
        decoration = decoration.copyWith(
          boxShadow: [
            BoxShadow(color: themeColor, blurRadius: 15, spreadRadius: 0),
            BoxShadow(color: themeColor.withOpacity(0.5), blurRadius: 30, spreadRadius: 0),
          ],
        );
        break;
      case 'cyberpunk':
        decoration = decoration.copyWith(
          color: const Color(0xFFF3E600), // Default cyberpunk yellow
          borderRadius: BorderRadius.zero,
        );
        textStyle = textStyle.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        );
        text = text.toUpperCase();
        if (iconWidget != null) iconWidget = Icon((iconWidget as Icon).icon, size: 16, color: Colors.black);
        break;
      case 'comic':
        decoration = decoration.copyWith(
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: [
             const BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
          ],
          borderRadius: BorderRadius.zero,
        );
        textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        text = text.toUpperCase();
        break;
      case 'skeuomorphic':
        decoration = decoration.copyWith(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_adjustColorBrightness(themeColor, 0.2), themeColor],
          ),
          border: Border.all(color: _adjustColorBrightness(themeColor, -0.2)),
          boxShadow: [
            const BoxShadow(color: Colors.white, offset: Offset(0, 1), blurRadius: 0, spreadRadius: -1), // Inset mimic
            const BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
          ],
        );
        break;
      case 'liquid':
        decoration = decoration.copyWith(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(70),
            bottomRight: Radius.circular(70),
            bottomLeft: Radius.circular(30),
          ), // Simplified organic shape
          boxShadow: [
            BoxShadow(color: themeColor.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        );
        break;
      case 'shine':
        decoration = decoration.copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor,
              Colors.white.withOpacity(0.2),
              themeColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        );
        break;
      case 'block':
        // Block style handled by width: double.infinity in container
        textStyle = textStyle.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1);
        text = text.toUpperCase();
        break;
      case 'two-tone':
         decoration = decoration.copyWith(
          color: Colors.white,
          border: Border.all(color: themeColor.withOpacity(0.2)),
          padding: EdgeInsets.zero, // Reset padding for custom layout
        );
        textStyle = textStyle.copyWith(color: themeColor);
        break;
    }

    // Build Content Row
    List<Widget> rowChildren = [
      Text(text, style: textStyle),
    ];

    if (iconWidget != null) {
      if (iconPosition == 'left') {
        rowChildren.insert(0, Padding(padding: const EdgeInsets.only(right: 8), child: iconWidget));
      } else {
        rowChildren.add(Padding(padding: const EdgeInsets.only(left: 8), child: iconWidget));
      }
    }

    buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: rowChildren,
    );

    // Special handling for Two-Tone
    if (variant == 'two-tone') {
      buttonContent = Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(text, textAlign: TextAlign.center, style: textStyle),
            ),
          ),
          if (iconWidget != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: themeColor,
              child: Icon((iconWidget as Icon).icon, color: Colors.white, size: 16),
            ),
        ],
      );
    }

    // Special handling for Cyberpunk ClipPath
    Widget container = Container(
      decoration: variant == 'cyberpunk' ? null : decoration, // ClipPath handles decoration for cyberpunk
      padding: variant == 'two-tone' ? EdgeInsets.zero : padding,
      width: variant == 'block' ? double.infinity : null,
      child: buttonContent,
    );

    if (variant == 'block') {
      // Wrap in LayoutBuilder to prevent crash in Row (unbounded width)
      container = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedWidth) {
            return Container(
              decoration: variant == 'cyberpunk' ? null : decoration,
              padding: variant == 'two-tone' ? EdgeInsets.zero : padding,
              width: double.infinity,
              child: buttonContent,
            );
          } else {
            // Fallback for unbounded width (e.g. inside Row)
            return Container(
              decoration: variant == 'cyberpunk' ? null : decoration,
              padding: variant == 'two-tone' ? EdgeInsets.zero : padding,
              child: buttonContent,
            );
          }
        },
      );
    }

    if (variant == 'cyberpunk') {
      container = ClipPath(
        clipper: _CyberpunkClipper(),
        child: Container(
          decoration: decoration,
          padding: padding,
          child: buttonContent,
        ),
      );
    }
    
    if (variant == 'glass') {
       container = ClipRRect(
         borderRadius: BorderRadius.circular(borderRadius),
         child: BackdropFilter(
           filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
           child: container,
         ),
       );
    }

    return GestureDetector(
      onTap: () {
        final payload = Map<String, dynamic>.from(component);
        payload['formData'] = _formData;
        widget.onCTAClick?.call(action, payload);
      },
      child: container,
    );
  }

  Widget _buildVideoComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final height = (style['height'] as num?)?.toDouble() ?? 200.0;
    final width = (style['width'] as num?)?.toDouble();
    final autoPlay = content['autoPlay'] as bool? ?? false;
    final loop = content['loop'] as bool? ?? false;

    Widget videoContent = Stack(
      fit: StackFit.expand,
      children: [
        if (content['thumbnail'] != null)
          Image.network(
            content['thumbnail'],
            fit: BoxFit.cover,
            color: Colors.white.withOpacity(0.8),
            colorBlendMode: BlendMode.modulate,
          )
        else
          const Center(child: Icon(Icons.videocam, color: Colors.white54, size: 48)),
        
        if (!autoPlay)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
          ),
        
        if (content['showControls'] != false)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.black54,
              child: Row(
                children: [
                  Icon(autoPlay ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: Colors.grey,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.3,
                        child: Container(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(loop ? Icons.repeat_one : Icons.volume_up, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
      ],
    );

    if (width == null) {
      // Use AspectRatio to enforce a finite width based on height if width is not provided
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: videoContent,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0),
      ),
      child: videoContent,
    );
  }

  Widget _buildComponent(Map<String, dynamic> component) {
    final type = component['type'] as String? ?? 'text';
    final visible = component['visible'];
    if (visible != null && !_evaluateVisibility(visible, widget.campaign.config['variables'] as Map<String, dynamic>? ?? {})) {
      return const SizedBox.shrink();
    }

    Widget child;
    switch (type) {
      case 'text': child = _buildTextComponent(component); break;
      case 'image': child = _buildImageComponent(component); break;
      case 'button': child = _buildButtonComponent(component); break;
      case 'video': child = _buildVideoComponent(component); break;
      case 'divider': child = _buildDividerComponent(component); break;
      case 'spacer': child = _buildSpacerComponent(component); break;
      case 'badge': child = _buildBadgeComponent(component); break;
      case 'container': child = _buildContainerComponent(component); break;
      case 'input': child = _buildInputComponent(component); break;
      case 'checkbox': child = _buildCheckboxComponent(component); break;
      case 'progress': child = _buildProgressBarComponent(component); break;
      case 'rating': child = _buildRatingComponent(component); break;
      case 'carousel': child = _buildCarouselComponent(component); break;
      case 'accordion': child = _buildAccordionComponent(component); break;
      case 'list': child = _buildListComponent(component); break;
      case 'stepper': child = _buildStepperComponent(component); break;
      case 'richText': child = _buildRichTextComponent(component); break;
      case 'buttonGroup': child = _buildButtonGroupComponent(component); break;
      case 'countdown': child = _buildCountdownComponent(component); break;
      case 'statistic': child = _buildStatisticComponent(component); break;
      case 'progressCircle': child = _buildProgressCircleComponent(component); break;
      case 'gradientOverlay': child = _buildGradientOverlayComponent(component); break;
      default: child = const SizedBox.shrink();
    }

    // Apply interactions, styles, etc.
    child = _applyStyle(child, component['style'] as Map<String, dynamic>? ?? {});
    child = _buildInteraction(child, component);
    
    return child;
  }

  Widget _applyStyle(Widget child, Map<String, dynamic> style) {
    // Apply dimensions and decoration
    if (style['width'] != null || style['height'] != null || style['backgroundColor'] != null || 
        style['borderRadius'] != null || style['borderWidth'] != null || style['shadows'] != null) {
      
      BoxDecoration? decoration;
      if (style['backgroundColor'] != null || style['borderRadius'] != null || 
          style['borderWidth'] != null || style['shadows'] != null) {
        decoration = BoxDecoration(
          color: _parseColor(style['backgroundColor']),
          borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0),
          border: (style['borderWidth'] != null || style['borderColor'] != null)
              ? Border.all(
                  color: _parseColor(style['borderColor']) ?? Colors.black,
                  width: (style['borderWidth'] as num?)?.toDouble() ?? 0,
                )
              : null,
          boxShadow: _parseBoxShadow(style['shadows'] as List?),
        );
      }

      child = Container(
        width: (style['width'] as num?)?.toDouble(),
        height: (style['height'] as num?)?.toDouble(),
        margin: _parseEdgeInsets(style['margin']),
        padding: _parseEdgeInsets(style['padding']),
        decoration: decoration,
        child: child,
      );
    } else if (style['margin'] != null || style['padding'] != null) {
      child = Container(
        margin: _parseEdgeInsets(style['margin']),
        padding: _parseEdgeInsets(style['padding']),
        child: child,
      );
    }

    // Apply Opacity
    if (style['opacity'] != null) {
      child = Opacity(
        opacity: (style['opacity'] as num).toDouble(),
        child: child,
      );
    }

    // Apply Transform
    if (style['transform'] != null) {
      final transform = style['transform'] as Map<String, dynamic>;
      final matrix = Matrix4.identity();
      
      if (transform['rotate'] != null) {
        matrix.rotateZ((transform['rotate'] as num).toDouble() * math.pi / 180);
      }
      if (transform['scale'] != null) {
        final scale = (transform['scale'] as num).toDouble();
        matrix.scale(scale);
      }
      if (transform['translateX'] != null || transform['translateY'] != null) {
        matrix.translate(
          (transform['translateX'] as num?)?.toDouble() ?? 0.0,
          (transform['translateY'] as num?)?.toDouble() ?? 0.0,
        );
      }

      child = Transform(
        transform: matrix,
        alignment: Alignment.center,
        child: child,
      );
    }

    // Apply Filters (Blur, etc.)
    if (style['filter'] != null) {
      final filter = style['filter'] as Map<String, dynamic>;
      if (filter['blur'] != null) {
        final sigma = (filter['blur'] as num).toDouble();
        if (sigma > 0) {
          child = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        }
      }
    }

    return child;
  }

  Widget _buildDividerComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final color = _parseColor(style['color']) ?? Colors.grey[300];
    final thickness = (style['thickness'] as num?)?.toDouble() ?? 1.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) {
          return Divider(
            color: color,
            thickness: thickness,
            height: thickness,
          );
        } else {
          // In a Row (unbounded width), Divider crashes. 
          // We render a fixed width container as a fallback.
          return Container(
            width: 20, // Default small width for horizontal divider in row
            height: thickness,
            color: color,
          );
        }
      },
    );
  }

  Widget _buildSpacerComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final height = (style['height'] as num?)?.toDouble() ?? 16.0;
    return SizedBox(height: height);
  }

  // Removed duplicate/old component builders (Badge, Gradient, Statistic, ProgressCircle, Countdown)
  // New implementations are located below with other components.

  Widget _buildListComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final items = content['items'] as List? ?? [];
    final type = content['type'] as String? ?? 'bullet';
    final iconColor = _parseColor(style['iconColor']) ?? Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value.toString();
        
        Widget leading;
        if (type == 'numbered') {
          leading = Text('${index + 1}.', style: TextStyle(color: iconColor, fontWeight: FontWeight.bold));
        } else if (type == 'checkmark') {
          leading = Icon(Icons.check, size: 16, color: iconColor);
        } else {
          leading = Icon(Icons.circle, size: 6, color: iconColor);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: leading),
              Expanded(child: Text(item)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepperComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    final steps = (content['steps'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    final currentStep = (content['currentStep'] as num?)?.toInt() ?? 0;
    final orientation = style['orientation'] as String? ?? 'horizontal';
    final showNumbers = content['showNumbers'] as bool? ?? true;

    if (orientation == 'horizontal') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isLast = index == steps.length - 1;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: index == 0 ? const SizedBox() : Container(
                        height: 2,
                        color: isCompleted || isCurrent ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? const Color(0xFF22C55E) : (isCurrent ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB)),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                showNumbers ? '${index + 1}' : '',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: isLast ? const SizedBox() : Container(
                        height: 2,
                        color: isCompleted ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step['label'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.blue : Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? Colors.green : (isCurrent ? Colors.blue : Colors.grey[300]),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                showNumbers ? '${index + 1}' : '',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted ? Colors.green : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['label'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.blue : Colors.black87,
                        ),
                      ),
                      if (step['description'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          child: Text(
                            step['description'] as String,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        )
                      else
                        const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildRichTextComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final htmlContent = content['text'] as String? ?? '';
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 16),
        children: _parseSimpleHtml(htmlContent),
      ),
    );
  }

  List<TextSpan> _parseSimpleHtml(String html) {
    final spans = <TextSpan>[];
    final RegExp exp = RegExp(r'<(\w+)(?:[^>]*)>(.*?)<\/\1>|<br\s*\/?>|([^<]+)');
    final matches = exp.allMatches(html);

    if (matches.isEmpty) {
      spans.add(TextSpan(text: html));
      return spans;
    }

    for (final match in matches) {
      if (match.group(0)?.startsWith('<br') == true) {
        spans.add(const TextSpan(text: '\n'));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3)));
      } else {
        final tag = match.group(1);
        final text = match.group(2);
        TextStyle style = const TextStyle();

        switch (tag) {
          case 'b':
          case 'strong':
            style = const TextStyle(fontWeight: FontWeight.bold);
            break;
          case 'i':
          case 'em':
            style = const TextStyle(fontStyle: FontStyle.italic);
            break;
          case 'u':
            style = const TextStyle(decoration: TextDecoration.underline);
            break;
          case 'span':
            // Basic span support (could be expanded to parse style attribute)
            break;
        }
        spans.add(TextSpan(text: text, style: style));
      }
    }
    return spans;
  }

  Widget _buildBadgeComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final text = content['badgeText'] as String? ?? 'Badge';
    final variant = content['badgeVariant'] as String? ?? 'custom';
    final iconName = content['badgeIcon'] as String?;
    final iconPosition = content['badgeIconPosition'] as String? ?? 'left';
    final pulse = content['pulse'] as bool? ?? false;

    Color bg;
    Color textColor;

    switch (variant) {
      case 'success':
        bg = const Color(0xFF10B981);
        textColor = Colors.white;
        break;
      case 'error':
        bg = const Color(0xFFEF4444);
        textColor = Colors.white;
        break;
      case 'warning':
        bg = const Color(0xFFF59E0B);
        textColor = Colors.white;
        break;
      case 'info':
        bg = const Color(0xFF3B82F6);
        textColor = Colors.white;
        break;
      case 'custom':
      default:
        bg = _parseColor(style['badgeBackgroundColor']) ?? Colors.grey;
        textColor = _parseColor(style['badgeTextColor']) ?? Colors.white;
        break;
    }

    Widget badge = Container(
      padding: _parseEdgeInsets(style['badgePadding']) ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular((style['badgeBorderRadius'] as num?)?.toDouble() ?? 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconName != null && iconPosition == 'left') ...[
            Icon(_getIconData(iconName), size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (iconName != null && iconPosition == 'right') ...[
            const SizedBox(width: 4),
            Icon(_getIconData(iconName), size: 14, color: textColor),
          ],
        ],
      ),
    );

    if (pulse) {
      // Simple pulse animation wrapper could be added here
      // For now, just returning the badge
    }

    return badge;
  }

  Widget _buildCheckboxComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final label = content['checkboxLabel'] as String? ?? 'Checkbox';
    final name = content['name'] as String?;
    
    // State handling
    final isChecked = _formData[name] as bool? ?? content['checked'] as bool? ?? false;
    final checkboxColor = _parseColor(content['checkboxColor']) ?? const Color(0xFF6366F1);
    final textColor = _parseColor(content['textColor']) ?? const Color(0xFF374151);
    final fontSize = (content['fontSize'] as num?)?.toDouble() ?? 14.0;

    return GestureDetector(
      onTap: () {
        if (name != null) {
          setState(() {
            _formData[name] = !isChecked;
          });
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isChecked ? checkboxColor : Colors.transparent,
              border: Border.all(color: isChecked ? checkboxColor : Colors.grey.shade400, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isChecked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontFamily: style['fontFamily'] as String?,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonGroupComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    final buttons = (content['buttons'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final layout = style['layout'] as String? ?? 'horizontal';
    final gap = (style['gap'] as num?)?.toDouble() ?? 12.0;

    final children = buttons.map((btnConfig) {
      return _buildButtonComponent({
        'content': {
          'label': btnConfig['label'],
          'action': btnConfig['action'],
          'buttonVariant': btnConfig['variant'],
        },
        'style': {
          'backgroundColor': style['buttonColor'],
          'borderRadius': style['borderRadius'],
        }
      });
    }).toList();

    if (layout == 'horizontal') {
      return Row(
        children: children.map((child) => Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gap / 2),
            child: child,
          ),
        )).toList(),
      );
    } else {
      return Column(
        children: children.map((child) => Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: SizedBox(width: double.infinity, child: child),
        )).toList(),
      );
    }
  }

  Widget _buildInputComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final label = content['label'] as String? ?? '';
    final placeholder = content['placeholder'] as String? ?? 'Enter text...';
    final inputType = content['inputType'] as String? ?? 'text';
    final maxLines = (content['maxLines'] as num?)?.toInt() ?? 1;

    Widget inputWidget = TextField(
      maxLines: maxLines,
      keyboardType: inputType == 'number' ? TextInputType.number : (inputType == 'email' ? TextInputType.emailAddress : TextInputType.text),
      onChanged: (value) {
        setState(() {
          if (label.isNotEmpty) {
             _formData[label] = value;
          }
          if (content['name'] != null) {
            _formData[content['name']] = value;
          }
        });
      },
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(
          color: _parseColor(style['placeholderColor']) ?? Colors.grey[400],
          fontSize: (style['fontSize'] as num?)?.toDouble() ?? 15.0,
        ),
        filled: true,
        fillColor: _parseColor(style['backgroundColor']) ?? const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 8),
          borderSide: BorderSide(
            color: _parseColor(style['borderColor']) ?? const Color(0xFFD1D5DB),
            width: (style['borderWidth'] as num?)?.toDouble() ?? 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 8),
          borderSide: BorderSide(
            color: _parseColor(style['borderColor']) ?? Colors.blue,
            width: (style['borderWidth'] as num?)?.toDouble() ?? 2.0,
          ),
        ),
      ),
    );

    Widget wrappedInput = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) {
          return inputWidget;
        } else {
          // Unbounded width (e.g. in Row), default to 200.0
          return SizedBox(width: 200.0, child: inputWidget);
        }
      },
    );

    if (label.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          wrappedInput,
        ],
      );
    }
    return wrappedInput;
  }

  Widget _buildContainerComponent(Map<String, dynamic> component) {
    final children = component['children'] as List? ?? [];
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final flexLayout = component['flexLayout'] as Map<String, dynamic>? ?? {};
    
    Widget content;
    
    // 1. Layout Strategy
    if (flexLayout['enabled'] == true) {
      // Use Flexible Layout
      content = _buildFlexibleLayout({
        'components': children,
        'layout': flexLayout,
      });
    } else {
      // Default Column Layout
      final gap = (style['gap'] as num?)?.toDouble() ?? 0.0;
      final childWidgets = children.map((c) {
        final comp = c is Map<String, dynamic> ? c : <String, dynamic>{};
        Widget widget = _buildComponent(comp);
        if (comp['animation'] != null) {
          widget = _EntranceAnimator(animation: comp['animation'], child: widget);
        }
        return widget;
      }).toList();

      if (gap > 0 && childWidgets.isNotEmpty) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: childWidgets.expand((widget) => [widget, SizedBox(height: gap)]).take(childWidgets.length * 2 - 1).toList(),
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: childWidgets,
        );
      }
    }

    // 3. Container Styling
    final bgColor = _parseColor(style['backgroundColor']);
    final bgImage = style['backgroundImage'] as String?;
    final bgGradient = _parseGradient(style['backgroundGradient']);
    final shadows = _parseBoxShadow(style['shadows'] as List?);
    final overflow = style['overflow'] as String? ?? 'visible';
    
    DecorationImage? decorationImage;
    if (bgImage != null && bgImage.isNotEmpty) {
      decorationImage = DecorationImage(
        image: NetworkImage(bgImage),
        fit: _parseBoxFit(style['backgroundSize'] ?? 'cover'),
        // backgroundPosition is harder to map 1:1 to Alignment without parsing 'center', 'top left' etc.
        // Defaulting to center for now.
        alignment: Alignment.center, 
      );
    }

    return Container(
      padding: _parseEdgeInsets(style['padding']),
      margin: _parseEdgeInsets(style['margin']),
      width: (style['width'] as num?)?.toDouble(),
      height: (style['height'] as num?)?.toDouble(),
      clipBehavior: overflow == 'hidden' ? Clip.hardEdge : Clip.none,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: bgGradient,
        image: decorationImage,
        borderRadius: BorderRadius.circular((style['borderRadius'] as num?)?.toDouble() ?? 0),
        border: Border.all(
          color: _parseColor(style['borderColor']) ?? Colors.transparent,
          width: (style['borderWidth'] as num?)?.toDouble() ?? 0,
        ),
        boxShadow: shadows,
      ),
      child: content,
    );
  }

  Widget _applyStyle(Widget child, Map<String, dynamic> style) {
    // 1. Transform (Rotate, Scale, Translate)
    final transform = style['transform'];
    if (transform is Map) {
      final rotate = (transform['rotate'] as num?)?.toDouble() ?? 0.0;
      final scale = (transform['scale'] as num?)?.toDouble() ?? 1.0;
      final dx = (transform['translateX'] as num?)?.toDouble() ?? 0.0;
      final dy = (transform['translateY'] as num?)?.toDouble() ?? 0.0;

      if (rotate != 0 || scale != 1 || dx != 0 || dy != 0) {
        child = Transform(
          transform: Matrix4.identity()
            ..translate(dx, dy)
            ..rotateZ(rotate * math.pi / 180)
            ..scale(scale),
          alignment: Alignment.center,
          child: child,
        );
      }
    }

    // 2. Padding
    final padding = _parseEdgeInsets(style['padding']);
    if (padding != null) {
      child = Padding(padding: padding, child: child);
    }

    // 3. Margin
    final margin = _parseEdgeInsets(style['margin']);
    if (margin != null) {
      child = Padding(padding: margin, child: child);
    }

    // 4. Opacity
    final opacity = (style['opacity'] as num?)?.toDouble() ?? 1.0;
    if (opacity < 1.0) {
      child = Opacity(opacity: opacity, child: child);
    }

    // 5. Backdrop Filter (Blur)
    final backdropFilter = style['backdropFilter'] as String?;
    if (backdropFilter != null && backdropFilter.startsWith('blur')) {
      // Parse "blur(10px)"
      final match = RegExp(r'blur\((\d+(?:\.\d+)?)px\)').firstMatch(backdropFilter);
      if (match != null) {
        final sigma = double.tryParse(match.group(1) ?? '0') ?? 0;
        if (sigma > 0) {
          child = ClipRRect(
            // Clip is needed for backdrop filter to respect bounds usually, 
            // but here we might just want to apply it to the child area.
            // Actually, BackdropFilter applies to everything BEHIND the child.
            // If we want to blur the background of this component, we usually use it in a Stack.
            // But if this is "glassmorphism" style on the component itself, 
            // it usually implies the component has a semi-transparent bg and we blur what's behind it.
            // Let's wrap in ClipRRect to respect border radius if possible, but we don't have radius here easily.
            // We'll just wrap in BackdropFilter.
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
          );
        }
      }
    }

    // 5.5 Filters (Brightness, Contrast, Grayscale)
    final filter = style['filter'] as String?;
    if (filter != null) {
      if (filter.contains('grayscale')) {
         final match = RegExp(r'grayscale\((\d+(?:\.\d+)?)%\)').firstMatch(filter);
         final percent = double.tryParse(match?.group(1) ?? '0') ?? 0;
         if (percent > 0) {
           child = ColorFiltered(
             colorFilter: ColorFilter.matrix([
               0.2126 + 0.7874 * (1 - percent/100), 0.7152 - 0.7152 * (1 - percent/100), 0.0722 - 0.0722 * (1 - percent/100), 0, 0,
               0.2126 - 0.2126 * (1 - percent/100), 0.7152 + 0.2848 * (1 - percent/100), 0.0722 - 0.0722 * (1 - percent/100), 0, 0,
               0.2126 - 0.2126 * (1 - percent/100), 0.7152 - 0.7152 * (1 - percent/100), 0.0722 + 0.9278 * (1 - percent/100), 0, 0,
               0, 0, 0, 1, 0,
             ]),
             child: child,
           );
         }
      }
      // Note: Brightness and Contrast are harder to apply directly to a generic widget without a specific shader or ColorFilter matrix.
      // Grayscale is the most common request.
    }

    // 6. Background & Border (Container)
    // Only wrap in Container if there are styles that require it
    // and the child isn't already handling it (like Button or Container component)
    // However, for generic styling, wrapping is safe.
    final bgColor = _parseColor(style['backgroundColor']);
    final gradient = _parseGradient(style['backgroundGradient']);
    final borderColor = _parseColor(style['borderColor']);
    final borderWidth = (style['borderWidth'] as num?)?.toDouble() ?? 0.0;
    final borderRadius = (style['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final shadows = _parseBoxShadow(style['shadows'] as List?);

    if (bgColor != null || gradient != null || (borderColor != null && borderWidth > 0) || (shadows != null && shadows.isNotEmpty)) {
      child = Container(
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor != null && borderWidth > 0
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: shadows,
        ),
        child: child,
      );
    }

    return child;
  }

  // --- Helpers ---

  bool _evaluateVisibility(dynamic visible, Map<String, dynamic> variables) {
    if (visible == null) return true;
    if (visible is bool) return visible;
    if (visible is String) {
      if (visible.startsWith('{') && visible.endsWith('}')) {
        final expression = visible.substring(1, visible.length - 1).trim();
        return _evaluateCondition(expression, variables);
      }
      return true;
    }
    return true;
  }

  Widget _buildInteraction(Widget child, Map<String, dynamic> component) {
    final action = component['content']?['action'] as Map<String, dynamic>?;
    if (action == null) return child;

    return GestureDetector(
      onTap: () {
        debugPrint('Action Triggered: $action');
      },
      child: child,
    );
  }

  Gradient? _parseGradient(dynamic gradientConfig) {
    if (gradientConfig == null || gradientConfig is! Map) return null;
    
    final type = gradientConfig['type'] as String? ?? 'linear';
    final colors = (gradientConfig['colors'] as List?)?.map((c) => _parseColor(c) ?? Colors.transparent).toList() ?? [];
    final stops = (gradientConfig['stops'] as List?)?.map((s) => (s as num).toDouble()).toList();
    
    if (colors.isEmpty) return null;

    if (type == 'linear') {
      final angle = (gradientConfig['angle'] as num?)?.toDouble() ?? 180.0;
      // Convert angle to Alignment
      final radians = angle * (math.pi / 180);
      final begin = Alignment(math.cos(radians + math.pi), math.sin(radians + math.pi));
      final end = Alignment(math.cos(radians), math.sin(radians));

      return LinearGradient(
        colors: colors,
        stops: stops,
        begin: begin,
        end: end,
      );
    }
    return null;
  }

  Color? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is Color) return color;
    final colorStr = color.toString();
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.replaceFirst('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    }
    return null;
  }

  EdgeInsets? _parseEdgeInsets(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final list = value.map((e) => (e as num).toDouble()).toList();
      if (list.length == 4) {
        return EdgeInsets.fromLTRB(list[3], list[0], list[1], list[2]); // Top, Right, Bottom, Left -> LTRB? No.
        // CSS: Top, Right, Bottom, Left
        // Flutter LTRB: Left, Top, Right, Bottom
        // So: list[3] (Left), list[0] (Top), list[1] (Right), list[2] (Bottom)
      } else if (list.length == 2) {
        return EdgeInsets.symmetric(vertical: list[0], horizontal: list[1]);
      } else if (list.length == 1) {
        return EdgeInsets.all(list[0]);
      }
    }
    if (value is Map) {
      return EdgeInsets.only(
        top: (value['top'] as num?)?.toDouble() ?? 0,
        right: (value['right'] as num?)?.toDouble() ?? 0,
        bottom: (value['bottom'] as num?)?.toDouble() ?? 0,
        left: (value['left'] as num?)?.toDouble() ?? 0,
      );
    }
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }
    return null;
  }

  List<BoxShadow>? _parseBoxShadow(List? shadows) {
    if (shadows == null || shadows.isEmpty) return null;
    return shadows.map((s) {
      final color = _parseColor(s['color']) ?? Colors.black.withOpacity(0.2);
      final blur = (s['blur'] as num?)?.toDouble() ?? 4.0;
      final spread = (s['spread'] as num?)?.toDouble() ?? 0.0;
      final x = (s['x'] as num?)?.toDouble() ?? 0.0;
      final y = (s['y'] as num?)?.toDouble() ?? 2.0;
      return BoxShadow(
        color: color,
        blurRadius: blur,
        spreadRadius: spread,
        offset: Offset(x, y),
      );
      default: return CrossAxisAlignment.center;
    }
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment main) {
    switch (main) {
      case MainAxisAlignment.start: return WrapAlignment.start;
      case MainAxisAlignment.end: return WrapAlignment.end;
      case MainAxisAlignment.center: return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween: return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround: return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly: return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(CrossAxisAlignment cross) {
    switch (cross) {
      case CrossAxisAlignment.start: return WrapCrossAlignment.start;
      case CrossAxisAlignment.end: return WrapCrossAlignment.end;
      case CrossAxisAlignment.center: return WrapCrossAlignment.center;
      default: return WrapCrossAlignment.center;
    }
  }

  BoxFit _parseBoxFit(String? value) {
    switch (value) {
      case 'contain': return BoxFit.contain;
      case 'cover': return BoxFit.cover;
      case 'fill': return BoxFit.fill;
      case 'fitWidth': return BoxFit.fitWidth;
      case 'fitHeight': return BoxFit.fitHeight;
      case 'none': return BoxFit.none;
      case 'scaleDown': return BoxFit.scaleDown;
      default: return BoxFit.cover;
    }
  }

  TextAlign _parseTextAlign(String? value) {
    switch (value) {
      case 'left': return TextAlign.left;
      case 'right': return TextAlign.right;
      case 'center': return TextAlign.center;
      case 'justify': return TextAlign.justify;
      case 'start': return TextAlign.start;
      case 'end': return TextAlign.end;
      default: return TextAlign.start;
    }
  }

  TextOverflow _parseTextOverflow(String? value) {
    switch (value) {
      case 'ellipsis': return TextOverflow.ellipsis;
      case 'clip': return TextOverflow.clip;
      case 'fade': return TextOverflow.fade;
      case 'visible': return TextOverflow.visible;
      default: return TextOverflow.clip;
    }
  }

  TextStyle _parseTextStyle(Map<String, dynamic> style) {
    final opacity = (style['opacity'] as num?)?.toDouble() ?? 1.0;
    final shadow = style['textShadow'] as Map<String, dynamic>?;

    return TextStyle(
      fontWeight: _parseFontWeight(style['fontWeight']),
      fontStyle: style['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
      decoration: _parseTextDecoration(style['textDecoration']),
      letterSpacing: (style['letterSpacing'] as num?)?.toDouble(),
      height: (style['lineHeight'] as num?)?.toDouble(),
      fontFamily: style['fontFamily'] as String?,
      color: (_parseColor(style['color']) ?? Colors.black).withOpacity(opacity),
      shadows: shadow != null ? [
        Shadow(
          color: _parseColor(shadow['color']) ?? Colors.black.withOpacity(0.5),
          offset: Offset(
            (shadow['x'] as num?)?.toDouble() ?? 0,
            (shadow['y'] as num?)?.toDouble() ?? 0,
          ),
          blurRadius: (shadow['blur'] as num?)?.toDouble() ?? 0,
        )
      ] : null,
    );
  }

  FontWeight _parseFontWeight(dynamic value) {
    if (value == null) return FontWeight.normal;
    if (value is int) {
      switch (value) {
        case 100: return FontWeight.w100;
        case 200: return FontWeight.w200;
        case 300: return FontWeight.w300;
        case 400: return FontWeight.w400;
        case 500: return FontWeight.w500;
        case 600: return FontWeight.w600;
        case 700: return FontWeight.w700;
        case 800: return FontWeight.w800;
        case 900: return FontWeight.w900;
      }
    }
    switch (value.toString().toLowerCase()) {
      case 'bold': return FontWeight.bold;
      case 'normal': return FontWeight.normal;
      case 'w100': return FontWeight.w100;
      case 'w200': return FontWeight.w200;
      case 'w300': return FontWeight.w300;
      case 'w400': return FontWeight.w400;
      case 'w500': return FontWeight.w500;
      case 'w600': return FontWeight.w600;
      case 'w700': return FontWeight.w700;
      case 'w800': return FontWeight.w800;
      case 'w900': return FontWeight.w900;
      default: return FontWeight.normal;
    }
  }

  TextDecoration _parseTextDecoration(String? value) {
    switch (value) {
      case 'underline': return TextDecoration.underline;
      case 'overline': return TextDecoration.overline;
      case 'line-through': return TextDecoration.lineThrough;
      default: return TextDecoration.none;
    }
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start: return WrapAlignment.start;
      case MainAxisAlignment.end: return WrapAlignment.end;
      case MainAxisAlignment.center: return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween: return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround: return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly: return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(CrossAxisAlignment alignment) {
    switch (alignment) {
      case CrossAxisAlignment.start: return WrapCrossAlignment.start;
      case CrossAxisAlignment.end: return WrapCrossAlignment.end;
      case CrossAxisAlignment.center: return WrapCrossAlignment.center;
      case CrossAxisAlignment.stretch: return WrapCrossAlignment.center; // Wrap doesn't support stretch directly
      case CrossAxisAlignment.baseline: return WrapCrossAlignment.center; // Wrap doesn't support baseline directly
    }
  }

  String _substituteVariables(String text, List? variables) {
    // if (variables == null || variables.isEmpty) return text; // Removed to allow _formData substitution
    
    // 1. Create a map of variables for easy lookup
    final varMap = <String, dynamic>{};
    if (variables != null) {
      for (final v in variables) {
        varMap[v['name']] = v['value'];
      }
    }
    // Merge form data for dynamic updates
    varMap.addAll(_formData);

    // 2. Regex to find { expression } patterns
    // Matches { variable }, { price > 100 ? 'High' : 'Low' }, { name | uppercase }
    final RegExp exp = RegExp(r'\{([^}]+)\}');
    
    return text.replaceAllMapped(exp, (match) {
      final expression = match.group(1)?.trim() ?? '';
      
      // Handle Formatting Pipes (|)
      final parts = expression.split('|');
      final coreExpression = parts[0].trim();
      final format = parts.length > 1 ? parts[1].trim() : null;

      // Evaluate the core expression
      dynamic result = _evaluateExpression(coreExpression, varMap);

      // Apply Formatting
      if (format != null) {
        result = _applyFormat(result, format);
      }

      return result.toString();
    });
  }

  dynamic _evaluateExpression(String expression, Map<String, dynamic> variables) {
    // 1. Simple Variable Lookup
    if (variables.containsKey(expression)) {
      return variables[expression];
    }

    // 2. Ternary Operator (condition ? true : false)
    if (expression.contains('?')) {
      final parts = expression.split('?');
      final condition = parts[0].trim();
      final rest = parts[1].split(':');
      final trueVal = rest[0].trim().replaceAll("'", "");
      final falseVal = rest.length > 1 ? rest[1].trim().replaceAll("'", "") : '';

      if (_evaluateCondition(condition, variables)) {
        return trueVal;
      } else {
        return falseVal;
      }
    }

    // 3. Math Operations (+, -)
    // Very basic implementation for demo purposes
    if (expression.contains('+')) {
      final parts = expression.split('+');
      final left = _resolveValue(parts[0].trim(), variables);
      final right = _resolveValue(parts[1].trim(), variables);
      if (left is num && right is num) return left + right;
      return '$left$right';
    }
    if (expression.contains('-')) {
      final parts = expression.split('-');
      final left = _resolveValue(parts[0].trim(), variables);
      final right = _resolveValue(parts[1].trim(), variables);
      if (left is num && right is num) return left - right;
    }

    // 4. Literal Values
    return _resolveValue(expression, variables);
  }

  bool _evaluateCondition(String condition, Map<String, dynamic> variables) {
    // Basic comparison support: >, <, ==, !=, >=, <=
    final operators = ['>=', '<=', '==', '!=', '>', '<'];
    
    for (final op in operators) {
      if (condition.contains(op)) {
        final parts = condition.split(op);
        final left = _resolveValue(parts[0].trim(), variables);
        final right = _resolveValue(parts[1].trim(), variables);

        if (left is num && right is num) {
          switch (op) {
            case '>': return left > right;
            case '<': return left < right;
            case '>=': return left >= right;
            case '<=': return left <= right;
            case '==': return left == right;
            case '!=': return left != right;
          }
        }
        // String comparison
        if (op == '==') return left.toString() == right.toString();
        if (op == '!=') return left.toString() != right.toString();
      }
    }
    
    // Boolean variable check
    final val = _resolveValue(condition, variables);
    if (val is bool) return val;
    return val != null && val != false && val != 0 && val != '';
  }

  dynamic _resolveValue(String key, Map<String, dynamic> variables) {
    // Check if it's a number literal
    final numVal = num.tryParse(key);
    if (numVal != null) return numVal;

    // Check if it's a string literal
    if (key.startsWith("'") && key.endsWith("'")) {
      return key.substring(1, key.length - 1);
    }

    // Look up variable
    return variables[key] ?? key;
  }

  dynamic _applyFormat(dynamic value, String format) {
    final str = value.toString();
    switch (format.toLowerCase()) {
      case 'uppercase':
      case 'upper':
        return str.toUpperCase();
      case 'lowercase':
      case 'lower':
        return str.toLowerCase();
      case 'currency':
        final numVal = num.tryParse(str) ?? 0;
        return '\$${numVal.toStringAsFixed(2)}';
      default:
        return str;
    }
  }

  Color _adjustColorBrightness(Color color, double amount) {
    assert(amount >= -1 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  IconData? _getIconData(String name) {
    switch (name) {
      case 'ArrowRight': return Icons.arrow_forward;
      case 'ArrowLeft': return Icons.arrow_back;
      case 'Play': return Icons.play_arrow;
      case 'Search': return Icons.search;
      case 'Home': return Icons.home;
      case 'Check': return Icons.check;
      case 'X': return Icons.close;
      case 'Download': return Icons.download;
      case 'Upload': return Icons.upload;
      case 'User': return Icons.person;
      case 'Settings': return Icons.settings;
      default: return null;
    }
  }

  Widget _buildShapeComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final shapeType = component['content']?['shapeType'] as String? ?? 'rectangle';
    final color = _parseColor(style['backgroundColor']) ?? Colors.blue;
    final width = (style['width'] as num?)?.toDouble() ?? 100.0;
    final height = (style['height'] as num?)?.toDouble() ?? 100.0;

    if (shapeType == 'circle') {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else if (shapeType == 'triangle') {
      return CustomPaint(
        size: Size(width, height),
        painter: _TrianglePainter(color: color),
      );
    }
    return Container(
      width: width,
      height: height,
      color: color,
    );
  }

  Widget _buildLinkComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final text = content['text'] as String? ?? 'Link';
    final url = content['url'] as String? ?? '#';
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    return InkWell(
      onTap: () => widget.onCTAClick?.call('link', {'url': url}),
      child: Text(
        text,
        style: _parseTextStyle(style).copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildRatingComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final maxStars = (content['maxStars'] as num?)?.toInt() ?? 5;
    final initialRating = (content['initialRating'] as num?)?.toDouble() ?? 0.0;
    final starSize = (style['fontSize'] as num?)?.toDouble() ?? 24.0;
    final activeColor = _parseColor(style['activeColor']) ?? Colors.amber;
    final inactiveColor = _parseColor(style['inactiveColor']) ?? Colors.grey.shade300;
    final spacing = (style['starSpacing'] as num?)?.toDouble() ?? 4.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        IconData icon = Icons.star_border;
        Color color = inactiveColor;
        
        if (index < initialRating) {
          icon = Icons.star;
          color = activeColor;
          if (index + 1 > initialRating) {
             icon = Icons.star_half;
          }
        }

        return Padding(
          padding: EdgeInsets.only(right: index < maxStars - 1 ? spacing : 0),
          child: Icon(icon, size: starSize, color: color),
        );
      }),
    );
  }

  Widget _buildCarouselComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final items = content['items'] as List? ?? [];
    final height = (component['style']?['height'] as num?)?.toDouble() ?? 200.0;
    
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index] is Map<String, dynamic> ? items[index] as Map<String, dynamic> : <String, dynamic>{};
          if (item['type'] == 'image') {
             return _buildImageComponent({'content': item, 'style': {'fit': 'cover', 'width': double.infinity, 'height': height}});
          }
          return Container(
            color: Colors.grey[200],
            child: Center(child: Text('Item $index')),
          );
        },
      ),
    );
  }

  Widget _buildAccordionComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final items = content['items'] as List? ?? [];
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final activeColor = _parseColor(style['activeColor']) ?? Colors.blue;

    return Column(
      children: items.map<Widget>((dynamic item) {
        final mapItem = item is Map<String, dynamic> ? item : <String, dynamic>{};
        final title = mapItem['title'] as String? ?? 'Section';
        final body = mapItem['body'] as String? ?? '';
        
        return ExpansionTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          iconColor: activeColor,
          textColor: activeColor,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(body),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProgressBarComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final max = (content['max'] as num?)?.toDouble() ?? 100.0;
    final value = (content['value'] as num?)?.toDouble() ?? 0.0;
    final percentage = (value / max).clamp(0.0, 1.0);
    final showPercentage = content['showPercentage'] as bool? ?? false;
    final label = content['label'] as String? ?? '';
    final variant = content['variant'] as String? ?? 'default';
    
    final height = (style['height'] as num?)?.toDouble() ?? 8.0;
    final color = _parseColor(style['color']) ?? const Color(0xFF3B82F6);
    final bgColor = _parseColor(style['backgroundColor']) ?? const Color(0xFFE5E7EB);
    final borderRadius = (style['borderRadius'] as num?)?.toDouble() ?? 4.0;

    Widget barWidget;

    if (variant == 'striped' || variant == 'animated') {
      barWidget = CustomPaint(
        size: Size(double.infinity, height),
        painter: _StripedBarPainter(
          percentage: percentage,
          color: color,
          backgroundColor: bgColor,
          borderRadius: borderRadius,
        ),
      );
    } else if (variant == 'gradient') {
       barWidget = Container(
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: percentage,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.7), color],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      );
    } else if (variant == 'glow') {
      barWidget = Container(
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: percentage,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1),
              ],
            ),
          ),
        ),
      );
    } else if (variant == 'segmented') {
      final segments = 10;
      barWidget = Row(
        children: List.generate(segments, (index) {
          final isActive = index / segments < percentage;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: height,
              decoration: BoxDecoration(
                color: isActive ? color : bgColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          );
        }),
      );
    } else {
      // Default / Rounded
      barWidget = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          value: percentage,
          backgroundColor: bgColor,
          color: color,
          minHeight: height,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label.isNotEmpty)
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (showPercentage)
                  Text('${(percentage * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        wrappedBar,
      ],
    );
  }

  Widget _buildProgressCircleComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final value = (content['value'] as num?)?.toDouble() ?? 0.0;
    final max = (content['max'] as num?)?.toDouble() ?? 100.0;
    final showPercentage = content['showPercentage'] as bool? ?? true;
    final variant = content['progressVariant'] as String? ?? 'simple';
    final themeColor = _parseColor(content['themeColor']) ?? _parseColor(style['backgroundColor']) ?? const Color(0xFF6366F1);
    final trackColor = const Color(0xFFE5E7EB);
    final size = (style['width'] as num?)?.toDouble() ?? 120.0;

    final percentage = (value / max).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressCirclePainter(
              percentage: percentage,
              variant: variant,
              color: themeColor,
              trackColor: trackColor,
              strokeWidth: variant == 'thick' ? 12.0 : 8.0,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toInt()}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                  fontFamily: style['fontFamily'] as String?,
                ),
              ),
              if (showPercentage)
                Text(
                  variant == 'semicircle' ? 'Score' : (content['max'] != null ? 'of ${max.toInt()}' : '%'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final value = (content['value'] as num?)?.toDouble() ?? 0;
    final label = content['label'] as String? ?? '';
    final prefix = content['prefix'] as String? ?? '';
    final suffix = content['suffix'] as String? ?? '';
    final color = _parseColor(style['color']) ?? Colors.black;
    final fontSize = (style['fontSize'] as num?)?.toDouble() ?? 32.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (prefix.isNotEmpty)
              Text(prefix, style: TextStyle(fontSize: fontSize * 0.6, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutExpo,
              builder: (context, val, child) {
                return Text(
                  val.toInt().toString(),
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
                );
              },
            ),
            if (suffix.isNotEmpty)
              Text(suffix, style: TextStyle(fontSize: fontSize * 0.6, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
          ],
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  Widget _buildGradientOverlayComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final type = content['gradientType'] as String? ?? 'linear';
    final stops = (content['gradientStops'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    
    final colors = stops.map((s) => _parseColor(s['color']) ?? Colors.transparent).toList();
    final stopValues = stops.map((s) => (s['position'] as num).toDouble() / 100).toList();

    Gradient gradient;
    if (type == 'radial') {
      gradient = RadialGradient(
        colors: colors,
        stops: stopValues,
        center: Alignment.center,
        radius: 0.8,
      );
    } else {
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stopValues,
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: gradient),
    );
  }

  Widget _buildCountdownComponent(Map<String, dynamic> component) {
    return _CountdownTimer(component: component);
  }
}

class _CountdownTimer extends StatefulWidget {
  final Map<String, dynamic> component;

  const _CountdownTimer({Key? key, required this.component}) : super(key: key);

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    final content = widget.component['content'] as Map<String, dynamic>? ?? {};
    final targetDateStr = content['targetDate'] as String?;
    final targetDate = targetDateStr != null ? DateTime.tryParse(targetDateStr) : DateTime.now().add(const Duration(hours: 1));
    
    _remaining = targetDate != null ? targetDate.difference(DateTime.now()) : Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final newRemaining = targetDate!.difference(DateTime.now());
          if (newRemaining.isNegative) {
            _remaining = Duration.zero;
            timer.cancel();
          } else {
            _remaining = newRemaining;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.component['content'] as Map<String, dynamic>? ?? {};
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final variant = content['timerVariant'] as String? ?? 'text';
    final fontSize = (style['fontSize'] as num?)?.toDouble() ?? 24.0;
    final color = _parseColor(style['color']) ?? Colors.black;
    final fontWeight = _parseFontWeight(style['fontWeight']);

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    switch (variant) {
      case 'card':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCard(hours, 'Hours', fontSize, color),
            _buildSeparator(fontSize, color),
            _buildCard(minutes, 'Mins', fontSize, color),
            _buildSeparator(fontSize, color),
            _buildCard(seconds, 'Secs', fontSize, color),
          ],
        );
      case 'flip':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlip(hours, 'HOURS', fontSize),
            const SizedBox(width: 4),
            _buildFlip(minutes, 'MINS', fontSize),
            const SizedBox(width: 4),
            _buildFlip(seconds, 'SECS', fontSize),
          ],
        );
      case 'digital':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDigital(hours, 'HOURS', fontSize),
            _buildDigitalSeparator(fontSize),
            _buildDigital(minutes, 'MINS', fontSize),
            _buildDigitalSeparator(fontSize),
            _buildDigital(seconds, 'SECS', fontSize),
          ],
        );
      case 'circular':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircular(hours, 24, 'Hrs', fontSize, color),
            const SizedBox(width: 12),
            _buildCircular(minutes, 60, 'Mins', fontSize, color),
            const SizedBox(width: 12),
            _buildCircular(seconds, 60, 'Secs', fontSize, color),
          ],
        );
      case 'bubble':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBubble(hours, 'Hrs', fontSize, color),
            const SizedBox(width: 12),
            _buildBubble(minutes, 'Mins', fontSize, color),
            const SizedBox(width: 12),
            _buildBubble(seconds, 'Secs', fontSize, color),
          ],
        );
      case 'neon':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNeon(hours, 'HRS', fontSize),
            const SizedBox(width: 12),
            _buildNeon(minutes, 'MIN', fontSize),
            const SizedBox(width: 12),
            _buildNeon(seconds, 'SEC', fontSize),
          ],
        );
      case 'minimal':
         return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMinimal(hours, 'HOURS', fontSize, color),
            Container(width: 1, height: fontSize, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
            _buildMinimal(minutes, 'MINS', fontSize, color),
            Container(width: 1, height: fontSize, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
            _buildMinimal(seconds, 'SECS', fontSize, color),
          ],
        );
      default:
        return Text(
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        );
    }
  }

  Widget _buildCard(int value, String label, double fontSize, Color color) {
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final bgColor = _parseColor(style['backgroundColor']) ?? Colors.grey[100];
    final borderColor = _parseColor(style['borderColor']) ?? Colors.grey[300];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor!),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSeparator(double fontSize, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(':', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildFlip(int value, String label, double fontSize) {
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final bgColor = _parseColor(style['backgroundColor']) ?? const Color(0xFF1F2937);
    final textColor = _parseColor(widget.component['content']?['textColor']) ?? Colors.white;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 4), blurRadius: 6),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Courier'),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDigital(int value, String label, double fontSize) {
    final isUrgent = widget.component['content']?['urgencyThreshold'] != null && _remaining.inSeconds < (widget.component['content']['urgencyThreshold'] as num);
    final color = isUrgent ? Colors.red : const Color(0xFF10B981);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[800]!),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.2), blurRadius: 10),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontFamily: 'Courier',
              shadows: [Shadow(color: color, blurRadius: 5)],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDigitalSeparator(double fontSize) {
    final isUrgent = widget.component['content']?['urgencyThreshold'] != null && _remaining.inSeconds < (widget.component['content']['urgencyThreshold'] as num);
    final color = isUrgent ? Colors.red : const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(':', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color, shadows: [Shadow(color: color, blurRadius: 5)])),
    );
  }

  Widget _buildCircular(int value, int max, String label, double fontSize, Color color) {
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final bgColor = _parseColor(style['backgroundColor']) ?? const Color(0xFF6366F1);
    
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value / max,
                backgroundColor: Colors.grey[200],
                color: bgColor,
                strokeWidth: 4,
              ),
              Center(
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: TextStyle(fontSize: fontSize * 0.6, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBubble(int value, String label, double fontSize, Color color) {
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final bgColor = _parseColor(style['backgroundColor']) ?? const Color(0xFFEEF2FF);
    final borderColor = _parseColor(style['borderColor']) ?? Colors.transparent;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(fontSize: fontSize * 0.8, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildNeon(int value, String label, double fontSize) {
    final style = widget.component['style'] as Map<String, dynamic>? ?? {};
    final borderColor = _parseColor(style['borderColor']) ?? const Color(0xFF6366F1);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(color: borderColor, blurRadius: 8),
              BoxShadow(color: borderColor, blurRadius: 8, spreadRadius: -2, offset: const Offset(0, 0), blurStyle: BlurStyle.inner),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: borderColor, blurRadius: 10)],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: borderColor, fontWeight: FontWeight.w600, shadows: [Shadow(color: borderColor, blurRadius: 5)])),
      ],
    );
  }

  Widget _buildMinimal(int value, String label, double fontSize, Color color) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.w300, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Color? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is Color) return color;
    final colorStr = color.toString();
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.replaceFirst('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    }
    return null;
  }
  
  FontWeight _parseFontWeight(dynamic value) {
    if (value == null) return FontWeight.normal;
    switch (value.toString().toLowerCase()) {
      case 'bold': return FontWeight.bold;
      case 'normal': return FontWeight.normal;
      case 'w100': return FontWeight.w100;
      case 'w200': return FontWeight.w200;
      case 'w300': return FontWeight.w300;
      case 'w400': return FontWeight.w400;
      case 'w500': return FontWeight.w500;
      case 'w600': return FontWeight.w600;
      case 'w700': return FontWeight.w700;
      case 'w800': return FontWeight.w800;
      case 'w900': return FontWeight.w900;
      default: return FontWeight.normal;
    }
  }

  double? _parseHeight(dynamic value, double screenHeight) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.endsWith('%')) {
        final percentage = double.tryParse(value.replaceAll('%', ''));
        if (percentage != null) {
          return screenHeight * (percentage / 100);
        }
      }
      return double.tryParse(value);
    }
    return null;
  }

  Gradient? _parseGradient(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final type = value['type'] as String? ?? 'linear';
      final colors = (value['colors'] as List?)?.map((c) => _parseColor(c) ?? Colors.transparent).toList() ?? [];
      final stops = (value['stops'] as List?)?.map((s) => (s as num).toDouble()).toList();
      final begin = _parseAlignment(value['begin'] ?? 'topCenter');
      final end = _parseAlignment(value['end'] ?? 'bottomCenter');

      if (colors.isEmpty) return null;

      if (type == 'linear') {
        return LinearGradient(
          colors: colors,
          stops: stops,
          begin: begin,
          end: end,
        );
      } else if (type == 'radial') {
        return RadialGradient(
          colors: colors,
          stops: stops,
        );
      }
    }
    return null;
  }

  Alignment _parseAlignment(String value) {
    switch (value) {
      case 'topLeft': return Alignment.topLeft;
      case 'topCenter': return Alignment.topCenter;
      case 'topRight': return Alignment.topRight;
      case 'centerLeft': return Alignment.centerLeft;
      case 'center': return Alignment.center;
      case 'centerRight': return Alignment.centerRight;
      case 'bottomLeft': return Alignment.bottomLeft;
      case 'bottomCenter': return Alignment.bottomCenter;
      case 'bottomRight': return Alignment.bottomRight;
      default: return Alignment.topCenter;
    }
  }

  BorderRadius _parseBorderRadius(dynamic value) {
    if (value is num) return BorderRadius.circular(value.toDouble());
    if (value is Map) {
      return BorderRadius.only(
        topLeft: Radius.circular((value['topLeft'] as num?)?.toDouble() ?? 0),
        topRight: Radius.circular((value['topRight'] as num?)?.toDouble() ?? 0),
        bottomLeft: Radius.circular((value['bottomLeft'] as num?)?.toDouble() ?? 0),
        bottomRight: Radius.circular((value['bottomRight'] as num?)?.toDouble() ?? 0),
      );
    }
    return BorderRadius.zero;
  }

  List<BoxShadow>? _parseBoxShadow(dynamic value) {
    if (value is List) {
      return value.map((s) {
        if (s is Map) {
          return BoxShadow(
            color: _parseColor(s['color']) ?? Colors.black.withOpacity(0.1),
            offset: Offset(
              (s['offset']?['x'] as num?)?.toDouble() ?? 0,
              (s['offset']?['y'] as num?)?.toDouble() ?? 0,
            ),
            blurRadius: (s['blur'] as num?)?.toDouble() ?? 0,
            spreadRadius: (s['spread'] as num?)?.toDouble() ?? 0,
          );
        }
        return const BoxShadow();
      }).toList();
    }
    return null;
  }

  EdgeInsets? _parseEdgeInsets(dynamic value) {
    if (value is num) return EdgeInsets.all(value.toDouble());
    if (value is Map) {
      return EdgeInsets.only(
        top: (value['top'] as num?)?.toDouble() ?? 0,
        right: (value['right'] as num?)?.toDouble() ?? 0,
        bottom: (value['bottom'] as num?)?.toDouble() ?? 0,
        left: (value['left'] as num?)?.toDouble() ?? 0,
      );
    }
    return null;
  }

  MainAxisAlignment _parseMainAxisAlignment(String? value) {
    switch (value) {
      case 'flex-start': return MainAxisAlignment.start;
      case 'center': return MainAxisAlignment.center;
      case 'flex-end': return MainAxisAlignment.end;
      case 'space-between': return MainAxisAlignment.spaceBetween;
      case 'space-around': return MainAxisAlignment.spaceAround;
      case 'space-evenly': return MainAxisAlignment.spaceEvenly;
      default: return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? value) {
    switch (value) {
      case 'flex-start': return CrossAxisAlignment.start;
      case 'center': return CrossAxisAlignment.center;
      case 'flex-end': return CrossAxisAlignment.end;
      case 'stretch': return CrossAxisAlignment.stretch;
      case 'baseline': return CrossAxisAlignment.baseline;
      default: return CrossAxisAlignment.center;
    }
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start: return WrapAlignment.start;
      case MainAxisAlignment.center: return WrapAlignment.center;
      case MainAxisAlignment.end: return WrapAlignment.end;
      case MainAxisAlignment.spaceBetween: return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround: return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly: return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(CrossAxisAlignment alignment) {
    switch (alignment) {
      case CrossAxisAlignment.start: return WrapCrossAlignment.start;
      case CrossAxisAlignment.center: return WrapCrossAlignment.center;
      case CrossAxisAlignment.end: return WrapCrossAlignment.end;
      default: return WrapCrossAlignment.center;
    }
  }

  BoxFit _parseBoxFit(String? value) {
    switch (value) {
      case 'contain': return BoxFit.contain;
      case 'cover': return BoxFit.cover;
      case 'fill': return BoxFit.fill;
      case 'fitWidth': return BoxFit.fitWidth;
      case 'fitHeight': return BoxFit.fitHeight;
      case 'none': return BoxFit.none;
      case 'scaleDown': return BoxFit.scaleDown;
      default: return BoxFit.cover;
    }
  }

  IconData? _getIconData(String name) {
    switch (name) {
      case 'arrow_forward': return Icons.arrow_forward;
      case 'arrow_back': return Icons.arrow_back;
      case 'check': return Icons.check;
      case 'close': return Icons.close;
      case 'search': return Icons.search;
      case 'home': return Icons.home;
      case 'settings': return Icons.settings;
      case 'person': return Icons.person;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'star': return Icons.star;
      case 'favorite': return Icons.favorite;
      case 'share': return Icons.share;
      case 'download': return Icons.download;
      case 'play_arrow': return Icons.play_arrow;
      case 'pause': return Icons.pause;
      default: return null;
    }
  }

  TextAlign _parseTextAlign(String? value) {
    switch (value) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }

  TextOverflow _parseTextOverflow(String? value) {
    switch (value) {
      case 'ellipsis': return TextOverflow.ellipsis;
      case 'clip': return TextOverflow.clip;
      case 'fade': return TextOverflow.fade;
      case 'visible': return TextOverflow.visible;
      default: return TextOverflow.clip;
    }
  }

  TextStyle _parseTextStyle(Map<String, dynamic> style) {
    return TextStyle(
      fontSize: (style['fontSize'] as num?)?.toDouble(),
      fontWeight: _parseFontWeight(style['fontWeight']),
      fontStyle: style['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
      decoration: style['textDecoration'] == 'underline' ? TextDecoration.underline : TextDecoration.none,
      fontFamily: style['fontFamily'],
      height: (style['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (style['letterSpacing'] as num?)?.toDouble(),
    );
  }

  String _substituteVariables(String text, List? variables) {
    if (variables == null || variables.isEmpty) return text;
    String result = text;
    for (final v in variables) {
      if (v is Map) {
        final key = v['key'];
        final val = v['value'];
        if (key != null && val != null) {
          result = result.replaceAll('{{$key}}', val.toString());
        }
      }
    }
    return result;
  }

  Color _adjustColorBrightness(Color color, double amount) {
    assert(amount >= -1 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class _EntranceAnimator extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic> animation;

  const _EntranceAnimator({
    Key? key,
    required this.child,
    required this.animation,
  }) : super(key: key);

  @override
  State<_EntranceAnimator> createState() => _EntranceAnimatorState();
}

class _EntranceAnimatorState extends State<_EntranceAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final duration = Duration(milliseconds: (widget.animation['duration'] as num?)?.toInt() ?? 600);
    final delay = Duration(milliseconds: (widget.animation['delay'] as num?)?.toInt() ?? 0);
    final type = widget.animation['type'] as String? ?? 'fade';

    final easingStr = widget.animation['easing'] as String? ?? 'easeOut';
    final curve = _parseCurve(easingStr);

    _controller = AnimationController(vsync: this, duration: duration);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );

    // Slide defaults
    Offset beginSlide = const Offset(0, 0.2); // Slide Up
    if (type == 'slide-left') beginSlide = const Offset(0.2, 0);
    if (type == 'slide-right') beginSlide = const Offset(-0.2, 0);
    if (type == 'slide-down') beginSlide = const Offset(0, -0.2);

    _slideAnimation = Tween<Offset>(begin: beginSlide, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (delay.inMilliseconds > 0) {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.animation['type'] as String? ?? 'fade';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget animatedChild = widget.child;

        if (type.contains('slide')) {
          animatedChild = SlideTransition(position: _slideAnimation, child: animatedChild);
        }
        if (type.contains('scale') || type == 'zoom') {
          animatedChild = ScaleTransition(scale: _scaleAnimation, child: animatedChild);
        }
        // Always fade unless explicitly disabled (which we don't support yet)
        animatedChild = FadeTransition(opacity: _fadeAnimation, child: animatedChild);

        return animatedChild;
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StripedBarPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;
  final double borderRadius;

  _StripedBarPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(borderRadius));

    // Background
    paint.color = backgroundColor;
    canvas.drawRRect(rrect, paint);

    // Foreground (Striped)
    canvas.save();
    canvas.clipRRect(rrect);
    
    final fillWidth = size.width * percentage;
    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    
    paint.color = color;
    canvas.drawRect(fillRect, paint);

    // Stripes
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final stripeWidth = 10.0;
    final spacing = 10.0;
    
    for (double i = -size.height; i < fillWidth; i += stripeWidth + spacing) {
      final path = Path()
        ..moveTo(i, size.height)
        ..lineTo(i + stripeWidth, size.height)
        ..lineTo(i + stripeWidth + size.height, 0)
        ..lineTo(i + size.height, 0)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}

class _ProgressCirclePainter extends CustomPainter {
  final double percentage;
  final String variant;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _ProgressCirclePainter({
    required this.percentage,
    required this.variant,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Draw Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (variant == 'dashed') {
      // Dashed track logic (simplified)
      _drawDashedCircle(canvas, center, radius, trackPaint);
    } else if (variant == 'semicircle') {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75, // Start at 135 degrees
        math.pi * 1.5,  // Sweep 270 degrees
        false,
        trackPaint..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(center, radius, trackPaint);
    }

    // Draw Progress
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (variant == 'semicircle') {
      final sweepAngle = (math.pi * 1.5) * percentage;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75,
        sweepAngle,
        false,
        progressPaint,
      );
    } else {
      final sweepAngle = 2 * math.pi * percentage;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();
    final anglePerDash = (2 * math.pi) / dashCount;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        anglePerDash * i,
        anglePerDash * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressCirclePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
           oldDelegate.variant != variant ||
           oldDelegate.color != color;
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 0.0,
    this.gap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = _dashPath(path, dashArray: CircularIntervalList<double>([gap, gap]));
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, {required CircularIntervalList<double> dashArray}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final len = dashArray.next;
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.radius != radius ||
           oldDelegate.gap != gap;
  }
}

class CircularIntervalList<T> {
  final List<T> _values;
  int _index = 0;

  CircularIntervalList(this._values);

  T get next {
    if (_index >= _values.length) {
      _index = 0;
    }
    return _values[_index++];
  }
}



class _CyberpunkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - 20, 0);
    path.lineTo(size.width, 20);
    path.lineTo(size.width, size.height);
    path.lineTo(20, size.height);
    path.lineTo(0, size.height - 20);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
