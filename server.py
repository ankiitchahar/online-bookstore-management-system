#!/usr/bin/env python3
"""
============================================================================
ONLINE BOOKSTORE MANAGEMENT SYSTEM
Backend Application Server & API Engine
----------------------------------------------------------------------------
This server provides RESTful API endpoints for the Online Bookstore UI.
It implements the exact business logic of the Oracle PL/SQL packages:
  - USER_MGMT_PKG   (Registration, Auth, Profiles, SHA-256 Hashing)
  - BOOK_MGMT_PKG   (Catalog, Inventory, Search, Stock Control)
  - CART_MGMT_PKG   (Cart Operations, Real-time Subtotal/Taxes/Shipping)
  - ORDER_MGMT_PKG  (Atomic Checkout, Status Workflow, Restock on Cancel)
  - REPORT_MGMT_PKG (Best Sellers, Sales Trends, Category Performance, Low Stock)

Built using Python standard library (http.server + sqlite3) with zero external
dependencies needed for instant execution.
============================================================================
"""

import os
import sys
import json
import sqlite3
import hashlib
import mimetypes
from urllib.parse import urlparse, parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

PORT = 8080
DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bookstore.db")
PUBLIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "public")

def hash_password(password: str, salt: str) -> str:
    combined = f"{password}@BOOKSTORE#{salt}".encode("utf-8")
    return hashlib.sha256(combined).hexdigest()

