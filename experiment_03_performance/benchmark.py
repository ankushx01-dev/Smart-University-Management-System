"""Compare equality lookups with indexes ignored versus explicitly used.

Run after generate_data.py and indexes.sql:
    python experiment_03_performance/benchmark.py --iterations 10

The baseline uses IGNORE INDEX on the three benchmark indexes, reproducing
the unindexed access path without dropping indexes. The indexed case forces
the corresponding B-tree index so the comparison is repeatable.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Any

import mysql.connector
from mysql.connector import Error


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from database.connection import get_mysql_connection  # noqa: E402


TABLE_NAME = "Enrollment_Performance"
MINIMUM_ROWS = 50_000
INDEX_NAMES = (
    "idx_ep_student_id",
    "idx_ep_course_id",
    "idx_ep_student_email_sha256",
)
DEFAULT_OUTPUT = Path(__file__).with_name("benchmark_results.csv")
ACTUAL_ROWS_PATTERN = re.compile(
    r"actual time=[^)]*?\brows=(\d+)\s+loops=(\d+)", re.IGNORECASE
)


@dataclass(frozen=True)
class Workload:
    """One query shape and the lookup value used for both benchmark modes."""

    name: str
    target_description: str
    target_value: int | str
    index_name: str
    baseline_sql: str
    indexed_sql: str


def parse_arguments() -> argparse.Namespace:
    """Parse repeat count, warmups, and output path."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--iterations",
        type=int,
        default=10,
        help="measured runs per query and mode (default: 10)",
    )
    parser.add_argument(
        "--warmups",
        type=int,
        default=2,
        help="unrecorded warm-up runs per query and mode (default: 2)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="CSV destination (default: experiment_03_performance/benchmark_results.csv)",
    )
    arguments = parser.parse_args()
    if arguments.iterations < 1:
        parser.error("--iterations must be greater than zero")
    if arguments.warmups < 0:
        parser.error("--warmups cannot be negative")
    return arguments


def check_benchmark_table(cursor: mysql.connector.cursor.MySQLCursor) -> int:
    """Check that the generated dataset and all intended indexes exist."""
    cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
    row_count = int(cursor.fetchone()[0])
    if row_count < MINIMUM_ROWS:
        raise RuntimeError(
            f"{TABLE_NAME} contains {row_count:,} rows; run generate_data.py "
            f"to load at least {MINIMUM_ROWS:,}."
        )

    cursor.execute(f"SHOW INDEX FROM {TABLE_NAME}")
    existing_indexes = {str(row[2]) for row in cursor.fetchall()}
    missing_indexes = sorted(set(INDEX_NAMES) - existing_indexes)
    if missing_indexes:
        raise RuntimeError(
            "Required indexes are missing: "
            + ", ".join(missing_indexes)
            + ". Run indexes.sql before benchmark.py."
        )
    return row_count


