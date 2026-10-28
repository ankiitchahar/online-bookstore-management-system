-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 07_reporting_pkg.sql
-- Description: Analytical Reporting, KPI Summaries & Sales Trend Package
-- ============================================================================

CREATE OR REPLACE PACKAGE REPORT_MGMT_PKG AS

    -- Get top best-selling books by volume & revenue
    PROCEDURE get_best_selling_books(
        p_limit  IN  NUMBER DEFAULT 5,
        o_cursor OUT SYS_REFCURSOR
    );

    -- Get daily sales trends over the past N days
    PROCEDURE get_sales_trends(
        p_days_back IN  NUMBER DEFAULT 30,
        o_cursor    OUT SYS_REFCURSOR
    );

    -- Get sales performance aggregated by book category
    PROCEDURE get_category_performance(
        o_cursor OUT SYS_REFCURSOR
    );

    -- Get low stock inventory alert report
    PROCEDURE get_inventory_health(
        p_low_stock_threshold IN  NUMBER DEFAULT 10,
        o_cursor              OUT SYS_REFCURSOR
    );

    -- Executive KPI summary for dashboard widgets
    PROCEDURE get_kpi_summary(
        o_total_revenue      OUT NUMBER,
        o_total_orders       OUT NUMBER,
        o_total_books_sold   OUT NUMBER,
        o_active_users       OUT NUMBER,
        o_low_stock_count    OUT NUMBER
    );

    -- Text-formatted sales summary printable in SQL*Plus / SQL Developer
    PROCEDURE print_sales_summary_report(
        p_days_back IN NUMBER DEFAULT 30
    );

