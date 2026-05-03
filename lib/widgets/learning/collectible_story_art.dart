import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/collectibles_catalog.dart';
import '../../models/learning/book_models.dart';
import '../../theme/app_theme.dart';

class CollectibleStoryArt extends StatelessWidget {
  final BibleBook book;
  final CollectibleItem item;
  final bool unlocked;
  final bool compact;
  final double borderRadius;

  const CollectibleStoryArt({
    super.key,
    required this.book,
    required this.item,
    required this.unlocked,
    this.compact = false,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CollectibleStoryPainter(
              book: book,
              kind: item.kind,
              unlocked: unlocked,
              compact: compact,
            ),
          ),
          if (!unlocked)
            ColoredBox(
              color: Colors.black.withOpacity(0.16),
              child: Center(
                child: Container(
                  width: compact ? 28 : 42,
                  height: compact ? 28 : 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.34),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.26)),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white.withOpacity(0.82),
                    size: compact ? 15 : 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BookStoryMural extends StatelessWidget {
  final BibleBook book;
  final int unlockedCount;
  final int totalCount;
  final bool compact;
  final double borderRadius;

  const BookStoryMural({
    super.key,
    required this.book,
    required this.unlockedCount,
    required this.totalCount,
    this.compact = false,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final items = CollectiblesCatalog.I
        .itemsForBook(book.id)
        .take(totalCount)
        .toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppDesignSystem.midnightDeep),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 1),
                  child: CollectibleStoryArt(
                    book: book,
                    item: items[index],
                    unlocked: index < unlockedCount,
                    compact: true,
                    borderRadius: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectibleStoryPainter extends CustomPainter {
  final BibleBook book;
  final CollectibleKind kind;
  final bool unlocked;
  final bool compact;

  _CollectibleStoryPainter({
    required this.book,
    required this.kind,
    required this.unlocked,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final palette = _StoryPalette.from(book: book, kind: kind, unlocked: unlocked);

    _paintBackground(canvas, bounds, palette);
    _paintBookFingerprint(canvas, size, palette);

    switch (kind) {
      case CollectibleKind.cover:
        _paintCover(canvas, size, palette);
        break;
      case CollectibleKind.scene:
        _paintScene(canvas, size, palette);
        break;
      case CollectibleKind.map:
        _paintRoute(canvas, size, palette);
        break;
      case CollectibleKind.devotional:
        _paintDevotional(canvas, size, palette);
        break;
      case CollectibleKind.calligraphy:
        _paintCalligraphy(canvas, size, palette);
        break;
    }

    _paintCategoryEmblem(canvas, size, palette);
    _paintFrame(canvas, bounds, palette);
  }

  void _paintBackground(Canvas canvas, Rect bounds, _StoryPalette palette) {
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.sky, palette.middle, palette.ground],
      ).createShader(bounds);
    canvas.drawRect(bounds, backgroundPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.36 + (book.order % 7) * 0.12, -0.48),
        radius: 0.9,
        colors: [palette.light.withOpacity(0.72), Colors.transparent],
      ).createShader(bounds);
    canvas.drawRect(bounds, glowPaint);
  }

  void _paintBookFingerprint(Canvas canvas, Size size, _StoryPalette palette) {
    final count = 4 + (book.chapters % 7);
    final dotPaint = Paint()..color = palette.light.withOpacity(unlocked ? 0.36 : 0.18);
    for (var index = 0; index < count; index++) {
      final seed = book.order * 37 + kind.index * 19 + index * 11;
      final dx = (0.12 + ((_wave(seed) + 1) / 2) * 0.76) * size.width;
      final dy = (0.10 + ((_wave(seed + 5) + 1) / 2) * 0.55) * size.height;
      final radius = (compact ? 1.2 : 2.0) + (index % 3) * 0.65;
      canvas.drawCircle(Offset(dx, dy), radius, dotPaint);
    }
  }

  void _paintCover(Canvas canvas, Size size, _StoryPalette palette) {
    final center = Offset(size.width * 0.5, size.height * 0.53);
    final width = size.width * (compact ? 0.52 : 0.46);
    final height = size.height * 0.56;
    final bookRect = Rect.fromCenter(center: center, width: width, height: height);
    final pagePaint = Paint()..color = palette.paper.withOpacity(unlocked ? 0.96 : 0.42);
    final coverPaint = Paint()..color = palette.primary.withOpacity(unlocked ? 0.72 : 0.3);
    final linePaint = Paint()
      ..color = palette.dark.withOpacity(unlocked ? 0.52 : 0.24)
      ..strokeWidth = math.max(1, size.shortestSide * 0.012);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bookRect, Radius.circular(size.shortestSide * 0.035)),
      pagePaint,
    );
    canvas.drawRect(Rect.fromLTWH(bookRect.left, bookRect.top, width * 0.18, height), coverPaint);
    canvas.drawLine(
      Offset(bookRect.left + width * 0.3, bookRect.top + height * 0.2),
      Offset(bookRect.right - width * 0.14, bookRect.top + height * 0.2),
      linePaint,
    );
    canvas.drawLine(
      Offset(bookRect.left + width * 0.3, bookRect.top + height * 0.38),
      Offset(bookRect.right - width * 0.2, bookRect.top + height * 0.38),
      linePaint,
    );
    canvas.drawCircle(
      center.translate(0, -height * 0.02),
      width * 0.13,
      Paint()..color = palette.gold,
    );
  }

