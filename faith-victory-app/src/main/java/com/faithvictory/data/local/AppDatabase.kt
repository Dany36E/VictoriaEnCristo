package com.faithvictory.data.local

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.faithvictory.data.local.dao.DevotionalDao
import com.faithvictory.data.local.dao.ProgressDao
import com.faithvictory.data.local.dao.VerseDao
import com.faithvictory.data.local.entities.Devotional
import com.faithvictory.data.local.entities.Progress
import com.faithvictory.data.local.entities.Verse
import android.content.Context

@Database(entities = [Verse::class, Devotional::class, Progress::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {

    abstract fun verseDao(): VerseDao
    abstract fun devotionalDao(): DevotionalDao
    abstract fun progressDao(): ProgressDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "faith_victory_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}