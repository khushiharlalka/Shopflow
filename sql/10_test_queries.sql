-- =====================================================================
-- FILE      : 10_test_queries.sql
-- PURPOSE   : Report queries, SQL functions, DML and data-dictionary
--             checks on the sample data of file 09.
-- HOW       : Run in SQL Developer with Run Script (F5), or one query at a
--             time with Run Statement (Ctrl+Enter).
--             Each query has a comment: what it does + EXPECTED output
--             (expected values assume fresh sample data from file 09).
--             The DML section ends with ROLLBACK, so data stays unchanged.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
SET LINESIZE 220
SET PAGESIZE 100

-- =====================================================================
-- A. BASIC SELECT QUERIES
-- =====================================================================
-- A1. All customers -> 12 rows (101-112)
SELECT * FROM CUSTOMER ORDER BY Customer_ID;
-- A2. All categories -> 10 rows
SELECT * FROM CATEGORY ORDER BY Category_ID;
-- A3. All products (Stock_Status is calculated) -> 20 rows
SELECT * FROM PRODUCT ORDER BY Product_ID;
-- A4. All orders -> 15 rows (5001-5015)
SELECT * FROM CUSTOMER_ORDER ORDER BY Order_ID;
-- A5. All order items (Item_Subtotal is calculated) -> 28 rows
SELECT * FROM ORDER_ITEM ORDER BY Order_ID, Product_ID;
-- A6. All payments -> 14 rows (9001-9014); the two COD payments have NULL reference
SELECT * FROM PAYMENT ORDER BY Payment_ID;
-- A7. All return requests -> 10 rows (7001-7010)
SELECT * FROM RETURN_REQUEST ORDER BY Return_ID;
-- A8. All phone numbers -> 16 rows
SELECT * FROM CUSTOMER_PHONE ORDER BY Customer_ID, Phone_Number;

-- =====================================================================
-- B. FILTERING AND SORTING
-- =====================================================================
-- B1. Active products -> 18 rows (1011 DISCONTINUED and 1012 INACTIVE are excluded)
SELECT Product_ID, Product_Name, Unit_Price, Product_Status
FROM   PRODUCT
WHERE  Product_Status = 'ACTIVE'
ORDER  BY Product_ID;

-- B2. Products priced above 2000 -> 5 rows: 1006, 1005, 1012, 1020, 1002
SELECT Product_ID, Product_Name, Unit_Price
FROM   PRODUCT
WHERE  Unit_Price > 2000
ORDER  BY Unit_Price;

-- B3. Products cheapest first -> 1019 (120) first, 1002 (15999) last
SELECT Product_ID, Product_Name, Unit_Price FROM PRODUCT ORDER BY Unit_Price ASC;

-- B4. Products costliest first -> 1002 (15999) first
SELECT Product_ID, Product_Name, Unit_Price FROM PRODUCT ORDER BY Unit_Price DESC;

-- B5. Orders between 01-Jul-2026 and 31-Aug-2026 -> 8 rows: 5003, 5010, 5011, 5004, 5005, 5012, 5006, 5013
SELECT Order_ID, Customer_ID, Order_Date, Order_Status
FROM   CUSTOMER_ORDER
WHERE  Order_Date BETWEEN TO_DATE('01-07-2026', 'DD-MM-YYYY') AND TO_DATE('31-08-2026', 'DD-MM-YYYY')
ORDER  BY Order_Date;

-- B6. Delivered orders -> 9 rows: 5001, 5002, 5004, 5008-5013
SELECT Order_ID, Customer_ID, Order_Date FROM CUSTOMER_ORDER WHERE Order_Status = 'DELIVERED' ORDER BY Order_ID;

-- B7. Pending payments -> 1 row: 9005 (order 5005, WALLET, 5495)
SELECT Payment_ID, Order_ID, Payment_Method, Payment_Amount FROM PAYMENT WHERE Payment_Status = 'PENDING';

-- B8. Approved return requests -> 3 rows: 7001, 7008, 7010
SELECT Return_ID, Order_ID, Product_ID, Return_Quantity, Refund_Amount
FROM   RETURN_REQUEST
WHERE  Return_Status = 'APPROVED';

-- =====================================================================
-- C. JOINS
-- =====================================================================
-- C1. INNER JOIN: every order with the customer's full name -> 15 rows
SELECT co.Order_ID, c.First_Name || ' ' || c.Last_Name AS Customer_Name, co.Order_Date, co.Order_Status
FROM   CUSTOMER_ORDER co
       INNER JOIN CUSTOMER c ON c.Customer_ID = co.Customer_ID
