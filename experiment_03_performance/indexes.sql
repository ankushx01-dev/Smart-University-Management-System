-- Experiment 3: add explicit B-tree indexes for the benchmark workload.
-- Run generate_data.py and explain_before.sql before this file.
-- Re-running the generator rebuilds the table and removes these indexes.

USE SUMS;

CREATE INDEX idx_ep_student_id
    ON Enrollment_Performance (Student_ID) USING BTREE;

CREATE INDEX idx_ep_course_id
    ON Enrollment_Performance (Course_ID) USING BTREE;

CREATE INDEX idx_ep_student_email_sha256
    ON Enrollment_Performance (Student_Email_SHA256) USING BTREE;

-- Refresh table statistics so the optimizer sees the new indexes.
ANALYZE TABLE Enrollment_Performance;

-- Verify all three indexes are B-tree indexes on the intended columns.
SELECT
    INDEX_NAME,
    COLUMN_NAME,
    INDEX_TYPE,
    NON_UNIQUE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'Enrollment_Performance'
  AND INDEX_NAME IN (
      'idx_ep_student_id',
      'idx_ep_course_id',
      'idx_ep_student_email_sha256'
  )
ORDER BY INDEX_NAME;
