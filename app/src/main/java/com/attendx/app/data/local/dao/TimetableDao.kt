package com.attendx.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.attendx.app.data.local.entity.TimetableSlot
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetableDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(slot: TimetableSlot): Long

    @Update
    suspend fun update(slot: TimetableSlot)

    @Delete
    suspend fun delete(slot: TimetableSlot)

    @Query("SELECT * FROM timetable_slots WHERE dayOfWeek = :day ORDER BY periodNumber ASC")
    fun getSlotsForDay(day: Int): Flow<List<TimetableSlot>>

    @Query("SELECT * FROM timetable_slots ORDER BY dayOfWeek, periodNumber ASC")
    fun getAllSlots(): Flow<List<TimetableSlot>>

    @Query("SELECT * FROM timetable_slots WHERE id = :id")
    suspend fun getSlotById(id: Long): TimetableSlot?

    @Query("SELECT MAX(periodNumber) FROM timetable_slots WHERE dayOfWeek = :day")
    suspend fun getMaxPeriodForDay(day: Int): Int?

    @Query("DELETE FROM timetable_slots WHERE dayOfWeek = :day")
    suspend fun deleteSlotsForDay(day: Int)

    @Query("DELETE FROM timetable_slots")
    suspend fun deleteAll()
}
