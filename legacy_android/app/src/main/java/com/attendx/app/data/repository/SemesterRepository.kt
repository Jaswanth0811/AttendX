package com.attendx.app.data.repository

import com.attendx.app.data.local.dao.SemesterDao
import com.attendx.app.data.local.entity.Semester
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SemesterRepository @Inject constructor(
    private val semesterDao: SemesterDao
) {
    fun getActiveSemester(): Flow<Semester?> = semesterDao.getActiveSemester()

    suspend fun getActiveSemesterSync(): Semester? = semesterDao.getActiveSemesterSync()

    suspend fun setActiveSemester(semester: Semester): Long {
        semesterDao.deactivateAll()
        return semesterDao.insert(semester.copy(isActive = true))
    }

    suspend fun updateSemester(semester: Semester) = semesterDao.update(semester)

    suspend fun deleteAll() = semesterDao.deleteAll()
}
