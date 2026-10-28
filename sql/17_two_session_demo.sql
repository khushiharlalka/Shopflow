-- =====================================================================
-- FILE      : 17_two_session_demo.sql
-- PURPOSE   : (Report Ch. 8.8 Concurrency, 8.9 Deadlock)
--             Shows locking, "no dirty reads" and a real deadlock.
--
-- !!! DO NOT press F5 on this file. !!!
-- You need TWO separate sessions of the SHOPFLOW connection:
--   Window 1 = the normal ShopFlow worksheet
--   Window 2 = an UNSHARED worksheet: press Ctrl+Shift+N (Cmd+Shift+N on
--              Mac) and choose the ShopFlow connection.
-- Copy each line into the window named, and run it with Ctrl+Enter
-- (Cmd+Enter on Mac), in the numbered order. Everything ends with ROLLBACK,
-- so no data changes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DEMO 1: row locking and no dirty read
-- ---------------------------------------------------------------------
-- 1. WINDOW 1: change the price but do NOT commit
UPDATE PRODUCT SET Unit_Price = 1599 WHERE Product_ID = 1001;

-- 2. WINDOW 2: read it -> still 1499 (Window 1's change is not committed,
--    so it is invisible: no dirty read)
SELECT Product_ID, Unit_Price FROM PRODUCT WHERE Product_ID = 1001;

-- 3. WINDOW 2: try to change the same row -> it WAITS (spinning icon),
--    because Window 1 holds a row lock
UPDATE PRODUCT SET Unit_Price = 1699 WHERE Product_ID = 1001;

-- 4. WINDOW 1: release the lock
ROLLBACK;
--    -> Window 2 immediately finishes: "1 row updated."

-- 5. WINDOW 2: undo
ROLLBACK;

-- ---------------------------------------------------------------------
-- DEMO 2: deadlock
-- ---------------------------------------------------------------------
-- 6. WINDOW 1: lock product 1001
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 1 WHERE Product_ID = 1001;

-- 7. WINDOW 2: lock product 1002
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 1 WHERE Product_ID = 1002;

-- 8. WINDOW 1: now ask for 1002 -> WAITS for Window 2
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 1 WHERE Product_ID = 1002;

-- 9. WINDOW 2: now ask for 1001 -> each window waits for the other = DEADLOCK.
--    Within a few seconds Oracle detects it and one window shows:
--    ORA-00060: deadlock detected while waiting for resource
--    Oracle cancels only that one statement, so the other can continue.
UPDATE PRODUCT SET Stock_Quantity = Stock_Quantity + 1 WHERE Product_ID = 1001;

-- 10. BOTH WINDOWS: undo everything
ROLLBACK;

-- ShopFlow's own protection: PR_ADD_ORDER_ITEM and TRG_ORDER_ITEM_STOCK lock
-- the product row with SELECT ... FOR UPDATE before checking stock, so two
-- customers buying the last units cannot both succeed (no lost update).
