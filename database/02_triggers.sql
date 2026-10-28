-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 02_triggers.sql
-- Description: Business Rule Enforcement and Auditing Triggers
-- ============================================================================

-- 1. Trigger: Auto-update user timestamp on modification
CREATE OR REPLACE TRIGGER trg_users_update_ts
BEFORE UPDATE ON USERS
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;
END;
/

-- 2. Trigger: Auto-update book timestamp on modification
CREATE OR REPLACE TRIGGER trg_books_update_ts
BEFORE UPDATE ON BOOKS
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSDATE;
END;
/

-- 3. Trigger: Prevent Negative Stock and Validate Inventory
CREATE OR REPLACE TRIGGER trg_prevent_negative_stock
BEFORE INSERT OR UPDATE OF stock_quantity ON BOOKS
FOR EACH ROW
BEGIN
    IF :NEW.stock_quantity < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: Stock quantity cannot be negative for book: ' || :NEW.title);
    END IF;
END;
/

-- 4. Trigger: Audit price and stock modifications on Books
CREATE OR REPLACE TRIGGER trg_audit_book_changes
AFTER UPDATE OF price, stock_quantity ON BOOKS
FOR EACH ROW
DECLARE
    v_details VARCHAR2(2000) := '';
BEGIN
    IF :OLD.price != :NEW.price THEN
        v_details := v_details || 'Price changed from $' || TO_CHAR(:OLD.price, 'FM9990.00') || 
                     ' to $' || TO_CHAR(:NEW.price, 'FM9990.00') || '; ';
    END IF;
    
    IF :OLD.stock_quantity != :NEW.stock_quantity THEN
        v_details := v_details || 'Stock quantity changed from ' || :OLD.stock_quantity || 
                     ' to ' || :NEW.stock_quantity || '; ';
    END IF;

    IF LENGTH(v_details) > 0 THEN
        INSERT INTO AUDIT_LOGS (
            log_id, action_type, table_name, record_id, performed_by, action_time, details
        ) VALUES (
            AUDIT_SEQ.NEXTVAL,
            'UPDATE',
            'BOOKS',
            TO_CHAR(:NEW.book_id),
            NVL(SYS_CONTEXT('USERENV', 'SESSION_USER'), 'SYSTEM'),
            SYSDATE,
            v_details
        );
    END IF;
END;
/

-- 5. Trigger: Audit Order Status Transitions and Auto-Restock on Cancellation
CREATE OR REPLACE TRIGGER trg_order_status_audit
AFTER UPDATE OF order_status ON ORDERS
FOR EACH ROW
BEGIN
    -- Log the status transition
    INSERT INTO AUDIT_LOGS (
        log_id, action_type, table_name, record_id, performed_by, action_time, details
    ) VALUES (
        AUDIT_SEQ.NEXTVAL,
        'STATUS_CHANGE',
        'ORDERS',
        TO_CHAR(:NEW.order_id),
        NVL(SYS_CONTEXT('USERENV', 'SESSION_USER'), 'SYSTEM'),
        SYSDATE,
        'Order status changed from [' || :OLD.order_status || '] to [' || :NEW.order_status || ']'
    );

    -- If order is cancelled from any non-cancelled state, restore inventory
    IF :NEW.order_status = 'CANCELLED' AND :OLD.order_status != 'CANCELLED' THEN
        FOR item IN (SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = :NEW.order_id) LOOP
            UPDATE BOOKS
            SET stock_quantity = stock_quantity + item.quantity
            WHERE book_id = item.book_id;
        END LOOP;
        
        INSERT INTO AUDIT_LOGS (
            log_id, action_type, table_name, record_id, performed_by, action_time, details
        ) VALUES (
            AUDIT_SEQ.NEXTVAL,
            'RESTOCK_ON_CANCEL',
            'ORDERS',
            TO_CHAR(:NEW.order_id),
            'SYSTEM',
            SYSDATE,
            'Inventory automatically restored for cancelled order #' || :NEW.order_id
        );
    END IF;
END;
/

PROMPT Triggers Created Successfully.
