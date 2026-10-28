-- =====================================================================
-- FILE      : 01_user_setup.sql
-- PROJECT   : ShopFlow E-Commerce Order, Inventory and Returns Management System
-- STUDENT   : Khushi Harlalka (25BDE0151) | BACSE202 Database Systems | L49+L50
-- PURPOSE   : OPTIONAL. Creates a separate SHOPFLOW database user.
--
-- !!! IMPORTANT !!!
--  * These commands need ADMINISTRATOR privileges (connect as SYSTEM or
--    another admin account).
--  * Do NOT run this from a normal student account unless your lab
--    administrator has given you permission.
--  * If your lab already gave you a username, SKIP this file and run the
--    other scripts in your own account.
--  * We grant only the privileges the project needs. We do NOT grant DBA.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 0 (Oracle 12c and later, multitenant only)
-- In 12c+ the database has a root container (CDB$ROOT) and pluggable
-- databases (PDBs). Normal users must be created inside a PDB.
-- Common PDB names: XEPDB1 (Oracle XE 18c/21c), FREEPDB1 (Oracle 23ai Free),
-- ORCLPDB / ORCLPDB1 (Enterprise default). Check yours with:
--     SELECT name FROM v$pdbs;
-- Then switch (remove the -- below and put your PDB name):
-- ALTER SESSION SET CONTAINER = XEPDB1;
-- ---------------------------------------------------------------------

-- STEP 1: Create the user. Replace ShopFlow_2026 with your own password.
CREATE USER shopflow IDENTIFIED BY ShopFlow_2026
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp
    QUOTA 100M ON users;

-- STEP 2: Grant only what the project needs.
GRANT CREATE SESSION   TO shopflow;   -- allows login
GRANT CREATE TABLE     TO shopflow;   -- tables and indexes on own tables
GRANT CREATE VIEW      TO shopflow;   -- views
GRANT CREATE SEQUENCE  TO shopflow;   -- sequences for automatic IDs
GRANT CREATE PROCEDURE TO shopflow;   -- procedures and functions
GRANT CREATE TRIGGER   TO shopflow;   -- triggers

-- STEP 3: (Only if the quota above was not enough or was removed)
-- ALTER USER shopflow QUOTA 100M ON users;

-- STEP 4: Verify (run as admin)
SELECT username, default_tablespace, account_status
FROM   dba_users
WHERE  username = 'SHOPFLOW';

SELECT privilege FROM dba_sys_privs WHERE grantee = 'SHOPFLOW' ORDER BY privilege;

-- Now create a new connection in SQL Developer with:
--   Username : shopflow
--   Password : ShopFlow_2026 (or the one you chose)
--   Service  : your PDB name (for example XEPDB1 or FREEPDB1)
-- and run files 02 to 11 (or file 12 alone) from that connection.
