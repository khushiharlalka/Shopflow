# ShopFlow – Every Project File Explained

**Project:** ShopFlow E-Commerce Order, Inventory and Returns Management System
**Student:** Khushi Harlalka · 25BDE0151 · Database Systems (BACSE202) · Slot L49 + L50
**Technology:** Oracle Database (SQL + PL/SQL) for the backend · Python 3 + Flask + python-oracledb for the website

This file describes all 33 files in the project: what each one contains, when you use it and how it connects to the others.
The companion file `ALL_CODE_FOR_CHATGPT.txt` holds the complete code of every file in one place.

---

## 0. How to use this with ChatGPT

1. Upload two files to ChatGPT: `PROJECT_FILES_EXPLAINED.md` (this file) and `ALL_CODE_FOR_CHATGPT.txt`.
2. Paste this prompt:

> I am a student. Attached are my complete Database Systems course project "ShopFlow" (Oracle SQL/PL/SQL backend + Python Flask website) and a file that explains every file in it.
> Please teach me how the whole project works, in very simple language, one part at a time:
> 1. First the 8 tables, their keys and relationships.
> 2. Then the sequences and triggers, especially TRG_ORDER_ITEM_STOCK and TRG_ORDER_STATUS_RULES.
> 3. Then each function and procedure, including the two cursor procedures.
> 4. Then the views and sample data.
> 5. Then how the Python website (app.py and db.py) calls Oracle, and what happens step by step when I click "Add item".
> After each part, ask me 3 viva questions and check my answers. Do not change my table names, columns or design.

3. Useful follow-up questions:
   - "Explain line by line what happens in Oracle when PR_ADD_ORDER_ITEM runs."
   - "Why does stock never get reduced twice?"
   - "Explain normalization from UNF to 5NF using my tables."
   - "What happens in db.py's run_action() when Oracle gives an error?"
   - "Ask me 20 viva questions on this project, one at a time."

---

## 1. The whole picture

```
 SQL Developer / SQL*Plus ──runs the .sql files once──►  ORACLE DATABASE  (user SHOPFLOW)
                                                          8 tables · 9 triggers · 3 functions
                                                          9 procedures · 5 views · 6 sequences
                                                               ▲            │
                                   calls procedures / SQL      │            │  results or ORA- errors
                                                               │            ▼
 Browser (http://127.0.0.1:5000) ──clicks──►  PYTHON WEBSITE  (app/app.py → app/db.py)
```

- **Backend = the `sql/` folder.** Every business rule lives here: stock control, payments, returns, status rules.
- **Front end = the `app/` folder.** It only calls the backend and shows the result. It contains no business rules.
- Every click on the website follows the flow from the course guideline:
  **User operation → SQL/PL/SQL → Database processing → Result**, shown in a "Behind the scenes" box.

---

## 2. Folder layout

```
shopflow/
├── README.md                     short run instructions
├── PROJECT_FILES_EXPLAINED.md    this file
├── ALL_CODE_FOR_CHATGPT.txt      every file's code in one place
├── requirements.txt              Python add-ons: flask, oracledb
├── run.bat                       start the website on Windows
├── run.sh                        start the website on Mac / Linux
├── sql/                          ── BACKEND (Oracle) ──
│   ├── 01_user_setup.sql
│   ├── 02_drop_objects.sql
│   ├── 03_sequences.sql
│   ├── 04_create_tables.sql
│   ├── 05_indexes.sql
│   ├── 06_triggers.sql
│   ├── 07_functions_procedures.sql
│   ├── 08_views.sql
│   ├── 09_sample_data.sql
│   ├── 10_test_queries.sql
│   ├── 11_transaction_demo.sql
│   └── 12_complete_shopflow.sql
└── app/                          ── FRONT END (Python website) ──
    ├── app.py
    ├── db.py
    ├── queries.py
    ├── config.py
    ├── static/style.css
    └── templates/
        ├── base.html  _macros.html
        ├── dashboard.html
        ├── customers.html  customer_detail.html
        ├── products.html
        ├── orders.html  order_detail.html
        ├── returns.html
        ├── reports.html
        ├── log.html
        └── db_error.html
```

