#!/usr/bin/env python3
"""
============================================================================
ONLINE BOOKSTORE MANAGEMENT SYSTEM (STUDENT MINI-PROJECT BACKEND)
============================================================================
Simple, clean Python backend (Zero extra libraries needed).
Uses standard Python library (http.server + sqlite3) to run the student UI.
============================================================================
"""

import os
import json
import sqlite3
import mimetypes
from urllib.parse import urlparse, parse_qs
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 5000
DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "student_bookstore.db")
PUBLIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "public")

def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()

    # 1. Create 5 Simple Student Tables
    c.executescript("""
    CREATE TABLE IF NOT EXISTS USERS (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        phone TEXT,
        role TEXT DEFAULT 'CUSTOMER'
    );

    CREATE TABLE IF NOT EXISTS BOOKS (
        book_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS CART (
        cart_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES USERS(user_id),
        book_id INTEGER REFERENCES BOOKS(book_id),
        quantity INTEGER DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS ORDERS (
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES USERS(user_id),
        order_date TEXT DEFAULT CURRENT_TIMESTAMP,
        total_amount REAL NOT NULL,
        order_status TEXT DEFAULT 'PLACED'
    );

    CREATE TABLE IF NOT EXISTS ORDER_ITEMS (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER REFERENCES ORDERS(order_id),
        book_id INTEGER REFERENCES BOOKS(book_id),
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL
    );
    """)

    # 2. Seed Sample Users
    c.execute("SELECT COUNT(*) FROM USERS")
    if c.fetchone()[0] == 0:
        c.executemany("INSERT INTO USERS (name, email, password, phone, role) VALUES (?, ?, ?, ?, ?)", [
            ("Rahul Sharma", "rahul@gmail.com", "rahul123", "9876543210", "CUSTOMER"),
            ("Priya Singh", "priya@gmail.com", "priya123", "9123456780", "CUSTOMER"),
            ("Admin", "admin@bookstore.com", "admin123", "9998887770", "ADMIN")
        ])

    # 3. Seed Sample Books
    c.execute("SELECT COUNT(*) FROM BOOKS")
    if c.fetchone()[0] == 0:
        c.executemany("INSERT INTO BOOKS (title, author, category, price, stock) VALUES (?, ?, ?, ?, ?)", [
            ("Oracle PL/SQL Programming", "Steven Feuerstein", "Database", 550.00, 25),
            ("Database System Concepts", "Abraham Silberschatz", "Database", 650.00, 15),
            ("Clean Code", "Robert C. Martin", "Programming", 450.00, 20),
            ("The Pragmatic Programmer", "Andrew Hunt", "Programming", 500.00, 10),
            ("Atomic Habits", "James Clear", "Self-Help", 350.00, 30),
            ("Wings of Fire", "Dr. A.P.J. Abdul Kalam", "Biography", 280.00, 18),
            ("To Kill a Mockingbird", "Harper Lee", "Fiction", 300.00, 5)
        ])

    conn.commit()
    conn.close()