ORDER  BY co.Order_ID;

-- C2. INNER JOIN: order items with product name, quantity, price, subtotal -> 28 rows
SELECT oi.Order_ID, p.Product_Name, oi.Quantity, oi.Unit_Price AS Selling_Price, oi.Item_Subtotal
FROM   ORDER_ITEM oi
       INNER JOIN PRODUCT p ON p.Product_ID = oi.Product_ID
ORDER  BY oi.Order_ID, p.Product_Name;

-- C3. INNER JOIN: products with their category names -> 20 rows
SELECT p.Product_ID, p.Product_Name, c.Category_Name
FROM   PRODUCT p
       INNER JOIN CATEGORY c ON c.Category_ID = p.Category_ID
ORDER  BY c.Category_Name, p.Product_ID;

-- C4. INNER JOIN: orders WITH payment details -> 14 rows (5006 is missing - it has no payment)
SELECT co.Order_ID, co.Order_Status, p.Payment_Method, p.Payment_Amount, p.Payment_Status
FROM   CUSTOMER_ORDER co
       INNER JOIN PAYMENT p ON p.Order_ID = co.Order_ID
ORDER  BY co.Order_ID;

-- C5. LEFT JOIN: ALL orders, payment shown if it exists -> 15 rows, 5006 has NULL payment columns
--     Why LEFT JOIN? An INNER JOIN keeps only rows that match in BOTH tables,
--     so an order without a payment would disappear. LEFT JOIN keeps every
--     row of the left table (CUSTOMER_ORDER) and fills NULL where there is
--     no matching payment.
SELECT co.Order_ID, co.Order_Status, p.Payment_ID, p.Payment_Method, p.Payment_Status
FROM   CUSTOMER_ORDER co
       LEFT JOIN PAYMENT p ON p.Order_ID = co.Order_ID
ORDER  BY co.Order_ID;

-- C6. LEFT JOIN used to FIND orders without payments -> 1 row: 5006
SELECT co.Order_ID, co.Order_Status
FROM   CUSTOMER_ORDER co
       LEFT JOIN PAYMENT p ON p.Order_ID = co.Order_ID
WHERE  p.Payment_ID IS NULL;

-- C7. Return requests with customer and product details -> 10 rows
SELECT r.Return_ID, c.First_Name || ' ' || c.Last_Name AS Customer_Name,
       p.Product_Name, r.Return_Quantity, r.Return_Status, r.Refund_Amount
FROM   RETURN_REQUEST r
       INNER JOIN CUSTOMER_ORDER co ON co.Order_ID   = r.Order_ID
       INNER JOIN CUSTOMER       c  ON c.Customer_ID = co.Customer_ID
       INNER JOIN PRODUCT        p  ON p.Product_ID  = r.Product_ID
ORDER  BY r.Return_ID;

-- C8. LEFT JOIN: customers and their orders -> 105 Vikram and 112 Pooja appear with NULL order
SELECT c.Customer_ID, c.First_Name, co.Order_ID
FROM   CUSTOMER c
       LEFT JOIN CUSTOMER_ORDER co ON co.Customer_ID = c.Customer_ID
ORDER  BY c.Customer_ID, co.Order_ID;

-- =====================================================================
-- D. AGGREGATE QUERIES (GROUP BY, HAVING)
-- =====================================================================
-- D1. Total customers -> 12
SELECT COUNT(*) AS Total_Customers FROM CUSTOMER;

-- D2. Total orders -> 15
SELECT COUNT(*) AS Total_Orders FROM CUSTOMER_ORDER;

-- D3. Orders per customer -> 101,102,103,106,110: 2 | 104,107,108,109,111: 1 | 105,112: 0
SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer_Name, COUNT(co.Order_ID) AS Orders_Placed
FROM   CUSTOMER c
       LEFT JOIN CUSTOMER_ORDER co ON co.Customer_ID = c.Customer_ID
GROUP  BY c.Customer_ID, c.First_Name, c.Last_Name
ORDER  BY c.Customer_ID;

-- D4. Total sales (cancelled orders excluded) -> 54257
SELECT SUM(oi.Item_Subtotal) AS Total_Sales
FROM   ORDER_ITEM oi
       JOIN CUSTOMER_ORDER co ON co.Order_ID = oi.Order_ID
WHERE  co.Order_Status <> 'CANCELLED';