---

## 3. Order of use (the short version)

| Step | What you do | File |
| --- | --- | --- |
| 1 | As admin (SYSTEM), create the SHOPFLOW user. Do this once. | `sql/01_user_setup.sql` |
| 2 | As SHOPFLOW, build the whole database. Re-run any time to reset the data. | `sql/12_complete_shopflow.sql` |
| 3 | Run the queries and check the outputs | `sql/10_test_queries.sql` |
| 4 | Run the transactions and the 20 tests, then re-run file 12 to reset | `sql/11_transaction_demo.sql` |
| 5 | Start the website | `run.bat` (Windows) or `./run.sh` (Mac) |
| 6 | Open http://127.0.0.1:5000 and do the demo | browser |

Files 02 to 09 are the parts that file 12 is made of. You do not run them separately; they are kept so each part can be shown and explained on its own.

---

## 4. The database design in brief

### The 8 tables

| Table | Primary key | Foreign keys | Main rules |
| --- | --- | --- | --- |
| CUSTOMER | Customer_ID | – | Email UNIQUE + NOT NULL; Registration_Date DEFAULT SYSDATE |
| CUSTOMER_PHONE | (Customer_ID, Phone_Number) | Customer_ID → CUSTOMER, ON DELETE CASCADE | Many phones per customer; phone format CHECK |
| CATEGORY | Category_ID | – | Category_Name UNIQUE |
| PRODUCT | Product_ID | Category_ID → CATEGORY | Price > 0; stock and reorder ≥ 0; status list; **Stock_Status virtual column** |
| CUSTOMER_ORDER | Order_ID | Customer_ID → CUSTOMER | Status list: PENDING / CONFIRMED / SHIPPED / DELIVERED / CANCELLED |
| ORDER_ITEM | (Order_ID, Product_ID) | Order_ID → CUSTOMER_ORDER; Product_ID → PRODUCT | Qty > 0; Unit_Price = selling price at order time; **Item_Subtotal virtual column** |
| PAYMENT | Payment_ID | Order_ID → CUSTOMER_ORDER | Order_ID UNIQUE (max 1 payment per order); Transaction_Reference UNIQUE; reference may be NULL only for COD |
| RETURN_REQUEST | Return_ID | (Order_ID, Product_ID) → ORDER_ITEM (**composite FK**) | That pair is UNIQUE (max 1 return per item); qty > 0; refund ≥ 0 |

### Relationships
- CUSTOMER 1 : N CUSTOMER_ORDER · CUSTOMER 1 : N CUSTOMER_PHONE · CATEGORY 1 : N PRODUCT
- CUSTOMER_ORDER 1 : N ORDER_ITEM · PRODUCT 1 : N ORDER_ITEM (so ORDER_ITEM resolves the M : N between orders and products)
- CUSTOMER_ORDER 1 : 0..1 PAYMENT · ORDER_ITEM 1 : 0..1 RETURN_REQUEST

### The most important design decision
**Stock is changed in only one place: trigger `TRG_ORDER_ITEM_STOCK`.** Procedures never touch `PRODUCT.Stock_Quantity` themselves, so stock can never be reduced twice. The other stock changes are separate events:
- `TRG_ORDER_STATUS_RULES` puts stock back when a whole order is cancelled.
- `PR_AUTO_RESTOCK` buys new stock.

### ID numbers in the sample data
Customers 101–112 · categories 1–10 · products 1001–1020 · orders 5001–5015 · payments 9001–9014 · returns 7001–7010.

---

## 5. Backend files (`sql/` folder), one by one

