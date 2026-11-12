-- Experiment 1: demonstrate least-privilege GRANT and REVOKE statements.
-- Run as a MySQL administrator after schema.sql and insert_data.sql.
-- RANDOM PASSWORD requires MySQL 8.0.18+; the server returns the generated
-- password once when it creates the account. Store it in a local secret store.

USE SUMS;

-- Create a dedicated local lab account without embedding a password in this file.
-- IF NOT EXISTS makes reruns safe; if the account already exists, use its
-- previously generated password or reset it separately as an administrator.
CREATE USER IF NOT EXISTS 'sums_lab_user'@'localhost'
    IDENTIFIED BY RANDOM PASSWORD;

-- Verify the account's current grant list before assigning database privileges.
SHOW GRANTS FOR 'sums_lab_user'@'localhost';

-- Grant only read and insert access to the SUMS database.
GRANT SELECT, INSERT ON SUMS.* TO 'sums_lab_user'@'localhost';

-- SHOW GRANTS and this SELECT verify that SELECT and INSERT were granted.
SHOW GRANTS FOR 'sums_lab_user'@'localhost';

SELECT
    PRIVILEGE_TYPE,
    IS_GRANTABLE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = 'SUMS'
  AND GRANTEE = '''sums_lab_user''@''localhost'''
ORDER BY PRIVILEGE_TYPE;

SELECT COUNT(*) AS Select_And_Insert_Grants_Before_Revoke
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = 'SUMS'
  AND GRANTEE = '''sums_lab_user''@''localhost'''
  AND PRIVILEGE_TYPE IN ('SELECT', 'INSERT');

-- Revoke INSERT while retaining SELECT access.
REVOKE INSERT ON SUMS.* FROM 'sums_lab_user'@'localhost';

-- Verify that SELECT remains and INSERT has been removed.
SHOW GRANTS FOR 'sums_lab_user'@'localhost';

SELECT COUNT(*) AS Select_Grants_Remaining
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = 'SUMS'
  AND GRANTEE = '''sums_lab_user''@''localhost'''
  AND PRIVILEGE_TYPE = 'SELECT';

SELECT COUNT(*) AS Insert_Grants_Remaining
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = 'SUMS'
  AND GRANTEE = '''sums_lab_user''@''localhost'''
  AND PRIVILEGE_TYPE = 'INSERT';
