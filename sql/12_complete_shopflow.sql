-- =====================================================================
-- FILE      : 12_complete_shopflow.sql
-- PROJECT   : SHOPFLOW E-COMMERCE ORDER, INVENTORY AND RETURNS MANAGEMENT SYSTEM
-- STUDENT   : Khushi Harlalka | Reg. No. 25BDE0151
-- COURSE    : Database Systems (BACSE202) | Slot L49 + L50
-- DATABASE  : Oracle Database (Oracle SQL and PL/SQL only)
--
-- PURPOSE   : The WHOLE implementation in ONE script, in the correct order:
--               PART 1  cleanup (drop old objects)          = file 02
--               PART 2  sequences                           = file 03
--               PART 3  tables and constraints              = file 04
--               PART 4  indexes                             = file 05
--               PART 5  triggers                            = file 06
--               PART 6  functions, procedures, cursors      = file 07
--               PART 7  views                               = file 08
--               PART 8  sample data + COMMIT                = file 09
--               PART 9  final verification
-- HOW TO RUN: SQL Developer -> open this file -> Run Script (F5).
--             SQL Plus      -> @12_complete_shopflow.sql
--             The script is rerunnable: it cleans up first every time.
-- Demos and tests are kept separately in 10_test_queries.sql and
-- 11_transaction_demo.sql (run them after this file).
-- File 01_user_setup.sql (admin only) is NOT part of this script.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- #####################################################################
-- PART 1 : contents of 02_drop_objects.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 02_drop_objects.sql
-- PURPOSE   : Rerunnable cleanup. Removes every ShopFlow object so the
--             project can be built again from a clean state.
-- ORDER     : views -> triggers -> procedures -> functions -> sequences
--             -> tables (child tables first, parent tables last)
-- HOW       : A small local procedure runs each DROP with EXECUTE IMMEDIATE
--             and ignores only "object does not exist" errors:
--               ORA-00942 table or view does not exist
--               ORA-04043 object (procedure/function) does not exist
--               ORA-04080 trigger does not exist
--               ORA-02289 sequence does not exist
--             Any other error is raised normally, so real problems are seen.
-- =====================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF

