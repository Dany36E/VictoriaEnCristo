package com.faithvictory.ui.screens.devotional

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.faithvictory.ui.components.PrayerButton
import com.faithvictory.ui.components.ProgressTracker

@Composable
fun DevotionalScreen(
    viewModel: DevotionalViewModel = viewModel()
) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Devocionales") })
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Display devotional content
            Text(text = viewModel.currentDevotional.title, style = MaterialTheme.typography.h6)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = viewModel.currentDevotional.content, style = MaterialTheme.typography.body1)
            Spacer(modifier = Modifier.height(16.dp))

            // Prayer button
            PrayerButton(onClick = { viewModel.initiatePrayer() })

            // Progress tracker
            ProgressTracker(progress = viewModel.progress)
        }
    }
}