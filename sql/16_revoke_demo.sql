-- =====================================================================
-- FILE      : 16_revoke_demo.sql
-- PURPOSE   : (Report Ch. 7.11) Takes back the table privilege.
-- RUN AS    : SHOPFLOW connection.  F5.  Then run file 15 again as Viewer.
-- =====================================================================
REVOKE SELECT ON PRODUCT FROM shopflow_viewer;

-- Only the view privilege is left
SELECT grantee, table_name, privilege FROM USER_TAB_PRIVS_MADE ORDER BY table_name;

-- Now, as Viewer, file 15 shows:
--   SELECT ... FROM SHOPFLOW.PRODUCT                  -> ORA-00942 (access removed)
--   SELECT ... FROM SHOPFLOW.VW_PRODUCT_STOCK_STATUS  -> still works
-- This shows privileges are granted per object: the view can be shared
-- while the base table stays hidden.
