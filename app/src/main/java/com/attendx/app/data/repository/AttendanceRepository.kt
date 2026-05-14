package com.attendx.app.data.repository

import com.attendx.app.data.local.dao.AttendanceDao
import com.attendx.app.data.local.entity.AttendanceRecord
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AttendanceRepository @Inject constructor(
    private val attendanceDao: AttendanceDao
) {
    fun getAllRecords(): Flow<List<AttendanceRecord>> = attendanceDao.getAllRecords()

    fun getRecordsForDate(date: Long): Flow<List<AttendanceRecord>> =
        attendanceDao.getRecordsForDate(date)

    suspend fun getRecordsForDateSync(date: Long): List<AttendanceRecord> =
        attendanceDao.getRecordsForDateSync(date)

    fun getRecordsForSubject(subjectId: Long): Flow<List<AttendanceRecord>> =
        attendanceDao.getRecordsForSubject(subjectId)

    fun getPresentCountForSubject(subjectId: Long): Flow<Int> =
        attendanceDao.getPresentCountForSubject(subjectId)

    fun getTotalCountForSubject(subjectId: Long): Flow<Int> =
        attendanceDao.getTotalCountForSubject(subjectId)

    fun getTotalPresentCount(): Flow<Int> = attendanceDao.getTotalPresentCount()

    fun getTotalClassCount(): Flow<Int> = attendanceDao.getTotalClassCount()

    fun getTotalAbsentCount(): Flow<Int> = attendanceDao.getTotalAbsentCount()

    fun getPresentDates(): Flow<List<Long>> = attendanceDao.getPresentDates()

    fun getAbsentDates(): Flow<List<Long>> = attendanceDao.getAbsentDates()

    fun getHolidayDates(): Flow<List<Long>> = attendanceDao.getHolidayDates()

    fun getAllDatesWithRecords(): Flow<List<Long>> = attendanceDao.getAllDatesWithRecords()

    fun getRecordsBetweenDates(start: Long, end: Long): Flow<List<AttendanceRecord>> =
        attendanceDao.getRecordsBetweenDates(start, end)

    fun getPresentCountBetweenDates(start: Long, end: Long): Flow<Int> =
        attendanceDao.getPresentCountBetweenDates(start, end)

    fun getTotalCountBetweenDates(start: Long, end: Long): Flow<Int> =
        attendanceDao.getTotalCountBetweenDates(start, end)

    suspend fun insertRecord(record: AttendanceRecord): Long = attendanceDao.insert(record)

    suspend fun insertRecords(records: List<AttendanceRecord>) = attendanceDao.insertAll(records)

    suspend fun updateRecord(record: AttendanceRecord) = attendanceDao.update(record)

    suspend fun deleteRecord(record: AttendanceRecord) = attendanceDao.delete(record)

    suspend fun deleteAll() = attendanceDao.deleteAll()

    suspend fun deleteAbsentRecordsForDate(date: Long) = attendanceDao.deleteAbsentRecordsForDate(date)

    suspend fun deleteHolidayRecordsForDate(date: Long) = attendanceDao.deleteHolidayRecordsForDate(date)
}