-- D5. Total value of each order -> 5001:2698, 5002:4097, 5003:17797, 5004:2549, 5005:5495,
--     5006:2998, 5007:2398, 5008:1545, 5009:2698, 5010:1299, 5011:1796, 5012:6398,
--     5013:2449, 5014:639, 5015:1799
SELECT Order_ID, SUM(Quantity) AS Total_Qty, SUM(Item_Subtotal) AS Order_Value
FROM   ORDER_ITEM
GROUP  BY Order_ID
ORDER  BY Order_ID;

-- D6. Average, minimum and maximum product price -> 2135.1, 120, 15999
SELECT ROUND(AVG(Unit_Price), 2) AS Avg_Price,
       MIN(Unit_Price)           AS Min_Price,
       MAX(Unit_Price)           AS Max_Price
FROM   PRODUCT;

-- D7. Total quantity sold per product (cancelled orders excluded)
--     -> 1019:7, 1003:6, 1013:5, 1004/1009/1014:3, 1001/1015/1016/1018:2, others: 1
SELECT p.Product_ID, p.Product_Name, SUM(oi.Quantity) AS Qty_Sold
FROM   ORDER_ITEM oi
       JOIN PRODUCT        p  ON p.Product_ID = oi.Product_ID
       JOIN CUSTOMER_ORDER co ON co.Order_ID  = oi.Order_ID
WHERE  co.Order_Status <> 'CANCELLED'
GROUP  BY p.Product_ID, p.Product_Name
ORDER  BY Qty_Sold DESC, p.Product_ID;

-- D8. Category-wise product count -> Electronics 4, Fashion 3, Home & Kitchen 3,
--     Beauty 2, Books 2, Sports 2, Furniture/Grocery/Stationery/Toys 1 each
SELECT c.Category_Name, COUNT(p.Product_ID) AS Product_Count
FROM   CATEGORY c
       LEFT JOIN PRODUCT p ON p.Category_ID = c.Category_ID
GROUP  BY c.Category_Name
ORDER  BY c.Category_Name;

-- D9. Category-wise stock value (price x stock)
--     -> Electronics 280948, Home & Kitchen 73859, Fashion 69440, Sports & Fitness 38667,
--        Beauty 26463, Grocery 24662, Books 18097, Furniture 16497, Toys 11883, Stationery 11160
SELECT c.Category_Name, SUM(p.Unit_Price * p.Stock_Quantity) AS Stock_Value
FROM   CATEGORY c
       JOIN PRODUCT p ON p.Category_ID = c.Category_ID
GROUP  BY c.Category_Name
ORDER  BY Stock_Value DESC;

-- D10. Month-wise sales (cancelled excluded) -> 2026-06: 11038, 2026-07: 23441,
--      2026-08: 17340, 2026-09: 2438
SELECT TO_CHAR(co.Order_Date, 'YYYY-MM') AS Sales_Month,
       COUNT(DISTINCT co.Order_ID)       AS Orders,
       SUM(oi.Item_Subtotal)             AS Sales
FROM   CUSTOMER_ORDER co
       JOIN ORDER_ITEM oi ON oi.Order_ID = co.Order_ID
WHERE  co.Order_Status <> 'CANCELLED'
GROUP  BY TO_CHAR(co.Order_Date, 'YYYY-MM')
ORDER  BY Sales_Month;

-- D11. HAVING: categories with more than 2 products -> Electronics 4, Fashion 3, Home & Kitchen 3
SELECT c.Category_Name, COUNT(*) AS Product_Count
FROM   CATEGORY c
       JOIN PRODUCT p ON p.Category_ID = c.Category_ID
GROUP  BY c.Category_Name
HAVING COUNT(*) > 2
ORDER  BY Product_Count DESC;

-- D12. HAVING: orders worth more than 4000 -> 5002 (4097), 5003 (17797), 5005 (5495), 5012 (6398)
SELECT Order_ID, SUM(Item_Subtotal) AS Order_Value
FROM   ORDER_ITEM
GROUP  BY Order_ID
HAVING SUM(Item_Subtotal) > 4000
ORDER  BY Order_ID;

-- =====================================================================
-- E. SUBQUERIES
-- =====================================================================
-- E1. Products priced above the average price (2135.1) -> 1002, 1020, 1012, 1005, 1006
SELECT Product_ID, Product_Name, Unit_Price
FROM   PRODUCT
WHERE  Unit_Price > (SELECT AVG(Unit_Price) FROM PRODUCT)
ORDER  BY Unit_Price DESC;

