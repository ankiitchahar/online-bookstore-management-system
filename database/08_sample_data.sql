-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 08_sample_data.sql
-- Description: Seed Data for Roles, Categories, Books, Users, and Sample Orders
-- ============================================================================

-- 1. Insert Roles
INSERT INTO ROLES (role_id, role_name, description)
VALUES (1, 'ADMIN', 'System administrator with full catalog and order management privileges');

INSERT INTO ROLES (role_id, role_name, description)
VALUES (2, 'CUSTOMER', 'Registered online bookstore shopper');

-- 2. Insert Categories
INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (1, 'Computer Science', 'Software engineering, algorithms, and system design', 'Y');

INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (2, 'Database Systems', 'Relational databases, SQL, PL/SQL, and cloud data architecture', 'Y');

INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (3, 'Fiction & Literature', 'Novels, classic literature, and contemporary storytelling', 'Y');

INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (4, 'Business & Leadership', 'Entrepreneurship, leadership, startups, and economic strategy', 'Y');

INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (5, 'Science & Nature', 'Physics, cosmology, neuroscience, and natural history', 'Y');

INSERT INTO CATEGORIES (category_id, category_name, description, is_active)
VALUES (6, 'Self-Help & Productivity', 'Habit building, mindfulness, personal development, and focus', 'Y');

-- 3. Insert Users via USER_MGMT_PKG
DECLARE
    v_uid NUMBER;
    v_st  VARCHAR2(20);
    v_msg VARCHAR2(400);
BEGIN
    -- Admin User
    USER_MGMT_PKG.register_user(
        'System Administrator', 'admin@bookstore.com', 'admin123',
        '+1-800-555-0199', '100 Oracle Parkway, Redwood Shores, CA 94065',
        'ADMIN', v_uid, v_st, v_msg
    );

    -- Customer 1: Alice Johnson
    USER_MGMT_PKG.register_user(
        'Alice Johnson', 'alice@example.com', 'alice123',
        '+1-555-234-5678', '742 Evergreen Terrace, Springfield, OR 97477',
        'CUSTOMER', v_uid, v_st, v_msg
    );

    -- Customer 2: Bob Smith
    USER_MGMT_PKG.register_user(
        'Bob Smith', 'bob@example.com', 'bob123',
        '+1-555-876-5432', '221B Baker Street, Marylebone, London NW1 6XE',
        'CUSTOMER', v_uid, v_st, v_msg
    );

    -- Customer 3: Clara Oswald
    USER_MGMT_PKG.register_user(
        'Clara Oswald', 'clara@example.com', 'clara123',
        '+1-555-432-1098', '15 Coal Hill Road, Shoreditch, London EC2A 3BX',
        'CUSTOMER', v_uid, v_st, v_msg
    );
END;
/

-- 4. Insert Books
DECLARE
    v_bid NUMBER;
    v_st  VARCHAR2(20);
    v_msg VARCHAR2(400);
