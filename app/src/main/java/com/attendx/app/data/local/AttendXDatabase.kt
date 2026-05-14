package com.attendx.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.attendx.app.data.local.dao.AttendanceDao
import com.attendx.app.data.local.dao.SemesterDao
import com.attendx.app.data.local.dao.SubjectDao
import com.attendx.app.data.local.dao.TimetableDao
import com.attendx.app.data.local.entity.AttendanceRecord
import com.attendx.app.data.local.entity.Semester
import com.attendx.app.data.local.entity.Subject
import com.attendx.app.data.local.entity.TimetableSlot

@Database(
    entities = [
        Subject::class,
        TimetableSlot::class,
        AttendanceRecord::class,
        Semester::class
    ],
    version = 1,
    exportSchema = true
)
abstract class AttendXDatabase : RoomDatabase() {
    abstract fun subjectDao(): SubjectDao
    abstract fun timetableDao(): TimetableDao
    abstract fun attendanceDao(): AttendanceDao
    abstract fun semesterDao(): SemesterDao

    companion object {
        const val DATABASE_NAME = "attendx_database"
    }
}
