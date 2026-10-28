-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 09_test_suite.sql
-- Description: Automated PL/SQL Test Suite with Verification Assertions
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_test_count  NUMBER := 0;
    v_pass_count  NUMBER := 0;
    v_fail_count  NUMBER := 0;

    -- Helper procedure for assertions
    PROCEDURE assert_test(p_test_name IN VARCHAR2, p_condition IN BOOLEAN, p_info IN VARCHAR2 DEFAULT '') IS
    BEGIN
        v_test_count := v_test_count + 1;
        IF p_condition THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('  [PASS] Test ' || LPAD(v_test_count, 2, '0') || ': ' || p_test_name);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('  [FAIL] Test ' || LPAD(v_test_count, 2, '0') || ': ' || p_test_name || ' -> ' || p_info);
        END IF;
    END assert_test;

    -- Test variables
    v_uid       NUMBER;
    v_bid       NUMBER;
    v_oid       NUMBER;
    v_tot       NUMBER;
    v_st        VARCHAR2(20);
    v_msg       VARCHAR2(400);
    v_name      VARCHAR2(100);
    v_role      VARCHAR2(30);
    v_stock_pre NUMBER;
    v_stock_post NUMBER;
    v_item_cnt  NUMBER;
    v_cur       SYS_REFCURSOR;
    v_subtotal  NUMBER;
    v_ship      NUMBER;
    v_tax       NUMBER;
    v_dummy_id  NUMBER;
    v_dummy_ttl VARCHAR2(200);

BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('     RUNNING ONLINE BOOKSTORE PL/SQL AUTOMATED TEST SUITE       ');
    DBMS_OUTPUT.PUT_LINE('================================================================');

    -- ------------------------------------------------------------------------
    -- SUITE 1: USER MANAGEMENT & AUTHENTICATION
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- SUITE 1: USER REGISTRATION & AUTHENTICATION ---');

    -- 1.1 Valid User Registration
    USER_MGMT_PKG.register_user(
        'David Miller', 'david.miller@example.com', 'securepass123',
        '+1-555-901-2345', '123 Market St, San Francisco, CA', 'CUSTOMER',
        v_uid, v_st, v_msg
    );
    assert_test('User Registration with Valid Data', v_st = 'SUCCESS' AND v_uid IS NOT NULL, v_msg);

    -- 1.2 Duplicate Email Prevention
    USER_MGMT_PKG.register_user(
        'Duplicate David', 'david.miller@example.com', 'anotherpwd',
        NULL, NULL, 'CUSTOMER',
        v_uid, v_st, v_msg
    );
    assert_test('Prevent Duplicate Email Registration', v_st = 'ERROR', 'Expected error on duplicate email');

    -- 1.3 Successful Login
    USER_MGMT_PKG.authenticate_user(
        'david.miller@example.com', 'securepass123',
        v_uid, v_name, v_role, v_st, v_msg
    );
    assert_test('Authenticate User with Correct Password', v_st = 'SUCCESS' AND v_role = 'CUSTOMER', v_msg);

    -- 1.4 Failed Login with Invalid Password
    USER_MGMT_PKG.authenticate_user(
        'david.miller@example.com', 'wrongpassword',
        v_uid, v_name, v_role, v_st, v_msg
    );
    assert_test('Reject Authentication with Wrong Password', v_st = 'ERROR', 'Expected authentication failure');

    -- 1.5 Update User Profile
    USER_MGMT_PKG.update_profile(v_uid, 'David Miller Jr.', '+1-555-999-8888', '456 Mission St, SF, CA', v_st, v_msg);
    assert_test('Update User Profile Information', v_st = 'SUCCESS', v_msg);

    -- ------------------------------------------------------------------------
    -- SUITE 2: BOOK MANAGEMENT & INVENTORY
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- SUITE 2: BOOK MANAGEMENT & SEARCH ---');

    -- 2.1 Add New Book
    BOOK_MGMT_PKG.add_book(
        '978-0131103627', 'The C Programming Language', 'Brian W. Kernighan, Dennis M. Ritchie',
        1, 35.00, 15, 1988, 'Classic Bell Labs programming reference.', NULL,
        v_bid, v_st, v_msg
    );
    assert_test('Admin Add New Book to Catalog', v_st = 'SUCCESS' AND v_bid IS NOT NULL, v_msg);

    -- 2.2 Update Book Price & Details
    BOOK_MGMT_PKG.update_book(
        v_bid, 'The C Programming Language (2nd Ed)', NULL, NULL,
        37.50, 20, NULL, NULL, NULL,
        v_st, v_msg
    );
    assert_test('Admin Update Book Details and Stock', v_st = 'SUCCESS', v_msg);

    -- 2.3 Search Books by Keyword
    BOOK_MGMT_PKG.search_books('Programming', NULL, NULL, NULL, 'N', v_cur);
    assert_test('Search Books by Keyword RefCursor Opened', v_cur%ISOPEN, 'Cursor must be open');
    CLOSE v_cur;

    -- ------------------------------------------------------------------------
    -- SUITE 3: SHOPPING CART WORKFLOW
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- SUITE 3: SHOPPING CART OPERATIONS ---');

    -- 3.1 Add Book to Cart
    CART_MGMT_PKG.add_to_cart(v_uid, v_bid, 3, v_st, v_msg);
    assert_test('Add Book to User Shopping Cart', v_st = 'SUCCESS', v_msg);

    -- 3.2 Update Quantity in Cart
    CART_MGMT_PKG.update_cart_quantity(v_uid, v_bid, 5, v_st, v_msg);
    assert_test('Update Item Quantity in Shopping Cart', v_st = 'SUCCESS', v_msg);

    -- 3.3 Fetch Cart and Validate Subtotal Calculation
    CART_MGMT_PKG.get_cart_items(v_uid, v_cur, v_item_cnt, v_subtotal, v_ship, v_tax, v_tot);
    assert_test('Cart Calculation (Qty=5 @ $37.50 -> Subtotal=$187.50)', v_subtotal = 187.50 AND v_item_cnt = 5,
                'Subtotal was $' || v_subtotal);
    CLOSE v_cur;

    -- ------------------------------------------------------------------------
    -- SUITE 4: ORDER PLACEMENT, ATOMIC TRANSACTION & RESTOCK TRIGGER
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- SUITE 4: ORDER TRANSACTIONS & TRIGGERS ---');

    SELECT stock_quantity INTO v_stock_pre FROM BOOKS WHERE book_id = v_bid;

    -- 4.1 Place Order from Cart
    ORDER_MGMT_PKG.place_order_from_cart(
        v_uid, '456 Mission St, SF, CA', 'CREDIT_CARD', 'Leave with receptionist',
        v_oid, v_tot, v_st, v_msg
    );
    assert_test('Place Order from Cart (Atomic Transaction)', v_st = 'SUCCESS' AND v_oid IS NOT NULL, v_msg);

    -- 4.2 Verify Stock Deduction
    SELECT stock_quantity INTO v_stock_post FROM BOOKS WHERE book_id = v_bid;
    assert_test('Verify Inventory Deduction (20 - 5 = 15)', v_stock_post = (v_stock_pre - 5),
                'Pre: ' || v_stock_pre || ', Post: ' || v_stock_post);

    -- 4.3 Verify Cart Cleared Post-Checkout
    CART_MGMT_PKG.get_cart_items(v_uid, v_cur, v_item_cnt, v_subtotal, v_ship, v_tax, v_tot);
    assert_test('Verify Cart Cleared after Successful Checkout', v_item_cnt = 0, 'Cart item count: ' || v_item_cnt);
    CLOSE v_cur;

    -- 4.4 Update Order Status (Admin)
    ORDER_MGMT_PKG.update_order_status(v_oid, 'PROCESSING', 'ADMIN', v_st, v_msg);
    assert_test('Admin Advance Order Status to PROCESSING', v_st = 'SUCCESS', v_msg);

    -- 4.5 Cancel Order and Test Automatic Restock Trigger
    ORDER_MGMT_PKG.cancel_order(v_oid, v_uid, v_st, v_msg);
    assert_test('Customer Cancel Order while in Processing', v_st = 'SUCCESS', v_msg);

    SELECT stock_quantity INTO v_stock_post FROM BOOKS WHERE book_id = v_bid;
    assert_test('Trigger trg_order_status_audit Restored Book Inventory', v_stock_post = v_stock_pre,
                'Expected ' || v_stock_pre || ', Got ' || v_stock_post);

    -- ------------------------------------------------------------------------
    -- SUITE 5: REPORTING & ANALYTICS
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- SUITE 5: REPORTING & KPIS ---');

    REPORT_MGMT_PKG.get_best_selling_books(5, v_cur);
    assert_test('Reporting: Best Selling Books Cursor Generated', v_cur%ISOPEN, 'Cursor must be open');
    CLOSE v_cur;

    REPORT_MGMT_PKG.get_inventory_health(10, v_cur);
    assert_test('Reporting: Low-Stock Inventory Health Cursor Generated', v_cur%ISOPEN, 'Cursor must be open');
    CLOSE v_cur;

    -- ------------------------------------------------------------------------
    -- SUMMARY
    -- ------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST RESULTS SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('  Total Tests Executed : ' || v_test_count);
    DBMS_OUTPUT.PUT_LINE('  Passed               : ' || v_pass_count);
    DBMS_OUTPUT.PUT_LINE('  Failed               : ' || v_fail_count);
    IF v_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('STATUS: ALL TESTS PASSED SUCCESSFULLY! (100% Pass Rate)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('STATUS: ' || v_fail_count || ' TEST(S) FAILED. CHECK LOGS.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('================================================================' || CHR(10));

    -- Print formal formatted Sales Summary Report
    REPORT_MGMT_PKG.print_sales_summary_report(30);

END;
/
