/**
 * ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL ENGINE)
 * Front-end Client Controller
 */

// Application State
const state = {
  currentUser: {
    user_id: 2,
    full_name: "Alice Johnson",
    email: "alice@example.com",
    role: "CUSTOMER"
  },
  categories: [],
  books: [],
  selectedCategory: null,
  searchKeyword: "",
  inStockOnly: false,
  cart: {
    items: [],
    item_count: 0,
    subtotal: 0,
    shipping: 0,
    tax: 0,
    total: 0
  },
  currentTab: "catalog",
  adminTab: "inventory"
};

// --------------------------------------------------------------------------
// API Client Helper
// --------------------------------------------------------------------------
async function api(endpoint, method = "GET", data = null) {
  const options = {
    method,
    headers: {
      "Content-Type": "application/json",
      "X-User-Id": state.currentUser ? String(state.currentUser.user_id) : ""
    }
  };

  if (data && method !== "GET") {
    options.body = JSON.stringify(data);
  }

  try {
    const res = await fetch(endpoint, options);
    const json = await res.json();
    if (!res.ok && json.status === "ERROR") {
      throw new Error(json.message || "Request failed");
    }
    return json;
  } catch (err) {
    showToast(err.message, "error");
    throw err;
  }
}

// --------------------------------------------------------------------------
// Initialization
// --------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", async () => {
  updateUserUI();
  await loadCategories();
  await loadBooks();
  await loadCart();
});

function showToast(msg, type = "success") {
  const container = document.getElementById("toastContainer");
  const el = document.createElement("div");
  el.className = `toast toast-${type}`;
  el.innerHTML = `<span>${type === "error" ? "⚠️" : "✅"}</span> <span>${msg}</span>`;
  container.appendChild(el);
  setTimeout(() => {
    el.style.opacity = "0";
    setTimeout(() => el.remove(), 300);
  }, 3500);
}

// --------------------------------------------------------------------------
// Authentication & Quick Switcher
// --------------------------------------------------------------------------
async function quickLogin(userKey) {
  let email, pwd;
  if (userKey === "admin") {
    email = "admin@bookstore.com";
    pwd = "admin123";
  } else if (userKey === "bob") {
    email = "bob@example.com";
    pwd = "bob123";
  } else {
    email = "alice@example.com";
    pwd = "alice123";
  }

  try {
    const res = await api("/api/auth/login", "POST", { email, password: pwd });
    state.currentUser = res.data;
    updateUserUI();
    showToast(`Logged in as ${res.data.full_name} (${res.data.role})`);

    // Update active quickswitch pill
    document.querySelectorAll(".demo-role-quickswitch .pill-btn").forEach(btn => btn.classList.remove("active"));
    const selector = userKey === "admin" ? ".pill-btn.admin" : (userKey === "bob" ? ".pill-btn:nth-child(3)" : ".pill-btn:nth-child(2)");
    const activeBtn = document.querySelector(selector);
    if (activeBtn) activeBtn.classList.add("active");

    await loadCart();
    if (state.currentTab === "orders") {
      loadUserOrders();
    } else if (state.currentTab === "admin") {
      refreshAdminData();
    }
  } catch (e) {
    console.error(e);
  }
}

function updateUserUI() {
  const u = state.currentUser;
  const adminNav = document.getElementById("navAdminBtn");
  const navUserName = document.getElementById("navUserName");
  const navUserRole = document.getElementById("navUserRole");
  const userAvatar = document.getElementById("userAvatar");

  if (!u) {
    navUserName.textContent = "Sign In";
    navUserRole.textContent = "GUEST";
    userAvatar.textContent = "?";
    adminNav.style.display = "none";
    return;
  }

  navUserName.textContent = u.full_name;
  navUserRole.textContent = u.role;
  userAvatar.textContent = u.full_name.charAt(0).toUpperCase();

  if (u.role === "ADMIN") {
    adminNav.style.display = "inline-block";
  } else {
    adminNav.style.display = "none";
    if (state.currentTab === "admin") {
      switchTab("catalog");
    }
  }
}

function logout() {
  state.currentUser = null;
  updateUserUI();
  showToast("Logged out successfully");
  switchTab("catalog");
}

