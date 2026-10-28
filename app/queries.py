"""
queries.py - the report queries shown on the Reports page.

Each entry has a title, the SQL concept it demonstrates, a one-line
explanation and the SQL itself. The page runs the SQL live on Oracle and
shows both the SQL text and the result, so every query can be explained.
"""

REPORTS = [
    {
        "key": "stock-status", "concept": "View + virtual column",
        "title": "Product stock status",
        "explain": "Every product with its category and the calculated Stock_Status.",
        "sql": """SELECT Product_ID, Product_Name, Category_Name, Unit_Price,
       Stock_Quantity, Reorder_Level, Stock_Status, Product_Status
FROM   VW_PRODUCT_STOCK_STATUS
ORDER  BY Product_ID""",
    },
    {
        "key": "date-range", "concept": "Filtering with TO_DATE + BETWEEN",
        "title": "Orders placed in July and August 2026",
        "explain": "Uses TO_DATE with a fixed format so the date comparison is exact.",
        "sql": """SELECT Order_ID, Customer_ID, TO_CHAR(Order_Date, 'DD-Mon-YYYY') AS Ordered_On, Order_Status
FROM   CUSTOMER_ORDER
WHERE  Order_Date BETWEEN TO_DATE('01-07-2026', 'DD-MM-YYYY')
                      AND TO_DATE('31-08-2026', 'DD-MM-YYYY')
ORDER  BY Order_Date""",
    },
    {
        "key": "order-items", "concept": "INNER JOIN (3 tables)",
        "title": "Order items with customer and product names",
        "explain": "Joins ORDER_ITEM to CUSTOMER_ORDER, CUSTOMER and PRODUCT. Item_Subtotal is a virtual column.",
        "sql": """SELECT oi.Order_ID, c.First_Name || ' ' || c.Last_Name AS Customer,
       p.Product_Name, oi.Quantity, oi.Unit_Price AS Selling_Price, oi.Item_Subtotal
FROM   ORDER_ITEM oi
       INNER JOIN CUSTOMER_ORDER co ON co.Order_ID   = oi.Order_ID
       INNER JOIN CUSTOMER       c  ON c.Customer_ID = co.Customer_ID
       INNER JOIN PRODUCT        p  ON p.Product_ID  = oi.Product_ID
ORDER  BY oi.Order_ID, p.Product_Name""",
    },
    {
        "key": "unpaid", "concept": "LEFT JOIN ... IS NULL",
        "title": "Orders that have no payment yet",
        "explain": "LEFT JOIN keeps every order; orders with no matching PAYMENT row get NULLs.",
        "sql": """SELECT co.Order_ID, c.First_Name || ' ' || c.Last_Name AS Customer, co.Order_Status
FROM   CUSTOMER_ORDER co
       JOIN      CUSTOMER c ON c.Customer_ID = co.Customer_ID
       LEFT JOIN PAYMENT  p ON p.Order_ID    = co.Order_ID
WHERE  p.Payment_ID IS NULL
ORDER  BY co.Order_ID""",
    },
    {
        "key": "orders-per-customer", "concept": "LEFT JOIN + COUNT + GROUP BY",
        "title": "Number of orders per customer",
        "explain": "COUNT(co.Order_ID) gives 0 for customers who never ordered.",
        "sql": """SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer,
       COUNT(co.Order_ID) AS Orders_Placed
FROM   CUSTOMER c
       LEFT JOIN CUSTOMER_ORDER co ON co.Customer_ID = c.Customer_ID
GROUP  BY c.Customer_ID, c.First_Name, c.Last_Name
ORDER  BY Orders_Placed DESC, c.Customer_ID""",
    },
    {
        "key": "sales-summary", "concept": "Aggregates: SUM, COUNT, AVG, MIN, MAX",
        "title": "Sales summary (cancelled orders excluded)",
        "explain": "One row of key numbers for the whole shop.",
        "sql": """SELECT COUNT(DISTINCT co.Order_ID)      AS Orders,
       SUM(oi.Quantity)                 AS Units_Sold,
       SUM(oi.Item_Subtotal)            AS Total_Sales,
       ROUND(SUM(oi.Item_Subtotal) / COUNT(DISTINCT co.Order_ID), 2) AS Avg_Order_Value,
       MIN(oi.Unit_Price)               AS Cheapest_Item_Sold,
       MAX(oi.Unit_Price)               AS Costliest_Item_Sold
FROM   CUSTOMER_ORDER co
       JOIN ORDER_ITEM oi ON oi.Order_ID = co.Order_ID
WHERE  co.Order_Status <> 'CANCELLED'""",
    },
    {
        "key": "monthly", "concept": "GROUP BY on TO_CHAR(date)",
        "title": "Month-wise sales",
        "explain": "Groups orders by month of Order_Date.",
        "sql": """SELECT TO_CHAR(co.Order_Date, 'YYYY-MM') AS Sales_Month,
       COUNT(DISTINCT co.Order_ID)       AS Orders,
       SUM(oi.Item_Subtotal)             AS Sales
FROM   CUSTOMER_ORDER co
       JOIN ORDER_ITEM oi ON oi.Order_ID = co.Order_ID
WHERE  co.Order_Status <> 'CANCELLED'
GROUP  BY TO_CHAR(co.Order_Date, 'YYYY-MM')
ORDER  BY Sales_Month""",
    },
    {
        "key": "category-value", "concept": "GROUP BY + expression",
        "title": "Category-wise product count and stock value",
        "explain": "Stock value = price x stock, added up per category.",
        "sql": """SELECT c.Category_Name, COUNT(p.Product_ID) AS Products,
       NVL(SUM(p.Unit_Price * p.Stock_Quantity), 0) AS Stock_Value
FROM   CATEGORY c
       LEFT JOIN PRODUCT p ON p.Category_ID = c.Category_ID
GROUP  BY c.Category_Name
ORDER  BY Stock_Value DESC""",
    },
    {
        "key": "best-sellers", "concept": "SUM + ORDER BY + FETCH FIRST",
        "title": "Top 5 best-selling products",
        "explain": "Total quantity sold per product; FETCH FIRST keeps the top five (Oracle 12c+).",
        "sql": """SELECT p.Product_ID, p.Product_Name, SUM(oi.Quantity) AS Qty_Sold,
       SUM(oi.Item_Subtotal) AS Revenue
FROM   ORDER_ITEM oi
       JOIN PRODUCT        p  ON p.Product_ID = oi.Product_ID
       JOIN CUSTOMER_ORDER co ON co.Order_ID  = oi.Order_ID
WHERE  co.Order_Status <> 'CANCELLED'
GROUP  BY p.Product_ID, p.Product_Name
ORDER  BY Qty_Sold DESC, Revenue DESC
FETCH FIRST 5 ROWS ONLY""",
    },
    {
        "key": "having", "concept": "GROUP BY + HAVING",
        "title": "Orders worth more than Rs 4,000",
        "explain": "HAVING filters groups after they are formed (WHERE filters rows before).",
        "sql": """SELECT Order_ID, SUM(Quantity) AS Items, SUM(Item_Subtotal) AS Order_Value
FROM   ORDER_ITEM
GROUP  BY Order_ID
HAVING SUM(Item_Subtotal) > 4000
ORDER  BY Order_Value DESC""",
    },
    {
        "key": "above-avg", "concept": "Single-row subquery",
        "title": "Products priced above the average price",
        "explain": "The inner query calculates AVG(Unit_Price) once; the outer query compares with it.",
        "sql": """SELECT Product_ID, Product_Name, Unit_Price,
       (SELECT ROUND(AVG(Unit_Price), 2) FROM PRODUCT) AS Average_Price
FROM   PRODUCT
WHERE  Unit_Price > (SELECT AVG(Unit_Price) FROM PRODUCT)
ORDER  BY Unit_Price DESC""",
    },
    {
        "key": "top-order", "concept": "Nested aggregate subquery",
        "title": "Customer who placed the highest-value order",
        "explain": "MAX(SUM(...)) with GROUP BY finds the largest order total.",
        "sql": """SELECT co.Order_ID, c.First_Name || ' ' || c.Last_Name AS Customer,
       SUM(oi.Item_Subtotal) AS Order_Value
FROM   CUSTOMER_ORDER co
       JOIN CUSTOMER   c  ON c.Customer_ID = co.Customer_ID
       JOIN ORDER_ITEM oi ON oi.Order_ID   = co.Order_ID
GROUP  BY co.Order_ID, c.First_Name, c.Last_Name
HAVING SUM(oi.Item_Subtotal) = (SELECT MAX(SUM(Item_Subtotal)) FROM ORDER_ITEM GROUP BY Order_ID)""",
    },
    {
        "key": "never-ordered", "concept": "Correlated subquery: NOT EXISTS",
        "title": "Customers who never placed an order",
        "explain": "For each customer the inner query checks whether any order exists.",
        "sql": """SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer, c.City
FROM   CUSTOMER c
WHERE  NOT EXISTS (SELECT 1 FROM CUSTOMER_ORDER co WHERE co.Customer_ID = c.Customer_ID)""",
    },
    {
        "key": "minus", "concept": "Set operation: MINUS",
        "title": "Products that were never ordered",
        "explain": "All product IDs minus the product IDs found in ORDER_ITEM.",
        "sql": """SELECT Product_ID FROM PRODUCT
MINUS
SELECT Product_ID FROM ORDER_ITEM""",
    },
    {
        "key": "intersect", "concept": "Set operation: INTERSECT",
        "title": "Customers who ordered AND raised a return",
        "explain": "Only customer IDs present in both result sets.",
        "sql": """SELECT Customer_ID FROM CUSTOMER_ORDER
INTERSECT
SELECT co.Customer_ID
FROM   RETURN_REQUEST r JOIN CUSTOMER_ORDER co ON co.Order_ID = r.Order_ID
ORDER  BY 1""",
    },
    {
        "key": "union", "concept": "Set operation: UNION",
        "title": "Every city we deal with (customers + shipping)",
        "explain": "UNION removes duplicates; Gurugram appears only as a shipping city.",
        "sql": """SELECT City AS City FROM CUSTOMER
UNION
SELECT Shipping_City FROM CUSTOMER_ORDER
ORDER  BY 1""",
    },
    {
        "key": "return-rate", "concept": "JOIN + GROUP BY + CASE",
        "title": "Return rate by category",
        "explain": "Units returned compared with units sold in each category.",
        "sql": """SELECT c.Category_Name,
       SUM(oi.Quantity)                       AS Units_Sold,
       NVL(SUM(r.Return_Quantity), 0)         AS Units_Returned,
       ROUND(100 * NVL(SUM(r.Return_Quantity), 0) / SUM(oi.Quantity), 1) AS Return_Rate_Pct,
       CASE WHEN NVL(SUM(r.Return_Quantity), 0) / SUM(oi.Quantity) > 0.2
            THEN 'Check quality' ELSE 'Normal' END AS Remark
FROM   ORDER_ITEM oi
       JOIN PRODUCT  p ON p.Product_ID  = oi.Product_ID
       JOIN CATEGORY c ON c.Category_ID = p.Category_ID
       LEFT JOIN RETURN_REQUEST r ON r.Order_ID = oi.Order_ID AND r.Product_ID = oi.Product_ID
GROUP  BY c.Category_Name
ORDER  BY Return_Rate_Pct DESC""",
    },
    {
        "key": "payment-share", "concept": "GROUP BY + analytic SUM() OVER ()",
        "title": "Share of each payment method",
        "explain": "SUM(...) OVER () gives the grand total on every row, so each share can be calculated.",
        "sql": """SELECT Payment_Method, COUNT(*) AS Payments, SUM(Payment_Amount) AS Amount,
       ROUND(100 * SUM(Payment_Amount) / SUM(SUM(Payment_Amount)) OVER (), 1) AS Share_Pct
FROM   PAYMENT
WHERE  Payment_Status = 'SUCCESS'
GROUP  BY Payment_Method
ORDER  BY Amount DESC""",
    },
    {
        "key": "functions", "concept": "Stored functions inside SELECT",
        "title": "Customer order counts and order totals using our functions",
        "explain": "FN_CUSTOMER_ORDER_COUNT and FN_ORDER_TOTAL are PL/SQL functions called from SQL.",
        "sql": """SELECT c.Customer_ID, c.First_Name || ' ' || c.Last_Name AS Customer,
       FN_CUSTOMER_ORDER_COUNT(c.Customer_ID) AS Orders,
       (SELECT NVL(SUM(FN_ORDER_TOTAL(co.Order_ID)), 0)
        FROM CUSTOMER_ORDER co
        WHERE co.Customer_ID = c.Customer_ID AND co.Order_Status <> 'CANCELLED') AS Total_Spent
FROM   CUSTOMER c
ORDER  BY Total_Spent DESC""",
    },
]

REPORTS_BY_KEY = {r["key"]: r for r in REPORTS}
