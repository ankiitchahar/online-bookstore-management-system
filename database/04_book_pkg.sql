-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 04_book_pkg.sql
-- Description: Book Catalog & Inventory Management Package
-- ============================================================================

CREATE OR REPLACE PACKAGE BOOK_MGMT_PKG AS

    -- Add a new book to the catalog (Admin)
    PROCEDURE add_book(
        p_isbn             IN  VARCHAR2,
        p_title            IN  VARCHAR2,
        p_author           IN  VARCHAR2,
        p_category_id      IN  NUMBER,
        p_price            IN  NUMBER,
        p_stock_quantity   IN  NUMBER,
        p_publication_year IN  NUMBER,
        p_description      IN  VARCHAR2,
        p_cover_image      IN  VARCHAR2,
        o_book_id          OUT NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Update existing book details (Admin)
    PROCEDURE update_book(
        p_book_id          IN  NUMBER,
        p_title            IN  VARCHAR2,
        p_author           IN  VARCHAR2,
        p_category_id      IN  NUMBER,
        p_price            IN  NUMBER,
        p_stock_quantity   IN  NUMBER,
        p_publication_year IN  NUMBER,
        p_description      IN  VARCHAR2,
        p_cover_image      IN  VARCHAR2,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Remove or deactivate a book (Admin)
    PROCEDURE remove_book(
        p_book_id          IN  NUMBER,
        p_soft_delete      IN  VARCHAR2 DEFAULT 'Y',
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Adjust stock quantity (e.g. inventory restock or manual adjustment)
    PROCEDURE update_stock(
        p_book_id          IN  NUMBER,
        p_delta_quantity   IN  NUMBER,
        o_new_stock        OUT NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    );

    -- Search books by multiple criteria (Users/Admin)
    PROCEDURE search_books(
        p_keyword          IN  VARCHAR2 DEFAULT NULL,
        p_category_id      IN  NUMBER   DEFAULT NULL,
        p_min_price        IN  NUMBER   DEFAULT NULL,
        p_max_price        IN  NUMBER   DEFAULT NULL,
        p_in_stock_only    IN  VARCHAR2 DEFAULT 'N',
        o_cursor           OUT SYS_REFCURSOR
    );

    -- Get single book details
    PROCEDURE get_book_by_id(
        p_book_id          IN  NUMBER,
        o_cursor           OUT SYS_REFCURSOR
    );

    -- Check if sufficient stock is available
    FUNCTION check_availability(
        p_book_id          IN  NUMBER,
        p_required_qty     IN  NUMBER
    ) RETURN BOOLEAN;

END BOOK_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY BOOK_MGMT_PKG AS

    -- Add a new book
    PROCEDURE add_book(
        p_isbn             IN  VARCHAR2,
        p_title            IN  VARCHAR2,
        p_author           IN  VARCHAR2,
        p_category_id      IN  NUMBER,
        p_price            IN  NUMBER,
        p_stock_quantity   IN  NUMBER,
        p_publication_year IN  NUMBER,
        p_description      IN  VARCHAR2,
        p_cover_image      IN  VARCHAR2,
        o_book_id          OUT NUMBER,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    ) IS
        v_isbn_count NUMBER;
        v_cat_count  NUMBER;
    BEGIN
        -- Validate mandatory fields
        IF p_isbn IS NULL OR p_title IS NULL OR p_author IS NULL OR p_price IS NULL THEN
            o_status := 'ERROR';
            o_message := 'ISBN, title, author, and price are required.';
            RETURN;
        END IF;

        IF p_price < 0 THEN
            o_status := 'ERROR';
            o_message := 'Price cannot be negative.';
            RETURN;
        END IF;

        IF NVL(p_stock_quantity, 0) < 0 THEN
            o_status := 'ERROR';
            o_message := 'Stock quantity cannot be negative.';
            RETURN;
        END IF;

        -- Verify Category exists
        SELECT COUNT(*) INTO v_cat_count FROM CATEGORIES WHERE category_id = p_category_id;
        IF v_cat_count = 0 THEN
            o_status := 'ERROR';
            o_message := 'Category ID ' || p_category_id || ' does not exist.';
            RETURN;
        END IF;

        -- Check duplicate ISBN
        SELECT COUNT(*) INTO v_isbn_count FROM BOOKS WHERE UPPER(isbn) = UPPER(p_isbn);
        IF v_isbn_count > 0 THEN
            o_status := 'ERROR';
            o_message := 'A book with ISBN ' || p_isbn || ' already exists.';
            RETURN;
        END IF;

        o_book_id := BOOK_SEQ.NEXTVAL;

        INSERT INTO BOOKS (
            book_id, isbn, title, author, category_id, price, stock_quantity,
            publication_year, description, cover_image, is_active, created_at, updated_at
        ) VALUES (
            o_book_id, UPPER(TRIM(p_isbn)), TRIM(p_title), TRIM(p_author), p_category_id,
            p_price, NVL(p_stock_quantity, 0), p_publication_year, p_description,
            p_cover_image, 'Y', SYSDATE, SYSDATE
        );

        INSERT INTO AUDIT_LOGS (log_id, action_type, table_name, record_id, performed_by, action_time, details)
        VALUES (AUDIT_SEQ.NEXTVAL, 'INSERT', 'BOOKS', TO_CHAR(o_book_id),
                NVL(SYS_CONTEXT('USERENV', 'SESSION_USER'), 'ADMIN'), SYSDATE,
                'Added book: ' || p_title || ' (ISBN: ' || p_isbn || ')');

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Book added successfully with ID ' || o_book_id || '.';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to add book: ' || SQLERRM;
    END add_book;

    -- Update book details
    PROCEDURE update_book(
        p_book_id          IN  NUMBER,
        p_title            IN  VARCHAR2,
        p_author           IN  VARCHAR2,
        p_category_id      IN  NUMBER,
        p_price            IN  NUMBER,
        p_stock_quantity   IN  NUMBER,
        p_publication_year IN  NUMBER,
        p_description      IN  VARCHAR2,
        p_cover_image      IN  VARCHAR2,
        o_status           OUT VARCHAR2,
        o_message          OUT VARCHAR2
    ) IS
    BEGIN
        IF p_price < 0 OR p_stock_quantity < 0 THEN
            o_status := 'ERROR';
            o_message := 'Price and stock quantity cannot be negative.';
            RETURN;
        END IF;

        UPDATE BOOKS
        SET title = NVL(TRIM(p_title), title),
            author = NVL(TRIM(p_author), author),
            category_id = NVL(p_category_id, category_id),
            price = NVL(p_price, price),
            stock_quantity = NVL(p_stock_quantity, stock_quantity),
            publication_year = NVL(p_publication_year, publication_year),
            description = NVL(p_description, description),
            cover_image = NVL(p_cover_image, cover_image),
            updated_at = SYSDATE
        WHERE book_id = p_book_id;

        IF SQL%ROWCOUNT = 0 THEN
            o_status := 'ERROR';
            o_message := 'Book ID ' || p_book_id || ' not found.';
        ELSE
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Book updated successfully.';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to update book: ' || SQLERRM;
    END update_book;

    -- Remove or Deactivate book
    PROCEDURE remove_book(
        p_book_id     IN  NUMBER,
        p_soft_delete IN  VARCHAR2 DEFAULT 'Y',
        o_status      OUT VARCHAR2,
        o_message     OUT VARCHAR2
    ) IS
        v_order_count NUMBER;
    BEGIN
        IF UPPER(p_soft_delete) = 'Y' THEN
            UPDATE BOOKS
            SET is_active = 'N', updated_at = SYSDATE
            WHERE book_id = p_book_id;

            IF SQL%ROWCOUNT > 0 THEN
                COMMIT;
                o_status := 'SUCCESS';
                o_message := 'Book deactivated successfully.';
            ELSE
                o_status := 'ERROR';
                o_message := 'Book ID ' || p_book_id || ' not found.';
            END IF;
        ELSE
            -- Hard delete check: verify if book is in existing orders
            SELECT COUNT(*) INTO v_order_count FROM ORDER_ITEMS WHERE book_id = p_book_id;
            IF v_order_count > 0 THEN
                -- Fall back to soft delete to preserve historical integrity
                UPDATE BOOKS SET is_active = 'N', updated_at = SYSDATE WHERE book_id = p_book_id;
                COMMIT;
                o_status := 'SUCCESS';
                o_message := 'Book is referenced in orders, so it was deactivated instead of deleted.';
            ELSE
                DELETE FROM CART_ITEMS WHERE book_id = p_book_id;
                DELETE FROM BOOKS WHERE book_id = p_book_id;
                COMMIT;
                o_status := 'SUCCESS';
                o_message := 'Book deleted permanently.';
            END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Failed to remove book: ' || SQLERRM;
    END remove_book;

    -- Update inventory stock
    PROCEDURE update_stock(
        p_book_id        IN  NUMBER,
        p_delta_quantity IN  NUMBER,
        o_new_stock      OUT NUMBER,
        o_status         OUT VARCHAR2,
        o_message        OUT VARCHAR2
    ) IS
        v_curr_stock NUMBER;
    BEGIN
        SELECT stock_quantity INTO v_curr_stock FROM BOOKS WHERE book_id = p_book_id FOR UPDATE;

        IF (v_curr_stock + p_delta_quantity) < 0 THEN
            o_status := 'ERROR';
            o_message := 'Insufficient stock. Current stock: ' || v_curr_stock || ', requested deduction: ' || ABS(p_delta_quantity);
            ROLLBACK;
            RETURN;
        END IF;

        UPDATE BOOKS
        SET stock_quantity = stock_quantity + p_delta_quantity,
            updated_at = SYSDATE
        WHERE book_id = p_book_id
        RETURNING stock_quantity INTO o_new_stock;

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Stock updated successfully. New stock: ' || o_new_stock;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Book ID ' || p_book_id || ' not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Stock update failed: ' || SQLERRM;
    END update_stock;

    -- Search books
    PROCEDURE search_books(
        p_keyword       IN  VARCHAR2 DEFAULT NULL,
        p_category_id   IN  NUMBER   DEFAULT NULL,
        p_min_price     IN  NUMBER   DEFAULT NULL,
        p_max_price     IN  NUMBER   DEFAULT NULL,
        p_in_stock_only IN  VARCHAR2 DEFAULT 'N',
        o_cursor        OUT SYS_REFCURSOR
    ) IS
        v_clean_kw VARCHAR2(200) := '%' || UPPER(TRIM(NVL(p_keyword, ''))) || '%';
    BEGIN
        OPEN o_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                   c.category_name, b.price, b.stock_quantity, b.publication_year,
                   b.description, b.cover_image, b.is_active, b.created_at
            FROM BOOKS b
            JOIN CATEGORIES c ON b.category_id = c.category_id
            WHERE b.is_active = 'Y'
              AND (p_keyword IS NULL OR (UPPER(b.title) LIKE v_clean_kw OR UPPER(b.author) LIKE v_clean_kw OR UPPER(b.isbn) LIKE v_clean_kw))
              AND (p_category_id IS NULL OR b.category_id = p_category_id)
              AND (p_min_price IS NULL OR b.price >= p_min_price)
              AND (p_max_price IS NULL OR b.price <= p_max_price)
              AND (p_in_stock_only = 'N' OR b.stock_quantity > 0)
            ORDER BY b.title ASC;
    END search_books;

    -- Get book by ID
    PROCEDURE get_book_by_id(
        p_book_id IN  NUMBER,
        o_cursor  OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                   c.category_name, b.price, b.stock_quantity, b.publication_year,
                   b.description, b.cover_image, b.is_active, b.created_at
            FROM BOOKS b
            JOIN CATEGORIES c ON b.category_id = c.category_id
            WHERE b.book_id = p_book_id;
    END get_book_by_id;

    -- Check availability
    FUNCTION check_availability(
        p_book_id      IN NUMBER,
        p_required_qty IN NUMBER
    ) RETURN BOOLEAN IS
        v_stock NUMBER;
    BEGIN
        SELECT stock_quantity INTO v_stock FROM BOOKS WHERE book_id = p_book_id AND is_active = 'Y';
        RETURN (v_stock >= p_required_qty);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END check_availability;

END BOOK_MGMT_PKG;
/

PROMPT Book Management Package Created Successfully.