// --------------------------------------------------------------------------
// Tab Navigation
// --------------------------------------------------------------------------
function switchTab(tabName) {
  state.currentTab = tabName;
  document.querySelectorAll(".view-section").forEach(s => s.classList.remove("active"));
  document.querySelectorAll(".nav-link").forEach(l => l.classList.remove("active"));

  if (tabName === "catalog") {
    document.getElementById("catalogView").classList.add("active");
    document.getElementById("navCatalogBtn").classList.add("active");
  } else if (tabName === "orders") {
    document.getElementById("ordersView").classList.add("active");
    document.getElementById("navOrdersBtn").classList.add("active");
    loadUserOrders();
  } else if (tabName === "admin") {
    document.getElementById("adminView").classList.add("active");
    document.getElementById("navAdminBtn").classList.add("active");
    refreshAdminData();
  }
}

// --------------------------------------------------------------------------
// Catalog & Categories
// --------------------------------------------------------------------------
async function loadCategories() {
  try {
    const res = await api("/api/categories");
    state.categories = res.data;
    renderCategories();
  } catch (e) {
    console.error(e);
  }
}

function renderCategories() {
  const container = document.getElementById("categoryPillList");
  const editSelect = document.getElementById("editBookCategory");

  container.innerHTML = `<button class="cat-pill ${state.selectedCategory === null ? 'active' : ''}" onclick="filterByCategory(null)">All Categories</button>`;
  editSelect.innerHTML = `<option value="">Select a category</option>`;

  state.categories.forEach(cat => {
    const pill = document.createElement("button");
    pill.className = `cat-pill ${state.selectedCategory === cat.category_id ? 'active' : ''}`;
    pill.textContent = cat.category_name;
    pill.onclick = () => filterByCategory(cat.category_id);
    container.appendChild(pill);

    const opt = document.createElement("option");
    opt.value = cat.category_id;
    opt.textContent = cat.category_name;
    editSelect.appendChild(opt);
  });
}

function filterByCategory(catId) {
  state.selectedCategory = catId;
  renderCategories();
  loadBooks();
}

function handleSearch(val) {
  state.searchKeyword = val;
  const clearBtn = document.getElementById("clearSearchBtn");
  clearBtn.style.display = val ? "inline-block" : "none";
  loadBooks();
}

function clearSearch() {
  document.getElementById("searchInput").value = "";
  handleSearch("");
}

function toggleInStockFilter(val) {
  state.inStockOnly = val;
  loadBooks();
}

async function loadBooks() {
  let url = `/api/books?`;
  if (state.searchKeyword) url += `&keyword=${encodeURIComponent(state.searchKeyword)}`;
  if (state.selectedCategory) url += `&category_id=${state.selectedCategory}`;
  if (state.inStockOnly) url += `&in_stock_only=Y`;

  try {
    const res = await api(url);
    state.books = res.data;
    renderBooks();
    document.getElementById("heroBookCount").textContent = state.books.length;
  } catch (e) {
    console.error(e);
  }
}

