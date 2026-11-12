# Experiment 1 — Relational Database Using MySQL

## Aim

Build a small, normalized relational database for the Smart University
Management System (SUMS), then demonstrate constraints, joins, database
privileges, and transaction control.

## Objectives

- Create the `SUMS` database and six related InnoDB tables.
- Enforce primary keys, foreign keys, uniqueness, and required values.
- Seed ten synthetic rows in each table.
- Retrieve enrolled student-course details with an `INNER JOIN`.
- Find students without enrolments with a `LEFT JOIN`.
- Grant and revoke database-level privileges for a dedicated lab account.
- Show how `COMMIT` persists a change and `ROLLBACK` discards one.

## Prerequisites

- MySQL Server 8.0.18 or newer and the `mysql` command-line client.
- A MySQL administrator account that can create databases, tables, and users.
- A terminal opened at the SUMS project root.

MySQL 8.0.18 is required for the generated-password form of `CREATE USER` in
`permissions.sql`. The other files use MySQL 8.0 SQL and InnoDB.

## Files and execution order

Run each file from the MySQL client in this order:

1. `schema.sql` — creates the database and tables.
2. `insert_data.sql` — inserts or updates the synthetic sample records.
3. `joins.sql` — executes the required `INNER JOIN` and `LEFT JOIN` queries.
4. `permissions.sql` — creates the lab account, grants `SELECT` and `INSERT`,
   then revokes `INSERT`. Run it as an administrator.
5. `transactions.sql` — demonstrates and verifies `COMMIT` and `ROLLBACK`.

From PowerShell, open the MySQL client while your current directory is the
project root:

```powershell
mysql --host=localhost --user=root --password
```

Enter the administrator password at the prompt. At the `mysql>` prompt, run:

```sql
SOURCE experiment_01_relational_sql/schema.sql;
SOURCE experiment_01_relational_sql/insert_data.sql;
SOURCE experiment_01_relational_sql/joins.sql;
SOURCE experiment_01_relational_sql/permissions.sql;
SOURCE experiment_01_relational_sql/transactions.sql;
```

The client prompts for the password without putting it in command history. If
`mysql` is not on `PATH`, run the `mysql.exe` installed with MySQL Server. If a
`SOURCE` command cannot find a file, first change the terminal's working
directory to the project root, then open `mysql` again.

`schema.sql` does not drop existing tables or data. The seed file uses
`ON DUPLICATE KEY UPDATE`, so rerunning it keeps the ten fixed sample IDs and
does not add duplicate rows. The transaction script restores its edited names
to the seed values when it finishes.

## Expected outputs (examples, not execution results)

The following are expected on a fresh database; they are examples, not claims
that the SQL has been run on your server.

- The schema verification query lists six tables: `Campuses`, `Courses`,
  `Departments`, `Enrollments`, `Professors`, and `Students`.
- The seed verification query reports `Record_Count = 10` for each of those
  six tables. Both student orphan counts are `0`.
- The `INNER JOIN` returns ten enrollment rows. Example rows include Aarav
  Mehta with Introduction to Python (`2026-Fall`, grade `A`) and Diya Sharma
  with Linear Algebra (`2026-Fall`, grade `A-`).
- The `LEFT JOIN` returns Vikram Bose (Student_ID 9) and Tara Sen (Student_ID
  10), who have no enrollment rows. The summary reports 10 enrollments and 2
  students without enrolments.
- On its first run, `CREATE USER ... IDENTIFIED BY RANDOM PASSWORD` returns a
  generated password. Save it securely if you want to sign in as the lab user.
  The grant verification reports two privileges before `REVOKE`; afterward,
  `Select_Grants_Remaining` is 1 and `Insert_Grants_Remaining` is 0.
- In the transaction demo, the committed name is visible after `COMMIT`. The
  rollback demo shows the temporary name before `ROLLBACK` and the original
  `Diya Sharma` afterward. The final query shows the original seeded names for
  both students.

