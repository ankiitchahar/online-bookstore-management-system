-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- STUDENT LEVEL MINI PROJECT (Easy to Understand & Explain in Viva)
-- ============================================================================
-- This single script contains:
-- 1. Tables (Users, Books, Cart, Orders, Order_Items)
-- 2. Sequences for Auto IDs
-- 3. Stored Procedures (Registration, Add to Cart, Place Order)
-- 4. Stored Functions (Calculate Total, Stock Check)
-- 5. Database Triggers (Auto stock deduction, Restock on cancel)
-- 6. Cursor implementation (Displaying books)
-- 7. Sample Data & Test Execution
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ----------------------------------------------------------------------------
-- STEP 1: CLEANUP OLD TABLES IF THEY ALREADY EXIST
-- ----------------------------------------------------------------------------
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN 
             ('ORDER_ITEMS', 'ORDERS', 'CART', 'BOOKS', 'USERS')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    
    FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN 
             ('USER_SEQ', 'BOOK_SEQ', 'ORDER_SEQ', 'CART_SEQ', 'ITEM_SEQ')) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

-- ----------------------------------------------------------------------------
-- STEP 2: SEQUENCES (Auto-generating IDs)
-- ----------------------------------------------------------------------------
CREATE SEQUENCE USER_SEQ START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE BOOK_SEQ START WITH 101 INCREMENT BY 1;
CREATE SEQUENCE CART_SEQ START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE ORDER_SEQ START WITH 5001 INCREMENT BY 1;
CREATE SEQUENCE ITEM_SEQ START WITH 1 INCREMENT BY 1;

-- ----------------------------------------------------------------------------
-- STEP 3: CREATING TABLES
-- ----------------------------------------------------------------------------

-- Table 1: USERS (Customer aur Admin ki details)
CREATE TABLE USERS (
    user_id       NUMBER PRIMARY KEY,
    name          VARCHAR2(100) NOT NULL,
    email         VARCHAR2(100) UNIQUE NOT NULL,
    password      VARCHAR2(50) NOT NULL,
    phone         VARCHAR2(15),
    role          VARCHAR2(10) DEFAULT 'CUSTOMER',  -- 'CUSTOMER' ya 'ADMIN'
    created_date  DATE DEFAULT SYSDATE
);

-- Table 2: BOOKS (Book catalog and stock)
CREATE TABLE BOOKS (
    book_id       NUMBER PRIMARY KEY,
    title         VARCHAR2(150) NOT NULL,
    author        VARCHAR2(100) NOT NULL,
    category      VARCHAR2(50),
    price         NUMBER(8,2) NOT NULL,
    stock         NUMBER(5) DEFAULT 0,
    CONSTRAINT chk_price CHECK (price > 0),
    CONSTRAINT chk_stock CHECK (stock >= 0)
);

-- Table 3: CART (Shopping cart items)
CREATE TABLE CART (
    cart_id       NUMBER PRIMARY KEY,
    user_id       NUMBER REFERENCES USERS(user_id) ON DELETE CASCADE,
    book_id       NUMBER REFERENCES BOOKS(book_id) ON DELETE CASCADE,
    quantity      NUMBER DEFAULT 1,
    CONSTRAINT chk_qty CHECK (quantity > 0)
);

-- Table 4: ORDERS (Order summary)
CREATE TABLE ORDERS (
    order_id      NUMBER PRIMARY KEY,
    user_id       NUMBER REFERENCES USERS(user_id),
    order_date    DATE DEFAULT SYSDATE,
    total_amount  NUMBER(10,2) NOT NULL,
    order_status  VARCHAR2(20) DEFAULT 'PLACED'  -- 'PLACED', 'CANCELLED'
);

-- Table 5: ORDER_ITEMS (Books inside each order)
CREATE TABLE ORDER_ITEMS (
    item_id       NUMBER PRIMARY KEY,
    order_id      NUMBER REFERENCES ORDERS(order_id) ON DELETE CASCADE,
    book_id       NUMBER REFERENCES BOOKS(book_id),
    quantity      NUMBER NOT NULL,
    unit_price    NUMBER(8,2) NOT NULL
);

PROMPT Tables and Sequences created successfully!

-- ----------------------------------------------------------------------------
-- STEP 4: PL/SQL FUNCTIONS
-- ----------------------------------------------------------------------------

-- Function 1: Check if book is in stock
-- Concept: Function hamesha ek value RETURN karta hai.
CREATE OR REPLACE FUNCTION check_book_stock(
    p_book_id IN NUMBER,
    p_qty     IN NUMBER
) RETURN BOOLEAN IS
    v_available NUMBER := 0;
BEGIN
    SELECT stock INTO v_available
    FROM BOOKS
    WHERE book_id = p_book_id;

    IF v_available >= p_qty THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
END;
/

-- Function 2: Calculate Cart Total for a User
CREATE OR REPLACE FUNCTION get_cart_total(
    p_user_id IN NUMBER
) RETURN NUMBER IS
    v_total NUMBER := 0;
