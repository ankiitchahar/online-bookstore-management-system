CREATE TABLE accounts (
    account_id     NUMBER PRIMARY KEY,
    account_holder VARCHAR2(50),
    balance        NUMBER
);


INSERT INTO accounts VALUES (1001, 'Aman', 50000); 
INSERT INTO accounts VALUES (1002, 'Riya', 20000); 
INSERT INTO accounts VALUES (1003, 'Karan', 500);

COMMIT;

CREATE TABLE account_audit_log (
log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
account_id NUMBER, 
old_balance NUMBER, 
new_balance NUMBER, 
change_amount NUMBER, 
changed_by VARCHAR2(50), 
changed_on DATE
);

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
    )
    VALUES (
        :OLD.account_id,
        :OLD.balance,
        :NEW.balance,
        :NEW.balance - :OLD.balance, USER,
        SYSDATE
    );  

END trg_audit_balance;
/

UPDATE accounts
SET balance = balance - 5000 
WHERE account_id = 1001;

UPDATE accounts
SET balance = balance - 10000 
WHERE account_id = 1001;

UPDATE accounts
SET balance = balance + 10000 
WHERE account_id = 1002;

UPDATE accounts
SET account_holder = 'Aman Kumar' 
WHERE account_id = 1001;

COMMIT;

SELECT * FROM accounts;

SELECT * FROM account_audit_log 
ORDER BY log_id;


