import 'package:flutter/material.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/share_template.dart';
import 'share_card_renderer.dart';

/// Widget de preview de una plantilla de compartir (usado en ShareOptionsSheet).
class ShareTemplatePreview extends StatelessWidget {
  final ShareCardTemplate template;
  final BibleVerse verse;
  final bool selected;
  final VoidCallback? onTap;

  const ShareTemplatePreview({
    super.key,
    required this.template,
    required this.verse,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: const Color(0xFFD4A853), width: 2)
              : Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          fit: BoxFit.cover,
          child: ShareCardRenderer(
            template: template,
            verseText: verse.text,
            reference: verse.reference,
            version: verse.version,
            cardSize: const Size(1080, 1080),
          ),
        ),
      ),
    );
  }
}