BEGIN
    SELECT NVL(SUM(c.quantity * b.price), 0)
    INTO v_total
    FROM CART c
    JOIN BOOKS b ON c.book_id = b.book_id
    WHERE c.user_id = p_user_id;

    RETURN v_total;
END;
/

PROMPT Functions created successfully!

-- ----------------------------------------------------------------------------
-- STEP 5: PL/SQL PROCEDURES
-- ----------------------------------------------------------------------------

-- Procedure 1: Register New User
-- Concept: Procedure koi action perform karta hai (INSERT/UPDATE).
CREATE OR REPLACE PROCEDURE register_user(
    p_name     IN VARCHAR2,
    p_email    IN VARCHAR2,
    p_password IN VARCHAR2,
    p_phone    IN VARCHAR2,
    p_role     IN VARCHAR2 DEFAULT 'CUSTOMER'
) IS
BEGIN
    INSERT INTO USERS (user_id, name, email, password, phone, role)
    VALUES (USER_SEQ.NEXTVAL, p_name, LOWER(p_email), p_password, p_phone, UPPER(p_role));
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: User ' || p_name || ' registered successfully!');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Error: Email ' || p_email || ' already registered!');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in registration: ' || SQLERRM);
END;
/

-- Procedure 2: Add Book to Cart with Stock Verification
CREATE OR REPLACE PROCEDURE add_to_cart(
    p_user_id IN NUMBER,
    p_book_id IN NUMBER,
    p_quantity IN NUMBER DEFAULT 1
) IS
    v_exists NUMBER := 0;
BEGIN
    -- Check if stock is available using our function
    IF NOT check_book_stock(p_book_id, p_quantity) THEN
        DBMS_OUTPUT.PUT_LINE('Error: Requested quantity not available in stock.');
        RETURN;
    END IF;

    -- Check if item is already in cart
    SELECT COUNT(*) INTO v_exists 
    FROM CART 
    WHERE user_id = p_user_id AND book_id = p_book_id;

    IF v_exists > 0 THEN
        UPDATE CART 
        SET quantity = quantity + p_quantity
        WHERE user_id = p_user_id AND book_id = p_book_id;
        DBMS_OUTPUT.PUT_LINE('Updated cart quantity.');
    ELSE
        INSERT INTO CART (cart_id, user_id, book_id, quantity)
        VALUES (CART_SEQ.NEXTVAL, p_user_id, p_book_id, p_quantity);
        DBMS_OUTPUT.PUT_LINE('Book added to cart successfully.');
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error adding to cart: ' || SQLERRM);
END;
/

-- Procedure 3: Place Order from Cart (ATOMIC TRANSACTION)
-- Concept: Cursor use karta hai cart ke saare items iterate karne ke liye.
CREATE OR REPLACE PROCEDURE place_order(
    p_user_id IN NUMBER
) IS
    v_order_id NUMBER;
    v_total    NUMBER;
    v_cart_cnt NUMBER;

    -- EXPLICIT CURSOR: cart ke saare books padhne ke liye
    CURSOR c_cart IS
        SELECT c.book_id, c.quantity, b.price, b.title, b.stock
        FROM CART c
        JOIN BOOKS b ON c.book_id = b.book_id
        WHERE c.user_id = p_user_id;

BEGIN
    -- 1. Check if cart is empty
    SELECT COUNT(*) INTO v_cart_cnt FROM CART WHERE user_id = p_user_id;
    IF v_cart_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Cart is empty. Cannot place order.');
        RETURN;
    END IF;

    -- 2. Calculate Total
    v_total := get_cart_total(p_user_id);

    -- 3. Verify stock for each item using cursor
    FOR item IN c_cart LOOP
        IF item.stock < item.quantity THEN
            DBMS_OUTPUT.PUT_LINE('Order Failed: Out of stock for book "' || item.title || '"');
            RETURN;
        END IF;
    END LOOP;

    -- 4. Create Order Header
    v_order_id := ORDER_SEQ.NEXTVAL;
    INSERT INTO ORDERS (order_id, user_id, order_date, total_amount, order_status)
    VALUES (v_order_id, p_user_id, SYSDATE, v_total, 'PLACED');

    -- 5. Copy Cart Items to ORDER_ITEMS and deduct stock
    FOR item IN c_cart LOOP
        INSERT INTO ORDER_ITEMS (item_id, order_id, book_id, quantity, unit_price)
        VALUES (ITEM_SEQ.NEXTVAL, v_order_id, item.book_id, item.quantity, item.price);

        -- Deduct inventory
        UPDATE BOOKS
        SET stock = stock - item.quantity
        WHERE book_id = item.book_id;
    END LOOP;

    -- 6. Empty the shopping cart
    DELETE FROM CART WHERE user_id = p_user_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Order #' || v_order_id || ' placed! Total Amount: Rs.' || v_total);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Order failed: ' || SQLERRM);
END;
/

