import 'package:flutter/material.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

class ExpressionLine extends StatelessWidget {
  final Expression expression;
  final String? previewText;
  final ThemeColors colors;

  const ExpressionLine({
    super.key,
    required this.expression,
    this.previewText,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = expression.getAllTokens();

    if (tokens.isEmpty) {
      return const SizedBox(height: 32.0);
    }

    final spans = <TextSpan>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final isLast = i == tokens.length - 1;

      if (token.isOperator) {
        spans.add(
          TextSpan(
            text: token.text,
            style: TextStyle(
              color: colors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 22.0,
            ),
          ),
        );
      } else if (token.isPercent) {
        spans.add(
          TextSpan(
            text: '%',
            style: TextStyle(
              color: colors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 20.0,
            ),
          ),
        );
      } else {
        // Number token
        spans.add(
          TextSpan(
            text: token.text,
            style: TextStyle(
              color: isLast ? colors.ink : colors.inkSoft,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
              fontSize: 22.0,
            ),
          ),
        );
      }
    }

    return Container(
      alignment: Alignment.center, // Centered directly above the hero 3D numerals
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'BebasNeue',
              letterSpacing: 0.5,
            ),
            children: spans,
          ),
        ),
      ),
    );
  }
}
