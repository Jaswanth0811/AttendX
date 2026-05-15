package com.attendx.app.data.repository

import com.attendx.app.data.local.dao.SubjectDao
import com.attendx.app.data.local.entity.Subject
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SubjectRepository @Inject constructor(
    private val subjectDao: SubjectDao
) {
    fun getAllSubjects(): Flow<List<Subject>> = subjectDao.getAllSubjects()

    fun getSubjectCount(): Flow<Int> = subjectDao.getSubjectCount()

    fun getSubjectByIdFlow(id: Long): Flow<Subject?> = subjectDao.getSubjectByIdFlow(id)

    suspend fun getSubjectById(id: Long): Subject? = subjectDao.getSubjectById(id)

    suspend fun insertSubject(subject: Subject): Long = subjectDao.insert(subject)

    suspend fun updateSubject(subject: Subject) = subjectDao.update(subject)

    suspend fun deleteSubject(subject: Subject) = subjectDao.update(subject)

    suspend fun getSubjectByName(name: String): Subject? = subjectDao.getSubjectByName(name)

    suspend fun deleteAll() = subjectDao.deleteAll()
}
