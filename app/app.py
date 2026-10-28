"""
app.py - ShopFlow web application (Flask + Oracle).

How every user action works (the flow asked for in the project guide):

    User operation  ->  SQL / PL/SQL  ->  Oracle processing  ->  Result

Each action function below:
  1. reads the form values,
  2. calls ONE procedure / DML statement through db.run_action()
     (Oracle triggers fire automatically inside it),
  3. records a "trace" (what was done, which tables, which component,
     the exact SQL, what changed, the result or the Oracle error),
  4. redirects back to the page, which shows the trace in the
     "Behind the scenes" panel.

Run:  python app.py      then open  http://127.0.0.1:5000
"""
from collections import deque
from datetime import datetime
from itertools import count

from flask import Flask, abort, redirect, render_template, request, url_for

import config
import db
from queries import REPORTS, REPORTS_BY_KEY

app = Flask(__name__)
app.secret_key = config.SECRET_KEY
app.teardown_appcontext(db.close_conn)

ORDER_FLOW = ["PENDING", "CONFIRMED", "SHIPPED", "DELIVERED"]
NEXT_STATUS = {"PENDING": "CONFIRMED", "CONFIRMED": "SHIPPED", "SHIPPED": "DELIVERED"}
RETURN_STATUSES = ["REQUESTED", "APPROVED", "REJECTED", "PICKED_UP", "COMPLETED", "REFUNDED"]
PAYMENT_METHODS = ["UPI", "CARD", "NET_BANKING", "COD", "WALLET"]

# ---------------------------------------------------------------------------
# "Behind the scenes" log: kept in memory for the SQL Log page
# ---------------------------------------------------------------------------
TRACES = deque(maxlen=60)
_trace_id = count(1)


def record(operation, tables, component, sql, ok, output, error, effect=None):
    trace = {
        "id": next(_trace_id), "time": datetime.now().strftime("%H:%M:%S"),
        "operation": operation, "tables": tables, "component": component,
        "sql": sql.strip(), "ok": ok, "output": output, "error": error,
        "effect": effect or [],
    }
    TRACES.appendleft(trace)
    return trace["id"]


def back(endpoint, trace_id, **kw):
    return redirect(url_for(endpoint, t=trace_id, **kw))


@app.context_processor
def inject_trace():
    """Every page gets the trace of the action that led to it (if any)."""
    t = request.args.get("t", type=int)
    return {"trace": next((x for x in TRACES if x["id"] == t), None)}


@app.template_filter("money")
def money(v):
    if v is None:
        return "-"
    v = float(v)
    return "Rs " + (f"{v:,.0f}" if v == int(v) else f"{v:,.2f}")


@app.template_filter("d")
def fmt_date(v):
    return v.strftime("%d %b %Y") if v else "-"


def stock_of(product_ids):
    """Current stock of some products - used to show 'before -> after'."""
    if not product_ids:
        return {}
    binds = {f"p{i}": pid for i, pid in enumerate(product_ids)}
    rows = db.query(f"SELECT Product_ID, Product_Name, Stock_Quantity FROM PRODUCT "
                    f"WHERE Product_ID IN ({', '.join(':' + k for k in binds)})", binds)
    return {r["product_id"]: r for r in rows}


def stock_effect(before, after):
    out = []
    for pid, b in before.items():
        a = after.get(pid)
        if a and a["stock_quantity"] != b["stock_quantity"]:
            out.append(f"PRODUCT {pid} ({b['product_name']}): stock "
                       f"{b['stock_quantity']} -> {a['stock_quantity']}")
    return out


@app.errorhandler(Exception)
def db_down(e):
    """Friendly page if Oracle cannot be reached (wrong password, listener down ...)."""
    import oracledb
    from werkzeug.exceptions import HTTPException
    if isinstance(e, HTTPException):
        return e
    if isinstance(e, oracledb.Error):
        return render_template("db_error.html", message=db.oracle_message(e), dsn=config.DB_DSN,
                               user=config.DB_USER), 500
    raise e


