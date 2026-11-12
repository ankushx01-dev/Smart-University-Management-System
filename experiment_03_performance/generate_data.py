"""Create a reproducible, unindexed enrolment workload in the SUMS database.

Run from the project root:
    python experiment_03_performance/generate_data.py

The dedicated benchmark table is rebuilt on each run. It references only
Student_ID and Course_ID values that exist in the Experiment 1 tables; a
post-load orphan check verifies that relationship before commit. It has no
foreign-key constraints or secondary indexes so EXPLAIN can show a true
unindexed baseline without changing the production Enrollments table.
"""

from __future__ import annotations

import argparse
import hashlib
import random
import sys
from pathlib import Path

import mysql.connector
from mysql.connector import Error


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from database.connection import get_mysql_connection  # noqa: E402


MINIMUM_ROWS = 50_000
DEFAULT_SEED = 20_261_112
GRADE_VALUES = ("A+", "A", "A-", "B+", "B", "B-", "C+", "C", "D", "F", "IP")
GRADE_WEIGHTS = (1, 8, 8, 10, 15, 10, 10, 12, 8, 8, 10)
SEMESTERS = tuple(
    f"{year}-{term}"
    for year in range(2018, 2027)
    for term in ("Spring", "Fall")
)


def parse_arguments() -> argparse.Namespace:
    """Read reproducibility and batching options from the command line."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rows",
        type=int,
        default=MINIMUM_ROWS,
        help=f"number of synthetic rows to create (minimum {MINIMUM_ROWS})",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="random seed; keep it unchanged to reproduce the same records",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1_000,
        help="rows per parameterized executemany batch",
    )
    arguments = parser.parse_args()
    if arguments.rows < MINIMUM_ROWS:
        parser.error(f"--rows must be at least {MINIMUM_ROWS}")
    if arguments.batch_size < 1:
        parser.error("--batch-size must be greater than zero")
    return arguments


def create_benchmark_table(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    """Rebuild only the experiment's staging table with no lookup indexes."""
    cursor.execute("DROP TABLE IF EXISTS Enrollment_Performance")
    cursor.execute(
        """
        CREATE TABLE Enrollment_Performance (
            Performance_Enrollment_ID BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            Student_ID INT UNSIGNED NOT NULL,
            Course_ID SMALLINT UNSIGNED NOT NULL,
            Semester VARCHAR(20) NOT NULL,
            Grade VARCHAR(2) NOT NULL,
            Credits TINYINT UNSIGNED NOT NULL,
            Student_Email_SHA256 CHAR(64)
                CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
            CONSTRAINT pk_enrollment_performance
                PRIMARY KEY (Performance_Enrollment_ID),
            CONSTRAINT chk_ep_credits CHECK (Credits BETWEEN 1 AND 6),
            CONSTRAINT chk_ep_grade
                CHECK (Grade IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D', 'F', 'IP'))
        ) ENGINE = InnoDB
        """
    )


def load_valid_reference_data(cursor: mysql.connector.cursor.MySQLCursor) -> tuple[
    list[tuple[int, str]], dict[int, int]
]:
    """Read the real seed IDs and credits used by the synthetic fact rows."""
    cursor.execute("SELECT Student_ID, Email FROM Students ORDER BY Student_ID")
    students = [(int(student_id), str(email)) for student_id, email in cursor.fetchall()]
    cursor.execute("SELECT Course_ID, Credits FROM Courses ORDER BY Course_ID")
    courses = {int(course_id): int(credits) for course_id, credits in cursor.fetchall()}

    if not students:
        raise RuntimeError("SUMS.Students is empty; run Experiment 1 seed_data first.")
    if not courses:
        raise RuntimeError("SUMS.Courses is empty; run Experiment 1 seed_data first.")
    if any(not email for _, email in students):
        raise RuntimeError("Every reference student must have an email address.")
    return students, courses