-- E2. Customers who placed more orders than the average customer
--     (average = 15 orders / 12 customers = 1.25) -> 101, 102, 103, 106, 110
SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer_Name, COUNT(co.Order_ID) AS Orders_Placed
FROM   CUSTOMER c
       JOIN CUSTOMER_ORDER co ON co.Customer_ID = c.Customer_ID
GROUP  BY c.Customer_ID, c.First_Name, c.Last_Name
HAVING COUNT(co.Order_ID) > (SELECT COUNT(*) FROM CUSTOMER_ORDER) / (SELECT COUNT(*) FROM CUSTOMER)
ORDER  BY c.Customer_ID;

-- E3. Customer who placed the highest-value order -> Rohan Das, order 5003, 17797
SELECT co.Order_ID, c.First_Name || ' ' || c.Last_Name AS Customer_Name, SUM(oi.Item_Subtotal) AS Order_Value
FROM   CUSTOMER_ORDER co
       JOIN CUSTOMER   c  ON c.Customer_ID = co.Customer_ID
       JOIN ORDER_ITEM oi ON oi.Order_ID   = co.Order_ID
GROUP  BY co.Order_ID, c.First_Name, c.Last_Name
HAVING SUM(oi.Item_Subtotal) = (SELECT MAX(SUM(Item_Subtotal)) FROM ORDER_ITEM GROUP BY Order_ID);

-- E4. Products that were never ordered -> 1011, 1012
SELECT Product_ID, Product_Name
FROM   PRODUCT
WHERE  Product_ID NOT IN (SELECT Product_ID FROM ORDER_ITEM)
ORDER  BY Product_ID;

-- E5. Customers who never placed an order (correlated subquery) -> 105 Vikram Singh, 112 Pooja Joshi
SELECT c.Customer_ID, c.First_Name, c.Last_Name
FROM   CUSTOMER c
WHERE  NOT EXISTS (SELECT 1 FROM CUSTOMER_ORDER co WHERE co.Customer_ID = c.Customer_ID);

-- E6. Orders without payments -> 5006
SELECT Order_ID, Customer_ID, Order_Status
FROM   CUSTOMER_ORDER
WHERE  Order_ID NOT IN (SELECT Order_ID FROM PAYMENT);

-- =====================================================================
-- F. SET OPERATIONS (both SELECTs must return the same number and type of columns)
-- =====================================================================
-- F1. UNION (duplicates removed): all cities we deal with -> 12 rows:
--     Ahmedabad, Bengaluru, Chennai, Gurugram (a shipping-only city), Hyderabad, Jaipur,
--     Kochi, Kolkata, Lucknow, Mumbai, New Delhi, Pune
SELECT City AS City FROM CUSTOMER
UNION
SELECT Shipping_City FROM CUSTOMER_ORDER
ORDER  BY 1;

-- F2. UNION ALL (duplicates kept): product activity log -> 38 rows (28 ordered + 10 returned)
SELECT Product_ID, 'ORDERED' AS Activity FROM ORDER_ITEM
UNION ALL
SELECT Product_ID, 'RETURNED' FROM RETURN_REQUEST
ORDER  BY 1, 2;

-- F3. INTERSECT: customers who ordered AND also raised a return -> 101, 102, 106-111
SELECT Customer_ID FROM CUSTOMER_ORDER
INTERSECT
SELECT co.Customer_ID
FROM   RETURN_REQUEST r JOIN CUSTOMER_ORDER co ON co.Order_ID = r.Order_ID;

-- F4. MINUS: customers who never ordered -> 105, 112
SELECT Customer_ID FROM CUSTOMER
MINUS
SELECT Customer_ID FROM CUSTOMER_ORDER;

-- F5. MINUS: products never ordered -> 1011, 1012
SELECT Product_ID FROM PRODUCT
MINUS
SELECT Product_ID FROM ORDER_ITEM;

-- =====================================================================
-- G. STRING FUNCTIONS
-- =====================================================================
-- G1. UPPER, LOWER, INITCAP, SUBSTR, INSTR, LENGTH, CONCAT and ||  -> 12 rows
SELECT Customer_ID,
       UPPER(First_Name)                          AS Upper_First,      -- AARAV
       LOWER(Last_Name)                           AS Lower_Last,       -- sharma
       INITCAP(LOWER(Email))                      AS Initcap_Email,    -- Aarav.Sharma@Gmail.Com
       SUBSTR(Email, 1, INSTR(Email, '@') - 1)    AS Email_Username,   -- aarav.sharma
       LENGTH(Email)                              AS Email_Length,     -- 22
       CONCAT(First_Name, CONCAT(' ', Last_Name)) AS Full_Name_Concat, -- Aarav Sharma
       First_Name || ' ' || Last_Name             AS Full_Name_Pipes   -- Aarav Sharma
