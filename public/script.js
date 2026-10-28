/**
 * ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL MINI PROJECT)
 * Student-Friendly Frontend JavaScript
 */

let allBooks = [];

// Initial Load
document.addEventListener("DOMContentLoaded", () => {
  loadBooks();
  loadCart();
  loadOrders();
});

// Show Toast Alert
function showAlert(msg, isError = false) {
  const box = document.getElementById("alertBox");
  box.textContent = msg;
  box.className = isError ? "alert-box alert-error" : "alert-box";
  box.style.display = "block";
  setTimeout(() => { box.style.display = "none"; }, 3500);
}

// Log to PL/SQL Console Box (Visual demonstration for Viva)
function logPLSQL(message, type = "normal") {
  const consoleBody = document.getElementById("consoleOutput");
  const entry = document.createElement("div");
  const time = new Date().toLocaleTimeString();
  entry.className = `log-entry ${type}`;
  entry.textContent = `[${time}] ${message}`;
  consoleBody.appendChild(entry);
  consoleBody.scrollTop = consoleBody.scrollHeight;
}

function clearConsole() {
  document.getElementById("consoleOutput").innerHTML = '<div class="log-entry system">[CONSOLE CLEARED] Ready for new executions.</div>';
}

// Tab Switching
function showTab(tabName) {
  document.querySelectorAll(".tab-content").forEach(el => el.classList.remove("active"));
  document.querySelectorAll(".nav-btn").forEach(el => el.classList.remove("active"));

  if (tabName === "catalog") {
    document.getElementById("catalogTab").classList.add("active");
    document.querySelector(".nav-btn:nth-child(1)").classList.add("active");
    loadBooks();
  } else if (tabName === "cart") {
    document.getElementById("cartTab").classList.add("active");
    document.querySelector(".nav-btn:nth-child(2)").classList.add("active");
    loadCart();
  } else if (tabName === "orders") {
    document.getElementById("ordersTab").classList.add("active");
    document.querySelector(".nav-btn:nth-child(3)").classList.add("active");
    loadOrders();
  } else if (tabName === "admin") {
    document.getElementById("adminTab").classList.add("active");
    document.querySelector(".nav-btn:nth-child(4)").classList.add("active");
  }
}

// ============================================================================
// 1. BOOK CATALOG
// ============================================================================
async function loadBooks() {
  try {
    const res = await fetch("/api/books");
    const data = await res.json();
    allBooks = data.books || [];
    renderBooks(allBooks);
  } catch (err) {
    console.error("Error loading books:", err);
  }
}

function renderBooks(books) {
  const grid = document.getElementById("booksGrid");
  grid.innerHTML = "";

  if (books.length === 0) {
    grid.innerHTML = `<p style="grid-column: 1/-1; text-align: center; color: #718096; padding: 2rem;">No books found.</p>`;
    return;
  }

  books.forEach(b => {
    let stockClass = "stock-ok";
    let stockText = `${b.stock} in stock`;
    let isOutOfStock = b.stock <= 0;

    if (b.stock === 0) {
      stockClass = "stock-out";
      stockText = "Out of Stock";
    } else if (b.stock <= 5) {
      stockClass = "stock-low";
      stockText = `Low Stock (${b.stock} left)`;
    }

    const card = document.createElement("div");
    card.className = "book-card";
    card.innerHTML = `
      <div>
        <span class="book-cat">${b.category || 'General'}</span>
        <h3>${b.title}</h3>
        <p class="author">by ${b.author}</p>
      </div>
      <div>
        <div class="book-meta">
          <span class="price-tag">Rs. ${parseFloat(b.price).toFixed(2)}</span>
          <span class="stock-tag ${stockClass}">${stockText}</span>
        </div>
        <button class="btn btn-primary btn-add" onclick="addToCart(${b.book_id})" ${isOutOfStock ? 'disabled' : ''}>
          ${isOutOfStock ? 'Sold Out' : '🛒 Add to Cart'}
        </button>
      </div>
    `;
    grid.appendChild(card);
  });
}

function filterBooks(query) {
  const q = query.toLowerCase();
  const filtered = allBooks.filter(b =>
    b.title.toLowerCase().includes(q) ||
    b.author.toLowerCase().includes(q) ||
    (b.category && b.category.toLowerCase().includes(q))
  );
  renderBooks(filtered);
}

// ============================================================================
// 2. SHOPPING CART (PL/SQL Procedure: add_to_cart & Function: get_cart_total)
// ============================================================================
async function addToCart(bookId) {
  try {
    const res = await fetch("/api/cart", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ book_id: bookId, quantity: 1 })
    });
    const data = await res.json();

    if (data.status === "SUCCESS") {
      showAlert(data.message);
      logPLSQL(data.plsql_log);
      loadCart();
    } else {
      showAlert(data.message, true);
      logPLSQL(`ERROR: ${data.message}`, "trigger");
    }
  } catch (err) {
    showAlert("Failed to add to cart", true);
  }
}

async function loadCart() {
  try {
    const res = await fetch("/api/cart");
    const data = await res.json();
    const items = data.items || [];
    const total = data.cart_total || 0;

    // Update nav badge count
    const totalQty = items.reduce((sum, it) => sum + it.quantity, 0);
    document.getElementById("cartCountBadge").textContent = totalQty;

    renderCart(items, total);
  } catch (err) {
    console.error("Error loading cart:", err);
  }
}

