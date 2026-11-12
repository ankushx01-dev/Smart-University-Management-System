-- Experiment 1: demonstrate INNER JOIN and LEFT JOIN queries.
-- Run insert_data.sql first so the expected sample rows are present.

USE SUMS;

-- INNER JOIN: list students and the courses in which they are enrolled.
SELECT
    s.Student_ID,
    s.Name AS Student_Name,
    c.Course_ID,
    c.Course_Name,
    e.Semester,
    e.Grade
FROM Students AS s
INNER JOIN Enrollments AS e ON e.Student_ID = s.Student_ID
INNER JOIN Courses AS c ON c.Course_ID = e.Course_ID
ORDER BY s.Student_ID, c.Course_ID;

-- LEFT JOIN: find students with no matching enrollment.
-- The NULL test is on the non-null primary key of Enrollments.
SELECT
    s.Student_ID,
    s.Name AS Student_Name,
    s.Email
FROM Students AS s
LEFT JOIN Enrollments AS e ON e.Student_ID = s.Student_ID
WHERE e.Enrollment_ID IS NULL
ORDER BY s.Student_ID;

-- Verify the expected counts: ten enrollment rows and two students without one.
SELECT
    (SELECT COUNT(*) FROM Enrollments) AS Enrollment_Count,
    (SELECT COUNT(*)
     FROM Students AS s
     LEFT JOIN Enrollments AS e ON e.Student_ID = s.Student_ID
     WHERE e.Enrollment_ID IS NULL) AS Students_Without_Enrollment;