# ===========================================================================
# DASHBOARD
# ===========================================================================
@app.route("/")
def dashboard():
    kpi = db.query_one("""
        SELECT (SELECT COUNT(*) FROM CUSTOMER)                                   AS customers,
               (SELECT COUNT(*) FROM CUSTOMER_ORDER)                             AS orders,
               (SELECT NVL(SUM(oi.Item_Subtotal), 0) FROM ORDER_ITEM oi
                  JOIN CUSTOMER_ORDER co ON co.Order_ID = oi.Order_ID
                 WHERE co.Order_Status <> 'CANCELLED')                            AS sales,
               (SELECT COUNT(*) FROM VW_LOW_STOCK_PRODUCTS)                      AS low_stock,
               (SELECT COUNT(*) FROM RETURN_REQUEST
                 WHERE Return_Status IN ('REQUESTED', 'APPROVED', 'PICKED_UP'))   AS open_returns
        FROM DUAL""")
    recent = db.query("SELECT * FROM VW_ORDER_SUMMARY ORDER BY Order_Date DESC, Order_ID DESC "
                      "FETCH FIRST 6 ROWS ONLY")
    low = db.query("SELECT * FROM VW_LOW_STOCK_PRODUCTS ORDER BY Stock_Quantity, Product_ID")
    monthly = db.query("""
        SELECT TO_CHAR(co.Order_Date, 'YYYY-MM') AS month, SUM(oi.Item_Subtotal) AS sales
        FROM   CUSTOMER_ORDER co JOIN ORDER_ITEM oi ON oi.Order_ID = co.Order_ID
        WHERE  co.Order_Status <> 'CANCELLED'
        GROUP  BY TO_CHAR(co.Order_Date, 'YYYY-MM') ORDER BY month""")
    top = max([m["sales"] for m in monthly] or [1])
    by_status = db.query("SELECT Order_Status AS status, COUNT(*) AS n FROM CUSTOMER_ORDER "
                         "GROUP BY Order_Status")
    return render_template("dashboard.html", kpi=kpi, recent=recent, low=low,
                           monthly=monthly, top=top, by_status={r["status"]: r["n"] for r in by_status})


@app.post("/restock")
def auto_restock():
    """CURSOR procedure: restock every ACTIVE product at/below its reorder level."""
    multiple = request.form.get("multiple", 3, type=int)
    before = {r["product_id"]: r for r in db.query(
        "SELECT Product_ID, Product_Name, Stock_Quantity FROM PRODUCT")}

    def work(cur):
        out_count = cur.var(int)
        cur.callproc("PR_AUTO_RESTOCK", [multiple, out_count])
        return out_count.getvalue()

    ok, n, output, error = db.run_action(work)
    effect = stock_effect(before, stock_of(list(before))) if ok else []
    tid = record(f"Auto-restock all low-stock products (stock = reorder level x {multiple})",
                 "PRODUCT (read with a cursor, then UPDATE ... WHERE CURRENT OF)",
                 "Procedure PR_AUTO_RESTOCK - explicit cursor c_low with FOR UPDATE",
                 "BEGIN PR_AUTO_RESTOCK(:p_multiple, :p_restocked_count); END;",
                 ok, output, error, effect or ([f"{n} product(s) restocked"] if ok else []))
    return back(request.form.get("next", "dashboard"), tid)


# ===========================================================================
# CUSTOMERS
# ===========================================================================
@app.route("/customers")
def customers():
    rows = db.query("""
        SELECT c.Customer_ID, c.First_Name, c.Last_Name, c.Email, c.City, c.State,
               c.Registration_Date,
               (SELECT LISTAGG(p.Phone_Number, ', ') WITHIN GROUP (ORDER BY p.Phone_Number)
                FROM CUSTOMER_PHONE p WHERE p.Customer_ID = c.Customer_ID) AS phones,
               FN_CUSTOMER_ORDER_COUNT(c.Customer_ID) AS orders
        FROM   CUSTOMER c
        ORDER  BY c.Customer_ID""")
    return render_template("customers.html", rows=rows)