DECLARE
    PROCEDURE drop_object (p_sql IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
        DBMS_OUTPUT.PUT_LINE('Dropped : ' || p_sql);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE IN (-942, -4043, -4080, -2289) THEN
                DBMS_OUTPUT.PUT_LINE('Skipped : ' || p_sql || '  (not found)');
            ELSE
                RAISE;
            END IF;
    END drop_object;
BEGIN
    -- 1. Views
    drop_object('DROP VIEW VW_RETURN_DETAILS');
    drop_object('DROP VIEW VW_LOW_STOCK_PRODUCTS');
    drop_object('DROP VIEW VW_CUSTOMER_ORDER_HISTORY');
    drop_object('DROP VIEW VW_ORDER_SUMMARY');
    drop_object('DROP VIEW VW_PRODUCT_STOCK_STATUS');

    -- 2. Triggers (dropping a table also drops its triggers,
    --    but we drop them explicitly for clarity)
    drop_object('DROP TRIGGER TRG_RETURN_VALIDATE');
    drop_object('DROP TRIGGER TRG_RETURN_REQUEST_BI');
    drop_object('DROP TRIGGER TRG_PAYMENT_BI');
    drop_object('DROP TRIGGER TRG_ORDER_ITEM_STOCK');
    drop_object('DROP TRIGGER TRG_ORDER_STATUS_RULES');
    drop_object('DROP TRIGGER TRG_CUSTOMER_ORDER_BI');
    drop_object('DROP TRIGGER TRG_PRODUCT_BI');
    drop_object('DROP TRIGGER TRG_CATEGORY_BI');
    drop_object('DROP TRIGGER TRG_CUSTOMER_BI');

    -- 3. Procedures
    drop_object('DROP PROCEDURE PR_PROCESS_APPROVED_REFUNDS');
    drop_object('DROP PROCEDURE PR_AUTO_RESTOCK');
    drop_object('DROP PROCEDURE PR_REGISTER_CUSTOMER');
    drop_object('DROP PROCEDURE PR_UPDATE_ORDER_STATUS');
    drop_object('DROP PROCEDURE PR_CREATE_RETURN_REQUEST');
    drop_object('DROP PROCEDURE PR_RECORD_PAYMENT');
    drop_object('DROP PROCEDURE PR_CONFIRM_ORDER');
    drop_object('DROP PROCEDURE PR_ADD_ORDER_ITEM');
    drop_object('DROP PROCEDURE PR_CREATE_ORDER');

    -- 4. Functions
    drop_object('DROP FUNCTION FN_CUSTOMER_ORDER_COUNT');
    drop_object('DROP FUNCTION FN_AVAILABLE_STOCK');
    drop_object('DROP FUNCTION FN_ORDER_TOTAL');

    -- 5. Sequences
    drop_object('DROP SEQUENCE SEQ_RETURN_REQUEST');
    drop_object('DROP SEQUENCE SEQ_PAYMENT');
    drop_object('DROP SEQUENCE SEQ_CUSTOMER_ORDER');
    drop_object('DROP SEQUENCE SEQ_PRODUCT');
    drop_object('DROP SEQUENCE SEQ_CATEGORY');
    drop_object('DROP SEQUENCE SEQ_CUSTOMER');

    -- 6. Tables: children first, parents last.
    --    PURGE removes the table permanently (skips the recycle bin).
    drop_object('DROP TABLE RETURN_REQUEST PURGE');   -- child of ORDER_ITEM
    drop_object('DROP TABLE PAYMENT PURGE');          -- child of CUSTOMER_ORDER
    drop_object('DROP TABLE ORDER_ITEM PURGE');       -- child of CUSTOMER_ORDER, PRODUCT
    drop_object('DROP TABLE CUSTOMER_ORDER PURGE');   -- child of CUSTOMER
    drop_object('DROP TABLE PRODUCT PURGE');          -- child of CATEGORY
    drop_object('DROP TABLE CATEGORY PURGE');
    drop_object('DROP TABLE CUSTOMER_PHONE PURGE');   -- child of CUSTOMER
    drop_object('DROP TABLE CUSTOMER PURGE');

    DBMS_OUTPUT.PUT_LINE('Cleanup finished.');
END;
/

-- #####################################################################
-- PART 2 : contents of 03_sequences.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 03_sequences.sql
-- PURPOSE   : Number generators for the automatic primary keys.
--
-- START WITH   : first number the sequence gives out.
-- INCREMENT BY : how much is added each time (1 = 101, 102, 103 ...).
-- NOCACHE      : Oracle does not pre-allocate numbers in memory, so fewer
--                numbers are lost on a restart (gaps are still possible
--                after ROLLBACK, because a used sequence number is never
--                given back - this is normal and acceptable).
-- NOCYCLE      : after the maximum value the sequence stops instead of
--                starting again from the beginning, so IDs never repeat.
--
-- Different starting numbers make IDs easy to recognise during the viva:
--   Customers 101.., Categories 1.., Products 1001.., Orders 5001..,
--   Payments 9001.., Returns 7001..
-- =====================================================================
SET DEFINE OFF

CREATE SEQUENCE SEQ_CUSTOMER       START WITH 101  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CATEGORY       START WITH 1    INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PRODUCT        START WITH 1001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CUSTOMER_ORDER START WITH 5001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PAYMENT        START WITH 9001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_RETURN_REQUEST START WITH 7001 INCREMENT BY 1 NOCACHE NOCYCLE;

-- #####################################################################
-- PART 3 : contents of 04_create_tables.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 04_create_tables.sql
-- PURPOSE   : Creates the eight ShopFlow tables in dependency order
--             (a parent table is always created before its child).
--   1 CUSTOMER  2 CUSTOMER_PHONE  3 CATEGORY  4 PRODUCT
--   5 CUSTOMER_ORDER  6 ORDER_ITEM  7 PAYMENT  8 RETURN_REQUEST
-- Every important constraint has a name, so error messages and the data
-- dictionary show which rule was broken (e.g. UQ_CUSTOMER_EMAIL).
-- Prefixes: PK primary key, UQ unique, FK foreign key, CK check, NN not null
-- =====================================================================
SET DEFINE OFF

-- ---------------------------------------------------------------------
-- TABLE 1 : CUSTOMER  - one row per registered customer
-- ---------------------------------------------------------------------
CREATE TABLE CUSTOMER (
    Customer_ID        NUMBER         CONSTRAINT PK_CUSTOMER PRIMARY KEY,
    First_Name         VARCHAR2(50)   CONSTRAINT NN_CUSTOMER_FNAME NOT NULL,
    Last_Name          VARCHAR2(50)   CONSTRAINT NN_CUSTOMER_LNAME NOT NULL,
    Email              VARCHAR2(100)  CONSTRAINT NN_CUSTOMER_EMAIL NOT NULL,
    Street             VARCHAR2(150),
    City               VARCHAR2(50),
    State              VARCHAR2(50),
    Postal_Code        VARCHAR2(10),
    Registration_Date  DATE DEFAULT SYSDATE CONSTRAINT NN_CUSTOMER_REGDATE NOT NULL,
    CONSTRAINT UQ_CUSTOMER_EMAIL UNIQUE (Email),                  -- candidate key
    CONSTRAINT CK_CUSTOMER_EMAIL CHECK (Email LIKE '%_@_%._%')    -- basic format check
);

-- ---------------------------------------------------------------------
-- TABLE 2 : CUSTOMER_PHONE - one row per phone number (multivalued attribute)
-- ---------------------------------------------------------------------
CREATE TABLE CUSTOMER_PHONE (
    Customer_ID   NUMBER,
    Phone_Number  VARCHAR2(15)  CONSTRAINT NN_PHONE_NUMBER NOT NULL,
    CONSTRAINT PK_CUSTOMER_PHONE PRIMARY KEY (Customer_ID, Phone_Number),  -- composite PK
    CONSTRAINT FK_PHONE_CUSTOMER FOREIGN KEY (Customer_ID)
        REFERENCES CUSTOMER (Customer_ID) ON DELETE CASCADE,  -- phones go when customer goes
    CONSTRAINT CK_PHONE_FORMAT CHECK (REGEXP_LIKE(Phone_Number, '^\+?[0-9]{10,14}$'))
);

-- ---------------------------------------------------------------------
-- TABLE 3 : CATEGORY - product categories
-- ---------------------------------------------------------------------
CREATE TABLE CATEGORY (
    Category_ID           NUMBER         CONSTRAINT PK_CATEGORY PRIMARY KEY,
    Category_Name         VARCHAR2(80)   CONSTRAINT NN_CATEGORY_NAME NOT NULL,
    Category_Description  VARCHAR2(250),
    CONSTRAINT UQ_CATEGORY_NAME UNIQUE (Category_Name)            -- candidate key
);

-- ---------------------------------------------------------------------
-- TABLE 4 : PRODUCT - product details, current price and stock
-- Stock_Status is a VIRTUAL column: Oracle calculates it from
-- Stock_Quantity and Reorder_Level every time it is read. It is never
-- stored or inserted, so it can never be out of date.
-- ---------------------------------------------------------------------
CREATE TABLE PRODUCT (
    Product_ID      NUMBER         CONSTRAINT PK_PRODUCT PRIMARY KEY,
    Category_ID     NUMBER         CONSTRAINT NN_PRODUCT_CATEGORY NOT NULL,
    Product_Name    VARCHAR2(100)  CONSTRAINT NN_PRODUCT_NAME NOT NULL,
    Description     VARCHAR2(500),
    Unit_Price      NUMBER(10,2)   CONSTRAINT NN_PRODUCT_PRICE NOT NULL,
    Stock_Quantity  NUMBER DEFAULT 0          CONSTRAINT NN_PRODUCT_STOCK NOT NULL,
    Reorder_Level   NUMBER DEFAULT 0          CONSTRAINT NN_PRODUCT_REORDER NOT NULL,
    Product_Status  VARCHAR2(20) DEFAULT 'ACTIVE' CONSTRAINT NN_PRODUCT_STATUS NOT NULL,
    Stock_Status    VARCHAR2(15) GENERATED ALWAYS AS (
                        CASE
                            WHEN Stock_Quantity = 0              THEN 'OUT OF STOCK'
                            WHEN Stock_Quantity <= Reorder_Level THEN 'LOW STOCK'
                            ELSE 'IN STOCK'
                        END
                    ) VIRTUAL,
    CONSTRAINT FK_PRODUCT_CATEGORY FOREIGN KEY (Category_ID)
        REFERENCES CATEGORY (Category_ID),
    CONSTRAINT CK_PRODUCT_PRICE   CHECK (Unit_Price > 0),
    CONSTRAINT CK_PRODUCT_STOCK   CHECK (Stock_Quantity >= 0),
    CONSTRAINT CK_PRODUCT_REORDER CHECK (Reorder_Level >= 0),
    CONSTRAINT CK_PRODUCT_STATUS  CHECK (Product_Status IN ('ACTIVE', 'INACTIVE', 'DISCONTINUED'))
);

-- ---------------------------------------------------------------------
-- TABLE 5 : CUSTOMER_ORDER - order header (not called ORDER, because
--           ORDER is an SQL reserved word as in ORDER BY)
-- ---------------------------------------------------------------------
CREATE TABLE CUSTOMER_ORDER (
    Order_ID              NUMBER        CONSTRAINT PK_CUSTOMER_ORDER PRIMARY KEY,
    Customer_ID           NUMBER        CONSTRAINT NN_ORDER_CUSTOMER NOT NULL,
    Order_Date            DATE DEFAULT SYSDATE       CONSTRAINT NN_ORDER_DATE NOT NULL,
    Order_Status          VARCHAR2(20) DEFAULT 'PENDING' CONSTRAINT NN_ORDER_STATUS NOT NULL,
    Shipping_Street       VARCHAR2(150),
    Shipping_City         VARCHAR2(50),
    Shipping_State        VARCHAR2(50),
    Shipping_Postal_Code  VARCHAR2(10),
    CONSTRAINT FK_ORDER_CUSTOMER FOREIGN KEY (Customer_ID)
        REFERENCES CUSTOMER (Customer_ID),   -- no cascade: customers with orders cannot be deleted
    CONSTRAINT CK_ORDER_STATUS CHECK (Order_Status IN
        ('PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'))
);

-- ---------------------------------------------------------------------
-- TABLE 6 : ORDER_ITEM - associative (junction) table between
--           CUSTOMER_ORDER and PRODUCT. One row = one product in one order.
-- Unit_Price here = selling price at the time of ordering (history).
-- Item_Subtotal is a VIRTUAL column = Quantity * Unit_Price.
-- ---------------------------------------------------------------------
CREATE TABLE ORDER_ITEM (
    Order_ID       NUMBER,
    Product_ID     NUMBER,
    Quantity       NUMBER        CONSTRAINT NN_ITEM_QUANTITY NOT NULL,
    Unit_Price     NUMBER(10,2)  CONSTRAINT NN_ITEM_PRICE NOT NULL,
    Item_Subtotal  NUMBER(12,2)  GENERATED ALWAYS AS (Quantity * Unit_Price) VIRTUAL,
    CONSTRAINT PK_ORDER_ITEM   PRIMARY KEY (Order_ID, Product_ID),      -- composite PK
    CONSTRAINT FK_ITEM_ORDER   FOREIGN KEY (Order_ID)   REFERENCES CUSTOMER_ORDER (Order_ID),
    CONSTRAINT FK_ITEM_PRODUCT FOREIGN KEY (Product_ID) REFERENCES PRODUCT (Product_ID),
    CONSTRAINT CK_ITEM_QUANTITY CHECK (Quantity > 0),
    CONSTRAINT CK_ITEM_PRICE    CHECK (Unit_Price > 0)
);

-- ---------------------------------------------------------------------
-- TABLE 7 : PAYMENT - at most one payment per order (UQ_PAYMENT_ORDER)
-- COD decision: Transaction_Reference may be NULL only for COD.
-- Oracle allows many NULLs in a single-column UNIQUE constraint, so many
-- COD payments without a reference never violate UQ_PAYMENT_TXN_REF.
-- ---------------------------------------------------------------------
CREATE TABLE PAYMENT (
    Payment_ID             NUMBER         CONSTRAINT PK_PAYMENT PRIMARY KEY,
    Order_ID               NUMBER         CONSTRAINT NN_PAYMENT_ORDER NOT NULL,
    Payment_Date           DATE DEFAULT SYSDATE      CONSTRAINT NN_PAYMENT_DATE NOT NULL,
    Payment_Method         VARCHAR2(20)   CONSTRAINT NN_PAYMENT_METHOD NOT NULL,
    Payment_Amount         NUMBER(12,2)   CONSTRAINT NN_PAYMENT_AMOUNT NOT NULL,
    Transaction_Reference  VARCHAR2(100),
    Payment_Status         VARCHAR2(20) DEFAULT 'PENDING' CONSTRAINT NN_PAYMENT_STATUS NOT NULL,
    CONSTRAINT UQ_PAYMENT_ORDER   UNIQUE (Order_ID),                   -- 1 : 0..1
    CONSTRAINT FK_PAYMENT_ORDER   FOREIGN KEY (Order_ID) REFERENCES CUSTOMER_ORDER (Order_ID),
    CONSTRAINT UQ_PAYMENT_TXN_REF UNIQUE (Transaction_Reference),
    CONSTRAINT CK_PAYMENT_AMOUNT  CHECK (Payment_Amount > 0),
    CONSTRAINT CK_PAYMENT_METHOD  CHECK (Payment_Method IN ('UPI', 'CARD', 'NET_BANKING', 'COD', 'WALLET')),
    CONSTRAINT CK_PAYMENT_STATUS  CHECK (Payment_Status IN ('PENDING', 'SUCCESS', 'FAILED', 'REFUNDED')),
    CONSTRAINT CK_PAYMENT_REFERENCE CHECK (Payment_Method = 'COD' OR Transaction_Reference IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- TABLE 8 : RETURN_REQUEST - at most one return per order item
-- (Order_ID, Product_ID) is a COMPOSITE FOREIGN KEY to ORDER_ITEM, so a
-- return can only point to a product that really is in that order.
-- ---------------------------------------------------------------------
CREATE TABLE RETURN_REQUEST (
    Return_ID        NUMBER         CONSTRAINT PK_RETURN_REQUEST PRIMARY KEY,
    Order_ID         NUMBER         CONSTRAINT NN_RETURN_ORDER NOT NULL,
    Product_ID       NUMBER         CONSTRAINT NN_RETURN_PRODUCT NOT NULL,
    Return_Date      DATE DEFAULT SYSDATE        CONSTRAINT NN_RETURN_DATE NOT NULL,
    Return_Quantity  NUMBER         CONSTRAINT NN_RETURN_QUANTITY NOT NULL,
    Return_Reason    VARCHAR2(500),
    Return_Status    VARCHAR2(20) DEFAULT 'REQUESTED' CONSTRAINT NN_RETURN_STATUS NOT NULL,
    Refund_Amount    NUMBER(12,2) DEFAULT 0      CONSTRAINT NN_RETURN_REFUND NOT NULL,
    CONSTRAINT UQ_RETURN_ORDER_ITEM UNIQUE (Order_ID, Product_ID),     -- 1 : 0..1
    CONSTRAINT FK_RETURN_ORDER_ITEM FOREIGN KEY (Order_ID, Product_ID)
        REFERENCES ORDER_ITEM (Order_ID, Product_ID),                    -- composite FK
    CONSTRAINT CK_RETURN_QUANTITY CHECK (Return_Quantity > 0),
    CONSTRAINT CK_RETURN_REFUND   CHECK (Refund_Amount >= 0),
    CONSTRAINT CK_RETURN_STATUS   CHECK (Return_Status IN
        ('REQUESTED', 'APPROVED', 'REJECTED', 'PICKED_UP', 'COMPLETED', 'REFUNDED'))
);

-- #####################################################################
-- PART 4 : contents of 05_indexes.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 05_indexes.sql
-- PURPOSE   : Extra indexes for faster searching and joining.
--
-- Oracle AUTOMATICALLY creates a unique index for every PRIMARY KEY and
-- UNIQUE constraint. So these already exist and are NOT created again:
--   PK_CUSTOMER, UQ_CUSTOMER_EMAIL, PK_CUSTOMER_PHONE (also covers its FK
--   because Customer_ID is the first column), PK_CATEGORY, UQ_CATEGORY_NAME,
--   PK_PRODUCT, PK_CUSTOMER_ORDER, PK_ORDER_ITEM (covers Order_ID),
--   PK_PAYMENT, UQ_PAYMENT_ORDER, UQ_PAYMENT_TXN_REF, PK_RETURN_REQUEST,
--   UQ_RETURN_ORDER_ITEM (covers the composite FK).
--
-- Oracle does NOT automatically index foreign-key columns, so we index the
-- FK columns that are not the first column of an existing index, plus two
-- columns used often in WHERE clauses.
--
-- Trade-off: an index makes SELECT faster (Oracle jumps to matching rows
-- instead of reading the whole table), but every INSERT, UPDATE and DELETE
-- must also update the index, which adds a small cost. So we create only
-- useful indexes.
-- =====================================================================
SET DEFINE OFF

CREATE INDEX IDX_PRODUCT_CATEGORY ON PRODUCT (Category_ID);          -- products of a category, FK join
CREATE INDEX IDX_ORDER_CUSTOMER   ON CUSTOMER_ORDER (Customer_ID);   -- orders of a customer, FK join
CREATE INDEX IDX_ITEM_PRODUCT     ON ORDER_ITEM (Product_ID);        -- sales of a product, FK join
CREATE INDEX IDX_RETURN_STATUS    ON RETURN_REQUEST (Return_Status); -- filter returns by status
CREATE INDEX IDX_ORDER_DATE       ON CUSTOMER_ORDER (Order_Date);    -- date-range and monthly reports

-- #####################################################################
-- PART 5 : contents of 06_triggers.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 06_triggers.sql
-- PURPOSE   : All triggers of ShopFlow.
--
-- DESIGN DECISION (very important):
--   Stock is changed in ONE place only: trigger TRG_ORDER_ITEM_STOCK.
--   (The only other stock change is TRG_ORDER_STATUS_RULES, which puts stock
--   back when a whole order is CANCELLED - a different event.)
--   Procedures NEVER update PRODUCT.Stock_Quantity themselves; they only
--   insert / update / delete ORDER_ITEM rows. Therefore stock can never be
--   reduced twice, whether data comes through a procedure or a plain INSERT.
--
-- ID generation: Oracle 12c+ also supports IDENTITY columns
--   (Customer_ID NUMBER GENERATED BY DEFAULT AS IDENTITY). This project uses
--   ONE consistent method instead: SEQUENCE + BEFORE INSERT trigger, which
--   also works on 11g. We never mix both methods for the same column.
--
-- Custom error numbers used by triggers:
--   -20010..-20017 order items / stock   -20030..-20032 order status
--   -20040..-20045 return requests
-- =====================================================================
SET DEFINE OFF

-- ---------------------------------------------------------------------
-- 1. ID-generation triggers (one per table that has a surrogate key)
--    "IF ... IS NULL" means: generate an ID only when none was supplied.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_CUSTOMER_BI
BEFORE INSERT ON CUSTOMER
FOR EACH ROW
BEGIN
    IF :NEW.Customer_ID IS NULL THEN
        :NEW.Customer_ID := SEQ_CUSTOMER.NEXTVAL;
    END IF;
    -- store email in one standard form so 'A@x.com' and 'a@x.com' count as the same
    :NEW.Email := LOWER(TRIM(:NEW.Email));
    IF :NEW.Registration_Date IS NULL THEN
        :NEW.Registration_Date := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_CATEGORY_BI
BEFORE INSERT ON CATEGORY
FOR EACH ROW
BEGIN
    IF :NEW.Category_ID IS NULL THEN
        :NEW.Category_ID := SEQ_CATEGORY.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_PRODUCT_BI
BEFORE INSERT ON PRODUCT
FOR EACH ROW
BEGIN
    IF :NEW.Product_ID IS NULL THEN
        :NEW.Product_ID := SEQ_PRODUCT.NEXTVAL;
    END IF;
END;
/

-- Order ID + every new order must start as PENDING
CREATE OR REPLACE TRIGGER TRG_CUSTOMER_ORDER_BI
BEFORE INSERT ON CUSTOMER_ORDER
FOR EACH ROW
BEGIN
    IF :NEW.Order_ID IS NULL THEN
        :NEW.Order_ID := SEQ_CUSTOMER_ORDER.NEXTVAL;
    END IF;
    IF :NEW.Order_Date IS NULL THEN
        :NEW.Order_Date := SYSDATE;
    END IF;
    IF :NEW.Order_Status IS NULL THEN
        :NEW.Order_Status := 'PENDING';
    END IF;
    IF :NEW.Order_Status <> 'PENDING' THEN
        RAISE_APPLICATION_ERROR(-20032,
            'A new order must start with status PENDING. Add items first, then confirm it.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_PAYMENT_BI
BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    IF :NEW.Payment_ID IS NULL THEN
        :NEW.Payment_ID := SEQ_PAYMENT.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_RETURN_REQUEST_BI
BEFORE INSERT ON RETURN_REQUEST
FOR EACH ROW
BEGIN
    IF :NEW.Return_ID IS NULL THEN
        :NEW.Return_ID := SEQ_RETURN_REQUEST.NEXTVAL;
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- 2. INVENTORY TRIGGER on ORDER_ITEM (the single place for stock changes)
--
--  INSERT : order must be PENDING, product must exist and be ACTIVE,
--           quantity must be available. Copies the CURRENT product price
--           into ORDER_ITEM.Unit_Price, then reduces stock by Quantity.
--  UPDATE : order must be PENDING. Order_ID, Product_ID and the historical
--           Unit_Price cannot be changed. If Quantity goes up, only the
--           extra amount is taken from stock (after checking it is there).
--           If Quantity goes down, the difference goes back to stock.
--  DELETE : order must be PENDING. The whole quantity goes back to stock.
--
--  CONCURRENCY: two users may order the last units of the same product at
--  the same moment. Both could read "stock = 5", both order 5, and stock
--  would become -5. To stop this we read the product row with
--  SELECT ... FOR UPDATE. This LOCKS that product row until COMMIT or
--  ROLLBACK, so the second user waits, then reads the new (reduced) stock
--  and gets a clear "insufficient stock" error. CK_PRODUCT_STOCK is a final
--  safety net: stock can never be saved as negative.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ORDER_ITEM_STOCK
BEFORE INSERT OR UPDATE OR DELETE ON ORDER_ITEM
FOR EACH ROW
DECLARE
    v_order_id      ORDER_ITEM.Order_ID%TYPE;
    v_order_status  CUSTOMER_ORDER.Order_Status%TYPE;
    v_stock         PRODUCT.Stock_Quantity%TYPE;
    v_price         PRODUCT.Unit_Price%TYPE;
    v_prod_status   PRODUCT.Product_Status%TYPE;
    v_diff          NUMBER;
BEGIN
    -- Which order is affected?
    IF DELETING THEN
        v_order_id := :OLD.Order_ID;
    ELSE
        v_order_id := :NEW.Order_ID;
    END IF;

    -- Items may change only while the order is still PENDING
    BEGIN
        SELECT Order_Status INTO v_order_status
        FROM   CUSTOMER_ORDER
        WHERE  Order_ID = v_order_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Order ' || v_order_id || ' does not exist.');
    END;

    IF v_order_status <> 'PENDING' THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Items can be added, changed or removed only while the order is PENDING. Order '
            || v_order_id || ' is ' || v_order_status || '.');
    END IF;

    IF INSERTING THEN
        -- lock the product row (concurrency protection) and read price/stock
        BEGIN
            SELECT Stock_Quantity, Unit_Price, Product_Status
            INTO   v_stock, v_price, v_prod_status
            FROM   PRODUCT
            WHERE  Product_ID = :NEW.Product_ID
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20012, 'Product ' || :NEW.Product_ID || ' does not exist.');
        END;

        IF v_prod_status <> 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20013,
                'Product ' || :NEW.Product_ID || ' is ' || v_prod_status || ' and cannot be ordered.');
        END IF;

        IF :NEW.Quantity IS NULL OR :NEW.Quantity <= 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Ordered quantity must be greater than zero.');
        END IF;

        IF :NEW.Quantity > v_stock THEN
            RAISE_APPLICATION_ERROR(-20015,
                'Insufficient stock for product ' || :NEW.Product_ID ||
                '. Available: ' || v_stock || ', requested: ' || :NEW.Quantity || '.');
        END IF;

        -- Business rule 12: selling price is ALWAYS copied from PRODUCT
        :NEW.Unit_Price := v_price;

        UPDATE PRODUCT
        SET    Stock_Quantity = Stock_Quantity - :NEW.Quantity
        WHERE  Product_ID = :NEW.Product_ID;

    ELSIF UPDATING THEN
        IF :NEW.Order_ID <> :OLD.Order_ID OR :NEW.Product_ID <> :OLD.Product_ID THEN
            RAISE_APPLICATION_ERROR(-20016,
                'Order_ID and Product_ID of an order item cannot be changed. Delete the item and add it again.');
        END IF;

        IF :NEW.Unit_Price <> :OLD.Unit_Price THEN
            RAISE_APPLICATION_ERROR(-20017,
                'The selling price saved in an order item is historical and cannot be changed.');
        END IF;

        IF :NEW.Quantity IS NULL OR :NEW.Quantity <= 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Ordered quantity must be greater than zero.');
        END IF;

        v_diff := :NEW.Quantity - :OLD.Quantity;   -- positive = more needed, negative = give back

        IF v_diff <> 0 THEN
            SELECT Stock_Quantity INTO v_stock
            FROM   PRODUCT
            WHERE  Product_ID = :NEW.Product_ID
            FOR UPDATE;

            IF v_diff > v_stock THEN
                RAISE_APPLICATION_ERROR(-20015,
                    'Insufficient stock for product ' || :NEW.Product_ID ||
                    '. Extra needed: ' || v_diff || ', available: ' || v_stock || '.');
            END IF;

            UPDATE PRODUCT
            SET    Stock_Quantity = Stock_Quantity - v_diff
            WHERE  Product_ID = :NEW.Product_ID;
        END IF;

    ELSIF DELETING THEN
        UPDATE PRODUCT
        SET    Stock_Quantity = Stock_Quantity + :OLD.Quantity
        WHERE  Product_ID = :OLD.Product_ID;
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- 3. ORDER STATUS RULES on CUSTOMER_ORDER
--  a) Only these status changes are allowed:
--       PENDING   -> CONFIRMED or CANCELLED
--       CONFIRMED -> SHIPPED   or CANCELLED
--       SHIPPED   -> DELIVERED
--     DELIVERED and CANCELLED are final.
--  b) An order can become CONFIRMED / SHIPPED / DELIVERED only if it has at
--     least one ORDER_ITEM. (A foreign key cannot check this "parent must
--     have at least one child" rule - see the report.)
--  c) When an order is CANCELLED, all its item quantities go back to stock.
--     The ORDER_ITEM rows are kept as history, and because items of a
--     non-PENDING order cannot be deleted, stock is never restored twice.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ORDER_STATUS_RULES
BEFORE UPDATE OF Order_Status ON CUSTOMER_ORDER
FOR EACH ROW
WHEN (NEW.Order_Status <> OLD.Order_Status)
DECLARE
    v_item_count  NUMBER;
    v_allowed     BOOLEAN;
