(function () {
  const CART_KEY = 'mrco_cart';
  const DELIVERY_FEE = 40;
  const PICKUP_FEE = 15;
  const CART_ACTIVITY_KEY = 'mrco_cart_activity';

  function readCart() {
    try {
      const saved = JSON.parse(localStorage.getItem(CART_KEY) || '[]');
      return Array.isArray(saved) ? saved : [];
    } catch (error) {
      return [];
    }
  }

  function saveCart(cart) {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }

  function recordCartActivity(product, quantity, user) {
    const activity = {
      id: 'cart-' + Date.now(),
      productName: product.name,
      quantity,
      userName: user.name,
      userEmail: user.email,
      addedAt: new Date().toISOString()
    };
    let activities = [];
    try { activities = JSON.parse(localStorage.getItem(CART_ACTIVITY_KEY) || '[]'); } catch (error) { activities = []; }
    localStorage.setItem(CART_ACTIVITY_KEY, JSON.stringify([activity, ...activities].slice(0, 100)));
    window.dispatchEvent(new CustomEvent('mrco-cart-activity'));
  }

  function getCartCount(cart = readCart()) {
    return cart.reduce((total, item) => total + item.quantity, 0);
  }

  function getSubtotal(cart = readCart()) {
    return cart.reduce((total, item) => total + (Number(item.price) * item.quantity), 0);
  }

  function getCurrentUser() {
    return window.MRCo?.getCurrentUser();
  }

  function getUserOrders() {
    const user = getCurrentUser();
    if (!user) return [];
    return window.MRCo.getOrders().filter((order) => order.userId === user.id);
  }

  function formatMoney(value) {
    return `GHS ${Number(value).toFixed(2)}`;
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    }[character]));
  }

  function isLoggedIn() {
    return Boolean(window.MRCo?.getCurrentUser());
  }

  function buildDrawer() {
    if (document.getElementById('cartDrawer')) return;

    document.body.insertAdjacentHTML('beforeend', `
      <aside id="cartDrawer" class="cart-drawer" aria-label="Shopping cart" aria-hidden="true">
        <div class="cart-drawer-header">
          <div><p class="eyebrow">YOUR RIDE KIT</p><h2>Shopping cart</h2></div>
          <button class="modal-close" type="button" data-close-cart aria-label="Close cart">&times;</button>
        </div>
        <div id="cartItems" class="cart-items"></div>
        <section class="order-status" aria-labelledby="order-status-title">
          <h3 id="order-status-title">Your orders</h3>
          <div id="user-orders"></div>
        </section>
        <div class="cart-summary">
          <div class="cart-line"><span>Subtotal</span><strong id="cartSubtotal">GHS 0.00</strong></div>
          <fieldset class="delivery-options">
            <legend>Collection method</legend>
            <label><input type="radio" name="deliveryMethod" value="delivery" checked> Delivery <span>+GHS 40.00</span></label>
            <label><input type="radio" name="deliveryMethod" value="pickup"> Pickup <span>+GHS 15.00</span></label>
          </fieldset>
          <label class="cart-location-field" for="deliveryLocation">Delivery location <span>(required for delivery)</span></label>
          <input id="deliveryLocation" class="cart-location-input" type="text" placeholder="Town, area, and delivery address">
          <div class="cart-line"><span>Service cost</span><strong id="cartServiceFee">GHS 40.00</strong></div>
          <div class="cart-line cart-grand-total"><span>Grand total</span><strong id="cartGrandTotal">GHS 0.00</strong></div>
          <p class="payment-methods">Pay securely with card, bank transfer, or mobile money.</p>
          <button class="btn cart-checkout" type="button">Pay with Paystack</button>
        </div>
      </aside>
    `);
  }

  function renderCart() {
    buildDrawer();
    const cart = readCart();
    const items = document.getElementById('cartItems');
    const subtotal = getSubtotal(cart);
    const method = document.querySelector('input[name="deliveryMethod"]:checked')?.value || 'delivery';
    const serviceFee = method === 'pickup' ? PICKUP_FEE : DELIVERY_FEE;

    if (!items) return;
    items.innerHTML = cart.length
      ? cart.map((item) => `
        <article class="cart-item">
          <img src="${escapeHtml(item.image)}" alt="${escapeHtml(item.name)}">
          <div class="cart-item-info"><h3>${escapeHtml(item.name)}</h3><p>${formatMoney(item.price)}</p>
            <div class="quantity-controls"><button type="button" data-cart-decrease="${escapeHtml(item.id)}">-</button><span>${item.quantity}</span><button type="button" data-cart-increase="${escapeHtml(item.id)}">+</button><button class="cart-remove" type="button" data-cart-remove="${escapeHtml(item.id)}">Remove</button></div>
          </div>
        </article>`).join('')
      : '<p class="cart-empty">Your cart is waiting for its first piece of gear.</p>';

    const orderList = document.getElementById('user-orders');
    const orders = getUserOrders();
    if (orderList) {
      orderList.innerHTML = orders.length
        ? orders.map((order) => `
          <article class="user-order">
            <div><strong>Order ${escapeHtml(order.id.slice(-6))}</strong><small>${new Date(order.paidAt).toLocaleString()}</small></div>
            <span class="order-status-badge ${order.deliveryConfirmed ? 'delivered' : 'paid'}">${order.deliveryConfirmed ? 'Delivered' : 'Payment confirmed'}</span>
          </article>`).join('')
        : '<p class="order-empty">Completed orders will appear here.</p>';
    }

    document.getElementById('cartSubtotal').textContent = formatMoney(subtotal);
    document.getElementById('cartServiceFee').textContent = formatMoney(serviceFee);
    document.getElementById('cartGrandTotal').textContent = formatMoney(cart.length ? subtotal + serviceFee : 0);
    document.querySelectorAll('[data-cart-count]').forEach((badge) => {
      badge.textContent = getCartCount(cart);
      badge.hidden = getCartCount(cart) === 0;
    });
  }

  function addProduct(productId) {
    if (!isLoggedIn()) {
      document.querySelector('[data-auth="login"]')?.click();
      return;
    }

    const product = window.MRCo.getProducts().find((entry) => entry.id === productId);
    if (!product) return;

    const cart = readCart();
    const existing = cart.find((item) => item.id === productId);
    if (existing) existing.quantity += 1;
    else cart.push({ id: product.id, name: product.name, price: Number(product.price), image: product.image, quantity: 1 });
    recordCartActivity(product, existing ? existing.quantity : 1, getCurrentUser());
    saveCart(cart);
    renderCart();
    openCart();
  }

  function openCart() {
    const drawer = document.getElementById('cartDrawer');
    if (!drawer) return;
    renderCart();
    drawer.classList.add('open');
    drawer.setAttribute('aria-hidden', 'false');
  }

  function closeCart() {
    const drawer = document.getElementById('cartDrawer');
    if (!drawer) return;
    drawer.classList.remove('open');
    drawer.setAttribute('aria-hidden', 'true');
  }

  function saveCompletedOrder(reference) {
    const cart = readCart();
    const user = getCurrentUser();
    if (!cart.length || !user) return;

    const method = document.querySelector('input[name="deliveryMethod"]:checked')?.value || 'delivery';
    const location = document.getElementById('deliveryLocation')?.value.trim() || '';
    if (method === 'delivery' && !location) {
      window.alert('Enter your delivery location before continuing.');
      return;
    }
    const serviceFee = method === 'pickup' ? PICKUP_FEE : DELIVERY_FEE;
    const order = {
      id: 'order-' + Date.now(),
      userId: user.id,
      userName: user.name,
      userEmail: user.email,
      items: cart,
      subtotal: getSubtotal(cart),
      serviceFee,
      total: getSubtotal(cart) + serviceFee,
      deliveryMethod: method,
      deliveryLocation: location,
      paymentStatus: 'completed',
      paymentProvider: 'paystack',
      paymentReference: reference,
      paidAt: new Date().toISOString(),
      deliveryConfirmed: false
    };

    const orders = window.MRCo.getOrders();
    orders.unshift(order);
    window.MRCo.saveOrders(orders);
    saveCart([]);
    renderCart();
    window.alert('Payment completed. Your order has been placed.');
  }

  function startPaystackCheckout() {
    const cart = readCart();
    const user = getCurrentUser();
    const publicKey = window.MRCO_PAYSTACK_PUBLIC_KEY;
    if (!cart.length || !user) return;

    if (!publicKey || publicKey.includes('REPLACE_WITH')) {
      window.alert('Paystack is not configured yet. Add your Paystack public key in paystack-config.js.');
      return;
    }

    if (typeof window.PaystackPop !== 'function') {
      window.alert('The Paystack payment service could not be loaded. Please check your connection and try again.');
      return;
    }

    const method = document.querySelector('input[name="deliveryMethod"]:checked')?.value || 'delivery';
    const location = document.getElementById('deliveryLocation')?.value.trim() || '';
    if (method === 'delivery' && !location) {
      window.alert('Enter your delivery location before continuing.');
      return;
    }
    const serviceFee = method === 'pickup' ? PICKUP_FEE : DELIVERY_FEE;
    const total = getSubtotal(cart) + serviceFee;
    const checkoutButton = document.querySelector('.cart-checkout');
    if (checkoutButton) checkoutButton.disabled = true;

    const popup = new window.PaystackPop();
    popup.newTransaction({
      key: publicKey,
      email: user.email,
      amount: Math.round(total * 100),
      currency: 'GHS',
      channels: ['card', 'bank', 'mobile_money'],
      metadata: {
        custom_fields: [
          { display_name: 'Customer name', variable_name: 'customer_name', value: user.name },
          { display_name: 'Collection method', variable_name: 'collection_method', value: method },
          { display_name: 'Delivery location', variable_name: 'delivery_location', value: location || 'Pickup' }
        ]
      },
      onSuccess: (transaction) => saveCompletedOrder(transaction.reference),
      onCancel: () => window.alert('Payment was cancelled. Your cart is still available.'),
      onError: () => window.alert('Payment could not be started. Please try again.')
    });

    if (checkoutButton) checkoutButton.disabled = false;
  }

  function refreshCartButton() {
    const user = window.MRCo?.getCurrentUser();
    document.querySelectorAll('[data-cart-trigger]').forEach((button) => button.remove());
    if (document.body.classList.contains('admin-page')) return;
    if (!user) return;

    const account = document.querySelector('.account-section');
    if (!account) return;
    const button = document.createElement('button');
    button.className = 'nav-btn cart-trigger';
    button.type = 'button';
    button.setAttribute('data-cart-trigger', 'true');
    button.innerHTML = '<i class="fas fa-shopping-bag" aria-hidden="true"></i> Cart <span data-cart-count hidden>0</span>';
    account.appendChild(button);
    renderCart();
  }

  document.addEventListener('click', (event) => {
    const addButton = event.target.closest('[data-product-id]');
    if (addButton) addProduct(addButton.dataset.productId);
    if (event.target.closest('[data-cart-trigger]')) openCart();
    if (event.target.closest('[data-close-cart]')) closeCart();

    const increase = event.target.closest('[data-cart-increase]');
    const decrease = event.target.closest('[data-cart-decrease]');
    const remove = event.target.closest('[data-cart-remove]');
    const cart = readCart();
    const itemId = increase?.dataset.cartIncrease || decrease?.dataset.cartDecrease || remove?.dataset.cartRemove;
    if (itemId) {
      const item = cart.find((entry) => entry.id === itemId);
      if (increase && item) item.quantity += 1;
      if (decrease && item) item.quantity -= 1;
      if (remove || item?.quantity <= 0) saveCart(cart.filter((entry) => entry.id !== itemId));
      else saveCart(cart);
      renderCart();
    }

    if (event.target.closest('.cart-checkout')) {
      startPaystackCheckout();
    }
  });

  document.addEventListener('change', (event) => {
    if (event.target.matches('input[name="deliveryMethod"]')) renderCart();
  });

  document.addEventListener('DOMContentLoaded', () => {
    buildDrawer();
    refreshCartButton();
  });

  window.MRCO_CART = { refresh: refreshCartButton, render: renderCart };
})();
