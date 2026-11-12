-- Experiment 2: safely register one student in one course and semester.
-- Requires the validation trigger from triggers.sql.

USE SUMS;

DROP PROCEDURE IF EXISTS RegisterStudent;

DELIMITER $$

CREATE PROCEDURE RegisterStudent(
    IN p_student_id INT UNSIGNED,
    IN p_course_id SMALLINT UNSIGNED,
    IN p_semester VARCHAR(20)
)
BEGIN
    DECLARE v_exists BOOLEAN DEFAULT FALSE;

    -- Convert a concurrent unique-key collision into a clear registration error.
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: duplicate enrolment.';
    END;

    -- Preserve and return any other SQL exception, including trigger errors.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        RESIGNAL;
    END;

    IF p_student_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: Student_ID is required.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Students
        WHERE Student_ID = p_student_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: Student_ID does not exist.';
    END IF;

    IF p_course_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: Course_ID is required.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Courses
        WHERE Course_ID = p_course_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: Course_ID does not exist.';
    END IF;

    IF p_semester IS NULL OR CHAR_LENGTH(TRIM(p_semester)) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: Semester must not be blank.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Enrollments AS existing_enrollment
        WHERE existing_enrollment.Student_ID = p_student_id
          AND existing_enrollment.Course_ID = p_course_id
          AND existing_enrollment.Semester = p_semester
    ) INTO v_exists;

    IF v_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RegisterStudent rejected: duplicate enrolment.';
    END IF;

    -- Registration is a single atomic InnoDB INSERT. Grade starts as in progress.
    -- The trigger and unique key recheck invariants at the database boundary.
    INSERT INTO Enrollments (Student_ID, Course_ID, Semester, Grade)
    VALUES (p_student_id, p_course_id, p_semester, 'IP');

    SELECT Enrollment_ID, Student_ID, Course_ID, Semester, Grade
    FROM Enrollments
    WHERE Student_ID = p_student_id
      AND Course_ID = p_course_id
      AND Semester = p_semester;
END$$

DELIMITER ;

-- Positive test: register a valid pair and remove the temporary test row.
CALL RegisterStudent(10, 10, '2027-Spring');

DELETE FROM Enrollments
WHERE Student_ID = 10
  AND Course_ID = 10
  AND Semester = '2027-Spring';

-- Negative tests capture expected errors and keep the script executable.
DROP PROCEDURE IF EXISTS TestRegisterStudentRejection;

DELIMITER $$

CREATE PROCEDURE TestRegisterStudentRejection(
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

    CALL RegisterStudent(p_student_id, p_course_id, p_semester);

    SELECT
        IF(v_actual_error = p_expected_error, 'PASS', 'FAIL') AS Test_Result,
        p_expected_error AS Expected_Error,
        v_actual_error AS Actual_Error;
END$$

DELIMITER ;

CALL TestRegisterStudentRejection(
    9999,
    1,
    '2027-Spring',
    'RegisterStudent rejected: Student_ID does not exist.'
);

CALL TestRegisterStudentRejection(
    1,
    9999,
    '2027-Spring',
    'RegisterStudent rejected: Course_ID does not exist.'
);

CALL TestRegisterStudentRejection(
    1,
    1,
    '2026-Fall',
    'RegisterStudent rejected: duplicate enrolment.'
);

CALL TestRegisterStudentRejection(
    10,
    10,
    '',
    'RegisterStudent rejected: Semester must not be blank.'
);

DROP PROCEDURE TestRegisterStudentRejection;

-- Verify the positive-test row was cleaned up.
SELECT COUNT(*) AS Temporary_Procedure_Test_Rows_Remaining
FROM Enrollments
WHERE Student_ID = 10
  AND Course_ID = 10
  AND Semester = '2027-Spring';
