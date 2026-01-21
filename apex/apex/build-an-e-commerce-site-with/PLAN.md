# Project Plan

## Config
- **DATABASE**: none
- **FRAMEWORK**: fastapi
- **NOTE**: Using SQLite file (ecommerce.db) - no external database service needed

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app, routes, startup/shutdown |
| database.py | SQLAlchemy engine, session management |
| models.py | Product, CartItem, Order SQLAlchemy models |
| schemas.py | Pydantic schemas for request/response |
| seed.py | Seed script for sample products |
| templates/index.html | Homepage with product grid |
| templates/product.html | Product detail page |
| templates/base.html | Base template with dark theme |
| static/css/style.css | Dark theme styles |
| static/js/main.js | Frontend JavaScript |

## Database Schema

### products
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| name | VARCHAR(200) | NOT NULL |
| description | TEXT | |
| price | DECIMAL(10,2) | NOT NULL |
| category | VARCHAR(100) | NOT NULL |
| image_url | VARCHAR(500) | |
| stock | INTEGER | NOT NULL, DEFAULT 0 |
| created_at | TIMESTAMP | DEFAULT NOW |

### cart_items (Sprint 3)
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| session_id | VARCHAR(100) | NOT NULL, INDEX |
| product_id | INTEGER | FK → products.id |
| quantity | INTEGER | NOT NULL, DEFAULT 1 |
| created_at | TIMESTAMP | DEFAULT NOW |

### orders (Sprint 4)
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| session_id | VARCHAR(100) | NOT NULL |
| total | DECIMAL(10,2) | NOT NULL |
| status | VARCHAR(50) | DEFAULT 'completed' |
| shipping_name | VARCHAR(200) | |
| shipping_address | TEXT | |
| created_at | TIMESTAMP | DEFAULT NOW |

### order_items (Sprint 4)
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| order_id | INTEGER | FK → orders.id |
| product_id | INTEGER | FK → products.id |
| quantity | INTEGER | NOT NULL |
| price_at_purchase | DECIMAL(10,2) | NOT NULL |

## Session Management Strategy
- Use HTTP-only cookies with UUID session ID
- Session ID generated on first request if not present
- Cart items linked to session_id (no user accounts needed)
- Sessions persist across browser restarts

## Environment Variables
- PORT (set by Railway, default 8000 for local)
- DATABASE_PATH (optional, defaults to ./ecommerce.db)

---

## Sprint 1: API Contract

### GET /products
List all products.

**Request:** None

**Response 200:**
```json
[
  {
    "id": 1,
    "name": "Wireless Headphones",
    "description": "Premium noise-canceling headphones",
    "price": "149.99",
    "category": "Electronics",
    "image_url": "https://picsum.photos/seed/headphones/400/400",
    "stock": 25
  }
]
```

**Notes:**
- price is string (Decimal → string for JSON precision)
- Returns empty array if no products

---

### GET /products/{id}
Get single product by ID.

**Request:** Path parameter `id` (integer)

**Response 200:**
```json
{
  "id": 1,
  "name": "Wireless Headphones",
  "description": "Premium noise-canceling headphones",
  "price": "149.99",
  "category": "Electronics",
  "image_url": "https://picsum.photos/seed/headphones/400/400",
  "stock": 25
}
```

**Response 404:**
```json
{
  "detail": "Product not found"
}
```

---

### GET / (HTML)
Homepage with product grid.

**Response:** HTML page rendered from `templates/index.html`
- Displays all products in responsive grid
- Each product shows: image, name, price, category
- Clicking product navigates to detail page

---

### GET /product/{id} (HTML)
Product detail page.

**Response:** HTML page rendered from `templates/product.html`
- Shows full product details
- "Add to Cart" button (functional in Sprint 3)

---

## Sprint 1 Features
1. Project structure with FastAPI + SQLAlchemy
2. SQLite database with products table
3. Seed data: 10+ products across 3+ categories (Electronics, Clothing, Home)
4. GET /products API endpoint
5. GET /products/{id} API endpoint
6. Homepage with dark-themed product grid
7. Product detail page

