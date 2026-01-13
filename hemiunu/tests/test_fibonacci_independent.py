#!/usr/bin/env python3
"""
OBEROENDE TESTER för fibonacci(n) funktionen
Dessa tester skrivna av TESTER baserat på kontraktet, INNAN läsning av Worker's kod.

Fibonacci-sekvens: F(0)=0, F(1)=1, F(n)=F(n-1)+F(n-2) för n>1
Sekvens: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, ...
"""

import sys
import os

# Lägg till src till Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

def test_fibonacci_base_cases():
    """Testa grundfallen F(0) och F(1)"""
    from math_funcs import fibonacci
    
    # F(0) = 0
    result = fibonacci(0)
    assert result == 0, f"fibonacci(0) ska returnera 0, fick {result}"
    
    # F(1) = 1  
    result = fibonacci(1)
    assert result == 1, f"fibonacci(1) ska returnera 1, fick {result}"
    
    print("✓ Grundfall F(0) och F(1) fungerar korrekt")

def test_fibonacci_small_values():
    """Testa små värden i Fibonacci-sekvensen"""
    from math_funcs import fibonacci
    
    # Förväntat: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
    expected_values = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
    
    for i, expected in enumerate(expected_values):
        result = fibonacci(i)
        assert result == expected, f"fibonacci({i}) ska returnera {expected}, fick {result}"
    
    print(f"✓ Små värden F(0) till F({len(expected_values)-1}) fungerar korrekt")

def test_fibonacci_medium_values():
    """Testa medelstora värden"""
    from math_funcs import fibonacci
    
    # Testfall för n=10 till n=15
    test_cases = {
        10: 55,
        11: 89, 
        12: 144,
        13: 233,
        14: 377,
        15: 610
    }
    
    for n, expected in test_cases.items():
        result = fibonacci(n)
        assert result == expected, f"fibonacci({n}) ska returnera {expected}, fick {result}"
    
    print("✓ Medelstora värden F(10) till F(15) fungerar korrekt")

def test_fibonacci_larger_values():
    """Testa större värden för att säkerställa skalbarhet"""
    from math_funcs import fibonacci
    
    # Testfall för några större värden
    test_cases = {
        20: 6765,
        25: 75025,
        30: 832040
    }
    
    for n, expected in test_cases.items():
        result = fibonacci(n)
        assert result == expected, f"fibonacci({n}) ska returnera {expected}, fick {result}"
    
    print("✓ Större värden F(20), F(25), F(30) fungerar korrekt")

def test_fibonacci_properties():
    """Testa matematiska egenskaper hos Fibonacci-sekvensen"""
    from math_funcs import fibonacci
    
    # Testa rekursionsegenskapen: F(n) = F(n-1) + F(n-2) för n > 1
    for n in range(2, 15):
        fn = fibonacci(n)
        fn_1 = fibonacci(n-1)  
        fn_2 = fibonacci(n-2)
        
        assert fn == fn_1 + fn_2, f"F({n}) = {fn} ska vara F({n-1}) + F({n-2}) = {fn_1} + {fn_2} = {fn_1 + fn_2}"
    
    print("✓ Rekursionsegenskapen F(n) = F(n-1) + F(n-2) verifierad")

def test_fibonacci_return_type():
    """Testa att funktionen returnerar heltal"""
    from math_funcs import fibonacci
    
    for n in range(0, 10):
        result = fibonacci(n)
        assert isinstance(result, int), f"fibonacci({n}) ska returnera int, fick {type(result)}"
    
    print("✓ Returnerar korrekt datatyp (int)")

def test_fibonacci_specific_worker_case():
    """Testa det specifika fall som Worker's CLI-test kör: fibonacci(10)"""
    from math_funcs import fibonacci
    
    # fibonacci(10) ska vara 55
    result = fibonacci(10)
    expected = 55
    assert result == expected, f"fibonacci(10) ska returnera {expected}, fick {result}"
    
    print("✓ Worker's CLI-test case fibonacci(10) = 55 verifierad")

def run_all_tests():
    """Kör alla tester"""
    print("=== KÖR OBEROENDE TESTER FÖR fibonacci(n) ===")
    print()
    
    try:
        test_fibonacci_base_cases()
        test_fibonacci_small_values()  
        test_fibonacci_medium_values()
        test_fibonacci_larger_values()
        test_fibonacci_properties()
        test_fibonacci_return_type()
        test_fibonacci_specific_worker_case()
        
        print()
        print("🎉 ALLA OBEROENDE TESTER PASSERADE!")
        return True
        
    except Exception as e:
        print(f"❌ TEST MISSLYCKADES: {e}")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)