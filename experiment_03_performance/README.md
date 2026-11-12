# Experiment 3 — Database Performance Optimisation

## Aim

Measure how B-tree indexes affect realistic equality lookups over a large,
reproducible enrolment workload in the existing `SUMS` database.

## Prerequisites

- MySQL 8.0.18 or newer, the MySQL command-line client, Python 3.11+, and the
  dependencies in the project-root `requirements.txt`.
- Experiment 1 completed: `SUMS.Students` and `SUMS.Courses` must contain their
  seeded records.
- A project-root `.env` with valid `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`,
  `MYSQL_PASSWORD`, and `MYSQL_DATABASE=SUMS` values. Credentials are read by
  the shared `database/connection.py` helper and are not stored in this folder.
- An account with permission to create/drop the experiment's table and create
  indexes in `SUMS`.

The Experiment 1 `Enrollments` table already has a unique key and foreign-key
supporting indexes. This experiment therefore creates a separate
`SUMS.Enrollment_Performance` table for a clean unindexed baseline; it never
changes the production `Enrollments` table.

## Setup and execution

Run these commands from the project root in PowerShell. Copy the example
environment file only if `.env` does not already exist, then edit it and set
`MYSQL_DATABASE=SUMS` with your local connection values:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
python -m pip install -r requirements.txt
```

Generate at least 50,000 reproducible synthetic records. The default seed is
`20261112`; the same seed and reference rows produce the same row values.

```powershell
python experiment_03_performance/generate_data.py --rows 50000 --seed 20261112 --batch-size 1000
```

The generator rebuilds only `SUMS.Enrollment_Performance`, leaving the
Experiment 1 tables untouched. It uses actual IDs from `Students` and
`Courses`, copies the course credit values, computes SHA-256 hashes from
student email values, and audits for orphan IDs after loading. It prints the
loaded count and consistency audit result.

Open the MySQL client from the project root:

```powershell
mysql --host=localhost --user=root --password
```

At the `mysql>` prompt, capture the unindexed plans, add indexes, then capture
the indexed plans and run the hash lookup:

```sql
SOURCE experiment_03_performance/explain_before.sql;
SOURCE experiment_03_performance/indexes.sql;
SOURCE experiment_03_performance/explain_after.sql;
SOURCE experiment_03_performance/hash_lookup.sql;
```

Finally, measure both paths repeatedly and export the measurements and plans:

```powershell
python experiment_03_performance/benchmark.py --iterations 10 --warmups 2 --output experiment_03_performance/benchmark_results.csv
```

`benchmark.py` requires the indexes to exist. Its before path uses
`IGNORE INDEX` to reproduce the unindexed access path without dropping an
index; its after path uses `FORCE INDEX` to measure that index consistently.
The separate `explain_before.sql` is run while the table physically has no
secondary indexes, and `explain_after.sql` is run after they have been added.
The script alternates run order, performs warm-ups, fetches every result row,
and calculates the arithmetic mean, minimum, and maximum elapsed time.

The benchmark CSV contains one row per query and mode, with the MySQL version,
iteration counts, average/minimum/maximum milliseconds, rows returned,
`rows_examined` from the actual table-access iterator in `EXPLAIN ANALYZE`,
optimizer `estimated_rows_examined`, and the full execution plan. Timings are
wall-clock measurements from the Python client and depend on the host, storage,
buffer pool, and current load.

## Comparison tables

No benchmark numbers are included here because results must come from a real
run on the evaluator's MySQL server. Populate the cells from the matching
`before_no_index` and `after_btree_index` rows in the generated CSV.

| Query | Before average (ms) | After average (ms) | Before rows examined | After rows examined |
|---|---:|---:|---:|---:|
| `Student_ID = first seeded ID` | from CSV | from CSV | from CSV | from CSV |
| `Course_ID = first seeded ID` | from CSV | from CSV | from CSV | from CSV |
| `Student_Email_SHA256 = digest` | from CSV | from CSV | from CSV | from CSV |

Use the plan text alongside the timing table to verify the access path. Before
indexing, the expected plan is a table scan (`ALL`). After indexing, the
optimizer may choose the matching index; if it chooses a table scan, report
that observed plan and consider selectivity and table size before drawing a
conclusion. The CSV also contains the estimated and actual row counts for both
paths.

## Index and hash details

- `indexes.sql` creates B-tree indexes on `Student_ID`, `Course_ID`, and
  `Student_Email_SHA256`, then runs `ANALYZE TABLE` and verifies the index
  names, columns, and types.
- `generate_data.py` normalizes email with trim and case folding, calculates a
  hexadecimal SHA-256 digest, and stores it in
  `Student_Email_SHA256 CHAR(64)`. `hash_lookup.sql` and the Python benchmark
  calculate the same digest and search this indexed column.
- InnoDB uses B-tree indexes. The email hash is the value being indexed; this
  is not a MySQL `USING HASH` index.
- The benchmark table deliberately has no foreign-key constraints so the
  before plan can be unindexed. Its IDs are selected only from the existing
  parent tables and then checked with anti-joins before the data transaction
  is committed. The original SUMS tables retain their Experiment 1 foreign
  keys.

## When indexes help and when they may not

Indexes usually help when a query searches for a small fraction of a large
table by an indexed column, or uses that column to join tables. The optimizer
can navigate the B-tree to matching entries instead of inspecting every row.

An index may provide little benefit when a table is small, a query returns a
large share of its rows, or the query applies a function to the indexed column
instead of comparing the column directly. Indexes also use storage and add
work to inserts, updates, and deletes. The experiment's skewed synthetic data
creates selective test lookups, but results and optimizer choices must still
be measured rather than assumed.

## Expected outputs (examples, not actual execution)

- The generator reports `50,000` loaded rows for the default command, plus
  `0 missing students` and `0 missing courses`. These are expected for a
  successful run; they are not benchmark measurements.
- Before indexing, `EXPLAIN ANALYZE` is expected to show table scans and visit
  the table's rows for each equality lookup.
- `indexes.sql` reports three `BTREE` indexes, one per requested lookup
  column.
- After indexing, an indexed lookup plan may report an index lookup with fewer
  actual rows visited. The optimizer can choose a scan when its cost estimate
  favors one.
- `benchmark.py` prints six measurement rows (three query shapes times two
  modes) and creates `benchmark_results.csv` with the recorded plans and
  measured values. Exact timings are machine-dependent and are intentionally
  not predicted here.
- `hash_lookup.sql` reports the matching record count and up to ten matching
  rows for the first seeded student's email hash.

## Troubleshooting

- **Connection or access denied:** check the local MySQL service and values in
  `.env`; confirm the configured database is `SUMS` and the account has
  `CREATE`, `DROP`, `INDEX`, `SELECT`, and `INSERT` permissions as needed.
- **Students or courses are missing:** run Experiment 1's `schema.sql` and
  `insert_data.sql` first.
- **`EXPLAIN ANALYZE` is unknown:** use MySQL 8.0.18 or newer. Plain `EXPLAIN`
  is available on earlier MySQL 8.0 releases, but this experiment records
  actual iterator timing and rows.
- **Duplicate index name:** rerun `generate_data.py` before `indexes.sql`; the
  generator rebuilds only the performance table and clears its indexes.
- **Indexes are not selected in `EXPLAIN`:** check `ANALYZE TABLE` completed.
  The optimizer may still prefer a scan when the predicate returns many rows;
  compare its natural plan with the explicitly forced benchmark path.
- **CSV output path is not writable:** pass a writable path to `--output`.
- **Hash lookup returns zero rows:** confirm the source email is unchanged
  and that both Python and SQL normalize it with trim/lowercase before SHA-256.

## Screenshot checklist

- Generator completion showing row count and foreign-key consistency audit.
- Before-index `EXPLAIN` / `EXPLAIN ANALYZE` plans.
- `indexes.sql` verification output for the three B-tree indexes.
- After-index plans and the email hash lookup result.
- Benchmark comparison output and the generated CSV opened in a spreadsheet.

## Viva questions and answers

1. **What is an index?** A data structure that helps MySQL find rows without
   scanning the entire table.
2. **What index type does InnoDB use here?** B-tree.
3. **What does `EXPLAIN` show?** The optimizer's estimated plan and access
   choices for a statement.
4. **What does `EXPLAIN ANALYZE` add?** It runs a `SELECT` and reports actual
   iterator timing, rows, and loops alongside the plan.
5. **Why compare rows examined as well as elapsed time?** Fewer rows read can
   explain an access-path change, while timings are noisy and hardware
   dependent.
6. **Why is an equality lookup on `Student_ID` suitable for an index?** It can
   locate matching records by key rather than examining every row.
7. **When might MySQL ignore an index?** When a query returns many rows or the
   optimizer estimates a table scan is cheaper.
8. **What is SHA-256 used for in this experiment?** It creates a fixed-length
   digest of a normalized email for equality lookup.
9. **Why index the digest column instead of applying SHA-256 in the predicate
   to every row?** A stored, indexed digest can be compared directly without
   computing the digest for every candidate row at query time.
10. **What is the cost of adding indexes?** Additional storage and more work
    for writes that maintain each index.

## Observations

The before plans and indexed plans show how the optimizer's access path changes
for the same predicates. The benchmark records repeated warm-cache client
timings as well as plan row estimates and actual table-access iterator rows.
The explicit index hints make path-to-path measurements comparable; the
unhinted `EXPLAIN` output shows the optimizer's natural choice.

## Conclusion

This experiment generates a repeatable 50,000-row workload, checks that its
student and course references are valid, compares unindexed and B-tree lookup
paths, and exports measured results without assuming or fabricating a speedup.

## MySQL references

- [MySQL 8.0 `CREATE INDEX` statement](https://dev.mysql.com/doc/refman/8.0/en/create-index.html)
- [MySQL 8.0 `EXPLAIN ANALYZE`](https://dev.mysql.com/doc/refman/8.0/en/explain.html)
- [MySQL 8.0 InnoDB foreign-key index requirements](https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html)
