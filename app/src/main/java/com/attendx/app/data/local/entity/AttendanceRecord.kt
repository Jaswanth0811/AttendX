package com.attendx.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "attendance_records",
    foreignKeys = [
        ForeignKey(
            entity = Subject::class,
            parentColumns = ["id"],
            childColumns = ["scheduledSubjectId"],
            onDelete = ForeignKey.SET_NULL
        ),
        ForeignKey(
            entity = Subject::class,
            parentColumns = ["id"],
            childColumns = ["actualSubjectId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [
        Index("scheduledSubjectId"),
        Index("actualSubjectId"),
        Index("date"),
        Index("date", "periodNumber", unique = true)
    ]
)
data class AttendanceRecord(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val date: Long, // epoch millis (date only, time set to 00:00)
    val dayOfWeek: Int,
    val periodNumber: Int,
    val scheduledSubjectId: Long? = null,
    val actualSubjectId: Long? = null,
    val status: String, // PRESENT, ABSENT, CANCELLED, FREE, SEMINAR
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis()
) {
    companion object {
        const val STATUS_PRESENT = "PRESENT"
        const val STATUS_ABSENT = "ABSENT"
        const val STATUS_CANCELLED = "CANCELLED"
        const val STATUS_FREE = "FREE"
        const val STATUS_SEMINAR = "SEMINAR"
        const val STATUS_HOLIDAY = "HOLIDAY"
    }
}
