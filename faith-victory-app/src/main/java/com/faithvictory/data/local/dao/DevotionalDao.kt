package com.faithvictory.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.faithvictory.data.local.entities.Devotional

@Dao
interface DevotionalDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDevotional(devotional: Devotional)

    @Query("SELECT * FROM devotional WHERE id = :id")
    suspend fun getDevotionalById(id: Long): Devotional?

    @Query("SELECT * FROM devotional ORDER BY date DESC")
    suspend fun getAllDevotionals(): List<Devotional>

    @Query("DELETE FROM devotional")
    suspend fun deleteAllDevotionals()
}