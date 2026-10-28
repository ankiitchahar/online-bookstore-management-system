-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 05_cart_pkg.sql
-- Description: Shopping Cart Management Package
-- ============================================================================

CREATE OR REPLACE PACKAGE CART_MGMT_PKG AS

    -- Add item to cart or increment quantity if already present
    PROCEDURE add_to_cart(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        p_quantity    IN  NUMBER DEFAULT 1,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- Update quantity for an item in the cart
    PROCEDURE update_cart_quantity(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        p_quantity    IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- Remove a single item from cart
    PROCEDURE remove_from_cart(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- Clear all items from a user's cart
    PROCEDURE clear_cart(
        p_user_id     IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    );

    -- Get all cart items along with monetary totals
    PROCEDURE get_cart_items(
        p_user_id     IN  NUMBER,
        o_cursor      OUT SYS_REFCURSOR,
        o_item_count  OUT NUMBER,
        o_subtotal    OUT NUMBER,
        o_shipping    OUT NUMBER,
        o_tax         OUT NUMBER,
        o_total       OUT NUMBER
    );

END CART_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY CART_MGMT_PKG AS

    -- Add to cart
    PROCEDURE add_to_cart(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        p_quantity    IN  NUMBER DEFAULT 1,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
        v_stock         NUMBER;
        v_title         VARCHAR2(200);
        v_active        CHAR(1);
        v_existing_qty  NUMBER := 0;
        v_new_qty       NUMBER;
    BEGIN
        IF p_quantity <= 0 THEN
            o_status := 'ERROR';
            o_message := 'Quantity must be at least 1.';
            RETURN;
        END IF;

        -- Verify book exists and check stock
        BEGIN
            SELECT stock_quantity, title, is_active
            INTO v_stock, v_title, v_active
            FROM BOOKS
            WHERE book_id = p_book_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                o_status := 'ERROR';
                o_message := 'Book not found.';
                RETURN;
        END;

        IF v_active != 'Y' THEN
            o_status := 'ERROR';
            o_message := 'Book "' || v_title || '" is currently unavailable.';
            RETURN;
        END IF;

        -- Check existing cart quantity
        BEGIN
            SELECT quantity INTO v_existing_qty
            FROM CART_ITEMS
            WHERE user_id = p_user_id AND book_id = p_book_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_existing_qty := 0;
        END;

        v_new_qty := v_existing_qty + p_quantity;

        IF v_new_qty > v_stock THEN
            o_status := 'ERROR';
            o_message := 'Cannot add ' || p_quantity || ' item(s). Only ' || v_stock || ' available in stock (you already have ' || v_existing_qty || ' in your cart).';
            RETURN;
        END IF;

        IF v_existing_qty > 0 THEN
            UPDATE CART_ITEMS
            SET quantity = v_new_qty,
                added_at = SYSDATE
            WHERE user_id = p_user_id AND book_id = p_book_id;
        ELSE
            INSERT INTO CART_ITEMS (cart_id, user_id, book_id, quantity, added_at)
            VALUES (CART_SEQ.NEXTVAL, p_user_id, p_book_id, p_quantity, SYSDATE);
        END IF;

        COMMIT;
        o_status := 'SUCCESS';
        o_message := '"' || v_title || '" added to cart.';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to add item to cart: ' || SQLERRM;
    END add_to_cart;

    -- Update cart quantity
    PROCEDURE update_cart_quantity(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        p_quantity    IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
        v_stock NUMBER;
    BEGIN
        IF p_quantity <= 0 THEN
            remove_from_cart(p_user_id, p_book_id, o_status, o_message);
            RETURN;
        END IF;

        SELECT stock_quantity INTO v_stock FROM BOOKS WHERE book_id = p_book_id;

        IF p_quantity > v_stock THEN
            o_status := 'ERROR';
            o_message := 'Requested quantity (' || p_quantity || ') exceeds available stock (' || v_stock || ').';
            RETURN;
        END IF;

        UPDATE CART_ITEMS
        SET quantity = p_quantity,
            added_at = SYSDATE
        WHERE user_id = p_user_id AND book_id = p_book_id;

        IF SQL%ROWCOUNT > 0 THEN
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Cart quantity updated.';
        ELSE
            o_status := 'ERROR';
            o_message := 'Item not found in cart.';
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'Book not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to update cart: ' || SQLERRM;
    END update_cart_quantity;

    -- Remove from cart
    PROCEDURE remove_from_cart(
        p_user_id     IN  NUMBER,
        p_book_id     IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
    BEGIN
        DELETE FROM CART_ITEMS
        WHERE user_id = p_user_id AND book_id = p_book_id;

        IF SQL%ROWCOUNT > 0 THEN
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Item removed from cart.';
        ELSE
            o_status := 'ERROR';
            o_message := 'Item was not in your cart.';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to remove from cart: ' || SQLERRM;
    END remove_from_cart;

    -- Clear cart
    PROCEDURE clear_cart(
        p_user_id     IN  NUMBER,
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
    BEGIN
        DELETE FROM CART_ITEMS WHERE user_id = p_user_id;
        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Cart cleared successfully.';
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to clear cart: ' || SQLERRM;
    END clear_cart;

    -- Get cart items with calculations
    PROCEDURE get_cart_items(
        p_user_id     IN  NUMBER,
        o_cursor      OUT SYS_REFCURSOR,
        o_item_count  OUT NUMBER,
        o_subtotal    OUT NUMBER,
        o_shipping    OUT NUMBER,
        o_tax         OUT NUMBER,
        o_total       OUT NUMBER
    ) IS
    BEGIN
        -- Calculate totals
        SELECT NVL(SUM(c.quantity), 0),
               NVL(SUM(c.quantity * b.price), 0.00)
        INTO o_item_count, o_subtotal
        FROM CART_ITEMS c
        JOIN BOOKS b ON c.book_id = b.book_id
        WHERE c.user_id = p_user_id;

        IF o_item_count = 0 THEN
            o_shipping := 0.00;
            o_tax := 0.00;
            o_total := 0.00;
        ELSE
            -- Free shipping over $35, else $4.99
            IF o_subtotal >= 35.00 THEN
                o_shipping := 0.00;
            ELSE
                o_shipping := 4.99;
            END IF;
            -- 8% estimated tax
            o_tax := ROUND(o_subtotal * 0.08, 2);
            o_total := ROUND(o_subtotal + o_shipping + o_tax, 2);
        END IF;

        OPEN o_cursor FOR
            SELECT c.cart_id, c.book_id, b.title, b.author, b.isbn,
                   b.cover_image, b.price, c.quantity,
                   (c.quantity * b.price) AS line_total,
                   b.stock_quantity AS available_stock
            FROM CART_ITEMS c
            JOIN BOOKS b ON c.book_id = b.book_id
            WHERE c.user_id = p_user_id
            ORDER BY c.added_at DESC;

    END get_cart_items;

END CART_MGMT_PKG;
/

PROMPT Cart Management Package Created Successfully.