@app.post("/customers")
def add_customer():
    f = request.form
    vals = [f["first"].strip(), f["last"].strip(), f["email"].strip(), f["street"].strip(),
            f["city"].strip(), f["state"].strip(), f["postal"].strip(), f["phone"].strip() or None]

    def work(cur):
        new_id = cur.var(int)
        cur.callproc("PR_REGISTER_CUSTOMER", vals + [new_id])
        return new_id.getvalue()

    ok, cid, output, error = db.run_action(work)
    tid = record(f"Register customer {vals[0]} {vals[1]}",
                 "CUSTOMER (INSERT), CUSTOMER_PHONE (INSERT)",
                 "Procedure PR_REGISTER_CUSTOMER -> trigger TRG_CUSTOMER_BI (ID + lower-case email)",
                 """BEGIN PR_REGISTER_CUSTOMER(:first, :last, :email, :street, :city,
                       :state, :postal, :phone, :new_customer_id); END;""",
                 ok, output, error, [f"New CUSTOMER row {cid} + 1 CUSTOMER_PHONE row"] if ok else [])
    return back("customer_detail", tid, cid=cid) if ok else back("customers", tid)


@app.route("/customers/<int:cid>")
def customer_detail(cid):
    cust = db.query_one("SELECT * FROM CUSTOMER WHERE Customer_ID = :cid", {"cid": cid})
    if not cust:
        abort(404)
    phones = db.query("SELECT Phone_Number FROM CUSTOMER_PHONE WHERE Customer_ID = :cid "
                      "ORDER BY Phone_Number", {"cid": cid})
    orders = db.query("""SELECT s.* FROM VW_ORDER_SUMMARY s
                         JOIN CUSTOMER_ORDER co ON co.Order_ID = s.Order_ID
                         WHERE co.Customer_ID = :cid ORDER BY s.Order_Date DESC""", {"cid": cid})
    history = db.query("SELECT * FROM VW_CUSTOMER_ORDER_HISTORY WHERE Customer_ID = :cid "
                       "ORDER BY Order_Date DESC, Product_Name", {"cid": cid})
    return render_template("customer_detail.html", c=cust, phones=phones, orders=orders, history=history)


@app.post("/customers/<int:cid>/phone")
def add_phone(cid):
    phone = request.form["phone"].strip()
    ok, _, output, error = db.run_action(lambda cur: cur.execute(
        "INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (:cid, :phone)",
        {"cid": cid, "phone": phone}))
    tid = record(f"Add phone {phone} for customer {cid}", "CUSTOMER_PHONE (INSERT)",
                 "Plain INSERT - checked by PK_CUSTOMER_PHONE, FK_PHONE_CUSTOMER, CK_PHONE_FORMAT",
                 "INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (:cid, :phone)",
                 ok, output, error, ["1 row inserted"] if ok else [])
    return back("customer_detail", tid, cid=cid)


@app.post("/customers/<int:cid>/delete")
def delete_customer(cid):
    ok, n, output, error = db.run_action(lambda cur: (cur.execute(
        "DELETE FROM CUSTOMER WHERE Customer_ID = :cid", {"cid": cid}), cur.rowcount)[1])
    tid = record(f"Delete customer {cid}", "CUSTOMER (DELETE), CUSTOMER_PHONE (cascade)",
                 "Plain DELETE - FK_ORDER_CUSTOMER blocks it if orders exist; "
                 "FK_PHONE_CUSTOMER ON DELETE CASCADE removes the phones",
                 "DELETE FROM CUSTOMER WHERE Customer_ID = :cid",
                 ok, output, error, [f"{n} customer row deleted, phones removed by cascade"] if ok else [])
    return back("customers", tid) if ok else back("customer_detail", tid, cid=cid)


# ===========================================================================
# PRODUCTS
# ===========================================================================
@app.route("/products")
def products():
    cat = request.args.get("cat", type=int)
    sql = """SELECT v.*, p.Category_ID FROM VW_PRODUCT_STOCK_STATUS v
             JOIN PRODUCT p ON p.Product_ID = v.Product_ID"""
    rows = db.query(sql + (" WHERE p.Category_ID = :cat" if cat else "") + " ORDER BY v.Product_ID",
                    {"cat": cat} if cat else {})
    cats = db.query("""SELECT c.Category_ID, c.Category_Name, COUNT(p.Product_ID) AS n
                       FROM CATEGORY c LEFT JOIN PRODUCT p ON p.Category_ID = c.Category_ID
                       GROUP BY c.Category_ID, c.Category_Name ORDER BY c.Category_ID""")
    return render_template("products.html", rows=rows, cats=cats, cat=cat)


