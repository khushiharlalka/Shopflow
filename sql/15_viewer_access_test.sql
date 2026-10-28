-- =====================================================================
-- FILE      : 15_viewer_access_test.sql
-- PURPOSE   : (Report Ch. 10.6 / 7.11) Shows PERMITTED and DENIED operations
--             for the read-only test account.
-- RUN AS    : the "Viewer" connection (shopflow_viewer / Viewer_2026).  F5.
--             Run it twice: once after file 14 (GRANT), once after file 16 (REVOKE).
-- =====================================================================
SHOW USER

-- PERMITTED (after GRANT): read products
SELECT Product_ID, Product_Name, Unit_Price, Stock_Quantity
FROM   SHOPFLOW.PRODUCT
WHERE  Product_ID <= 1005
ORDER  BY Product_ID;
-- After file 16 (REVOKE) this same query fails:
--   ORA-00942: table or view does not exist

-- PERMITTED: read the stock view
SELECT Product_ID, Product_Name, Stock_Quantity, Stock_Status
FROM   SHOPFLOW.VW_PRODUCT_STOCK_STATUS
WHERE  Stock_Status <> 'IN STOCK'
ORDER  BY Product_ID;

-- DENIED: change data -> ORA-01031: insufficient privileges
UPDATE SHOPFLOW.PRODUCT SET Unit_Price = 1 WHERE Product_ID = 1001;
DELETE FROM SHOPFLOW.PRODUCT WHERE Product_ID = 1001;

-- DENIED: a table that was never granted -> ORA-00942: table or view does not exist
-- (Oracle does not even reveal that the table exists)
SELECT * FROM SHOPFLOW.CUSTOMER;

ROLLBACK;