### `01_user_setup.sql` – create the database user (optional, admin only)
- **Run as:** SYSTEM (the admin), connected to the PDB service (`XEPDB1` for 21c XE, `FREEPDB1` for 23ai Free / Docker on a Mac).
- **What it does:** creates the user `shopflow` with password `ShopFlow_2026` and 100 MB of space. It grants only CREATE SESSION, TABLE, VIEW, SEQUENCE, PROCEDURE and TRIGGER (not DBA), then shows the new user and its privileges.
- **Skip it if** your college already gave you an Oracle username.

### `02_drop_objects.sql` – cleanup, so everything can be rebuilt
- One PL/SQL block with a small helper `drop_object`. It runs each DROP with `EXECUTE IMMEDIATE` and ignores only "does not exist" errors (ORA-00942, ORA-04043, ORA-04080, ORA-02289).
- **Order:** views → triggers → procedures → functions → sequences → tables. Child tables are dropped before parent tables.
- **Output:** "Dropped" or "Skipped (not found)" for every object.

### `03_sequences.sql` – automatic ID numbers
- Six sequences: SEQ_CUSTOMER (starts at 101), SEQ_CATEGORY (1), SEQ_PRODUCT (1001), SEQ_CUSTOMER_ORDER (5001), SEQ_PAYMENT (9001), SEQ_RETURN_REQUEST (7001).
- All use INCREMENT BY 1, NOCACHE and NOCYCLE. The comments explain each option.

### `04_create_tables.sql` – the 8 tables with every constraint
- Creates the tables in dependency order (parents first). Every constraint has a name: PK_, UQ_, FK_, CK_, NN_.
- **Virtual columns:** `PRODUCT.Stock_Status` (OUT OF STOCK / LOW STOCK / IN STOCK) and `ORDER_ITEM.Item_Subtotal` (Quantity × Unit_Price). Oracle calculates both; they are never inserted.
- **Composite keys:** PK_CUSTOMER_PHONE, PK_ORDER_ITEM, FK_RETURN_ORDER_ITEM.

### `05_indexes.sql` – faster searching
- Five extra indexes: PRODUCT(Category_ID), CUSTOMER_ORDER(Customer_ID), ORDER_ITEM(Product_ID), RETURN_REQUEST(Return_Status), CUSTOMER_ORDER(Order_Date).
- The comments explain why primary-key and unique columns are not indexed again (Oracle indexes them automatically), and the cost of indexes on INSERT, UPDATE and DELETE.

### `06_triggers.sql` – 9 automatic actions

| Trigger | Fires on | What it does |
| --- | --- | --- |
| TRG_CUSTOMER_BI | before INSERT on CUSTOMER | ID from the sequence; email changed to lower case; default date |
| TRG_CATEGORY_BI / TRG_PRODUCT_BI / TRG_PAYMENT_BI / TRG_RETURN_REQUEST_BI | before INSERT | ID from the sequence when none is given |
| TRG_CUSTOMER_ORDER_BI | before INSERT on CUSTOMER_ORDER | ID; a new order must start as PENDING (ORA-20032) |
| **TRG_ORDER_ITEM_STOCK** | before INSERT/UPDATE/DELETE on ORDER_ITEM | The inventory trigger. Items can change only while the order is PENDING. On insert: product must be ACTIVE and in stock, the current price is copied, stock is reduced. On update: only the difference is applied, and the price cannot change. On delete: stock is given back. Uses `SELECT … FOR UPDATE` to lock the product row, so two users cannot oversell. |
| **TRG_ORDER_STATUS_RULES** | before UPDATE of Order_Status | Allows only PENDING→CONFIRMED→SHIPPED→DELIVERED, and cancelling from PENDING or CONFIRMED. CONFIRMED/SHIPPED/DELIVERED needs at least 1 item. CANCELLED puts all item stock back (cursor FOR loop). |
| TRG_RETURN_VALIDATE | before INSERT/UPDATE on RETURN_REQUEST | The item must exist in that order; 0 < return qty ≤ ordered qty; only DELIVERED orders; 0 ≤ refund ≤ qty × price paid |