You can verify the dedicated account's remaining read access from a second
terminal using the generated password:

```powershell
mysql --host=localhost --user=sums_lab_user --password --database=SUMS
```

Then run `SELECT COUNT(*) FROM Students;` at the `mysql>` prompt. It should
succeed. `INSERT` should be denied after the `REVOKE`; do not use this lab
account for any other database.

## Troubleshooting

- **Access denied for the administrator:** confirm the MySQL service is
  running and retry with the correct administrator account.
- **`mysql` is not recognized:** add the MySQL Server `bin` directory to
  `PATH`, or invoke its `mysql.exe` by full path.
- **Generated-password syntax is rejected:** check `SELECT VERSION();` and
  upgrade to MySQL 8.0.18 or newer before running `permissions.sql`.
- **A foreign-key error occurs while seeding:** confirm `schema.sql` completed
  successfully and execute files in the listed order.
- **The lab account already exists:** keep using its existing password. If it
  was lost, an administrator can reset it with
  `ALTER USER 'sums_lab_user'@'localhost' IDENTIFIED BY RANDOM PASSWORD;` and
  securely store the newly displayed password.

## Screenshot checklist

- Six created tables from the schema verification query.
- Ten-row count output for each table after seeding.
- `INNER JOIN` output and the two-row `LEFT JOIN` output.
- `SHOW GRANTS` output before and after `REVOKE`, including the verification
  counts for `SELECT` and `INSERT`.
- Transaction output showing the committed value and the rolled-back value.

## Viva questions and answers

1. **What is a primary key?** A column or column set that uniquely identifies
   each row and cannot contain `NULL`.
2. **What does a foreign key enforce?** That a referenced parent row exists,
   preserving referential integrity.
3. **Why is `Students.Email` unique?** A student email identifies one student
   and must not be duplicated.
4. **What does `NOT NULL` mean?** Every inserted row must provide a value for
   that column.
5. **What does an `INNER JOIN` return?** Rows with matching keys in both joined
   tables.
6. **How does a `LEFT JOIN` find students without enrolments?** Keep every
   student row and filter where the enrollment primary key is `NULL`.
7. **What is the purpose of `ON DELETE RESTRICT`?** It prevents deleting a
   parent row while child rows still reference it.
8. **What does `GRANT` do?** It assigns specified privileges to a database
   account.
9. **What does `REVOKE` do?** It removes a previously assigned privilege at
   the specified privilege level.
10. **What does `COMMIT` do?** It makes the current transaction's changes
    permanent.
11. **What does `ROLLBACK` do?** It cancels uncommitted changes in the current
    transaction.
12. **Why use InnoDB?** It supports transactions, row-level locking, and
    foreign-key constraints.
13. **Why use `ON DUPLICATE KEY UPDATE` in the seed script?** It lets the
    deterministic sample data be reapplied without creating duplicate rows.

## Observations

The foreign keys tie students and professors to departments and campuses, and
tie enrolments to valid students and courses. The inner join returns only
matched enrolment rows, while the left join keeps every student long enough to
identify those with no matching enrolment. The privilege checks demonstrate a
read-and-insert grant followed by removal of the insert privilege. The
transaction queries make the different outcomes of commit and rollback visible.

## Conclusion

This experiment establishes the SUMS relational foundation and demonstrates
how constraints, joins, permissions, and transaction control protect and
retrieve consistent academic records in MySQL.

## MySQL references

- [MySQL 8.0 `CREATE USER` statement](https://dev.mysql.com/doc/refman/8.0/en/create-user.html)
- [MySQL 8.0 `GRANT` and `REVOKE` statements](https://dev.mysql.com/doc/refman/8.0/en/grant.html)
- [MySQL 8.0 `INFORMATION_SCHEMA.SCHEMA_PRIVILEGES`](https://dev.mysql.com/doc/refman/8.0/en/information-schema-schema-privileges-table.html)
