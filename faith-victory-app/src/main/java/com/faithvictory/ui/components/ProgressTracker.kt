package com.faithvictory.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.faithvictory.data.local.entities.Progress

@Composable
fun ProgressTracker(progress: Progress) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = "Progreso", style = MaterialTheme.typography.h6)
        Spacer(modifier = Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = progress.current / progress.total.toFloat(),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = "${progress.current} de ${progress.total} completado")
    }
}