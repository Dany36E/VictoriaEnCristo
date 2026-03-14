package com.faithvictory.data.repository

import com.faithvictory.data.local.dao.VerseDao
import com.faithvictory.data.local.entities.Verse
import kotlinx.coroutines.flow.Flow

class VerseRepository(private val verseDao: VerseDao) {

    fun getAllVerses(): Flow<List<Verse>> {
        return verseDao.getAllVerses()
    }

    suspend fun insertVerse(verse: Verse) {
        verseDao.insertVerse(verse)
    }

    suspend fun deleteVerse(verse: Verse) {
        verseDao.deleteVerse(verse)
    }
}