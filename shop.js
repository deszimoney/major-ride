(function () {
  const { ensureDatabase, getProducts } = window.MRCo;
  const escapeHtml = (value) => window.MRCo.escapeHtml(value);

  function resolveSearchQuery() {
    const params = new URLSearchParams(window.location.search);
    return (params.get('q') || '').trim().toLowerCase();
  }

  // Category links use the same query-string pattern as the search form.
  function resolveCategory() {
    const params = new URLSearchParams(window.location.search);
    return (params.get('category') || '').trim();
  }

  function renderProducts() {
    const grid = document.getElementById('product-grid');
    if (!grid) return;

    const products = getProducts();
    const query = resolveSearchQuery();
    const category = resolveCategory();

    const heading = document.getElementById('shop-heading');
    if (heading) heading.textContent = category ? `${category} collection` : 'All products';

    const filtered = products.filter((product) => {
      const text = `${product.name} ${product.category} ${product.description}`.toLowerCase();
      const matchesCategory = !category || product.category.toLowerCase() === category.toLowerCase();
      return matchesCategory && (!query || text.includes(query));
    });

    if (!filtered.length) {
      grid.innerHTML = '<p class="empty-state">No products match your search. Try another keyword.</p>';
      return;
    }

    grid.innerHTML = filtered.map((product) => `
      <!-- Each card keeps the product name, category, and price visible before purchase. -->
      <article class="product-card">
      <img src="${escapeHtml(window.MRCo.sanitizeImageUrl(product.image))}" alt="${escapeHtml(product.name)}">
        <div class="product-card-body">
        <p class="product-category">${escapeHtml(product.category)}</p>
        <h2>${escapeHtml(product.name)}</h2>
        <p class="product-description">${escapeHtml(product.description)}</p>
        <div class="product-buy-row"><p class="price">GHS ${Number(product.price).toFixed(2)}</p><button class="btn product-buy" type="button" data-product-id="${escapeHtml(product.id)}">Add to cart</button></div>
        </div>
      </article>
    `).join('');
  }

  function attachSearch() {
    const form = document.getElementById('site-search-form');
    if (!form) return;

    const input = document.getElementById('site-search');
    const params = new URLSearchParams(window.location.search);
    if (input && params.has('q')) {
      input.value = params.get('q');
    }

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const query = input ? input.value.trim() : '';
      const destination = query ? `shop.html?q=${encodeURIComponent(query)}` : 'shop.html';
      window.location.href = destination;
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    ensureDatabase();
    renderProducts();
    attachSearch();
  });

  window.addEventListener('storage', (event) => {
    if (event.key === window.MRCo?.STORAGE_KEYS?.products) renderProducts();
  });
  window.addEventListener('mrco-products-updated', renderProducts);
})();
