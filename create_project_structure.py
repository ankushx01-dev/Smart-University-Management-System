"""Create the SUMS project scaffold without overwriting existing files.

Run from any directory with:
    python create_project_structure.py

The project root is the directory containing this script. Experiment files are
created as empty placeholders; shared project configuration is initialized.
"""

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent

PROJECT_FILES = {
    "README.md": """# Smart University Management System (SUMS)

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
.venv\\Scripts\\Activate.ps1
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
""",
    "requirements.txt": """# Python 3.11+
mysql-connector-python
python-dotenv
redis
pymongo
cassandra-driver
neo4j
""",
    ".env.example": """# MySQL 8.0+
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=sums
MYSQL_USER=
MYSQL_PASSWORD=

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=

# MongoDB
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DATABASE=sums

# Apache Cassandra
CASSANDRA_HOSTS=127.0.0.1
CASSANDRA_PORT=9042
CASSANDRA_KEYSPACE=sums

# Neo4j
NEO4J_URI=bolt://127.0.0.1:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=
NEO4J_DATABASE=neo4j
""",
    ".gitignore": """# Secrets and local environment
.env

# Python
.venv/
venv/
__pycache__/
*.py[cod]
*.egg-info/
.pytest_cache/

# Editor and operating system files
.vscode/
.idea/
.DS_Store
Thumbs.db
""",
    "database/connection.py": """\"\"\"Shared MySQL connection helper for SUMS.\"\"\"

import os
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import MySQLConnection


PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / \".env\")


def get_mysql_connection() -> MySQLConnection:
    \"\"\"Open a MySQL connection using values from the environment.

    MYSQL_USER, MYSQL_PASSWORD, and MYSQL_DATABASE must be set in the process
    environment or in the project-root `.env` file. Host and port have local
    development defaults; no credentials are embedded in this module.
    \"\"\"
    required_names = (\"MYSQL_USER\", \"MYSQL_PASSWORD\", \"MYSQL_DATABASE\")
    missing = [name for name in required_names if not os.getenv(name)]
    if missing:
        names = \", \".join(missing)
        raise RuntimeError(
            f\"Missing required MySQL environment variable(s): {names}. \"
            f\"Copy .env.example to .env and fill in the values.\"
        )

    try:
        port = int(os.getenv(\"MYSQL_PORT\", \"3306\"))
    except ValueError as exc:
        raise RuntimeError(\"MYSQL_PORT must be an integer.\") from exc

    return mysql.connector.connect(
        host=os.getenv(\"MYSQL_HOST\", \"127.0.0.1\"),
        port=port,
        database=os.environ[\"MYSQL_DATABASE\"],
        user=os.environ[\"MYSQL_USER\"],
        password=os.environ[\"MYSQL_PASSWORD\"],
        connection_timeout=10,
        autocommit=False,
    )
""",
}

EMPTY_FILES = """database/schema.sql
database/seed_data.sql
database/er_diagram.md
experiment_01_relational_sql/schema.sql
experiment_01_relational_sql/insert_data.sql
experiment_01_relational_sql/joins.sql
experiment_01_relational_sql/permissions.sql
experiment_01_relational_sql/transactions.sql
experiment_01_relational_sql/README.md
experiment_02_advanced_mysql/views.sql
experiment_02_advanced_mysql/triggers.sql
experiment_02_advanced_mysql/procedures.sql
experiment_02_advanced_mysql/functions.sql
experiment_02_advanced_mysql/cursors.sql
experiment_02_advanced_mysql/README.md
experiment_03_performance/generate_data.py
experiment_03_performance/indexes.sql
experiment_03_performance/hash_lookup.sql
experiment_03_performance/explain_before.sql
experiment_03_performance/explain_after.sql
experiment_03_performance/benchmark.py
experiment_03_performance/README.md
experiment_04_transactions/acid_demo.sql
experiment_04_transactions/locking_session_1.sql
experiment_04_transactions/locking_session_2.sql
experiment_04_transactions/deadlock_session_1.sql
experiment_04_transactions/deadlock_session_2.sql
experiment_04_transactions/mvcc_session_1.sql
experiment_04_transactions/mvcc_session_2.sql
experiment_04_transactions/README.md
experiment_05_redis_mongodb/redis_operations.py
experiment_05_redis_mongodb/mongodb_operations.py
experiment_05_redis_mongodb/redis_demo.py
experiment_05_redis_mongodb/README.md
experiment_06_cassandra_neo4j/cassandra_schema.cql
experiment_06_cassandra_neo4j/cassandra_operations.py
experiment_06_cassandra_neo4j/neo4j_operations.py
experiment_06_cassandra_neo4j/graph_queries.cypher
experiment_06_cassandra_neo4j/README.md
experiment_07_distributed/campus_sharding.py
experiment_07_distributed/replication.py
experiment_07_distributed/consistency_simulation.py
experiment_07_distributed/README.md
report/project_report.md
""".splitlines()

DIRECTORIES = (
    "database",
    "experiment_01_relational_sql",
    "experiment_02_advanced_mysql",
    "experiment_03_performance",
    "experiment_04_transactions",
    "experiment_05_redis_mongodb",
    "experiment_06_cassandra_neo4j",
    "experiment_07_distributed",
    "screenshots",
    "report",
)


def create_scaffold() -> None:
    """Create directories and files, preserving anything already present."""
    for relative_dir in DIRECTORIES:
        (PROJECT_ROOT / relative_dir).mkdir(parents=True, exist_ok=True)

    created = 0
    preserved = 0

    for relative_path, content in PROJECT_FILES.items():
        path = PROJECT_ROOT / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            preserved += 1
            continue
        path.write_text(content, encoding="utf-8", newline="\n")
        created += 1

    for relative_path in EMPTY_FILES:
        path = PROJECT_ROOT / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            preserved += 1
            continue
        path.touch()
        created += 1

    gitkeep = PROJECT_ROOT / "screenshots" / ".gitkeep"
    if not gitkeep.exists():
        gitkeep.touch()
        created += 1
    else:
        preserved += 1

    print(f"SUMS scaffold ready at: {PROJECT_ROOT}")
    print(f"Created {created} file(s); preserved {preserved} existing file(s).")
    print("Experiment implementation files are empty placeholders.")


if __name__ == "__main__":
    create_scaffold()