FROM   CUSTOMER
ORDER  BY Customer_ID;

-- G2. INITCAP on a lower-case string -> 'Banarasi Silk Saree'
SELECT INITCAP('banarasi silk saree') AS Initcap_Example FROM DUAL;

-- G3. First 10 characters of product names and their lengths -> 20 rows
SELECT Product_ID, SUBSTR(Product_Name, 1, 10) AS Short_Name, LENGTH(Product_Name) AS Name_Length
FROM   PRODUCT ORDER BY Product_ID;

-- =====================================================================
-- H. NUMBER FUNCTIONS
-- =====================================================================
-- H1. ROUND, CEIL, FLOOR (price with an illustrative 18% tax, and price per 100)
--     e.g. 1001: 1768.82, CEIL(14.99)=15, FLOOR(14.99)=14
SELECT Product_ID, Unit_Price,
       ROUND(Unit_Price * 1.18, 2) AS Price_With_18pct,
       ROUND(Unit_Price, -2)       AS Rounded_To_100,
       CEIL(Unit_Price / 100)      AS Ceil_Hundreds,
       FLOOR(Unit_Price / 100)     AS Floor_Hundreds
FROM   PRODUCT
ORDER  BY Product_ID;

-- H2. Direct examples -> 2699.08, 3, 2
SELECT ROUND(2699.0833, 2) AS Round_Ex, CEIL(2.1) AS Ceil_Ex, FLOOR(2.9) AS Floor_Ex FROM DUAL;

-- =====================================================================
-- I. DATE FUNCTIONS
-- =====================================================================
-- I1. Current date and time -> today's date
SELECT SYSDATE AS Today, TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS Today_Text FROM DUAL;

-- I2. ADD_MONTHS, EXTRACT, TRUNC, TO_CHAR on order dates -> 15 rows
--     e.g. 5001: one month later 10-07-2026, month 6, year 2026, month start 01-06-2026
SELECT Order_ID,
       TO_CHAR(Order_Date, 'DD-MM-YYYY')                AS Ordered_On,
       TO_CHAR(ADD_MONTHS(Order_Date, 1), 'DD-MM-YYYY') AS One_Month_Later,
       EXTRACT(MONTH FROM Order_Date)                   AS Order_Month,
       EXTRACT(YEAR  FROM Order_Date)                   AS Order_Year,
       TO_CHAR(TRUNC(Order_Date, 'MM'), 'DD-MM-YYYY')   AS Month_Start,
       TO_CHAR(Order_Date, 'Day')                       AS Week_Day
FROM   CUSTOMER_ORDER
ORDER  BY Order_ID;

-- I3. MONTHS_BETWEEN: how long each customer has been registered -> 12 rows (value depends on today)
SELECT Customer_ID, First_Name, Registration_Date,
       ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE), Registration_Date), 1) AS Months_Registered
FROM   CUSTOMER
ORDER  BY Customer_ID;

-- I4. TO_DATE in a condition -> orders on or after 1-Aug-2026: 5005, 5006, 5007, 5012-5015
SELECT Order_ID, Order_Date FROM CUSTOMER_ORDER
WHERE  Order_Date >= TO_DATE('01-08-2026', 'DD-MM-YYYY')
ORDER  BY Order_ID;

-- I5. Days between order date and return date -> 7001:10, 7002:10, 7003:11, 7004:8, 7005:10,
--     7006:7, 7007:7, 7008:9, 7009:8, 7010:12
SELECT r.Return_ID, r.Return_Date - co.Order_Date AS Days_After_Order
FROM   RETURN_REQUEST r JOIN CUSTOMER_ORDER co ON co.Order_ID = r.Order_ID
ORDER  BY r.Return_ID;

-- =====================================================================
-- J. CONDITIONAL LOGIC WITH CASE
-- =====================================================================
-- J1. Stock condition (written with CASE, same logic as the virtual column)
SELECT Product_ID, Product_Name, Stock_Quantity, Reorder_Level,
       CASE
           WHEN Stock_Quantity = 0              THEN 'Out of stock - reorder now'
           WHEN Stock_Quantity <= Reorder_Level THEN 'Low - reorder soon'
           ELSE 'Enough stock'
       END AS Stock_Condition
