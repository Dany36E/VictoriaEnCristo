import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_quitar/theme/app_theme_data.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('all theme body text meets WCAG AA contrast on cards', () {
    for (final theme in AppThemeData.all) {
      expect(
        _contrastRatio(theme.textPrimary, theme.cardBg),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.name}: primary text on card',
      );
      expect(
        _contrastRatio(theme.textSecondary, theme.cardBg),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.name}: secondary text on card',
      );
    }
  });
}