def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_database():
    """Initializes database schema and seed data matching the Oracle PL/SQL model."""
    conn = get_db()
    c = conn.cursor()

    c.executescript("""
    CREATE TABLE IF NOT EXISTS ROLES (
        role_id INTEGER PRIMARY KEY,
        role_name TEXT UNIQUE NOT NULL,
        description TEXT
    );

    CREATE TABLE IF NOT EXISTS CATEGORIES (
        category_id INTEGER PRIMARY KEY,
        category_name TEXT UNIQUE NOT NULL,
        description TEXT,
        is_active TEXT DEFAULT 'Y' NOT NULL
    );

    CREATE TABLE IF NOT EXISTS USERS (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        role_id INTEGER NOT NULL REFERENCES ROLES(role_id),
        full_name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        phone TEXT,
        shipping_address TEXT,
        status TEXT DEFAULT 'ACTIVE' NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL
    );

    CREATE TABLE IF NOT EXISTS BOOKS (
        book_id INTEGER PRIMARY KEY AUTOINCREMENT,
        isbn TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES CATEGORIES(category_id),
        price REAL NOT NULL CHECK(price >= 0),
        stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK(stock_quantity >= 0),
        publication_year INTEGER,
        description TEXT,
        cover_image TEXT,
        is_active TEXT DEFAULT 'Y' NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL
    );

    CREATE TABLE IF NOT EXISTS CART_ITEMS (
        cart_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES USERS(user_id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL REFERENCES BOOKS(book_id) ON DELETE CASCADE,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
        added_at TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
        UNIQUE(user_id, book_id)
    );

    CREATE TABLE IF NOT EXISTS ORDERS (
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES USERS(user_id),
        order_date TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
        subtotal REAL NOT NULL,
        shipping_fee REAL DEFAULT 0.00 NOT NULL,
        tax_amount REAL DEFAULT 0.00 NOT NULL,
        total_amount REAL NOT NULL,
        shipping_address TEXT NOT NULL,
        payment_method TEXT DEFAULT 'CREDIT_CARD' NOT NULL,
        payment_status TEXT DEFAULT 'PAID' NOT NULL,
        order_status TEXT DEFAULT 'PENDING' NOT NULL,
        notes TEXT
    );

    CREATE TABLE IF NOT EXISTS ORDER_ITEMS (
        order_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES ORDERS(order_id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL REFERENCES BOOKS(book_id),
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS AUDIT_LOGS (
        log_id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT,
        performed_by TEXT,
        action_time TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL,
        details TEXT
    );
    """)

    # Seed Roles if missing
    c.execute("SELECT COUNT(*) FROM ROLES")
    if c.fetchone()[0] == 0:
        c.executemany("INSERT INTO ROLES (role_id, role_name, description) VALUES (?, ?, ?)", [
            (1, "ADMIN", "System administrator with full catalog and order privileges"),
            (2, "CUSTOMER", "Registered customer account")
        ])

    # Seed Categories
    c.execute("SELECT COUNT(*) FROM CATEGORIES")
    if c.fetchone()[0] == 0:
        c.executemany("INSERT INTO CATEGORIES (category_id, category_name, description, is_active) VALUES (?, ?, ?, 'Y')", [
            (1, "Computer Science", "Algorithms, clean code, and software engineering architecture"),
            (2, "Database Systems", "SQL, PL/SQL, distributed databases, and transaction processing"),
            (3, "Fiction & Literature", "Timeless classics and modern literary fiction"),
            (4, "Business & Leadership", "Entrepreneurship, economics, and leadership frameworks"),
            (5, "Science & Nature", "Cosmology, physics, biology, and scientific thought"),
            (6, "Self-Help & Productivity", "Mindset, habit cultivation, and cognitive productivity")
        ])

    # Seed Users
    c.execute("SELECT COUNT(*) FROM USERS")
    if c.fetchone()[0] == 0:
        def add_user(name, email, pwd, phone, addr, role_id):
            salt = os.urandom(16).hex()
            h = hash_password(pwd, salt)
            c.execute("""
            INSERT INTO USERS (role_id, full_name, email, password_hash, salt, phone, shipping_address, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE')
            """, (role_id, name, email.lower(), h, salt, phone, addr))

        add_user("System Administrator", "admin@bookstore.com", "admin123", "+1-800-555-0199", "100 Oracle Parkway, Redwood Shores, CA", 1)
        add_user("Alice Johnson", "alice@example.com", "alice123", "+1-555-234-5678", "742 Evergreen Terrace, Springfield, OR 97477", 2)
        add_user("Bob Smith", "bob@example.com", "bob123", "+1-555-876-5432", "221B Baker Street, London NW1 6XE", 2)
        add_user("Clara Oswald", "clara@example.com", "clara123", "+1-555-432-1098", "15 Coal Hill Road, London EC2A 3BX", 2)

    # Seed Books
    c.execute("SELECT COUNT(*) FROM BOOKS")
    if c.fetchone()[0] == 0:
        books_seed = [
            ("978-1449324452", "Oracle PL/SQL Programming", "Steven Feuerstein", 2, 49.99, 35, 2014,
             "The definitive authority on Oracle Database's procedural language, triggers, packages, dynamic SQL, and performance tuning.",
             "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop&q=80"),
            ("978-0078022159", "Database System Concepts", "Abraham Silberschatz", 2, 64.50, 18, 2019,
             "Comprehensive foundation covering relational algebra, SQL optimization, ACID transactions, concurrency, and indexing.",
             "https://images.unsplash.com/photo-1532012164546-f432f2e3777a?w=600&auto=format&fit=crop&q=80"),
            ("978-1491903063", "Designing Data-Intensive Applications", "Martin Kleppmann", 2, 42.00, 40, 2017,
             "An acclaimed architectural deep dive into distributed data storage, partitioning, replication, stream processing, and consensus.",
             "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=600&auto=format&fit=crop&q=80"),
            ("978-0132350884", "Clean Code", "Robert C. Martin", 1, 38.95, 25, 2008,
             "A Handbook of Agile Software Craftsmanship teaching principles of readable, maintainable, and bug-resistant programming.",
             "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&auto=format&fit=crop&q=80"),
            ("978-0135957059", "The Pragmatic Programmer", "David Thomas & Andrew Hunt", 1, 45.50, 15, 2019,
             "Classic guide to engineering excellence, automated testing, continuous learning, avoiding software rot, and career development.",
             "https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=600&auto=format&fit=crop&q=80"),
            ("978-0735211292", "Atomic Habits", "James Clear", 6, 18.99, 50, 2018,
             "A proven framework for improving everyday routines by 1% with cue-craving-response-reward systems.",
             "https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=600&auto=format&fit=crop&q=80"),
            ("978-1455586691", "Deep Work", "Cal Newport", 6, 21.50, 12, 2016,
             "Rules for focused success in a distracted world. Master difficult information quickly and produce premium creative work.",
             "https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=600&auto=format&fit=crop&q=80"),
            ("978-0061120084", "To Kill a Mockingbird", "Harper Lee", 3, 14.99, 45, 1960,
             "Pulitzer Prize-winning masterpiece exploring courage, empathy, and racial injustice in the American South.",
             "https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=600&auto=format&fit=crop&q=80"),
            ("978-0451524935", "1984", "George Orwell", 3, 12.95, 4, 1949,
             "Seminal dystopian portrait of totalitarian surveillance, doublethink, and government truth control.",
             "https://images.unsplash.com/photo-1495640388908-05fa85288e61?w=600&auto=format&fit=crop&q=80"),
            ("978-0553380163", "A Brief History of Time", "Stephen Hawking", 5, 16.80, 22, 1988,
             "Landmark tour from the Big Bang to black holes, exploring space, time, quantum gravity, and the cosmos.",
             "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80"),
            ("978-0804139298", "Zero to One", "Peter Thiel", 4, 22.00, 30, 2014,
             "Notes on startups and how to build the future through breakthrough technological innovation rather than incremental copies.",
             "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=600&auto=format&fit=crop&q=80"),
            ("978-0743273565", "The Great Gatsby", "F. Scott Fitzgerald", 3, 13.50, 0, 1925,
             "Iconic Jazz Age tragedy detailing romantic obsession, opulence, and moral disillusionment in 1920s Long Island.",
             "https://images.unsplash.com/photo-1476275466078-4007374efbbe?w=600&auto=format&fit=crop&q=80")
        ]

        c.executemany("""
        INSERT INTO BOOKS (isbn, title, author, category_id, price, stock_quantity, publication_year, description, cover_image, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Y')
        """, books_seed)

    # Seed Sample Initial Orders for realistic reporting
    c.execute("SELECT COUNT(*) FROM ORDERS")
    if c.fetchone()[0] == 0:
        # Alice order
        c.execute("INSERT INTO ORDERS (user_id, order_date, subtotal, shipping_fee, tax_amount, total_amount, shipping_address, payment_method, payment_status, order_status, notes) VALUES (2, '2026-10-25 10:15:00', 68.98, 0.00, 5.52, 74.50, '742 Evergreen Terrace, Springfield, OR', 'CREDIT_CARD', 'PAID', 'DELIVERED', 'Front porch delivery')")
        oid1 = c.lastrowid
        c.execute("INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal) VALUES (?, 1, 1, 49.99, 49.99)", (oid1,))
        c.execute("INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal) VALUES (?, 6, 1, 18.99, 18.99)", (oid1,))

        # Bob order
        c.execute("INSERT INTO ORDERS (user_id, order_date, subtotal, shipping_fee, tax_amount, total_amount, shipping_address, payment_method, payment_status, order_status, notes) VALUES (3, '2026-10-26 14:30:00', 79.99, 0.00, 6.40, 86.39, '221B Baker Street, London NW1 6XE', 'PAYPAL', 'PAID', 'PROCESSING', 'Ring doorbell')")
        oid2 = c.lastrowid
        c.execute("INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal) VALUES (?, 3, 1, 42.00, 42.00)", (oid2,))
        c.execute("INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal) VALUES (?, 6, 2, 18.99, 37.98)", (oid2,))

        # Audit logs
        c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('CHECKOUT', 'ORDERS', ?, 'alice@example.com', 'Placed order total $74.50')", (str(oid1),))
        c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('CHECKOUT', 'ORDERS', ?, 'bob@example.com', 'Placed order total $86.39')", (str(oid2),))

    conn.commit()
    conn.close()

