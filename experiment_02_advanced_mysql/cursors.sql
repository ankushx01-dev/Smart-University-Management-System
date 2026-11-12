-- Experiment 2: summarize enrolments and average grade points by department.
-- Grade points: A+/A 4.0, A- 3.7, B+ 3.3, B 3.0, B- 2.7, C+ 2.3,
-- C 2.0, D 1.0, F 0.0. In-progress (IP) grades are excluded from averages.

USE SUMS;

DROP PROCEDURE IF EXISTS DepartmentPerformanceSummary;

DELIMITER $$

CREATE PROCEDURE DepartmentPerformanceSummary()
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_department_id SMALLINT UNSIGNED;
    DECLARE v_department_name VARCHAR(100);
    DECLARE v_total_enrollments INT UNSIGNED;
    DECLARE v_average_grade_points DECIMAL(5, 2);

    DECLARE department_performance_cursor CURSOR FOR
        SELECT
            d.Department_ID,
            d.Department_Name,
            COUNT(e.Enrollment_ID) AS Total_Enrollments,
            AVG(
                CASE e.Grade
                    WHEN 'A+' THEN 4.0
                    WHEN 'A'  THEN 4.0
                    WHEN 'A-' THEN 3.7
                    WHEN 'B+' THEN 3.3
                    WHEN 'B'  THEN 3.0
                    WHEN 'B-' THEN 2.7
                    WHEN 'C+' THEN 2.3
                    WHEN 'C'  THEN 2.0
                    WHEN 'D'  THEN 1.0
                    WHEN 'F'  THEN 0.0
                    ELSE NULL
                END
            ) AS Average_Grade_Points
        FROM Departments AS d
        LEFT JOIN Courses AS c ON c.Department_ID = d.Department_ID
        LEFT JOIN Enrollments AS e ON e.Course_ID = c.Course_ID
        GROUP BY d.Department_ID, d.Department_Name
        ORDER BY d.Department_ID;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DROP TEMPORARY TABLE IF EXISTS tmp_department_performance_summary;

    CREATE TEMPORARY TABLE tmp_department_performance_summary (
        Department_ID SMALLINT UNSIGNED NOT NULL,
        Department_Name VARCHAR(100) NOT NULL,
        Total_Enrollments INT UNSIGNED NOT NULL,
        Average_Grade_Points DECIMAL(5, 2) NULL,
        PRIMARY KEY (Department_ID)
    ) ENGINE = InnoDB;

    OPEN department_performance_cursor;

    department_loop: LOOP
        FETCH department_performance_cursor
        INTO v_department_id,
             v_department_name,
             v_total_enrollments,
             v_average_grade_points;

        IF v_done THEN
            LEAVE department_loop;
        END IF;

        INSERT INTO tmp_department_performance_summary (
            Department_ID,
            Department_Name,
            Total_Enrollments,
            Average_Grade_Points
        ) VALUES (
            v_department_id,
            v_department_name,
            v_total_enrollments,
            v_average_grade_points
        );
    END LOOP;

    CLOSE department_performance_cursor;

    SELECT
        Department_ID,
        Department_Name,
        Total_Enrollments,
        ROUND(Average_Grade_Points, 2) AS Average_Grade_Points
    FROM tmp_department_performance_summary
    ORDER BY Department_ID;

    DROP TEMPORARY TABLE tmp_department_performance_summary;
END$$

DELIMITER ;

-- Positive and zero-activity test: returns every department, including
-- departments 9 and 10 with zero enrolments and a NULL average.
CALL DepartmentPerformanceSummary();
