package com.faithvictory.ui.screens.home

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun HomeScreen(viewModel: HomeViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Home") })
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(text = "Welcome to Faith Victory App", style = MaterialTheme.typography.h5)
            Spacer(modifier = Modifier.height(20.dp))
            Button(onClick = { /* Navigate to Verses Screen */ }) {
                Text("View Verses")
            }
            Spacer(modifier = Modifier.height(10.dp))
            Button(onClick = { /* Navigate to Devotionals Screen */ }) {
                Text("View Devotionals")
            }
            Spacer(modifier = Modifier.height(10.dp))
            Button(onClick = { /* Navigate to Progress Screen */ }) {
                Text("Track Progress")
            }
        }
    }
}