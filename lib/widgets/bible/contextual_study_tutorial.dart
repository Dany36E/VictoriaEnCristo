import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/bible_reader_theme.dart';

class ContextualStudyTutorial extends StatefulWidget {
  final String tutorialId;
  final String title;
  final String summary;
  final List<StudyTutorialStep> steps;
  final BibleReaderThemeData theme;

  const ContextualStudyTutorial({
    super.key,
    required this.tutorialId,
    required this.title,
    required this.summary,
    required this.steps,
    required this.theme,
  });

  @override
  State<ContextualStudyTutorial> createState() =>
      _ContextualStudyTutorialState();
}

class _ContextualStudyTutorialState extends State<ContextualStudyTutorial> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadFirstVisit();
  }

  Future<void> _loadFirstVisit() async {
    final preferences = await SharedPreferences.getInstance();
    final key = 'bible_context_tutorial_${widget.tutorialId}_v2';
    final firstVisit = !(preferences.getBool(key) ?? false);
    if (firstVisit) await preferences.setBool(key, true);
    if (mounted && firstVisit) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: t.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.manrope(
                              color: t.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.summary,
                            style: GoogleFonts.manrope(
                              color: t.textPrimary.withValues(alpha: 0.55),
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: t.accent.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Divider(color: t.accent.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 12),
                  for (var index = 0; index < widget.steps.length; index++)
                    _buildStep(index + 1, widget.steps[index]),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, StudyTutorialStep step) {
    final t = widget.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: GoogleFonts.manrope(
                color: t.background,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${step.title}. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: step.body),
                ],
              ),
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.78),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudyTutorialStep {
  final String title;
  final String body;

  const StudyTutorialStep(this.title, this.body);
}
