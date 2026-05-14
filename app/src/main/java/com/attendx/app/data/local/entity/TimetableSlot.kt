package com.attendx.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "timetable_slots",
    foreignKeys = [
        ForeignKey(
            entity = Subject::class,
            parentColumns = ["id"],
            childColumns = ["subjectId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [Index("subjectId"), Index("dayOfWeek", "periodNumber")]
)
data class TimetableSlot(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val dayOfWeek: Int, // 1=Monday, 2=Tuesday, ..., 6=Saturday
    val periodNumber: Int,
    val startTime: String, // "09:00"
    val endTime: String,   // "10:00"
    val subjectId: Long? = null
)
