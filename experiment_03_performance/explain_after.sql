-- Experiment 3: capture plans after adding secondary B-tree indexes.
-- Run indexes.sql before this file.

USE SUMS;

-- Let the optimizer choose an access path for Student_ID.
EXPLAIN FORMAT = JSON
SELECT
    ep.Performance_Enrollment_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Student_ID = 1;

EXPLAIN ANALYZE
SELECT
    ep.Performance_Enrollment_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Student_ID = 1;

-- Let the optimizer choose an access path for Course_ID.
EXPLAIN FORMAT = JSON
SELECT
    ep.Performance_Enrollment_ID,
    ep.Student_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Course_ID = 1;

EXPLAIN ANALYZE
SELECT
    ep.Performance_Enrollment_ID,
    ep.Student_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Course_ID = 1;

-- Let the optimizer choose an access path for the SHA-256 email hash.
SET @target_email_hash = (
    SELECT LOWER(SHA2(LOWER(TRIM(Email)), 256))
    FROM Students
    WHERE Student_ID = 1
);

EXPLAIN FORMAT = JSON
SELECT
    ep.Performance_Enrollment_ID,
    ep.Student_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade
FROM Enrollment_Performance AS ep
WHERE ep.Student_Email_SHA256 = @target_email_hash;

EXPLAIN ANALYZE
SELECT
    ep.Performance_Enrollment_ID,
    ep.Student_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade
FROM Enrollment_Performance AS ep
WHERE ep.Student_Email_SHA256 = @target_email_hash;
