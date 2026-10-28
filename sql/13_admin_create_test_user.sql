-- =====================================================================
-- FILE      : 13_admin_create_test_user.sql
-- PURPOSE   : (Report Ch. 7.11 / 10.6) Creates a second, read-only test
--             account so GRANT and REVOKE can be demonstrated.
-- RUN AS    : the ADMIN connection (SYSTEM), same service as SHOPFLOW
--             (XEPDB1 on Windows XE, FREEPDB1 on Mac/Docker).  Press F5.
-- =====================================================================

-- The viewer can only log in. It gets table access later, from SHOPFLOW,
-- through GRANT (file 14) and loses it through REVOKE (file 16).
CREATE USER shopflow_viewer IDENTIFIED BY Viewer_2026;
GRANT CREATE SESSION TO shopflow_viewer;

SELECT username, account_status, created FROM dba_users WHERE username = 'SHOPFLOW_VIEWER';

-- Expected:  User SHOPFLOW_VIEWER created.  Grant succeeded.  1 row (OPEN).
-- If it says ORA-01920 (user already exists) that is fine - it was made earlier.
-- Next: make a SQL Developer connection "Viewer" with
--       username shopflow_viewer / password Viewer_2026 / same host, port, service.
