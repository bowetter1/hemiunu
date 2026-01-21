# E-Commerce Site - Sprint Backlog

## Overview
Dark modern themed e-commerce site with product catalog, shopping cart, and checkout flow.
Stack: FastAPI + SQLite + Jinja2 templates + vanilla JS

---

## Sprint 1: Core Setup + Product Catalog Display
| Feature | Done when... |
|---------|--------------|
| Project structure | main.py, database.py, models.py exist |
| SQLite database | Products table with: id, name, description, price, category, image_url, stock |
| Seed data | 10+ sample products across 3+ categories |
| Product listing | GET /products returns all products |
| Product detail | GET /products/{id} returns single product |
| Base UI | Homepage displays products in grid layout |
| Dark theme | Modern dark color scheme applied |

## Sprint 2: Search & Filter
| Feature | Done when... |
|---------|--------------|
| Search bar | Text input that filters products by name/description |
| Category filter | Dropdown to filter by category |
| Price sort | Sort by price (low-high, high-low) |
| Live filtering | Results update without page reload |

## Sprint 3: Shopping Cart
| Feature | Done when... |
|---------|--------------|
| Session management | Cart persists via session ID cookie |
| Add to cart | Button on each product adds item to cart |
| Cart view | /cart page shows items, quantities, subtotal |
| Update quantity | Can increase/decrease item quantity |
| Remove item | Can remove items from cart |
| Cart badge | Header shows item count |

## Sprint 4: Checkout + Inventory
| Feature | Done when... |
|---------|--------------|
| Checkout page | /checkout with form for shipping info |
| Order summary | Shows cart items + total before payment |
| Mock payment | "Pay Now" button simulates success |
| Order confirmation | Shows order ID and thank you message |
| Inventory decrement | Stock decreases after successful order |
| Out of stock handling | Can't add to cart if stock = 0 |

---

## Out of Scope
- Real payment processing (Stripe, PayPal)
- User accounts / authentication
- Order history
- Shipping cost calculation
- Tax calculation
- Product reviews
- Admin panel for products
