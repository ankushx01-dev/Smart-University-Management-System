# Experiment 2 — Advanced MySQL Programming

## Aim

Extend the SUMS relational schema with a view, an enrolment validation trigger,
a safe registration procedure, an earned-credits function, and a cursor-based
department performance summary.

## Prerequisites

- MySQL 8.0 and the MySQL command-line client (or MySQL Workbench with stored
  routine delimiter support).
- Experiment 1 completed: database `SUMS`, its six tables, and its synthetic
  seed data must exist.
- An account with permission to create views, triggers, procedures, and
  functions in `SUMS`.
- The cursor and routine tests use the Experiment 1 seed IDs and values.

## Execution order

From PowerShell, start the MySQL client at the project root:

```powershell
mysql --host=localhost --user=root --password
```

At the `mysql>` prompt, execute the files in this order:

```sql
SOURCE experiment_02_advanced_mysql/views.sql;
SOURCE experiment_02_advanced_mysql/triggers.sql;
SOURCE experiment_02_advanced_mysql/procedures.sql;
SOURCE experiment_02_advanced_mysql/functions.sql;
SOURCE experiment_02_advanced_mysql/cursors.sql;
```

Enter the administrator password at the prompt. If `mysql` is not on `PATH`,
invoke the MySQL Server `mysql.exe` by its installed path. Open the client from
the project root so the relative `SOURCE` paths resolve. All files select
`SUMS` themselves. The view and routines use `CREATE OR REPLACE` or
`DROP ... IF EXISTS`, so the object definitions can be reloaded. Positive
registration tests remove their temporary rows before the file finishes.

Run these files through the MySQL client or Workbench's script runner. `DELIMITER`
is a MySQL client command used to submit each complete stored-program body; it
is not a SQL statement to send separately through a Python connector.

## Objects and tests

### `views.sql`

Creates `Student_Enrollment_View` with student ID/name, course ID/name, credits,
semester, and grade. The positive query returns student 1's seeded courses. The
zero-row query for student 9 is the negative/edge case: an inner-join view has
no row for a student without enrolments.

### `triggers.sql`

Creates `trg_validate_enrollment_before_insert`. Before an insert, it checks
that the student and course exist, the semester is not blank, and the same
student/course/semester combination is not already registered. Rejections use
SQLSTATE `45000` with a message that identifies the problem. The schema's
unique key remains the final duplicate guard if two sessions race.

The script tests one valid temporary row, then safely captures expected errors
for an unknown student, unknown course, duplicate registration, and blank
semester. Each negative test prints `PASS` only when the returned error text
matches the expected message. The temporary valid row is deleted.

### `procedures.sql`

Creates `RegisterStudent(Student_ID, Course_ID, Semester)`. It validates all
three inputs, checks that the student and course exist, rejects an existing
registration, and inserts a new row with grade `IP` (in progress). One InnoDB
insert is atomic; the procedure leaves transaction boundaries under the
caller's control. SQL exceptions are re-signalled, while duplicate-key races
receive a clear duplicate-registration message.

The positive test registers student 10 in course 10 for `2027-Spring` and then
removes that temporary row. Negative tests safely capture unknown student,
unknown course, duplicate, and blank-semester errors.

### `functions.sql`

Creates `EarnedCredits(Student_ID)`. It sums the credits for grades A+, A, A-,
B+, B, B-, C+, C, and D. F and IP do not earn credits. An unknown student ID
raises a descriptive SQL error. The tests expect 7 credits for student 1, zero
for student 10, and a captured error for unknown student 9999.

### `cursors.sql`

Creates `DepartmentPerformanceSummary()`. Its cursor visits every department,
counts all enrolments in courses owned by that department, and calculates the
average grade points for completed grades. `IP` is ignored in the average but
still counts as an enrolment. It returns all departments, including those with
zero enrolments and a `NULL` average.

The grade-point mapping is A+/A = 4.0, A- = 3.7, B+ = 3.3, B = 3.0, B- = 2.7,
C+ = 2.3, C = 2.0, D = 1.0, and F = 0.0. Enrolments are grouped by the
department that owns the course.

## Expected outputs (examples, not actual execution)

These values are expected from the Experiment 1 seed data. They are examples,
not claims that the files have been executed against your MySQL server.

- `Student_Enrollment_View` for student 1 returns two rows: Introduction to
  Python (4 credits, grade A) and Linear Algebra (3 credits, grade A), both in
  `2026-Fall`. Student 9 returns a count of `0`.
- Trigger positive insert returns one row for student 10/course 10 and the
  final cleanup count is `0`. The four rejection checks report `PASS` with
  these messages: student does not exist; course does not exist; duplicate
  student/course/semester registration; semester must not be blank.
