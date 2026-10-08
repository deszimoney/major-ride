(function () {
  const STORAGE_KEYS = {
    products: 'mrco_products',
    currentUser: 'mrco_current_user',
    search: 'mrco_search_query'
  };

  // The starter catalog keeps the storefront useful before the admin adds live inventory.
  const DEFAULT_PRODUCTS = [
    {
      id: 'prod-001',
      name: 'Shark Evo Helmet',
      category: 'Helmets',
      price: 299.99,
      image: 'https://images.unsplash.com/photo-1591637333184-19aa84b3e01f?auto=format&fit=crop&w=1200&q=80',
      description: 'High-impact protection with a lightweight shell and premium comfort fit.'
    },
    {
      id: 'prod-002',
      name: 'Alpinestars Gloves',
      category: 'Gloves',
      price: 89.99,
      image: 'https://images.unsplash.com/photo-1614165933026-0750fcd503e8?auto=format&fit=crop&w=1200&q=80',
      description: 'Rugged grip and dexterity for daily rides and track-ready performance.'
    },
    {
      id: 'prod-003',
      name: 'Racing Boots',
      category: 'Boots',
      price: 199.99,
      image: 'https://images.unsplash.com/photo-1609630875171-b1321377ee65?auto=format&fit=crop&w=1200&q=80',
      description: 'Supportive ankle protection with durable construction and all-day comfort.'
    },
    {
      id: 'prod-004', name: 'Roadshield Jacket', category: 'Clothing', price: 449.99,
      image: 'images/jackets.jpg', description: 'Weather-ready riding jacket with a structured protective fit.'
    },
    {
      id: 'prod-005', name: 'Urban Rider Backpack', category: 'Backpacks', price: 179.99,
      image: 'images/bags.jpg', description: 'A practical, water-resistant bag for daily commutes and weekend rides.'
    },
    {
      id: 'prod-006', name: 'Signal Pro Kit', category: 'Electronics', price: 329.99,
      image: 'images/electronics.jpg', description: 'Compact ride electronics to keep your journey connected.'
    },
    {
      id: 'prod-007', name: 'SecureLock Disc Lock', category: 'Security', price: 129.99,
      image: 'images/locks.jpg', description: 'Heavy-duty compact security for stops around town.'
    },
    {
      id: 'prod-008', name: 'Street Grip Tyre', category: 'Tyres', price: 389.99,
      image: 'images/tyre.jpg', description: 'Confident road grip for daily city riding.'
    },
    {
      id: 'prod-009', name: 'Torque Exhaust', category: 'Exhausts', price: 699.99,
      image: 'images/exhausts.jpg', description: 'A clean performance upgrade with a deep, controlled note.'
    },
    {
      id: 'prod-010', name: 'MotoCare Body Kit', category: 'Parts', price: 259.99,
      image: 'images/bodyparts.jpg', description: 'Replacement bodywork made for dependable fitment.'
    }
  ];

  let productRevision = 0;
  let cachedOrders = [];
  let databaseInitialized = false;

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    }[character]));
  }

  function sanitizeImageUrl(value) {
    const candidate = String(value ?? '').trim();
    if (/^data:image\/(?:png|jpeg|gif|webp);base64,[a-z0-9+/]+=*$/i.test(candidate)) {
      return candidate;
    }

    try {
      const url = new URL(candidate, window.location.href);
      if (url.protocol === 'https:' || url.origin === window.location.origin) {
        return url.href;
      }
    } catch (error) {
      console.error('Invalid product image URL.', error);
    }
    return '';
  }

  function getSupabaseClient() {
    if (!window.MRCO_SUPABASE_READY) return null;
    if (!window.supabase) return null;

    if (!window.__mrco_supabase_client) {
      window.__mrco_supabase_client = window.supabase.createClient(
        window.MRCO_SUPABASE.url,
        window.MRCO_SUPABASE.anonKey
      );
    }

    return window.__mrco_supabase_client;
  }

  async function syncSupabaseData() {
    const supabase = getSupabaseClient();
    if (!supabase) return;
    const syncRevision = productRevision;

    try {
      const [{ data: liveProducts, error: productsError }, { data: liveOrders, error: ordersError }] = await Promise.all([
        supabase.from('products').select('*'),
        supabase.from('orders').select('*').order('paid_at', { ascending: false })
      ]);

      if (productsError) {
        console.error('Unable to load the product catalog from Supabase.', productsError);
      }
      if (!productsError && Array.isArray(liveProducts) && syncRevision === productRevision) {
        localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(liveProducts.map((product) => ({
          ...product,
          category: product.category?.toLowerCase() === 'accessories' ? 'Backpacks' : product.category
        }))));
        window.dispatchEvent(new CustomEvent('mrco-products-updated'));
      }

      if (ordersError) {
        console.error('Unable to load authorized orders from Supabase.', ordersError);
      } else if (Array.isArray(liveOrders)) {
        cachedOrders = liveOrders.map((order) => ({
          id: order.id,
          userId: order.user_id,
          userName: order.user_name,
          userEmail: order.user_email,
          items: order.items,
          subtotal: order.subtotal,
          serviceFee: order.service_fee,
          total: order.total,
          paymentStatus: order.payment_status,
          paymentProvider: order.payment_provider,
          paymentReference: order.payment_reference,
          paymentVerifiedAt: order.payment_verified_at,
          paidAt: order.paid_at,
          deliveryMethod: order.delivery_method,
          deliveryLocation: order.delivery_location,
          deliveryConfirmed: order.delivery_confirmed,
          deliveredAt: order.delivered_at
        }));
        window.dispatchEvent(new CustomEvent('mrco-orders-updated'));
      }
    } catch (error) {
      console.error('Unable to synchronize secure store data.', error);
    }
  }

  function ensureDatabase() {
    if (databaseInitialized) return;
    databaseInitialized = true;
    localStorage.removeItem('mrco_orders');
    localStorage.removeItem('mrco_users');

    if (!localStorage.getItem(STORAGE_KEYS.products)) {
      localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(DEFAULT_PRODUCTS));
    } else {
      // Merge newly introduced starter products without overwriting admin inventory.
      const savedProducts = getStoredProducts();
      const migratedProducts = savedProducts.map((product) => ({
        ...product,
        category: product.category?.toLowerCase() === 'accessories' ? 'Backpacks' : product.category
      }));
      if (JSON.stringify(migratedProducts) !== JSON.stringify(savedProducts)) {
        localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(migratedProducts));
      }
      const savedIds = new Set(migratedProducts.map((product) => product.id));
      const missingProducts = DEFAULT_PRODUCTS.filter((product) => !savedIds.has(product.id));
      if (missingProducts.length) {
        localStorage.setItem(STORAGE_KEYS.products, JSON.stringify([...migratedProducts, ...missingProducts]));
      }
    }

    syncSupabaseData();
    restoreCurrentUser();
  }

  function getProducts() {
    ensureDatabase();
    return getStoredProducts();
  }

  function getStoredProducts() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.products) || '[]');
    } catch (error) {
      console.error('Discarded an invalid cached product catalog.', error);
      return [];
    }
  }

  async function saveProducts(products) {
    productRevision += 1;
    const supabase = getSupabaseClient();
    if (!supabase || !Array.isArray(products)) {
      throw new Error('Secure product management is not configured.');
    }
    const { error } = await supabase.from('products').upsert(products, { onConflict: 'id' });
    if (error) throw error;
    localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(products));
    window.dispatchEvent(new CustomEvent('mrco-products-updated'));
  }

  async function deleteProduct(productId) {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error('Secure product management is not configured.');
    const { error } = await supabase.from('products').delete().eq('id', productId);
    if (error) throw error;
    const products = getStoredProducts().filter((product) => product.id !== productId);
    localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(products));
    window.dispatchEvent(new CustomEvent('mrco-products-updated'));
  }

  function getOrders() {
    return [...cachedOrders];
  }

  function cacheVerifiedOrder(order) {
    if (
      !order ||
      order.paymentStatus !== 'completed' ||
      !order.paymentReference ||
      !order.paymentVerifiedAt
    ) {
      throw new Error('Only a server-verified payment can be added to the order cache.');
    }
    cachedOrders = [order, ...cachedOrders.filter((entry) => entry.id !== order.id)];
    window.dispatchEvent(new CustomEvent('mrco-orders-updated'));
  }

  async function updateOrderDeliveryStatus(orderId, deliveryConfirmed) {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error('Secure order management is not configured.');

    const deliveredAt = deliveryConfirmed ? new Date().toISOString() : null;
    const { data, error } = await supabase
      .from('orders')
      .update({ delivery_confirmed: deliveryConfirmed, delivered_at: deliveredAt })
      .eq('id', orderId)
      .select('*')
      .single();
    if (error) throw error;

    const updatedOrder = {
      ...cachedOrders.find((order) => order.id === orderId),
      deliveryConfirmed: data.delivery_confirmed,
      deliveredAt: data.delivered_at
    };
    cachedOrders = cachedOrders.map((order) => order.id === orderId ? updatedOrder : order);
    window.dispatchEvent(new CustomEvent('mrco-orders-updated'));
  }

  async function isStoreAdmin() {
    const supabase = getSupabaseClient();
    if (!supabase) return false;
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    if (!userData.user) return false;
    const { data, error } = await supabase.rpc('is_store_admin');
    if (error) throw error;
    return data === true;
  }

  function getCurrentUser() {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.currentUser);
      return raw ? JSON.parse(raw) : null;
    } catch (error) {
      localStorage.removeItem(STORAGE_KEYS.currentUser);
      console.error('Discarded an invalid cached account profile.', error);
      return null;
    }
  }

  function setCurrentUser(user) {
    if (!user) {
      localStorage.removeItem(STORAGE_KEYS.currentUser);
    } else {
      localStorage.setItem(STORAGE_KEYS.currentUser, JSON.stringify(user));
    }
    window.dispatchEvent(new CustomEvent('mrco-auth-changed'));
  }

  function clearCurrentUser() {
    setCurrentUser(null);
  }

  function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase();
  }

  async function getAuthProfile(authUser, fallbackName = '') {
    const supabase = getSupabaseClient();
    const normalizedEmail = normalizeEmail(authUser?.email);
    if (supabase && authUser?.id) {
      const { data, error } = await supabase
        .from('users')
        .select('id, name, email, provider, role')
        .eq('id', authUser.id)
        .maybeSingle();
      if (error) {
        console.error('Unable to load the signed-in user profile.', error);
      } else if (data) {
        return data;
      }
    }

    return {
      id: authUser.id,
      name: fallbackName || authUser.user_metadata?.name || normalizedEmail.split('@')[0],
      email: normalizedEmail,
      provider: 'email',
      role: 'user'
    };
  }

  async function registerUser({ name, email, password, provider = 'email' }) {
    const normalizedEmail = normalizeEmail(email);

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return { success: false, message: 'Enter a valid email address.' };
    }

    if (provider !== 'email') {
      return { success: false, message: 'Use the configured provider sign-in button.' };
    }

    if (!password || password.length < 6) {
      return { success: false, message: 'Password must be at least 6 characters long.' };
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      return { success: false, message: 'Secure authentication is not configured. Please try again later.' };
    }

    const { data, error } = await supabase.auth.signUp({
      email: normalizedEmail,
      password,
      options: { data: { name: name || normalizedEmail.split('@')[0] } }
    });

    if (error) {
      return { success: false, message: error.message };
    }

    if (!data.user) {
      return { success: false, message: 'Account creation did not return a user. Please try again.' };
    }

    const profile = data.session
      ? await getAuthProfile(data.user, name)
      : null;
    if (profile) setCurrentUser(profile);

    return {
      success: true,
      user: profile,
      requiresConfirmation: !data.session,
      message: data.session
        ? 'Account created successfully.'
        : 'Check your email to confirm your account before logging in.'
    };
  }

  async function loginUser({ email, password }) {
    const normalizedEmail = normalizeEmail(email);
    const supabase = getSupabaseClient();
    if (!supabase) {
      return { success: false, message: 'Secure authentication is not configured. Please try again later.' };
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email: normalizedEmail,
      password
    });
    if (error) {
      return { success: false, message: error.message };
    }

    const profile = await getAuthProfile(data.user);
    setCurrentUser(profile);
    return { success: true, user: profile };
  }

  async function requestPasswordReset(email) {
    const normalizedEmail = normalizeEmail(email);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return { success: false, message: 'Enter a valid email address.' };
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      return { success: false, message: 'Secure password reset is not configured. Please try again later.' };
    }

    const redirectTo = window.location.href.split('#')[0];
    const { error } = await supabase.auth.resetPasswordForEmail(normalizedEmail, { redirectTo });
    return error
      ? { success: false, message: error.message }
      : { success: true, requiresEmail: true };
  }

  async function updatePassword({ password }) {
    if (!password || password.length < 6) {
      return { success: false, message: 'Password must be at least 6 characters long.' };
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      return { success: false, message: 'Secure password reset is not configured. Please try again later.' };
    }

    const { error } = await supabase.auth.updateUser({ password });
    return error ? { success: false, message: error.message } : { success: true };
  }

  async function socialLogin(provider) {
    const providerName = (provider || '').toLowerCase();
    const supabase = getSupabaseClient();

    if (!supabase) {
      return { success: false, message: 'Secure authentication is not configured. Please try again later.' };
    }

    if (!['google', 'apple'].includes(providerName)) {
      return { success: false, message: 'This sign-in provider is not supported.' };
    }

    if (window.MRCO_SOCIAL_PROVIDERS?.[providerName] === false) {
      return {
        success: false,
        message: `${providerName === 'google' ? 'Google' : 'Apple'} sign-in is not enabled yet. Enable this provider in Supabase Authentication settings.`
      };
    }

    const { error } = await supabase.auth.signInWithOAuth({
      provider: providerName,
      options: { redirectTo: window.location.href }
    });
    return error
      ? { success: false, message: error.message }
      : { success: true, redirecting: true };
  }

  async function restoreCurrentUser() {
    const supabase = getSupabaseClient();
    if (!supabase) {
      clearCurrentUser();
      cachedOrders = [];
      return;
    }

    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) {
      clearCurrentUser();
      cachedOrders = [];
      if (error && error.name !== 'AuthSessionMissingError') {
        console.error('Unable to restore the Supabase session.', error);
      }
      return;
    }

    setCurrentUser(await getAuthProfile(data.user));
  }

  window.MRCo = {
    STORAGE_KEYS,
    escapeHtml,
    sanitizeImageUrl,
    ensureDatabase,
    getProducts,
    saveProducts,
    deleteProduct,
    getOrders,
    cacheVerifiedOrder,
    updateOrderDeliveryStatus,
    isStoreAdmin,
    getCurrentUser,
    setCurrentUser,
    clearCurrentUser,
    registerUser,
    loginUser,
    requestPasswordReset,
    updatePassword,
    socialLogin,
    getSupabaseClient
  };

  window.addEventListener('DOMContentLoaded', ensureDatabase);
  window.addEventListener('mrco-auth-changed', syncSupabaseData);
})();
