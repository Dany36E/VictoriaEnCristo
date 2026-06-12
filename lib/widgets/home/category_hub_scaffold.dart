import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class CategoryHubScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CategoryHubScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppDesignSystem.midnightDeep,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: AppDesignSystem.midnightDeep,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          foregroundColor: AppDesignSystem.pureWhite,
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: _overlayStyle,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/bible/share_backgrounds/cosmos.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppDesignSystem.midnightDeep.withValues(alpha: 0.80),
                      AppDesignSystem.midnight.withValues(alpha: 0.68),
                      AppDesignSystem.midnightDeep.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppDesignSystem.spacingM,
                mediaPadding.top + kToolbarHeight + AppDesignSystem.spacingS,
                AppDesignSystem.spacingM,
                mediaPadding.bottom + AppDesignSystem.spacingXL,
              ),
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}
