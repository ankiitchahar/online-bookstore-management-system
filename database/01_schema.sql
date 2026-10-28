-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 01_schema.sql
-- Description: Core Database Schema Definition
-- Compatible with: Oracle Database 11g, 12c, 18c, 19c, 21c, 23c & Oracle LiveSQL
-- ============================================================================

-- Clean up existing objects if any (safe drop)
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN 
             ('AUDIT_LOGS', 'ORDER_ITEMS', 'ORDERS', 'CART_ITEMS', 'BOOKS', 'CATEGORIES', 'USERS', 'ROLES')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    
    FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN 
             ('USER_SEQ', 'CATEGORY_SEQ', 'BOOK_SEQ', 'CART_SEQ', 'ORDER_SEQ', 'ORDER_ITEM_SEQ', 'AUDIT_SEQ')) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

-- ============================================================================
-- 1. SEQUENCES
-- ============================================================================
CREATE SEQUENCE USER_SEQ START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE CATEGORY_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE BOOK_SEQ START WITH 5001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE CART_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE ORDER_SEQ START WITH 10001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE ORDER_ITEM_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE AUDIT_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

-- ============================================================================
-- 2. ROLES TABLE
-- ============================================================================
CREATE TABLE ROLES (
    role_id         NUMBER(5) PRIMARY KEY,
    role_name       VARCHAR2(30) NOT NULL UNIQUE,
    description     VARCHAR2(255)
);

