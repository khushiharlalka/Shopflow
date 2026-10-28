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