@app.post("/products")
def add_product():
    f = request.form
    params = {"cat": int(f["category"]), "name": f["name"].strip(), "descr": f["description"].strip(),
              "price": float(f["price"]), "stock": int(f["stock"]), "reorder": int(f["reorder"])}

    def work(cur):
        new_id = cur.var(int)
        cur.execute("""INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price,
                                            Stock_Quantity, Reorder_Level, Product_Status)
                       VALUES (:cat, :name, :descr, :price, :stock, :reorder, 'ACTIVE')
                       RETURNING Product_ID INTO :new_id""", {**params, "new_id": new_id})
        return new_id.getvalue()[0]

    ok, pid, output, error = db.run_action(work)
    tid = record(f"Add product '{params['name']}'", "PRODUCT (INSERT)",
                 "INSERT ... RETURNING -> trigger TRG_PRODUCT_BI gives the ID; "
                 "CK_PRODUCT_PRICE / CK_PRODUCT_STOCK check the values",
                 """INSERT INTO PRODUCT (Category_ID, Product_Name, Description, Unit_Price,
                       Stock_Quantity, Reorder_Level, Product_Status)
VALUES (:cat, :name, :descr, :price, :stock, :reorder, 'ACTIVE')
RETURNING Product_ID INTO :new_id""",
                 ok, output, error, [f"New PRODUCT row {pid}"] if ok else [])
    return back("products", tid)


@app.post("/products/<int:pid>/update")
def update_product(pid):
    f = request.form
    params = {"pid": pid, "price": float(f["price"]), "stock": int(f["stock"]), "status": f["status"]}
    before = db.query_one("SELECT Unit_Price, Stock_Quantity, Stock_Status, Product_Status FROM PRODUCT "
                          "WHERE Product_ID = :pid", {"pid": pid})
    ok, _, output, error = db.run_action(lambda cur: cur.execute(
        """UPDATE PRODUCT SET Unit_Price = :price, Stock_Quantity = :stock, Product_Status = :status
           WHERE Product_ID = :pid""", params))
    after = db.query_one("SELECT Unit_Price, Stock_Quantity, Stock_Status, Product_Status FROM PRODUCT "
                         "WHERE Product_ID = :pid", {"pid": pid})
    effect = [f"{k.replace('_', ' ').title()}: {before[k]} -> {after[k]}"
              for k in before if before[k] != after[k]] if ok else []
    tid = record(f"Update product {pid}", "PRODUCT (UPDATE)",
                 "Plain UPDATE - CHECK constraints validate; Stock_Status (virtual column) recalculates; "
                 "old ORDER_ITEM prices stay unchanged",
                 "UPDATE PRODUCT SET Unit_Price = :price, Stock_Quantity = :stock, "
                 "Product_Status = :status WHERE Product_ID = :pid",
                 ok, output, error, effect or (["No values changed"] if ok else []))
    return back("products", tid, cat=request.form.get("cat") or None)


# ===========================================================================
# ORDERS
# ===========================================================================
@app.route("/orders")
def orders():
    status = request.args.get("status")
    rows = db.query("SELECT * FROM VW_ORDER_SUMMARY" + (" WHERE Order_Status = :st" if status else "")
                    + " ORDER BY Order_ID DESC", {"st": status} if status else {})
    custs = db.query("SELECT Customer_ID, First_Name || ' ' || Last_Name AS name, City FROM CUSTOMER "
                     "ORDER BY First_Name")
    return render_template("orders.html", rows=rows, custs=custs, status=status,
                           statuses=ORDER_FLOW + ["CANCELLED"])


