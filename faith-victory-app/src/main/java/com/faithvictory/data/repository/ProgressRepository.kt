package com.faithvictory.data.repository

import com.faithvictory.data.local.dao.ProgressDao
import com.faithvictory.data.local.entities.Progress

class ProgressRepository(private val progressDao: ProgressDao) {

    suspend fun insertProgress(progress: Progress) {
        progressDao.insert(progress)
    }

    suspend fun getProgressById(id: Int): Progress? {
        return progressDao.getProgressById(id)
    }

    suspend fun getAllProgress(): List<Progress> {
        return progressDao.getAllProgress()
    }

    suspend fun updateProgress(progress: Progress) {
        progressDao.update(progress)
    }

    suspend fun deleteProgress(progress: Progress) {
        progressDao.delete(progress)
    }
}