-- Experiment 3: capture plans before adding secondary indexes.
-- Run generate_data.py first, then run this file BEFORE indexes.sql.
-- MySQL 8.0.18+ is required for EXPLAIN ANALYZE.

USE SUMS;

-- Estimated plan and row count for a selective student lookup.
EXPLAIN FORMAT = JSON
SELECT
    ep.Performance_Enrollment_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Student_ID = 1;

-- Actual iterator plan, rows, and timing for the same student lookup.
EXPLAIN ANALYZE
SELECT
    ep.Performance_Enrollment_ID,
    ep.Course_ID,
    ep.Semester,
    ep.Grade,
    ep.Credits
FROM Enrollment_Performance AS ep
WHERE ep.Student_ID = 1;

-- Course lookup plan before its dedicated B-tree index.
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

-- Hash lookup plan before its dedicated B-tree index.
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
