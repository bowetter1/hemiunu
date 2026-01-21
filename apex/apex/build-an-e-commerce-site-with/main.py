from fastapi import FastAPI, Depends, HTTPException, Request, Query
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import or_, asc, desc
from decimal import Decimal
from typing import Optional, List
import models
from database import SessionLocal, engine, get_db

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

def seed_data(db: Session):
    if db.query(models.Product).count() == 0:
        products = [
            # Electronics
            models.Product(name="Wireless Headphones", description="Premium noise-canceling headphones with 20h battery life.", price=Decimal("149.99"), category="Electronics", image_url="https://picsum.photos/seed/headphones/400/400", stock=25),
            models.Product(name="Mechanical Keyboard", description="RGB backlit mechanical keyboard with blue switches.", price=Decimal("89.99"), category="Electronics", image_url="https://picsum.photos/seed/keyboard/400/400", stock=15),
            models.Product(name="4K Monitor", description="27-inch 4K UHD IPS monitor with slim bezels.", price=Decimal("349.99"), category="Electronics", image_url="https://picsum.photos/seed/monitor/400/400", stock=10),
            models.Product(name="Smart Watch", description="Fitness tracker with heart rate monitor and GPS.", price=Decimal("199.99"), category="Electronics", image_url="https://picsum.photos/seed/watch/400/400", stock=30),
            
            # Clothing
            models.Product(name="Cotton T-Shirt", description="100% organic cotton basic t-shirt in black.", price=Decimal("19.99"), category="Clothing", image_url="https://picsum.photos/seed/tshirt/400/400", stock=100),
            models.Product(name="Denim Jacket", description="Classic vintage style denim jacket.", price=Decimal("59.99"), category="Clothing", image_url="https://picsum.photos/seed/jacket/400/400", stock=40),
            models.Product(name="Running Shoes", description="Lightweight running shoes for daily training.", price=Decimal("79.99"), category="Clothing", image_url="https://picsum.photos/seed/shoes/400/400", stock=50),
            models.Product(name="Hoodie", description="Warm fleece hoodie with kangaroo pocket.", price=Decimal("39.99"), category="Clothing", image_url="https://picsum.photos/seed/hoodie/400/400", stock=60),

            # Home
            models.Product(name="Desk Lamp", description="Adjustable LED desk lamp with USB charging port.", price=Decimal("29.99"), category="Home", image_url="https://picsum.photos/seed/lamp/400/400", stock=45),
            models.Product(name="Succulent Planter", description="Ceramic geometric planter for small plants.", price=Decimal("14.99"), category="Home", image_url="https://picsum.photos/seed/planter/400/400", stock=80),
            models.Product(name="Wall Clock", description="Minimalist modern wall clock.", price=Decimal("24.99"), category="Home", image_url="https://picsum.photos/seed/clock/400/400", stock=35)
        ]
        db.add_all(products)
        db.commit()

@app.on_event("startup")
def startup_event():
    db = SessionLocal()
    seed_data(db)
    db.close()

# API ENDPOINTS:
# GET  /products         - list all
# GET  /products/<id>    - get one
# GET  /                 - homepage (HTML)

@app.get("/")
def serve_frontend(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/product/{product_id}")
def serve_product_page(request: Request, product_id: int):
    return templates.TemplateResponse("product.html", {"request": request, "product_id": product_id})

@app.get("/products")
def read_products(
    search: Optional[str] = None,
    category: Optional[str] = None,
    sort: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(models.Product)

    # 1. Apply Search (name or description, case-insensitive)
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            or_(
                models.Product.name.ilike(search_term),
                models.Product.description.ilike(search_term)
            )
        )

    # 2. Apply Category Filter (exact match, case-insensitive)
    if category:
        query = query.filter(models.Product.category.ilike(category))

    # 3. Apply Sorting
    if sort:
        if sort == "price_asc":
            query = query.order_by(asc(models.Product.price))
        elif sort == "price_desc":
            query = query.order_by(desc(models.Product.price))
        elif sort == "name_asc":
            query = query.order_by(asc(models.Product.name))
        elif sort == "name_desc":
            query = query.order_by(desc(models.Product.name))

    products = query.all()
    
    return {
        "products": products,
        "total": len(products),
        "filters": {
            "search": search,
            "category": category,
            "sort": sort
        }
    }

@app.get("/categories")
def get_categories(db: Session = Depends(get_db)):
    # Get distinct categories
    categories = db.query(models.Product.category).distinct().order_by(models.Product.category).all()
    # categories is a list of tuples like [('Clothing',), ('Electronics',)], flatten it
    return {"categories": [c[0] for c in categories]}

@app.get("/products/{product_id}")
def read_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(models.Product).filter(models.Product.id == product_id).first()
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