BEGIN
    v_allowed :=
          (:OLD.Order_Status = 'PENDING'   AND :NEW.Order_Status IN ('CONFIRMED', 'CANCELLED'))
       OR (:OLD.Order_Status = 'CONFIRMED' AND :NEW.Order_Status IN ('SHIPPED', 'CANCELLED'))
       OR (:OLD.Order_Status = 'SHIPPED'   AND :NEW.Order_Status = 'DELIVERED');

    IF NOT v_allowed THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Invalid status change for order ' || :NEW.Order_ID || ': '
            || :OLD.Order_Status || ' -> ' || :NEW.Order_Status || '.');
    END IF;

    IF :NEW.Order_Status IN ('CONFIRMED', 'SHIPPED', 'DELIVERED') THEN
        SELECT COUNT(*) INTO v_item_count
        FROM   ORDER_ITEM
        WHERE  Order_ID = :NEW.Order_ID;

        IF v_item_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20031,
                'Order ' || :NEW.Order_ID || ' has no items and cannot be ' || :NEW.Order_Status || '.');
        END IF;
    END IF;

    IF :NEW.Order_Status = 'CANCELLED' THEN
        FOR r IN (SELECT Product_ID, Quantity
                  FROM   ORDER_ITEM
                  WHERE  Order_ID = :NEW.Order_ID) LOOP
            UPDATE PRODUCT
            SET    Stock_Quantity = Stock_Quantity + r.Quantity
            WHERE  Product_ID = r.Product_ID;
        END LOOP;
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- 4. RETURN VALIDATION on RETURN_REQUEST
--  * the (Order_ID, Product_ID) pair must be a real order item
--  * Return_Quantity must be > 0 and <= ordered quantity
--  * a NEW return is allowed only for a DELIVERED order
--  * Refund_Amount must be >= 0 and <= Return_Quantity * selling price
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_RETURN_VALIDATE
BEFORE INSERT OR UPDATE OF Order_ID, Product_ID, Return_Quantity, Refund_Amount
ON RETURN_REQUEST
FOR EACH ROW
DECLARE
    v_ordered_qty   ORDER_ITEM.Quantity%TYPE;
    v_sell_price    ORDER_ITEM.Unit_Price%TYPE;
    v_order_status  CUSTOMER_ORDER.Order_Status%TYPE;
