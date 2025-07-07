CREATE OR ALTER PROCEDURE sp_GetStudentsByDepartment
    @dept_num INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM departments WHERE dept_num = @dept_num)
    BEGIN
        SELECT 
            s.student_id,
            s.name,
            s.email,
            s.gender,
            s.phone,
            s.gpa,
            s.is_hired,
            s.job_title,
            s.company,
            s.dept_num,
            d.dept_name
        FROM students s
        JOIN departments d ON s.dept_num = d.dept_num
        WHERE s.dept_num = @dept_num;
    END
    ELSE
    BEGIN
        PRINT '❌ Department number not found.';
    END
END;
GO
CREATE OR ALTER PROCEDURE sp_GetStudentGrades
    @student_id VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM students WHERE student_id = @student_id)
    BEGIN
        SELECT 
            e.exam_id,
            e.course_id,
            c.course_name,
            e.student_score,
            e.total_score,
            CAST(
                CAST(e.student_score AS FLOAT) / NULLIF(e.total_score, 0) * 100 
                AS DECIMAL(5,2)
            ) AS percentage
        FROM exams e
        JOIN courses c ON e.course_id = c.course_id
        WHERE e.student_id = @student_id;
    END
    ELSE
    BEGIN
        PRINT '❌ Student ID not found.';
    END
END;
GO
CREATE PROCEDURE sp_GetExamQuestions
    @ExamID INT
AS
BEGIN
    SELECT 
        q.Question_ID,
        q.Question_text,
        q.Question_Type,
        q.correct_answer,
        q.question_score
    FROM exam_has_questions eq
    INNER JOIN questions q ON eq.question_id = q.Question_ID
    WHERE eq.exam_id = @ExamID
END
GO
CREATE OR ALTER PROCEDURE sp_GetInstructorCoursesWithStudentCount
    @ins_id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM instructors2 WHERE ins_ID = @ins_id)
    BEGIN
        SELECT 
            c.Course_ID,
            c.Course_Name,
            COUNT(DISTINCT s.student_id) AS Student_Count
        FROM courses c
        LEFT JOIN exams e ON c.Course_ID = e.course_id
        LEFT JOIN students s ON s.student_id = e.student_id
        WHERE c.ins_id = @ins_id
        GROUP BY c.Course_ID, c.Course_Name;
    END
    ELSE
    BEGIN
        PRINT '❌ Instructor ID not found.';
    END