  void _paintScene(Canvas canvas, Size size, _StoryPalette palette) {
    final horizon = size.height * 0.63;
    final mountainPaint = Paint()..color = palette.dark.withOpacity(unlocked ? 0.58 : 0.34);
    final mountainPath = Path()
      ..moveTo(0, horizon)
      ..lineTo(size.width * 0.2, size.height * 0.38)
      ..lineTo(size.width * 0.42, horizon * 0.92)
      ..lineTo(size.width * 0.64, size.height * 0.32)
      ..lineTo(size.width, horizon)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountainPath, mountainPaint);

    final sunPaint = Paint()..color = palette.gold.withOpacity(unlocked ? 0.9 : 0.42);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.24),
      size.shortestSide * 0.13,
      sunPaint,
    );

    final pathPaint = Paint()
      ..color = palette.paper.withOpacity(unlocked ? 0.54 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * 0.035;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.86)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.67,
        size.width * 0.53,
        size.height * 0.73,
        size.width * 0.76,
        size.height * 0.50,
      );
    canvas.drawPath(path, pathPaint);
  }

  void _paintRoute(Canvas canvas, Size size, _StoryPalette palette) {
    final routePaint = Paint()
      ..color = palette.paper.withOpacity(unlocked ? 0.78 : 0.36)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, size.shortestSide * 0.038);
    final route = Path()
      ..moveTo(size.width * 0.16, size.height * 0.74)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.34,
        size.width * 0.62,
        size.height * 0.84,
        size.width * 0.84,
        size.height * 0.28,
      );
    canvas.drawPath(route, routePaint);

    final nodePaint = Paint()..color = palette.gold.withOpacity(unlocked ? 0.94 : 0.46);
    final nodeBorderPaint = Paint()
      ..color = palette.paper.withOpacity(unlocked ? 0.92 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.shortestSide * 0.012);
    final nodes = [
      Offset(size.width * 0.16, size.height * 0.74),
      Offset(size.width * 0.48, size.height * 0.56),
      Offset(size.width * 0.84, size.height * 0.28),
    ];
    for (final node in nodes) {
      canvas.drawCircle(node, size.shortestSide * 0.055, nodePaint);
      canvas.drawCircle(node, size.shortestSide * 0.055, nodeBorderPaint);
    }
  }

  void _paintDevotional(Canvas canvas, Size size, _StoryPalette palette) {
    final tablePaint = Paint()..color = palette.dark.withOpacity(unlocked ? 0.54 : 0.3);
    final tableRect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.68,
      size.width * 0.64,
      size.height * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, Radius.circular(size.shortestSide * 0.035)),
      tablePaint,
    );

    final flameBase = Offset(size.width * 0.5, size.height * 0.55);
    final flamePaint = Paint()..color = palette.gold.withOpacity(unlocked ? 0.95 : 0.48);
    final innerFlamePaint = Paint()..color = palette.paper.withOpacity(unlocked ? 0.86 : 0.38);
    final flame = Path()
      ..moveTo(flameBase.dx, flameBase.dy - size.height * 0.28)
      ..cubicTo(
        flameBase.dx + size.width * 0.18,
        flameBase.dy - size.height * 0.08,
        flameBase.dx + size.width * 0.06,
        flameBase.dy + size.height * 0.12,
        flameBase.dx,
        flameBase.dy + size.height * 0.12,
      )
      ..cubicTo(
        flameBase.dx - size.width * 0.12,
        flameBase.dy + size.height * 0.04,
        flameBase.dx - size.width * 0.10,
        flameBase.dy - size.height * 0.13,
        flameBase.dx,
        flameBase.dy - size.height * 0.28,
      )
      ..close();
    canvas.drawPath(flame, flamePaint);
    canvas.drawCircle(
      flameBase.translate(0, -size.height * 0.03),
      size.shortestSide * 0.06,
      innerFlamePaint,
    );
  }

  void _paintCalligraphy(Canvas canvas, Size size, _StoryPalette palette) {
    final scrollRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.52),
      width: size.width * 0.64,
      height: size.height * 0.46,
    );
    final scrollPaint = Paint()..color = palette.paper.withOpacity(unlocked ? 0.94 : 0.42);
    final strokePaint = Paint()
      ..color = palette.dark.withOpacity(unlocked ? 0.48 : 0.22)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, size.shortestSide * 0.014);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scrollRect, Radius.circular(size.shortestSide * 0.045)),
      scrollPaint,
    );

    for (var index = 0; index < 4; index++) {
      final yPosition = scrollRect.top + scrollRect.height * (0.26 + index * 0.16);
      final endInset = scrollRect.width * (0.16 + ((book.order + index) % 3) * 0.06);
      canvas.drawLine(
        Offset(scrollRect.left + scrollRect.width * 0.16, yPosition),
        Offset(scrollRect.right - endInset, yPosition),
        strokePaint,
      );
    }

    final sealPaint = Paint()..color = palette.gold.withOpacity(unlocked ? 0.9 : 0.44);
    canvas.drawCircle(
      Offset(
        scrollRect.right - scrollRect.width * 0.18,
        scrollRect.bottom - scrollRect.height * 0.2,
      ),
      size.shortestSide * 0.055,
      sealPaint,
    );
  }

  void _paintCategoryEmblem(Canvas canvas, Size size, _StoryPalette palette) {
    final center = Offset(size.width * 0.22, size.height * 0.23);
    final emblemPaint = Paint()
      ..color = palette.paper.withOpacity(unlocked ? 0.52 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.022)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final category = book.category.toLowerCase();
    if (category.contains('evangel')) {
      canvas.drawLine(
        center.translate(0, -size.height * 0.08),
        center.translate(0, size.height * 0.08),
        emblemPaint,
      );
      canvas.drawLine(
        center.translate(-size.width * 0.06, -size.height * 0.01),
        center.translate(size.width * 0.06, -size.height * 0.01),
        emblemPaint,
      );
      return;
    }
    if (category.contains('po')) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: size.width * 0.18, height: size.height * 0.2),
        math.pi * 0.32,
        math.pi * 1.25,
        false,
        emblemPaint,
      );
      canvas.drawLine(
        center.translate(0, -size.height * 0.09),
        center.translate(size.width * 0.08, size.height * 0.09),
        emblemPaint,
      );
      return;
    }
    if (category.contains('prof')) {
      final flame = Path()
        ..moveTo(center.dx, center.dy - size.height * 0.09)
        ..quadraticBezierTo(
          center.dx + size.width * 0.09,
          center.dy,
          center.dx,
          center.dy + size.height * 0.09,
        )
        ..quadraticBezierTo(
          center.dx - size.width * 0.08,
          center.dy,
          center.dx,
          center.dy - size.height * 0.09,
        );
      canvas.drawPath(flame, emblemPaint);
      return;
    }
    if (category.contains('carta') ||
        category.contains('pastoral') ||
        category.contains('general')) {
      final envelopeRect = Rect.fromCenter(
        center: center,
        width: size.width * 0.2,
        height: size.height * 0.12,
      );
      canvas.drawRect(envelopeRect, emblemPaint);
      canvas.drawLine(envelopeRect.topLeft, center, emblemPaint);
      canvas.drawLine(envelopeRect.topRight, center, emblemPaint);
      return;
    }
    if (category.contains('hist')) {
      final wallRect = Rect.fromCenter(
        center: center,
        width: size.width * 0.2,
        height: size.height * 0.13,
      );
      canvas.drawRect(wallRect, emblemPaint);
      canvas.drawLine(wallRect.topLeft, wallRect.bottomRight, emblemPaint);
      canvas.drawLine(wallRect.topRight, wallRect.bottomLeft, emblemPaint);
      return;
    }

    final tent = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.09)
      ..lineTo(center.dx - size.width * 0.1, center.dy + size.height * 0.08)
      ..lineTo(center.dx + size.width * 0.1, center.dy + size.height * 0.08)
      ..close();
    canvas.drawPath(tent, emblemPaint);
  }

  void _paintFrame(Canvas canvas, Rect bounds, _StoryPalette palette) {
    final framePaint = Paint()
      ..color = palette.paper.withOpacity(unlocked ? 0.22 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(bounds.deflate(0.6), framePaint);
  }

  double _wave(int seed) => math.sin(seed * 12.9898 + book.order * 0.78233);

  @override
  bool shouldRepaint(covariant _CollectibleStoryPainter oldDelegate) {
    return oldDelegate.book.id != book.id ||
        oldDelegate.kind != kind ||
        oldDelegate.unlocked != unlocked ||
        oldDelegate.compact != compact;
  }
}

