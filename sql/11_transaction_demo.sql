-- =====================================================================
-- FILE      : 11_transaction_demo.sql
-- PURPOSE   : Part A - transaction demos (ROLLBACK, SAVEPOINT)
--             Part B - the 20 mandatory test cases (successful and failing)
--             Part C - COMMIT demo
-- HOW       : Run the WHOLE file with Run Script (F5) in SQL Developer, or
--             @11_transaction_demo.sql in SQL Plus. It uses bind variables
--             (VARIABLE / :name / PRINT), which work in script mode.
--             Statements marked "EXPECTED: ERROR" are supposed to fail -
--             the script continues after each error.
--             Parts A and B end with ROLLBACK, so the sample data is
--             restored. Part C COMMITs one extra order (re-run file 12, or
--             02 to 09, to reset the data afterwards).
-- Make sure Auto-Commit is OFF in SQL Developer
-- (Tools > Preferences > Database > Advanced > Autocommit unticked).
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- =====================================================================
-- PART A. TRANSACTION DEMOS
-- =====================================================================

-- A1. ALL-OR-NOTHING ORDER (business rule 22)
-- A PL/SQL block creates an order and adds two items. The second item asks
-- for 10 running shoes but only 2 exist, so it fails. The exception
-- handler rolls back to the savepoint: the order AND its first item
-- disappear, and the headphone stock goes back to 38.
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1001, 1006);   -- 38, 2

DECLARE
    v_order_id NUMBER;
BEGIN
    SAVEPOINT sp_before_order;
    PR_CREATE_ORDER(104, v_order_id);
    PR_ADD_ORDER_ITEM(v_order_id, 1001, 1);    -- works: stock 38 -> 37
    PR_ADD_ORDER_ITEM(v_order_id, 1006, 10);   -- fails: only 2 in stock
    PR_CONFIRM_ORDER(v_order_id);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Order ' || v_order_id || ' saved.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO sp_before_order;
        DBMS_OUTPUT.PUT_LINE('Order NOT saved - everything rolled back. Reason: ' || SQLERRM);
END;
/
-- EXPECTED output: "Order NOT saved ... ORA-20215: Insufficient stock for product 1006 ..."
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1001, 1006);   -- still 38, 2
-- Note: the order number used inside the block is NOT given back by the
-- sequence, so the next order gets the following number (a gap). Normal.

-- A2. SAVEPOINT and ROLLBACK TO SAVEPOINT with separate statements
VARIABLE v_demo_order NUMBER
EXEC PR_CREATE_ORDER(102, :v_demo_order)
PRINT v_demo_order
EXEC PR_ADD_ORDER_ITEM(:v_demo_order, 1004, 2)
SAVEPOINT sp_after_kurta;
EXEC PR_ADD_ORDER_ITEM(:v_demo_order, 1008, 1)
SELECT Order_ID, Product_ID, Quantity, Item_Subtotal FROM ORDER_ITEM WHERE Order_ID = :v_demo_order;  -- 2 rows
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1004, 1008);  -- 45, 8

ROLLBACK TO SAVEPOINT sp_after_kurta;     -- undo only the cooker
SELECT Order_ID, Product_ID, Quantity FROM ORDER_ITEM WHERE Order_ID = :v_demo_order;  -- 1 row (kurta)
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1004, 1008);  -- 45, 9

ROLLBACK;                                 -- undo the whole demo order
SELECT COUNT(*) AS Demo_Order_Rows FROM CUSTOMER_ORDER WHERE Order_ID = :v_demo_order;  -- 0
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1004, 1008);  -- 47, 9

-- A3. CONCURRENCY (explanation - try it with two SQL Developer sessions)
-- Session 1: EXEC PR_ADD_ORDER_ITEM(5006, 1002, 10)  -- locks product 1002, no COMMIT yet
-- Session 2: run the same for another PENDING order -> it WAITS (row lock)
-- Session 1: COMMIT;  -> session 2 continues, reads the reduced stock and
--            gets ORA-20215 if not enough is left. Stock never goes negative.
-- (Open the 2nd session with File > New > SQL Worksheet... "Unshared".)