Custom error numbers: −20010 to −20017 (items/stock), −20030 to −20032 (order status), −20040 to −20045 (returns).

### `07_functions_procedures.sql` – 3 functions and 9 procedures
Procedures never COMMIT; the caller decides (SQL Developer or the website).

| Name | Type | Parameters | What it does |
| --- | --- | --- | --- |
| FN_ORDER_TOTAL | function | P_ORDER_ID | Sum of the order's Item_Subtotal (0 if no items) |
| FN_AVAILABLE_STOCK | function | P_PRODUCT_ID | Current stock of the product |
| FN_CUSTOMER_ORDER_COUNT | function | P_CUSTOMER_ID | Number of orders the customer has placed |
| PR_CREATE_ORDER | procedure | customer IN, order ID OUT, optional shipping address IN | Makes a PENDING order (address copied from the customer) |
| PR_ADD_ORDER_ITEM | procedure | order, product, quantity | Checks everything and inserts the item. The trigger reduces stock. |
| PR_CONFIRM_ORDER | procedure | order | Needs at least 1 item (ORA-20223) → CONFIRMED |
| PR_RECORD_PAYMENT | procedure | order, method, amount, reference, payment ID OUT, status | One payment per order; amount > 0 and ≤ order total; reference required unless COD |
| PR_CREATE_RETURN_REQUEST | procedure | order, product, qty, reason, return ID OUT | Only for DELIVERED orders; qty ≤ ordered; one return per item |
| PR_UPDATE_ORDER_STATUS | procedure | order, new status | Checks the value; the trigger checks the allowed path |
| PR_REGISTER_CUSTOMER | procedure | names, email, address, phone, customer ID OUT | Saves the customer and the first phone together (ORA-20271 without a phone, ORA-20272 duplicate email) |
| **PR_AUTO_RESTOCK** | procedure, **explicit cursor** | multiple IN, count OUT | OPEN / FETCH / CLOSE loop over low-stock ACTIVE products; sets stock = reorder level × multiple using WHERE CURRENT OF |
| **PR_PROCESS_APPROVED_REFUNDS** | procedure, **cursor FOR loop** | count OUT, total OUT | Pays every APPROVED return: refund = qty × price paid, status REFUNDED |

Custom error numbers: −20101 to −20103 (functions), −20201 to −20281 (procedures).

### `08_views.sql` – 5 ready-made reports
- VW_PRODUCT_STOCK_STATUS – product, category, stock, reorder level and stock status
- VW_ORDER_SUMMARY – one row per order: customer, totals, payment status and method (LEFT JOIN, so unpaid orders show "NO PAYMENT")
- VW_CUSTOMER_ORDER_HISTORY – every item every customer bought
- VW_LOW_STOCK_PRODUCTS – products at or below their reorder level
- VW_RETURN_DETAILS – returns with customer, order and product details

### `09_sample_data.sql` – realistic Indian sample data
- 12 customers · 16 phones · 10 categories · 20 products · 15 orders · 28 order items · 14 payments · 10 returns.
- IDs and item prices are not typed in; the triggers fill them, and stock goes down automatically.
- Orders are inserted as PENDING, then moved forward step by step. Order 5007 is cancelled, so its stock comes back.
- Ends with COMMIT and a check of the final stock and row counts.
- **Expected stock picture:** 1003 and 1011 OUT OF STOCK; 1006, 1010 and 1020 LOW STOCK; the rest IN STOCK.

### `10_test_queries.sql` – about 70 queries with expected results
Every query has a comment above it saying what it does and what the result should be.