function renderBooks() {
  const grid = document.getElementById("bookGrid");
  grid.innerHTML = "";

  if (state.books.length === 0) {
    grid.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 4rem 1rem; color: #64748b;">
        <span style="font-size: 3rem;">🔍</span>
        <h3 style="margin-top: 0.5rem;">No books found matching your criteria</h3>
        <p style="font-size: 0.9rem;">Try loosening your search terms or resetting filters.</p>
      </div>
    `;
    return;
  }

  state.books.forEach(book => {
    let stockClass = "stock-in";
    let stockText = `${book.stock_quantity} In Stock`;
    if (book.stock_quantity === 0) {
      stockClass = "stock-out";
      stockText = "Out of Stock";
    } else if (book.stock_quantity <= 5) {
      stockClass = "stock-low";
      stockText = `Only ${book.stock_quantity} left`;
    }

    const card = document.createElement("div");
    card.className = "book-card";
    card.innerHTML = `
      <div class="book-cover-wrap" onclick="viewBookDetails(${book.book_id})">
        <img class="book-cover" src="${book.cover_image || 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600'}" alt="${book.title}" loading="lazy">
        <span class="book-cat-tag">${book.category_name}</span>
        <span class="book-stock-tag ${stockClass}">${stockText}</span>
      </div>
      <div class="book-details">
        <h3 class="book-title" onclick="viewBookDetails(${book.book_id})">${book.title}</h3>
        <span class="book-author">by ${book.author}</span>
        <p class="book-desc-clamp">${book.description || 'No description provided.'}</p>
        <div class="book-footer">
          <span class="book-price">$${parseFloat(book.price).toFixed(2)}</span>
          <button class="btn-add-cart" onclick="addToCart(${book.book_id})" ${book.stock_quantity === 0 ? 'disabled' : ''}>
            <span>🛒</span> ${book.stock_quantity === 0 ? 'Out of Stock' : 'Add to Cart'}
          </button>
        </div>
      </div>
    `;
    grid.appendChild(card);
  });
}

// --------------------------------------------------------------------------
// Book Details Modal
// --------------------------------------------------------------------------
async function viewBookDetails(bookId) {
  try {
    const res = await api(`/api/books/${bookId}`);
    const b = res.data;
    document.getElementById("modalBookTitle").textContent = b.title;

    let stockTag = `<span class="book-stock-tag stock-in">${b.stock_quantity} in stock</span>`;
    if (b.stock_quantity === 0) {
      stockTag = `<span class="book-stock-tag stock-out">Out of stock</span>`;
    } else if (b.stock_quantity <= 5) {
      stockTag = `<span class="book-stock-tag stock-low">Low stock (${b.stock_quantity} remaining)</span>`;
    }

    document.getElementById("modalBookContent").innerHTML = `
      <div style="display: flex; gap: 1.5rem; flex-wrap: wrap;">
        <img src="${b.cover_image}" alt="${b.title}" style="width: 160px; height: 230px; object-fit: cover; border-radius: 8px; box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);">
        <div style="flex: 1; min-width: 260px;">
          <h2 style="font-family: var(--font-serif); font-size: 1.5rem; line-height: 1.2;">${b.title}</h2>
          <p style="color: #64748b; font-size: 0.95rem; margin: 0.25rem 0 0.75rem;">by <strong>${b.author}</strong></p>
          <div style="display: flex; gap: 0.5rem; align-items: center; margin-bottom: 1rem;">
            <span class="badge" style="background:#e0e7ff; color:#4338ca; padding:0.25rem 0.6rem; border-radius:99px; font-size:0.75rem; font-weight:700;">${b.category_name}</span>
            <span style="font-size:0.8rem; color:#64748b;">ISBN: <strong>${b.isbn}</strong></span>
            <span style="font-size:0.8rem; color:#64748b;">Year: ${b.publication_year || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 1rem;">
            ${stockTag}
          </div>
          <p style="font-size: 0.9rem; color: #334155; line-height: 1.6; margin-bottom: 1.5rem;">${b.description || 'No detailed overview provided.'}</p>
          <div style="display: flex; align-items: center; justify-content: space-between; border-top: 1px solid #e2e8f0; padding-top: 1rem;">
            <span style="font-size: 1.75rem; font-weight: 800; color: var(--primary);">$${parseFloat(b.price).toFixed(2)}</span>
            <button class="btn btn-primary" onclick="addToCart(${b.book_id}); closeBookDetailsModal();" ${b.stock_quantity === 0 ? 'disabled' : ''}>
              🛒 Add to Shopping Cart
            </button>
          </div>
        </div>
      </div>
    `;

    document.getElementById("bookDetailsModal").classList.add("active");
  } catch (e) {
    console.error(e);
  }
}

function closeBookDetailsModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("bookDetailsModal").classList.remove("active");
}

// --------------------------------------------------------------------------
// Shopping Cart Operations (CART_MGMT_PKG)
// --------------------------------------------------------------------------
async function loadCart() {
  if (!state.currentUser) {
    document.getElementById("cartBadgeCount").textContent = "0";
    return;
  }

  try {
    const res = await api("/api/cart");
    state.cart = res.data;
    document.getElementById("cartBadgeCount").textContent = state.cart.item_count;
    renderCart();
  } catch (e) {
    console.error(e);
  }
}

function renderCart() {
  const container = document.getElementById("cartItemsList");
  container.innerHTML = "";

  if (!state.cart.items || state.cart.items.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 3rem 1rem; color: #64748b;">
        <span style="font-size: 3rem;">🛒</span>
        <h4 style="margin-top: 0.5rem;">Your cart is empty</h4>
        <p style="font-size: 0.85rem; margin-top: 0.25rem;">Explore our catalog to add books.</p>
      </div>
    `;
    document.getElementById("checkoutBtn").disabled = true;
  } else {
    document.getElementById("checkoutBtn").disabled = false;
    state.cart.items.forEach(item => {
      const el = document.createElement("div");
      el.className = "cart-item";
      el.innerHTML = `
        <img class="cart-thumb" src="${item.cover_image || 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600'}" alt="${item.title}">
        <div class="cart-info">
          <h4 class="cart-title">${item.title}</h4>
          <span class="cart-price">$${parseFloat(item.price).toFixed(2)} each</span>
          <div class="qty-control">
            <button class="qty-btn" onclick="updateCartItemQty(${item.book_id}, ${item.quantity - 1})">-</button>
            <span class="qty-val">${item.quantity}</span>
            <button class="qty-btn" onclick="updateCartItemQty(${item.book_id}, ${item.quantity + 1})" ${item.quantity >= item.available_stock ? 'disabled' : ''}>+</button>
            <button class="btn btn-sm btn-danger" style="margin-left: auto;" onclick="removeCartItem(${item.book_id})">🗑️</button>
          </div>
        </div>
      `;
      container.appendChild(el);
    });
  }

  document.getElementById("cartSubtotal").textContent = `$${state.cart.subtotal.toFixed(2)}`;
  document.getElementById("cartShipping").textContent = state.cart.shipping === 0 ? "FREE" : `$${state.cart.shipping.toFixed(2)}`;
  document.getElementById("cartTax").textContent = `$${state.cart.tax.toFixed(2)}`;
  document.getElementById("cartGrandTotal").textContent = `$${state.cart.total.toFixed(2)}`;
}

async function addToCart(bookId) {
  if (!state.currentUser) {
    showToast("Please sign in or use Quick Switcher to add books to cart.", "error");
    return;
  }

  try {
    const res = await api("/api/cart", "POST", { book_id: bookId, quantity: 1 });
    showToast(res.message);
    await loadCart();
  } catch (e) {
    console.error(e);
  }
}

async function updateCartItemQty(bookId, newQty) {
  try {
    const res = await api(`/api/cart/${bookId}`, "PUT", { quantity: newQty });
    showToast(res.message);
    await loadCart();
  } catch (e) {
    console.error(e);
  }
}

async function removeCartItem(bookId) {
  try {
    const res = await api(`/api/cart/${bookId}`, "DELETE");
    showToast(res.message);
    await loadCart();
  } catch (e) {
    console.error(e);
  }
}

async function clearCart() {
  if (!confirm("Are you sure you want to empty your shopping cart?")) return;
  try {
    const res = await api("/api/cart", "DELETE");
    showToast(res.message);
    await loadCart();
  } catch (e) {
    console.error(e);
  }
}

function openCartModal() {
  document.getElementById("cartModal").classList.add("active");
}

function closeCartModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("cartModal").classList.remove("active");
}