-- =====================================================================
-- PART B. MANDATORY TEST CASES
-- =====================================================================
VARIABLE v_cust  NUMBER
VARIABLE v_prod  NUMBER
VARIABLE v_order NUMBER
VARIABLE v_empty NUMBER
VARIABLE v_pay   NUMBER
VARIABLE v_ret   NUMBER
VARIABLE v_t17   NUMBER

-- TEST 1: insert a valid customer -> 1 row; new ID (e.g. 113) printed
BEGIN
    INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code)
    VALUES ('Ananya', 'Gupta', 'ananya.gupta@gmail.com', '9 Civil Lines', 'Jaipur', 'Rajasthan', '302006')
    RETURNING Customer_ID INTO :v_cust;
END;
/
PRINT v_cust
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (:v_cust, '9829012345');

-- TEST 1b: register through the procedure (customer + first phone in one step)
VARIABLE v_cust2 NUMBER
EXEC PR_REGISTER_CUSTOMER('Meera', 'Nair', 'meera.nair@gmail.com', '5 Residency Road', 'Bengaluru', 'Karnataka', '560025', '9886012345', :v_cust2)
PRINT v_cust2
--   without a phone -> EXPECTED: ERROR ORA-20271: At least one phone number is required ...
EXEC PR_REGISTER_CUSTOMER('No', 'Phone', 'no.phone@gmail.com', NULL, 'Pune', 'Maharashtra', '411001', NULL, :v_cust2)

-- TEST 2: duplicate email (different case) -> EXPECTED: ERROR
--   ORA-00001: unique constraint (SHOPFLOW.UQ_CUSTOMER_EMAIL) violated
--   (the trigger turns the email to lower case first, so it matches)
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, City)
VALUES ('Aarav', 'S', 'AARAV.SHARMA@gmail.com', 'Mysuru');

-- TEST 3: insert a valid product -> 1 row; Stock_Status = IN STOCK
BEGIN
    INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
    VALUES (1, 'LED Desk Lamp', 'USB rechargeable LED desk lamp', 1299, 15, 5, 'ACTIVE')
    RETURNING Product_ID INTO :v_prod;
END;
/
PRINT v_prod
SELECT Product_ID, Product_Name, Stock_Quantity, Stock_Status FROM PRODUCT WHERE Product_ID = :v_prod;

-- TEST 4: product with a negative price -> EXPECTED: ERROR
--   ORA-02290: check constraint (SHOPFLOW.CK_PRODUCT_PRICE) violated
INSERT INTO PRODUCT (Category_ID, Product_Name, Unit_Price, Stock_Quantity, Reorder_Level)
VALUES (1, 'Faulty Price Item', -500, 10, 2);

-- TEST 5: create a valid order -> "Order N created (PENDING) ..."
EXEC PR_CREATE_ORDER(:v_cust, :v_order)
PRINT v_order

-- TEST 6: add valid order items -> lamp stock 15 -> 12, kurta 47 -> 45
EXEC PR_ADD_ORDER_ITEM(:v_order, :v_prod, 3)
EXEC PR_ADD_ORDER_ITEM(:v_order, 1004, 2)
SELECT Order_ID, Product_ID, Quantity, Unit_Price, Item_Subtotal FROM ORDER_ITEM WHERE Order_ID = :v_order;
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (:v_prod, 1004);

-- TEST 7: order more than available stock -> EXPECTED: ERROR (two ways)
--   via procedure: ORA-20215: Insufficient stock for product 1006. Available: 2, requested: 50.
EXEC PR_ADD_ORDER_ITEM(:v_order, 1006, 50)
--   via plain INSERT (trigger): ORA-20015: Insufficient stock for product 1002. Available: 14, requested: 100.
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (:v_order, 1002, 100);

-- TEST 16 (run here because items can change only while the order is PENDING):
-- update ordered quantity and check the stock difference
UPDATE ORDER_ITEM SET Quantity = 5 WHERE Order_ID = :v_order AND Product_ID = :v_prod;
SELECT Stock_Quantity AS Lamp_Stock FROM PRODUCT WHERE Product_ID = :v_prod;   -- 12 -> 10 (only 2 extra taken)
UPDATE ORDER_ITEM SET Quantity = 4 WHERE Order_ID = :v_order AND Product_ID = :v_prod;
SELECT Stock_Quantity AS Lamp_Stock FROM PRODUCT WHERE Product_ID = :v_prod;   -- 10 -> 11 (1 given back)