END;
GO
CREATE OR ALTER PROCEDURE sp_GenerateExam
    @exam_id INT,
    @course_id INT,
    @student_id VARCHAR(50),
    @tf_count TINYINT,
    @mcq_count TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalQuestions INT = @tf_count + @mcq_count;

    IF @TotalQuestions <> 10
    BEGIN
        PRINT '❌ Total number of questions must be 10';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO exams (
            exam_id, course_id, student_id, exam_date, exam_time,
            num_of_questions, total_score, Exam_duration_in_minutes, student_score
        )
        VALUES (
            @exam_id, @course_id, @student_id, GETDATE(), GETDATE(),
            @TotalQuestions, 100, 60, 0
        );

        INSERT INTO exam_has_questions (exam_id, question_id)
        SELECT TOP (@tf_count) @exam_id, question_id
        FROM questions
        WHERE course_id = @course_id AND question_type = 'True/False'
        ORDER BY NEWID();

        INSERT INTO exam_has_questions (exam_id, question_id)
        SELECT TOP (@mcq_count) @exam_id, question_id
        FROM questions
        WHERE course_id = @course_id AND question_type = 'MCQ'
        ORDER BY NEWID();

        COMMIT TRANSACTION;
        PRINT '✅ Exam created successfully with ID = ' + CAST(@exam_id AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT '❌ Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_SubmitAnswers
    @exam_id INT,
    @student_id NVARCHAR(50),
    @a1 NVARCHAR(50), @a2 NVARCHAR(50), @a3 NVARCHAR(50), @a4 NVARCHAR(50), @a5 NVARCHAR(50),
    @a6 NVARCHAR(50), @a7 NVARCHAR(50), @a8 NVARCHAR(50), @a9 NVARCHAR(50), @a10 NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @QuestionList TABLE (row_num INT IDENTITY(1,1), question_id INT);

        INSERT INTO @QuestionList (question_id)
        SELECT question_id
        FROM exam_has_questions
        WHERE exam_id = @exam_id
        ORDER BY question_id;

        INSERT INTO student_answers_exam_questions (
            student_id, exam_id, question_id, student_answer, student_mark_in_question
        )
        SELECT @student_id, @exam_id, question_id, answer, 0
        FROM (
            SELECT 1 AS row_num, @a1 AS answer UNION ALL
            SELECT 2, @a2 UNION ALL
            SELECT 3, @a3 UNION ALL
            SELECT 4, @a4 UNION ALL
            SELECT 5, @a5 UNION ALL
            SELECT 6, @a6 UNION ALL
            SELECT 7, @a7 UNION ALL
            SELECT 8, @a8 UNION ALL
            SELECT 9, @a9 UNION ALL
            SELECT 10, @a10
        ) AS answers
        JOIN @QuestionList Q ON answers.row_num = Q.row_num;

        COMMIT TRANSACTION;
        PRINT '✅ Answers submitted successfully';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT '❌ Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_CorrectExam
    @exam_id INT,
    @student_id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Score INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @Score = COUNT(*)
        FROM student_answers_exam_questions s
        JOIN questions q ON s.question_id = q.question_id
        WHERE s.exam_id = @exam_id
          AND s.student_id = @student_id
          AND s.student_answer = q.correct_answer;

        UPDATE exams
        SET student_score = @Score * 10
        WHERE exam_id = @exam_id;

        COMMIT TRANSACTION;
        PRINT '✅ Exam corrected. Score = ' + CAST(@Score * 10 AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT '❌ Failed to correct exam: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE sp_GetCourseTopics
    @course_id NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM courses WHERE course_id = @course_id)
    BEGIN
        SELECT 
            topic_id,
            topic_name
        FROM course_topics2
        WHERE course_id = @course_id;
    END
    ELSE
    BEGIN
        PRINT '❌ Course ID not found.';
    END
END;
GO
USE our_project
GO

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertStudent
    @student_id NVARCHAR(50),
    @name NVARCHAR(50),
    @email NVARCHAR(50),
    @password NVARCHAR(50),
    @gender NVARCHAR(50),
    @phone BIGINT,
    @gpa FLOAT,
    @is_hired NVARCHAR(50),
    @job_title NVARCHAR(50),
    @company NVARCHAR(50),
    @dept_num TINYINT
AS
BEGIN
    INSERT INTO students (
        student_id, name, email, password, gender, phone,
        gpa, is_hired, job_title, company, dept_num
    )
    VALUES (
        @student_id, @name, @email, @password, @gender, @phone,
        @gpa, @is_hired, @job_title, @company, @dept_num
    )
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateStudent
    @student_id NVARCHAR(50),
    @name NVARCHAR(50),
    @email NVARCHAR(50),
    @password NVARCHAR(50),
    @gender NVARCHAR(50),
    @phone BIGINT,
    @gpa FLOAT,
    @is_hired NVARCHAR(50),
    @job_title NVARCHAR(50),
    @company NVARCHAR(50),
    @dept_num TINYINT
AS
BEGIN
    UPDATE students
    SET 
        name = @name,
        email = @email,
        password = @password,
        gender = @gender,
        phone = @phone,
        gpa = @gpa,
        is_hired = @is_hired,
        job_title = @job_title,
        company = @company,
        dept_num = @dept_num
    WHERE student_id = @student_id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteStudent
    @student_id NVARCHAR(50)
AS
BEGIN
    DELETE FROM students
    WHERE student_id = @student_id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertExam
    @exam_id NVARCHAR(50), @student_id NVARCHAR(50), @course_id NVARCHAR(50),
    @student_score TINYINT, @exam_date DATE, @exam_time TIME,
    @num_of_questions TINYINT, @total_score TINYINT, @Exam_duration_in_minutes TINYINT
AS
BEGIN
    INSERT INTO exams VALUES (@exam_id, @student_id, @course_id, @student_score, @exam_date, @exam_time, @num_of_questions, @total_score, @Exam_duration_in_minutes)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateExamScore
    @exam_id NVARCHAR(50), @new_score TINYINT
AS
BEGIN
    UPDATE exams SET total_score = @new_score WHERE exam_id = @exam_id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteExam
    @exam_id NVARCHAR(50)
AS
BEGIN
    DELETE FROM exams WHERE exam_id = @exam_id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertFreelance
    @freelance_id NVARCHAR(50), @student_id NVARCHAR(50), @platform NVARCHAR(50),
    @duration TINYINT, @date DATE
AS
BEGIN
    INSERT INTO freelance VALUES (@freelance_id, @student_id, @platform, @duration, @date)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateFreelancePlatform
    @freelance_id NVARCHAR(50), @new_platform NVARCHAR(50)
AS
BEGIN
    UPDATE freelance SET platform = @new_platform WHERE freelance_id = @freelance_id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteFreelance
    @freelance_id NVARCHAR(50)
AS
BEGIN
    DELETE FROM freelance WHERE freelance_id = @freelance_id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertInstructor
    @id NVARCHAR(50), @name NVARCHAR(50), @email NVARCHAR(50), @internal NVARCHAR(50),
    @hired_date DATE, @gender NVARCHAR(50), @supervisor_id NVARCHAR(50)
AS
BEGIN
    INSERT INTO instructors2 VALUES (@id, @name, @email, @internal, @hired_date, @gender, @supervisor_id)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateInstructorStatus
    @id NVARCHAR(50), @new_status NVARCHAR(50)
AS
BEGIN
    UPDATE instructors2 SET is_internal = @new_status WHERE ins_ID = @id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteInstructor
    @id NVARCHAR(50)
AS
BEGIN
    DELETE FROM instructors2 WHERE ins_ID = @id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertQuestion
    @id NVARCHAR(50), @type NVARCHAR(50), @answer NVARCHAR(100),
    @text NVARCHAR(250), @course_id NVARCHAR(50), @score TINYINT
AS
BEGIN
    INSERT INTO questions VALUES (@id, @type, @answer, @text, @course_id, @score)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateQuestionAnswer
    @id NVARCHAR(50), @new_answer NVARCHAR(100)
AS
BEGIN
    UPDATE questions SET correct_answer = @new_answer WHERE Question_ID = @id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteQuestion
    @id NVARCHAR(50)
AS
BEGIN
    DELETE FROM questions WHERE Question_ID = @id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertCertificate
    @id NVARCHAR(50), @student_id NVARCHAR(50), @field NVARCHAR(50),
    @source NVARCHAR(50), @date DATE, @expired DATE
AS
BEGIN
    INSERT INTO certificates VALUES (@id, @student_id, @field, @source, @date, @expired)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateCertificateSource
    @id NVARCHAR(50), @new_source NVARCHAR(50)
AS
BEGIN
    UPDATE certificates SET certificate_source = @new_source WHERE certificate_id = @id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteCertificate
    @id NVARCHAR(50)
AS
BEGIN
    DELETE FROM certificates WHERE certificate_id = @id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertCourse
    @id NVARCHAR(50), @name NVARCHAR(50), @hours TINYINT, @instructor_id NVARCHAR(50)
AS
BEGIN
    INSERT INTO courses VALUES (@id, @name, @hours, @instructor_id)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateCourseName
    @id NVARCHAR(50), @new_name NVARCHAR(50)
AS
BEGIN
    UPDATE courses SET Course_Name = @new_name WHERE Course_ID = @id
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteCourse
    @id NVARCHAR(50)
AS
BEGIN
    DELETE FROM courses WHERE Course_ID = @id
END
GO

/*************************************/

-- INSERT
CREATE OR ALTER PROCEDURE sp_InsertDepartment
    @num TINYINT, @name NVARCHAR(50), @manager_id NVARCHAR(50)
AS
BEGIN
    INSERT INTO departments VALUES (@num, @name, @manager_id)
END
GO

-- UPDATE
CREATE OR ALTER PROCEDURE sp_UpdateDepartmentName
    @num TINYINT, @new_name NVARCHAR(50)
AS
BEGIN
    UPDATE departments SET dept_name = @new_name WHERE dept_num = @num
END
GO

-- DELETE
CREATE OR ALTER PROCEDURE sp_DeleteDepartment
    @num TINYINT
AS
BEGIN
    DELETE FROM departments WHERE dept_num = @num
END
GO
CREATE PROCEDURE sp_GetStudentExamAnswers
    @ExamID INT,
    @StudentID NVARCHAR(50)
AS
BEGIN
    SELECT 
        q.Question_ID,
        q.Question_text,
        q.correct_answer,
        saf.student_answer,
        saf.student_mark_in_question
    FROM student_answers_exam_questions saf
    INNER JOIN questions q ON saf.question_id = q.Question_ID
    WHERE saf.exam_id = @ExamID
      AND saf.student_id = @StudentID
END
GO

