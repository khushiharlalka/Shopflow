"""
db.py - everything that talks to Oracle lives in this one file.

The web pages never build SQL themselves; they call the helpers below:

    query(sql, params)      -> run a SELECT, get a list of rows (dicts)
    query_one(sql, params)  -> first row or None
    run_action(...)         -> run INSERT/UPDATE/DELETE or a PL/SQL block as
                               ONE transaction: COMMIT if it works,
                               ROLLBACK if Oracle raises an error

python-oracledb runs in "thin" mode, so no Oracle Client install is needed.
All values are passed as bind variables (:name), never glued into the SQL
text, which also protects against SQL injection.
"""
import oracledb
from flask import g

import config

_pool = None


def get_pool():
    """Create the connection pool once, on first use."""
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(user=config.DB_USER, password=config.DB_PASSWORD,
                                     dsn=config.DB_DSN, min=1, max=4, increment=1)
    return _pool


def get_conn():
    """One connection per web request, kept in Flask's g object."""
    if "conn" not in g:
        g.conn = get_pool().acquire()
        g.conn.autocommit = False                        # we decide when to COMMIT
        g.conn.cursor().callproc("DBMS_OUTPUT.ENABLE", [None])   # so PUT_LINE messages can be read
    return g.conn


def close_conn(_exc=None):
    conn = g.pop("conn", None)
    if conn is not None:
        try:
            conn.rollback()          # nothing unfinished is ever left behind
        finally:
            get_pool().release(conn)


def _rows(cur):
    cols = [d[0].lower() for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def query(sql, params=None):
    cur = get_conn().cursor()
    cur.execute(sql, params or {})
    return _rows(cur)


def query_one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None


def query_with_columns(sql, params=None):
    """For the Reports page: returns (column names, rows as lists)."""
    cur = get_conn().cursor()
    cur.execute(sql, params or {})
    cols = [d[0] for d in cur.description]
    return cols, [list(r) for r in cur.fetchall()]


def read_dbms_output(cur):
    """Collect the lines that PL/SQL printed with DBMS_OUTPUT.PUT_LINE."""
    lines = []
    line_var = cur.var(str)
    status_var = cur.var(int)
    while True:
        cur.callproc("DBMS_OUTPUT.GET_LINE", (line_var, status_var))
        if status_var.getvalue() != 0:
            break
        lines.append(line_var.getvalue() or "")
    return lines


def oracle_message(error):
    """'ORA-20215: Insufficient stock ...' - first line only, without the trigger stack."""
    err, = error.args
    return str(getattr(err, "message", err)).splitlines()[0]


def run_action(work):
    """
    Run one business transaction.
      work(cur) does the SQL / PL/SQL and may return a value.
    Returns (ok, value, output_lines, error_message).
    """
    conn = get_conn()
    cur = conn.cursor()
    read_dbms_output(cur)                       # clear old messages
    try:
        value = work(cur)
        output = read_dbms_output(cur)
        conn.commit()                           # all steps succeeded -> save
        return True, value, output, None
    except oracledb.DatabaseError as e:
        conn.rollback()                         # any step failed -> undo everything
        return False, None, read_dbms_output(cur), oracle_message(e)