BEGIN
    -- Book 1
    BOOK_MGMT_PKG.add_book(
        '978-1449324452', 'Oracle PL/SQL Programming', 'Steven Feuerstein', 2,
        49.99, 35, 2014,
        'The definitive guide to Oracle''s procedural language. Covers syntax, packages, triggers, dynamic SQL, and best practices.',
        'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 2
    BOOK_MGMT_PKG.add_book(
        '978-0078022159', 'Database System Concepts', 'Abraham Silberschatz', 2,
        64.50, 20, 2019,
        'Foundation textbook presenting fundamental concepts of database management, relational algebra, SQL, transactions, and indexing.',
        'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 3
    BOOK_MGMT_PKG.add_book(
        '978-1491903063', 'Designing Data-Intensive Applications', 'Martin Kleppmann', 2,
        42.00, 45, 2017,
        'Key principles and trade-offs behind distributed data systems, replication, partitioning, stream processing, and consensus.',
        'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 4
    BOOK_MGMT_PKG.add_book(
        '978-0132350884', 'Clean Code', 'Robert C. Martin', 1,
        38.95, 28, 2008,
        'A Handbook of Agile Software Craftsmanship. Learn meaningful names, functions, formatting, error handling, and refactoring.',
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 5
    BOOK_MGMT_PKG.add_book(
        '978-0135957059', 'The Pragmatic Programmer', 'David Thomas & Andrew Hunt', 1,
        45.50, 18, 2019,
        '20th Anniversary Edition exploring modern software development philosophy, career mastery, automated testing, and software rot.',
        'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 6
    BOOK_MGMT_PKG.add_book(
        '978-0735211292', 'Atomic Habits', 'James Clear', 6,
        18.99, 60, 2018,
        'An easy and proven way to build good habits and break bad ones using behavioral psychology, cue-craving-response-reward loops.',
        'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 7
    BOOK_MGMT_PKG.add_book(
        '978-1455586691', 'Deep Work', 'Cal Newport', 6,
        21.50, 14, 2016,
        'Rules for Focused Success in a Distracted World. Transforming shallow tasks into high-leverage cognitive output.',
        'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 8
    BOOK_MGMT_PKG.add_book(
        '978-0061120084', 'To Kill a Mockingbird', 'Harper Lee', 3,
        14.99, 50, 1960,
        'The Pulitzer Prize-winning classic novel of warmth and humor despite dealing with serious issues of rape and racial inequality.',
        'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 9
    BOOK_MGMT_PKG.add_book(
        '978-0451524935', '1984', 'George Orwell', 3,
        12.95, 4, 1949,  -- Low stock indicator test
        'Dystopian social science fiction novel detailing the pervasive surveillance of Big Brother and the Ministry of Truth.',
        'https://images.unsplash.com/photo-1495640388908-05fa85288e61?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 10
    BOOK_MGMT_PKG.add_book(
        '978-0553380163', 'A Brief History of Time', 'Stephen Hawking', 5,
        16.80, 22, 1988,
        'From the Big Bang to Black Holes. Exploration of space, time, general relativity, quantum mechanics, and cosmology.',
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 11
    BOOK_MGMT_PKG.add_book(
        '978-0804139298', 'Zero to One', 'Peter Thiel', 4,
        22.00, 30, 2014,
        'Notes on Startups, or How to Build the Future. The secret to building monopolies and technology breakthroughs.',
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );

    -- Book 12
    BOOK_MGMT_PKG.add_book(
        '978-0743273565', 'The Great Gatsby', 'F. Scott Fitzgerald', 3,
        13.50, 0, 1925,  -- Out of stock indicator test
        'The Roaring Twenties classic exploring decadence, idealism, social upheaval, and the elusive American Dream.',
        'https://images.unsplash.com/photo-1476275466078-4007374efbbe?w=500&auto=format&fit=crop&q=60',
        v_bid, v_st, v_msg
    );
END;
/

-- 5. Seed Initial Shopping Carts & Historical Orders to populate Reports
DECLARE
    v_alice_id NUMBER;
    v_bob_id   NUMBER;
    v_b1_id    NUMBER;
    v_b2_id    NUMBER;
    v_b3_id    NUMBER;
    v_oid      NUMBER;
    v_tot      NUMBER;
    v_st       VARCHAR2(20);
    v_msg      VARCHAR2(400);
BEGIN
    SELECT user_id INTO v_alice_id FROM USERS WHERE email = 'alice@example.com';
    SELECT user_id INTO v_bob_id FROM USERS WHERE email = 'bob@example.com';
    
    SELECT book_id INTO v_b1_id FROM BOOKS WHERE isbn = '978-1449324452';
    SELECT book_id INTO v_b2_id FROM BOOKS WHERE isbn = '978-1491903063';
    SELECT book_id INTO v_b3_id FROM BOOKS WHERE isbn = '978-0735211292';

    -- Alice creates an order
    CART_MGMT_PKG.add_to_cart(v_alice_id, v_b1_id, 2, v_st, v_msg);
    CART_MGMT_PKG.add_to_cart(v_alice_id, v_b3_id, 1, v_st, v_msg);
    ORDER_MGMT_PKG.place_order_from_cart(v_alice_id, '742 Evergreen Terrace, Springfield, OR', 'CREDIT_CARD', 'Please leave package at front porch.', v_oid, v_tot, v_st, v_msg);

    -- Bob creates an order
    CART_MGMT_PKG.add_to_cart(v_bob_id, v_b2_id, 1, v_st, v_msg);
    CART_MGMT_PKG.add_to_cart(v_bob_id, v_b3_id, 2, v_st, v_msg);
    ORDER_MGMT_PKG.place_order_from_cart(v_bob_id, '221B Baker Street, London NW1 6XE', 'PAYPAL', 'Express shipping requested.', v_oid, v_tot, v_st, v_msg);

    -- Advance Alice's order status to SHIPPED
    ORDER_MGMT_PKG.update_order_status(v_oid - 1, 'SHIPPED', 'ADMIN', v_st, v_msg);

    -- Bob adds a book to cart for current active shopping session
    CART_MGMT_PKG.add_to_cart(v_bob_id, v_b1_id, 1, v_st, v_msg);

    COMMIT;
END;
/

PROMPT Sample Data Seeded Successfully.
