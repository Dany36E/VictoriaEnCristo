import 'package:flutter/material.dart';

import '../screens/battle_partner/battle_partner_screen.dart';
import '../screens/bible/bible_home_screen.dart';
import '../screens/devotional_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/exercises_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/learning/learning_home_screen.dart';
import '../screens/plan_library_screen.dart';
import '../screens/prayers_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/verses_screen.dart';
import '../screens/wall/wall_screen.dart';

class AppNavigation {
  const AppNavigation._();

  static Future<T?> push<T>(
    BuildContext context,
    WidgetBuilder builder, {
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute<T>(builder: builder, fullscreenDialog: fullscreenDialog));
  }

  static Future<T?> pushOn<T>(
    NavigatorState navigator,
    WidgetBuilder builder, {
    bool fullscreenDialog = false,
  }) {
    return navigator.push<T>(
      MaterialPageRoute<T>(builder: builder, fullscreenDialog: fullscreenDialog),
    );
  }

  static Future<void> openEmergency(BuildContext context) {
    return push<void>(context, (_) => const EmergencyScreen());
  }

  static Future<void> openDevotional(BuildContext context) {
    return push<void>(context, (_) => const DevotionalScreen());
  }

  static Future<void> openDevotionalFromNavigator(NavigatorState navigator) {
    return pushOn<void>(navigator, (_) => const DevotionalScreen());
  }

  static Future<void> openJournal(BuildContext context) {
    return push<void>(context, (_) => const JournalScreen());
  }

  static Future<void> openJournalFromNavigator(NavigatorState navigator) {
    return pushOn<void>(navigator, (_) => const JournalScreen());
  }

  static Future<void> openBattlePartner(BuildContext context) {
    return push<void>(context, (_) => const BattlePartnerScreen());
  }

  static Future<void> openBattlePartnerFromNavigator(NavigatorState navigator) {
    return pushOn<void>(navigator, (_) => const BattlePartnerScreen());
  }

  static Future<void> openWall(BuildContext context) {
    return push<void>(context, (_) => const WallScreen());
  }

  static Future<void> openBible(BuildContext context) {
    return push<void>(context, (_) => const BibleHomeScreen());
  }

  static Future<void> openProgress(BuildContext context) {
    return push<void>(context, (_) => const ProgressScreen());
  }

  static Future<void> openPlanLibrary(BuildContext context) {
    return push<void>(context, (_) => const PlanLibraryScreen());
  }

  static Future<void> openPrayers(BuildContext context) {
    return push<void>(context, (_) => const PrayersScreen());
  }

  static Future<void> openExercises(BuildContext context) {
    return push<void>(context, (_) => const ExercisesScreen());
  }

  static Future<void> openVerses(BuildContext context) {
    return push<void>(context, (_) => const VersesScreen());
  }

  static Future<void> openLearning(BuildContext context) {
    return push<void>(context, (_) => const LearningHomeScreen());
  }
}
