package com.attendx.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.attendx.app.data.local.entity.Semester
import kotlinx.coroutines.flow.Flow

@Dao
interface SemesterDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(semester: Semester): Long

    @Update
    suspend fun update(semester: Semester)

    @Query("SELECT * FROM semesters WHERE isActive = 1 LIMIT 1")
    fun getActiveSemester(): Flow<Semester?>

    @Query("SELECT * FROM semesters WHERE isActive = 1 LIMIT 1")
    suspend fun getActiveSemesterSync(): Semester?

    @Query("UPDATE semesters SET isActive = 0")
    suspend fun deactivateAll()

    @Query("DELETE FROM semesters")
    suspend fun deleteAll()
}
