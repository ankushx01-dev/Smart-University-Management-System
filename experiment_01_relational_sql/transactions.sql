-- Experiment 1: demonstrate COMMIT and ROLLBACK with explicit transactions.
-- Run insert_data.sql first; the final statements restore the seeded names.

USE SUMS;

-- COMMIT demo: inspect a baseline value, change it inside a transaction,
-- commit the change, and select again to show it persisted.
SELECT Student_ID, Name
FROM Students
WHERE Student_ID = 1;

START TRANSACTION;

UPDATE Students
SET Name = 'Aarav Mehta - COMMIT demo'
WHERE Student_ID = 1;

SELECT Student_ID, Name
FROM Students
WHERE Student_ID = 1;

COMMIT;

SELECT Student_ID, Name AS Name_After_Commit
FROM Students
WHERE Student_ID = 1;

-- Restore the seed value so rerunning the demonstration gives the same output.
START TRANSACTION;

UPDATE Students
SET Name = 'Aarav Mehta'
WHERE Student_ID = 1;

COMMIT;

-- ROLLBACK demo: the temporary value is visible within this session before
-- rollback, then the original seeded name remains after rollback.
SELECT Student_ID, Name
FROM Students
WHERE Student_ID = 2;

START TRANSACTION;

UPDATE Students
SET Name = 'This change must be rolled back'
WHERE Student_ID = 2;

SELECT Student_ID, Name AS Name_Before_Rollback
FROM Students
WHERE Student_ID = 2;

ROLLBACK;

SELECT Student_ID, Name AS Name_After_Rollback
FROM Students
WHERE Student_ID = 2;

-- Final verification: both student names match the seed data again.
SELECT Student_ID, Name
FROM Students
WHERE Student_ID IN (1, 2)
ORDER BY Student_ID;
