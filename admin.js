(function () {
  const { ensureDatabase, getProducts, saveProducts, getCurrentUser, getOrders, saveOrders } = window.MRCo;
  const CART_ACTIVITY_KEY = 'mrco_cart_activity';
  const CART_ACTIVITY_SEEN_KEY = 'mrco_cart_activity_seen';

  function formatMoney(value) {
    return `GHS ${Number(value).toFixed(2)}`;
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    }[character]));
  }

  function renderProductList() {
    const list = document.getElementById('admin-product-list');
    if (!list) return;

    const products = getProducts();
    if (!products.length) {
      list.innerHTML = '<p class="empty-state">No products yet. Add your first product from the form above.</p>';
      return;
    }

    list.innerHTML = products.map((product) => `
      <article class="admin-product-item">
        <img src="${escapeHtml(product.image)}" alt="${escapeHtml(product.name)}">
        <div>
          <h3>${escapeHtml(product.name)}</h3>
          <p>${escapeHtml(product.category)}</p>
          <p class="price-tag">${formatMoney(product.price)}</p>
          <p>${escapeHtml(product.description)}</p>
          <div class="admin-product-actions">
            <button type="button" class="btn admin-edit-product" data-product-id="${escapeHtml(product.id)}">Edit</button>
            <button type="button" class="btn admin-delete-product" data-product-id="${escapeHtml(product.id)}">Remove</button>
          </div>
        </div>
      </article>
    `).join('');
  }

  function setFormMode(product = null) {
    const form = document.getElementById('product-form');
    const submitButton = document.getElementById('product-submit');
    const cancelButton = document.getElementById('cancel-product-edit');
    if (!form || !submitButton || !cancelButton) return;

    form.dataset.editId = product?.id || '';
    submitButton.textContent = product ? 'Update Product' : 'Save Product';
    cancelButton.classList.toggle('hidden', !product);
    if (product) {
      form.querySelector('#productName').value = product.name;
      form.querySelector('#productCategory').value = product.category;
      form.querySelector('#productDescription').value = product.description;
      form.querySelector('#productPrice').value = product.price;
      form.querySelector('#productImageUrl').value = product.image?.startsWith('data:') ? '' : product.image || '';
      form.querySelector('#productImageFile').value = '';
      form.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } else {
      form.reset();
    }
  }

  function editProduct(productId) {
    const product = getProducts().find((entry) => entry.id === productId);
    if (product) setFormMode(product);
  }

  function removeProduct(productId) {
    const products = getProducts();
    const product = products.find((entry) => entry.id === productId);
    if (!product || !window.confirm(`Remove ${product.name} from the shop?`)) return;

    saveProducts(products.filter((entry) => entry.id !== productId));
    renderProductList();
    if (document.getElementById('product-form')?.dataset.editId === productId) setFormMode();
  }

  function renderOrderList() {
    const list = document.getElementById('admin-order-list');
    if (!list) return;

    const orders = getOrders();
    if (!orders.length) {
      list.innerHTML = '<p class="empty-state">No completed payments yet.</p>';
      return;
    }

    list.innerHTML = orders.map((order) => `
      <article class="admin-order-item">
        <div class="admin-order-main">
          <div class="admin-order-title">
            <h3>Order ${order.id.slice(-6)}</h3>
            <span class="order-status-badge ${order.deliveryConfirmed ? 'delivered' : 'paid'}">${order.deliveryConfirmed ? 'Delivered' : 'Paid'}</span>
          </div>
          <p><strong>${order.userName}</strong> · ${order.userEmail}</p>
          <p>${order.items.map((item) => `${item.name} x${item.quantity}`).join(', ')}</p>
          <p class="admin-order-meta">Paid ${new Date(order.paidAt).toLocaleString()} · ${order.deliveryMethod || 'Delivery'} · ${formatMoney(order.total)}</p>
          <p class="admin-order-location"><strong>Location:</strong> ${escapeHtml(order.deliveryLocation || 'Pickup')}</p>
        </div>
        <label class="delivery-toggle">
          <input type="checkbox" data-order-id="${order.id}" ${order.deliveryConfirmed ? 'checked' : ''}>
          <span>Delivery confirmed</span>
        </label>
      </article>`).join('');
  }

  function getCartActivity() {
    try {
      const activity = JSON.parse(localStorage.getItem(CART_ACTIVITY_KEY) || '[]');
      return Array.isArray(activity) ? activity : [];
    } catch (error) {
      return [];
    }
  }

  function renderCartActivity() {
    const list = document.getElementById('admin-cart-activity');
    if (!list) return;
    const activity = getCartActivity();
    list.innerHTML = activity.length
      ? activity.slice(0, 20).map((entry) => `
        <article class="cart-activity-item">
          <span class="activity-icon" aria-hidden="true">&#128722;</span>
          <div><strong>${escapeHtml(entry.userName)}</strong> added <strong>${escapeHtml(entry.productName)}</strong> x${entry.quantity}<small>${new Date(entry.addedAt).toLocaleString()} · ${escapeHtml(entry.userEmail)}</small></div>
        </article>`).join('')
      : '<p class="empty-state">No recent cart activity.</p>';
  }

  function renderNotificationCount() {
    const badge = document.getElementById('admin-notification-count');
    if (!badge) return;
    const seenAt = localStorage.getItem(CART_ACTIVITY_SEEN_KEY) || '';
    const count = getCartActivity().filter((entry) => !seenAt || entry.addedAt > seenAt).length;
    badge.textContent = count;
    badge.hidden = count === 0;
  }

  function renderReports() {
    const orders = getOrders().filter((order) => order.paymentStatus === 'completed');
    const totalReceived = orders.reduce((sum, order) => sum + Number(order.total || 0), 0);
    const itemCount = orders.reduce((sum, order) => sum + order.items.reduce((itemSum, item) => itemSum + Number(item.quantity || 0), 0), 0);
    const pendingCount = orders.filter((order) => !order.deliveryConfirmed).length;
    document.getElementById('report-total-received').textContent = formatMoney(totalReceived);
    document.getElementById('report-order-count').textContent = orders.length;
    document.getElementById('report-item-count').textContent = itemCount;
    document.getElementById('report-pending-count').textContent = pendingCount;

    const summary = document.getElementById('admin-report-summary');
    if (!summary) return;
    if (!orders.length) {
      summary.innerHTML = '<p class="empty-state">Completed payment reports will appear here.</p>';
      return;
    }
    const products = {};
    orders.forEach((order) => order.items.forEach((item) => {
      products[item.name] = (products[item.name] || 0) + Number(item.quantity || 0);
    }));
    summary.innerHTML = `<div class="report-product-list"><h3>Items purchased</h3>${Object.entries(products).map(([name, quantity]) => `<div><span>${escapeHtml(name)}</span><strong>${quantity}</strong></div>`).join('')}</div>`;
  }

  function markNotificationsRead() {
    localStorage.setItem(CART_ACTIVITY_SEEN_KEY, new Date().toISOString());
    const badge = document.getElementById('admin-notification-count');
    if (badge) badge.hidden = true;
  }

  function updateDeliveryStatus(event) {
    const orderId = event.target.dataset.orderId;
    if (!orderId) return;

    const orders = getOrders();
    const order = orders.find((entry) => entry.id === orderId);
    if (!order) return;
    order.deliveryConfirmed = event.target.checked;
    order.deliveredAt = order.deliveryConfirmed ? new Date().toISOString() : null;
    saveOrders(orders);
    renderOrderList();
  }

  function handleSubmit(event) {
    event.preventDefault();

    const currentUser = getCurrentUser();
    if (!currentUser || currentUser.role !== 'admin') {
      window.alert('Only the admin can add products.');
      return;
    }

    const form = event.currentTarget;
    const editId = form.dataset.editId;
    const fileInput = form.querySelector('#productImageFile');
    const imageUrl = form.querySelector('#productImageUrl').value.trim();
    const existingProduct = editId ? getProducts().find((product) => product.id === editId) : null;
    const payload = {
      id: editId || 'prod-' + Date.now(),
      name: form.querySelector('#productName').value.trim(),
      category: form.querySelector('#productCategory').value.trim(),
      description: form.querySelector('#productDescription').value.trim(),
      price: Number(form.querySelector('#productPrice').value),
      image: imageUrl || existingProduct?.image || ''
    };

    if (!payload.name || !payload.category || !payload.description || Number.isNaN(payload.price) || payload.price <= 0) {
      window.alert('Please complete all product details before saving.');
      return;
    }

    if (fileInput && fileInput.files && fileInput.files[0]) {
      const file = fileInput.files[0];
      const reader = new FileReader();
      reader.onload = function () {
        payload.image = reader.result;
        saveProduct(payload);
      };
      reader.readAsDataURL(file);
      return;
    }

    if (!payload.image) {
      window.alert('Add a product photo URL or choose a file to upload.');
      return;
    }

    saveProduct(payload);
  }

  function saveProduct(product) {
    const products = getProducts();
    const index = products.findIndex((entry) => entry.id === product.id);
    if (index >= 0) products[index] = product;
    else products.unshift(product);
    saveProducts(products);
    setFormMode();
    renderProductList();
    window.alert(index >= 0 ? 'Product updated successfully.' : 'Product saved successfully.');
  }

  function enforceAdminAccess() {
    const currentUser = getCurrentUser();
    const adminContent = document.querySelector('.admin-shell');
    if (!adminContent) return;

    if (!currentUser || currentUser.role !== 'admin') {
      adminContent.innerHTML = `
        <div class="admin-lock">
          <h2>Admin access required</h2>
          <p>Please log in with the admin account to manage products.</p>
          <p>Use email: <strong>admin@mayorrideco.com</strong> and password: <strong>admin123</strong></p>
          <a href="index.html" class="btn">Back to Home</a>
        </div>
      `;
      return false;
    }

    return true;
  }

  document.addEventListener('DOMContentLoaded', () => {
    ensureDatabase();
    if (!enforceAdminAccess()) {
      return;
    }

    renderProductList();
    renderOrderList();
    renderCartActivity();
    renderNotificationCount();
    renderReports();
    const form = document.getElementById('product-form');
    if (form) {
      form.addEventListener('submit', handleSubmit);
    }
    document.getElementById('admin-product-list')?.addEventListener('click', (event) => {
      const editButton = event.target.closest('.admin-edit-product');
      const deleteButton = event.target.closest('.admin-delete-product');
      if (editButton) editProduct(editButton.dataset.productId);
      if (deleteButton) removeProduct(deleteButton.dataset.productId);
    });
    document.getElementById('cancel-product-edit')?.addEventListener('click', () => setFormMode());
    document.getElementById('admin-order-list')?.addEventListener('change', updateDeliveryStatus);
    document.getElementById('admin-notifications')?.addEventListener('click', () => {
      const activity = document.getElementById('admin-cart-activity');
      activity?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      markNotificationsRead();
    });
  });

  window.addEventListener('mrco-products-updated', renderProductList);
  window.addEventListener('storage', (event) => {
    if (event.key === CART_ACTIVITY_KEY) {
      renderCartActivity();
      renderNotificationCount();
    }
    if (event.key === 'mrco_orders') {
      renderOrderList();
      renderReports();
    }
  });
  window.addEventListener('mrco-cart-activity', () => {
    renderCartActivity();
    renderNotificationCount();
  });
})();