FROM   PRODUCT
ORDER  BY Product_ID;

-- J2. Order progress
SELECT Order_ID, Order_Status,
       CASE Order_Status
           WHEN 'PENDING'   THEN 'Step 1 of 4 - waiting for confirmation'
           WHEN 'CONFIRMED' THEN 'Step 2 of 4 - being packed'
           WHEN 'SHIPPED'   THEN 'Step 3 of 4 - on the way'
           WHEN 'DELIVERED' THEN 'Step 4 of 4 - completed'
           WHEN 'CANCELLED' THEN 'Stopped - order cancelled'
       END AS Order_Progress
FROM   CUSTOMER_ORDER
ORDER  BY Order_ID;

-- J3. Payment condition (LEFT JOIN so unpaid orders are shown too)
SELECT co.Order_ID,
       CASE
           WHEN p.Payment_ID IS NULL           THEN 'Not paid yet'
           WHEN p.Payment_Status = 'SUCCESS'   THEN 'Paid by ' || p.Payment_Method
           WHEN p.Payment_Status = 'PENDING'   THEN 'Payment awaiting confirmation'
           WHEN p.Payment_Status = 'FAILED'    THEN 'Payment failed'
           WHEN p.Payment_Status = 'REFUNDED'  THEN 'Money returned to customer'
       END AS Payment_Condition
FROM   CUSTOMER_ORDER co
       LEFT JOIN PAYMENT p ON p.Order_ID = co.Order_ID
ORDER  BY co.Order_ID;

-- J4. Return condition
SELECT Return_ID, Return_Status, Refund_Amount,
       CASE
           WHEN Return_Status IN ('REQUESTED', 'APPROVED', 'PICKED_UP') THEN 'In progress'
           WHEN Return_Status = 'REJECTED'                              THEN 'Closed - no refund'
           WHEN Return_Status IN ('COMPLETED', 'REFUNDED')              THEN 'Closed - refund ' || Refund_Amount
       END AS Return_Condition
FROM   RETURN_REQUEST
ORDER  BY Return_ID;

-- =====================================================================
-- K. VIEWS
-- =====================================================================
SELECT * FROM VW_PRODUCT_STOCK_STATUS ORDER BY Product_ID;         -- 20 rows
SELECT * FROM VW_ORDER_SUMMARY ORDER BY Order_ID;                  -- 15 rows, 5006 = NO PAYMENT
SELECT * FROM VW_CUSTOMER_ORDER_HISTORY ORDER BY Customer_ID, Order_ID, Product_ID;  -- 28 rows
SELECT * FROM VW_LOW_STOCK_PRODUCTS ORDER BY Product_ID;           -- 5 rows: 1003, 1006, 1010, 1011, 1020
SELECT * FROM VW_RETURN_DETAILS ORDER BY Return_ID;                -- 10 rows

-- =====================================================================
-- L. FUNCTIONS
-- =====================================================================
-- -> 2698, 0, 2
SELECT FN_ORDER_TOTAL(5001)          AS Total_5001,
       FN_AVAILABLE_STOCK(1003)      AS Stock_1003,
       FN_CUSTOMER_ORDER_COUNT(101)  AS Orders_101
FROM   DUAL;

-- Using a function per row -> each order with its total
SELECT Order_ID, Order_Status, FN_ORDER_TOTAL(Order_ID) AS Order_Total
FROM   CUSTOMER_ORDER ORDER BY Order_ID;

-- =====================================================================
-- L2. CURSOR PROCEDURES (results undone with ROLLBACK)
-- =====================================================================
-- PR_AUTO_RESTOCK walks an explicit cursor over low-stock ACTIVE products
-- -> 4 restocked: 1003 0->15, 1006 2->15, 1010 3->15, 1020 3->9
--    (1011 is DISCONTINUED, so the cursor skips it)
VARIABLE v_restocked NUMBER
EXEC PR_AUTO_RESTOCK(3, :v_restocked)
PRINT v_restocked
SELECT * FROM VW_LOW_STOCK_PRODUCTS;        -- only 1011 is left
ROLLBACK;