-- TEST 15: delete an order item and check that stock is restored
DELETE FROM ORDER_ITEM WHERE Order_ID = :v_order AND Product_ID = 1004;
SELECT Stock_Quantity AS Kurta_Stock FROM PRODUCT WHERE Product_ID = 1004;     -- 45 -> 47

-- TEST 8: confirm an order that has items -> "Order N confirmed with 1 item(s). Total = 5196"
EXEC PR_CONFIRM_ORDER(:v_order)
SELECT Order_ID, Order_Status FROM CUSTOMER_ORDER WHERE Order_ID = :v_order;   -- CONFIRMED

-- TEST 9: confirm an EMPTY order -> EXPECTED: ERROR
--   ORA-20223: Order N has no items. Add at least one item before confirming.
EXEC PR_CREATE_ORDER(105, :v_empty)
EXEC PR_CONFIRM_ORDER(:v_empty)
--   direct UPDATE is also blocked by the trigger: ORA-20031 ... has no items ...
UPDATE CUSTOMER_ORDER SET Order_Status = 'CONFIRMED' WHERE Order_ID = :v_empty;

-- TEST 10: record a valid payment (4 lamps x 1299 = 5196) -> "Payment N recorded ..."
EXEC PR_RECORD_PAYMENT(:v_order, 'UPI', 5196, 'UPI-TEST-000001', :v_pay)
PRINT v_pay

-- TEST 11: second payment for the same order -> EXPECTED: ERROR (two ways)
--   via procedure: ORA-20239: Order N already has a payment ...
EXEC PR_RECORD_PAYMENT(:v_order, 'CARD', 5196, 'CARD-TEST-000002', :v_pay)
--   via plain INSERT: ORA-00001: unique constraint (SHOPFLOW.UQ_PAYMENT_ORDER) violated
INSERT INTO PAYMENT (Order_ID, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (:v_order, 'CARD', 100, 'CARD-TEST-000003', 'SUCCESS');

-- TEST 12: valid return request (order 5004 is DELIVERED, product 1010 ordered once)
EXEC PR_CREATE_RETURN_REQUEST(5004, 1010, 1, 'Book cover damaged on arrival', :v_ret)
PRINT v_ret

-- TEST 13: return more than ordered (5002 had 2 kurtas) -> EXPECTED: ERROR (two ways)
--   via procedure: ORA-20254: Return quantity 5 is more than the ordered quantity 2.
EXEC PR_CREATE_RETURN_REQUEST(5002, 1004, 5, 'Size too large', :v_ret)
--   via plain INSERT (trigger): ORA-20042: Return quantity (5) cannot be greater than the ordered quantity (2).
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Quantity, Return_Reason)
VALUES (5002, 1004, 5, 'Size too large');

-- TEST 14: second return for the same order item (5001 / 1001 already has 7001) -> EXPECTED: ERROR
--   via procedure: ORA-20255: A return request already exists ...
EXEC PR_CREATE_RETURN_REQUEST(5001, 1001, 1, 'Second request', :v_ret)
--   via plain INSERT: ORA-00001: unique constraint (SHOPFLOW.UQ_RETURN_ORDER_ITEM) violated
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Quantity, Return_Reason)
VALUES (5001, 1001, 1, 'Second request');

-- (Extra) return for a product that is not in the order -> EXPECTED: ERROR
--   ORA-20040: Product 1002 is not part of order 5001 ...
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Quantity) VALUES (5001, 1002, 1);

-- TEST 17: roll back a cancelled transaction
SAVEPOINT sp_t17;
EXEC PR_CREATE_ORDER(103, :v_t17)
EXEC PR_ADD_ORDER_ITEM(:v_t17, 1002, 2)
SELECT Stock_Quantity AS Phone_Stock FROM PRODUCT WHERE Product_ID = 1002;   -- 14 -> 12
ROLLBACK TO SAVEPOINT sp_t17;
SELECT Stock_Quantity AS Phone_Stock FROM PRODUCT WHERE Product_ID = 1002;   -- back to 14
SELECT COUNT(*) AS T17_Order_Rows FROM CUSTOMER_ORDER WHERE Order_ID = :v_t17;  -- 0

