package com.attendx.app.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.attendx.app.data.local.entity.AttendanceRecord
import kotlinx.coroutines.flow.Flow

@Dao
interface AttendanceDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(record: AttendanceRecord): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(records: List<AttendanceRecord>)

    @Update
    suspend fun update(record: AttendanceRecord)

    @Delete
    suspend fun delete(record: AttendanceRecord)

    @Query("SELECT * FROM attendance_records WHERE date = :date ORDER BY periodNumber ASC")
    fun getRecordsForDate(date: Long): Flow<List<AttendanceRecord>>

    @Query("SELECT * FROM attendance_records WHERE date = :date ORDER BY periodNumber ASC")
    suspend fun getRecordsForDateSync(date: Long): List<AttendanceRecord>

    @Query("SELECT * FROM attendance_records ORDER BY date DESC, periodNumber ASC")
    fun getAllRecords(): Flow<List<AttendanceRecord>>

    @Query("SELECT * FROM attendance_records WHERE actualSubjectId = :subjectId ORDER BY date DESC")
    fun getRecordsForSubject(subjectId: Long): Flow<List<AttendanceRecord>>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE actualSubjectId = :subjectId AND status = 'PRESENT'
    """)
    fun getPresentCountForSubject(subjectId: Long): Flow<Int>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE actualSubjectId = :subjectId AND (status = 'PRESENT' OR status = 'ABSENT')
    """)
    fun getTotalCountForSubject(subjectId: Long): Flow<Int>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE status = 'PRESENT'
    """)
    fun getTotalPresentCount(): Flow<Int>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE status = 'PRESENT' OR status = 'ABSENT'
    """)
    fun getTotalClassCount(): Flow<Int>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE status = 'ABSENT'
    """)
    fun getTotalAbsentCount(): Flow<Int>

    @Query("""
        SELECT DISTINCT date FROM attendance_records 
        WHERE status = 'PRESENT' 
        ORDER BY date DESC
    """)
    fun getPresentDates(): Flow<List<Long>>

    @Query("""
        SELECT DISTINCT date FROM attendance_records 
        WHERE status = 'ABSENT'
        ORDER BY date DESC
    """)
    fun getAbsentDates(): Flow<List<Long>>

    @Query("""
        SELECT DISTINCT date FROM attendance_records 
        WHERE status = 'HOLIDAY'
        ORDER BY date DESC
    """)
    fun getHolidayDates(): Flow<List<Long>>

    @Query("""
        SELECT DISTINCT date FROM attendance_records 
        ORDER BY date DESC
    """)
    fun getAllDatesWithRecords(): Flow<List<Long>>

    @Query("""
        SELECT * FROM attendance_records 
        WHERE date BETWEEN :startDate AND :endDate 
        ORDER BY date DESC, periodNumber ASC
    """)
    fun getRecordsBetweenDates(startDate: Long, endDate: Long): Flow<List<AttendanceRecord>>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE date BETWEEN :startDate AND :endDate AND status = 'PRESENT'
    """)
    fun getPresentCountBetweenDates(startDate: Long, endDate: Long): Flow<Int>

    @Query("""
        SELECT COUNT(*) FROM attendance_records 
        WHERE date BETWEEN :startDate AND :endDate AND (status = 'PRESENT' OR status = 'ABSENT')
    """)
    fun getTotalCountBetweenDates(startDate: Long, endDate: Long): Flow<Int>

    @Query("DELETE FROM attendance_records")
    suspend fun deleteAll()

    @Query("DELETE FROM attendance_records WHERE date = :date AND status = 'ABSENT'")
    suspend fun deleteAbsentRecordsForDate(date: Long)

    @Query("DELETE FROM attendance_records WHERE date = :date AND status = 'HOLIDAY'")
    suspend fun deleteHolidayRecordsForDate(date: Long)
}
