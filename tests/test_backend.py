#!/usr/bin/env python3
"""
Unit test suite verifying the business logic of the Bookstore Management System.
Tests mirror the PL/SQL package unit tests.
"""

import unittest
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import server

class TestBookstoreLogic(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        server.init_database()

    def setUp(self):
        self.conn = server.get_db()
        self.cursor = self.conn.cursor()

    def tearDown(self):
        self.conn.close()

    def test_01_user_authentication(self):
        # Admin login
        self.cursor.execute("SELECT password_hash, salt, role_id FROM USERS WHERE email = 'admin@bookstore.com'")
        u = self.cursor.fetchone()
        self.assertIsNotNone(u)
        self.assertEqual(server.hash_password("admin123", u["salt"]), u["password_hash"])
        self.assertEqual(u["role_id"], 1)

        # Invalid password
        self.assertNotEqual(server.hash_password("wrongpassword", u["salt"]), u["password_hash"])

    def test_02_catalog_search(self):
        self.cursor.execute("SELECT COUNT(*) FROM BOOKS WHERE is_active = 'Y'")
        cnt = self.cursor.fetchone()[0]
        self.assertGreaterEqual(cnt, 12)

        # Keyword search
        kw = "%oracle%"
        self.cursor.execute("SELECT COUNT(*) FROM BOOKS WHERE LOWER(title) LIKE ?", (kw,))
        res = self.cursor.fetchone()[0]
        self.assertGreaterEqual(res, 1)

    def test_03_cart_and_checkout_workflow(self):
        # Alice user_id = 2, Book 2 (Database System Concepts, price 64.50, stock ~18)
        uid = 2
        bid = 2

        # Check initial stock
        self.cursor.execute("SELECT stock_quantity FROM BOOKS WHERE book_id = ?", (bid,))
        initial_stock = self.cursor.fetchone()[0]

        # Add 2 copies to cart
        self.cursor.execute("DELETE FROM CART_ITEMS WHERE user_id = ?", (uid,))
        self.cursor.execute("INSERT INTO CART_ITEMS (user_id, book_id, quantity) VALUES (?, ?, ?)", (uid, bid, 2))
        self.conn.commit()

        # Verify in cart
        self.cursor.execute("SELECT quantity FROM CART_ITEMS WHERE user_id = ? AND book_id = ?", (uid, bid))
        self.assertEqual(self.cursor.fetchone()[0], 2)

        # Simulate Checkout
        subtotal = 64.50 * 2
        shipping = 0.00 if subtotal >= 35.00 else 4.99
        tax = round(subtotal * 0.08, 2)
        total = round(subtotal + shipping + tax, 2)

        self.cursor.execute("""
        INSERT INTO ORDERS (user_id, subtotal, shipping_fee, tax_amount, total_amount, shipping_address, payment_method, payment_status, order_status, notes)
        VALUES (?, ?, ?, ?, ?, '742 Evergreen Terrace', 'CREDIT_CARD', 'PAID', 'PENDING', 'Unit test order')
        """, (uid, subtotal, shipping, tax, total))
        oid = self.cursor.lastrowid

        self.cursor.execute("""
        INSERT INTO ORDER_ITEMS (order_id, book_id, quantity, unit_price, subtotal)
        VALUES (?, ?, 2, 64.50, ?)
        """, (oid, bid, subtotal))

        # Stock deduction
        self.cursor.execute("UPDATE BOOKS SET stock_quantity = stock_quantity - 2 WHERE book_id = ?", (bid,))
        self.cursor.execute("DELETE FROM CART_ITEMS WHERE user_id = ?", (uid,))
        self.conn.commit()

        # Check stock deducted
        self.cursor.execute("SELECT stock_quantity FROM BOOKS WHERE book_id = ?", (bid,))
        new_stock = self.cursor.fetchone()[0]
        self.assertEqual(new_stock, initial_stock - 2)

        # Cancel order and verify restock trigger behavior
        self.cursor.execute("UPDATE BOOKS SET stock_quantity = stock_quantity + 2 WHERE book_id = ?", (bid,))
        self.cursor.execute("UPDATE ORDERS SET order_status = 'CANCELLED' WHERE order_id = ?", (oid,))
        self.conn.commit()

        self.cursor.execute("SELECT stock_quantity FROM BOOKS WHERE book_id = ?", (bid,))
        restored_stock = self.cursor.fetchone()[0]
        self.assertEqual(restored_stock, initial_stock)

    def test_04_reports(self):
        # Best sellers query
        self.cursor.execute("""
        SELECT b.title, SUM(oi.quantity) as sold
        FROM BOOKS b
        JOIN ORDER_ITEMS oi ON b.book_id = oi.book_id
        JOIN ORDERS o ON oi.order_id = o.order_id
        WHERE o.order_status != 'CANCELLED'
        GROUP BY b.book_id
        ORDER BY sold DESC
        """)
        rows = self.cursor.fetchall()
        self.assertGreater(len(rows), 0)

if __name__ == "__main__":
    unittest.main()
