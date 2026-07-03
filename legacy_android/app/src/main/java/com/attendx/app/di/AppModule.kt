package com.attendx.app.di

import android.content.Context
import androidx.room.Room
import com.attendx.app.data.local.AttendXDatabase
import com.attendx.app.data.local.dao.AttendanceDao
import com.attendx.app.data.local.dao.SemesterDao
import com.attendx.app.data.local.dao.SubjectDao
import com.attendx.app.data.local.dao.TimetableDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AttendXDatabase {
        return Room.databaseBuilder(
            context,
            AttendXDatabase::class.java,
            AttendXDatabase.DATABASE_NAME
        ).build()
    }

    @Provides
    @Singleton
    fun provideSubjectDao(database: AttendXDatabase): SubjectDao = database.subjectDao()

    @Provides
    @Singleton
    fun provideTimetableDao(database: AttendXDatabase): TimetableDao = database.timetableDao()

    @Provides
    @Singleton
    fun provideAttendanceDao(database: AttendXDatabase): AttendanceDao = database.attendanceDao()

    @Provides
    @Singleton
    fun provideSemesterDao(database: AttendXDatabase): SemesterDao = database.semesterDao()
}