def make_rows(
    *,
    row_count: int,
    seed: int,
    students: list[tuple[int, str]],
    courses: dict[int, int],
):
    """Yield deterministic records whose IDs and email hashes match SUMS."""
    generator = random.Random(seed)
    student_ids = [student_id for student_id, _ in students]
    email_by_student = {
        student_id: hashlib.sha256(email.strip().casefold().encode("utf-8")).hexdigest()
        for student_id, email in students
    }
    course_ids = list(courses)

    # A modestly skewed distribution gives the benchmark a selective lookup
    # target (the first existing ID) while retaining records for every ID.
    student_weights = [1 if student_id == student_ids[0] else 10 for student_id in student_ids]
    course_weights = [1 if course_id == course_ids[0] else 10 for course_id in course_ids]

    chosen_students = generator.choices(student_ids, weights=student_weights, k=row_count)
    chosen_courses = generator.choices(course_ids, weights=course_weights, k=row_count)

    for student_id, course_id in zip(chosen_students, chosen_courses, strict=True):
        yield (
            student_id,
            course_id,
            generator.choice(SEMESTERS),
            generator.choices(GRADE_VALUES, weights=GRADE_WEIGHTS, k=1)[0],
            courses[course_id],
            email_by_student[student_id],
        )


def verify_row_count_and_references(
    cursor: mysql.connector.cursor.MySQLCursor, expected_rows: int
) -> None:
    """Check the loaded count and ensure no generated IDs are orphaned."""
    cursor.execute("SELECT COUNT(*) FROM Enrollment_Performance")
    actual_rows = int(cursor.fetchone()[0])
    if actual_rows != expected_rows:
        raise RuntimeError(f"Expected {expected_rows} rows, found {actual_rows}.")

    cursor.execute(
        """
        SELECT
            SUM(s.Student_ID IS NULL) AS Missing_Students,
            SUM(c.Course_ID IS NULL) AS Missing_Courses
        FROM Enrollment_Performance AS ep
        LEFT JOIN Students AS s ON s.Student_ID = ep.Student_ID
        LEFT JOIN Courses AS c ON c.Course_ID = ep.Course_ID
        """
    )
    missing_students, missing_courses = cursor.fetchone()
    if int(missing_students or 0) or int(missing_courses or 0):
        raise RuntimeError(
            "Reference audit failed: "
            f"{missing_students} student IDs and {missing_courses} course IDs are missing."
        )


def generate_data(arguments: argparse.Namespace) -> None:
    """Rebuild and populate the performance table in one data transaction."""
    connection = get_mysql_connection()
    try:
        with connection.cursor() as cursor:
            create_benchmark_table(cursor)
            students, courses = load_valid_reference_data(cursor)

            insert_sql = """
                INSERT INTO Enrollment_Performance
                    (Student_ID, Course_ID, Semester, Grade, Credits, Student_Email_SHA256)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            generated_rows = make_rows(
                row_count=arguments.rows,
                seed=arguments.seed,
                students=students,
                courses=courses,
            )

            inserted = 0
            while inserted < arguments.rows:
                next_count = min(arguments.batch_size, arguments.rows - inserted)
                batch = [next(generated_rows) for _ in range(next_count)]
                cursor.executemany(insert_sql, batch)
                inserted += len(batch)
                print(f"Prepared {inserted:,} of {arguments.rows:,} rows")

            verify_row_count_and_references(cursor, arguments.rows)
        connection.commit()
        print(
            f"Loaded {arguments.rows:,} reproducible rows into "
            "SUMS.Enrollment_Performance."
        )
        print("Foreign-key consistency audit passed: 0 missing students, 0 missing courses.")
        print("The table has only its primary key; run indexes.sql for the indexed phase.")
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def main() -> int:
    arguments = parse_arguments()
    try:
        generate_data(arguments)
    except (Error, RuntimeError, ValueError) as error:
        print(f"Data generation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
