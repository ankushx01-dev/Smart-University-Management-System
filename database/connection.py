"""Shared MySQL connection helper for SUMS."""

import os
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import MySQLConnection


PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")


def get_mysql_connection() -> MySQLConnection:
    """Open a MySQL connection using values from the environment.

    MYSQL_USER, MYSQL_PASSWORD, and MYSQL_DATABASE must be set in the process
    environment or in the project-root `.env` file. Host and port have local
    development defaults; no credentials are embedded in this module.
    """
    required_names = ("MYSQL_USER", "MYSQL_PASSWORD", "MYSQL_DATABASE")
    missing = [name for name in required_names if not os.getenv(name)]
    if missing:
        names = ", ".join(missing)
        raise RuntimeError(
            f"Missing required MySQL environment variable(s): {names}. "
            f"Copy .env.example to .env and fill in the values."
        )

    try:
        port = int(os.getenv("MYSQL_PORT", "3306"))
    except ValueError as exc:
        raise RuntimeError("MYSQL_PORT must be an integer.") from exc

    return mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=port,
        database=os.environ["MYSQL_DATABASE"],
        user=os.environ["MYSQL_USER"],
        password=os.environ["MYSQL_PASSWORD"],
        connection_timeout=10,
        autocommit=False,
    )
