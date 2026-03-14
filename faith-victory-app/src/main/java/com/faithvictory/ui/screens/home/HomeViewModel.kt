package com.faithvictory.ui.screens.home

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.faithvictory.data.repository.DevotionalRepository
import com.faithvictory.data.repository.VerseRepository

class HomeViewModel(
    private val verseRepository: VerseRepository,
    private val devotionalRepository: DevotionalRepository
) : ViewModel() {

    private val _verses = MutableLiveData<List<String>>()
    val verses: LiveData<List<String>> get() = _verses

    private val _devotionals = MutableLiveData<List<String>>()
    val devotionals: LiveData<List<String>> get() = _devotionals

    fun fetchVerses() {
        // Simulate fetching verses from the repository
        _verses.value = verseRepository.getAllVerses()
    }

    fun fetchDevotionals() {
        // Simulate fetching devotionals from the repository
        _devotionals.value = devotionalRepository.getAllDevotionals()
    }
}