class StudentRequestHandler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "*")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        # Static files (HTML, CSS, JS)
        if not path.startswith("/api/"):
            if path == "/" or path == "":
                path = "/index.html"
            local_file = os.path.join(PUBLIC_DIR, path.lstrip("/"))
            if os.path.isfile(local_file):
                mime, _ = mimetypes.guess_type(local_file)
                self.send_response(200)
                self.send_header("Content-Type", mime or "text/html")
                with open(local_file, "rb") as f:
                    self.end_headers()
                    self.wfile.write(f.read())
                return
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not Found")
                return

        conn = get_db()
        c = conn.cursor()

        # 1. Get all books (Catalog)
        if path == "/api/books":
            c.execute("SELECT * FROM BOOKS ORDER BY book_id ASC")
            books = [dict(r) for r in c.fetchall()]
            self.send_json({"status": "SUCCESS", "books": books})

        # 2. Get Cart Items for user (user_id = 1)
        elif path == "/api/cart":
            uid = 1  # Rahul Sharma (Default student user)
            c.execute("""
            SELECT c.cart_id, c.book_id, b.title, b.author, b.price, c.quantity,
                   (c.quantity * b.price) as item_total, b.stock as available_stock
            FROM CART c
            JOIN BOOKS b ON c.book_id = b.book_id
            WHERE c.user_id = ?
            """, (uid,))
            items = [dict(r) for r in c.fetchall()]
            total = sum(i["item_total"] for i in items)
            self.send_json({"status": "SUCCESS", "items": items, "cart_total": total})

        # 3. Get Orders for user
        elif path == "/api/orders":
            uid = 1
            c.execute("""
            SELECT o.*,
                   (SELECT COUNT(*) FROM ORDER_ITEMS WHERE order_id = o.order_id) as total_items
            FROM ORDERS o
            WHERE o.user_id = ?
            ORDER BY o.order_id DESC
            """, (uid,))
            orders = [dict(r) for r in c.fetchall()]
            self.send_json({"status": "SUCCESS", "orders": orders})

        # 4. Get Order Details
        elif path.startswith("/api/orders/"):
            oid = int(path.split("/")[-1])
            c.execute("""
            SELECT oi.*, b.title, b.author
            FROM ORDER_ITEMS oi
            JOIN BOOKS b ON oi.book_id = b.book_id
            WHERE oi.order_id = ?
            """, (oid,))
            items = [dict(r) for r in c.fetchall()]
            self.send_json({"status": "SUCCESS", "items": items})

        conn.close()

    def do_POST(self):
        path = urlparse(self.path).path
        content_length = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(content_length).decode("utf-8")) if content_length > 0 else {}
        conn = get_db()
        c = conn.cursor()

        # 1. Add to Cart (Procedure: add_to_cart)
        if path == "/api/cart":
            uid = 1
            bid = payload.get("book_id")
            qty = payload.get("quantity", 1)

            # Check stock
            c.execute("SELECT stock, title FROM BOOKS WHERE book_id = ?", (bid,))
            b = c.fetchone()
            if not b or b["stock"] < qty:
                self.send_json({"status": "ERROR", "message": f"Out of stock! Only {b['stock'] if b else 0} left."})
                conn.close()
                return

            c.execute("SELECT quantity FROM CART WHERE user_id = ? AND book_id = ?", (uid, bid))
            existing = c.fetchone()
            if existing:
                c.execute("UPDATE CART SET quantity = quantity + ? WHERE user_id = ? AND book_id = ?", (qty, uid, bid))
            else:
                c.execute("INSERT INTO CART (user_id, book_id, quantity) VALUES (?, ?, ?)", (uid, bid, qty))

            conn.commit()
            self.send_json({
                "status": "SUCCESS",
                "message": f'Added "{b["title"]}" to cart.',
                "plsql_log": f"EXEC add_to_cart(p_user_id => 1, p_book_id => {bid}, p_qty => {qty});"
            })

        # 2. Place Order (Procedure: place_order)
        elif path == "/api/orders":
            uid = 1
            c.execute("""
            SELECT c.book_id, c.quantity, b.price, b.stock, b.title
            FROM CART c
            JOIN BOOKS b ON c.book_id = b.book_id
            WHERE c.user_id = ?
            """, (uid,))
            cart_items = c.fetchall()

            if not cart_items:
                self.send_json({"status": "ERROR", "message": "Cart is empty."})
                conn.close()
                return

            # Check stock for all
            for it in cart_items:
                if it["stock"] < it["quantity"]:
                    self.send_json({"status": "ERROR", "message": f'Stock insufficient for "{it["title"]}"'})
                    conn.close()
                    return

            total = sum(it["price"] * it["quantity"] for it in cart_items)

            # Insert into ORDERS
            c.execute("INSERT INTO ORDERS (user_id, total_amount, order_status) VALUES (?, ?, 'PLACED')", (uid, total))
            oid = c.lastrowid

            # Insert ORDER_ITEMS & update stock
            for it in cart_items:
                c.execute("INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price) VALUES (?, ?, ?, ?)",
                          (oid, it["book_id"], it["quantity"], it["price"]))
                c.execute("UPDATE BOOKS SET stock = stock - ? WHERE book_id = ?", (it["quantity"], it["book_id"]))

            # Clear cart
            c.execute("DELETE FROM CART WHERE user_id = ?", (uid,))
            conn.commit()

            self.send_json({
                "status": "SUCCESS",
                "message": f"Order #{oid} placed successfully for Rs. {total:.2f}!",
                "plsql_log": f"EXEC place_order(p_user_id => 1); -- Order #{oid} created, stock deducted, cart cleared."
            })

        # 3. Cancel Order (Trigger: trg_restore_stock_on_cancel)
        elif path.endswith("/cancel"):
            oid = int(path.split("/")[-2])
            c.execute("SELECT order_status FROM ORDERS WHERE order_id = ?", (oid,))
            ord_row = c.fetchone()

            if not ord_row or ord_row["order_status"] == "CANCELLED":
                self.send_json({"status": "ERROR", "message": "Order already cancelled or not found."})
                conn.close()
                return

            # Trigger logic: restore stock
            c.execute("SELECT book_id, quantity FROM ORDER_ITEMS WHERE order_id = ?", (oid,))
            items = c.fetchall()
            for it in items:
                c.execute("UPDATE BOOKS SET stock = stock + ? WHERE book_id = ?", (it["quantity"], it["book_id"]))

            c.execute("UPDATE ORDERS SET order_status = 'CANCELLED' WHERE order_id = ?", (oid,))
            conn.commit()

            self.send_json({
                "status": "SUCCESS",
                "message": f"Order #{oid} cancelled. Inventory automatically restored!",
                "plsql_log": f"TRIGGER FIRED: trg_restore_stock_on_cancel on Order #{oid} -> Stock added back to BOOKS table."
            })

        # 4. Add Book (Admin)
        elif path == "/api/books":
            title = payload.get("title")
            author = payload.get("author")
            category = payload.get("category", "General")
            price = float(payload.get("price", 100))
            stock = int(payload.get("stock", 10))

            c.execute("INSERT INTO BOOKS (title, author, category, price, stock) VALUES (?, ?, ?, ?, ?)",
                      (title, author, category, price, stock))
            bid = c.lastrowid
            conn.commit()
            self.send_json({
                "status": "SUCCESS",
                "message": f'New book "{title}" added with ID #{bid}!',
                "plsql_log": f"INSERT INTO BOOKS VALUES ({bid}, '{title}', '{author}', '{category}', {price}, {stock});"
            })

        conn.close()

    def do_DELETE(self):
        path = urlparse(self.path).path
        conn = get_db()
        c = conn.cursor()

        if path.startswith("/api/cart/"):
            cart_id = int(path.split("/")[-1])
            c.execute("DELETE FROM CART WHERE cart_id = ?", (cart_id,))
            conn.commit()
            self.send_json({"status": "SUCCESS", "message": "Item removed from cart."})

        conn.close()

def main():
    init_db()
    os.makedirs(PUBLIC_DIR, exist_ok=True)
    server_address = ("127.0.0.1", PORT)
    httpd = HTTPServer(server_address, StudentRequestHandler)
    print("=" * 65)
    print("  ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL MINI PROJECT)")
    print(f"  Local Web App URL: http://localhost:{PORT}")
    print("=" * 65)
    print("Press Ctrl + C in VS Code terminal to stop the server.\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        httpd.server_close()

if __name__ == "__main__":
    main()