BEGIN
    BEGIN
        SELECT oi.Quantity, oi.Unit_Price, co.Order_Status
        INTO   v_ordered_qty, v_sell_price, v_order_status
        FROM   ORDER_ITEM oi
               JOIN CUSTOMER_ORDER co ON co.Order_ID = oi.Order_ID
        WHERE  oi.Order_ID   = :NEW.Order_ID
        AND    oi.Product_ID = :NEW.Product_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20040,
                'Product ' || :NEW.Product_ID || ' is not part of order ' || :NEW.Order_ID ||
                '. A return can only be raised for an item of that order.');
    END;

    IF :NEW.Return_Quantity IS NULL OR :NEW.Return_Quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20041, 'Return quantity must be greater than zero.');
    END IF;

    IF :NEW.Return_Quantity > v_ordered_qty THEN
        RAISE_APPLICATION_ERROR(-20042,
            'Return quantity (' || :NEW.Return_Quantity || ') cannot be greater than the ordered quantity ('
            || v_ordered_qty || ').');
    END IF;

    IF INSERTING AND v_order_status <> 'DELIVERED' THEN
        RAISE_APPLICATION_ERROR(-20043,
            'A return can be requested only for a DELIVERED order. Order '
            || :NEW.Order_ID || ' is ' || v_order_status || '.');
    END IF;

    IF NVL(:NEW.Refund_Amount, 0) < 0 THEN
        RAISE_APPLICATION_ERROR(-20044, 'Refund amount cannot be negative.');
    END IF;

    IF NVL(:NEW.Refund_Amount, 0) > :NEW.Return_Quantity * v_sell_price THEN
        RAISE_APPLICATION_ERROR(-20045,
            'Refund amount cannot be more than ' || (:NEW.Return_Quantity * v_sell_price) ||
            ' (return quantity x selling price).');
    END IF;
END;
/

-- Check that every trigger compiled
SELECT trigger_name, table_name, status FROM USER_TRIGGERS ORDER BY table_name, trigger_name;
SELECT name, type, line, position, text FROM USER_ERRORS WHERE type = 'TRIGGER' ORDER BY name, sequence;

-- #####################################################################
-- PART 6 : contents of 07_functions_procedures.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 07_functions_procedures.sql
-- PURPOSE   : Stored functions (return one value) and procedures
--             (perform a business action).
--
-- Transaction rule: procedures do NOT COMMIT. The caller decides when to
-- COMMIT or ROLLBACK, so several procedure calls (create order + add items
-- + confirm) can be saved together or undone together.
--
-- Stock rule: procedures never update PRODUCT.Stock_Quantity directly.
-- They insert/update ORDER_ITEM rows and trigger TRG_ORDER_ITEM_STOCK does
-- the stock change. So stock is never reduced twice.
--
-- Custom error numbers: functions -20101..-20103, procedures -20201..-20281
-- Procedures 8 and 9 use EXPLICIT CURSORS to process many rows.
-- =====================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF

-- =====================================================================
-- FUNCTION 1 : FN_ORDER_TOTAL
--   P_ORDER_ID (IN) : the order whose total is needed
--   Returns the sum of Item_Subtotal of all items (0 if no items yet).
-- =====================================================================
CREATE OR REPLACE FUNCTION FN_ORDER_TOTAL (P_ORDER_ID IN NUMBER)
RETURN NUMBER
IS
    v_count  NUMBER;
    v_total  NUMBER(12,2);
BEGIN
    SELECT COUNT(*) INTO v_count FROM CUSTOMER_ORDER WHERE Order_ID = P_ORDER_ID;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20101, 'Order ' || P_ORDER_ID || ' does not exist.');
    END IF;

    SELECT NVL(SUM(Item_Subtotal), 0)
    INTO   v_total
    FROM   ORDER_ITEM
    WHERE  Order_ID = P_ORDER_ID;

    RETURN v_total;
END FN_ORDER_TOTAL;
/

-- =====================================================================
-- FUNCTION 2 : FN_AVAILABLE_STOCK
--   P_PRODUCT_ID (IN) : product to check
--   Returns PRODUCT.Stock_Quantity.
-- =====================================================================
CREATE OR REPLACE FUNCTION FN_AVAILABLE_STOCK (P_PRODUCT_ID IN NUMBER)
RETURN NUMBER
IS
    v_stock  PRODUCT.Stock_Quantity%TYPE;
BEGIN
    SELECT Stock_Quantity INTO v_stock
    FROM   PRODUCT
    WHERE  Product_ID = P_PRODUCT_ID;

    RETURN v_stock;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20102, 'Product ' || P_PRODUCT_ID || ' does not exist.');
END FN_AVAILABLE_STOCK;
/

-- =====================================================================
-- FUNCTION 3 : FN_CUSTOMER_ORDER_COUNT
--   P_CUSTOMER_ID (IN) : customer to check
--   Returns the number of orders placed by the customer (0 if none).
-- =====================================================================
CREATE OR REPLACE FUNCTION FN_CUSTOMER_ORDER_COUNT (P_CUSTOMER_ID IN NUMBER)
RETURN NUMBER
IS
    v_exists  NUMBER;
    v_count   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists FROM CUSTOMER WHERE Customer_ID = P_CUSTOMER_ID;
    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20103, 'Customer ' || P_CUSTOMER_ID || ' does not exist.');
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM   CUSTOMER_ORDER
    WHERE  Customer_ID = P_CUSTOMER_ID;

    RETURN v_count;
END FN_CUSTOMER_ORDER_COUNT;
/

-- =====================================================================
-- PROCEDURE 1 : PR_CREATE_ORDER
--   P_CUSTOMER_ID   (IN)  customer placing the order (must exist)
--   P_ORDER_ID      (OUT) the new Order_ID generated by the sequence
--   P_SHIP_STREET, P_SHIP_CITY, P_SHIP_STATE, P_SHIP_POSTAL (IN, optional)
--                         shipping address; if not given, the customer's
--                         own address is used.
--   The order is created with status PENDING.
-- Example:
--   DECLARE v_id NUMBER; BEGIN PR_CREATE_ORDER(101, v_id); END;
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_CREATE_ORDER (
    P_CUSTOMER_ID  IN  NUMBER,
    P_ORDER_ID     OUT NUMBER,
    P_SHIP_STREET  IN  VARCHAR2 DEFAULT NULL,
    P_SHIP_CITY    IN  VARCHAR2 DEFAULT NULL,
    P_SHIP_STATE   IN  VARCHAR2 DEFAULT NULL,
    P_SHIP_POSTAL  IN  VARCHAR2 DEFAULT NULL
)
IS
    v_street  CUSTOMER.Street%TYPE;
    v_city    CUSTOMER.City%TYPE;
    v_state   CUSTOMER.State%TYPE;
    v_postal  CUSTOMER.Postal_Code%TYPE;
BEGIN
    BEGIN
        SELECT Street, City, State, Postal_Code
        INTO   v_street, v_city, v_state, v_postal
        FROM   CUSTOMER
        WHERE  Customer_ID = P_CUSTOMER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20201,
                'Cannot create order: customer ' || P_CUSTOMER_ID || ' does not exist.');
    END;

    INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Status,
                                Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
    VALUES (P_CUSTOMER_ID, 'PENDING',
            NVL(P_SHIP_STREET, v_street), NVL(P_SHIP_CITY, v_city),
            NVL(P_SHIP_STATE, v_state),   NVL(P_SHIP_POSTAL, v_postal))
    RETURNING Order_ID INTO P_ORDER_ID;

    DBMS_OUTPUT.PUT_LINE('Order ' || P_ORDER_ID || ' created (PENDING) for customer ' || P_CUSTOMER_ID || '.');
END PR_CREATE_ORDER;
/

-- =====================================================================
-- PROCEDURE 2 : PR_ADD_ORDER_ITEM
--   P_ORDER_ID   (IN) order to add to (must be PENDING)
--   P_PRODUCT_ID (IN) product to add (must exist and be ACTIVE)
--   P_QUANTITY   (IN) quantity (> 0 and <= available stock)
--   Copies the current PRODUCT.Unit_Price into ORDER_ITEM. The stock is
--   reduced by trigger TRG_ORDER_ITEM_STOCK (not here) - no double reduction.
--   The product row is locked with FOR UPDATE so the stock check stays
--   correct even if another user orders the same product at the same time.
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_ADD_ORDER_ITEM (
    P_ORDER_ID    IN NUMBER,
    P_PRODUCT_ID  IN NUMBER,
    P_QUANTITY    IN NUMBER
)
IS
    v_order_status  CUSTOMER_ORDER.Order_Status%TYPE;
    v_price         PRODUCT.Unit_Price%TYPE;
    v_stock         PRODUCT.Stock_Quantity%TYPE;
    v_prod_status   PRODUCT.Product_Status%TYPE;
    v_exists        NUMBER;
BEGIN
    IF P_QUANTITY IS NULL OR P_QUANTITY <= 0 THEN
        RAISE_APPLICATION_ERROR(-20210, 'Quantity must be greater than zero.');
    END IF;

    BEGIN
        SELECT Order_Status INTO v_order_status
        FROM   CUSTOMER_ORDER
        WHERE  Order_ID = P_ORDER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20211, 'Order ' || P_ORDER_ID || ' does not exist.');
    END;

    IF v_order_status <> 'PENDING' THEN
        RAISE_APPLICATION_ERROR(-20212,
            'Items can be added only to a PENDING order. Order ' || P_ORDER_ID || ' is ' || v_order_status || '.');
    END IF;

    BEGIN
        SELECT Unit_Price, Stock_Quantity, Product_Status
        INTO   v_price, v_stock, v_prod_status
        FROM   PRODUCT
        WHERE  Product_ID = P_PRODUCT_ID
        FOR UPDATE;                                  -- lock the product row
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20213, 'Product ' || P_PRODUCT_ID || ' does not exist.');
    END;

    IF v_prod_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20214,
            'Product ' || P_PRODUCT_ID || ' is ' || v_prod_status || ' and cannot be ordered.');
    END IF;

    IF P_QUANTITY > v_stock THEN
        RAISE_APPLICATION_ERROR(-20215,
            'Insufficient stock for product ' || P_PRODUCT_ID ||
            '. Available: ' || v_stock || ', requested: ' || P_QUANTITY || '.');
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM   ORDER_ITEM
    WHERE  Order_ID = P_ORDER_ID AND Product_ID = P_PRODUCT_ID;

    IF v_exists > 0 THEN
        RAISE_APPLICATION_ERROR(-20216,
            'Product ' || P_PRODUCT_ID || ' is already in order ' || P_ORDER_ID ||
            '. Update its quantity instead of adding it again.');
    END IF;

    INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity, Unit_Price)
    VALUES (P_ORDER_ID, P_PRODUCT_ID, P_QUANTITY, v_price);   -- trigger reduces stock

    DBMS_OUTPUT.PUT_LINE('Added product ' || P_PRODUCT_ID || ' x ' || P_QUANTITY ||
                         ' @ ' || v_price || ' to order ' || P_ORDER_ID || '.');
END PR_ADD_ORDER_ITEM;
/

