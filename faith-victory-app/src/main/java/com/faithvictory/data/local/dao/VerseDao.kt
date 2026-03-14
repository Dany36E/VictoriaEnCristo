package com.faithvictory.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.faithvictory.data.local.entities.Verse

@Dao
interface VerseDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertVerse(verse: Verse)

    @Query("SELECT * FROM verses WHERE id = :verseId")
    suspend fun getVerseById(verseId: Long): Verse?

    @Query("SELECT * FROM verses")
    suspend fun getAllVerses(): List<Verse>

    @Query("DELETE FROM verses")
    suspend fun deleteAllVerses()
}