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
