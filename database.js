(function () {
  const STORAGE_KEYS = {
    users: 'mrco_users',
    products: 'mrco_products',
    orders: 'mrco_orders',
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

  const DEFAULT_ADMIN = {
    id: 'admin-001',
    name: 'Owner',
    email: 'admin@mayorrideco.com',
    password: 'admin123',
    provider: 'email',
    role: 'admin'
  };

  let productRevision = 0;

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
      const [{ data: liveUsers, error: usersError }, { data: liveProducts, error: productsError }, { data: liveOrders, error: ordersError }] = await Promise.all([
        supabase.from('users').select('id, name, email, provider, role'),
        supabase.from('products').select('*'),
        supabase.from('orders').select('*').order('paid_at', { ascending: false })
      ]);

      if (!usersError && Array.isArray(liveUsers) && liveUsers.length) {
        localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(liveUsers));
      }

      if (!productsError && Array.isArray(liveProducts) && liveProducts.length && syncRevision === productRevision) {
        localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(liveProducts.map((product) => ({
          ...product,
          category: product.category?.toLowerCase() === 'accessories' ? 'Backpacks' : product.category
        }))));
        window.dispatchEvent(new CustomEvent('mrco-products-updated'));
      }

      if (!ordersError && Array.isArray(liveOrders)) {
        localStorage.setItem(STORAGE_KEYS.orders, JSON.stringify(liveOrders.map((order) => ({
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
          paidAt: order.paid_at,
          deliveryMethod: order.delivery_method,
          deliveryLocation: order.delivery_location,
          deliveryConfirmed: order.delivery_confirmed,
          deliveredAt: order.delivered_at
        }))));
      }
    } catch (error) {
      // Remote tables may not exist yet; local storage remains the fallback source.
    }
  }

  function ensureDatabase() {
    if (!localStorage.getItem(STORAGE_KEYS.users)) {
      localStorage.setItem(STORAGE_KEYS.users, JSON.stringify([DEFAULT_ADMIN]));
    }

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
  }

  function getUsers() {
    ensureDatabase();
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.users) || '[]');
    } catch (error) {
      return [];
    }
  }

  function saveUsers(users) {
    localStorage.setItem(STORAGE_KEYS.users, JSON.stringify(users));
    const supabase = getSupabaseClient();
    if (!supabase || !Array.isArray(users)) return;

    try {
      const profiles = users.map(({ id, name, email, provider, role }) => ({
        id,
        name,
        email,
        provider,
        role
      }));
      supabase.from('users').upsert(profiles, { onConflict: 'id' }).then(() => {}).catch(() => {});
    } catch (error) {
      // Supabase table must exist; local storage remains active until configured.
    }
  }

  function getProducts() {
    ensureDatabase();
    return getStoredProducts();
  }

  function getStoredProducts() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.products) || '[]');
    } catch (error) {
      return [];
    }
  }

  function saveProducts(products) {
    productRevision += 1;
    localStorage.setItem(STORAGE_KEYS.products, JSON.stringify(products));
    window.dispatchEvent(new CustomEvent('mrco-products-updated'));
    const supabase = getSupabaseClient();
    if (!supabase || !Array.isArray(products)) return;

    try {
      supabase.from('products').upsert(products, { onConflict: 'id' }).then(() => {}).catch(() => {});
    } catch (error) {
      // Supabase table must exist; local storage remains active until the schema is created.
    }
  }

  function getOrders() {
    ensureDatabase();
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.orders) || '[]');
    } catch (error) {
      return [];
    }
  }

  function saveOrders(orders) {
    localStorage.setItem(STORAGE_KEYS.orders, JSON.stringify(orders));
    const supabase = getSupabaseClient();
    if (!supabase || !Array.isArray(orders)) return;

    try {
      const rows = orders.map((order) => ({
        id: order.id,
        user_id: order.userId,
        user_name: order.userName,
        user_email: order.userEmail,
        items: order.items,
        subtotal: order.subtotal,
        service_fee: order.serviceFee,
        total: order.total,
        payment_status: order.paymentStatus,
        payment_provider: order.paymentProvider,
        payment_reference: order.paymentReference,
        paid_at: order.paidAt,
        delivery_method: order.deliveryMethod,
        delivery_location: order.deliveryLocation,
        delivery_confirmed: order.deliveryConfirmed,
        delivered_at: order.deliveredAt
      }));
      supabase.from('orders').upsert(rows, { onConflict: 'id' }).then(() => {}).catch(() => {});
    } catch (error) {
      // Supabase table must exist; local storage remains active until the schema is created.
    }
  }

  function getCurrentUser() {
    const raw = localStorage.getItem(STORAGE_KEYS.currentUser);
    return raw ? JSON.parse(raw) : null;
  }

  function setCurrentUser(user) {
    if (!user) {
      localStorage.removeItem(STORAGE_KEYS.currentUser);
      return;
    }
    localStorage.setItem(STORAGE_KEYS.currentUser, JSON.stringify(user));
  }

  function clearCurrentUser() {
    localStorage.removeItem(STORAGE_KEYS.currentUser);
  }

  function normalizeEmail(email) {
    return String(email || '').trim().toLowerCase();
  }

  async function getAuthProfile(authUser, fallbackName = '') {
    const supabase = getSupabaseClient();
    const normalizedEmail = normalizeEmail(authUser?.email);
    let profile = null;

    if (supabase && authUser?.id) {
      const { data } = await supabase
        .from('users')
        .select('id, name, email, provider, role')
        .eq('id', authUser.id)
        .maybeSingle();
      profile = data;
    }

    return profile || {
      id: authUser.id,
      name: fallbackName || authUser.user_metadata?.name || normalizedEmail.split('@')[0],
      email: normalizedEmail,
      provider: 'email',
      role: normalizedEmail === DEFAULT_ADMIN.email ? 'admin' : 'user'
    };
  }

  async function registerUser({ name, email, password, provider = 'email' }) {
    const users = getUsers();
    const normalizedEmail = normalizeEmail(email);

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return { success: false, message: 'Enter a valid email address.' };
    }

    if (provider === 'email' && (!password || password.length < 6)) {
      return { success: false, message: 'Password must be at least 6 characters long.' };
    }

    const supabase = getSupabaseClient();
    if (supabase && provider === 'email') {
      const { data, error } = await supabase.auth.signUp({
        email: normalizedEmail,
        password,
        options: { data: { name: name || normalizedEmail.split('@')[0] } }
      });

      if (error) {
        return { success: false, message: error.message };
      }

      if (data.user) {
        const profile = {
          id: data.user.id,
          name: name || normalizedEmail.split('@')[0],
          email: normalizedEmail,
          password: null,
          provider: 'email',
          role: normalizedEmail === DEFAULT_ADMIN.email ? 'admin' : 'user'
        };
        await supabase.from('users').upsert(profile, { onConflict: 'id' });

        if (data.session) {
          setCurrentUser(profile);
        }

        return {
          success: true,
          user: data.session ? profile : null,
          requiresConfirmation: !data.session,
          message: data.session
            ? 'Account created successfully.'
            : 'Check your email to confirm your account before logging in.'
        };
      }
    }

    if (users.some((user) => normalizeEmail(user.email) === normalizedEmail)) {
      return { success: false, message: 'An account with this email already exists.' };
    }

    const newUser = {
      id: 'user-' + Date.now(),
      name: name || normalizedEmail.split('@')[0],
      email: normalizedEmail,
      password: provider === 'email' ? password : '',
      provider,
      role: normalizedEmail === DEFAULT_ADMIN.email ? 'admin' : 'user'
    };

    users.push(newUser);
    saveUsers(users);
    setCurrentUser(newUser);
    return { success: true, user: newUser };
  }

  async function loginUser({ email, password }) {
    const normalizedEmail = normalizeEmail(email);
    const supabase = getSupabaseClient();

    if (supabase) {
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

    const users = getUsers();
    const match = users.find((user) => normalizeEmail(user.email) === normalizedEmail);

    if (!match) {
      return { success: false, message: 'No account found with that email.' };
    }

    if (match.provider === 'email' && match.password !== password) {
      return { success: false, message: 'Incorrect password.' };
    }

    setCurrentUser(match);
    return { success: true, user: match };
  }

  async function requestPasswordReset(email) {
    const normalizedEmail = normalizeEmail(email);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      return { success: false, message: 'Enter a valid email address.' };
    }

    const supabase = getSupabaseClient();
    if (supabase) {
      const redirectTo = window.location.href.split('#')[0];
      const { error } = await supabase.auth.resetPasswordForEmail(normalizedEmail, { redirectTo });
      return error
        ? { success: false, message: error.message }
        : { success: true, requiresEmail: true };
    }

    const userExists = getUsers().some((user) => normalizeEmail(user.email) === normalizedEmail);
    return userExists
      ? { success: true, localReset: true }
      : { success: false, message: 'No account found with that email.' };
  }

  async function updatePassword({ email, password }) {
    if (!password || password.length < 6) {
      return { success: false, message: 'Password must be at least 6 characters long.' };
    }

    const supabase = getSupabaseClient();
    if (supabase) {
      const { error } = await supabase.auth.updateUser({ password });
      return error ? { success: false, message: error.message } : { success: true };
    }

    const users = getUsers();
    const normalizedEmail = normalizeEmail(email);
    const user = users.find((entry) => normalizeEmail(entry.email) === normalizedEmail);
    if (!user) return { success: false, message: 'No account found with that email.' };
    user.password = password;
    saveUsers(users);
    return { success: true };
  }

  async function socialLogin(provider) {
    const providerName = (provider || '').toLowerCase();
    const supabase = getSupabaseClient();

    if (supabase && ['google', 'apple'].includes(providerName)) {
      if (window.MRCO_SOCIAL_PROVIDERS?.[providerName] === false) {
        return {
          success: false,
          message: `${providerName === 'google' ? 'Google' : 'Apple'} sign-in is not enabled yet. Enable this provider in Supabase Authentication settings, then set its flag in supabase-config.js to true.`
        };
      }

      const { error } = await supabase.auth.signInWithOAuth({
        provider: providerName,
        options: { redirectTo: window.location.href }
      });
      return error
        ? {
          success: false,
          message: error.message?.toLowerCase().includes('provider is not enabled')
            ? 'Google sign-in is not enabled in Supabase yet. In Supabase Dashboard, open Authentication > Providers > Google, add the Google Client ID and Client Secret, save, then try again.'
            : error.message
        }
        : { success: true, redirecting: true };
    }

    const email = `${providerName}-user-${Date.now()}@example.com`;
    const existingUser = getUsers().find((user) => normalizeEmail(user.email) === normalizeEmail(email));

    if (existingUser) {
      setCurrentUser(existingUser);
      return { success: true, user: existingUser };
    }

    return registerUser({
      name: providerName === 'google' ? 'Google User' : 'Apple User',
      email,
      password: 'social-login',
      provider: providerName
    });
  }

  window.MRCo = {
    STORAGE_KEYS,
    ensureDatabase,
    getUsers,
    saveUsers,
    getProducts,
    saveProducts,
    getOrders,
    saveOrders,
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
})();