-- PR_PROCESS_APPROVED_REFUNDS walks a cursor over APPROVED returns
-- -> 3 refunds: 7001 1499, 7008 5499, 7010 799, total 7797
VARIABLE v_ref_count NUMBER
VARIABLE v_ref_total NUMBER
EXEC PR_PROCESS_APPROVED_REFUNDS(:v_ref_count, :v_ref_total)
PRINT v_ref_count
PRINT v_ref_total
ROLLBACK;

-- =====================================================================
-- M. DML EXAMPLES (INSERT, UPDATE, DELETE, MERGE) - all undone at the end
-- =====================================================================
SAVEPOINT sp_dml_demo;

-- M1. INSERT: a new category (ID generated by trigger) -> 1 row inserted, ID 11
INSERT INTO CATEGORY (Category_Name, Category_Description)
VALUES ('Pet Supplies', 'Pet food, toys and accessories');

-- M2. INSERT that FAILS: duplicate category name
--     -> ORA-00001: unique constraint (..UQ_CATEGORY_NAME) violated
INSERT INTO CATEGORY (Category_Name) VALUES ('Books');

-- M3. UPDATE: price rise for headphones 1499 -> 1599
UPDATE PRODUCT SET Unit_Price = 1599 WHERE Product_ID = 1001;
--     Historical price is safe: order 5001 still shows 1499 for product 1001
SELECT Order_ID, Product_ID, Unit_Price, Item_Subtotal FROM ORDER_ITEM WHERE Product_ID = 1001;
SELECT Product_ID, Unit_Price FROM PRODUCT WHERE Product_ID = 1001;   -- 1599

-- M4. UPDATE: restock running shoes 2 -> 12; Stock_Status changes LOW STOCK -> IN STOCK
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 10 WHERE Product_ID = 1006;
SELECT Product_ID, Stock_Quantity, Stock_Status FROM PRODUCT WHERE Product_ID = 1006;

-- M5. UPDATE that FAILS: negative stock -> ORA-02290: check constraint (..CK_PRODUCT_STOCK) violated
UPDATE PRODUCT SET Stock_Quantity = -5 WHERE Product_ID = 1004;

-- M6. DELETE: remove one of Aarav's two phone numbers -> 1 row deleted
DELETE FROM CUSTOMER_PHONE WHERE Customer_ID = 101 AND Phone_Number = '9123456780';

-- M7. DELETE that FAILS: customer 101 has orders
--     -> ORA-02292: integrity constraint (..FK_ORDER_CUSTOMER) violated - child record found
DELETE FROM CUSTOMER WHERE Customer_ID = 101;

-- M8. DELETE with ON DELETE CASCADE: customer 105 has no orders, so the
--     delete works and his phone number is removed automatically
DELETE FROM CUSTOMER WHERE Customer_ID = 105;
SELECT COUNT(*) AS Phones_Of_105 FROM CUSTOMER_PHONE WHERE Customer_ID = 105;  -- 0

-- M9. MERGE (update if exists, else insert): price list for products
MERGE INTO PRODUCT p
USING (SELECT 1004 AS Product_ID, 849 AS New_Price, 20 AS Add_Stock FROM DUAL
       UNION ALL
       SELECT 1010, 699, 25 FROM DUAL) s
ON (p.Product_ID = s.Product_ID)
WHEN MATCHED THEN
    UPDATE SET p.Unit_Price = s.New_Price,
               p.Stock_Quantity = p.Stock_Quantity + s.Add_Stock;
SELECT Product_ID, Unit_Price, Stock_Quantity, Stock_Status FROM PRODUCT WHERE Product_ID IN (1004, 1010);
-- -> 1004: 849, 67 | 1010: 699, 28, IN STOCK

-- M10. MERGE with both branches: category list
MERGE INTO CATEGORY c
USING (SELECT 'Garden and Outdoor' AS Category_Name, 'Plants, pots and garden tools' AS Category_Description FROM DUAL
       UNION ALL
       SELECT 'Books', 'Textbooks, guides and novels' FROM DUAL) s
ON (c.Category_Name = s.Category_Name)
WHEN MATCHED THEN
    UPDATE SET c.Category_Description = s.Category_Description
WHEN NOT MATCHED THEN
    INSERT (Category_Name, Category_Description) VALUES (s.Category_Name, s.Category_Description);
-- -> 'Books' description updated, 'Garden and Outdoor' inserted

SELECT * FROM CATEGORY ORDER BY Category_ID;

-- Undo every change of section M
ROLLBACK TO SAVEPOINT sp_dml_demo;
ROLLBACK;
SELECT COUNT(*) AS Categories_After_Rollback FROM CATEGORY;   -- back to 10
SELECT Product_ID, Unit_Price FROM PRODUCT WHERE Product_ID = 1001;  -- back to 1499