-- Procedure 4: Display All Books Using Cursor (Viva examiner loves this!)
CREATE OR REPLACE PROCEDURE display_all_books IS
    CURSOR book_cur IS
        SELECT book_id, title, author, price, stock
        FROM BOOKS
        ORDER BY book_id;

    v_rec book_cur%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('ID', 6) || RPAD('TITLE', 30) || RPAD('AUTHOR', 20) || RPAD('PRICE', 10) || 'STOCK');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');

    OPEN book_cur;
    LOOP
        FETCH book_cur INTO v_rec;
        EXIT WHEN book_cur%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_rec.book_id, 6) ||
            RPAD(SUBSTR(v_rec.title, 1, 28), 30) ||
            RPAD(SUBSTR(v_rec.author, 1, 18), 20) ||
            RPAD('Rs.' || v_rec.price, 10) ||
            v_rec.stock
        );
    END LOOP;
    CLOSE book_cur;
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------');
END;
/

PROMPT Procedures created successfully!

-- ----------------------------------------------------------------------------
-- STEP 6: PL/SQL TRIGGERS
-- ----------------------------------------------------------------------------

-- Trigger 1: Negative stock rokna (BEFORE UPDATE)
CREATE OR REPLACE TRIGGER trg_check_stock
BEFORE INSERT OR UPDATE OF stock ON BOOKS
FOR EACH ROW
BEGIN
    IF :NEW.stock < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Stock cannot be negative for book: ' || :NEW.title);
    END IF;
END;
/

-- Trigger 2: Agar Order CANCEL ho, toh stock wapas restore karna (AFTER UPDATE)
CREATE OR REPLACE TRIGGER trg_restore_stock_on_cancel
AFTER UPDATE OF order_status ON ORDERS
FOR EACH ROW
BEGIN
    IF :NEW.order_status = 'CANCELLED' AND :OLD.order_status != 'CANCELLED' THEN
        FOR item IN (SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = :NEW.order_id) LOOP
            UPDATE BOOKS
            SET stock = stock + item.quantity
            WHERE book_id = item.book_id;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Trigger: Inventory automatically restored for cancelled order #' || :NEW.order_id);
    END IF;
END;
/

PROMPT Triggers created successfully!

-- ----------------------------------------------------------------------------
-- STEP 7: SAMPLE DATA SEEDING
-- ----------------------------------------------------------------------------

-- Insert Books
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'Oracle PL/SQL Programming', 'Steven Feuerstein', 'Database', 550.00, 25);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'Database System Concepts', 'Silberschatz', 'Database', 650.00, 15);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'Clean Code', 'Robert C. Martin', 'Programming', 450.00, 20);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'The Pragmatic Programmer', 'Andrew Hunt', 'Programming', 500.00, 10);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'Atomic Habits', 'James Clear', 'Self-Help', 350.00, 30);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'Wings of Fire', 'Dr. A.P.J. Abdul Kalam', 'Biography', 280.00, 18);
INSERT INTO BOOKS VALUES (BOOK_SEQ.NEXTVAL, 'To Kill a Mockingbird', 'Harper Lee', 'Fiction', 300.00, 5); -- Low stock
COMMIT;

-- Register Users via Procedure
BEGIN
    register_user('Rahul Sharma', 'rahul@gmail.com', 'rahul123', '9876543210', 'CUSTOMER');
    register_user('Priya Singh', 'priya@gmail.com', 'priya123', '9123456780', 'CUSTOMER');
    register_user('Admin User', 'admin@bookstore.com', 'admin123', '9998887770', 'ADMIN');
END;
/

-- ----------------------------------------------------------------------------
-- STEP 8: TEST RUN (Checking Everything Works)
-- ----------------------------------------------------------------------------
PROMPT
PROMPT ========================================================
PROMPT CURRENT CATALOG IN DATABASE (Via Cursor Procedure):
PROMPT ========================================================
EXEC display_all_books;

PROMPT
PROMPT ========================================================
PROMPT SIMULATING SHOPPING & ORDER PLACEMENT
PROMPT ========================================================
BEGIN
    -- Rahul (User ID 1) adds Book 101 (PL/SQL) and Book 105 (Atomic Habits) to cart
    DBMS_OUTPUT.PUT_LINE('--- 1. Rahul Adding Items to Cart ---');
    add_to_cart(1, 101, 2);  -- 2 copies of PL/SQL book
    add_to_cart(1, 105, 1);  -- 1 copy of Atomic Habits

    -- Place order
    DBMS_OUTPUT.PUT_LINE('--- 2. Placing Order for Rahul ---');
    place_order(1);
END;
/

PROMPT
PROMPT ========================================================
PROMPT CATALOG STOCK AFTER ORDER (Stock Reduced automatically):
PROMPT ========================================================
EXEC display_all_books;

PROMPT
PROMPT ========================================================
PROMPT TESTING TRIGGER: CANCELLING ORDER #5001 (Stock Restores)
PROMPT ========================================================
UPDATE ORDERS SET order_status = 'CANCELLED' WHERE order_id = 5001;
COMMIT;

PROMPT
PROMPT ========================================================
PROMPT CATALOG STOCK AFTER CANCELLATION (Restored via Trigger):
PROMPT ========================================================
EXEC display_all_books;

PROMPT ========================================================
PROMPT ALL DONE! SCRIPT FINISHED SUCCESSFULLY!
PROMPT ========================================================
