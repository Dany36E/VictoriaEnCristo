package com.faithvictory.ui.screens.settings

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun SettingsScreen(settingsViewModel: SettingsViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Settings") })
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.Top
        ) {
            Text(text = "Settings", style = MaterialTheme.typography.h5)
            Spacer(modifier = Modifier.height(16.dp))

            // Add settings options here
            // Example: Switch for notifications
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = "Enable Notifications")
                Spacer(modifier = Modifier.weight(1f))
                Switch(
                    checked = settingsViewModel.notificationsEnabled,
                    onCheckedChange = { settingsViewModel.toggleNotifications() }
                )
            }
            Spacer(modifier = Modifier.height(16.dp))

            // Additional settings can be added here
        }
    }
}