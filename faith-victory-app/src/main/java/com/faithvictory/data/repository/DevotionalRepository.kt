package com.faithvictory.data.repository

import com.faithvictory.data.local.dao.DevotionalDao
import com.faithvictory.data.local.entities.Devotional
import kotlinx.coroutines.flow.Flow

class DevotionalRepository(private val devotionalDao: DevotionalDao) {

    fun getAllDevotionals(): Flow<List<Devotional>> {
        return devotionalDao.getAllDevotionals()
    }

    suspend fun insertDevotional(devotional: Devotional) {
        devotionalDao.insertDevotional(devotional)
    }

    suspend fun deleteDevotional(devotional: Devotional) {
        devotionalDao.deleteDevotional(devotional)
    }
}