- `RegisterStudent(10, 10, '2027-Spring')` returns one row with grade `IP`.
  Its generated `Enrollment_ID` depends on prior inserts. Its four rejection
  checks report `PASS` for unknown student, unknown course, duplicate
  enrolment, and blank semester. The cleanup count is `0`.
- `EarnedCredits(1)` returns `7`; `EarnedCredits(10)` returns `0`. The unknown
  student test reports `PASS` and the expected SQL error text.
- `DepartmentPerformanceSummary()` returns 10 rows. Expected examples:

  | Department | Total enrolments | Average grade points |
  |---|---:|---:|
  | Computer Science | 2 | 3.65 |
  | Mathematics | 2 | 3.85 |
  | Physics | 1 | 3.30 |
  | Chemistry | 1 | 4.00 |
  | Electrical Engineering | 0 | `NULL` |
  | Business Administration | 0 | `NULL` |

## Troubleshooting

- **Unknown database or table:** complete Experiment 1's `schema.sql` and
  `insert_data.sql` first, then reconnect and run these files in order.
- **`DELIMITER` is rejected:** run the file in the `mysql` command-line client
  or Workbench's script runner; do not send the delimiter command through a
  connector API as if it were SQL.
- **Access denied while creating an object:** use an account that has the
  required `CREATE VIEW`, `TRIGGER`, `ROUTINE`, and `EXECUTE` permissions in
  `SUMS`, or ask the database administrator to run the setup files.
- **Function creation is blocked when binary logging is enabled:** use a local
  academic MySQL server account authorized to create stored functions, or ask
  the administrator to configure the server's stored-function policy.
- **A duplicate error appears during registration:** check the existing
  `(Student_ID, Course_ID, Semester)` row. The unique constraint intentionally
  prevents duplicate registrations even if two calls race.
- **Expected negative-test output says `FAIL`:** compare `Actual_Error` with
  the expected message. Confirm that the matching trigger/procedure definition
  from this folder was reloaded and that Experiment 1's schema is unchanged.

## Screenshot checklist

- The view output for student 1 and the zero-row check for student 9.
- Trigger test output with the positive row and four passing rejection checks.
- `RegisterStudent` positive output and the four passing negative tests.
- `EarnedCredits` results for students 1 and 10, plus the invalid-ID test.
- The department performance result set, including zero-enrolment departments.

## Viva questions and answers

1. **What is a view?** A named query that presents data from one or more
   underlying tables.
2. **Why use `SQL SECURITY INVOKER` for the view?** The query runs using the
   privileges of the user who selects from it.
3. **When does a `BEFORE INSERT` trigger run?** Once for each row before MySQL
   attempts to insert that row.
4. **What does `SIGNAL SQLSTATE '45000'` do?** It raises a user-defined SQL
   error with the supplied message.
5. **Why keep the unique key if the trigger checks duplicates?** The key is the
   final database-enforced guard, including under concurrent inserts.
6. **What is a stored procedure?** A named routine that can accept parameters
   and execute SQL statements.
7. **Why does `RegisterStudent` insert grade `IP`?** The enrolment exists, but
   the course has not yet received a final grade.
8. **What does `RESIGNAL` do?** It passes the current SQL exception back to the
   caller without hiding its diagnostic information.
9. **What is a stored function?** A routine that returns one value and can be
   used in an SQL expression.
10. **Which grades earn credits in this experiment?** A+ through D; F and IP
    do not earn credits.
11. **What is a cursor used for?** It processes a query result one row at a
    time inside a stored program.
12. **Why is the department cursor's join left-sided?** It preserves
    departments that currently have no courses with enrolments.
13. **Why is the average grade point `NULL` for a department with no graded
    enrolments?** There are no numeric grade points to average.

## Observations

The view simplifies repeated student-course joins. The trigger and procedure
provide readable validation errors, while the foreign keys and unique key
remain the final integrity controls. The credits function excludes failed and
in-progress courses. The cursor includes departments with no activity and
reports `NULL` where an average cannot be calculated.

## Conclusion

Experiment 2 adds reusable MySQL programming objects to SUMS and demonstrates
how views, triggers, procedures, functions, and cursors support validated
academic operations and department-level summaries.

## MySQL references

- [MySQL 8.0 trigger syntax and error behavior](https://dev.mysql.com/doc/refman/8.0/en/trigger-syntax.html)
- [MySQL 8.0 stored program restrictions](https://dev.mysql.com/doc/refman/8.0/en/stored-program-restrictions.html)
- [MySQL 8.0 `CREATE VIEW` statement](https://dev.mysql.com/doc/refman/8.0/en/create-view.html)