class _StoryPalette {
  final Color sky;
  final Color middle;
  final Color ground;
  final Color primary;
  final Color light;
  final Color dark;
  final Color paper;
  final Color gold;

  const _StoryPalette({
    required this.sky,
    required this.middle,
    required this.ground,
    required this.primary,
    required this.light,
    required this.dark,
    required this.paper,
    required this.gold,
  });

  factory _StoryPalette.from({
    required BibleBook book,
    required CollectibleKind kind,
    required bool unlocked,
  }) {
    final hue = (_baseHue(book.category) + book.order * 3.7 + kind.index * 16.0) % 360;
    final saturation = unlocked ? 0.58 : 0.08;
    final lightnessShift = unlocked ? 0.0 : -0.08;
    final primary = HSLColor.fromAHSL(1, hue, saturation, 0.44 + lightnessShift).toColor();
    final sky = HSLColor.fromAHSL(
      1,
      (hue + 16) % 360,
      saturation * 0.74,
      0.28 + lightnessShift,
    ).toColor();
    final middle = HSLColor.fromAHSL(1, hue, saturation, 0.38 + lightnessShift).toColor();
    final ground = HSLColor.fromAHSL(
      1,
      (hue + 338) % 360,
      saturation,
      0.18 + lightnessShift,
    ).toColor();
    final light = HSLColor.fromAHSL(
      1,
      (hue + 42) % 360,
      unlocked ? 0.7 : 0.12,
      unlocked ? 0.72 : 0.58,
    ).toColor();
    return _StoryPalette(
      sky: sky,
      middle: middle,
      ground: ground,
      primary: primary,
      light: light,
      dark: AppDesignSystem.midnightDeep,
      paper: unlocked ? AppDesignSystem.pureWhite : const Color(0xFFD1D5DB),
      gold: unlocked ? AppDesignSystem.gold : const Color(0xFF9CA3AF),
    );
  }

  static double _baseHue(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('pentateuco')) return 34;
    if (normalized.contains('hist')) return 142;
    if (normalized.contains('po')) return 204;
    if (normalized.contains('prof')) return 18;
    if (normalized.contains('evangel')) return 48;
    if (normalized.contains('carta')) return 266;
    if (normalized.contains('pastoral')) return 300;
    if (normalized.contains('general')) return 174;
    return 226;
  }
}
