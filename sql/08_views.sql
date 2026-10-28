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