END REPORT_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY REPORT_MGMT_PKG AS

    -- Best selling books
    PROCEDURE get_best_selling_books(
        p_limit  IN  NUMBER DEFAULT 5,
        o_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT * FROM (
                SELECT b.book_id, b.title, b.author, c.category_name,
                       b.price, b.stock_quantity,
                       NVL(SUM(oi.quantity), 0) AS total_units_sold,
                       NVL(SUM(oi.subtotal), 0.00) AS total_revenue
                FROM BOOKS b
                JOIN CATEGORIES c ON b.category_id = c.category_id
                LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
                GROUP BY b.book_id, b.title, b.author, c.category_name, b.price, b.stock_quantity
                ORDER BY total_units_sold DESC, total_revenue DESC
            )
            WHERE ROWNUM <= NVL(p_limit, 5);
    END get_best_selling_books;

    -- Sales trends by date
    PROCEDURE get_sales_trends(
        p_days_back IN  NUMBER DEFAULT 30,
        o_cursor    OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT TRUNC(o.order_date) AS sale_date,
                   COUNT(o.order_id) AS total_orders,
                   SUM(o.total_amount) AS daily_revenue,
                   SUM(oi.quantity) AS books_sold
            FROM ORDERS o
            JOIN ORDER_ITEMS oi ON o.order_id = oi.order_id
            WHERE o.order_status != 'CANCELLED'
              AND o.order_date >= TRUNC(SYSDATE) - NVL(p_days_back, 30)
            GROUP BY TRUNC(o.order_date)
            ORDER BY sale_date DESC;
    END get_sales_trends;

    -- Category performance
    PROCEDURE get_category_performance(
        o_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT c.category_id, c.category_name,
                   COUNT(DISTINCT b.book_id) AS total_titles,
                   NVL(SUM(oi.quantity), 0) AS units_sold,
                   NVL(SUM(oi.subtotal), 0.00) AS total_revenue
            FROM CATEGORIES c
            LEFT JOIN BOOKS b ON c.category_id = b.category_id
            LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
            LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
            GROUP BY c.category_id, c.category_name
            ORDER BY total_revenue DESC;
    END get_category_performance;

    -- Inventory health check
    PROCEDURE get_inventory_health(
        p_low_stock_threshold IN  NUMBER DEFAULT 10,
        o_cursor              OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT b.book_id, b.isbn, b.title, b.author, c.category_name,
                   b.stock_quantity, b.price,
                   CASE 
                       WHEN b.stock_quantity = 0 THEN 'OUT OF STOCK'
                       WHEN b.stock_quantity <= p_low_stock_threshold THEN 'LOW STOCK'
                       ELSE 'HEALTHY'
                   END AS stock_status
            FROM BOOKS b
            JOIN CATEGORIES c ON b.category_id = c.category_id
            WHERE b.stock_quantity <= p_low_stock_threshold
              AND b.is_active = 'Y'
            ORDER BY b.stock_quantity ASC;
    END get_inventory_health;

    -- Executive KPI summary
    PROCEDURE get_kpi_summary(
        o_total_revenue      OUT NUMBER,
        o_total_orders       OUT NUMBER,
        o_total_books_sold   OUT NUMBER,
        o_active_users       OUT NUMBER,
        o_low_stock_count    OUT NUMBER
    ) IS
    BEGIN
        SELECT NVL(SUM(total_amount), 0.00), COUNT(*)
        INTO o_total_revenue, o_total_orders
        FROM ORDERS
        WHERE order_status != 'CANCELLED';

        SELECT NVL(SUM(quantity), 0)
        INTO o_total_books_sold
        FROM ORDER_ITEMS oi
        JOIN ORDERS o ON oi.order_id = o.order_id
        WHERE o.order_status != 'CANCELLED';

        SELECT COUNT(*)
        INTO o_active_users
        FROM USERS
        WHERE status = 'ACTIVE';

        SELECT COUNT(*)
        INTO o_low_stock_count
        FROM BOOKS
        WHERE stock_quantity <= 10 AND is_active = 'Y';
    END get_kpi_summary;

    -- Print DBMS_OUTPUT report
    PROCEDURE print_sales_summary_report(
        p_days_back IN NUMBER DEFAULT 30
    ) IS
        v_total_rev   NUMBER;
        v_orders      NUMBER;
        v_books_sold  NUMBER;
        v_users       NUMBER;
        v_low_stock   NUMBER;
    BEGIN
        get_kpi_summary(v_total_rev, v_orders, v_books_sold, v_users, v_low_stock);

        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('           ONLINE BOOKSTORE MANAGEMENT SYSTEM                   ');
        DBMS_OUTPUT.PUT_LINE('                EXECUTIVE SALES & KPI REPORT                    ');
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('Report Generation Time : ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('Reporting Window       : Past ' || p_days_back || ' Days');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('  Total Revenue (Non-cancelled) : $' || TO_CHAR(v_total_rev, 'FM999,990.00'));
        DBMS_OUTPUT.PUT_LINE('  Total Orders Processed        : ' || v_orders);
        DBMS_OUTPUT.PUT_LINE('  Total Books Sold              : ' || v_books_sold || ' units');
        DBMS_OUTPUT.PUT_LINE('  Active Registered Users       : ' || v_users);
        DBMS_OUTPUT.PUT_LINE('  Items with Low/Zero Stock     : ' || v_low_stock);
        DBMS_OUTPUT.PUT_LINE('================================================================');
        DBMS_OUTPUT.PUT_LINE('TOP 5 BEST-SELLING BOOKS:');
        DBMS_OUTPUT.PUT_LINE(RPAD('ID', 6) || RPAD('TITLE', 32) || RPAD('PRICE', 10) || RPAD('SOLD', 8) || 'REVENUE');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------');

        FOR rec IN (
            SELECT * FROM (
                SELECT b.book_id, b.title, b.price,
                       NVL(SUM(oi.quantity), 0) AS sold_qty,
                       NVL(SUM(oi.subtotal), 0.00) AS total_val
                FROM BOOKS b
                LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
                GROUP BY b.book_id, b.title, b.price
                ORDER BY sold_qty DESC, total_val DESC
            ) WHERE ROWNUM <= 5
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.book_id, 6) ||
                RPAD(SUBSTR(rec.title, 1, 30), 32) ||
                RPAD('$' || TO_CHAR(rec.price, 'FM990.00'), 10) ||
                RPAD(rec.sold_qty, 8) ||
                '$' || TO_CHAR(rec.total_val, 'FM999,990.00')
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('================================================================');
    END print_sales_summary_report;

END REPORT_MGMT_PKG;
/

PROMPT Reporting Package Created Successfully.
