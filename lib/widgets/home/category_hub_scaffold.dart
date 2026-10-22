import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../vec/vec_tema.dart';

class CategoryHubScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CategoryHubScaffold({
    super.key,
    required this.title,
    required this.children,
  });


  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final tema = AppThemeData.of(context);
    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          systemOverlayStyle:
              (tema.oscuro
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: VecColores.crema,
                  ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppDesignSystem.spacingM,
            AppDesignSystem.spacingL,
            AppDesignSystem.spacingM,
            mediaPadding.bottom + AppDesignSystem.spacingXL,
          ),
          children: children,
        ),
      );
  }
}
