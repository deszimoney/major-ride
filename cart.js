(function () {
  const CART_KEY = 'mrco_cart';
  const DELIVERY_FEE = 40;
  const PICKUP_FEE = 15;
  const CART_ACTIVITY_KEY = 'mrco_cart_activity';

  function readCart() {
    try {
      const saved = JSON.parse(localStorage.getItem(CART_KEY) || '[]');
      if (!Array.isArray(saved)) return [];
      return saved.flatMap((item) => {
        if (!item || typeof item.id !== 'string' || !Number.isInteger(item.quantity)) return [];
        if (item.quantity < 1 || item.quantity > 99) return [];
        const product = window.MRCo?.getProducts().find((entry) => entry.id === item.id);
        return product && Number.isFinite(Number(product.price)) && Number(product.price) > 0
          ? [{
            id: product.id,
            name: product.name,
            price: Number(product.price),
            image: product.image,
            quantity: item.quantity
          }]
          : [];
      });
    } catch (error) {
      console.error('Discarded an invalid saved cart.', error);
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
    return window.MRCo.getOrders().filter((order) =>
      order.userId === user.id &&
      order.paymentStatus === 'completed' &&
      order.paymentReference &&
      order.paymentVerifiedAt
    );
  }

  function formatMoney(value) {
    const amount = Number(value);
    return `GHS ${(Number.isFinite(amount) ? amount : 0).toFixed(2)}`;
  }

  const escapeHtml = (value) => window.MRCo.escapeHtml(value);

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
          <input id="deliveryLocation" class="cart-location-input" type="text" maxlength="300" placeholder="Town, area, and delivery address">
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
          <img src="${escapeHtml(window.MRCo.sanitizeImageUrl(item.image))}" alt="${escapeHtml(item.name)}">
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

  async function saveCompletedOrder(reference, items, method, location) {
    const user = getCurrentUser();
    if (!items.length || !user || typeof reference !== 'string' || !reference) {
      window.alert('We could not confirm this payment. Keep your payment reference and contact support.');
      return;
    }

    const supabase = window.MRCo.getSupabaseClient();
    if (!supabase) {
      window.alert('Payment was received, but secure order verification is unavailable. Keep your payment reference and contact support.');
      return;
    }

    try {
      const { data, error } = await supabase.functions.invoke('verify-paystack-order', {
        body: {
          reference,
          items: items.map((item) => ({ id: item.id, quantity: item.quantity })),
          deliveryMethod: method,
          deliveryLocation: location
        }
      });
      if (error || !data?.order) {
        console.error('Server-side payment verification failed.', error || data);
        window.alert('Payment may have been received, but the order is not verified yet. Keep your payment reference and contact support.');
        return;
      }

      const row = data.order;
      window.MRCo.cacheVerifiedOrder({
        id: row.id,
        userId: row.user_id,
        userName: row.user_name,
        userEmail: row.user_email,
        items: row.items,
        subtotal: row.subtotal,
        serviceFee: row.service_fee,
        total: row.total,
        paymentStatus: row.payment_status,
        paymentProvider: row.payment_provider,
        paymentReference: row.payment_reference,
        paymentVerifiedAt: row.payment_verified_at,
        paidAt: row.paid_at,
        deliveryMethod: row.delivery_method,
        deliveryLocation: row.delivery_location,
        deliveryConfirmed: row.delivery_confirmed,
        deliveredAt: row.delivered_at
      });
      const currentCart = readCart();
      const checkoutCartUnchanged = currentCart.length === items.length &&
        currentCart.every((item, index) =>
          item.id === items[index].id && item.quantity === items[index].quantity
        );
      if (checkoutCartUnchanged) saveCart([]);
      renderCart();
      window.alert('Payment verified. Your order has been placed.');
    } catch (error) {
      console.error('Unable to verify and save the paid order.', error);
      window.alert('Payment may have been received, but the order is not verified yet. Keep your payment reference and contact support.');
    }
  }

  async function startPaystackCheckout() {
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
    if (!['delivery', 'pickup'].includes(method)) {
      window.alert('Choose a valid collection method.');
      return;
    }
    if (method === 'delivery' && (location.length < 4 || location.length > 300)) {
      window.alert('Enter your delivery location before continuing.');
      return;
    }
    const serviceFee = method === 'pickup' ? PICKUP_FEE : DELIVERY_FEE;
    const total = getSubtotal(cart) + serviceFee;
    const checkoutButton = document.querySelector('.cart-checkout');
    const supabase = window.MRCo.getSupabaseClient();
    if (!supabase) {
      window.alert('Secure payment verification is not configured yet. Please try again later.');
      return;
    }
    if (checkoutButton) checkoutButton.disabled = true;

    try {
      const { data, error } = await supabase.functions.invoke('verify-paystack-order', {
        body: { action: 'healthcheck' }
      });
      if (error || data?.ready !== true) {
        console.error('Secure payment verification is unavailable.', error || data);
        window.alert('Secure payment verification is unavailable. No payment was started.');
        return;
      }

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
        onSuccess: (transaction) => saveCompletedOrder(transaction?.reference, cart, method, location),
        onCancel: () => window.alert('Payment was cancelled. Your cart is still available.'),
        onError: () => window.alert('Payment could not be started. Please try again.')
      });
    } catch (error) {
      console.error('Unable to open Paystack checkout.', error);
      window.alert('Payment could not be started. Please try again.');
    } finally {
      if (checkoutButton) checkoutButton.disabled = false;
    }
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
    const icon = document.createElement('i');
    icon.className = 'fas fa-shopping-bag';
    icon.setAttribute('aria-hidden', 'true');
    button.append(icon, document.createTextNode(' Cart '));
    const count = document.createElement('span');
    count.dataset.cartCount = '';
    count.hidden = true;
    button.append(count);
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
      if (increase && item && item.quantity < 99) item.quantity += 1;
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
