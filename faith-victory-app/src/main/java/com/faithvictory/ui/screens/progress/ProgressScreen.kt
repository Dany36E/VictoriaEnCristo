package com.faithvictory.ui.screens.progress

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.faithvictory.ui.components.ProgressTracker
import com.faithvictory.ui.theme.Typography

@Composable
fun ProgressScreen(progressViewModel: ProgressViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Progreso", style = Typography.h6) }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Tu progreso espiritual", style = Typography.h5)
            Spacer(modifier = Modifier.height(16.dp))
            ProgressTracker(progressViewModel)
        }
    }
}