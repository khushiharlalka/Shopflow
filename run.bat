@echo off
REM ShopFlow launcher for Windows. Edit the three lines below for your Oracle.
set SHOPFLOW_DB_USER=shopflow
set SHOPFLOW_DB_PASSWORD=ShopFlow_2026
set SHOPFLOW_DB_DSN=localhost:1521/XEPDB1

cd /d "%~dp0"
python -m pip install -q -r requirements.txt
start "" http://127.0.0.1:5000
python app\app.py
pause