| Section | Contents |
| --- | --- |
| A | Basic SELECT of every table |
| B | Filtering and sorting (WHERE, BETWEEN with TO_DATE, ORDER BY) |
| C | INNER JOIN and LEFT JOIN (with why LEFT JOIN is needed) |
| D | Aggregates: COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING (total sales = 54257) |
| E | Subqueries, including correlated NOT EXISTS |
| F | UNION, UNION ALL, INTERSECT, MINUS |
| G–I | String, number and date functions |
| J | CASE expressions |
| K | All 5 views |
| L | The 3 functions |
| L2 | Both cursor procedures, then ROLLBACK |
| M | INSERT, UPDATE, DELETE, MERGE (with deliberate constraint failures), then ROLLBACK |
| N | Small SAVEPOINT / ROLLBACK example |
| O | Data dictionary: DESC, USER_TABLES, USER_CONSTRAINTS, USER_TRIGGERS, USER_ERRORS, SHOW ERRORS |

### `11_transaction_demo.sql` – transactions and the 20 mandatory tests
- **Run the whole file with F5** (Run Script), because the tests pass values to each other through bind variables (`VARIABLE`, `:v_order`, `PRINT`).
- **Part A:** an all-or-nothing order that is rolled back, SAVEPOINT / ROLLBACK TO SAVEPOINT, and how to show the concurrency lock.
- **Part B:** tests 1–20, plus 1b (register through the procedure) and 1c (no phone, so it fails). Lines marked `EXPECTED: ERROR` should fail; that proves each rule works. Part B ends with ROLLBACK.
- **Part C:** the COMMIT demo, which saves one order permanently. **Re-run file 12 afterwards to reset the data.**

### `12_complete_shopflow.sql` – the whole backend in one file
- Files 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 joined in that order, plus a final check.
- **Expected final check:** TABLE 8, INDEX 18, SEQUENCE 6, TRIGGER 9, FUNCTION 3, PROCEDURE 9, VIEW 5, all VALID. `SELECT * FROM USER_ERRORS;` returns no rows.
- You can run it again and again; it cleans up first every time.

---

## 6. Front-end files (`app/` folder), one by one

### `config.py` – connection settings
- `DB_USER`, `DB_PASSWORD` and `DB_DSN` (for example `localhost:1521/XEPDB1`). They are read from the environment variables SHOPFLOW_DB_USER, SHOPFLOW_DB_PASSWORD and SHOPFLOW_DB_DSN, which run.bat and run.sh set.

### `db.py` – the only file that talks to Oracle
- `get_pool()` creates a python-oracledb connection pool in thin mode (no Oracle Client needed).
- `get_conn()` gets one connection per web request, with autocommit OFF, and enables DBMS_OUTPUT.
- `query(sql, params)`, `query_one()` and `query_with_columns()` run SELECTs with bind variables (`:name`), which prevents SQL injection.
- **`run_action(work)`** runs one business transaction. If Oracle accepts it → **COMMIT**. If Oracle raises any ORA- error → **ROLLBACK**. It also returns the DBMS_OUTPUT lines and the first line of the error message.
- `close_conn()` rolls back anything unfinished and returns the connection to the pool.

### `app.py` – every page and every button
Each button calls one procedure or one SQL statement, then records a "trace" (operation, tables, component, exact SQL, what changed, result) that is shown in the "Behind the scenes" box.