@app.post("/orders")
def create_order():
    cid = request.form.get("customer", type=int)

    def work(cur):
        new_id = cur.var(int)
        cur.callproc("PR_CREATE_ORDER", [cid, new_id])
        return new_id.getvalue()

    ok, oid, output, error = db.run_action(work)
    tid = record(f"Create a new order for customer {cid}", "CUSTOMER (read), CUSTOMER_ORDER (INSERT)",
                 "Procedure PR_CREATE_ORDER -> trigger TRG_CUSTOMER_ORDER_BI (ID, status PENDING)",
                 "BEGIN PR_CREATE_ORDER(:p_customer_id, :p_order_id); END;",
                 ok, output, error, [f"New CUSTOMER_ORDER row {oid}, status PENDING, "
                                     "shipping address copied from the customer"] if ok else [])
    return back("order_detail", tid, oid=oid) if ok else back("orders", tid)


@app.route("/orders/<int:oid>")
def order_detail(oid):
    order = db.query_one("""
        SELECT co.*, c.First_Name || ' ' || c.Last_Name AS customer_name, c.Email
        FROM CUSTOMER_ORDER co JOIN CUSTOMER c ON c.Customer_ID = co.Customer_ID
        WHERE co.Order_ID = :oid""", {"oid": oid})
    if not order:
        abort(404)
    items = db.query("""
        SELECT oi.*, p.Product_Name, p.Unit_Price AS current_price, p.Stock_Quantity,
               r.Return_ID, r.Return_Status, r.Return_Quantity
        FROM ORDER_ITEM oi
             JOIN PRODUCT p ON p.Product_ID = oi.Product_ID
             LEFT JOIN RETURN_REQUEST r ON r.Order_ID = oi.Order_ID AND r.Product_ID = oi.Product_ID
        WHERE oi.Order_ID = :oid ORDER BY p.Product_Name""", {"oid": oid})
    total = db.query_one("SELECT FN_ORDER_TOTAL(:oid) AS total FROM DUAL", {"oid": oid})["total"]
    payment = db.query_one("SELECT * FROM PAYMENT WHERE Order_ID = :oid", {"oid": oid})
    products = db.query("""SELECT Product_ID, Product_Name, Unit_Price, Stock_Quantity FROM PRODUCT
                           WHERE Product_Status = 'ACTIVE' AND Stock_Quantity > 0
                           ORDER BY Product_Name""")
    return render_template("order_detail.html", o=order, items=items, total=total, payment=payment,
                           products=products, flow=ORDER_FLOW, next_status=NEXT_STATUS.get(order["order_status"]),
                           methods=PAYMENT_METHODS)


@app.post("/orders/<int:oid>/items")
def add_item(oid):
    pid = request.form.get("product", type=int)
    qty = request.form.get("qty", type=int)
    before = stock_of([pid])

    def work(cur):
        cur.callproc("PR_ADD_ORDER_ITEM", [oid, pid, qty])

    ok, _, output, error = db.run_action(work)
    tid = record(f"Add {qty} x product {pid} to order {oid}",
                 "CUSTOMER_ORDER (read), PRODUCT (read + lock + UPDATE), ORDER_ITEM (INSERT)",
                 "Procedure PR_ADD_ORDER_ITEM -> trigger TRG_ORDER_ITEM_STOCK "
                 "(copies the price, checks and reduces stock)",
                 "BEGIN PR_ADD_ORDER_ITEM(:p_order_id, :p_product_id, :p_quantity); END;",
                 ok, output, error, stock_effect(before, stock_of([pid])) if ok else [])
    return back("order_detail", tid, oid=oid)


@app.post("/orders/<int:oid>/items/<int:pid>/qty")
def change_qty(oid, pid):
    qty = request.form.get("qty", type=int)
    before = stock_of([pid])
    ok, _, output, error = db.run_action(lambda cur: cur.execute(
        "UPDATE ORDER_ITEM SET Quantity = :qty WHERE Order_ID = :oid AND Product_ID = :pid",
        {"qty": qty, "oid": oid, "pid": pid}))
    tid = record(f"Change quantity of product {pid} in order {oid} to {qty}",
                 "ORDER_ITEM (UPDATE), PRODUCT (stock UPDATE by trigger)",
                 "Plain UPDATE -> trigger TRG_ORDER_ITEM_STOCK applies only the difference",
                 "UPDATE ORDER_ITEM SET Quantity = :qty WHERE Order_ID = :oid AND Product_ID = :pid",
                 ok, output, error, stock_effect(before, stock_of([pid])) if ok else [])
    return back("order_detail", tid, oid=oid)


