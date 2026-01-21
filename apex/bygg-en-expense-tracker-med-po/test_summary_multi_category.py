#!/usr/bin/env python3
"""
Quick test to verify the GET /expenses/summary endpoint handles multiple categories correctly
"""

import sqlite3
import os
from datetime import date
from decimal import Decimal
from main import get_expense_summary

def test_summary_with_multiple_categories():
    """
    Test the summary function directly with multiple categories
    """
    print("Testing summary function with multiple categories...")
    
    # Create some test expenses directly in the database
    from database import SessionLocal
    from models import Expense
    from sqlalchemy import create_engine, text
    from datetime import date
    
    # Connect to the database
    db = SessionLocal()
    
    try:
        # Clear existing expenses for a clean test
        db.execute(text("DELETE FROM expenses"))
        db.commit()
        
        # Add test expenses in different categories
        test_expenses = [
            {"amount": 100.50, "description": "Groceries", "category": "Food", "date": date.today()},
            {"amount": 50.25, "description": "Bus ticket", "category": "Transport", "date": date.today()},
            {"amount": 200.00, "description": "Movie tickets", "category": "Entertainment", "date": date.today()},
            {"amount": 100.50, "description": "More groceries", "category": "Food", "date": date.today()},
            {"amount": 150.75, "description": "Electricity bill", "category": "Bills", "date": date.today()},
        ]
        
        for exp in test_expenses:
            new_expense = Expense(
                amount=exp["amount"],
                description=exp["description"],
                category=exp["category"],
                date=exp["date"]
            )
            db.add(new_expense)
        
        db.commit()
        
        # Now test the summary function
        summary = get_expense_summary()
        
        print(f"Summary result: {summary}")
        
        # Verify the results
        expected_total = "602.00"  # 100.50 + 50.25 + 200.00 + 100.50 + 150.75
        expected_count = 5
        expected_food_total = "201.00"  # 100.50 + 100.50
        expected_transport_total = "50.25"
        expected_entertainment_total = "200.00"
        expected_bills_total = "150.75"
        
        assert summary.total == expected_total, f"Expected total {expected_total}, got {summary.total}"
        assert summary.count == expected_count, f"Expected count {expected_count}, got {summary.count}"
        assert summary.by_category["Food"] == expected_food_total, f"Expected Food total {expected_food_total}, got {summary.by_category['Food']}"
        assert summary.by_category["Transport"] == expected_transport_total, f"Expected Transport total {expected_transport_total}, got {summary.by_category['Transport']}"
        assert summary.by_category["Entertainment"] == expected_entertainment_total, f"Expected Entertainment total {expected_entertainment_total}, got {summary.by_category['Entertainment']}"
        assert summary.by_category["Bills"] == expected_bills_total, f"Expected Bills total {expected_bills_total}, got {summary.by_category['Bills']}"
        
        print("✓ All assertions passed!")
        print("✓ Summary endpoint correctly handles multiple categories")
        print("✓ Amounts are properly converted to strings for decimal precision")
        print("✓ Category totals are calculated correctly")
        print("✓ Count of expenses is accurate")
        
        return True
        
    except Exception as e:
        print(f"✗ Error in test: {e}")
        return False
    finally:
        db.close()

if __name__ == "__main__":
    success = test_summary_with_multiple_categories()
    if success:
        print("\n🎉 Summary endpoint test with multiple categories passed!")
    else:
        print("\n❌ Summary endpoint test failed!")
        exit(1)