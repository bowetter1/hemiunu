from main import read_products, get_categories
from database import SessionLocal

def run_tests():
    db = SessionLocal()
    try:
        # Test Categories
        print("Testing Categories...")
        cats = get_categories(db)
        print(f"Categories: {cats}")
        assert "categories" in cats
        assert isinstance(cats["categories"], list)
        
        # Test Search
        print("\nTesting Search 'headphone'...")
        res = read_products(search="headphone", db=db)
        print(f"Found: {res['total']}")
        assert res["total"] > 0
        for p in res["products"]:
            assert "headphone" in p.name.lower() or "headphone" in p.description.lower()

        # Test Filter
        print("\nTesting Filter 'Electronics'...")
        res = read_products(category="Electronics", db=db)
        print(f"Found: {res['total']}")
        assert res["total"] > 0
        for p in res["products"]:
            assert p.category == "Electronics"

        # Test Sort
        print("\nTesting Sort 'price_asc'...")
        res = read_products(sort="price_asc", db=db)
        prices = [p.price for p in res["products"]]
        print(f"Prices: {prices}")
        assert prices == sorted(prices)

        print("\n✅ Logic tests passed!")
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    run_tests()
