package com.attendx.app.data.repository

import com.attendx.app.data.local.dao.TimetableDao
import com.attendx.app.data.local.entity.TimetableSlot
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TimetableRepository @Inject constructor(
    private val timetableDao: TimetableDao
) {
    fun getAllSlots(): Flow<List<TimetableSlot>> = timetableDao.getAllSlots()

    fun getSlotsForDay(day: Int): Flow<List<TimetableSlot>> = timetableDao.getSlotsForDay(day)

    suspend fun getSlotById(id: Long): TimetableSlot? = timetableDao.getSlotById(id)

    suspend fun getMaxPeriodForDay(day: Int): Int = timetableDao.getMaxPeriodForDay(day) ?: 0

    suspend fun insertSlot(slot: TimetableSlot): Long = timetableDao.insert(slot)

    suspend fun updateSlot(slot: TimetableSlot) = timetableDao.update(slot)

    suspend fun deleteSlot(slot: TimetableSlot) = timetableDao.delete(slot)

    suspend fun deleteSlotsForDay(day: Int) = timetableDao.deleteSlotsForDay(day)

    suspend fun deleteAll() = timetableDao.deleteAll()
}