-- =====================================================================
-- PROCEDURE 3 : PR_CONFIRM_ORDER
--   P_ORDER_ID (IN) order to confirm.
--   Checks: order exists, is PENDING, has at least one item.
--   A foreign key cannot check "an order has at least one item", so this
--   check is done here (and again by TRG_ORDER_STATUS_RULES).
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_CONFIRM_ORDER (P_ORDER_ID IN NUMBER)
IS
    v_status  CUSTOMER_ORDER.Order_Status%TYPE;
    v_items   NUMBER;
BEGIN
    BEGIN
        SELECT Order_Status INTO v_status
        FROM   CUSTOMER_ORDER
        WHERE  Order_ID = P_ORDER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20221, 'Order ' || P_ORDER_ID || ' does not exist.');
    END;

    IF v_status <> 'PENDING' THEN
        RAISE_APPLICATION_ERROR(-20222,
            'Only a PENDING order can be confirmed. Order ' || P_ORDER_ID || ' is ' || v_status || '.');
    END IF;

    SELECT COUNT(*) INTO v_items FROM ORDER_ITEM WHERE Order_ID = P_ORDER_ID;

    IF v_items = 0 THEN
        RAISE_APPLICATION_ERROR(-20223,
            'Order ' || P_ORDER_ID || ' has no items. Add at least one item before confirming.');
    END IF;

    UPDATE CUSTOMER_ORDER SET Order_Status = 'CONFIRMED' WHERE Order_ID = P_ORDER_ID;

    DBMS_OUTPUT.PUT_LINE('Order ' || P_ORDER_ID || ' confirmed with ' || v_items ||
                         ' item(s). Total = ' || FN_ORDER_TOTAL(P_ORDER_ID));
END PR_CONFIRM_ORDER;
/

-- =====================================================================
-- PROCEDURE 4 : PR_RECORD_PAYMENT
--   P_ORDER_ID   (IN)  order being paid (must exist, not CANCELLED, have items)
--   P_METHOD     (IN)  UPI / CARD / NET_BANKING / COD / WALLET
--   P_AMOUNT     (IN)  amount (> 0 and not more than the order total)
--   P_REFERENCE  (IN)  transaction reference (required except for COD)
--   P_PAYMENT_ID (OUT) new Payment_ID
--   P_STATUS     (IN, default SUCCESS) PENDING / SUCCESS / FAILED
--   Only one payment per order is allowed (also enforced by UQ_PAYMENT_ORDER).
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_RECORD_PAYMENT (
    P_ORDER_ID    IN  NUMBER,
    P_METHOD      IN  VARCHAR2,
    P_AMOUNT      IN  NUMBER,
    P_REFERENCE   IN  VARCHAR2,
    P_PAYMENT_ID  OUT NUMBER,
    P_STATUS      IN  VARCHAR2 DEFAULT 'SUCCESS'
)
IS
    v_order_status  CUSTOMER_ORDER.Order_Status%TYPE;
    v_total         NUMBER(12,2);
    v_method        PAYMENT.Payment_Method%TYPE := UPPER(TRIM(P_METHOD));
    v_status        PAYMENT.Payment_Status%TYPE := UPPER(TRIM(P_STATUS));
    v_existing      NUMBER;
BEGIN
    BEGIN
        SELECT Order_Status INTO v_order_status
        FROM   CUSTOMER_ORDER
        WHERE  Order_ID = P_ORDER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20231, 'Order ' || P_ORDER_ID || ' does not exist.');
    END;

    IF v_order_status = 'CANCELLED' THEN
        RAISE_APPLICATION_ERROR(-20232, 'Order ' || P_ORDER_ID || ' is CANCELLED. Payment not allowed.');
    END IF;

    v_total := FN_ORDER_TOTAL(P_ORDER_ID);
    IF v_total = 0 THEN
        RAISE_APPLICATION_ERROR(-20233, 'Order ' || P_ORDER_ID || ' has no items, so nothing can be paid.');
    END IF;

    IF P_AMOUNT IS NULL OR P_AMOUNT <= 0 THEN
        RAISE_APPLICATION_ERROR(-20234, 'Payment amount must be greater than zero.');
    END IF;

    IF P_AMOUNT > v_total THEN
        RAISE_APPLICATION_ERROR(-20235,
            'Payment amount ' || P_AMOUNT || ' is more than the order total ' || v_total || '.');
    END IF;

    IF v_method IS NULL OR v_method NOT IN ('UPI', 'CARD', 'NET_BANKING', 'COD', 'WALLET') THEN
        RAISE_APPLICATION_ERROR(-20236,
            'Invalid payment method "' || P_METHOD || '". Use UPI, CARD, NET_BANKING, COD or WALLET.');
    END IF;

    IF v_method <> 'COD' AND P_REFERENCE IS NULL THEN
        RAISE_APPLICATION_ERROR(-20237, 'Transaction reference is required for ' || v_method || ' payments.');
    END IF;

    IF v_status IS NULL OR v_status NOT IN ('PENDING', 'SUCCESS', 'FAILED') THEN
        RAISE_APPLICATION_ERROR(-20238, 'A new payment status must be PENDING, SUCCESS or FAILED.');
    END IF;

    SELECT COUNT(*) INTO v_existing FROM PAYMENT WHERE Order_ID = P_ORDER_ID;
    IF v_existing > 0 THEN
        RAISE_APPLICATION_ERROR(-20239,
            'Order ' || P_ORDER_ID || ' already has a payment. Only one payment per order is allowed.');
    END IF;

    INSERT INTO PAYMENT (Order_ID, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
    VALUES (P_ORDER_ID, v_method, P_AMOUNT, P_REFERENCE, v_status)
    RETURNING Payment_ID INTO P_PAYMENT_ID;

    DBMS_OUTPUT.PUT_LINE('Payment ' || P_PAYMENT_ID || ' recorded: ' || v_method || ' ' || P_AMOUNT ||
                         ' (' || v_status || ') for order ' || P_ORDER_ID || '.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20240,
            'Duplicate payment: this order already has a payment or the transaction reference "'
            || P_REFERENCE || '" is already used.');
END PR_RECORD_PAYMENT;
/

-- =====================================================================
-- PROCEDURE 5 : PR_CREATE_RETURN_REQUEST
--   P_ORDER_ID    (IN)  order of the returned item
--   P_PRODUCT_ID  (IN)  product being returned (must be in that order)
--   P_RETURN_QTY  (IN)  quantity (> 0 and <= ordered quantity)
--   P_REASON      (IN)  reason text
--   P_RETURN_ID   (OUT) new Return_ID
--   Creates the request with status REQUESTED and refund 0. The refund is
--   filled in later when the return is approved / refunded.
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_CREATE_RETURN_REQUEST (
    P_ORDER_ID    IN  NUMBER,
    P_PRODUCT_ID  IN  NUMBER,
    P_RETURN_QTY  IN  NUMBER,
    P_REASON      IN  VARCHAR2,
    P_RETURN_ID   OUT NUMBER
)
IS
    v_ordered_qty   ORDER_ITEM.Quantity%TYPE;
    v_order_status  CUSTOMER_ORDER.Order_Status%TYPE;
    v_existing      NUMBER;
BEGIN
    BEGIN
        SELECT oi.Quantity, co.Order_Status
        INTO   v_ordered_qty, v_order_status
        FROM   ORDER_ITEM oi
               JOIN CUSTOMER_ORDER co ON co.Order_ID = oi.Order_ID
        WHERE  oi.Order_ID = P_ORDER_ID
        AND    oi.Product_ID = P_PRODUCT_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20251,
                'Product ' || P_PRODUCT_ID || ' was not ordered in order ' || P_ORDER_ID || '.');
    END;

    IF v_order_status <> 'DELIVERED' THEN
        RAISE_APPLICATION_ERROR(-20252,
            'Returns are allowed only for DELIVERED orders. Order ' || P_ORDER_ID || ' is ' || v_order_status || '.');
    END IF;

    IF P_RETURN_QTY IS NULL OR P_RETURN_QTY <= 0 THEN
        RAISE_APPLICATION_ERROR(-20253, 'Return quantity must be greater than zero.');
    END IF;

    IF P_RETURN_QTY > v_ordered_qty THEN
        RAISE_APPLICATION_ERROR(-20254,
            'Return quantity ' || P_RETURN_QTY || ' is more than the ordered quantity ' || v_ordered_qty || '.');
    END IF;

    SELECT COUNT(*) INTO v_existing
    FROM   RETURN_REQUEST
    WHERE  Order_ID = P_ORDER_ID AND Product_ID = P_PRODUCT_ID;

    IF v_existing > 0 THEN
        RAISE_APPLICATION_ERROR(-20255,
            'A return request already exists for product ' || P_PRODUCT_ID || ' in order ' || P_ORDER_ID ||
            '. Only one return per order item is allowed.');
    END IF;

    INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
    VALUES (P_ORDER_ID, P_PRODUCT_ID, P_RETURN_QTY, P_REASON, 'REQUESTED', 0)
    RETURNING Return_ID INTO P_RETURN_ID;

    DBMS_OUTPUT.PUT_LINE('Return request ' || P_RETURN_ID || ' created for product ' || P_PRODUCT_ID ||
                         ' (qty ' || P_RETURN_QTY || ') in order ' || P_ORDER_ID || '.');
END PR_CREATE_RETURN_REQUEST;
/

-- =====================================================================
-- PROCEDURE 6 : PR_UPDATE_ORDER_STATUS
--   P_ORDER_ID   (IN) order to change
--   P_NEW_STATUS (IN) PENDING / CONFIRMED / SHIPPED / DELIVERED / CANCELLED
--   Checks the value is valid and different from the current one.
--   The allowed path (PENDING->CONFIRMED->SHIPPED->DELIVERED, cancel from
--   PENDING or CONFIRMED) and the stock restore on CANCELLED are done by
--   trigger TRG_ORDER_STATUS_RULES, so they also apply to plain UPDATEs.
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_UPDATE_ORDER_STATUS (
    P_ORDER_ID    IN NUMBER,
    P_NEW_STATUS  IN VARCHAR2
)
IS
    v_new  CUSTOMER_ORDER.Order_Status%TYPE := UPPER(TRIM(P_NEW_STATUS));
    v_old  CUSTOMER_ORDER.Order_Status%TYPE;
BEGIN
    IF v_new IS NULL OR v_new NOT IN ('PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED') THEN
        RAISE_APPLICATION_ERROR(-20261,
            'Invalid order status "' || P_NEW_STATUS || '". Use PENDING, CONFIRMED, SHIPPED, DELIVERED or CANCELLED.');
    END IF;

    BEGIN
        SELECT Order_Status INTO v_old
        FROM   CUSTOMER_ORDER
        WHERE  Order_ID = P_ORDER_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20262, 'Order ' || P_ORDER_ID || ' does not exist.');
    END;

    IF v_old = v_new THEN
        RAISE_APPLICATION_ERROR(-20263, 'Order ' || P_ORDER_ID || ' is already ' || v_new || '.');
    END IF;

    UPDATE CUSTOMER_ORDER SET Order_Status = v_new WHERE Order_ID = P_ORDER_ID;  -- trigger validates

    DBMS_OUTPUT.PUT_LINE('Order ' || P_ORDER_ID || ' status changed: ' || v_old || ' -> ' || v_new || '.');