// --------------------------------------------------------------------------
// Checkout Operations (ORDER_MGMT_PKG.place_order_from_cart)
// --------------------------------------------------------------------------
function openCheckoutModal() {
  if (state.cart.item_count === 0) {
    showToast("Your cart is empty.", "error");
    return;
  }

  closeCartModal();
  document.getElementById("checkoutFinalTotal").textContent = `$${state.cart.total.toFixed(2)}`;

  // Pre-fill user address if available
  api("/api/auth/profile").then(res => {
    if (res.data && res.data.shipping_address) {
      document.getElementById("checkoutAddress").value = res.data.shipping_address;
    }
  }).catch(() => {});

  document.getElementById("checkoutModal").classList.add("active");
}

function closeCheckoutModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("checkoutModal").classList.remove("active");
}

async function handleCheckout(event) {
  event.preventDefault();
  const address = document.getElementById("checkoutAddress").value.trim();
  const paymentMethod = document.getElementById("checkoutPaymentMethod").value;
  const notes = document.getElementById("checkoutNotes").value.trim();

  const submitBtn = document.getElementById("placeOrderSubmitBtn");
  submitBtn.disabled = true;
  submitBtn.textContent = "Processing Transaction...";

  try {
    const res = await api("/api/orders", "POST", {
      shipping_address: address,
      payment_method: paymentMethod,
      notes: notes
    });

    showToast(res.message, "success");
    closeCheckoutModal();
    await loadCart();
    await loadBooks(); // Refresh book inventory levels

    // Automatically switch to orders tab to show confirmation
    switchTab("orders");
  } catch (e) {
    console.error(e);
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Place Order Now";
  }
}