## Categories for Seed Data
- Electronics (headphones, keyboards, monitors, etc.)
- Clothing (t-shirts, hoodies, jackets, etc.)
- Home (lamps, planters, organizers, etc.)

---

## Sprint 2: Search & Filter API Contract

### GET /products (Enhanced)
List products with optional search, filter, and sort parameters.

**Request:** Query parameters (all optional)
| Parameter | Type | Description |
|-----------|------|-------------|
| search | string | Search term to match against name OR description (case-insensitive) |
| category | string | Filter by exact category name (case-insensitive) |
| sort | string | Sort order: `price_asc`, `price_desc`, `name_asc`, `name_desc` |

**Example Requests:**
- `GET /products` → All products (default, unsorted)
- `GET /products?search=wireless` → Products containing "wireless" in name or description
- `GET /products?category=Electronics` → Only Electronics category
- `GET /products?sort=price_asc` → Sorted by price low to high
- `GET /products?search=shirt&category=Clothing&sort=price_desc` → Combined filters

**Response 200:**
```json
{
  "products": [
    {
      "id": 1,
      "name": "Wireless Headphones",
      "description": "Premium noise-canceling headphones",
      "price": "149.99",
      "category": "Electronics",
      "image_url": "https://picsum.photos/seed/headphones/400/400",
      "stock": 25
    }
  ],
  "total": 1,
  "filters": {
    "search": "wireless",
    "category": null,
    "sort": null
  }
}
```

**Response Fields:**
- `products`: Array of matching products
- `total`: Number of products returned
- `filters`: Echo of applied filters (useful for debugging/UI state)

**Notes:**
- If no parameters provided, returns all products (same as Sprint 1 behavior)
- Search is case-insensitive and matches partial strings
- Category match is case-insensitive but must be exact category name
- Invalid sort value is ignored (returns unsorted)
- Empty result returns `{ "products": [], "total": 0, "filters": {...} }`

---

### GET /categories
List all available categories for the dropdown filter.

**Request:** None

**Response 200:**
```json
{
  "categories": ["Clothing", "Electronics", "Home"]
}
```

**Notes:**
- Returns distinct categories from products table
- Sorted alphabetically
- Used by frontend to populate category dropdown

---

## Sprint 2 Frontend Requirements

### Search Bar Component
- Text input with placeholder "Search products..."
- Debounce input (300ms) to avoid excessive API calls
- Triggers fetch on input change

### Category Dropdown Component
- Fetch categories from `GET /categories` on page load
- First option: "All Categories" (no filter)
- Selecting category triggers fetch

### Sort Dropdown Component
- Options:
  - "Default" (no sort)
  - "Price: Low to High" → `sort=price_asc`
  - "Price: High to Low" → `sort=price_desc`
  - "Name: A-Z" → `sort=name_asc`
  - "Name: Z-A" → `sort=name_desc`

### Live Filtering Implementation
- All filters update URL query params (for shareability)
- Single `fetchProducts()` function builds query string from current filter state
- DOM updates without page reload using JavaScript
- Show "No products found" message when results empty
- Show loading indicator during fetch

### JavaScript Implementation Pattern
```javascript
// Filter state
let filters = { search: '', category: '', sort: '' };

// Debounced search
let searchTimeout;
searchInput.addEventListener('input', (e) => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    filters.search = e.target.value;
    fetchProducts();
  }, 300);
});

// Fetch with filters
async function fetchProducts() {
  const params = new URLSearchParams();
  if (filters.search) params.append('search', filters.search);
  if (filters.category) params.append('category', filters.category);
  if (filters.sort) params.append('sort', filters.sort);

  const response = await fetch(`/products?${params}`);
  const data = await response.json();
  renderProducts(data.products);
}
```

## Sprint 2 Features Summary
1. Enhanced GET /products with search, category, sort query params
2. New GET /categories endpoint
3. Search bar with debounced input
4. Category dropdown filter
5. Price/name sort dropdown
6. Live filtering without page reload
7. URL query params for shareable filtered views