END PR_UPDATE_ORDER_STATUS;
/

-- =====================================================================
-- PROCEDURE 7 : PR_REGISTER_CUSTOMER
--   Registers a customer AND the first phone number together, so the rule
--   "every customer has at least one phone" (which a foreign key cannot
--   enforce) is kept. If the phone insert fails, the customer insert is
--   undone too (ROLLBACK TO SAVEPOINT inside the procedure).
--   P_FIRST_NAME, P_LAST_NAME, P_EMAIL, P_STREET, P_CITY, P_STATE,
--   P_POSTAL, P_PHONE (IN)  customer details and first phone
--   P_CUSTOMER_ID (OUT)     new Customer_ID
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_REGISTER_CUSTOMER (
    P_FIRST_NAME   IN  VARCHAR2,
    P_LAST_NAME    IN  VARCHAR2,
    P_EMAIL        IN  VARCHAR2,
    P_STREET       IN  VARCHAR2,
    P_CITY         IN  VARCHAR2,
    P_STATE        IN  VARCHAR2,
    P_POSTAL       IN  VARCHAR2,
    P_PHONE        IN  VARCHAR2,
    P_CUSTOMER_ID  OUT NUMBER
)
IS
BEGIN
    SAVEPOINT sp_register;      -- first statement, so the handlers can always roll back to it

    IF P_PHONE IS NULL THEN
        RAISE_APPLICATION_ERROR(-20271, 'At least one phone number is required to register a customer.');
    END IF;

    INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code)
    VALUES (P_FIRST_NAME, P_LAST_NAME, P_EMAIL, P_STREET, P_CITY, P_STATE, P_POSTAL)
    RETURNING Customer_ID INTO P_CUSTOMER_ID;

    INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (P_CUSTOMER_ID, P_PHONE);

    DBMS_OUTPUT.PUT_LINE('Customer ' || P_CUSTOMER_ID || ' registered with phone ' || P_PHONE || '.');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK TO sp_register;
        RAISE_APPLICATION_ERROR(-20272, 'Email ' || LOWER(P_EMAIL) || ' is already registered.');
    WHEN OTHERS THEN
        ROLLBACK TO sp_register;
        RAISE;
END PR_REGISTER_CUSTOMER;
/

-- =====================================================================
-- PROCEDURE 8 (CURSOR) : PR_AUTO_RESTOCK
--   Business use: every evening the store manager restocks all ACTIVE
--   products that are at or below their reorder level.
--   An EXPLICIT CURSOR (c_low) selects those products. The loop FETCHes
--   them one by one and sets the stock to Reorder_Level x P_MULTIPLE.
--   FOR UPDATE locks the rows; WHERE CURRENT OF updates the row the
--   cursor is on.
--   P_MULTIPLE        (IN, default 3) new stock = reorder level x this
--   P_RESTOCKED_COUNT (OUT)           number of products restocked
--   Note: this is purchasing new stock - a different event from orders,
--   so it does not conflict with the inventory trigger.
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_AUTO_RESTOCK (
    P_MULTIPLE         IN  NUMBER DEFAULT 3,
    P_RESTOCKED_COUNT  OUT NUMBER
)
IS
    CURSOR c_low IS
        SELECT Product_ID, Product_Name, Stock_Quantity, Reorder_Level
        FROM   PRODUCT
        WHERE  Product_Status = 'ACTIVE'
        AND    Stock_Quantity <= Reorder_Level
        ORDER  BY Product_ID
        FOR UPDATE OF Stock_Quantity;

    v_row        c_low%ROWTYPE;
    v_new_stock  PRODUCT.Stock_Quantity%TYPE;
BEGIN
    IF P_MULTIPLE IS NULL OR P_MULTIPLE < 2 THEN
        RAISE_APPLICATION_ERROR(-20281, 'Restock multiple must be 2 or more.');
    END IF;

    P_RESTOCKED_COUNT := 0;

    OPEN c_low;
    LOOP
        FETCH c_low INTO v_row;
        EXIT WHEN c_low%NOTFOUND;

        v_new_stock := GREATEST(v_row.Reorder_Level * P_MULTIPLE, v_row.Reorder_Level + 1);

        UPDATE PRODUCT
        SET    Stock_Quantity = v_new_stock
        WHERE  CURRENT OF c_low;

        P_RESTOCKED_COUNT := P_RESTOCKED_COUNT + 1;
        DBMS_OUTPUT.PUT_LINE('Restocked ' || v_row.Product_ID || ' ' || v_row.Product_Name ||
                             ': ' || v_row.Stock_Quantity || ' -> ' || v_new_stock);
    END LOOP;
    CLOSE c_low;

    DBMS_OUTPUT.PUT_LINE(P_RESTOCKED_COUNT || ' product(s) restocked.');
EXCEPTION
    WHEN OTHERS THEN
        IF c_low%ISOPEN THEN
            CLOSE c_low;
        END IF;
        RAISE;
END PR_AUTO_RESTOCK;
/

-- =====================================================================
-- PROCEDURE 9 (CURSOR) : PR_PROCESS_APPROVED_REFUNDS
--   Business use: the accounts team pays out all APPROVED returns at once.
--   An explicit cursor reads every APPROVED return with its selling price;
--   each one gets Refund_Amount = Return_Quantity x selling price and
--   status REFUNDED. TRG_RETURN_VALIDATE still checks every row.
--   P_REFUND_COUNT (OUT)  number of returns refunded
--   P_REFUND_TOTAL (OUT)  total money refunded
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_PROCESS_APPROVED_REFUNDS (
    P_REFUND_COUNT  OUT NUMBER,
    P_REFUND_TOTAL  OUT NUMBER
)
IS
    CURSOR c_approved IS
        SELECT r.Return_ID, r.Order_ID, r.Product_ID, r.Return_Quantity, oi.Unit_Price
        FROM   RETURN_REQUEST r
               JOIN ORDER_ITEM oi ON oi.Order_ID = r.Order_ID AND oi.Product_ID = r.Product_ID
        WHERE  r.Return_Status = 'APPROVED'
        ORDER  BY r.Return_ID
        FOR UPDATE OF r.Return_Status, r.Refund_Amount;

    v_amount  NUMBER(12,2);
BEGIN
    P_REFUND_COUNT := 0;
    P_REFUND_TOTAL := 0;

    FOR rec IN c_approved LOOP          -- cursor FOR loop: opens, fetches and closes automatically
        v_amount := rec.Return_Quantity * rec.Unit_Price;

        UPDATE RETURN_REQUEST
        SET    Return_Status = 'REFUNDED',
               Refund_Amount = v_amount
        WHERE  CURRENT OF c_approved;

        P_REFUND_COUNT := P_REFUND_COUNT + 1;
        P_REFUND_TOTAL := P_REFUND_TOTAL + v_amount;
        DBMS_OUTPUT.PUT_LINE('Return ' || rec.Return_ID || ' (order ' || rec.Order_ID ||
                             ', product ' || rec.Product_ID || ') refunded ' || v_amount);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(P_REFUND_COUNT || ' refund(s) processed, total ' || P_REFUND_TOTAL || '.');
END PR_PROCESS_APPROVED_REFUNDS;
/

-- Check compilation
SELECT object_name, object_type, status
FROM   USER_OBJECTS
WHERE  object_type IN ('FUNCTION', 'PROCEDURE')
ORDER  BY object_type, object_name;

SELECT name, type, line, position, text FROM USER_ERRORS
WHERE  type IN ('FUNCTION', 'PROCEDURE') ORDER BY name, sequence;

-- #####################################################################
-- PART 7 : contents of 08_views.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 08_views.sql
-- PURPOSE   : Ready-made reports. A view is a saved SELECT query; it
--             stores no data of its own and always shows current data.
-- =====================================================================
SET DEFINE OFF

-- 1. Product, category, stock, reorder level and calculated stock status
CREATE OR REPLACE VIEW VW_PRODUCT_STOCK_STATUS AS
SELECT p.Product_ID,
       p.Product_Name,
       c.Category_Name,
       p.Unit_Price,
       p.Stock_Quantity,
       p.Reorder_Level,
       p.Stock_Status,          -- virtual column: IN STOCK / LOW STOCK / OUT OF STOCK
       p.Product_Status
FROM   PRODUCT p
       JOIN CATEGORY c ON c.Category_ID = p.Category_ID;

-- 2. One row per order: customer, totals and payment.
--    LEFT JOINs keep orders that have no items yet or no payment yet.
CREATE OR REPLACE VIEW VW_ORDER_SUMMARY AS
SELECT co.Order_ID,
       c.First_Name || ' ' || c.Last_Name       AS Customer_Name,
       co.Order_Date,
       co.Order_Status,
       NVL(SUM(oi.Quantity), 0)                 AS Total_Quantity,
       NVL(SUM(oi.Item_Subtotal), 0)            AS Total_Order_Value,
       NVL(p.Payment_Status, 'NO PAYMENT')      AS Payment_Status,
       NVL(p.Payment_Method, '-')               AS Payment_Method
FROM   CUSTOMER_ORDER co
       JOIN      CUSTOMER   c  ON c.Customer_ID = co.Customer_ID
       LEFT JOIN ORDER_ITEM oi ON oi.Order_ID   = co.Order_ID
       LEFT JOIN PAYMENT    p  ON p.Order_ID    = co.Order_ID
GROUP  BY co.Order_ID, c.First_Name, c.Last_Name, co.Order_Date, co.Order_Status,
          p.Payment_Status, p.Payment_Method;

-- 3. Customers, their orders, products, quantities and item values
CREATE OR REPLACE VIEW VW_CUSTOMER_ORDER_HISTORY AS
SELECT c.Customer_ID,
       c.First_Name || ' ' || c.Last_Name  AS Customer_Name,
       co.Order_ID,
       co.Order_Date,
       co.Order_Status,
       p.Product_ID,
       p.Product_Name,
       oi.Quantity,
       oi.Unit_Price                       AS Selling_Price,
       oi.Item_Subtotal                    AS Item_Value
FROM   CUSTOMER c
       JOIN CUSTOMER_ORDER co ON co.Customer_ID = c.Customer_ID
       JOIN ORDER_ITEM     oi ON oi.Order_ID    = co.Order_ID
       JOIN PRODUCT        p  ON p.Product_ID   = oi.Product_ID;

-- 4. Products at or below their reorder level (need restocking)
CREATE OR REPLACE VIEW VW_LOW_STOCK_PRODUCTS AS
SELECT p.Product_ID,
       p.Product_Name,
       c.Category_Name,
       p.Stock_Quantity,
       p.Reorder_Level,
       p.Reorder_Level - p.Stock_Quantity  AS Units_Below_Reorder,
       p.Stock_Status,
       p.Product_Status
FROM   PRODUCT p
       JOIN CATEGORY c ON c.Category_ID = p.Category_ID
WHERE  p.Stock_Quantity <= p.Reorder_Level;

-- 5. Return requests with customer, order and product details
CREATE OR REPLACE VIEW VW_RETURN_DETAILS AS
SELECT r.Return_ID,
       r.Return_Date,
       c.Customer_ID,
       c.First_Name || ' ' || c.Last_Name  AS Customer_Name,
       r.Order_ID,
       co.Order_Date,
       r.Product_ID,
       p.Product_Name,
       oi.Quantity                         AS Ordered_Quantity,
       r.Return_Quantity,
       r.Return_Reason,
       r.Return_Status,
       r.Refund_Amount