def build_workloads(cursor: mysql.connector.cursor.MySQLCursor) -> list[Workload]:
    """Use existing SUMS student/course IDs and email for lookup parameters."""
    cursor.execute("SELECT Student_ID, Email FROM Students ORDER BY Student_ID LIMIT 1")
    student_row = cursor.fetchone()
    cursor.execute("SELECT Course_ID FROM Courses ORDER BY Course_ID LIMIT 1")
    course_row = cursor.fetchone()
    if student_row is None or course_row is None:
        raise RuntimeError("SUMS.Students and SUMS.Courses must contain seed rows.")

    student_id = int(student_row[0])
    email = str(student_row[1]).strip().casefold()
    course_id = int(course_row[0])
    email_hash = hashlib.sha256(email.encode("utf-8")).hexdigest()
    ignored_indexes = ", ".join(INDEX_NAMES)

    return [
        Workload(
            name="Student_ID equality",
            target_description=f"Student_ID={student_id}",
            target_value=student_id,
            index_name="idx_ep_student_id",
            baseline_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Course_ID, ep.Semester, "
                f"ep.Grade, ep.Credits FROM {TABLE_NAME} AS ep "
                f"IGNORE INDEX ({ignored_indexes}) WHERE ep.Student_ID = %s"
            ),
            indexed_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Course_ID, ep.Semester, "
                f"ep.Grade, ep.Credits FROM {TABLE_NAME} AS ep "
                f"FORCE INDEX (idx_ep_student_id) WHERE ep.Student_ID = %s"
            ),
        ),
        Workload(
            name="Course_ID equality",
            target_description=f"Course_ID={course_id}",
            target_value=course_id,
            index_name="idx_ep_course_id",
            baseline_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Student_ID, ep.Semester, "
                f"ep.Grade, ep.Credits FROM {TABLE_NAME} AS ep "
                f"IGNORE INDEX ({ignored_indexes}) WHERE ep.Course_ID = %s"
            ),
            indexed_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Student_ID, ep.Semester, "
                f"ep.Grade, ep.Credits FROM {TABLE_NAME} AS ep "
                f"FORCE INDEX (idx_ep_course_id) WHERE ep.Course_ID = %s"
            ),
        ),
        Workload(
            name="SHA-256 email equality",
            target_description=f"SHA-256 for Student_ID={student_id}",
            target_value=email_hash,
            index_name="idx_ep_student_email_sha256",
            baseline_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Student_ID, ep.Course_ID, "
                f"ep.Semester, ep.Grade FROM {TABLE_NAME} AS ep "
                f"IGNORE INDEX ({ignored_indexes}) "
                f"WHERE ep.Student_Email_SHA256 = %s"
            ),
            indexed_sql=(
                f"SELECT ep.Performance_Enrollment_ID, ep.Student_ID, ep.Course_ID, "
                f"ep.Semester, ep.Grade FROM {TABLE_NAME} AS ep "
                f"FORCE INDEX (idx_ep_student_email_sha256) "
                f"WHERE ep.Student_Email_SHA256 = %s"
            ),
        ),
    ]


def estimated_rows_examined(cursor: mysql.connector.cursor.MySQLCursor, sql: str, value: Any) -> int:
    """Read the optimizer's estimated rows per scan from EXPLAIN JSON."""
    cursor.execute(f"EXPLAIN FORMAT=JSON {sql}", (value,))
    plan_json = json.loads(cursor.fetchone()[0])
    estimates: list[int] = []

    def visit(node: Any) -> None:
        if isinstance(node, dict):
            estimate = node.get("rows_examined_per_scan")
            if estimate is not None:
                estimates.append(int(estimate))
            for child in node.values():
                visit(child)
        elif isinstance(node, list):
            for child in node:
                visit(child)

    visit(plan_json)
    if not estimates:
        raise RuntimeError("EXPLAIN JSON did not contain rows_examined_per_scan.")
    return max(estimates)


def explain_analyze_and_actual_rows(
    cursor: mysql.connector.cursor.MySQLCursor, sql: str, value: Any
) -> tuple[str, int]:
    """Capture the actual iterator plan and row count at its table access."""
    cursor.execute(f"EXPLAIN ANALYZE {sql}", (value,))
    plan = str(cursor.fetchone()[0])
    matches: list[tuple[int, int]] = []
    matches.extend(
        (int(rows), int(loops)) for rows, loops in ACTUAL_ROWS_PATTERN.findall(plan)
    )
    if not matches:
        raise RuntimeError("Could not read actual iterator rows from EXPLAIN ANALYZE output.")
    actual_access_rows = max(rows * loops for rows, loops in matches)
    return plan, actual_access_rows


def run_once(
    cursor: mysql.connector.cursor.MySQLCursor, sql: str, value: Any
) -> tuple[float, int]:
    """Run a SELECT, consume its rows, and return elapsed milliseconds and count."""
    started_at = perf_counter()
    cursor.execute(sql, (value,))
    result_rows = cursor.fetchall()
    elapsed_ms = (perf_counter() - started_at) * 1_000
    return elapsed_ms, len(result_rows)


