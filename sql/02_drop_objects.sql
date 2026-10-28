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
