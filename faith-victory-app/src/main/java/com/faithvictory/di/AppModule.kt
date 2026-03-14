package com.faithvictory.di

import org.koin.dsl.module
import com.faithvictory.data.repository.VerseRepository
import com.faithvictory.data.repository.DevotionalRepository
import com.faithvictory.data.repository.ProgressRepository
import com.faithvictory.data.local.AppDatabase

val appModule = module {
    single { AppDatabase.getInstance(get()) }
    single { get<AppDatabase>().verseDao() }
    single { get<AppDatabase>().devotionalDao() }
    single { get<AppDatabase>().progressDao() }
    single { VerseRepository(get()) }
    single { DevotionalRepository(get()) }
    single { ProgressRepository(get()) }
}