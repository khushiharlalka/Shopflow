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