def benchmark_workload(
    cursor: mysql.connector.cursor.MySQLCursor,
    workload: Workload,
    iterations: int,
    warmups: int,
    mysql_version: str,
) -> list[dict[str, Any]]:
    """Measure both query paths repeatedly and return CSV-ready metric rows."""
    modes = (
        ("before_no_index", workload.baseline_sql),
        ("after_btree_index", workload.indexed_sql),
    )
    plan_by_mode: dict[str, tuple[str, int, int]] = {}
    for mode, sql in modes:
        estimate = estimated_rows_examined(cursor, sql, workload.target_value)
        plan, actual_access_rows = explain_analyze_and_actual_rows(
            cursor, sql, workload.target_value
        )
        plan_by_mode[mode] = (plan, actual_access_rows, estimate)

    # Alternate which mode runs first in each warm-up and measured pair to
    # reduce systematic ordering and cache-warmth bias.
    timings: dict[str, list[float]] = {mode: [] for mode, _ in modes}
    returned_rows: dict[str, int] = {}
    for iteration in range(warmups + iterations):
        run_modes = list(modes)
        if iteration % 2:
            run_modes.reverse()
        for mode, sql in run_modes:
            elapsed_ms, rows = run_once(cursor, sql, workload.target_value)
            if mode in returned_rows and returned_rows[mode] != rows:
                raise RuntimeError(f"Unstable result count for {workload.name} ({mode}).")
            returned_rows[mode] = rows
            if iteration >= warmups:
                timings[mode].append(elapsed_ms)

    before_count = returned_rows["before_no_index"]
    after_count = returned_rows["after_btree_index"]
    if before_count != after_count:
        raise RuntimeError(f"Before/after result counts differ for {workload.name}.")

    result_rows: list[dict[str, Any]] = []
    for mode, _ in modes:
        plan, actual_access_rows, estimate = plan_by_mode[mode]
        samples = timings[mode]
        result_rows.append(
            {
                "mysql_version": mysql_version,
                "query_name": workload.name,
                "target": workload.target_description,
                "mode": mode,
                "index_name": workload.index_name if mode == "after_btree_index" else "none",
                "iterations": iterations,
                "warmups": warmups,
                "average_execution_ms": f"{statistics.fmean(samples):.6f}",
                "minimum_execution_ms": f"{min(samples):.6f}",
                "maximum_execution_ms": f"{max(samples):.6f}",
                "rows_returned": before_count,
                "rows_examined": actual_access_rows,
                "estimated_rows_examined": estimate,
                "execution_plan": plan,
            }
        )
    return result_rows


def write_csv(output_path: Path, rows: list[dict[str, Any]]) -> Path:
    """Write all timing, row, and plan measurements to a CSV file."""
    output_path = output_path.expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0].keys())
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return output_path


def run_benchmark(arguments: argparse.Namespace) -> None:
    """Validate prerequisites, run workloads, and report measured averages."""
    connection = get_mysql_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT VERSION()")
            mysql_version = str(cursor.fetchone()[0])
            row_count = check_benchmark_table(cursor)
            workloads = build_workloads(cursor)

            all_results: list[dict[str, Any]] = []
            for workload in workloads:
                all_results.extend(
                    benchmark_workload(
                        cursor,
                        workload,
                        arguments.iterations,
                        arguments.warmups,
                        mysql_version,
                    )
                )

        output_path = write_csv(arguments.output, all_results)
        print(f"MySQL {mysql_version}; benchmark rows: {row_count:,}")
        print(
            f"Measured {arguments.iterations} iterations after "
            f"{arguments.warmups} warm-ups per query and mode."
        )
        print(
            "\nQuery                         Mode                 Average ms   "
            "Rows examined   Rows returned"
        )
        for result in all_results:
            print(
                f"{result['query_name']:<29} {result['mode']:<21} "
                f"{result['average_execution_ms']:>10} "
                f"{result['rows_examined']:>14} {result['rows_returned']:>15}"
            )
        print(f"CSV with plans and metrics: {output_path}")
    finally:
        connection.close()


def main() -> int:
    arguments = parse_arguments()
    try:
        run_benchmark(arguments)
    except (Error, RuntimeError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"Benchmark failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