-- TEST 17b: cancelling an order restores stock through the status trigger
EXEC PR_UPDATE_ORDER_STATUS(5006, 'CANCELLED')
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID IN (1004, 1006);   -- 1004: 48, 1006: 3
--   and an invalid status change -> EXPECTED: ERROR
--   ORA-20030: Invalid status change for order 5001: DELIVERED -> PENDING.
EXEC PR_UPDATE_ORDER_STATUS(5001, 'PENDING')
--   and changing items of a non-PENDING order -> EXPECTED: ERROR ORA-20011
DELETE FROM ORDER_ITEM WHERE Order_ID = 5001 AND Product_ID = 1007;

-- TEST 18: verify all views (each returns rows, no error)
SELECT * FROM VW_PRODUCT_STOCK_STATUS ORDER BY Product_ID;
SELECT * FROM VW_ORDER_SUMMARY ORDER BY Order_ID;
SELECT * FROM VW_CUSTOMER_ORDER_HISTORY ORDER BY Customer_ID, Order_ID;
SELECT * FROM VW_LOW_STOCK_PRODUCTS ORDER BY Product_ID;
SELECT * FROM VW_RETURN_DETAILS ORDER BY Return_ID;

-- TEST 19: verify functions and procedures
SELECT FN_ORDER_TOTAL(5001) AS Total_5001, FN_AVAILABLE_STOCK(1003) AS Stock_1003,
       FN_CUSTOMER_ORDER_COUNT(101) AS Orders_101 FROM DUAL;                  -- 2698, 0, 2
--   EXPECTED: ERROR ORA-20101: Order 9999 does not exist.
SELECT FN_ORDER_TOTAL(9999) FROM DUAL;
SELECT object_name, object_type, status FROM USER_OBJECTS
WHERE  object_type IN ('FUNCTION', 'PROCEDURE', 'TRIGGER', 'VIEW') ORDER BY object_type, object_name;  -- all VALID

-- TEST 20: foreign-key violations are rejected -> EXPECTED: ERROR for each
--   ORA-02291: integrity constraint (SHOPFLOW.FK_ORDER_CUSTOMER) violated - parent key not found
INSERT INTO CUSTOMER_ORDER (Customer_ID) VALUES (999);
--   ORA-02291: integrity constraint (SHOPFLOW.FK_PHONE_CUSTOMER) violated - parent key not found
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (999, '9000000000');
--   ORA-02291: integrity constraint (SHOPFLOW.FK_PAYMENT_ORDER) violated - parent key not found
INSERT INTO PAYMENT (Order_ID, Payment_Method, Payment_Amount, Transaction_Reference)
VALUES (9999, 'UPI', 100, 'UPI-NO-ORDER');
--   ORA-02292: integrity constraint (SHOPFLOW.FK_PRODUCT_CATEGORY) violated - child record found
DELETE FROM CATEGORY WHERE Category_ID = 1;

-- Undo every test change so the sample data is exactly as before
ROLLBACK;
SELECT COUNT(*) AS Customers FROM CUSTOMER;                   -- 12
SELECT Order_ID, Order_Status FROM CUSTOMER_ORDER WHERE Order_ID = 5006;  -- PENDING again

-- =====================================================================
-- PART C. COMMIT DEMO (makes a permanent change)
-- =====================================================================
VARIABLE v_commit_order NUMBER
EXEC PR_CREATE_ORDER(104, :v_commit_order)
EXEC PR_ADD_ORDER_ITEM(:v_commit_order, 1008, 1)
EXEC PR_CONFIRM_ORDER(:v_commit_order)
COMMIT;
-- After COMMIT the change is permanent; ROLLBACK can no longer undo it:
ROLLBACK;
SELECT * FROM VW_ORDER_SUMMARY WHERE Order_ID = :v_commit_order;   -- still there, CONFIRMED, 1899
SELECT Product_ID, Stock_Quantity FROM PRODUCT WHERE Product_ID = 1008;  -- 8
-- To reset the database to the original sample data, run file 12 again.