class BookstoreRequestHandler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-Id")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-Id")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.end_headers()

    def get_current_user_id(self):
        header_val = self.headers.get("X-User-Id")
        if header_val and header_val.isdigit():
            return int(header_val)
        return None

    def read_json_body(self):
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > 0:
            raw = self.rfile.read(content_length).decode("utf-8")
            return json.loads(raw)
        return {}

    # ------------------------------------------------------------------------
    # GET Handlers
    # ------------------------------------------------------------------------
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        # Serve static files for Web UI
        if not path.startswith("/api/"):
            if path == "/" or path == "":
                path = "/index.html"
            local_file = os.path.join(PUBLIC_DIR, path.lstrip("/"))
            if os.path.isfile(local_file):
                mime, _ = mimetypes.guess_type(local_file)
                self.send_response(200)
                self.send_header("Content-Type", mime or "application/octet-stream")
                with open(local_file, "rb") as f:
                    content = f.read()
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"File Not Found")
                return

        conn = get_db()
        c = conn.cursor()

        try:
            # 1. Categories
            if path == "/api/categories":
                c.execute("SELECT category_id, category_name, description FROM CATEGORIES WHERE is_active = 'Y' ORDER BY category_id")
                categories = [dict(row) for row in c.fetchall()]
                self.send_json({"status": "SUCCESS", "data": categories})

            # 2. Books Catalog / Search
            elif path == "/api/books":
                keyword = params.get("keyword", [None])[0]
                category_id = params.get("category_id", [None])[0]
                in_stock_only = params.get("in_stock_only", ["N"])[0]

                sql = """
                SELECT b.book_id, b.isbn, b.title, b.author, b.category_id,
                       c.category_name, b.price, b.stock_quantity, b.publication_year,
                       b.description, b.cover_image, b.is_active
                FROM BOOKS b
                JOIN CATEGORIES c ON b.category_id = c.category_id
                WHERE b.is_active = 'Y'
                """
                args = []

                if keyword and keyword.strip():
                    kw = f"%{keyword.strip().lower()}%"
                    sql += " AND (LOWER(b.title) LIKE ? OR LOWER(b.author) LIKE ? OR LOWER(b.isbn) LIKE ?)"
                    args.extend([kw, kw, kw])

                if category_id and category_id.isdigit():
                    sql += " AND b.category_id = ?"
                    args.append(int(category_id))

                if in_stock_only == "Y":
                    sql += " AND b.stock_quantity > 0"

                sql += " ORDER BY b.title ASC"
                c.execute(sql, args)
                books = [dict(row) for row in c.fetchall()]
                self.send_json({"status": "SUCCESS", "data": books})

            # 3. Single Book Details
            elif path.startswith("/api/books/"):
                book_id = int(path.split("/")[-1])
                c.execute("""
                SELECT b.*, c.category_name
                FROM BOOKS b
                JOIN CATEGORIES c ON b.category_id = c.category_id
                WHERE b.book_id = ?
                """, (book_id,))
                row = c.fetchone()
                if row:
                    self.send_json({"status": "SUCCESS", "data": dict(row)})
                else:
                    self.send_json({"status": "ERROR", "message": "Book not found"}, 404)

            # 4. User Profile
            elif path == "/api/auth/profile":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return
                c.execute("""
                SELECT u.user_id, u.full_name, u.email, u.phone, u.shipping_address, u.status, u.created_at, r.role_name
                FROM USERS u JOIN ROLES r ON u.role_id = r.role_id WHERE u.user_id = ?
                """, (uid,))
                row = c.fetchone()
                if row:
                    self.send_json({"status": "SUCCESS", "data": dict(row)})
                else:
                    self.send_json({"status": "ERROR", "message": "User not found"}, 404)

            # 5. Shopping Cart Items & Calculations
            elif path == "/api/cart":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Please login to view cart"}, 401)
                    return
                c.execute("""
                SELECT c.cart_id, c.book_id, b.title, b.author, b.isbn,
                       b.cover_image, b.price, c.quantity,
                       ROUND(c.quantity * b.price, 2) AS line_total,
                       b.stock_quantity AS available_stock
                FROM CART_ITEMS c
                JOIN BOOKS b ON c.book_id = b.book_id
                WHERE c.user_id = ?
                ORDER BY c.added_at DESC
                """, (uid,))
                items = [dict(row) for row in c.fetchall()]

                subtotal = sum(i["line_total"] for i in items)
                item_count = sum(i["quantity"] for i in items)
                shipping = 0.00 if (subtotal >= 35.00 or item_count == 0) else 4.99
                tax = round(subtotal * 0.08, 2)
                total = round(subtotal + shipping + tax, 2)

                self.send_json({
                    "status": "SUCCESS",
                    "data": {
                        "items": items,
                        "item_count": item_count,
                        "subtotal": round(subtotal, 2),
                        "shipping": shipping,
                        "tax": tax,
                        "total": total
                    }
                })

            # 6. Orders (User history or Admin all orders)
            elif path == "/api/orders":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return

                # Check if user is admin
                c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                u_role = c.fetchone()
                is_admin = u_role and u_role["role_id"] == 1
                as_admin = params.get("admin", ["0"])[0] == "1" and is_admin

                if as_admin:
                    status_filter = params.get("status", [None])[0]
                    sql = """
                    SELECT o.*, u.full_name AS customer_name, u.email AS customer_email,
                           COUNT(oi.order_item_id) AS total_items,
                           SUM(oi.quantity) AS total_units
                    FROM ORDERS o
                    JOIN USERS u ON o.user_id = u.user_id
                    LEFT JOIN ORDER_ITEMS oi ON o.order_id = oi.order_id
                    """
                    args = []
                    if status_filter:
                        sql += " WHERE o.order_status = ?"
                        args.append(status_filter.upper())
                    sql += " GROUP BY o.order_id ORDER BY o.order_date DESC"
                    c.execute(sql, args)
                else:
                    c.execute("""
                    SELECT o.*,
                           COUNT(oi.order_item_id) AS total_items,
                           SUM(oi.quantity) AS total_units
                    FROM ORDERS o
                    LEFT JOIN ORDER_ITEMS oi ON o.order_id = oi.order_id
                    WHERE o.user_id = ?
                    GROUP BY o.order_id
                    ORDER BY o.order_date DESC
                    """, (uid,))

                orders = [dict(row) for row in c.fetchall()]
                self.send_json({"status": "SUCCESS", "data": orders})

            # 7. Order Details with Line Items
            elif path.startswith("/api/orders/"):
                oid = int(path.split("/")[-1])
                c.execute("""
                SELECT o.*, u.full_name, u.email
                FROM ORDERS o JOIN USERS u ON o.user_id = u.user_id
                WHERE o.order_id = ?
                """, (oid,))
                order = c.fetchone()
                if not order:
                    self.send_json({"status": "ERROR", "message": "Order not found"}, 404)
                    return

                c.execute("""
                SELECT oi.*, b.title, b.author, b.isbn, b.cover_image
                FROM ORDER_ITEMS oi
                JOIN BOOKS b ON oi.book_id = b.book_id
                WHERE oi.order_id = ?
                """, (oid,))
                items = [dict(r) for r in c.fetchall()]
                self.send_json({"status": "SUCCESS", "data": {"order": dict(order), "items": items}})

            # 8. Reports & Analytics
            elif path == "/api/reports/kpis":
                c.execute("SELECT IFNULL(SUM(total_amount), 0), COUNT(*) FROM ORDERS WHERE order_status != 'CANCELLED'")
                rev, ords = c.fetchone()
                c.execute("SELECT IFNULL(SUM(quantity), 0) FROM ORDER_ITEMS oi JOIN ORDERS o ON oi.order_id = o.order_id WHERE o.order_status != 'CANCELLED'")
                units = c.fetchone()[0]
                c.execute("SELECT COUNT(*) FROM USERS WHERE status = 'ACTIVE'")
                users = c.fetchone()[0]
                c.execute("SELECT COUNT(*) FROM BOOKS WHERE stock_quantity <= 10 AND is_active = 'Y'")
                low_stock = c.fetchone()[0]

                self.send_json({
                    "status": "SUCCESS",
                    "data": {
                        "total_revenue": round(rev, 2),
                        "total_orders": ords,
                        "total_books_sold": units,
                        "active_users": users,
                        "low_stock_count": low_stock
                    }
                })

            elif path == "/api/reports/best-sellers":
                c.execute("""
                SELECT b.book_id, b.title, b.author, c.category_name, b.price, b.stock_quantity,
                       IFNULL(SUM(oi.quantity), 0) AS total_units_sold,
                       ROUND(IFNULL(SUM(oi.subtotal), 0.0), 2) AS total_revenue
                FROM BOOKS b
                JOIN CATEGORIES c ON b.category_id = c.category_id
                LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
                GROUP BY b.book_id
                ORDER BY total_units_sold DESC, total_revenue DESC
                LIMIT 6
                """)
                self.send_json({"status": "SUCCESS", "data": [dict(r) for r in c.fetchall()]})

            elif path == "/api/reports/category-performance":
                c.execute("""
                SELECT c.category_id, c.category_name,
                       COUNT(DISTINCT b.book_id) AS total_titles,
                       IFNULL(SUM(oi.quantity), 0) AS units_sold,
                       ROUND(IFNULL(SUM(oi.subtotal), 0.0), 2) AS total_revenue
                FROM CATEGORIES c
                LEFT JOIN BOOKS b ON c.category_id = b.category_id
                LEFT JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
                LEFT JOIN ORDERS o ON oi.order_id = o.order_id AND o.order_status != 'CANCELLED'
                GROUP BY c.category_id
                ORDER BY total_revenue DESC
                """)
                self.send_json({"status": "SUCCESS", "data": [dict(r) for r in c.fetchall()]})

            elif path == "/api/reports/low-stock":
                c.execute("""
                SELECT b.book_id, b.isbn, b.title, b.author, c.category_name, b.stock_quantity, b.price,
                       CASE WHEN b.stock_quantity = 0 THEN 'OUT OF STOCK' ELSE 'LOW STOCK' END AS stock_status
                FROM BOOKS b
                JOIN CATEGORIES c ON b.category_id = c.category_id
                WHERE b.stock_quantity <= 10 AND b.is_active = 'Y'
                ORDER BY b.stock_quantity ASC
                """)
                self.send_json({"status": "SUCCESS", "data": [dict(r) for r in c.fetchall()]})

            elif path == "/api/audit-logs":
                c.execute("SELECT * FROM AUDIT_LOGS ORDER BY action_time DESC LIMIT 25")
                self.send_json({"status": "SUCCESS", "data": [dict(r) for r in c.fetchall()]})

            else:
                self.send_json({"status": "ERROR", "message": "Endpoint not found"}, 404)

        finally:
            conn.close()

    # ------------------------------------------------------------------------
    # POST Handlers
    # ------------------------------------------------------------------------
    def do_POST(self):
        path = urlparse(self.path).path
        payload = self.read_json_body()
        conn = get_db()
        c = conn.cursor()

        try:
            # 1. User Registration
            if path == "/api/auth/register":
                name = payload.get("full_name", "").strip()
                email = payload.get("email", "").strip().lower()
                pwd = payload.get("password", "")
                phone = payload.get("phone", "")
                addr = payload.get("shipping_address", "")
                role_name = payload.get("role", "CUSTOMER").upper()

                if not name or not email or not pwd:
                    self.send_json({"status": "ERROR", "message": "Name, email, and password are required."}, 400)
                    return
                if len(pwd) < 6:
                    self.send_json({"status": "ERROR", "message": "Password must be at least 6 characters."}, 400)
                    return

                c.execute("SELECT COUNT(*) FROM USERS WHERE LOWER(email) = ?", (email,))
                if c.fetchone()[0] > 0:
                    self.send_json({"status": "ERROR", "message": f"An account with email {email} already exists."}, 400)
                    return

                role_id = 1 if role_name == "ADMIN" else 2
                salt = os.urandom(16).hex()
                h = hash_password(pwd, salt)

                c.execute("""
                INSERT INTO USERS (role_id, full_name, email, password_hash, salt, phone, shipping_address, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE')
                """, (role_id, name, email, h, salt, phone, addr))
                uid = c.lastrowid

                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('REGISTER', 'USERS', ?, ?, 'Registered new user')", (str(uid), email))
                conn.commit()

                self.send_json({
                    "status": "SUCCESS",
                    "message": "User registered successfully.",
                    "data": {"user_id": uid, "full_name": name, "email": email, "role": role_name}
                })

            # 2. User Authentication / Login
            elif path == "/api/auth/login":
                email = payload.get("email", "").strip().lower()
                pwd = payload.get("password", "")

                c.execute("""
                SELECT u.user_id, u.full_name, u.password_hash, u.salt, u.status, r.role_name
                FROM USERS u JOIN ROLES r ON u.role_id = r.role_id
                WHERE LOWER(u.email) = ?
                """, (email,))
                row = c.fetchone()

                if not row:
                    self.send_json({"status": "ERROR", "message": "No account found with this email."}, 401)
                    return

                if row["status"] != "ACTIVE":
                    self.send_json({"status": "ERROR", "message": f"Account is {row['status']}."}, 403)
                    return

                calc_hash = hash_password(pwd, row["salt"])
                if calc_hash == row["password_hash"]:
                    c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('LOGIN', 'USERS', ?, ?, 'Logged in successfully')", (str(row["user_id"]), email))
                    conn.commit()

                    self.send_json({
                        "status": "SUCCESS",
                        "message": "Login successful.",
                        "data": {
                            "user_id": row["user_id"],
                            "full_name": row["full_name"],
                            "email": email,
                            "role": row["role_name"]
                        }
                    })
                else:
                    self.send_json({"status": "ERROR", "message": "Invalid password."}, 401)

            # 3. Add to Cart
            elif path == "/api/cart":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Please login to add items to cart."}, 401)
                    return

                book_id = payload.get("book_id")
                qty = payload.get("quantity", 1)

                c.execute("SELECT stock_quantity, title, is_active FROM BOOKS WHERE book_id = ?", (book_id,))
                book = c.fetchone()
                if not book or book["is_active"] != "Y":
                    self.send_json({"status": "ERROR", "message": "Book is unavailable."}, 400)
                    return

                c.execute("SELECT quantity FROM CART_ITEMS WHERE user_id = ? AND book_id = ?", (uid, book_id))
                existing = c.fetchone()
                current_qty = existing["quantity"] if existing else 0
                new_qty = current_qty + qty

                if new_qty > book["stock_quantity"]:
                    self.send_json({
                        "status": "ERROR",
                        "message": f"Cannot add {qty} items. Only {book['stock_quantity']} available in stock."
                    }, 400)
                    return

                if existing:
                    c.execute("UPDATE CART_ITEMS SET quantity = ?, added_at = CURRENT_TIMESTAMP WHERE user_id = ? AND book_id = ?", (new_qty, uid, book_id))
                else:
                    c.execute("INSERT INTO CART_ITEMS (user_id, book_id, quantity) VALUES (?, ?, ?)", (uid, book_id, qty))

                conn.commit()
                self.send_json({"status": "SUCCESS", "message": f'"{book["title"]}" added to cart.'})

            # 4. Checkout / Place Order from Cart
            elif path == "/api/orders":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Please login to place an order."}, 401)
                    return

                shipping_addr = payload.get("shipping_address", "").strip()
                payment_method = payload.get("payment_method", "CREDIT_CARD")
                notes = payload.get("notes", "")

                # Fetch cart items
                c.execute("""
                SELECT c.book_id, c.quantity, b.price, b.stock_quantity, b.title
                FROM CART_ITEMS c
                JOIN BOOKS b ON c.book_id = b.book_id
                WHERE c.user_id = ?
                """, (uid,))
                cart_items = c.fetchall()

                if not cart_items:
                    self.send_json({"status": "ERROR", "message": "Cart is empty."}, 400)
                    return

                if not shipping_addr:
                    c.execute("SELECT shipping_address FROM USERS WHERE user_id = ?", (uid,))
                    u_row = c.fetchone()
                    shipping_addr = u_row["shipping_address"] if u_row else ""
                    if not shipping_addr:
                        self.send_json({"status": "ERROR", "message": "Shipping address is required."}, 400)
                        return

                # Validate stock for all items
                for item in cart_items:
                    if item["stock_quantity"] < item["quantity"]:
                        self.send_json({
                            "status": "ERROR",
                            "message": f"Insufficient stock for '{item['title']}'. Requested: {item['quantity']}, Available: {item['stock_quantity']}"
                        }, 400)
                        return

                # Calculate monetary totals
                subtotal = sum(i["price"] * i["quantity"] for i in cart_items)
                shipping_fee = 0.00 if subtotal >= 35.00 else 4.99
                tax_amount = round(subtotal * 0.08, 2)
                total_amount = round(subtotal + shipping_fee + tax_amount, 2)

                # Insert Order Header
                c.execute("""
                INSERT INTO ORDERS (user_id, subtotal, shipping_fee, tax_amount, total_amount, shipping_address, payment_method, payment_status, order_status, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'PAID', 'PENDING', ?)
                """, (uid, round(subtotal, 2), shipping_fee, tax_amount, total_amount, shipping_addr, payment_method, notes))
                order_id = c.lastrowid

                # Insert Order Items & Deduct Inventory
                for item in cart_items:
                    line_subtotal = round(item["price"] * item["quantity"], 2)
                    c.execute("""
                    INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal)
                    VALUES (?, ?, ?, ?, ?)
                    """, (order_id, item["book_id"], item["quantity"], item["price"], line_subtotal))

                    c.execute("""
                    UPDATE BOOKS SET stock_quantity = stock_quantity - ?, updated_at = CURRENT_TIMESTAMP
                    WHERE book_id = ?
                    """, (item["quantity"], item["book_id"]))

                # Clear Cart
                c.execute("DELETE FROM CART_ITEMS WHERE user_id = ?", (uid,))

                # Audit Log
                c.execute("""
                INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details)
                VALUES ('CHECKOUT', 'ORDERS', ?, ?, ?)
                """, (str(order_id), str(uid), f"Order placed for total ${total_amount:.2f}"))

                conn.commit()
                self.send_json({
                    "status": "SUCCESS",
                    "message": f"Order #{order_id} placed successfully!",
                    "data": {"order_id": order_id, "total_amount": total_amount}
                })

            # 5. Add New Book (Admin)
            elif path == "/api/books":
                uid = self.get_current_user_id()
                c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                r = c.fetchone()
                if not r or r["role_id"] != 1:
                    self.send_json({"status": "ERROR", "message": "Admin authorization required."}, 403)
                    return

                isbn = payload.get("isbn", "").strip()
                title = payload.get("title", "").strip()
                author = payload.get("author", "").strip()
                cat_id = payload.get("category_id")
                price = float(payload.get("price", 0))
                stock = int(payload.get("stock_quantity", 0))
                pub_yr = payload.get("publication_year")
                desc = payload.get("description", "")
                cover = payload.get("cover_image", "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600")

                c.execute("SELECT COUNT(*) FROM BOOKS WHERE isbn = ?", (isbn,))
                if c.fetchone()[0] > 0:
                    self.send_json({"status": "ERROR", "message": f"A book with ISBN {isbn} already exists."}, 400)
                    return

                c.execute("""
                INSERT INTO BOOKS (isbn, title, author, category_id, price, stock_quantity, publication_year, description, cover_image, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Y')
                """, (isbn, title, author, cat_id, price, stock, pub_yr, desc, cover))
                bid = c.lastrowid

                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('INSERT', 'BOOKS', ?, 'ADMIN', ?)",
                          (str(bid), f"Added book '{title}' with stock {stock}"))
                conn.commit()

                self.send_json({"status": "SUCCESS", "message": "Book added successfully.", "data": {"book_id": bid}})

            # 6. Cancel Order (Restock inventory)
            elif path.endswith("/cancel") and "/api/orders/" in path:
                oid = int(path.split("/")[-2])
                uid = self.get_current_user_id()
                c.execute("SELECT user_id, order_status FROM ORDERS WHERE order_id = ?", (oid,))
                ord_row = c.fetchone()
                if not ord_row:
                    self.send_json({"status": "ERROR", "message": "Order not found."}, 404)
                    return

                if ord_row["user_id"] != uid:
                    # check if admin
                    c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                    u_role = c.fetchone()
                    if not u_role or u_role["role_id"] != 1:
                        self.send_json({"status": "ERROR", "message": "Not authorized to cancel this order."}, 403)
                        return

                if ord_row["order_status"] not in ("PENDING", "PROCESSING"):
                    self.send_json({"status": "ERROR", "message": f"Orders in status {ord_row['order_status']} cannot be cancelled."}, 400)
                    return

                # Restock inventory items
                c.execute("SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = ?", (oid,))
                for it in c.fetchall():
                    c.execute("UPDATE BOOKS SET stock_quantity = stock_quantity + ?, updated_at = CURRENT_TIMESTAMP WHERE book_id = ?", (it["quantity"], it["book_id"]))

                c.execute("UPDATE ORDERS SET order_status = 'CANCELLED' WHERE order_id = ?", (oid,))
                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('CANCEL', 'ORDERS', ?, ?, 'Order cancelled and inventory restored')", (str(oid), str(uid)))
                conn.commit()

                self.send_json({"status": "SUCCESS", "message": f"Order #{oid} cancelled and inventory restored."})

            else:
                self.send_json({"status": "ERROR", "message": "Endpoint not found"}, 404)

        finally:
            conn.close()

    # ------------------------------------------------------------------------
    # PUT Handlers
    # ------------------------------------------------------------------------
    def do_PUT(self):
        path = urlparse(self.path).path
        payload = self.read_json_body()
        conn = get_db()
        c = conn.cursor()

        try:
            # 1. Update Cart Quantity
            if path.startswith("/api/cart/"):
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return

                book_id = int(path.split("/")[-1])
                qty = int(payload.get("quantity", 1))

                if qty <= 0:
                    c.execute("DELETE FROM CART_ITEMS WHERE user_id = ? AND book_id = ?", (uid, book_id))
                    conn.commit()
                    self.send_json({"status": "SUCCESS", "message": "Item removed from cart."})
                    return

                c.execute("SELECT stock_quantity FROM BOOKS WHERE book_id = ?", (book_id,))
                b = c.fetchone()
                if not b or qty > b["stock_quantity"]:
                    self.send_json({"status": "ERROR", "message": f"Only {b['stock_quantity'] if b else 0} available in stock."}, 400)
                    return

                c.execute("UPDATE CART_ITEMS SET quantity = ?, added_at = CURRENT_TIMESTAMP WHERE user_id = ? AND book_id = ?", (qty, uid, book_id))
                conn.commit()
                self.send_json({"status": "SUCCESS", "message": "Cart updated."})

            # 2. Update Order Status (Admin)
            elif "/status" in path and "/api/orders/" in path:
                uid = self.get_current_user_id()
                c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                r = c.fetchone()
                if not r or r["role_id"] != 1:
                    self.send_json({"status": "ERROR", "message": "Admin authorization required."}, 403)
                    return

                oid = int(path.split("/")[3])
                new_status = payload.get("order_status", "").upper()

                if new_status not in ("PENDING", "PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED"):
                    self.send_json({"status": "ERROR", "message": "Invalid order status."}, 400)
                    return

                c.execute("SELECT order_status FROM ORDERS WHERE order_id = ?", (oid,))
                cur_ord = c.fetchone()
                if not cur_ord:
                    self.send_json({"status": "ERROR", "message": "Order not found."}, 404)
                    return

                if cur_ord["order_status"] == "CANCELLED":
                    self.send_json({"status": "ERROR", "message": "Cancelled orders cannot be modified."}, 400)
                    return

                # If transition to CANCELLED, restock inventory
                if new_status == "CANCELLED":
                    c.execute("SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = ?", (oid,))
                    for it in c.fetchall():
                        c.execute("UPDATE BOOKS SET stock_quantity = stock_quantity + ? WHERE book_id = ?", (it["quantity"], it["book_id"]))

                c.execute("UPDATE ORDERS SET order_status = ? WHERE order_id = ?", (new_status, oid))
                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('STATUS_CHANGE', 'ORDERS', ?, 'ADMIN', ?)",
                          (str(oid), f"Status updated from {cur_ord['order_status']} to {new_status}"))
                conn.commit()

                self.send_json({"status": "SUCCESS", "message": f"Order #{oid} status changed to {new_status}."})

            # 3. Update Book Details (Admin)
            elif path.startswith("/api/books/"):
                uid = self.get_current_user_id()
                c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                r = c.fetchone()
                if not r or r["role_id"] != 1:
                    self.send_json({"status": "ERROR", "message": "Admin authorization required."}, 403)
                    return

                book_id = int(path.split("/")[-1])
                c.execute("SELECT * FROM BOOKS WHERE book_id = ?", (book_id,))
                cur = c.fetchone()
                if not cur:
                    self.send_json({"status": "ERROR", "message": "Book not found."}, 404)
                    return

                title = payload.get("title", cur["title"])
                author = payload.get("author", cur["author"])
                cat_id = payload.get("category_id", cur["category_id"])
                price = float(payload.get("price", cur["price"]))
                stock = int(payload.get("stock_quantity", cur["stock_quantity"]))
                desc = payload.get("description", cur["description"])
                cover = payload.get("cover_image", cur["cover_image"])

                c.execute("""
                UPDATE BOOKS
                SET title = ?, author = ?, category_id = ?, price = ?, stock_quantity = ?, description = ?, cover_image = ?, updated_at = CURRENT_TIMESTAMP
                WHERE book_id = ?
                """, (title, author, cat_id, price, stock, desc, cover, book_id))

                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('UPDATE', 'BOOKS', ?, 'ADMIN', ?)",
                          (str(book_id), f"Updated '{title}': price=${price}, stock={stock}"))
                conn.commit()

                self.send_json({"status": "SUCCESS", "message": "Book updated successfully."})

            # 4. Update Profile
            elif path == "/api/auth/profile":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return

                name = payload.get("full_name")
                phone = payload.get("phone")
                addr = payload.get("shipping_address")

                c.execute("""
                UPDATE USERS
                SET full_name = COALESCE(?, full_name),
                    phone = COALESCE(?, phone),
                    shipping_address = COALESCE(?, shipping_address),
                    updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ?
                """, (name, phone, addr, uid))
                conn.commit()

                self.send_json({"status": "SUCCESS", "message": "Profile updated successfully."})

            else:
                self.send_json({"status": "ERROR", "message": "Endpoint not found"}, 404)

        finally:
            conn.close()

    # ------------------------------------------------------------------------
    # DELETE Handlers
    # ------------------------------------------------------------------------
    def do_DELETE(self):
        path = urlparse(self.path).path
        conn = get_db()
        c = conn.cursor()

        try:
            # Clear or remove item from cart
            if path == "/api/cart":
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return
                c.execute("DELETE FROM CART_ITEMS WHERE user_id = ?", (uid,))
                conn.commit()
                self.send_json({"status": "SUCCESS", "message": "Cart cleared."})

            elif path.startswith("/api/cart/"):
                uid = self.get_current_user_id()
                if not uid:
                    self.send_json({"status": "ERROR", "message": "Unauthorized"}, 401)
                    return
                book_id = int(path.split("/")[-1])
                c.execute("DELETE FROM CART_ITEMS WHERE user_id = ? AND book_id = ?", (uid, book_id))
                conn.commit()
                self.send_json({"status": "SUCCESS", "message": "Item removed from cart."})

            # Deactivate Book (Admin)
            elif path.startswith("/api/books/"):
                uid = self.get_current_user_id()
                c.execute("SELECT role_id FROM USERS WHERE user_id = ?", (uid,))
                r = c.fetchone()
                if not r or r["role_id"] != 1:
                    self.send_json({"status": "ERROR", "message": "Admin authorization required."}, 403)
                    return
                book_id = int(path.split("/")[-1])
                c.execute("UPDATE BOOKS SET is_active = 'N', updated_at = CURRENT_TIMESTAMP WHERE book_id = ?", (book_id,))
                c.execute("INSERT INTO AUDIT_LOGS (action_type, table_name, record_id, performed_by, details) VALUES ('DELETE', 'BOOKS', ?, 'ADMIN', 'Deactivated book')", (str(book_id),))
                conn.commit()
                self.send_json({"status": "SUCCESS", "message": "Book deactivated."})

            else:
                self.send_json({"status": "ERROR", "message": "Endpoint not found"}, 404)

        finally:
            conn.close()

def run_server():
    init_database()
    os.makedirs(PUBLIC_DIR, exist_ok=True)
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, BookstoreRequestHandler)
    print(f"============================================================")
    print(f" ONLINE BOOKSTORE MANAGEMENT SYSTEM SERVER")
    print(f" Local Web App running at: http://localhost:{PORT}")
    print(f" Matching PL/SQL Database Schema Initialized.")
    print(f"============================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()

if __name__ == "__main__":
    run_server()
