package com.faithvictory.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.faithvictory.data.local.entities.Progress

@Dao
interface ProgressDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProgress(progress: Progress)

    @Query("SELECT * FROM progress WHERE userId = :userId")
    suspend fun getProgressByUserId(userId: String): Progress?

    @Query("DELETE FROM progress WHERE userId = :userId")
    suspend fun deleteProgressByUserId(userId: String)
}