-- ============================================================================
-- 3. USERS TABLE
-- ============================================================================
CREATE TABLE USERS (
    user_id         NUMBER(10) PRIMARY KEY,
    role_id         NUMBER(5) DEFAULT 2 NOT NULL,
    full_name       VARCHAR2(100) NOT NULL,
    email           VARCHAR2(100) NOT NULL UNIQUE,
    password_hash   VARCHAR2(256) NOT NULL,
    salt            VARCHAR2(64) NOT NULL,
    phone           VARCHAR2(20),
    shipping_address VARCHAR2(500),
    status          VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    created_at      DATE DEFAULT SYSDATE NOT NULL,
    updated_at      DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT chk_user_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    CONSTRAINT chk_user_email CHECK (REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES ROLES(role_id)
);

-- ============================================================================
-- 4. CATEGORIES TABLE
-- ============================================================================
CREATE TABLE CATEGORIES (
    category_id     NUMBER(5) PRIMARY KEY,
    category_name   VARCHAR2(50) NOT NULL UNIQUE,
    description     VARCHAR2(300),
    is_active       CHAR(1) DEFAULT 'Y' NOT NULL,
    CONSTRAINT chk_category_active CHECK (is_active IN ('Y', 'N'))
);

-- ============================================================================
-- 5. BOOKS TABLE
-- ============================================================================
CREATE TABLE BOOKS (
    book_id         NUMBER(10) PRIMARY KEY,
    isbn            VARCHAR2(20) NOT NULL UNIQUE,
    title           VARCHAR2(200) NOT NULL,
    author          VARCHAR2(150) NOT NULL,
    category_id     NUMBER(5) NOT NULL,
    price           NUMBER(10,2) NOT NULL,
    stock_quantity  NUMBER(6) DEFAULT 0 NOT NULL,
    publication_year NUMBER(4),
    description     VARCHAR2(2000),
    cover_image     VARCHAR2(500),
    is_active       CHAR(1) DEFAULT 'Y' NOT NULL,
    created_at      DATE DEFAULT SYSDATE NOT NULL,
    updated_at      DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT chk_book_price CHECK (price >= 0),
    CONSTRAINT chk_book_stock CHECK (stock_quantity >= 0),
    CONSTRAINT chk_book_active CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT fk_books_category FOREIGN KEY (category_id) REFERENCES CATEGORIES(category_id)
);

-- ============================================================================
-- 6. CART ITEMS TABLE
-- ============================================================================
CREATE TABLE CART_ITEMS (
    cart_id         NUMBER(10) PRIMARY KEY,
    user_id         NUMBER(10) NOT NULL,
    book_id         NUMBER(10) NOT NULL,
    quantity        NUMBER(5) DEFAULT 1 NOT NULL,
    added_at        DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT chk_cart_quantity CHECK (quantity > 0),
    CONSTRAINT uq_user_book UNIQUE (user_id, book_id),
    CONSTRAINT fk_cart_user FOREIGN KEY (user_id) REFERENCES USERS(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_book FOREIGN KEY (book_id) REFERENCES BOOKS(book_id) ON DELETE CASCADE
);

-- ============================================================================
-- 7. ORDERS TABLE
-- ============================================================================
CREATE TABLE ORDERS (
    order_id        NUMBER(10) PRIMARY KEY,
    user_id         NUMBER(10) NOT NULL,
    order_date      DATE DEFAULT SYSDATE NOT NULL,
    subtotal        NUMBER(10,2) NOT NULL,
    shipping_fee    NUMBER(10,2) DEFAULT 0.00 NOT NULL,
    tax_amount      NUMBER(10,2) DEFAULT 0.00 NOT NULL,
    total_amount    NUMBER(10,2) NOT NULL,
    shipping_address VARCHAR2(500) NOT NULL,
    payment_method  VARCHAR2(30) DEFAULT 'CREDIT_CARD' NOT NULL,
    payment_status  VARCHAR2(20) DEFAULT 'PAID' NOT NULL,
    order_status    VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    notes           VARCHAR2(500),
    CONSTRAINT chk_order_status CHECK (order_status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    CONSTRAINT chk_payment_status CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('CREDIT_CARD', 'DEBIT_CARD', 'PAYPAL', 'CASH_ON_DELIVERY', 'UPI')),
    CONSTRAINT chk_order_totals CHECK (total_amount >= 0),
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

-- ============================================================================
-- 8. ORDER ITEMS TABLE
-- ============================================================================
CREATE TABLE ORDER_ITEMS (
    order_item_id   NUMBER(10) PRIMARY KEY,
    order_id        NUMBER(10) NOT NULL,
    book_id         NUMBER(10) NOT NULL,
    quantity        NUMBER(5) NOT NULL,
    unit_price      NUMBER(10,2) NOT NULL,
    subtotal        NUMBER(10,2) NOT NULL,
    CONSTRAINT chk_order_item_qty CHECK (quantity > 0),
    CONSTRAINT chk_order_item_price CHECK (unit_price >= 0),
    CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES ORDERS(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_items_book FOREIGN KEY (book_id) REFERENCES BOOKS(book_id)
);

-- ============================================================================
-- 9. AUDIT LOGS TABLE
-- ============================================================================
CREATE TABLE AUDIT_LOGS (
    log_id          NUMBER(10) PRIMARY KEY,
    action_type     VARCHAR2(30) NOT NULL,      -- 'INSERT', 'UPDATE', 'DELETE', 'CHECKOUT', 'STATUS_CHANGE'
    table_name      VARCHAR2(30) NOT NULL,
    record_id       VARCHAR2(50),
    performed_by    VARCHAR2(100),
    action_time     DATE DEFAULT SYSDATE NOT NULL,
    details         VARCHAR2(2000)
);

-- ============================================================================
-- 10. INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================
CREATE INDEX idx_users_email ON USERS(email);
CREATE INDEX idx_books_title ON BOOKS(UPPER(title));
CREATE INDEX idx_books_author ON BOOKS(UPPER(author));
CREATE INDEX idx_books_category ON BOOKS(category_id);
CREATE INDEX idx_books_active ON BOOKS(is_active);
CREATE INDEX idx_cart_user ON CART_ITEMS(user_id);
CREATE INDEX idx_orders_user ON ORDERS(user_id);
CREATE INDEX idx_orders_date ON ORDERS(order_date);
CREATE INDEX idx_orders_status ON ORDERS(order_status);
CREATE INDEX idx_order_items_order ON ORDER_ITEMS(order_id);
CREATE INDEX idx_order_items_book ON ORDER_ITEMS(book_id);

PROMPT Database Schema and Indexes Created Successfully.