@app.post("/orders/<int:oid>/items/<int:pid>/delete")
def remove_item(oid, pid):
    before = stock_of([pid])
    ok, _, output, error = db.run_action(lambda cur: cur.execute(
        "DELETE FROM ORDER_ITEM WHERE Order_ID = :oid AND Product_ID = :pid", {"oid": oid, "pid": pid}))
    tid = record(f"Remove product {pid} from order {oid}",
                 "ORDER_ITEM (DELETE), PRODUCT (stock UPDATE by trigger)",
                 "Plain DELETE -> trigger TRG_ORDER_ITEM_STOCK puts the quantity back",
                 "DELETE FROM ORDER_ITEM WHERE Order_ID = :oid AND Product_ID = :pid",
                 ok, output, error, stock_effect(before, stock_of([pid])) if ok else [])
    return back("order_detail", tid, oid=oid)


@app.post("/orders/<int:oid>/status")
def change_status(oid):
    new = request.form["status"]
    items = [r["product_id"] for r in db.query("SELECT Product_ID FROM ORDER_ITEM WHERE Order_ID = :oid",
                                               {"oid": oid})]
    before = stock_of(items)
    if new == "CONFIRMED":
        work = lambda cur: cur.callproc("PR_CONFIRM_ORDER", [oid])
        comp = "Procedure PR_CONFIRM_ORDER (needs at least one item) -> trigger TRG_ORDER_STATUS_RULES"
        sql = "BEGIN PR_CONFIRM_ORDER(:p_order_id); END;"
    else:
        work = lambda cur: cur.callproc("PR_UPDATE_ORDER_STATUS", [oid, new])
        comp = ("Procedure PR_UPDATE_ORDER_STATUS -> trigger TRG_ORDER_STATUS_RULES "
                "(checks the allowed path" + ("; restores stock of every item)" if new == "CANCELLED" else ")"))
        sql = "BEGIN PR_UPDATE_ORDER_STATUS(:p_order_id, :p_new_status); END;"
    ok, _, output, error = db.run_action(work)
    effect = ([f"CUSTOMER_ORDER {oid}: status -> {new}"] + stock_effect(before, stock_of(items))) if ok else []
    tid = record(f"Change order {oid} status to {new}",
                 "CUSTOMER_ORDER (UPDATE)" + (", ORDER_ITEM (read), PRODUCT (stock UPDATE)" if new == "CANCELLED"
                                              else ", ORDER_ITEM (count)"),
                 comp, sql, ok, output, error, effect)
    return back("order_detail", tid, oid=oid)


@app.post("/orders/<int:oid>/payment")
def record_payment(oid):
    f = request.form
    method = f["method"]
    ref = f.get("reference", "").strip() or None
    amount = float(f["amount"])
    status = f.get("pay_status", "SUCCESS")

    def work(cur):
        new_id = cur.var(int)
        cur.callproc("PR_RECORD_PAYMENT", [oid, method, amount, ref, new_id, status])
        return new_id.getvalue()

    ok, pay_id, output, error = db.run_action(work)
    tid = record(f"Record {method} payment of {money(amount)} for order {oid}",
                 "CUSTOMER_ORDER + ORDER_ITEM (read, via FN_ORDER_TOTAL), PAYMENT (INSERT)",
                 "Procedure PR_RECORD_PAYMENT (calls function FN_ORDER_TOTAL) -> trigger TRG_PAYMENT_BI; "
                 "UQ_PAYMENT_ORDER allows one payment per order",
                 "BEGIN PR_RECORD_PAYMENT(:p_order_id, :p_method, :p_amount, :p_reference, "
                 ":p_payment_id, :p_status); END;",
                 ok, output, error, [f"New PAYMENT row {pay_id}"] if ok else [])
    return back("order_detail", tid, oid=oid)


