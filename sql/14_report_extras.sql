-- =====================================================================
-- FILE      : 14_report_extras.sql
-- PURPOSE   : Extra demonstrations the report format asks for that are not
--             part of the core application:
--               1  DDL: CREATE / ALTER / TRUNCATE / DROP        (Ch 7.1)
--               2  DISTINCT                                    (Ch 7.3)
--               3  RIGHT, CROSS and SELF JOIN                  (Ch 7.6)
--               4  Multiple-row subqueries: IN, ALL            (Ch 7.7)
--               5  View update limitation                      (Ch 7.9)
--               6  Least privilege + DBMS version              (Ch 10.1, 2.4)
--               7  Indexes and EXPLAIN PLAN, before/after      (Ch 9.2 - 9.5)
--               8  Execution plan of a real project query      (Ch 9.3)
--               9  GRANT to the test account                   (Ch 7.11)
-- RUN AS    : SHOPFLOW connection.  Run file 13 (admin) first.
--             Press F5. Every section prints its own result; nothing here
--             changes the 8 project tables (practice tables are dropped).
-- =====================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 200

-- Remove practice tables left by an earlier run (safe to re-run this file)
BEGIN
    FOR t IN (SELECT table_name FROM USER_TABLES
              WHERE table_name IN ('DEMO_FEEDBACK', 'PERF_DEMO')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/

-- =====================================================================
-- 1. DDL on a practice table: CREATE, ALTER (ADD / MODIFY / RENAME),
--    TRUNCATE, DROP.  (The 8 real tables are not touched.)
-- =====================================================================
CREATE TABLE DEMO_FEEDBACK (
    Feedback_ID  NUMBER        CONSTRAINT PK_DEMO_FEEDBACK PRIMARY KEY,
    Customer_ID  NUMBER        CONSTRAINT FK_DEMO_FB_CUSTOMER REFERENCES CUSTOMER (Customer_ID),
    Rating       NUMBER(1)     CONSTRAINT CK_DEMO_FB_RATING CHECK (Rating BETWEEN 1 AND 5),
    Comments     VARCHAR2(200)
);
ALTER TABLE DEMO_FEEDBACK ADD (Feedback_Date DATE DEFAULT SYSDATE);       -- add a column
ALTER TABLE DEMO_FEEDBACK MODIFY (Comments VARCHAR2(500));                 -- widen a column
ALTER TABLE DEMO_FEEDBACK RENAME COLUMN Comments TO Feedback_Text;         -- rename a column
DESC DEMO_FEEDBACK
INSERT INTO DEMO_FEEDBACK (Feedback_ID, Customer_ID, Rating, Feedback_Text) VALUES (1, 101, 5, 'Fast delivery');
INSERT INTO DEMO_FEEDBACK (Feedback_ID, Customer_ID, Rating, Feedback_Text) VALUES (2, 102, 4, 'Good quality saree');
INSERT INTO DEMO_FEEDBACK (Feedback_ID, Customer_ID, Rating, Feedback_Text) VALUES (3, 103, 3, 'Packing could be better');
COMMIT;
SELECT * FROM DEMO_FEEDBACK ORDER BY Feedback_ID;                          -- 3 rows
TRUNCATE TABLE DEMO_FEEDBACK;                                               -- removes all rows, keeps the table
SELECT COUNT(*) AS Rows_After_Truncate FROM DEMO_FEEDBACK;                  -- 0
DROP TABLE DEMO_FEEDBACK PURGE;                                             -- removes the table itself

-- =====================================================================
-- 2. DISTINCT
-- =====================================================================
-- Cities our customers live in, each once -> 11 cities (Kolkata has 2 customers)
SELECT DISTINCT City FROM CUSTOMER ORDER BY City;
-- Payment methods actually used -> 5 rows
SELECT DISTINCT Payment_Method FROM PAYMENT ORDER BY Payment_Method;

-- =====================================================================
-- 3. RIGHT JOIN, CROSS JOIN, SELF JOIN
-- =====================================================================
-- RIGHT JOIN: every product, with its order lines if any.
-- Products with no order line show NULL -> here we keep only those: 1011, 1012
SELECT p.Product_ID, p.Product_Name, oi.Order_ID
FROM   ORDER_ITEM oi
       RIGHT JOIN PRODUCT p ON p.Product_ID = oi.Product_ID
WHERE  oi.Order_ID IS NULL
ORDER  BY p.Product_ID;

-- CROSS JOIN: every combination of the first 2 categories and the 5 payment
-- methods (a blank sales matrix for a manager's report) -> 2 x 5 = 10 rows
SELECT c.Category_Name, m.Payment_Method
FROM   CATEGORY c
       CROSS JOIN (SELECT DISTINCT Payment_Method FROM PAYMENT) m
WHERE  c.Category_ID <= 2
ORDER  BY c.Category_Name, m.Payment_Method;

-- SELF JOIN: pairs of different customers who live in the same city
-- -> 1 row: Rohan Das and Ishita Banerjee, Kolkata
SELECT a.First_Name || ' ' || a.Last_Name AS Customer_1,
       b.First_Name || ' ' || b.Last_Name AS Customer_2,
       a.City
FROM   CUSTOMER a
       JOIN CUSTOMER b ON a.City = b.City AND a.Customer_ID < b.Customer_ID;

-- SELF JOIN 2: for each product, the cheaper products in the same category
SELECT p1.Product_Name AS Product, p1.Unit_Price,
       p2.Product_Name AS Cheaper_In_Same_Category, p2.Unit_Price AS Cheaper_Price
FROM   PRODUCT p1
       JOIN PRODUCT p2 ON p1.Category_ID = p2.Category_ID AND p2.Unit_Price < p1.Unit_Price
WHERE  p1.Category_ID = 1
ORDER  BY p1.Unit_Price DESC, p2.Unit_Price DESC;

-- =====================================================================
-- 4. Multiple-row subqueries (IN, ALL)
-- =====================================================================
-- IN: customers who bought at least one Electronics product -> 101, 103, 104, 111
SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer
FROM   CUSTOMER c
WHERE  c.Customer_ID IN (SELECT co.Customer_ID
                         FROM   CUSTOMER_ORDER co
                                JOIN ORDER_ITEM oi ON oi.Order_ID   = co.Order_ID
                                JOIN PRODUCT    p  ON p.Product_ID  = oi.Product_ID
                         WHERE  p.Category_ID = 1)
ORDER  BY c.Customer_ID;

-- ALL: products costlier than EVERY book (books cost 950 and 649) -> 9 rows
SELECT Product_ID, Product_Name, Unit_Price
FROM   PRODUCT
WHERE  Unit_Price > ALL (SELECT Unit_Price FROM PRODUCT WHERE Category_ID = 4)
ORDER  BY Unit_Price DESC;

-- =====================================================================
-- 5. View update limitation
-- VW_ORDER_SUMMARY uses GROUP BY and SUM, so one view row is built from many
-- table rows. Oracle cannot know which base row to change.
-- EXPECTED: ERROR  ORA-01732: data manipulation operation not legal on this view
-- =====================================================================
UPDATE VW_ORDER_SUMMARY SET Order_Status = 'SHIPPED' WHERE Order_ID = 5005;
ROLLBACK;

-- =====================================================================
-- 6. Least privilege and DBMS version
-- =====================================================================
-- System privileges SHOPFLOW holds -> exactly the 6 granted in file 01, no DBA
SELECT privilege FROM USER_SYS_PRIVS ORDER BY privilege;
-- Oracle version actually used (for the hardware/software chapter)
SELECT * FROM PRODUCT_COMPONENT_VERSION;

-- =====================================================================
-- 7. Indexes and query optimization: BEFORE vs AFTER an index
-- The project tables are tiny (10-30 rows), and on tiny tables Oracle
-- correctly prefers a full scan. So a practice table PERF_DEMO with
-- 200,000 rows is generated to show a measurable difference.
-- =====================================================================
CREATE TABLE PERF_DEMO AS
SELECT LEVEL                                    AS Row_ID,
       MOD(LEVEL, 5000) + 1                     AS Customer_Ref,
       ROUND(DBMS_RANDOM.VALUE(100, 20000), 2)  AS Amount,
       DATE '2026-01-01' + MOD(LEVEL, 300)      AS Txn_Date
FROM   DUAL
CONNECT BY LEVEL <= 200000;

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PERF_DEMO')
SELECT COUNT(*) AS Total_Rows FROM PERF_DEMO;                      -- 200000

SET TIMING ON

-- BEFORE: no index on Customer_Ref -> plan shows TABLE ACCESS FULL
EXPLAIN PLAN FOR
SELECT * FROM PERF_DEMO WHERE Customer_Ref = 1234;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT COUNT(*) AS Matching_Rows, SUM(Amount) AS Total_Amount
FROM   PERF_DEMO WHERE Customer_Ref = 1234;                          -- 40 rows; note "Elapsed"

-- OPTIMIZATION: add a B-tree index on the searched column
CREATE INDEX IDX_PERF_CUSTOMER_REF ON PERF_DEMO (Customer_Ref);

-- AFTER: plan shows INDEX RANGE SCAN on IDX_PERF_CUSTOMER_REF, much lower cost
EXPLAIN PLAN FOR
SELECT * FROM PERF_DEMO WHERE Customer_Ref = 1234;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT COUNT(*) AS Matching_Rows, SUM(Amount) AS Total_Amount
FROM   PERF_DEMO WHERE Customer_Ref = 1234;                          -- same answer; note "Elapsed"

-- COMPOSITE index example: one index on two columns, used when both are searched
CREATE INDEX IDX_PERF_CUST_DATE ON PERF_DEMO (Customer_Ref, Txn_Date);
EXPLAIN PLAN FOR
SELECT * FROM PERF_DEMO
WHERE  Customer_Ref = 1234 AND Txn_Date = DATE '2026-01-01' + 233;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SET TIMING OFF
DROP TABLE PERF_DEMO PURGE;                                         -- practice table removed

-- =====================================================================
-- 8. Execution plan of a real project query (join + group by)
-- =====================================================================
EXPLAIN PLAN FOR
SELECT co.Order_ID, c.First_Name, SUM(oi.Item_Subtotal) AS Order_Value
FROM   CUSTOMER_ORDER co
       JOIN CUSTOMER   c  ON c.Customer_ID = co.Customer_ID
       JOIN ORDER_ITEM oi ON oi.Order_ID   = co.Order_ID
WHERE  co.Customer_ID = 103
GROUP  BY co.Order_ID, c.First_Name;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Shows the join method (NESTED LOOPS / HASH JOIN), the PK_CUSTOMER unique
-- scan, and the access paths Oracle chose for the small project tables.

-- =====================================================================
-- 9. GRANT read-only access to the test account (DCL)
-- =====================================================================
GRANT SELECT ON PRODUCT TO shopflow_viewer;
GRANT SELECT ON VW_PRODUCT_STOCK_STATUS TO shopflow_viewer;
SELECT grantee, table_name, privilege FROM USER_TAB_PRIVS_MADE ORDER BY table_name;
-- Next: open the "Viewer" connection and run file 15.