FROM   RETURN_REQUEST r
       JOIN ORDER_ITEM     oi ON oi.Order_ID = r.Order_ID AND oi.Product_ID = r.Product_ID
       JOIN CUSTOMER_ORDER co ON co.Order_ID = r.Order_ID
       JOIN CUSTOMER       c  ON c.Customer_ID = co.Customer_ID
       JOIN PRODUCT        p  ON p.Product_ID = r.Product_ID;

SELECT view_name FROM USER_VIEWS ORDER BY view_name;

-- #####################################################################
-- PART 8 : contents of 09_sample_data.sql
-- #####################################################################
-- =====================================================================
-- FILE      : 09_sample_data.sql
-- PURPOSE   : Realistic Indian sample data (at least 10 rows in every
--             table), inserted in foreign-key order.
--
-- Run this right after files 02-08 (fresh sequences), so the generated IDs
-- are exactly: customers 101-112, categories 1-10, products 1001-1020,
-- orders 5001-5015, payments 9001-9014, returns 7001-7010.
--
-- Notes:
--  * IDs are NOT typed - the BEFORE INSERT triggers generate them.
--  * ORDER_ITEM.Unit_Price is NOT typed - the inventory trigger copies
--    the current product price and reduces stock automatically.
--  * Virtual columns (Stock_Status, Item_Subtotal) are never inserted.
--  * Orders are inserted as PENDING (required), items are added, and then
--    the status is moved forward step by step, exactly as in real life.
--  * SET DEFINE OFF stops SQL Developer asking for a value for "&"
--    in names such as 'Home & Kitchen'.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------
-- 1. CATEGORY  (IDs 1-10)
-- ---------------------------------------------------------------------
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Electronics', 'Mobiles, audio devices, chargers and accessories');  -- 1
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Fashion', 'Clothing, ethnic wear and footwear');  -- 2
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Home & Kitchen', 'Cookware, kitchen appliances and dining items');  -- 3
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Books', 'Academic textbooks and competitive exam guides');  -- 4
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Beauty & Personal Care', 'Skin care, hair care and grooming products');  -- 5
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Sports & Fitness', 'Fitness gear and sports equipment');  -- 6
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Toys & Games', 'Board games, puzzles and toys');  -- 7
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Grocery', 'Staples, rice, pulses and packaged food');  -- 8
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Stationery', 'Pens, notebooks and office supplies');  -- 9
INSERT INTO CATEGORY (Category_Name, Category_Description) VALUES ('Furniture', 'Chairs, tables and study furniture');  -- 10

-- ---------------------------------------------------------------------
-- 2. PRODUCT  (IDs 1001-1020)
-- ---------------------------------------------------------------------
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (1, 'Wireless Bluetooth Headphones', 'Over-ear headphones with 30-hour battery and mic', 1499, 40, 10, 'ACTIVE');  -- 1001
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (1, 'Smartphone 128 GB', '6.5-inch display, 8 GB RAM, 128 GB storage, 5G', 15999, 15, 5, 'ACTIVE');  -- 1002
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (1, '65W USB-C Fast Charger', 'Dual-port fast charger with Type-C cable', 899, 6, 5, 'ACTIVE');  -- 1003
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (2, 'Men''s Cotton Kurta', 'Handloom cotton kurta, regular fit', 799, 50, 10, 'ACTIVE');  -- 1004
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (2, 'Banarasi Silk Saree', 'Pure silk saree with zari border', 2499, 12, 4, 'ACTIVE');  -- 1005
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (2, 'Running Shoes', 'Lightweight mesh running shoes', 2199, 3, 5, 'ACTIVE');  -- 1006
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (3, 'Non-Stick Kadai 28 cm', 'Induction-friendly non-stick kadai with lid', 1199, 25, 8, 'ACTIVE');  -- 1007
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (3, 'Stainless Steel Pressure Cooker 5 L', 'ISI-marked pressure cooker', 1899, 10, 5, 'ACTIVE');  -- 1008
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (4, 'Database System Concepts', 'Textbook for a database systems course', 950, 20, 5, 'ACTIVE');  -- 1009
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (4, 'Indian Polity Guide', 'Reference book for competitive exams', 649, 4, 5, 'ACTIVE');  -- 1010
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (1, 'Wired Earphones (Old Model)', '3.5 mm wired earphones, model discontinued', 299, 0, 5, 'DISCONTINUED');  -- 1011
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (3, 'Ceramic Dinner Set (24 pcs)', 'Microwave-safe ceramic dinner set', 3499, 8, 3, 'INACTIVE');  -- 1012
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (5, 'Herbal Neem Face Wash 150 ml', 'Soap-free face wash with neem and tulsi', 249, 60, 15, 'ACTIVE');  -- 1013
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (5, 'Ayurvedic Hair Oil 200 ml', 'Bhringraj and amla hair oil', 399, 35, 10, 'ACTIVE');  -- 1014
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (6, 'Yoga Mat 6 mm', 'Anti-slip yoga mat with carry strap', 899, 25, 8, 'ACTIVE');  -- 1015
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (6, 'Kashmir Willow Cricket Bat', 'Full-size Kashmir willow bat', 1799, 12, 4, 'ACTIVE');  -- 1016
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (7, 'Wooden Chess Set', 'Folding wooden chess board with pieces', 699, 18, 5, 'ACTIVE');  -- 1017
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (8, 'Basmati Rice 5 kg', 'Aged long-grain basmati rice', 649, 40, 10, 'ACTIVE');  -- 1018
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (9, 'Gel Pen Pack (10 pens)', 'Smooth blue gel pens, pack of 10', 120, 100, 20, 'ACTIVE');  -- 1019
INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price, Stock_Quantity, Reorder_Level, Product_Status)
VALUES (10, 'Ergonomic Study Chair', 'Mesh back chair with lumbar support', 5499, 4, 3, 'ACTIVE');  -- 1020

-- ---------------------------------------------------------------------
-- 3. CUSTOMER  (IDs 101-112)
-- ---------------------------------------------------------------------
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Aarav', 'Sharma', 'aarav.sharma@gmail.com', '12 MG Road', 'Bengaluru', 'Karnataka', '560001', TO_DATE('05-01-2026', 'DD-MM-YYYY'));  -- 101
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Priya', 'Iyer', 'priya.iyer@yahoo.com', '45 Anna Salai', 'Chennai', 'Tamil Nadu', '600002', TO_DATE('12-02-2026', 'DD-MM-YYYY'));  -- 102
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Rohan', 'Das', 'rohan.das@outlook.com', '7 Park Street', 'Kolkata', 'West Bengal', '700016', TO_DATE('20-03-2026', 'DD-MM-YYYY'));  -- 103
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Sneha', 'Patel', 'sneha.patel@gmail.com', '22 CG Road', 'Ahmedabad', 'Gujarat', '380009', TO_DATE('02-04-2026', 'DD-MM-YYYY'));  -- 104
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Vikram', 'Singh', 'vikram.singh@rediffmail.com', '18 Hazratganj', 'Lucknow', 'Uttar Pradesh', '226001', TO_DATE('15-05-2026', 'DD-MM-YYYY'));  -- 105
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Kavya', 'Reddy', 'kavya.reddy@gmail.com', '8-2-293 Banjara Hills', 'Hyderabad', 'Telangana', '500034', TO_DATE('08-01-2026', 'DD-MM-YYYY'));  -- 106
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Arjun', 'Mehta', 'arjun.mehta@hotmail.com', '14 Linking Road, Bandra', 'Mumbai', 'Maharashtra', '400050', TO_DATE('19-01-2026', 'DD-MM-YYYY'));  -- 107
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Ishita', 'Banerjee', 'ishita.banerjee@gmail.com', '56 Gariahat Road', 'Kolkata', 'West Bengal', '700019', TO_DATE('27-02-2026', 'DD-MM-YYYY'));  -- 108
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Rahul', 'Verma', 'rahul.verma@yahoo.in', '9 Civil Lines', 'Jaipur', 'Rajasthan', '302006', TO_DATE('10-03-2026', 'DD-MM-YYYY'));  -- 109
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Neha', 'Kapoor', 'neha.kapoor@gmail.com', 'C-45 Lajpat Nagar', 'New Delhi', 'Delhi', '110024', TO_DATE('28-03-2026', 'DD-MM-YYYY'));  -- 110
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Siddharth', 'Nair', 'siddharth.nair@gmail.com', '12 MG Road, Ernakulam', 'Kochi', 'Kerala', '682016', TO_DATE('14-04-2026', 'DD-MM-YYYY'));  -- 111
INSERT INTO CUSTOMER (First_Name, Last_Name, Email, Street, City, State, Postal_Code, Registration_Date)
VALUES ('Pooja', 'Joshi', 'pooja.joshi@outlook.com', '31 FC Road', 'Pune', 'Maharashtra', '411004', TO_DATE('22-05-2026', 'DD-MM-YYYY'));  -- 112

-- ---------------------------------------------------------------------
-- 4. CUSTOMER_PHONE  (16 numbers; 101, 103, 107, 110 have two each)
-- ---------------------------------------------------------------------
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (101, '9876543210');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (101, '9123456780');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (102, '9988776655');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (103, '9830012345');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (103, '9007654321');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (104, '9898989898');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (105, '9415001122');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (106, '9849012345');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (107, '9820098200');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (107, '9167712345');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (108, '9874561230');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (109, '9829011223');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (110, '9811122233');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (110, '9718899001');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (111, '9447012345');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (112, '9822334455');

-- ---------------------------------------------------------------------
-- 5. ORDERS + ORDER ITEMS (stock reduces automatically on each item)
-- ---------------------------------------------------------------------
-- Order 5001 : customer 101, 10-06-2026 -> DELIVERED  (1 x 1499 + 1 x 1199 = 2698)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (101, TO_DATE('10-06-2026', 'DD-MM-YYYY'), '12 MG Road', 'Bengaluru', 'Karnataka', '560001');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5001, 1001, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5001, 1007, 1);

-- Order 5002 : customer 102, 18-06-2026 -> DELIVERED  (1 x 2499 + 2 x 799 = 4097)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (102, TO_DATE('18-06-2026', 'DD-MM-YYYY'), '45 Anna Salai', 'Chennai', 'Tamil Nadu', '600002');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5002, 1005, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5002, 1004, 2);

-- Order 5003 : customer 103, 05-07-2026 -> SHIPPED  (1 x 15999 + 2 x 899 = 17797)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (103, TO_DATE('05-07-2026', 'DD-MM-YYYY'), 'Plot 5, Sector V, Salt Lake', 'Kolkata', 'West Bengal', '700091');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5003, 1002, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5003, 1003, 2);

-- Order 5004 : customer 101, 22-07-2026 -> DELIVERED  (2 x 950 + 1 x 649 = 2549)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (101, TO_DATE('22-07-2026', 'DD-MM-YYYY'), '12 MG Road', 'Bengaluru', 'Karnataka', '560001');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5004, 1009, 2);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5004, 1010, 1);

-- Order 5005 : customer 104, 03-08-2026 -> CONFIRMED  (1 x 1899 + 4 x 899 = 5495)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (104, TO_DATE('03-08-2026', 'DD-MM-YYYY'), '22 CG Road', 'Ahmedabad', 'Gujarat', '380009');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5005, 1008, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5005, 1003, 4);

