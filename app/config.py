"""
config.py - database connection settings.

Change these three values to match YOUR Oracle installation, or set the
environment variables instead (so the password is not typed into the code):

    SHOPFLOW_DB_USER      Oracle username            e.g. shopflow
    SHOPFLOW_DB_PASSWORD  Oracle password
    SHOPFLOW_DB_DSN       host:port/service_name     e.g. localhost:1521/XEPDB1

Common service names: XE (Oracle 11g XE), XEPDB1 (18c/21c XE),
FREEPDB1 (23ai Free), ORCLPDB / ORCLPDB1 (Enterprise).
"""
import os

DB_USER = os.environ.get("SHOPFLOW_DB_USER", "shopflow")
DB_PASSWORD = os.environ.get("SHOPFLOW_DB_PASSWORD", "ShopFlow_2026")
DB_DSN = os.environ.get("SHOPFLOW_DB_DSN", "localhost:1521/XEPDB1")

# Used by Flask to sign the session cookie (stores the "behind the scenes" log)
SECRET_KEY = os.environ.get("SHOPFLOW_SECRET_KEY", "shopflow-dbms-project")
