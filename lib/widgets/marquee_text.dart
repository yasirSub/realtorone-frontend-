import 'package:flutter/material.dart';

/// Horizontally scrolls [text] when it is wider than the available width.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 32,
    this.velocity = 28,
  });

  final String text;
  final TextStyle style;
  final double gap;

  /// Logical pixels per second.
  final double velocity;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _segmentWidth = 0;
  String _lastText = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller?.dispose();
      _controller = null;
      _lastText = '';
    }
  }

  void _ensureController(double segmentWidth) {
    if (_controller != null &&
        (_segmentWidth - segmentWidth).abs() < 1 &&
        _lastText == widget.text) {
      return;
    }

    _controller?.dispose();
    _segmentWidth = segmentWidth;
    _lastText = widget.text;

    final durationMs =
        ((segmentWidth / widget.velocity) * 1000).clamp(4000, 24000).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat();
  }

  double get _lineHeight {
    final fontSize = widget.style.fontSize ?? 14;
    final heightFactor = widget.style.height ?? 1.2;
    return fontSize * heightFactor;
  }

  Widget _marqueeStrip(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: widget.style, maxLines: 1, softWrap: false),
        SizedBox(width: widget.gap),
        Text(text, style: widget.style, maxLines: 1, softWrap: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= 0) {
          return Text(
            text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final painter = TextPainter(
          text: TextSpan(text: text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: double.infinity);

        final textWidth = painter.width;
        if (textWidth <= maxWidth + 2) {
          _controller?.dispose();
          _controller = null;
          return Text(
            text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final segmentWidth = textWidth + widget.gap;
        _ensureController(segmentWidth);

        final controller = _controller;
        if (controller == null) {
          return Text(
            text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return SizedBox(
          width: maxWidth,
          height: _lineHeight,
          child: ClipRect(
            clipBehavior: Clip.hardEdge,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final offset = controller.value * segmentWidth;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: -offset,
                      top: 0,
                      child: _marqueeStrip(text),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