-- =====================================================================
-- N. SMALL TRANSACTION CONTROL EXAMPLE (full demo in file 11)
-- =====================================================================
SAVEPOINT sp_before_restock;
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 50 WHERE Product_ID = 1003;  -- charger 0 -> 50
SAVEPOINT sp_after_charger;
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 5  WHERE Product_ID = 1006;  -- shoes 2 -> 7
ROLLBACK TO SAVEPOINT sp_after_charger;     -- undo only the shoes change
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1003, 1006);  -- 1003: 50, 1006: 2
ROLLBACK;                                   -- undo everything since the last COMMIT
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1003, 1006);  -- 1003: 0, 1006: 2

-- =====================================================================
-- O. DATA DICTIONARY AND VERIFICATION COMMANDS
-- =====================================================================
DESC CUSTOMER;
DESC CUSTOMER_PHONE;
DESC CATEGORY;
DESC PRODUCT;
DESC CUSTOMER_ORDER;
DESC ORDER_ITEM;
DESC PAYMENT;
DESC RETURN_REQUEST;

-- O1. Tables -> 8 rows
SELECT table_name FROM USER_TABLES ORDER BY table_name;

-- O2. Columns with data types
SELECT table_name, column_name, data_type, data_length, data_precision, data_scale, nullable
FROM   USER_TAB_COLUMNS
WHERE  table_name IN ('CUSTOMER','CUSTOMER_PHONE','CATEGORY','PRODUCT',
                      'CUSTOMER_ORDER','ORDER_ITEM','PAYMENT','RETURN_REQUEST')
ORDER  BY table_name, column_id;

-- O3. Virtual columns -> PRODUCT.STOCK_STATUS and ORDER_ITEM.ITEM_SUBTOTAL
SELECT table_name, column_name, virtual_column
FROM   USER_TAB_COLS
WHERE  virtual_column = 'YES' AND hidden_column = 'NO';

-- O4. Constraints (P = primary key, U = unique, R = foreign key, C = check / not null)
SELECT table_name, constraint_name, constraint_type, r_constraint_name, delete_rule, status
FROM   USER_CONSTRAINTS
WHERE  table_name IN ('CUSTOMER','CUSTOMER_PHONE','CATEGORY','PRODUCT',
                      'CUSTOMER_ORDER','ORDER_ITEM','PAYMENT','RETURN_REQUEST')
ORDER  BY table_name, constraint_type, constraint_name;

-- O5. Columns of each key constraint (shows composite keys with position 1, 2)
SELECT cc.table_name, cc.constraint_name, c.constraint_type, cc.column_name, cc.position
FROM   USER_CONS_COLUMNS cc
       JOIN USER_CONSTRAINTS c ON c.constraint_name = cc.constraint_name
WHERE  c.constraint_type IN ('P', 'U', 'R')
ORDER  BY cc.table_name, cc.constraint_name, cc.position;

-- O6. Indexes (automatic PK/UQ indexes + the 5 created in file 05)
SELECT index_name, table_name, uniqueness FROM USER_INDEXES ORDER BY table_name, index_name;

-- O7. Sequences
SELECT sequence_name, min_value, increment_by, last_number, cache_size, cycle_flag
FROM   USER_SEQUENCES ORDER BY sequence_name;

-- O8. Triggers -> 9 rows, all ENABLED
SELECT trigger_name, table_name, trigger_type, triggering_event, status
FROM   USER_TRIGGERS ORDER BY table_name, trigger_name;

-- O9. Views -> 5 rows
SELECT view_name FROM USER_VIEWS ORDER BY view_name;

-- O10. All project objects and whether they compiled (VALID)
SELECT object_type, object_name, status
FROM   USER_OBJECTS
WHERE  object_type IN ('TABLE','VIEW','SEQUENCE','TRIGGER','FUNCTION','PROCEDURE','INDEX')
ORDER  BY object_type, object_name;

-- O11. Compilation errors -> no rows means everything compiled
SELECT name, type, line, position, text FROM USER_ERRORS ORDER BY name, sequence;

-- O12. SHOW ERRORS shows errors of the last compiled object, or of a named one:
SHOW ERRORS PROCEDURE PR_ADD_ORDER_ITEM
SHOW ERRORS TRIGGER TRG_ORDER_ITEM_STOCK
