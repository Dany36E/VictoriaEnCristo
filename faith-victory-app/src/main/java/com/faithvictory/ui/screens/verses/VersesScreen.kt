package com.faithvictory.ui.screens.verses

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.faithvictory.ui.components.VerseCard

@Composable
fun VersesScreen(
    versesViewModel: VersesViewModel = viewModel()
) {
    val verses = versesViewModel.verses

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Verses") })
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (verses.isEmpty()) {
                Text("No verses available")
            } else {
                LazyColumn {
                    items(verses) { verse ->
                        VerseCard(verse = verse)
                    }
                }
            }
        }
    }
}