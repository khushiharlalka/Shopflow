# ShopFlow — E-Commerce Order, Inventory and Returns Management System

Database Systems course project · Khushi Harlalka · 25BDE0151 · BACSE202 · Slot L49 + L50

An Oracle database (8 tables, constraints, triggers, procedures, functions, cursors, views)
with a Python **Flask** web front end that talks to Oracle through **python-oracledb**.

```
shopflow/
├── sql/                         ← the whole database (backend), written by hand
│   ├── 01_user_setup.sql            optional, admin only: create SHOPFLOW user
│   ├── 02_drop_objects.sql          rerunnable cleanup
│   ├── 03_sequences.sql             6 sequences
│   ├── 04_create_tables.sql         8 tables + named constraints
│   ├── 05_indexes.sql               5 extra indexes
│   ├── 06_triggers.sql              9 triggers (IDs, inventory, order status, returns)
│   ├── 07_functions_procedures.sql  3 functions + 9 procedures (2 use explicit cursors)
│   ├── 08_views.sql                 5 views
│   ├── 09_sample_data.sql           10+ rows in every table
│   ├── 10_test_queries.sql          queries with expected output in comments
│   ├── 11_transaction_demo.sql      COMMIT / ROLLBACK / SAVEPOINT + 20 test cases
│   └── 12_complete_shopflow.sql     files 02–09 in one script  ← run this first
└── app/                         ← the front end (Python)
    ├── app.py                       every page and every user action
    ├── db.py                        the only file that talks to Oracle
    ├── queries.py                   19 report queries shown on the Reports page
    ├── config.py                    username / password / DSN
    ├── templates/                   HTML pages (Jinja)
    └── static/style.css             all styling
```

## 1. Build the database (once)

1. Open Oracle SQL Developer and connect to your schema
   (host `localhost`, port `1521`, service name `XEPDB1` / `FREEPDB1` / `XE` — whichever yours is).
2. Open `sql/12_complete_shopflow.sql` and press **F5** (Run Script).
3. The last lines should show 8 tables, 9 triggers, 3 functions, 9 procedures, 5 views,
   and `SELECT * FROM USER_ERRORS` should return **no rows**.

## 2. Run the web app

Needs Python 3.9 or newer. No Oracle Client install is needed (python-oracledb "thin" mode).

**Windows** — double-click `run.bat`, or in a terminal:

```bat
cd shopflow
pip install -r requirements.txt
set SHOPFLOW_DB_USER=shopflow
set SHOPFLOW_DB_PASSWORD=your_password
set SHOPFLOW_DB_DSN=localhost:1521/XEPDB1
python app\app.py
```

**macOS / Linux**

```bash
cd shopflow
pip install -r requirements.txt
export SHOPFLOW_DB_USER=shopflow SHOPFLOW_DB_PASSWORD=your_password SHOPFLOW_DB_DSN=localhost:1521/XEPDB1
python3 app/app.py
```

Open **http://127.0.0.1:5000**. (Instead of environment variables you can type the three values in `app/config.py`.)

## 3. What to show in the demo

Every action shows a **Behind the scenes** panel with the four steps the guide asks for:
User operation → SQL/PL/SQL → Database processing (tables, stock before → after) → Result (or the ORA- error).
The **SQL Log** page keeps all of them.

| Try this | What runs in Oracle |
| --- | --- |
| Customers → Register (with phone) | `PR_REGISTER_CUSTOMER` + `TRG_CUSTOMER_BI` |
| Register with an existing email | ORA-20272, nothing saved |
| Orders → Create order | `PR_CREATE_ORDER` + `TRG_CUSTOMER_ORDER_BI` |
| Add item | `PR_ADD_ORDER_ITEM` → `TRG_ORDER_ITEM_STOCK` (price copied, stock reduced) |
| Add more than in stock | ORA-20215, rolled back |
| Change quantity / Remove item | UPDATE / DELETE on ORDER_ITEM → trigger adjusts stock |
| Mark as Confirmed on an empty order | ORA-20223 |
| Record payment, then try again | `PR_RECORD_PAYMENT`, then ORA-20239 (one payment per order) |
| Ship → Deliver → Return… | `PR_UPDATE_ORDER_STATUS`, `PR_CREATE_RETURN_REQUEST` |
| Cancel order | `TRG_ORDER_STATUS_RULES` puts the stock back |
| Products → Auto-restock | **cursor** procedure `PR_AUTO_RESTOCK` |
| Returns → Approve, then Refund | **cursor** procedure `PR_PROCESS_APPROVED_REFUNDS` |
| Products → negative price | ORA-02290 `CK_PRODUCT_PRICE` |
| Customer page → Delete (customer with orders) | ORA-02292 `FK_ORDER_CUSTOMER` |
| Reports | 19 live queries: joins, GROUP BY / HAVING, subqueries, set operations, functions |

To reset everything to the original sample data, run `sql/12_complete_shopflow.sql` again.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `DPY-6005` / `ORA-12514` / cannot connect | Wrong DSN or service name — check `SHOPFLOW_DB_DSN` (e.g. `XEPDB1` vs `XE`) and that the listener is running |
| `ORA-01017` | Wrong username or password |
| `ORA-00942 table or view does not exist` | Run `12_complete_shopflow.sql` in the same schema the app logs into |
| `DPY-3010` (thin mode not supported) | Very old Oracle (11g). Install Oracle Instant Client and add `oracledb.init_oracle_client()` at the top of `db.py` |
