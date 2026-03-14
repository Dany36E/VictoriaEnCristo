package com.faithvictory.ui.screens.progress

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.faithvictory.data.repository.ProgressRepository
import com.faithvictory.data.local.entities.Progress

class ProgressViewModel(private val progressRepository: ProgressRepository) : ViewModel() {

    private val _progressList = MutableLiveData<List<Progress>>()
    val progressList: LiveData<List<Progress>> get() = _progressList

    fun fetchProgress() {
        // Simulate fetching progress data from the repository
        _progressList.value = progressRepository.getAllProgress()
    }

    fun addProgress(progress: Progress) {
        progressRepository.insertProgress(progress)
        fetchProgress() // Refresh the list after adding new progress
    }

    fun deleteProgress(progress: Progress) {
        progressRepository.deleteProgress(progress)
        fetchProgress() // Refresh the list after deleting progress
    }
}