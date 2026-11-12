-- Experiment 2: validate enrolments before they are inserted.
-- Duplicate checking here provides a clear message; the unique key from
-- Experiment 1 remains the final protection against concurrent duplicates.

USE SUMS;

DROP TRIGGER IF EXISTS trg_validate_enrollment_before_insert;

DELIMITER $$

CREATE TRIGGER trg_validate_enrollment_before_insert
BEFORE INSERT ON Enrollments
FOR EACH ROW
BEGIN
    DECLARE v_student_exists BOOLEAN DEFAULT FALSE;
    DECLARE v_course_exists BOOLEAN DEFAULT FALSE;
    DECLARE v_duplicate_exists BOOLEAN DEFAULT FALSE;

    IF NEW.Student_ID IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: Student_ID is required.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Students
        WHERE Student_ID = NEW.Student_ID
    ) INTO v_student_exists;

    IF NOT v_student_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: Student_ID does not exist.';
    END IF;

    IF NEW.Course_ID IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: Course_ID is required.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Courses
        WHERE Course_ID = NEW.Course_ID
    ) INTO v_course_exists;

    IF NOT v_course_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: Course_ID does not exist.';
    END IF;

    IF NEW.Semester IS NULL OR CHAR_LENGTH(TRIM(NEW.Semester)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: Semester must not be blank.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Enrollments AS existing_enrollment
        WHERE existing_enrollment.Student_ID = NEW.Student_ID
          AND existing_enrollment.Course_ID = NEW.Course_ID
          AND existing_enrollment.Semester = NEW.Semester
    ) INTO v_duplicate_exists;

    IF v_duplicate_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Enrollment rejected: duplicate student, course, and semester registration.';
    END IF;
END$$

DELIMITER ;

-- Positive test: add a valid temporary enrolment, verify it, and remove it.
INSERT INTO Enrollments (Student_ID, Course_ID, Semester, Grade)
VALUES (10, 10, '2027-Spring', 'IP');

SELECT Enrollment_ID, Student_ID, Course_ID, Semester, Grade
FROM Enrollments
WHERE Student_ID = 10
  AND Course_ID = 10
  AND Semester = '2027-Spring';

DELETE FROM Enrollments
WHERE Student_ID = 10
  AND Course_ID = 10
  AND Semester = '2027-Spring';

-- Negative tests safely capture the expected trigger errors so the whole file
-- can be sourced without stopping at an intentional rejection.
DROP PROCEDURE IF EXISTS TestTriggerRejection;

DELIMITER $$

CREATE PROCEDURE TestTriggerRejection(
    IN p_student_id INT UNSIGNED,
    IN p_course_id SMALLINT UNSIGNED,
    IN p_semester VARCHAR(20),
    IN p_expected_error VARCHAR(255)
)
BEGIN
    DECLARE v_actual_error TEXT DEFAULT NULL;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_actual_error = MESSAGE_TEXT;
    END;

    INSERT INTO Enrollments (Student_ID, Course_ID, Semester, Grade)
    VALUES (p_student_id, p_course_id, p_semester, 'IP');

    SELECT
        IF(v_actual_error = p_expected_error, 'PASS', 'FAIL') AS Test_Result,
        p_expected_error AS Expected_Error,
        v_actual_error AS Actual_Error;
END$$

DELIMITER ;

CALL TestTriggerRejection(
    9999,
    10,
    '2027-Spring',
    'Enrollment rejected: Student_ID does not exist.'
);

CALL TestTriggerRejection(
    10,
    9999,
    '2027-Spring',
    'Enrollment rejected: Course_ID does not exist.'
);

CALL TestTriggerRejection(
    1,
    1,
    '2026-Fall',
    'Enrollment rejected: duplicate student, course, and semester registration.'
);

CALL TestTriggerRejection(
    10,
    10,
    '',
    'Enrollment rejected: Semester must not be blank.'
);

DROP PROCEDURE TestTriggerRejection;

-- Verify the positive-test row was cleaned up.
SELECT COUNT(*) AS Temporary_Trigger_Test_Rows_Remaining
FROM Enrollments
WHERE Student_ID = 10
  AND Course_ID = 10
  AND Semester = '2027-Spring';
