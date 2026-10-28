-- =====================================================================
-- FILE      : 03_sequences.sql
-- PURPOSE   : Number generators for the automatic primary keys.
--
-- START WITH   : first number the sequence gives out.
-- INCREMENT BY : how much is added each time (1 = 101, 102, 103 ...).
-- NOCACHE      : Oracle does not pre-allocate numbers in memory, so fewer
--                numbers are lost on a restart (gaps are still possible
--                after ROLLBACK, because a used sequence number is never
--                given back - this is normal and acceptable).
-- NOCYCLE      : after the maximum value the sequence stops instead of
--                starting again from the beginning, so IDs never repeat.
--
-- Different starting numbers make IDs easy to recognise during the viva:
--   Customers 101.., Categories 1.., Products 1001.., Orders 5001..,
--   Payments 9001.., Returns 7001..
-- =====================================================================
SET DEFINE OFF

CREATE SEQUENCE SEQ_CUSTOMER       START WITH 101  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CATEGORY       START WITH 1    INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PRODUCT        START WITH 1001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CUSTOMER_ORDER START WITH 5001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PAYMENT        START WITH 9001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_RETURN_REQUEST START WITH 7001 INCREMENT BY 1 NOCACHE NOCYCLE;