// --------------------------------------------------------------------------
// Order Management (User Orders & Admin View)
// --------------------------------------------------------------------------
async function loadUserOrders() {
  const container = document.getElementById("userOrdersList");
  container.innerHTML = `<div style="text-align:center; padding: 2rem;">Loading your orders...</div>`;

  try {
    const res = await api("/api/orders");
    const orders = res.data;

    if (orders.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 4rem 1rem; color: #64748b; background: #fff; border-radius: 8px;">
          <span style="font-size: 3rem;">📦</span>
          <h3 style="margin-top: 0.5rem;">No orders placed yet</h3>
          <p style="font-size: 0.85rem;">When you purchase books, your order status and receipts appear here.</p>
        </div>
      `;
      return;
    }

    container.innerHTML = "";
    orders.forEach(o => {
      let statusClass = `status-${o.order_status.toLowerCase()}`;
      const card = document.createElement("div");
      card.className = "order-card";
      card.innerHTML = `
        <div class="order-top">
          <div>
            <span class="order-id-label">Order #${o.order_id}</span>
            <span class="order-date"> • Placed on ${new Date(o.order_date).toLocaleString()}</span>
          </div>
          <span class="status-badge ${statusClass}">${o.order_status}</span>
        </div>
        <div class="order-body-meta">
          <div class="order-info-col">
            <span>Delivery Destination:</span>
            <strong>${o.shipping_address}</strong>
          </div>
          <div class="order-info-col">
            <span>Payment Method:</span>
            <strong>${o.payment_method} (${o.payment_status})</strong>
          </div>
          <div class="order-info-col">
            <span>Total Units:</span>
            <strong>${o.total_units || 0} books (${o.total_items || 0} titles)</strong>
          </div>
          <div class="order-info-col">
            <span>Total Amount:</span>
            <strong style="color: var(--primary); font-size: 1.15rem;">$${parseFloat(o.total_amount).toFixed(2)}</strong>
          </div>
          <div class="order-actions">
            <button class="btn btn-secondary btn-sm" onclick="viewOrderDetailsModal(${o.order_id})">Receipt / Items</button>
            ${['PENDING', 'PROCESSING'].includes(o.order_status) ?
              `<button class="btn btn-danger btn-sm" onclick="cancelOrder(${o.order_id})">Cancel Order</button>` : ''}
          </div>
        </div>
      `;
      container.appendChild(card);
    });
  } catch (e) {
    console.error(e);
  }
}

async function cancelOrder(orderId) {
  if (!confirm(`Are you sure you want to cancel Order #${orderId}? Inventory will be automatically restored.`)) return;
  try {
    const res = await api(`/api/orders/${orderId}/cancel`, "POST");
    showToast(res.message);
    await loadUserOrders();
    await loadBooks();
  } catch (e) {
    console.error(e);
  }
}

async function viewOrderDetailsModal(orderId) {
  try {
    const res = await api(`/api/orders/${orderId}`);
    const { order, items } = res.data;

    document.getElementById("odTitle").textContent = `Order #${order.order_id} Receipt`;
    let itemsHtml = items.map(it => `
      <div style="display:flex; justify-content:space-between; align-items:center; padding: 0.6rem 0; border-bottom: 1px solid #e2e8f0;">
        <div style="display:flex; align-items:center; gap: 0.75rem;">
          <img src="${it.cover_image}" style="width:40px; height:55px; object-fit:cover; border-radius:4px;">
          <div>
            <strong style="font-size:0.875rem;">${it.title}</strong>
            <div style="font-size:0.75rem; color:#64748b;">Qty: ${it.quantity} &times; $${parseFloat(it.unit_price).toFixed(2)}</div>
          </div>
        </div>
        <strong style="font-size:0.9rem;">$${parseFloat(it.subtotal).toFixed(2)}</strong>
      </div>
    `).join("");

    document.getElementById("odContent").innerHTML = `
      <div style="margin-bottom: 1rem;">
        <p style="font-size:0.85rem; color:#64748b;">Customer: <strong>${order.full_name} (${order.email})</strong></p>
        <p style="font-size:0.85rem; color:#64748b;">Date: ${new Date(order.order_date).toLocaleString()}</p>
        <p style="font-size:0.85rem; color:#64748b;">Status: <span class="status-badge status-${order.order_status.toLowerCase()}">${order.order_status}</span></p>
      </div>
      <div style="margin-bottom: 1rem;">
        <h4 style="font-size:0.9rem; margin-bottom: 0.5rem; text-transform:uppercase; color:#64748b; letter-spacing:0.05em;">Purchased Items</h4>
        ${itemsHtml}
      </div>
      <div style="background:#f8fafc; padding: 1rem; border-radius:6px; font-size:0.875rem;">
        <div style="display:flex; justify-content:space-between; margin-bottom:0.25rem;"><span>Subtotal:</span><span>$${parseFloat(order.subtotal).toFixed(2)}</span></div>
        <div style="display:flex; justify-content:space-between; margin-bottom:0.25rem;"><span>Shipping:</span><span>$${parseFloat(order.shipping_fee).toFixed(2)}</span></div>
        <div style="display:flex; justify-content:space-between; margin-bottom:0.4rem;"><span>Estimated Tax:</span><span>$${parseFloat(order.tax_amount).toFixed(2)}</span></div>
        <div style="display:flex; justify-content:space-between; font-weight:800; font-size:1.1rem; border-top:1px dashed #cbd5e1; padding-top:0.4rem;"><span>Grand Total:</span><span style="color:var(--primary);">$${parseFloat(order.total_amount).toFixed(2)}</span></div>
      </div>
    `;

    document.getElementById("orderDetailsModal").classList.add("active");
  } catch (e) {
    console.error(e);
  }
}

function closeOrderDetailsModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("orderDetailsModal").classList.remove("active");
}

// --------------------------------------------------------------------------
// Admin Dashboard Controller
// --------------------------------------------------------------------------
function switchAdminTab(subtab) {
  state.adminTab = subtab;
  document.querySelectorAll(".subtab-btn").forEach(b => b.classList.remove("active"));
  document.querySelectorAll(".admin-panel").forEach(p => p.classList.remove("active"));

  if (subtab === "inventory") {
    document.querySelector(".subtab-btn:nth-child(1)").classList.add("active");
    document.getElementById("adminInventoryPanel").classList.add("active");
    loadAdminInventory();
  } else if (subtab === "fulfillment") {
    document.querySelector(".subtab-btn:nth-child(2)").classList.add("active");
    document.getElementById("adminFulfillmentPanel").classList.add("active");
    loadAdminOrders();
  } else if (subtab === "reports") {
    document.querySelector(".subtab-btn:nth-child(3)").classList.add("active");
    document.getElementById("adminReportsPanel").classList.add("active");
    loadBestSellers();
    loadCategoryPerformance();
    loadLowStock();
  } else if (subtab === "audit") {
    document.querySelector(".subtab-btn:nth-child(4)").classList.add("active");
    document.getElementById("adminAuditPanel").classList.add("active");
    loadAuditLogs();
  }
}

async function refreshAdminData() {
  await loadKPIs();
  switchAdminTab(state.adminTab);
}

async function loadKPIs() {
  try {
    const res = await api("/api/reports/kpis");
    const kpi = res.data;
    document.getElementById("kpiRevenue").textContent = `$${kpi.total_revenue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    document.getElementById("kpiOrders").textContent = kpi.total_orders;
    document.getElementById("kpiBooksSold").textContent = kpi.total_books_sold;
    document.getElementById("kpiLowStock").textContent = kpi.low_stock_count;
  } catch (e) {
    console.error(e);
  }
}

async function loadAdminInventory() {
  const tbody = document.getElementById("adminInventoryTableBody");
  tbody.innerHTML = `<tr><td colspan="7" style="text-align:center;">Loading catalog...</td></tr>`;

  try {
    const res = await api("/api/books");
    const books = res.data;
    tbody.innerHTML = "";

    books.forEach(b => {
      let stockColor = b.stock_quantity === 0 ? "var(--danger)" : (b.stock_quantity <= 10 ? "var(--warning)" : "var(--success)");
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><strong>#${b.book_id}</strong></td>
        <td>
          <div style="font-weight:700;">${b.title}</div>
          <div style="font-size:0.75rem; color:#64748b;">${b.author} • ISBN: ${b.isbn}</div>
        </td>
        <td><span class="badge" style="background:#f1f5f9; padding:0.2rem 0.5rem; border-radius:4px; font-size:0.75rem;">${b.category_name}</span></td>
        <td><strong>$${parseFloat(b.price).toFixed(2)}</strong></td>
        <td><strong style="color: ${stockColor}; font-size: 1rem;">${b.stock_quantity}</strong> units</td>
        <td><span class="badge" style="background:#d1fae5; color:#065f46; padding:0.2rem 0.5rem; border-radius:4px; font-size:0.75rem;">ACTIVE</span></td>
        <td>
          <button class="btn btn-secondary btn-sm" onclick="openEditBookModal(${b.book_id})">Edit</button>
          <button class="btn btn-danger btn-sm" onclick="deactivateBook(${b.book_id})">Deactivate</button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadAdminOrders() {
  const tbody = document.getElementById("adminOrdersTableBody");
  tbody.innerHTML = `<tr><td colspan="7" style="text-align:center;">Loading orders...</td></tr>`;

  try {
    const res = await api("/api/orders?admin=1");
    const orders = res.data;
    tbody.innerHTML = "";

    orders.forEach(o => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><strong>#${o.order_id}</strong></td>
        <td>
          <div style="font-weight:600;">${o.customer_name}</div>
          <div style="font-size:0.75rem; color:#64748b;">${o.customer_email}</div>
        </td>
        <td>${new Date(o.order_date).toLocaleDateString()}</td>
        <td>${o.total_units || 0} books</td>
        <td><strong>$${parseFloat(o.total_amount).toFixed(2)}</strong></td>
        <td>
          <select style="padding: 0.3rem 0.5rem; font-size: 0.8rem; border-radius: 4px; border: 1px solid #cbd5e1;"
                  onchange="updateOrderStatus(${o.order_id}, this.value)" ${o.order_status === 'CANCELLED' ? 'disabled' : ''}>
            <option value="PENDING" ${o.order_status === 'PENDING' ? 'selected' : ''}>PENDING</option>
            <option value="PROCESSING" ${o.order_status === 'PROCESSING' ? 'selected' : ''}>PROCESSING</option>
            <option value="SHIPPED" ${o.order_status === 'SHIPPED' ? 'selected' : ''}>SHIPPED</option>
            <option value="DELIVERED" ${o.order_status === 'DELIVERED' ? 'selected' : ''}>DELIVERED</option>
            <option value="CANCELLED" ${o.order_status === 'CANCELLED' ? 'selected' : ''}>CANCELLED</option>
          </select>
        </td>
        <td>
          <button class="btn btn-secondary btn-sm" onclick="viewOrderDetailsModal(${o.order_id})">Inspect</button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error(e);
  }
}

async function updateOrderStatus(orderId, newStatus) {
  try {
    const res = await api(`/api/orders/${orderId}/status`, "PUT", { order_status: newStatus });
    showToast(res.message);
    await refreshAdminData();
  } catch (e) {
    console.error(e);
  }
}

async function loadBestSellers() {
  const container = document.getElementById("bestSellersReportList");
  try {
    const res = await api("/api/reports/best-sellers");
    container.innerHTML = "";
    res.data.forEach((b, idx) => {
      const el = document.createElement("div");
      el.className = "leader-item";
      el.innerHTML = `
        <div style="display:flex; align-items:center; gap: 0.75rem;">
          <span style="font-size:1.1rem; font-weight:800; color:#94a3b8; width: 20px;">#${idx+1}</span>
          <div>
            <div class="leader-title">${b.title}</div>
            <div class="leader-sub">${b.category_name} • $${parseFloat(b.price).toFixed(2)}</div>
          </div>
        </div>
        <div class="leader-stat">
          <strong>$${parseFloat(b.total_revenue).toFixed(2)}</strong>
          <small>${b.total_units_sold} copies sold</small>
        </div>
      `;
      container.appendChild(el);
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadCategoryPerformance() {
  const container = document.getElementById("categoryPerformanceList");
  try {
    const res = await api("/api/reports/category-performance");
    container.innerHTML = "";
    res.data.forEach(c => {
      const el = document.createElement("div");
      el.className = "leader-item";
      el.innerHTML = `
        <div>
          <div class="leader-title">${c.category_name}</div>
          <div class="leader-sub">${c.total_titles} titles in catalog</div>
        </div>
        <div class="leader-stat">
          <strong>$${parseFloat(c.total_revenue).toFixed(2)}</strong>
          <small>${c.units_sold} books sold</small>
        </div>
      `;
      container.appendChild(el);
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadLowStock() {
  const tbody = document.getElementById("lowStockTableBody");
  try {
    const res = await api("/api/reports/low-stock");
    tbody.innerHTML = "";
    if (res.data.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center; color:#059669;">All titles maintain healthy stock levels (&gt; 10 units).</td></tr>`;
      return;
    }
    res.data.forEach(b => {
      const isOut = b.stock_quantity === 0;
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>#${b.book_id}</td>
        <td><code>${b.isbn}</code></td>
        <td><strong>${b.title}</strong></td>
        <td>${b.category_name}</td>
        <td><strong style="color: ${isOut ? 'var(--danger)' : 'var(--warning)'}; font-size:1.1rem;">${b.stock_quantity}</strong></td>
        <td><span class="badge ${isOut ? 'stock-out' : 'stock-low'}" style="padding:0.25rem 0.5rem; border-radius:4px; font-size:0.75rem;">${b.stock_status}</span></td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadAuditLogs() {
  const tbody = document.getElementById("auditLogsTableBody");
  try {
    const res = await api("/api/audit-logs");
    tbody.innerHTML = "";
    res.data.forEach(log => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>#${log.log_id}</td>
        <td><span class="badge" style="background:#e2e8f0; font-size:0.75rem; padding:0.2rem 0.45rem; font-weight:700;">${log.action_type}</span></td>
        <td><code>${log.table_name}</code></td>
        <td>${log.record_id || '-'}</td>
        <td>${log.performed_by || 'SYSTEM'}</td>
        <td style="font-size:0.75rem; color:#64748b;">${new Date(log.action_time).toLocaleTimeString()}</td>
        <td style="font-size:0.8rem;">${log.details || ''}</td>
      `;
      tbody.appendChild(tr);
    });
  } catch (e) {
    console.error(e);
  }
}

// --------------------------------------------------------------------------
// Book Add / Edit Modal Controller
// --------------------------------------------------------------------------
function openAddBookModal() {
  document.getElementById("bookEditModalTitle").textContent = "Add New Book";
  document.getElementById("bookEditForm").reset();
  document.getElementById("editBookId").value = "";
  document.getElementById("editBookCover").value = "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600";
  document.getElementById("bookEditModal").classList.add("active");
}

async function openEditBookModal(bookId) {
  try {
    const res = await api(`/api/books/${bookId}`);
    const b = res.data;
    document.getElementById("bookEditModalTitle").textContent = `Edit Book #${b.book_id}`;
    document.getElementById("editBookId").value = b.book_id;
    document.getElementById("editBookIsbn").value = b.isbn;
    document.getElementById("editBookCategory").value = b.category_id;
    document.getElementById("editBookTitle").value = b.title;
    document.getElementById("editBookAuthor").value = b.author;
    document.getElementById("editBookYear").value = b.publication_year || "";
    document.getElementById("editBookPrice").value = b.price;
    document.getElementById("editBookStock").value = b.stock_quantity;
    document.getElementById("editBookCover").value = b.cover_image || "";
    document.getElementById("editBookDesc").value = b.description || "";
    document.getElementById("bookEditModal").classList.add("active");
  } catch (e) {
    console.error(e);
  }
}

function closeBookEditModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("bookEditModal").classList.remove("active");
}

async function handleSaveBook(event) {
  event.preventDefault();
  const bookId = document.getElementById("editBookId").value;
  const data = {
    isbn: document.getElementById("editBookIsbn").value.trim(),
    category_id: parseInt(document.getElementById("editBookCategory").value),
    title: document.getElementById("editBookTitle").value.trim(),
    author: document.getElementById("editBookAuthor").value.trim(),
    publication_year: parseInt(document.getElementById("editBookYear").value) || null,
    price: parseFloat(document.getElementById("editBookPrice").value),
    stock_quantity: parseInt(document.getElementById("editBookStock").value),
    cover_image: document.getElementById("editBookCover").value.trim(),
    description: document.getElementById("editBookDesc").value.trim()
  };

  try {
    if (bookId) {
      const res = await api(`/api/books/${bookId}`, "PUT", data);
      showToast(res.message);
    } else {
      const res = await api("/api/books", "POST", data);
      showToast(res.message);
    }
    closeBookEditModal();
    await loadBooks();
    if (state.currentTab === "admin") {
      refreshAdminData();
    }
  } catch (e) {
    console.error(e);
  }
}

async function deactivateBook(bookId) {
  if (!confirm(`Are you sure you want to deactivate Book #${bookId}? It will be hidden from the storefront.`)) return;
  try {
    const res = await api(`/api/books/${bookId}`, "DELETE");
    showToast(res.message);
    await loadBooks();
    await refreshAdminData();
  } catch (e) {
    console.error(e);
  }
}

// --------------------------------------------------------------------------
// User Profile Modal
// --------------------------------------------------------------------------
async function openProfileModal() {
  if (!state.currentUser) return;
  try {
    const res = await api("/api/auth/profile");
    const u = res.data;
    document.getElementById("profFullName").value = u.full_name;
    document.getElementById("profEmail").value = u.email;
    document.getElementById("profRole").value = u.role_name;
    document.getElementById("profPhone").value = u.phone || "";
    document.getElementById("profAddress").value = u.shipping_address || "";
    document.getElementById("profileModal").classList.add("active");
  } catch (e) {
    console.error(e);
  }
}

function closeProfileModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById("profileModal").classList.remove("active");
}

async function handleUpdateProfile(event) {
  event.preventDefault();
  const data = {
    full_name: document.getElementById("profFullName").value.trim(),
    phone: document.getElementById("profPhone").value.trim(),
    shipping_address: document.getElementById("profAddress").value.trim()
  };

  try {
    const res = await api("/api/auth/profile", "PUT", data);
    showToast(res.message);
    state.currentUser.full_name = data.full_name;
    updateUserUI();
    closeProfileModal();
  } catch (e) {
    console.error(e);
  }
}