| URL | Page / action | Oracle part used |
| --- | --- | --- |
| `/` | Dashboard | VW_ORDER_SUMMARY, VW_LOW_STOCK_PRODUCTS, aggregate queries |
| `POST /restock` | Auto-restock button | PR_AUTO_RESTOCK (cursor) |
| `/customers`, `POST /customers` | List and register | FN_CUSTOMER_ORDER_COUNT, LISTAGG; PR_REGISTER_CUSTOMER |
| `/customers/<id>` | Customer page | VW_ORDER_SUMMARY, VW_CUSTOMER_ORDER_HISTORY |
| `POST /customers/<id>/phone` | Add a phone | INSERT INTO CUSTOMER_PHONE |
| `POST /customers/<id>/delete` | Delete customer | DELETE (FK check, cascade to phones) |
| `/products`, `POST /products` | List and add | VW_PRODUCT_STOCK_STATUS; INSERT … RETURNING |
| `POST /products/<id>/update` | Edit price, stock, status | UPDATE PRODUCT |
| `/orders`, `POST /orders` | List and create | VW_ORDER_SUMMARY; PR_CREATE_ORDER |
| `/orders/<id>` | Order page | ORDER_ITEM join, FN_ORDER_TOTAL, PAYMENT |
| `POST /orders/<id>/items` | Add item | PR_ADD_ORDER_ITEM → TRG_ORDER_ITEM_STOCK |
| `POST …/items/<pid>/qty` | Change quantity | UPDATE ORDER_ITEM → trigger |
| `POST …/items/<pid>/delete` | Remove item | DELETE ORDER_ITEM → trigger |
| `POST /orders/<id>/status` | Confirm / ship / deliver / cancel | PR_CONFIRM_ORDER or PR_UPDATE_ORDER_STATUS → TRG_ORDER_STATUS_RULES |
| `POST /orders/<id>/payment` | Record payment | PR_RECORD_PAYMENT |
| `POST …/items/<pid>/return` | Request return | PR_CREATE_RETURN_REQUEST → TRG_RETURN_VALIDATE |
| `/returns`, `POST /returns/<id>/status` | List and approve / reject | VW_RETURN_DETAILS; UPDATE RETURN_REQUEST |
| `POST /returns/process` | Pay approved refunds | PR_PROCESS_APPROVED_REFUNDS (cursor) |
| `/reports/<key>` | Reports | the 19 queries in queries.py |
| `/log` | SQL Log | the list of traces from this session |

Helper pieces: `record()` saves a trace, `stock_of()` and `stock_effect()` show stock before → after, `money` and `d` format rupees and dates, and `db_down()` shows a friendly page if Oracle cannot be reached.

### `queries.py` – the 19 report queries
A list of query entries, each with a title, the SQL concept it shows, a one-line explanation and the SQL text. Together they cover: a view with a virtual column, TO_DATE + BETWEEN, a 3-table INNER JOIN, LEFT JOIN … IS NULL, COUNT + GROUP BY, aggregates, monthly GROUP BY, category values, FETCH FIRST top 5, HAVING, a single-row subquery, a nested aggregate subquery, NOT EXISTS, MINUS, INTERSECT, UNION, a return rate with CASE, payment share with `SUM() OVER ()`, and the stored functions inside SELECT.

### `templates/` – the HTML pages (Jinja templates)

| File | Page |
| --- | --- |
| `base.html` | Shared layout: dark sidebar menu, page heading, the trace box |
| `_macros.html` | Reusable pieces: status pills, "SQL behind this table" boxes, the 4-step **Behind the scenes** panel |
| `dashboard.html` | KPI cards, sales-by-month bars, order pipeline, low-stock table, latest orders |
| `customers.html` | Customer list and the registration form |
| `customer_detail.html` | One customer: details, phones, orders, purchase history, delete |
| `products.html` | Category tabs, add-product form, editable product table |
| `orders.html` | Start a new order, filter by status, order list |
| `order_detail.html` | Status stepper, items (add / change / remove / return), shipping, payment |
| `returns.html` | Pay-all-approved banner, status tabs, approve or reject |
| `reports.html` | Query list on the left; SQL + live result on the right |
| `log.html` | Every action of this session with its SQL |
| `db_error.html` | Shown when Oracle cannot be reached, with a checklist |

### `static/style.css`
All the colours, layout, cards, tables, pills, buttons, the stepper and the trace panel. It uses no outside frameworks, so it works offline in the lab.

---

## 7. Root files

| File | What it is | How to use it |
| --- | --- | --- |
| `requirements.txt` | `flask>=3.0`, `oracledb>=2.0` | Installed automatically by run.bat / run.sh |
| `run.bat` | Windows launcher: sets user, password and DSN (`localhost:1521/XEPDB1`), installs add-ons, opens the browser, starts the app | Right-click → Edit to change the settings, then double-click it |
| `run.sh` | Mac/Linux launcher: the same, with DSN `localhost:1521/FREEPDB1` and a private `.venv` folder | `chmod +x run.sh` once, then `./run.sh` |
| `README.md` | A short version of these instructions and a troubleshooting table | Read first |