@app.post("/orders/<int:oid>/items/<int:pid>/return")
def request_return(oid, pid):
    qty = request.form.get("qty", type=int)
    reason = request.form.get("reason", "").strip()

    def work(cur):
        new_id = cur.var(int)
        cur.callproc("PR_CREATE_RETURN_REQUEST", [oid, pid, qty, reason, new_id])
        return new_id.getvalue()

    ok, rid, output, error = db.run_action(work)
    tid = record(f"Request return of {qty} x product {pid} from order {oid}",
                 "ORDER_ITEM + CUSTOMER_ORDER (read), RETURN_REQUEST (INSERT)",
                 "Procedure PR_CREATE_RETURN_REQUEST -> triggers TRG_RETURN_REQUEST_BI and "
                 "TRG_RETURN_VALIDATE; UQ_RETURN_ORDER_ITEM allows one return per item",
                 "BEGIN PR_CREATE_RETURN_REQUEST(:p_order_id, :p_product_id, :p_return_qty, "
                 ":p_reason, :p_return_id); END;",
                 ok, output, error, [f"New RETURN_REQUEST row {rid}, status REQUESTED"] if ok else [])
    return back("order_detail", tid, oid=oid)


# ===========================================================================
# RETURNS
# ===========================================================================
@app.route("/returns")
def returns():
    status = request.args.get("status")
    rows = db.query("SELECT * FROM VW_RETURN_DETAILS" + (" WHERE Return_Status = :st" if status else "")
                    + " ORDER BY Return_ID DESC", {"st": status} if status else {})
    approved = db.query_one("""SELECT COUNT(*) AS n, NVL(SUM(r.Return_Quantity * oi.Unit_Price), 0) AS amount
                               FROM RETURN_REQUEST r JOIN ORDER_ITEM oi
                                 ON oi.Order_ID = r.Order_ID AND oi.Product_ID = r.Product_ID
                               WHERE r.Return_Status = 'APPROVED'""")
    return render_template("returns.html", rows=rows, status=status, statuses=RETURN_STATUSES, approved=approved)


@app.post("/returns/<int:rid>/status")
def return_status(rid):
    new = request.form["status"]
    ok, _, output, error = db.run_action(lambda cur: cur.execute(
        "UPDATE RETURN_REQUEST SET Return_Status = :st WHERE Return_ID = :rid", {"st": new, "rid": rid}))
    tid = record(f"Mark return {rid} as {new}", "RETURN_REQUEST (UPDATE)",
                 "Plain UPDATE - CK_RETURN_STATUS allows only the listed statuses",
                 "UPDATE RETURN_REQUEST SET Return_Status = :st WHERE Return_ID = :rid",
                 ok, output, error, [f"RETURN_REQUEST {rid}: status -> {new}"] if ok else [])
    return back("returns", tid)


@app.post("/returns/process")
def process_refunds():
    def work(cur):
        n, total = cur.var(int), cur.var(float)
        cur.callproc("PR_PROCESS_APPROVED_REFUNDS", [n, total])
        return n.getvalue(), total.getvalue()

    ok, res, output, error = db.run_action(work)
    tid = record("Pay out every APPROVED return",
                 "RETURN_REQUEST (cursor + UPDATE ... WHERE CURRENT OF), ORDER_ITEM (read price)",
                 "Procedure PR_PROCESS_APPROVED_REFUNDS - explicit cursor c_approved in a cursor FOR loop; "
                 "TRG_RETURN_VALIDATE checks each refund",
                 "BEGIN PR_PROCESS_APPROVED_REFUNDS(:p_refund_count, :p_refund_total); END;",
                 ok, output, error,
                 [f"{res[0]} return(s) set to REFUNDED, total {money(res[1])}"] if ok else [])
    return back("returns", tid)


# ===========================================================================
# REPORTS and SQL LOG
# ===========================================================================
@app.route("/reports")
@app.route("/reports/<key>")
def reports(key=None):
    rep = REPORTS_BY_KEY.get(key or REPORTS[0]["key"])
    if not rep:
        abort(404)
    cols, rows = db.query_with_columns(rep["sql"])
    return render_template("reports.html", reports=REPORTS, rep=rep, cols=cols, rows=rows)


@app.route("/log")
def sql_log():
    return render_template("log.html", traces=list(TRACES))


if __name__ == "__main__":
    print(f"ShopFlow connecting to {config.DB_USER}@{config.DB_DSN}")
    print("Open http://127.0.0.1:5000 in your browser")
    app.run(debug=False, port=5000)
