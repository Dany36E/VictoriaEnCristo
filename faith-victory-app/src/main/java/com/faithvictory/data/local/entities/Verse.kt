package com.faithvictory.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "verses")
data class Verse(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val text: String,
    val reference: String,
    val category: String
)