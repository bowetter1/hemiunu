// Format currency
const formatPrice = (price) => {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(price);
};

// Fetch all products
async function fetchProducts() {
    const grid = document.getElementById('product-grid');
    if (!grid) return;

    grid.innerHTML = '<div class="loading">Loading products...</div>';

    try {
        const response = await fetch('/products');
        if (!response.ok) throw new Error('Failed to fetch products');
        
        const products = await response.json();
        
        if (products.length === 0) {
            grid.innerHTML = '<div class="loading">No products found.</div>';
            return;
        }

        grid.innerHTML = products.map(product => `
            <a href="/product/${product.id}" class="card">
                <img src="${product.image_url || 'https://via.placeholder.com/400'}" alt="${product.name}" class="card-image" loading="lazy">
                <div class="card-content">
                    <div class="card-category">${product.category}</div>
                    <h2 class="card-title">${product.name}</h2>
                    <div class="card-price">${formatPrice(product.price)}</div>
                </div>
            </a>
        `).join('');
        
    } catch (error) {
        console.error('Error:', error);
        grid.innerHTML = '<div class="loading">Error loading products. Please try again later.</div>';
    }
}

// Fetch single product
async function fetchProductDetail() {
    const container = document.getElementById('product-detail');
    if (!container) return;

    // Get ID from URL path: /product/{id}
    const pathParts = window.location.pathname.split('/');
    const id = pathParts[pathParts.length - 1];

    if (!id) {
        container.innerHTML = '<div class="loading">Product not found.</div>';
        return;
    }

    container.innerHTML = '<div class="loading">Loading details...</div>';

    try {
        const response = await fetch(`/products/${id}`); // Note: API is plural /products/{id}
        
        if (!response.ok) {
            if (response.status === 404) {
                container.innerHTML = '<div class="loading">Product not found.</div>';
            } else {
                throw new Error('Failed to fetch product');
            }
            return;
        }

        const product = await response.json();
        
        container.innerHTML = `
            <img src="${product.image_url || 'https://via.placeholder.com/600'}" alt="${product.name}" class="detail-image">
            <div class="detail-info">
                <div class="card-category">${product.category}</div>
                <h1 class="detail-title">${product.name}</h1>
                <div class="detail-price">${formatPrice(product.price)}</div>
                <p class="detail-description">${product.description}</p>
                <div class="actions">
                    <button class="btn btn-primary" disabled title="Coming in Sprint 3">
                        Add to Cart
                    </button>
                    <span style="margin-left: 10px; font-size: 0.8em; color: var(--text-muted);">(Cart coming soon)</span>
                </div>
                <div style="margin-top: 20px; color: ${product.stock > 0 ? 'var(--success)' : 'var(--danger)'}">
                    ${product.stock > 0 ? 'In Stock' : 'Out of Stock'}
                </div>
            </div>
        `;
        
    } catch (error) {
        console.error('Error:', error);
        container.innerHTML = '<div class="loading">Error loading product.</div>';
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('product-grid')) {
        fetchProducts();
    }
    if (document.getElementById('product-detail')) {
        fetchProductDetail();
    }
});