function renderCart(items, total) {
  const tbody = document.getElementById("cartTableBody");
  const placeOrderBtn = document.getElementById("btnPlaceOrder");
  tbody.innerHTML = "";

  if (items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; padding: 2rem; color: #718096;">Your cart is empty. Add some books from the catalog!</td></tr>`;
    document.getElementById("cartGrandTotal").textContent = "Rs. 0.00";
    placeOrderBtn.disabled = true;
    return;
  }

  placeOrderBtn.disabled = false;
  items.forEach(it => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${it.title}</strong></td>
      <td>${it.author}</td>
      <td>Rs. ${parseFloat(it.price).toFixed(2)}</td>
      <td><strong>${it.quantity}</strong></td>
      <td>Rs. ${parseFloat(it.item_total).toFixed(2)}</td>
      <td>
        <button class="btn btn-danger btn-sm" onclick="removeCartItem(${it.cart_id})">Remove</button>
      </td>
    `;
    tbody.appendChild(tr);
  });

  document.getElementById("cartGrandTotal").textContent = `Rs. ${parseFloat(total).toFixed(2)}`;
}

async function removeCartItem(cartId) {
  try {
    await fetch(`/api/cart/${cartId}`, { method: "DELETE" });
    logPLSQL(`DELETE FROM CART WHERE cart_id = ${cartId};`);
    loadCart();
  } catch (err) {
    showAlert("Failed to remove item", true);
  }
}

// ============================================================================
// 3. PLACE ORDER (PL/SQL Procedure: place_order)
// ============================================================================
async function placeOrder() {
  const btn = document.getElementById("btnPlaceOrder");
  btn.disabled = true;
  btn.textContent = "Processing Transaction...";

  try {
    const res = await fetch("/api/orders", { method: "POST" });
    const data = await res.json();

    if (data.status === "SUCCESS") {
      showAlert(data.message);
      logPLSQL(data.plsql_log);
      loadCart();
      showTab("orders");
    } else {
      showAlert(data.message, true);
      logPLSQL(`TRANSACTION ROLLBACK: ${data.message}`, "trigger");
    }
  } catch (err) {
    showAlert("Order placement failed", true);
  } finally {
    btn.disabled = false;
    btn.textContent = "🚀 Place Order (Calls PL/SQL place_order)";
  }
}

// ============================================================================
// 4. MY ORDERS (PL/SQL Trigger Demo: trg_restore_stock_on_cancel)
// ============================================================================
async function loadOrders() {
  try {
    const res = await fetch("/api/orders");
    const data = await res.json();
    const orders = data.orders || [];
    renderOrders(orders);
  } catch (err) {
    console.error("Error loading orders:", err);
  }
}

function renderOrders(orders) {
  const tbody = document.getElementById("ordersTableBody");
  tbody.innerHTML = "";

  if (orders.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align:center; padding: 2rem; color: #718096;">No orders placed yet.</td></tr>`;
    return;
  }

  orders.forEach(o => {
    const isCancelled = o.order_status === "CANCELLED";
    const statusBadge = isCancelled ?
      `<span class="badge-cancelled">CANCELLED</span>` :
      `<span class="badge-placed">PLACED</span>`;

    const cancelBtn = isCancelled ?
      `<span style="color: #718096; font-size: 0.8rem;">Stock Restored</span>` :
      `<button class="btn btn-danger btn-sm" onclick="cancelOrder(${o.order_id})">Cancel Order (Test Trigger)</button>`;

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>#${o.order_id}</strong></td>
      <td>${new Date(o.order_date).toLocaleString()}</td>
      <td><strong>Rs. ${parseFloat(o.total_amount).toFixed(2)}</strong></td>
      <td>${statusBadge}</td>
      <td>${cancelBtn}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function cancelOrder(orderId) {
  if (!confirm(`Cancel Order #${orderId}? This will test the PL/SQL Trigger that restores stock automatically.`)) return;

  try {
    const res = await fetch(`/api/orders/${orderId}/cancel`, { method: "POST" });
    const data = await res.json();

    if (data.status === "SUCCESS") {
      showAlert(data.message);
      logPLSQL(data.plsql_log, "trigger");
      loadOrders();
      loadBooks(); // refresh stock on catalog
    } else {
      showAlert(data.message, true);
    }
  } catch (err) {
    showAlert("Failed to cancel order", true);
  }
}

// ============================================================================
// 5. ADMIN: ADD NEW BOOK
// ============================================================================
async function handleNewBook(event) {
  event.preventDefault();
  const title = document.getElementById("newTitle").value.trim();
  const author = document.getElementById("newAuthor").value.trim();
  const category = document.getElementById("newCategory").value;
  const price = parseFloat(document.getElementById("newPrice").value);
  const stock = parseInt(document.getElementById("newStock").value);

  try {
    const res = await fetch("/api/books", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, author, category, price, stock })
    });
    const data = await res.json();

    if (data.status === "SUCCESS") {
      showAlert(data.message);
      logPLSQL(data.plsql_log);
      event.target.reset();
      showTab("catalog");
    } else {
      showAlert(data.message, true);
    }
  } catch (err) {
    showAlert("Failed to add book", true);
  }
}
