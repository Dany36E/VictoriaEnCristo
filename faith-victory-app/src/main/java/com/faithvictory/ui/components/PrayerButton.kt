package com.faithvictory.ui.components

import androidx.compose.material.Button
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview

@Composable
fun PrayerButton(onClick: () -> Unit) {
    Button(onClick = onClick) {
        Text(text = "Iniciar Oración")
    }
}

@Preview
@Composable
fun PreviewPrayerButton() {
    PrayerButton(onClick = {})
}