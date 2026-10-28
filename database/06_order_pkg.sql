-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 06_order_pkg.sql
-- Description: Order Processing, Status Tracking & Checkout Package
-- ============================================================================

CREATE OR REPLACE PACKAGE ORDER_MGMT_PKG AS

    -- Place an order atomically from the user's shopping cart
    PROCEDURE place_order_from_cart(
        p_user_id          IN  NUMBER,
        p_shipping_address IN  VARCHAR2,
        p_payment_method   IN  VARCHAR2 DEFAULT 'CREDIT_CARD',
        p_notes            IN  VARCHAR2 DEFAULT NULL,
        o_order_id         OUT NUMBER,
        o_total_amount     OUT NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Update order status (Admin)
    PROCEDURE update_order_status(
        p_order_id         IN  NUMBER,
        p_new_status       IN  VARCHAR2,
        p_admin_user       IN  VARCHAR2 DEFAULT 'ADMIN',
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Cancel an order (Customer can cancel if PENDING)
    PROCEDURE cancel_order(
        p_order_id         IN  NUMBER,
        p_user_id          IN  NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Get order history for a specific customer
    PROCEDURE get_user_orders(
        p_user_id          IN  NUMBER,
        o_cursor           OUT SYS_REFCURSOR
    );

    -- Get order header and itemized breakdown
    PROCEDURE get_order_details(
        p_order_id         IN  NUMBER,
        o_order_cursor     OUT SYS_REFCURSOR,
        o_items_cursor     OUT SYS_REFCURSOR
    );

    -- Admin: View all orders with optional status filter
    PROCEDURE get_all_orders_admin(
        p_status_filter    IN  VARCHAR2 DEFAULT NULL,
        o_cursor           OUT SYS_REFCURSOR
    );

END ORDER_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY ORDER_MGMT_PKG AS

    -- Place order from cart
    PROCEDURE place_order_from_cart(
        p_user_id          IN  NUMBER,
        p_shipping_address IN  VARCHAR2,
        p_payment_method   IN  VARCHAR2 DEFAULT 'CREDIT_CARD',
        p_notes            IN  VARCHAR2 DEFAULT NULL,
        o_order_id         OUT NUMBER,
        o_total_amount     OUT NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    ) IS
        v_cart_count     NUMBER;
        v_subtotal       NUMBER(10,2) := 0.00;
        v_shipping_fee   NUMBER(10,2) := 0.00;
        v_tax_amount     NUMBER(10,2) := 0.00;
        v_curr_stock     NUMBER;
        v_book_title     VARCHAR2(200);
        v_line_total     NUMBER(10,2);
        v_final_address  VARCHAR2(500);

        -- Cursor to lock and iterate over cart items
        CURSOR c_cart IS
            SELECT c.book_id, c.quantity, b.price, b.title, b.stock_quantity
            FROM CART_ITEMS c
            JOIN BOOKS b ON c.book_id = b.book_id
            WHERE c.user_id = p_user_id
            FOR UPDATE OF b.stock_quantity;

    BEGIN
        SAVEPOINT sp_checkout;

        -- 1. Check if cart is empty
        SELECT COUNT(*) INTO v_cart_count FROM CART_ITEMS WHERE user_id = p_user_id;
        IF v_cart_count = 0 THEN
            o_status := 'ERROR';
            o_message := 'Shopping cart is empty. Please add books before checkout.';
            RETURN;
        END IF;

        -- 2. Resolve Shipping Address
        IF p_shipping_address IS NOT NULL AND LENGTH(TRIM(p_shipping_address)) > 0 THEN
            v_final_address := TRIM(p_shipping_address);
        ELSE
            SELECT shipping_address INTO v_final_address FROM USERS WHERE user_id = p_user_id;
            IF v_final_address IS NULL OR LENGTH(TRIM(v_final_address)) = 0 THEN
                o_status := 'ERROR';
                o_message := 'Shipping address is required.';
                RETURN;
            END IF;
        END IF;

        -- 3. Validate Stock & Calculate Subtotal
        FOR item IN c_cart LOOP
            IF item.stock_quantity < item.quantity THEN
                ROLLBACK TO sp_checkout;
                o_status := 'ERROR';
                o_message := 'Insufficient stock for "' || item.title || '". Requested: ' || item.quantity || ', Available: ' || item.stock_quantity;
                RETURN;
            END IF;
            v_subtotal := v_subtotal + (item.quantity * item.price);
        END LOOP;

        -- 4. Calculate Shipping and Taxes
        IF v_subtotal >= 35.00 THEN
            v_shipping_fee := 0.00;
        ELSE
            v_shipping_fee := 4.99;
        END IF;
        v_tax_amount := ROUND(v_subtotal * 0.08, 2);
        o_total_amount := ROUND(v_subtotal + v_shipping_fee + v_tax_amount, 2);

        -- 5. Create Order Header
        o_order_id := ORDER_SEQ.NEXTVAL;

        INSERT INTO ORDERS (
            order_id, user_id, order_date, subtotal, shipping_fee, tax_amount,
            total_amount, shipping_address, payment_method, payment_status,
            order_status, notes
        ) VALUES (
            o_order_id, p_user_id, SYSDATE, v_subtotal, v_shipping_fee, v_tax_amount,
            o_total_amount, v_final_address, NVL(p_payment_method, 'CREDIT_CARD'),
            'PAID', 'PENDING', p_notes
        );

        -- 6. Insert Order Items & Deduct Inventory Stock
        FOR item IN (SELECT c.book_id, c.quantity, b.price
                     FROM CART_ITEMS c
                     JOIN BOOKS b ON c.book_id = b.book_id
                     WHERE c.user_id = p_user_id) LOOP
            v_line_total := ROUND(item.quantity * item.price, 2);

            INSERT INTO ORDER_ITEMS (
                order_item_id, order_id, book_id, quantity, unit_price, subtotal
            ) VALUES (
                ORDER_ITEM_SEQ.NEXTVAL, o_order_id, item.book_id, item.quantity, item.price, v_line_total
            );

            -- Deduct stock
            UPDATE BOOKS
            SET stock_quantity = stock_quantity - item.quantity,
                updated_at = SYSDATE
            WHERE book_id = item.book_id;
        END LOOP;

        -- 7. Clear Shopping Cart
        DELETE FROM CART_ITEMS WHERE user_id = p_user_id;

        -- 8. Audit Record
        INSERT INTO AUDIT_LOGS (log_id, action_type, table_name, record_id, performed_by, action_time, details)
        VALUES (AUDIT_SEQ.NEXTVAL, 'CHECKOUT', 'ORDERS', TO_CHAR(o_order_id),
                TO_CHAR(p_user_id), SYSDATE,
                'Order placed successfully. Total: $' || TO_CHAR(o_total_amount, 'FM9990.00'));

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Order #' || o_order_id || ' placed successfully!';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_checkout;
            o_status := 'ERROR';
            o_message := 'Order checkout failed: ' || SQLERRM;
    END place_order_from_cart;

    -- Update order status
    PROCEDURE update_order_status(
        p_order_id   IN  NUMBER,
        p_new_status IN  VARCHAR2,
        p_admin_user IN  VARCHAR2 DEFAULT 'ADMIN',
        o_status     OUT VARCHAR2,
        o_message    OUT VARCHAR2
    ) IS
        v_current_status VARCHAR2(20);
        v_valid_status   BOOLEAN := FALSE;
    BEGIN
        -- Validate valid status
        IF p_new_status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED') THEN
            v_valid_status := TRUE;
        END IF;

        IF NOT v_valid_status THEN
            o_status := 'ERROR';
            o_message := 'Invalid status: ' || p_new_status;
            RETURN;
        END IF;

        SELECT order_status INTO v_current_status FROM ORDERS WHERE order_id = p_order_id;

        IF v_current_status = 'DELIVERED' AND p_new_status != 'DELIVERED' THEN
            o_status := 'ERROR';
            o_message := 'Delivered orders cannot have their status altered.';
            RETURN;
        END IF;

        IF v_current_status = 'CANCELLED' THEN
            o_status := 'ERROR';
            o_message := 'Cancelled orders cannot be reopened.';
            RETURN;
        END IF;

        UPDATE ORDERS
        SET order_status = p_new_status
        WHERE order_id = p_order_id;

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Order #' || p_order_id || ' status changed to ' || p_new_status || '.';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Order #' || p_order_id || ' not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to update order status: ' || SQLERRM;
    END update_order_status;

    -- Cancel order
    PROCEDURE cancel_order(
        p_order_id IN  NUMBER,
        p_user_id  IN  NUMBER,
        o_status   OUT VARCHAR2,
        o_message  OUT VARCHAR2
    ) IS
        v_owner_id NUMBER;
        v_status   VARCHAR2(20);
    BEGIN
        SELECT user_id, order_status INTO v_owner_id, v_status
        FROM ORDERS WHERE order_id = p_order_id;

        IF v_owner_id != p_user_id THEN
            o_status := 'ERROR';
            o_message := 'You are not authorized to cancel this order.';
            RETURN;
        END IF;

        IF v_status NOT IN ('PENDING', 'PROCESSING') THEN
            o_status := 'ERROR';
            o_message := 'Orders in status ' || v_status || ' cannot be cancelled.';
            RETURN;
        END IF;

        UPDATE ORDERS
        SET order_status = 'CANCELLED'
        WHERE order_id = p_order_id;

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Order #' || p_order_id || ' cancelled successfully and items restocked.';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Order not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Cancellation failed: ' || SQLERRM;
    END cancel_order;

    -- Get user orders
    PROCEDURE get_user_orders(
        p_user_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT o.order_id, o.order_date, o.subtotal, o.shipping_fee,
                   o.tax_amount, o.total_amount, o.shipping_address,
                   o.payment_method, o.payment_status, o.order_status,
                   COUNT(oi.order_item_id) AS total_items,
                   SUM(oi.quantity) AS total_book_units
            FROM ORDERS o
            LEFT JOIN ORDER_ITEMS oi ON o.order_id = oi.order_id
            WHERE o.user_id = p_user_id
            GROUP BY o.order_id, o.order_date, o.subtotal, o.shipping_fee,
                     o.tax_amount, o.total_amount, o.shipping_address,
                     o.payment_method, o.payment_status, o.order_status
            ORDER BY o.order_date DESC;
    END get_user_orders;

    -- Get order details
    PROCEDURE get_order_details(
        p_order_id     IN  NUMBER,
        o_order_cursor OUT SYS_REFCURSOR,
        o_items_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        -- Order header
        OPEN o_order_cursor FOR
            SELECT o.order_id, o.user_id, u.full_name, u.email,
                   o.order_date, o.subtotal, o.shipping_fee, o.tax_amount,
                   o.total_amount, o.shipping_address, o.payment_method,
                   o.payment_status, o.order_status, o.notes
            FROM ORDERS o
            JOIN USERS u ON o.user_id = u.user_id
            WHERE o.order_id = p_order_id;

        -- Order items
        OPEN o_items_cursor FOR
            SELECT oi.order_item_id, oi.book_id, b.title, b.author,
                   b.isbn, b.cover_image, oi.quantity, oi.unit_price, oi.subtotal
            FROM ORDER_ITEMS oi
            JOIN BOOKS b ON oi.book_id = b.book_id
            WHERE oi.order_id = p_order_id
            ORDER BY oi.order_item_id ASC;
    END get_order_details;

    -- Admin: get all orders
    PROCEDURE get_all_orders_admin(
        p_status_filter IN  VARCHAR2 DEFAULT NULL,
        o_cursor        OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT o.order_id, o.order_date, u.full_name AS customer_name,
                   u.email AS customer_email, o.total_amount, o.order_status,
                   o.payment_method, o.payment_status,
                   (SELECT COUNT(*) FROM ORDER_ITEMS WHERE order_id = o.order_id) AS item_count
            FROM ORDERS o
            JOIN USERS u ON o.user_id = u.user_id
            WHERE (p_status_filter IS NULL OR o.order_status = UPPER(p_status_filter))
            ORDER BY o.order_date DESC;
    END get_all_orders_admin;

END ORDER_MGMT_PKG;
/

PROMPT Order Management Package Created Successfully.