-- Order 5006 : customer 103, 15-08-2026 -> PENDING  (1 x 2199 + 1 x 799 = 2998)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (103, TO_DATE('15-08-2026', 'DD-MM-YYYY'), '7 Park Street', 'Kolkata', 'West Bengal', '700016');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5006, 1006, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5006, 1004, 1);

-- Order 5007 : customer 102, 01-09-2026 -> CANCELLED  (2 x 1199 = 2398)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (102, TO_DATE('01-09-2026', 'DD-MM-YYYY'), '45 Anna Salai', 'Chennai', 'Tamil Nadu', '600002');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5007, 1007, 2);

-- Order 5008 : customer 106, 12-06-2026 -> DELIVERED  (3 x 249 + 2 x 399 = 1545)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (106, TO_DATE('12-06-2026', 'DD-MM-YYYY'), '8-2-293 Banjara Hills', 'Hyderabad', 'Telangana', '500034');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5008, 1013, 3);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5008, 1014, 2);

-- Order 5009 : customer 107, 25-06-2026 -> DELIVERED  (1 x 899 + 1 x 1799 = 2698)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (107, TO_DATE('25-06-2026', 'DD-MM-YYYY'), '14 Linking Road, Bandra', 'Mumbai', 'Maharashtra', '400050');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5009, 1015, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5009, 1016, 1);

-- Order 5010 : customer 108, 08-07-2026 -> DELIVERED  (1 x 699 + 5 x 120 = 1299)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (108, TO_DATE('08-07-2026', 'DD-MM-YYYY'), '56 Gariahat Road', 'Kolkata', 'West Bengal', '700019');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5010, 1017, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5010, 1019, 5);

-- Order 5011 : customer 109, 19-07-2026 -> DELIVERED  (2 x 649 + 2 x 249 = 1796)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (109, TO_DATE('19-07-2026', 'DD-MM-YYYY'), '9 Civil Lines', 'Jaipur', 'Rajasthan', '302006');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5011, 1018, 2);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5011, 1013, 2);

-- Order 5012 : customer 110, 06-08-2026 -> DELIVERED  (1 x 5499 + 1 x 899 = 6398)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (110, TO_DATE('06-08-2026', 'DD-MM-YYYY'), 'Tower B, Cyber City', 'Gurugram', 'Haryana', '122002');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5012, 1020, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5012, 1015, 1);

-- Order 5013 : customer 111, 20-08-2026 -> DELIVERED  (1 x 1499 + 1 x 950 = 2449)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (111, TO_DATE('20-08-2026', 'DD-MM-YYYY'), '12 MG Road, Ernakulam', 'Kochi', 'Kerala', '682016');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5013, 1001, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5013, 1009, 1);

-- Order 5014 : customer 106, 05-09-2026 -> SHIPPED  (1 x 399 + 2 x 120 = 639)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (106, TO_DATE('05-09-2026', 'DD-MM-YYYY'), '8-2-293 Banjara Hills', 'Hyderabad', 'Telangana', '500034');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5014, 1014, 1);
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5014, 1019, 2);

-- Order 5015 : customer 110, 12-09-2026 -> PENDING  (1 x 1799 = 1799)
INSERT INTO CUSTOMER_ORDER (Customer_ID, Order_Date, Shipping_Street, Shipping_City, Shipping_State, Shipping_Postal_Code)
VALUES (110, TO_DATE('12-09-2026', 'DD-MM-YYYY'), 'C-45 Lajpat Nagar', 'New Delhi', 'Delhi', '110024');
INSERT INTO ORDER_ITEM (Order_ID, Product_ID, Quantity) VALUES (5015, 1016, 1);

-- ---------------------------------------------------------------------
-- 6. Move order statuses forward (trigger checks every step;
--    cancelling 5007 puts its 2 kadais back into stock)
-- ---------------------------------------------------------------------
UPDATE CUSTOMER_ORDER SET Order_Status = 'CONFIRMED' WHERE Order_ID IN (5001, 5002, 5003, 5004, 5005, 5008, 5009, 5010, 5011, 5012, 5013, 5014);
UPDATE CUSTOMER_ORDER SET Order_Status = 'SHIPPED' WHERE Order_ID IN (5001, 5002, 5003, 5004, 5008, 5009, 5010, 5011, 5012, 5013, 5014);
UPDATE CUSTOMER_ORDER SET Order_Status = 'DELIVERED' WHERE Order_ID IN (5001, 5002, 5004, 5008, 5009, 5010, 5011, 5012, 5013);
UPDATE CUSTOMER_ORDER SET Order_Status = 'CANCELLED' WHERE Order_ID = 5007;

-- ---------------------------------------------------------------------
-- 7. PAYMENT  (IDs 9001-9014) - amount = order total
--    COD payments have no transaction reference (NULL).
-- ---------------------------------------------------------------------
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5001, TO_DATE('10-06-2026', 'DD-MM-YYYY'), 'UPI', 2698, 'UPI-260610-458712', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5002, TO_DATE('18-06-2026', 'DD-MM-YYYY'), 'CARD', 4097, 'CARD-TXN-882134', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5003, TO_DATE('05-07-2026', 'DD-MM-YYYY'), 'NET_BANKING', 17797, 'NB-HDFC-552301', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5004, TO_DATE('26-07-2026', 'DD-MM-YYYY'), 'COD', 2549, NULL, 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5005, TO_DATE('03-08-2026', 'DD-MM-YYYY'), 'WALLET', 5495, 'WAL-PAYTM-771205', 'PENDING');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5007, TO_DATE('01-09-2026', 'DD-MM-YYYY'), 'UPI', 2398, 'UPI-260901-339870', 'REFUNDED');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5008, TO_DATE('12-06-2026', 'DD-MM-YYYY'), 'UPI', 1545, 'UPI-260612-102938', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5009, TO_DATE('25-06-2026', 'DD-MM-YYYY'), 'CARD', 2698, 'CARD-TXN-883907', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5010, TO_DATE('11-07-2026', 'DD-MM-YYYY'), 'COD', 1299, NULL, 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5011, TO_DATE('19-07-2026', 'DD-MM-YYYY'), 'NET_BANKING', 1796, 'NB-SBI-661204', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5012, TO_DATE('06-08-2026', 'DD-MM-YYYY'), 'CARD', 6398, 'CARD-TXN-889012', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5013, TO_DATE('20-08-2026', 'DD-MM-YYYY'), 'WALLET', 2449, 'WAL-PHONEPE-220845', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5014, TO_DATE('05-09-2026', 'DD-MM-YYYY'), 'UPI', 639, 'UPI-260905-774411', 'SUCCESS');
INSERT INTO PAYMENT (Order_ID, Payment_Date, Payment_Method, Payment_Amount, Transaction_Reference, Payment_Status)
VALUES (5015, TO_DATE('12-09-2026', 'DD-MM-YYYY'), 'UPI', 1799, 'UPI-260912-990011', 'FAILED');

-- ---------------------------------------------------------------------
-- 8. RETURN_REQUEST  (IDs 7001-7010) - only for DELIVERED orders
-- ---------------------------------------------------------------------
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5001, 1001, TO_DATE('20-06-2026', 'DD-MM-YYYY'), 1, 'Left ear cup stopped working within a week', 'APPROVED', 1499);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5002, 1005, TO_DATE('28-06-2026', 'DD-MM-YYYY'), 1, 'Colour different from the product photo', 'REFUNDED', 2499);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5004, 1009, TO_DATE('02-08-2026', 'DD-MM-YYYY'), 1, 'Some pages are missing in the book', 'REQUESTED', 0);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5008, 1013, TO_DATE('20-06-2026', 'DD-MM-YYYY'), 1, 'Bottle leaked during delivery', 'COMPLETED', 249);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5009, 1016, TO_DATE('05-07-2026', 'DD-MM-YYYY'), 1, 'Crack near the handle', 'PICKED_UP', 0);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5010, 1019, TO_DATE('15-07-2026', 'DD-MM-YYYY'), 2, 'Two pens are not writing', 'REJECTED', 0);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5011, 1018, TO_DATE('26-07-2026', 'DD-MM-YYYY'), 1, 'Packet was torn on arrival', 'REFUNDED', 649);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5012, 1020, TO_DATE('15-08-2026', 'DD-MM-YYYY'), 1, 'One chair wheel is broken', 'APPROVED', 5499);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5013, 1009, TO_DATE('28-08-2026', 'DD-MM-YYYY'), 1, 'Wrong edition delivered', 'REQUESTED', 0);
INSERT INTO RETURN_REQUEST (Order_ID, Product_ID, Return_Date, Return_Quantity, Return_Reason, Return_Status, Refund_Amount)
VALUES (5002, 1004, TO_DATE('30-06-2026', 'DD-MM-YYYY'), 1, 'Size too large', 'APPROVED', 799);

COMMIT;

-- ---------------------------------------------------------------------
-- 9. Quick check of the final stock picture
--    Expected: 1003, 1011 OUT OF STOCK | 1006, 1010, 1020 LOW STOCK | rest IN STOCK
-- ---------------------------------------------------------------------
SELECT Product_ID, Product_Name, Stock_Quantity, Reorder_Level, Stock_Status, Product_Status
FROM   PRODUCT
ORDER  BY Product_ID;

SELECT 'CUSTOMER' AS Table_Name, COUNT(*) AS Row_Count FROM CUSTOMER
UNION ALL SELECT 'CUSTOMER_PHONE', COUNT(*) FROM CUSTOMER_PHONE
UNION ALL SELECT 'CATEGORY',       COUNT(*) FROM CATEGORY
UNION ALL SELECT 'PRODUCT',        COUNT(*) FROM PRODUCT
UNION ALL SELECT 'CUSTOMER_ORDER', COUNT(*) FROM CUSTOMER_ORDER
UNION ALL SELECT 'ORDER_ITEM',     COUNT(*) FROM ORDER_ITEM
UNION ALL SELECT 'PAYMENT',        COUNT(*) FROM PAYMENT
UNION ALL SELECT 'RETURN_REQUEST', COUNT(*) FROM RETURN_REQUEST;
-- Expected counts: 12, 16, 10, 20, 15, 28, 14, 10

-- #####################################################################
-- PART 9 : FINAL VERIFICATION
-- #####################################################################
-- Every object should be VALID; USER_ERRORS should return no rows.
SELECT object_type, COUNT(*) AS Objects,
       SUM(CASE WHEN status = 'VALID' THEN 1 ELSE 0 END) AS Valid_Objects
FROM   USER_OBJECTS
WHERE  object_type IN ('TABLE','INDEX','SEQUENCE','TRIGGER','FUNCTION','PROCEDURE','VIEW')
GROUP  BY object_type
ORDER  BY object_type;
-- Expected: FUNCTION 3, PROCEDURE 9, SEQUENCE 6, TABLE 8, TRIGGER 9, VIEW 5,
--           INDEX 18 (13 automatic PK/UQ indexes + 5 extra)

SELECT name, type, line, position, text FROM USER_ERRORS ORDER BY name, sequence;

SELECT * FROM VW_ORDER_SUMMARY ORDER BY Order_ID;
SELECT * FROM VW_LOW_STOCK_PRODUCTS ORDER BY Product_ID;

PROMPT ShopFlow database created successfully.
