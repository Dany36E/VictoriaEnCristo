package com.faithvictory.ui.screens.verses

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.faithvictory.data.repository.VerseRepository
import com.faithvictory.data.local.entities.Verse

class VersesViewModel(private val verseRepository: VerseRepository) : ViewModel() {

    private val _verses = MutableLiveData<List<Verse>>()
    val verses: LiveData<List<Verse>> get() = _verses

    init {
        loadVerses()
    }

    private fun loadVerses() {
        // Load verses from the repository
        _verses.value = verseRepository.getAllVerses()
    }
}