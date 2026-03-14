package com.faithvictory.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.faithvictory.ui.screens.home.HomeScreen
import com.faithvictory.ui.screens.verses.VersesScreen
import com.faithvictory.ui.screens.devotional.DevotionalScreen
import com.faithvictory.ui.screens.emergency.EmergencyScreen
import com.faithvictory.ui.screens.progress.ProgressScreen
import com.faithvictory.ui.screens.settings.SettingsScreen

@Composable
fun NavGraph(navController: NavHostController) {
    NavHost(navController = navController, startDestination = "home") {
        composable("home") { HomeScreen() }
        composable("verses") { VersesScreen() }
        composable("devotional") { DevotionalScreen() }
        composable("emergency") { EmergencyScreen() }
        composable("progress") { ProgressScreen() }
        composable("settings") { SettingsScreen() }
    }
}