import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final bool isSelectable;

  const ExpandableText({
    super.key,
    required this.text,
    required this.maxLines,
    this.style,
    this.isSelectable = false,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final span = TextSpan(text: widget.text, style: widget.style);
            final tp = TextPainter(
              text: span,
              maxLines: widget.maxLines,
              textDirection: TextDirection.ltr,
            );
            tp.layout(maxWidth: constraints.maxWidth);

            if (tp.didExceedMaxLines) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.isSelectable
                      ? SelectableText(
                          widget.text,
                          maxLines: _isExpanded ? null : widget.maxLines,
                          style: widget.style,
                        )
                      : Text(
                          widget.text,
                          maxLines: _isExpanded ? null : widget.maxLines,
                          overflow: _isExpanded ? null : TextOverflow.ellipsis,
                          style: widget.style,
                        ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Text(
                      _isExpanded ? "Daha az göster" : "Devamını oku...",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return widget.isSelectable
                  ? SelectableText(widget.text, style: widget.style)
                  : Text(widget.text, style: widget.style);
            }
          },
        ),
      ],
    );
  }
}
