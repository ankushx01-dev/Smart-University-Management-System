-- Experiment 2: expose enrolled student-course details through a view.
-- Requires SUMS and the Experiment 1 schema and seed data.

USE SUMS;

CREATE OR REPLACE
    ALGORITHM = UNDEFINED
    SQL SECURITY INVOKER
VIEW Student_Enrollment_View AS
SELECT
    s.Student_ID,
    s.Name AS Student_Name,
    c.Course_ID,
    c.Course_Name,
    c.Credits,
    e.Semester,
    e.Grade
FROM Students AS s
INNER JOIN Enrollments AS e ON e.Student_ID = s.Student_ID
INNER JOIN Courses AS c ON c.Course_ID = e.Course_ID;

-- Positive test: seeded student 1 has two course enrolments.
SELECT
    Student_ID,
    Student_Name,
    Course_Name,
    Credits,
    Semester,
    Grade
FROM Student_Enrollment_View
WHERE Student_ID = 1
ORDER BY Course_ID;

-- Negative/edge test: student 9 has no enrolments, so the view has no row.
SELECT COUNT(*) AS Rows_For_Unenrolled_Student
FROM Student_Enrollment_View
WHERE Student_ID = 9;
