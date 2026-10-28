#!/usr/bin/env bash
# ShopFlow launcher for macOS / Linux.
# Edit the three lines below if your Oracle details are different.
#   Docker on a Mac (Oracle 23ai Free) -> service name FREEPDB1
#   Oracle 21c XE                      -> service name XEPDB1
export SHOPFLOW_DB_USER=shopflow
export SHOPFLOW_DB_PASSWORD=ShopFlow_2026
export SHOPFLOW_DB_DSN=localhost:1521/FREEPDB1

cd "$(dirname "$0")"

# A private Python environment in the .venv folder (made the first time only),
# so the add-ons never clash with the Mac's own Python.
if [ ! -d .venv ]; then
  echo "First run: setting up Python add-ons (about 1 minute)..."
  python3 -m venv .venv || { echo "python3 not found - install Python from python.org"; exit 1; }
fi
source .venv/bin/activate
python -m pip install -q -r requirements.txt

( sleep 3; open "http://127.0.0.1:5000" 2>/dev/null ) &
python app/app.py
