-- Experiment 2: sum course credits for a student's passing enrolments.
-- Passing grades are A+ through D; F and IP do not earn credits.

USE SUMS;

DROP FUNCTION IF EXISTS EarnedCredits;

DELIMITER $$

CREATE FUNCTION EarnedCredits(p_student_id INT UNSIGNED)
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_student_exists BOOLEAN DEFAULT FALSE;
    DECLARE v_earned_credits BIGINT UNSIGNED DEFAULT 0;

    IF p_student_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'EarnedCredits rejected: Student_ID is required.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM Students
        WHERE Student_ID = p_student_id
    ) INTO v_student_exists;

    IF NOT v_student_exists THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'EarnedCredits rejected: Student_ID does not exist.';
    END IF;

    SELECT COALESCE(SUM(c.Credits), 0)
    INTO v_earned_credits
    FROM Enrollments AS e
    INNER JOIN Courses AS c ON c.Course_ID = e.Course_ID
    WHERE e.Student_ID = p_student_id
      AND e.Grade IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D');

    RETURN v_earned_credits;
END$$

DELIMITER ;

-- Positive test: student 1 has passed 4-credit and 3-credit courses.
SELECT EarnedCredits(1) AS Student_1_Earned_Credits;

-- Zero-credit edge test: student 10 has no enrolments in the seed data.
SELECT EarnedCredits(10) AS Student_10_Earned_Credits;

-- Negative test: capture the expected error for an unknown student ID.
DROP PROCEDURE IF EXISTS TestEarnedCreditsInvalidStudent;

DELIMITER $$

CREATE PROCEDURE TestEarnedCreditsInvalidStudent()
BEGIN
    DECLARE v_actual_error TEXT DEFAULT NULL;
    DECLARE v_earned_credits BIGINT UNSIGNED DEFAULT NULL;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_actual_error = MESSAGE_TEXT;
    END;

    SET v_earned_credits = EarnedCredits(9999);

    SELECT
        IF(
            v_actual_error = 'EarnedCredits rejected: Student_ID does not exist.',
            'PASS',
            'FAIL'
        ) AS Test_Result,
        v_actual_error AS Actual_Error;
END$$

DELIMITER ;

CALL TestEarnedCreditsInvalidStudent();
DROP PROCEDURE TestEarnedCreditsInvalidStudent;
