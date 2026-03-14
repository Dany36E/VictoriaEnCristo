package com.faithvictory.ui.screens.devotional

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.faithvictory.data.repository.DevotionalRepository
import com.faithvictory.data.local.entities.Devotional

class DevotionalViewModel(private val devotionalRepository: DevotionalRepository) : ViewModel() {

    private val _devotionals = MutableLiveData<List<Devotional>>()
    val devotionals: LiveData<List<Devotional>> get() = _devotionals

    fun fetchDevotionals() {
        // Simulate fetching data from the repository
        _devotionals.value = devotionalRepository.getAllDevotionals()
    }
}