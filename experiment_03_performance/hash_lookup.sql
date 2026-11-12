-- Experiment 3: search benchmark enrolments by a SHA-256 email digest.
-- Run generate_data.py and indexes.sql before this file.

USE SUMS;

-- Hash the normalized source email exactly as generate_data.py does.
SELECT LOWER(SHA2(LOWER(TRIM(Email)), 256))
INTO @target_email_hash
FROM Students
WHERE Student_ID = 1;

-- Verify that this hash is stored and indexed in the benchmark table.
SELECT
    COUNT(*) AS Matching_Enrollment_Records
FROM Enrollment_Performance
WHERE Student_Email_SHA256 = @target_email_hash;

-- Return a small sample of the matching enrolment records.
SELECT
    Performance_Enrollment_ID,
    Student_ID,
    Course_ID,
    Semester,
    Grade,
    Credits
FROM Enrollment_Performance
WHERE Student_Email_SHA256 = @target_email_hash
ORDER BY Performance_Enrollment_ID
LIMIT 10;
