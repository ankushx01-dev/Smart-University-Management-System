# Smart University Management System (SUMS)

An industry-based academic project for demonstrating relational, advanced,
performance, transaction, NoSQL, graph, and distributed database concepts.

## Technology stack

- Python 3.11+
- MySQL 8.0+
- Redis, MongoDB, Apache Cassandra, and Neo4j
- VS Code is the recommended editor

## Project setup

From the project root, create and activate a virtual environment, then install
the Python dependencies:

```powershell
py -3.11 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

On macOS or Linux, activate the environment with
`source .venv/bin/activate` after creating it with `python3.11 -m venv .venv`.

Copy `.env.example` to `.env` and set connection values for the databases you
run locally. Keep `.env` private; it is excluded by `.gitignore`. Database
services must be installed and running before their corresponding experiments
can connect.

The shared MySQL connection helper is in `database/connection.py`. Import
`get_mysql_connection()` from that module after installing the dependencies and
configuring `.env`.

## Experiments

1. `experiment_01_relational_sql/` — relational SQL
2. `experiment_02_advanced_mysql/` — advanced MySQL
3. `experiment_03_performance/` — query performance
4. `experiment_04_transactions/` — transaction management
5. `experiment_05_redis_mongodb/` — Redis and MongoDB
6. `experiment_06_cassandra_neo4j/` — Cassandra and Neo4j
7. `experiment_07_distributed/` — distributed database concepts

Experiment implementation files are placeholders at this stage. Each
experiment README will contain its exact setup, execution commands, expected
outputs, troubleshooting notes, screenshot checklist, viva questions, and
observations when that experiment is implemented.

## Data and credentials

Use synthetic data only. Relational experiments should use 10–20 records per
table unless a performance experiment explicitly generates a larger synthetic
dataset. Store credentials in environment variables defined through `.env`;
never commit secrets.