---

## 8. Example: what happens when you click "Add item" (2 headphones to a new order)

1. **Browser:** the form posts to `/orders/5016/items` with product=1001 and qty=2.
2. **app.py `add_item()`:** reads the stock of product 1001 (38), then calls `db.run_action()`.
3. **db.py:** runs `cur.callproc("PR_ADD_ORDER_ITEM", [5016, 1001, 2])` with autocommit off.
4. **Oracle, procedure PR_ADD_ORDER_ITEM:** checks qty > 0, that the order exists and is PENDING, and that the product exists. It locks the product row with FOR UPDATE, checks it is ACTIVE with stock ≥ 2 and not already in the order, then does `INSERT INTO ORDER_ITEM`.
5. **Oracle, trigger TRG_ORDER_ITEM_STOCK** (fires on that INSERT): checks again, copies the current price 1499 into ORDER_ITEM.Unit_Price, and does `UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity - 2`. Item_Subtotal (virtual) = 2998.
6. **db.py:** no error, so it COMMITs and reads the DBMS_OUTPUT line "Added product 1001 x 2 @ 1499 to order 5016."
7. **app.py:** reads the stock again (36) and records the trace "PRODUCT 1001: stock 38 -> 36".
8. **Browser:** the order page reloads with a green **Committed** box showing all 4 steps.

If you ask for 50 running shoes instead, the procedure raises **ORA-20215 Insufficient stock**, db.py ROLLBACKs, and the box turns red with that message. Nothing in the database changes.

---

## 9. Quick facts for the viva

- 8 tables, 2 composite PKs, 1 composite FK, 5 UNIQUE constraints, about 25 CHECK constraints, all named.
- 6 sequences, 9 triggers, 3 functions, 9 procedures (2 with explicit cursors), 5 views, 5 extra indexes.
- 10+ rows in every table; total sales excluding cancelled orders = Rs 54,257.
- Why Unit_Price is in both PRODUCT and ORDER_ITEM: PRODUCT holds today's price, ORDER_ITEM holds the price actually paid. Keeping both preserves history.
- Why the table is called CUSTOMER_ORDER: ORDER is an SQL reserved word (ORDER BY).
- Why RETURN_REQUEST has a composite FK: its parent ORDER_ITEM is identified by two columns.
- COD payments: Transaction_Reference may be NULL; a UNIQUE column allows many NULLs.
- Normalized to 5NF; the full explanation is in the project report.

---

## 10. Extra files for the report (13–17)

These show things the report format asks for that the app itself does not need. They never change the 8 project tables.

| File | Run as | What it shows (report chapter) |
| --- | --- | --- |
| `13_admin_create_test_user.sql` | ADMIN (SYSTEM) | Creates the read-only test account `shopflow_viewer` / `Viewer_2026` |
| `14_report_extras.sql` | SHOPFLOW, F5 | DDL (CREATE/ALTER/TRUNCATE/DROP) on a practice table (7.1); DISTINCT (7.3); RIGHT/CROSS/SELF JOIN (7.6); IN/ALL subqueries (7.7); view update limitation ORA-01732 (7.9); least privilege + Oracle version (10.1, 2.4); EXPLAIN PLAN before/after an index on a 200,000-row practice table (9.2–9.5); plan of a real join (9.3); GRANT (7.11) |
| `15_viewer_access_test.sql` | Viewer, F5 | Permitted SELECT; denied UPDATE/DELETE (ORA-01031); hidden table (ORA-00942) (10.6) |
| `16_revoke_demo.sql` | SHOPFLOW, F5 | REVOKE; then run 15 again to see access removed (7.11) |
| `17_two_session_demo.sql` | two SHOPFLOW windows, line by line | Row locking, no dirty read, and a real deadlock ORA-00060 (8.8, 8.9) |
