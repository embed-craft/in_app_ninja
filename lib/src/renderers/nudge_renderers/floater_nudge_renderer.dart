import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/campaign.dart';

class FloaterNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const FloaterNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<FloaterNudgeRenderer> createState() => _FloaterNudgeRendererState();
}

class _FloaterNudgeRendererState extends State<FloaterNudgeRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final position = config['position']?.toString() ?? 'bottom-right';
    final mode = config['mode']?.toString() ?? 'default';
    final shape = config['shape']?.toString() ?? 'circle';
    
    // Dimensions
    final width = (config['width'] as num?)?.toDouble() ?? (mode == 'image-only' || shape == 'circle' ? 60.0 : 200.0);
    final height = (config['height'] as num?)?.toDouble() ?? (mode == 'image-only' || shape == 'circle' ? 60.0 : 300.0);
    final offsetX = (config['offsetX'] as num?)?.toDouble() ?? 20.0;
    final offsetY = (config['offsetY'] as num?)?.toDouble() ?? 20.0;

    // Positioning
    double? left, right, top, bottom;
    switch (position) {
      case 'bottom-right':
        bottom = offsetY;
        right = offsetX;
        break;
      case 'bottom-left':
        bottom = offsetY;
        left = offsetX;
        break;
      case 'top-right':
        top = offsetY;
        right = offsetX;
        break;
      case 'top-left':
        top = offsetY;
        left = offsetX;
        break;
      case 'center-right':
        right = offsetX;
        // Vertical center handled by Align/Stack usually, but here we use absolute
        // We might need MediaQuery to center vertically if using Stack
        break;
      case 'center-left':
        left = offsetX;
        break;
    }

    // Styling
    final backgroundColor = _parseColor(config['backgroundColor']) ?? const Color(0xFF10B981);
    final borderRadius = (config['borderRadius'] as num?)?.toDouble() ?? 16.0;
    final opacity = (config['opacity'] as num?)?.toDouble() ?? 1.0;
    
    // Glassmorphism
    final glassConfig = config['glassmorphism'] as Map<String, dynamic>?;
    final isGlass = glassConfig?['enabled'] == true;
    final glassBlur = (glassConfig?['blur'] as num?)?.toDouble() ?? 10.0;
    final glassOpacity = (glassConfig?['opacity'] as num?)?.toDouble() ?? 0.2;

    // Gradient
    final gradientConfig = config['gradient'] as Map<String, dynamic>?;
    final isGradient = gradientConfig?['enabled'] == true;
    Gradient? gradient;
    if (isGradient) {
      gradient = LinearGradient(
        colors: [
          _parseColor(gradientConfig?['startColor']) ?? backgroundColor,
          _parseColor(gradientConfig?['endColor']) ?? backgroundColor,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        // Angle support would require custom Transform on Gradient
      );
    }

    // Image Only Background
    final backgroundImageUrl = config['backgroundImageUrl'] as String?;
    final isImageOnly = mode == 'image-only';

    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isGlass 
            ? backgroundColor.withOpacity(glassOpacity) 
            : (isImageOnly ? Colors.transparent : (isGradient ? null : backgroundColor)),
        gradient: isGradient ? gradient : null,
        borderRadius: shape == 'circle' ? null : BorderRadius.circular(borderRadius),
        shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
        boxShadow: isImageOnly ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          )
        ],
        image: isImageOnly && backgroundImageUrl != null ? DecorationImage(
          image: NetworkImage(backgroundImageUrl),
          fit: BoxFit.cover,
        ) : null,
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
      ),
      child: isImageOnly ? null : _buildContent(config),
    );

    // Apply Glassmorphism Blur
    if (isGlass) {
      content = ClipRRect(
        borderRadius: shape == 'circle' 
            ? BorderRadius.circular(width / 2) 
            : BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
          child: content,
        ),
      );
    } else if (shape == 'circle') {
       content = ClipOval(child: content);
    } else {
       content = ClipRRect(
         borderRadius: BorderRadius.circular(borderRadius),
         child: content,
       );
    }

    // Apply Opacity
    if (opacity < 1.0) {
      content = Opacity(opacity: opacity, child: content);
    }

    // Center Vertical Logic
    if (position.startsWith('center')) {
      return Positioned(
        top: 0,
        bottom: 0,
        left: left,
        right: right,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: content,
          ),
        ),
      );
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SafeArea(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: content,
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> config) {
    if (config['components'] != null && config['components'] is List) {
      return _buildFlexibleLayout(config);
    }
    return const Center(child: Icon(Icons.message, color: Colors.white));
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
        absoluteComponents.add(Positioned(
          top: (style['top'] as num?)?.toDouble(),
          right: (style['right'] as num?)?.toDouble(),
          bottom: (style['bottom'] as num?)?.toDouble(),
          left: (style['left'] as num?)?.toDouble(),
          child: child,
        ));
      } else {
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

    child = _applyStyle(child, component['style'] as Map<String, dynamic>? ?? {});
    child = _buildInteraction(child, component);
    
    return child;
  }

  Widget _buildTextComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    String text = content['text'] as String? ?? '';
    text = _substituteVariables(text, widget.campaign.config['variables'] as List?);

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
    final themeColor = _parseColor(content['themeColor']) ?? _parseColor(style['backgroundColor']) ?? const Color(0xFF6366F1);
    final textColor = _parseColor(content['textColor']) ?? _parseColor(style['color']) ?? Colors.white;
    final borderRadius = (style['borderRadius'] as num?)?.toDouble() ?? 8.0;
    
    return GestureDetector(
      onTap: () => _handleAction(action),
      child: Container(
        padding: _parseEdgeInsets(style['padding']) ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
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
          return Container(
            width: 20,
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

  Widget _buildBadgeComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final text = content['badgeText'] as String? ?? 'Badge';
    final variant = content['badgeVariant'] as String? ?? 'custom';
    final iconName = content['badgeIcon'] as String?;
    final iconPosition = content['badgeIconPosition'] as String? ?? 'left';

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

    return Container(
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
  }

  Widget _buildContainerComponent(Map<String, dynamic> component) {
    final children = component['children'] as List? ?? [];
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final flexLayout = component['flexLayout'] as Map<String, dynamic>? ?? {};
    
    Widget content;
    
    if (flexLayout['enabled'] == true) {
      content = _buildFlexibleLayout({
        'components': children,
        'layout': flexLayout,
      });
    } else {
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

    final bgColor = _parseColor(style['backgroundColor']);
    final bgImage = style['backgroundImage'] as String?;
    final gradient = _parseGradient(style['backgroundGradient']);
    final shadows = _parseBoxShadow(style['shadows'] as List?);
    final overflow = style['overflow'] as String? ?? 'visible';
    
    DecorationImage? decorationImage;
    if (bgImage != null && bgImage.isNotEmpty) {
      decorationImage = DecorationImage(
        image: NetworkImage(bgImage),
        fit: _parseBoxFit(style['backgroundSize'] ?? 'cover'),
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
        gradient: gradient,
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
        // No setState available here easily unless we add it to the class
        // For now just logging
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

  Widget _buildCheckboxComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final label = content['checkboxLabel'] as String? ?? 'Checkbox';
    final name = content['name'] as String?;
    
    // Simple checkbox for display
    final isChecked = content['checked'] as bool? ?? false;
    final checkboxColor = _parseColor(content['checkboxColor']) ?? const Color(0xFF6366F1);
    final textColor = _parseColor(content['textColor']) ?? const Color(0xFF374151);
    final fontSize = (content['fontSize'] as num?)?.toDouble() ?? 14.0;

    return GestureDetector(
      onTap: () {},
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
    final RegExp exp = RegExp(r'<(\w+)(?:[^>]*)>(.*?)<\/\1>|([^<]+)');
    final matches = exp.allMatches(html);

    if (matches.isEmpty) {
      spans.add(TextSpan(text: html));
      return spans;
    }

    for (final match in matches) {
      if (match.group(3) != null) {
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
        }
        spans.add(TextSpan(text: text, style: style));
      }
    }
    return spans;
  }

  Widget _buildProgressBarComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildRatingComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildCarouselComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildAccordionComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildCountdownComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildStatisticComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildProgressCircleComponent(Map<String, dynamic> c) => const SizedBox.shrink();
  Widget _buildGradientOverlayComponent(Map<String, dynamic> c) => const SizedBox.shrink();

  // --- Helpers ---

  void _handleAction(String action, [Map<String, dynamic>? data]) {
    if (action == 'dismiss') {
      widget.onDismiss?.call();
    } else {
      widget.onCTAClick?.call(action, data);
    }
  }

  EdgeInsets? _parseEdgeInsets(dynamic padding) {
    if (padding is num) {
      return EdgeInsets.all(padding.toDouble());
    }
    if (padding is Map) {
      return EdgeInsets.only(
        top: (padding['top'] as num?)?.toDouble() ?? 0,
        right: (padding['right'] as num?)?.toDouble() ?? 0,
        bottom: (padding['bottom'] as num?)?.toDouble() ?? 0,
        left: (padding['left'] as num?)?.toDouble() ?? 0,
      );
    }
    return null;
  }

  MainAxisAlignment _parseMainAxisAlignment(String? value) {
    switch (value) {
      case 'flex-start': return MainAxisAlignment.start;
      case 'flex-end': return MainAxisAlignment.end;
      case 'center': return MainAxisAlignment.center;
      case 'space-between': return MainAxisAlignment.spaceBetween;
      case 'space-around': return MainAxisAlignment.spaceAround;
      case 'space-evenly': return MainAxisAlignment.spaceEvenly;
      default: return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? value) {
    switch (value) {
      case 'flex-start': return CrossAxisAlignment.start;
      case 'flex-end': return CrossAxisAlignment.end;
      case 'center': return CrossAxisAlignment.center;
      case 'stretch': return CrossAxisAlignment.stretch;
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

  TextStyle _parseTextStyle(Map<String, dynamic> style) {
    return TextStyle(
      fontWeight: _parseFontWeight(style['fontWeight']),
      fontStyle: style['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
      decoration: style['textDecoration'] == 'underline' ? TextDecoration.underline : TextDecoration.none,
    );
  }

  FontWeight _parseFontWeight(dynamic weight) {
    if (weight == 'bold') return FontWeight.bold;
    if (weight == 'medium') return FontWeight.w500;
    if (weight == 'light') return FontWeight.w300;
    if (weight is int) {
      if (weight >= 700) return FontWeight.bold;
      if (weight >= 500) return FontWeight.w500;
      if (weight >= 300) return FontWeight.w300;
    }
    return FontWeight.normal;
  }

  TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }

  TextOverflow _parseTextOverflow(String? overflow) {
    switch (overflow) {
      case 'ellipsis': return TextOverflow.ellipsis;
      case 'clip': return TextOverflow.clip;
      case 'fade': return TextOverflow.fade;
      default: return TextOverflow.visible;
    }
  }

  BoxFit _parseBoxFit(String? fit) {
    switch (fit) {
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'fitWidth': return BoxFit.fitWidth;
      case 'fitHeight': return BoxFit.fitHeight;
      case 'none': return BoxFit.none;
      default: return BoxFit.cover;
    }
  }

  List<BoxShadow>? _parseBoxShadow(List? shadows) {
    if (shadows == null) return null;
    return shadows.map((s) {
      if (s is Map) {
        return BoxShadow(
          color: _parseColor(s['color']) ?? Colors.black.withOpacity(0.1),
          offset: Offset(
            (s['x'] as num?)?.toDouble() ?? 0,
            (s['y'] as num?)?.toDouble() ?? 0,
          ),
          blurRadius: (s['blur'] as num?)?.toDouble() ?? 0,
          spreadRadius: (s['spread'] as num?)?.toDouble() ?? 0,
        );
      }
      return const BoxShadow();
    }).toList();
  }

  String _substituteVariables(String text, List? variables) {
    return text;
  }

  bool _evaluateVisibility(dynamic condition, Map<String, dynamic> variables) {
    return true;
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
      final match = RegExp(r'blur\((\d+(?:\.\d+)?)px\)').firstMatch(backdropFilter);
      if (match != null) {
        final sigma = double.tryParse(match.group(1) ?? '0') ?? 0;
        if (sigma > 0) {
          child = ClipRRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
          );
        }
      }
    }

    // 6. Filters (Grayscale)
    final filter = style['filter'] as String?;
    if (filter != null && filter.contains('grayscale')) {
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

    // 7. Background & Border (Container)
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

  Widget _buildInteraction(Widget child, Map<String, dynamic> component) {
    final action = component['content']?['action'] as Map<String, dynamic>?;
    if (action == null) {
      if (component['onClick'] != null) {
        return GestureDetector(
          onTap: () => _handleAction(component['onClick']['action']),
          child: child,
        );
      }
      return child;
    }

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
    if (color is String) {
      if (color.startsWith('#')) {
        return Color(int.parse(color.substring(1), radix: 16) + 0xFF000000);
      } else if (color.startsWith('rgba')) {
        final parts = color.substring(5, color.length - 1).split(',');
        if (parts.length == 4) {
          return Color.fromRGBO(
            int.parse(parts[0].trim()),
            int.parse(parts[1].trim()),
            int.parse(parts[2].trim()),
            double.parse(parts[3].trim()),
          );
        }
      }
    }
    return null;
  }
}

class _EntranceAnimator extends StatefulWidget {
  final Widget child;
  final Map<String, dynamic> animation;

  const _EntranceAnimator({Key? key, required this.child, required this.animation}) : super(key: key);

  @override
  State<_EntranceAnimator> createState() => _EntranceAnimatorState();
}

class _EntranceAnimatorState extends State<_EntranceAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final duration = widget.animation['duration'] as int? ?? 500;
    final delay = widget.animation['delay'] as int? ?? 0;
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
