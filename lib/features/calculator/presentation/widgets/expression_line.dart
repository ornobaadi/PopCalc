import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

class ExpressionLine extends StatelessWidget {
  final Expression expression;
  final String? previewText;
  final ThemeColors colors;
  final bool justEvaluated;
  final int? editingTokenIndex;
  final ValueChanged<int>? onTokenTap;
  final bool showLivePreview;

  const ExpressionLine({
    super.key,
    required this.expression,
    this.previewText,
    required this.colors,
    this.justEvaluated = false,
    this.editingTokenIndex,
    this.onTokenTap,
    this.showLivePreview = false,
  });

  // Token horizontal padding — fixed, never changes, so highlight never causes shifts
  static const double _hPad = 4.0;
  static const double _vPad = 3.0;
  // Border width is ALWAYS 2.0 — just color changes (transparent ↔ accent)
  static const double _borderW = 2.0;
  static const double _fontSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final tokens = expression.getAllTokens();

    if (tokens.isEmpty) {
      return const SizedBox(height: 44.0);
    }

    final children = <Widget>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final isSelected = editingTokenIndex == i;

      Color textColor;
      if (isSelected) {
        textColor = colors.ink;
      } else if (token.isOperator || token.isPercent) {
        textColor = colors.accent;
      } else {
        textColor = colors.ink;
      }

      children.add(
        _TokenChip(
          key: ValueKey('tok_$i'),
          text: token.text,
          textColor: textColor,
          isSelected: isSelected,
          colors: colors,
          onTap: () {
            HapticFeedback.selectionClick();
            onTokenTap?.call(i);
          },
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          hPad: _hPad,
          vPad: _vPad,
          borderW: _borderW,
          fontSize: _fontSize,
        ),
      );
    }

    // Trailing state items
    if (justEvaluated) {
      children.add(
        _StaticChip(
          text: '=',
          color: colors.accent,
          fontWeight: FontWeight.w400,
          fontSize: _fontSize,
          hPad: _hPad,
          vPad: _vPad,
          borderW: _borderW,
        ),
      );
    } else if (showLivePreview && previewText != null) {
      children.add(
        _StaticChip(
          text: '=',
          color: colors.accent,
          fontWeight: FontWeight.w400,
          fontSize: _fontSize,
          hPad: _hPad,
          vPad: _vPad,
          borderW: _borderW,
        ),
      );
      children.add(
        _StaticChip(
          text: previewText!,
          color: colors.ink.withValues(alpha: 0.65),
          fontWeight: FontWeight.w400,
          fontSize: _fontSize,
          hPad: _hPad,
          vPad: _vPad,
          borderW: _borderW,
        ),
      );
    }

    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A single tappable token chip. The container geometry is ALWAYS the same size
/// (same padding + border width) regardless of selected state, so no layout shift occurs.
/// Only the border COLOR and background COLOR animate.
class _TokenChip extends StatefulWidget {
  final String text;
  final Color textColor;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;
  final FontWeight fontWeight;
  final double hPad;
  final double vPad;
  final double borderW;
  final double fontSize;

  const _TokenChip({
    super.key,
    required this.text,
    required this.textColor,
    required this.isSelected,
    required this.colors,
    required this.onTap,
    required this.fontWeight,
    required this.hPad,
    required this.vPad,
    required this.borderW,
    required this.fontSize,
  });

  @override
  State<_TokenChip> createState() => _TokenChipState();
}

class _TokenChipState extends State<_TokenChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _TokenChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          final t = _progress.value;
          final borderColor = Color.lerp(
            Colors.transparent,
            widget.colors.accent,
            t,
          )!;
          final bgColor = Color.lerp(
            Colors.transparent,
            widget.colors.accent.withValues(alpha: 0.16),
            t,
          )!;

          return Container(
            // ← STABLE: padding + borderW NEVER change. Only colors animate.
            padding: EdgeInsets.symmetric(
              horizontal: widget.hPad,
              vertical: widget.vPad,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: widget.borderW),
              borderRadius: BorderRadius.circular(6.0),
              color: bgColor,
            ),
            child: child,
          );
        },
        child: Text(
          widget.text,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontFamilyFallback: const ['Antonio', 'sans-serif'],
            fontSize: widget.fontSize,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
            letterSpacing: 0.5,
            fontWeight: widget.fontWeight,
            color: widget.textColor,
          ),
        ),
      ),
    );
  }
}

/// Static (non-interactive) chip for = and preview number.
class _StaticChip extends StatelessWidget {
  final String text;
  final Color color;
  final FontWeight fontWeight;
  final double fontSize;
  final double hPad;
  final double vPad;
  final double borderW;

  const _StaticChip({
    required this.text,
    required this.color,
    required this.fontWeight,
    required this.fontSize,
    required this.hPad,
    required this.vPad,
    required this.borderW,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.transparent, width: borderW),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'BebasNeue',
          fontFamilyFallback: const ['Antonio', 'sans-serif'],
          fontSize: fontSize,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: 0.5,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }
}
