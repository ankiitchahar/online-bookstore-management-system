-- ============================================================================
-- EXPERIMENT NO. 6 (PL/SQL)
-- Aim: Database Trigger to Maintain an Audit Log of Account Balance Changes
-- Compatible with: Oracle Database (11g, 12c, 19c, 21c, 23c, & Oracle LiveSQL)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;

-- ----------------------------------------------------------------------------
-- STEP 1: CLEANUP PREVIOUS TABLES (Safe Drop)
-- ----------------------------------------------------------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE account_audit_log CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE accounts CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- ----------------------------------------------------------------------------
-- STEP 2: CREATE ACCOUNTS TABLE & INSERT INITIAL DATA (Section 6)
-- ----------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id     NUMBER PRIMARY KEY,
    account_holder VARCHAR2(50),
    balance        NUMBER
);

INSERT INTO accounts VALUES (1001, 'Aman', 50000);
INSERT INTO accounts VALUES (1002, 'Riya', 20000);
INSERT INTO accounts VALUES (1003, 'Karan', 500);
COMMIT;

PROMPT Initial Accounts Data Created:
SELECT * FROM accounts ORDER BY account_id;

-- ----------------------------------------------------------------------------
-- STEP 3: CREATE AUDIT LOG TABLE (Section 6)
-- ----------------------------------------------------------------------------
CREATE TABLE account_audit_log (
    log_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id    NUMBER,
    old_balance   NUMBER,
    new_balance   NUMBER,
    change_amount NUMBER,
    changed_by    VARCHAR2(50),
    changed_on    DATE
);

PROMPT Audit Log Table Created Successfully!

-- ----------------------------------------------------------------------------
-- STEP 4: HELPER PROCEDURE transfer_funds (From Exp 5, needed for Section 11)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_acc IN  NUMBER,
    p_to_acc   IN  NUMBER,
    p_amount   IN  NUMBER,
    o_status   OUT VARCHAR2
) IS
    v_balance NUMBER;
BEGIN
    -- Check sender balance
    SELECT balance INTO v_balance FROM accounts WHERE account_id = p_from_acc FOR UPDATE;
    
    IF v_balance < p_amount THEN
        o_status := 'FAILED: Insufficient Balance';
        ROLLBACK;
        RETURN;
    END IF;

    -- Debit from sender
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_acc;

    -- Credit to receiver
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_acc;

    COMMIT;
    o_status := 'SUCCESS: Transferred ' || p_amount;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        o_status := 'ERROR: ' || SQLERRM;
END transfer_funds;
/

-- ----------------------------------------------------------------------------
-- STEP 5: CREATE THE AUDIT TRIGGER (Section 8)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audit_balance
AFTER UPDATE OF balance ON accounts
FOR EACH ROW
WHEN (OLD.balance <> NEW.balance)
BEGIN
    INSERT INTO account_audit_log (
        account_id,
        old_balance,
        new_balance,
        change_amount,
        changed_by,
        changed_on
    ) VALUES (
        :OLD.account_id,
        :OLD.balance,
        :NEW.balance,
        :NEW.balance - :OLD.balance,
        USER,
        SYSDATE
    );
END trg_audit_balance;
/

PROMPT Trigger trg_audit_balance Created Successfully!

-- ----------------------------------------------------------------------------
-- STEP 6: DEMONSTRATING THE TRIGGER (Section 11)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ========================================================
PROMPT EXECUTING 3 TEST CHANGES:
PROMPT ========================================================

-- 1. A direct withdrawal of 5000 from Aman (Trigger fires 1 time)
PROMPT 1. Withdrawing 5000 from Aman (Account 1001)...
UPDATE accounts SET balance = balance - 5000 WHERE account_id = 1001;

-- 2. Fund transfer of 10000 from Aman to Riya (Trigger fires 2 times)
PROMPT 2. Transferring 10000 from Aman to Riya using transfer_funds procedure...
DECLARE
    v_status VARCHAR2(100);
BEGIN
    transfer_funds(1001, 1002, 10000, v_status);
    DBMS_OUTPUT.PUT_LINE('Procedure Output: ' || v_status);
END;
/

-- 3. Changing account holder name (Balance unchanged -> Trigger will NOT fire)
PROMPT 3. Updating account holder name only (Trigger should NOT fire)...
UPDATE accounts SET account_holder = 'Aman Kumar' WHERE account_id = 1001;

COMMIT;

-- ----------------------------------------------------------------------------
-- STEP 7: VIEW AUDIT LOG RESULTS (Expected Output from Page 6)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ========================================================
PROMPT FINAL RESULT: CONTENTS OF account_audit_log
PROMPT ========================================================

COLUMN log_id FORMAT 9999 HEADING "LOG_ID"
COLUMN account_id FORMAT 999999 HEADING "ACCOUNT_ID"
COLUMN old_balance FORMAT 9999999 HEADING "OLD_BALANCE"
COLUMN new_balance FORMAT 9999999 HEADING "NEW_BALANCE"
COLUMN change_amount FORMAT 9999999 HEADING "CHANGE_AMOUNT"
COLUMN changed_by FORMAT A15 HEADING "CHANGED_BY"
COLUMN changed_on FORMAT A12 HEADING "CHANGED_ON"

SELECT log_id, account_id, old_balance, new_balance, change_amount, changed_by, TO_CHAR(changed_on, 'YYYY-MM-DD') AS changed_on
FROM account_audit_log
ORDER BY log_id;

PROMPT
PROMPT ========================================================
PROMPT CURRENT STATUS OF accounts TABLE:
PROMPT ========================================================
SELECT * FROM accounts ORDER BY account_id;
