(function () {
  const {
    ensureDatabase,
    getProducts,
    saveProducts,
    deleteProduct,
    getOrders,
    updateOrderDeliveryStatus,
    escapeHtml,
    sanitizeImageUrl
  } = window.MRCo;
  const CART_ACTIVITY_KEY = 'mrco_cart_activity';
  const CART_ACTIVITY_SEEN_KEY = 'mrco_cart_activity_seen';

  function formatMoney(value) {
    const amount = Number(value);
    return `GHS ${(Number.isFinite(amount) ? amount : 0).toFixed(2)}`;
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
        <img src="${escapeHtml(sanitizeImageUrl(product.image))}" alt="${escapeHtml(product.name)}">
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

    deleteProduct(productId).then(() => {
      renderProductList();
      if (document.getElementById('product-form')?.dataset.editId === productId) setFormMode();
    }).catch((error) => {
      console.error('Unable to remove product.', error);
      window.alert('The product could not be removed. Confirm you are signed in as an administrator.');
    });
  }

  function renderOrderList() {
    const list = document.getElementById('admin-order-list');
    if (!list) return;

    const orders = getOrders().filter((order) =>
      order.paymentStatus === 'completed' && order.paymentReference && order.paymentVerifiedAt
    );
    if (!orders.length) {
      list.innerHTML = '<p class="empty-state">No completed payments yet.</p>';
      return;
    }

    list.innerHTML = orders.map((order) => `
      <article class="admin-order-item">
        <div class="admin-order-main">
          <div class="admin-order-title">
            <h3>Order ${escapeHtml(String(order.id).slice(-6))}</h3>
            <span class="order-status-badge ${order.deliveryConfirmed ? 'delivered' : 'paid'}">${order.deliveryConfirmed ? 'Delivered' : 'Paid'}</span>
          </div>
          <p><strong>${escapeHtml(order.userName)}</strong> · ${escapeHtml(order.userEmail)}</p>
          <p>${order.items.map((item) => `${escapeHtml(item.name)} x${Number(item.quantity)}`).join(', ')}</p>
          <p class="admin-order-meta">Paid ${new Date(order.paidAt).toLocaleString()} · ${order.deliveryMethod || 'Delivery'} · ${formatMoney(order.total)}</p>
          <p class="admin-order-location"><strong>Location:</strong> ${escapeHtml(order.deliveryLocation || 'Pickup')}</p>
        </div>
        <label class="delivery-toggle">
          <input type="checkbox" data-order-id="${escapeHtml(order.id)}" ${order.deliveryConfirmed ? 'checked' : ''}>
          <span>Delivery confirmed</span>
        </label>
      </article>`).join('');
  }

  function getCartActivity() {
    try {
      const activity = JSON.parse(localStorage.getItem(CART_ACTIVITY_KEY) || '[]');
      return Array.isArray(activity) ? activity : [];
    } catch (error) {
      console.error('Discarded invalid local cart activity.', error);
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
          <div><strong>${escapeHtml(entry.userName)}</strong> added <strong>${escapeHtml(entry.productName)}</strong> x${Number(entry.quantity)}<small>${escapeHtml(new Date(entry.addedAt).toLocaleString())} · ${escapeHtml(entry.userEmail)}</small></div>
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
    const orders = getOrders().filter((order) =>
      order.paymentStatus === 'completed' && order.paymentReference && order.paymentVerifiedAt
    );
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
    const products = new Map();
    orders.forEach((order) => order.items.forEach((item) => {
      products.set(item.name, (products.get(item.name) || 0) + Number(item.quantity || 0));
    }));
    summary.innerHTML = `<div class="report-product-list"><h3>Items purchased</h3>${[...products].map(([name, quantity]) => `<div><span>${escapeHtml(name)}</span><strong>${quantity}</strong></div>`).join('')}</div>`;
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
    updateOrderDeliveryStatus(orderId, event.target.checked).then(() => {
      renderOrderList();
    }).catch((error) => {
      console.error('Unable to update order delivery status.', error);
      window.alert('Delivery status could not be saved. Confirm you are signed in as an administrator.');
      renderOrderList();
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const form = event.currentTarget;

    let isAdmin = false;
    try {
      isAdmin = await window.MRCo.isStoreAdmin();
    } catch (error) {
      console.error('Unable to verify administrator access before saving a product.', error);
    }
    if (!isAdmin) {
      window.alert('Only the admin can add products.');
      return;
    }

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
      image: imageUrl ? sanitizeImageUrl(imageUrl) : existingProduct?.image || ''
    };

    if (!payload.name || !payload.category || !payload.description || !Number.isFinite(payload.price) || payload.price <= 0) {
      window.alert('Please complete all product details before saving.');
      return;
    }
    if (imageUrl && !payload.image) {
      window.alert('Use a valid HTTPS image URL or a path within this site.');
      return;
    }

    if (fileInput && fileInput.files && fileInput.files[0]) {
      const file = fileInput.files[0];
      if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type) || file.size > 5 * 1024 * 1024) {
        window.alert('Choose a JPEG, PNG, WebP, or GIF image no larger than 5 MB.');
        return;
      }
      const reader = new FileReader();
      reader.onload = function () {
        payload.image = reader.result;
        saveProduct(payload);
      };
      reader.onerror = function () {
        window.alert('The image file could not be read. Please choose it again.');
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

  async function saveProduct(product) {
    const products = getProducts();
    const index = products.findIndex((entry) => entry.id === product.id);
    if (index >= 0) products[index] = product;
    else products.unshift(product);
    try {
      await saveProducts(products);
      setFormMode();
      renderProductList();
      window.alert(index >= 0 ? 'Product updated successfully.' : 'Product saved successfully.');
    } catch (error) {
      console.error('Unable to save product.', error);
      window.alert('The product could not be saved. Confirm you are signed in as an administrator.');
    }
  }

  async function enforceAdminAccess() {
    const adminContent = document.querySelector('.admin-shell');
    if (!adminContent) return false;

    let isAdmin = false;
    try {
      isAdmin = await window.MRCo.isStoreAdmin();
    } catch (error) {
      console.error('Unable to verify administrator access.', error);
    }
    if (isAdmin) return true;

    const isConfigured = Boolean(window.MRCo.getSupabaseClient());
    adminContent.innerHTML = isConfigured ? `
      <div class="admin-lock">
        <h2>Admin access required</h2>
        <p>Sign in with an administrator account configured in Supabase.</p>
        <a href="index.html" class="btn">Back to Home</a>
      </div>
    ` : `
      <div class="admin-lock">
        <h2>Admin tools are unavailable</h2>
        <p>Secure Supabase authentication and database access must be configured first.</p>
        <a href="index.html" class="btn">Back to Home</a>
      </div>
    `;
    return false;
  }

  document.addEventListener('DOMContentLoaded', async () => {
    ensureDatabase();
    if (!await enforceAdminAccess()) {
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
  window.addEventListener('mrco-orders-updated', () => {
    renderOrderList();
    renderReports();
  });
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
